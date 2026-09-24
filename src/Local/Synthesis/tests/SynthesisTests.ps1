#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'ResearchAutomation.Synthesis.psd1') -Force
. (Join-Path $PSScriptRoot 'TestHarness.ps1')
$script:Assertions=0
function Assert-RapSynth {param([bool]$Condition,[string]$Message)$script:Assertions++;if(!$Condition){throw $Message}}
function Assert-RapSynthThrows {param([scriptblock]$Action,[string]$Pattern,[string]$Message)$script:Assertions++;$m=$null;try{& $Action}catch{$m=$_.Exception.Message};if($null -eq $m -or $m -notmatch $Pattern){throw "$Message Actual=$m"}}
function Assert-RapNear {param([double]$Actual,[double]$Expected,[double]$Tolerance,[string]$Message)$script:Assertions++;if([Math]::Abs($Actual-$Expected) -gt $Tolerance){throw "$Message Actual=$Actual Expected=$Expected Tol=$Tolerance"}}

$records=New-RapBasicSynthesisFixture
$spec=New-RapAnalysisSpecification -AnalysisId AN-PRIMARY -ProjectId PR001 -Model RANDOM -Estimator DL
$dataset=New-RapTestAnalysisDataset -Specification $spec -Records $records
$memory=New-RapMemorySynthesisDependencies
$result=Invoke-RapSynthesis -Specification $spec -Dataset $dataset -OperationId SYNTH-PRIMARY -Dependencies $memory.Dependencies

# 01-05 input / identity
Assert-RapSynth (@($dataset.Rows).Count -eq 3 -and @($dataset.Rows|Where-Object ConfirmationState -ne 'RESEARCHER_CONFIRMED').Count -eq 0) 'TEST 01 confirmation gate failed.'
$ai=New-RapSynthesisRecord 'LIB:L000004' ES-AI .2 -ConfirmationState AI_ASSISTED
Assert-RapSynthThrows {New-RapTestAnalysisDataset $spec @($ai)} 'RESEARCHER_CONFIRMATION_REQUIRED' 'TEST 02 AI input admitted.'
$wrong=New-RapSynthesisRecord 'LIB:L000004' ES-X .2 -ProjectId PR002
Assert-RapSynthThrows {New-RapTestAnalysisDataset $spec @($wrong)} 'PROJECT_SCOPE_MISMATCH' 'TEST 03 project boundary failed.'
Assert-RapSynth ($dataset.Rows[0].LibraryId -match '^LIB:L') 'TEST 04 Library traceability failed.'
$dependent=@(New-RapSynthesisRecord 'LIB:L000010' ES-D1 .2 -DependencyGroupId STUDY-D;New-RapSynthesisRecord 'LIB:L000010' ES-D2 .3 -DependencyGroupId STUDY-D)
$depSpec=New-RapAnalysisSpecification -AnalysisId AN-DEP -ProjectId PR001 -Model RANDOM -Estimator DL -DependencyStrategy RVE
$depData=New-RapTestAnalysisDataset $depSpec $dependent
Assert-RapSynth (@($depData.Rows|Select-Object EffectSizeId -Unique).Count -eq 2) 'TEST 05 dependent effects lost identity.'

# 06-10 validation
$missing=$records[0].PSObject.Copy();$missing.MetaCodingId=''
Assert-RapSynthThrows {New-RapTestAnalysisDataset $spec @($missing)} 'ANALYSIS_INPUT_REQUIRED' 'TEST 06 missing input did not fail.'
$badN=New-RapSynthesisRecord 'LIB:L000011' ES-N .2 -SampleSize -1
Assert-RapSynthThrows {New-RapTestAnalysisDataset $spec @($badN)} 'INVALID_SAMPLE_SIZE' 'TEST 07 invalid N did not fail.'
$badV=New-RapSynthesisRecord 'LIB:L000012' ES-V .2 -Variance 0
Assert-RapSynthThrows {New-RapTestAnalysisDataset $spec @($badV)} 'INVALID_VARIANCE' 'TEST 08 invalid variance did not fail.'
$unsupported=New-RapSynthesisRecord 'LIB:L000013' ES-U .2;$unsupported.EffectSizeType='Odds_Ratio'
Assert-RapSynthThrows {New-RapTestAnalysisDataset $spec @($unsupported)} 'UNSUPPORTED_EFFECT_CONVERSION' 'TEST 09 unsupported conversion did not fail.'
$conflict=New-RapSynthesisRecord 'LIB:L000014' ES-C .2 -EvidenceStatus CONFLICTING_EVIDENCE
Assert-RapSynthThrows {New-RapTestAnalysisDataset $spec @($conflict)} 'UNRESOLVED_CONFLICT' 'TEST 10 conflict admitted.'

# 11-15 effect calculation
Assert-RapNear $dataset.Rows[0].OriginalEffect .1 1e-12 'TEST 11 direct effect changed.'
$derived=Get-RapHedgesG -MeanTreatment 12 -MeanControl 10 -SdTreatment 4 -SdControl 4 -NTreatment 50 -NControl 50
Assert-RapNear $derived.EffectValue .4961 .0002 'TEST 12 Hedges g incorrect.'
Assert-RapSynth ($derived.SourceInputs.MeanTreatment -eq 12 -and $derived.SourceInputs.NControl -eq 50) 'TEST 13 derived inputs missing.'
$derivedRecord=New-RapSynthesisRecord 'LIB:L000015' ES-H $derived.EffectValue $derived.Variance -EffectOrigin DERIVED_EFFECT -StatisticalInputs $derived.SourceInputs -Transformation ([pscustomobject]@{Method=$derived.Method;Version=$derived.FormulaVersion})
$derivedData=New-RapTestAnalysisDataset $spec @($derivedRecord)
Assert-RapSynth ($derivedData.Rows[0].EffectOrigin -eq 'DERIVED_EFFECT' -and $dataset.Rows[0].EffectOrigin -eq 'REPORTED_EFFECT') 'TEST 14 origins collapsed.'
Assert-RapNear $derived.StandardError ([Math]::Sqrt($derived.Variance)) 1e-12 'TEST 15 numerical tolerance failed.'

# 16-19 direction
Assert-RapSynth ($dataset.Rows[0].DirectionAction -eq 'NONE') 'TEST 16 direction metadata missing.'
$needs=New-RapSynthesisRecord 'LIB:L000016' ES-R .4 -DirectionAction REQUIRED
Assert-RapSynthThrows {New-RapTestAnalysisDataset $spec @($needs)} 'DIRECTION_HARMONIZATION_REQUIRED' 'TEST 17 silent reversal occurred.'
$reverse=New-RapSynthesisRecord 'LIB:L000016' ES-R .4 -DirectionAction REVERSE -DirectionConfirmed $true
$reverseData=New-RapTestAnalysisDataset $spec @($reverse)
Assert-RapNear $reverseData.Rows[0].AnalysisEffect -.4 1e-12 'TEST 18 approved reversal incorrect.'
Assert-RapNear $reverseData.Rows[0].OriginalEffect .4 1e-12 'TEST 19 original effect overwritten.'

# 20-23 dataset
$datasetAgain=New-RapTestAnalysisDataset $spec @($records|Sort-Object EffectSizeId -Descending)
Assert-RapSynth (($dataset.Rows|ConvertTo-Json -Depth 20 -Compress) -replace '"BuiltAt":"[^"]+",?','' -ne '') 'TEST 20 dataset construction failed.'
Assert-RapSynth ($dataset.DatasetHash -eq $datasetAgain.DatasetHash) 'TEST 21 dataset hash unstable.'
$changed=New-RapBasicSynthesisFixture;$changed[0].EffectValue=.11;$changedData=New-RapTestAnalysisDataset $spec $changed
Assert-RapSynth ($changedData.DatasetHash -ne $dataset.DatasetHash) 'TEST 22 changed input hash unchanged.'
Assert-RapSynth ($dataset.Rows[0].MetaCodingId -and $dataset.Rows[0].OutcomeId -and $dataset.Rows[0].ProvenanceReference) 'TEST 23 upstream IDs missing.'

# 24-27 specification/version
$tempRoot=Join-Path ([IO.Path]::GetTempPath()) "rap-synth-$PID-$([guid]::NewGuid().ToString('N'))";[void][IO.Directory]::CreateDirectory($tempRoot)
try{
  $db=Join-Path $tempRoot synthesis.db;$sqlite=New-RapSynthesisSqliteDependencies $db
  $stored=Invoke-RapSynthesis $spec $dataset SYNTH-SQL-1 $sqlite
  $snap=Get-RapSynthesisFixtureSnapshot $db
  Assert-RapSynth (@($snap.Specifications).Count -eq 1) 'TEST 24 configuration not persisted.'
  $specSame=New-RapAnalysisSpecification -AnalysisId AN-PRIMARY -ProjectId PR001 -Model RANDOM -Estimator DL
  Assert-RapSynth ($spec.ConfigurationHash -eq $specSame.ConfigurationHash) 'TEST 25 config hash unstable.'
  $fixed=New-RapAnalysisSpecification -AnalysisId AN-PRIMARY -ProjectId PR001 -Model FIXED -Estimator NONE
  Assert-RapSynth ($fixed.ConfigurationHash -ne $spec.ConfigurationHash) 'TEST 26 meaningful config hash unchanged.'
  [void](Invoke-RapSynthesis $fixed $dataset SYNTH-SQL-2 $sqlite);$snap2=Get-RapSynthesisFixtureSnapshot $db
  Assert-RapSynth (@($snap2.Specifications).Count -eq 2 -and @($snap2.Runs).Count -eq 2) 'TEST 27 prior version overwritten.'

  # 28-36 meta-analysis/heterogeneity
  Assert-RapNear $result.Run.PooledEstimate .6 1e-12 'TEST 28 pooled effect incorrect.'
  Assert-RapNear $result.Run.ConfidenceLow (-.0300529) .00001 'TEST 29 CI incorrect.'
  Assert-RapSynth ($result.Run.StudyCount -eq 3 -and $result.Run.EffectCount -eq 3) 'TEST 30 counts incorrect.'
  Assert-RapSynth ($result.Run.Model -eq 'RANDOM') 'TEST 31 model not recorded.'
  Assert-RapSynth ($result.Run.Estimator -eq 'DL') 'TEST 32 estimator not recorded.'
  Assert-RapNear $result.Run.Q 15.5 1e-10 'TEST 33 Q incorrect.'
  Assert-RapNear $result.Run.I2 87.096774 .00001 'TEST 34 I2 incorrect.'
  Assert-RapNear $result.Run.Tau2 .27 1e-12 'TEST 35 tau2 incorrect.'
  Assert-RapSynth ($null -eq $result.Run.PSObject.Properties['HeterogeneityInterpretation']) 'TEST 36 qualitative conclusion generated.'

  # 37-42 dependency/moderator
  Assert-RapSynth (@($depData.DependencyGroups).Count -eq 1) 'TEST 37 dependency undetected.'
  $noDep=New-RapAnalysisSpecification -AnalysisId AN-NODEP -ProjectId PR001 -Model RANDOM -Estimator DL
  Assert-RapSynthThrows {New-RapTestAnalysisDataset $noDep $dependent} 'DEPENDENCY_STRATEGY_REQUIRED' 'TEST 38 silent independence assumed.'
  Assert-RapSynth ($depData.DependencyStrategy -eq 'RVE') 'TEST 39 dependency strategy missing.'
  $modSpec=New-RapAnalysisSpecification -AnalysisId AN-MOD -ProjectId PR001 -Model RANDOM -Estimator DL -ModeratorSelection Region
  $modData=New-RapTestAnalysisDataset $modSpec $records;$sub=Invoke-RapSubgroupAnalysis $modSpec $modData Region
  Assert-RapSynth ($sub.Moderator -eq 'Region') 'TEST 40 moderator not linked.'
  Assert-RapSynth (@($sub.Groups|Select-Object Group -Unique).Count -eq 2) 'TEST 41 subgroup identity lost.'
  Assert-RapSynth ($sub.AutomaticSelection -eq $false) 'TEST 42 automatic moderator selection occurred.'

  # 43-48 sensitivity/diagnostics
  $sensitivityMemory=New-RapMemorySynthesisDependencies;$sensitivity=Invoke-RapSensitivityAnalysis $spec $dataset $sensitivityMemory.Dependencies
  Assert-RapSynth (@($sensitivity.Runs).Count -eq 3) 'TEST 43 sensitivity run failed.'
  Assert-RapSynth (@($sensitivity.Runs|Where-Object ParentAnalysisId -ne $spec.AnalysisId).Count -eq 0) 'TEST 44 parent ID missing.'
  Assert-RapSynth (@($sensitivity.Runs|ForEach-Object {$_.ExcludedEffectSizeIds[0]}|Select-Object -Unique).Count -eq 3) 'TEST 45 exclusions not auditable.'
  Assert-RapSynth ($sensitivity.PrimaryOverwritten -eq $false -and $result.Run.PooledEstimate -eq .6) 'TEST 46 primary overwritten.'
  $diagnostic=Get-RapPublicationBiasDiagnostic $dataset
  Assert-RapSynth (@($diagnostic.Points).Count -eq 3) 'TEST 47 diagnostic data missing.'
  Assert-RapSynth ($null -eq $diagnostic.Interpretation -and $diagnostic.ResearcherInterpretationRequired) 'TEST 48 diagnostic interpreted automatically.'

  # 49-52 graph lineage
  Assert-RapSynth (@($result.Run.Lineage|Where-Object EffectSizeNodeId -like 'EFFECT_SIZE:*').Count -eq 3) 'TEST 49 result-effect lineage missing.'
  Assert-RapSynth (@($result.Run.Lineage[0].EvidenceNodeIds|Where-Object {$_ -like 'EVIDENCE-*'}).Count -gt 0) 'TEST 50 effect-evidence trace missing.'
  $derivedMem=New-RapMemorySynthesisDependencies;$derivedResult=Invoke-RapSynthesis $spec $derivedData SYNTH-DERIVED $derivedMem.Dependencies
  Assert-RapSynth ($derivedResult.Run.Lineage[0].DerivedValueNodeId -and @($derivedResult.Run.Lineage[0].StatisticalInputNodeIds).Count -gt 0) 'TEST 51 derived-input trace missing.'
  Assert-RapSynth (@($result.Run.Lineage|Where-Object ProjectId -ne PR001).Count -eq 0) 'TEST 52 project lineage lost.'

  # 53-59 idempotency/persistence/reproducibility
  $before=@($snap2.Runs).Count;$replay=Invoke-RapSynthesis $spec $dataset SYNTH-SQL-1 $sqlite;$after=Get-RapSynthesisFixtureSnapshot $db
  Assert-RapSynth ($replay.Status -eq 'ALREADY_COMPLETED' -and @($after.Runs).Count -eq $before) 'TEST 53 replay not idempotent.'
  Assert-RapSynthThrows {Invoke-RapSynthesis $fixed $dataset SYNTH-SQL-1 $sqlite} 'PAYLOAD_CONFLICT' 'TEST 54 changed payload accepted.'
  Assert-RapSynth (@($after.Specifications|Where-Object ConfigurationHash -eq $spec.ConfigurationHash).Count -eq 1) 'TEST 55 specification reload failed.'
  Assert-RapSynth (@($after.Runs|Where-Object RunId -eq $result.Run.RunId).Count -eq 1) 'TEST 56 result reload failed.'
  Assert-RapSynth (@($after.Runs[0].Lineage[0].EvidenceNodeIds|Where-Object {$_ -like 'EVIDENCE-*'}).Count -gt 0) 'TEST 57 provenance reload failed.'
  $repeatMem=New-RapMemorySynthesisDependencies;$repeat=Invoke-RapSynthesis $spec $dataset SYNTH-REPEAT $repeatMem.Dependencies
  Assert-RapNear $repeat.Run.PooledEstimate $result.Run.PooledEstimate 1e-12 'TEST 58 reproduction mismatch.'
  Assert-RapSynth ($stored.Run.RunId -ne ($snap2.Runs|Where-Object ConfigurationHash -eq $fixed.ConfigurationHash).RunId) 'TEST 59 version run identity collision.'

  # 60-68 ownership/safety
  $human=New-RapSynthesisRecord 'LIB:L000020' ES-HUM .2;$human|Add-Member CriticalAppraisal keep
  Assert-RapSynthThrows {New-RapTestAnalysisDataset $spec @($human)} 'HUMAN_OWNED_FIELD_BLOCKED' 'TEST 60 human field writable.'
  $blank=New-RapSynthesisRecord 'LIB:L000021' ES-BLANK .2;$blank|Add-Member ReviewerMemo ''
  Assert-RapSynthThrows {New-RapTestAnalysisDataset $spec @($blank)} 'HUMAN_OWNED_FIELD_BLOCKED' 'TEST 61 blank human field writable.'
  Assert-RapSynth ($null -eq $result.Run.ScientificInterpretation) 'TEST 62 interpretation authored.'
  $repositoryRoot=[IO.Path]::GetFullPath((Join-Path $root '../../..'));$cfg=Get-Content (Join-Path $repositoryRoot 'src/Local/ResearchAutomation.Local/config/config.json') -Raw|ConvertFrom-Json
  Assert-RapSynth ($cfg.capabilities.ProductionAIProvider -eq $false) 'TEST 63 production AI enabled.'
  Assert-RapSynth ($cfg.capabilities.ProductionNotionWrite -eq $false) 'TEST 64 production Notion enabled.'
  Assert-RapSynth ($cfg.capabilities.ProductionZoteroWrite -eq $false) 'TEST 65 production Zotero enabled.'
  Assert-RapSynth ($cfg.capabilities.ProductionDriveMigration -eq $false) 'TEST 66 production Drive enabled.'
  Assert-RapSynth ($cfg.capabilities.AIReview -eq $false -and $result.ProductionWrite -eq 'DISABLED') 'TEST 67 external test safety failed.'
  Assert-RapSynth ($memory.State.Audits.Count -eq 1 -and $result.ProductionWrite -eq 'DISABLED') 'TEST 68 production changes detected.'
}finally{if(Test-Path $tempRoot){Remove-Item -LiteralPath $tempRoot -Recurse -Force}}

Write-Host "SPR-009 Synthesis focused tests: 68/68 PASS; assertions: $script:Assertions"
