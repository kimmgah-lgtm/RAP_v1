#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'ResearchAutomation.Synthesis.psd1') -Force
. (Join-Path $PSScriptRoot 'TestHarness.ps1')
$script:Assertions=0
$script:NumericalAssertions=0
function Assert-Gate {param([bool]$Condition,[string]$Message)$script:Assertions++;if(!$Condition){throw $Message}}
function Assert-GateThrows {param([scriptblock]$Action,[string]$Pattern,[string]$Message)$script:Assertions++;$actual=$null;try{& $Action}catch{$actual=$_.Exception.Message};if($null -eq $actual -or $actual -notmatch $Pattern){throw "$Message Actual=$actual"}}
function Assert-GateNear {param([double]$Actual,[double]$Expected,[double]$Tolerance,[string]$Message)$script:Assertions++;$script:NumericalAssertions++;if([Math]::Abs($Actual-$Expected) -gt $Tolerance){throw "$Message Actual=$Actual Expected=$Expected Tolerance=$Tolerance"}}

$spec=New-RapAnalysisSpecification -AnalysisId AN-GATE -ProjectId PR001 -Model RANDOM -Estimator DL
$derived=Get-RapHedgesG -MeanTreatment 12 -MeanControl 10 -SdTreatment 4 -SdControl 4 -NTreatment 50 -NControl 50
$validDerived=New-RapSynthesisRecord 'LIB:L000101' ES-GD $derived.EffectValue $derived.Variance -EffectOrigin DERIVED_EFFECT -StatisticalInputs $derived.SourceInputs -Transformation ([pscustomobject]@{Method=$derived.Method;Version=$derived.FormulaVersion})
$derivedGraph=New-RapSynthesisGraphHarness @($validDerived)
$missingInputs=$validDerived.PSObject.Copy();$missingInputs.StatisticalInputs=$null
Assert-GateThrows {New-RapAnalysisDataset $spec @($missingInputs) $derivedGraph.Dependencies} 'DERIVED_EFFECT_SOURCE_INPUTS_REQUIRED' 'GATE A missing derived inputs admitted.'
$missingTransformation=$validDerived.PSObject.Copy();$missingTransformation.Transformation=$null
Assert-GateThrows {New-RapAnalysisDataset $spec @($missingTransformation) $derivedGraph.Dependencies} 'DERIVED_EFFECT_TRANSFORMATION_REQUIRED' 'GATE B missing transformation admitted.'
$validDerivedData=New-RapAnalysisDataset $spec @($validDerived) $derivedGraph.Dependencies
Assert-Gate ($validDerivedData.Rows[0].Transformation.Version -eq '1.0' -and $validDerivedData.Rows[0].StatisticalInputs.NTreatment -eq 50) 'GATE C valid derivation provenance lost.'

$missingModerator=New-RapSynthesisRecord 'LIB:L000102' ES-GM .2
$modSpec=New-RapAnalysisSpecification -AnalysisId AN-GATEMOD -ProjectId PR001 -Model FIXED -Estimator NONE -ModeratorSelection Region
$missingModeratorData=New-RapTestAnalysisDataset $modSpec @($missingModerator)
Assert-GateThrows {Invoke-RapSubgroupAnalysis $modSpec $missingModeratorData Region} 'MISSING_MODERATOR_VALUE' 'GATE D empty moderator subgroup created.'
Assert-Gate ($null -eq $missingModeratorData.Rows[0].Moderator) 'GATE E missing moderator state changed.'

$dependent=@(New-RapSynthesisRecord 'LIB:L000103' ES-GR1 .1 -DependencyGroupId STUDY-GATE;New-RapSynthesisRecord 'LIB:L000103' ES-GR2 .9 -DependencyGroupId STUDY-GATE)
$rveSpec=New-RapAnalysisSpecification -AnalysisId AN-GATER -ProjectId PR001 -Model RANDOM -Estimator DL -DependencyStrategy RVE
$rveData=New-RapTestAnalysisDataset $rveSpec $dependent;$rveMemory=New-RapMemorySynthesisDependencies
Assert-GateThrows {Invoke-RapSynthesis $rveSpec $rveData GATE-RVE $rveMemory.Dependencies} 'UNSUPPORTED_DEPENDENCY_STRATEGY' 'GATE F RVE silently fell back.'
$noDependencySpec=New-RapAnalysisSpecification -AnalysisId AN-GATENONE -ProjectId PR001 -Model RANDOM -Estimator DL
Assert-GateThrows {New-RapTestAnalysisDataset $noDependencySpec $dependent} 'DEPENDENCY_STRATEGY_REQUIRED' 'GATE G dependent effects admitted without strategy.'
$independent=New-RapBasicSynthesisFixture;$independentData=New-RapTestAnalysisDataset $spec $independent;$independentMemory=New-RapMemorySynthesisDependencies;$independentResult=Invoke-RapSynthesis $spec $independentData GATE-INDEPENDENT $independentMemory.Dependencies
Assert-Gate ($independentResult.Status -eq 'COMPLETED' -and [Math]::Abs($independentResult.Run.PooledEstimate-.6) -le 1e-12) 'GATE H independent synthesis regressed.'
Assert-GateNear $derived.EffectValue .4961636828644501 1e-12 'Numerical Hedges g regression.'
Assert-GateNear $derived.Variance .04125601224588579 1e-12 'Numerical Hedges variance regression.'
Assert-GateNear $derived.StandardError .20311576070282136 1e-12 'Numerical Hedges SE regression.'
$fixedSpec=New-RapAnalysisSpecification -AnalysisId AN-GATEFIXED -ProjectId PR001 -Model FIXED -Estimator NONE;$fixedData=New-RapTestAnalysisDataset $fixedSpec $independent;$fixedMemory=New-RapMemorySynthesisDependencies;$fixedRun=(Invoke-RapSynthesis $fixedSpec $fixedData GATE-FIXED $fixedMemory.Dependencies).Run
Assert-GateNear $fixedRun.PooledEstimate .6 1e-12 'Numerical fixed pooled estimate regression.'
Assert-GateNear $fixedRun.StandardError .11547005383792516 1e-12 'Numerical fixed SE regression.'
Assert-GateNear $fixedRun.ConfidenceLow .37367869447766666 1e-12 'Numerical fixed CI regression.'

$tempRoot=Join-Path ([IO.Path]::GetTempPath()) "rap-synth-gate-$PID-$([guid]::NewGuid().ToString('N'))";[void][IO.Directory]::CreateDirectory($tempRoot)
try{
    $db=Join-Path $tempRoot 'sensitivity.db';$sqlite=New-RapSynthesisSqliteDependencies $db;$null=Invoke-RapSynthesis $spec $independentData GATE-PRIMARY $sqlite;$sensitivity=Invoke-RapSensitivityAnalysis $spec $independentData $sqlite GATE-SENSITIVITY;$snapshot=Get-RapSynthesisFixtureSnapshot $db
    Assert-Gate (@($sensitivity.Runs|Where-Object AnalysisId -eq $spec.AnalysisId).Count -eq 0) 'GATE I child AnalysisId not distinct.'
    Assert-Gate (@($sensitivity.Runs|Where-Object ParentAnalysisId -ne $spec.AnalysisId).Count -eq 0) 'GATE J parent AnalysisId missing.'
    Assert-Gate (@($sensitivity.Runs|Where-Object {-not $_.InputDatasetHash -or -not $_.ConfigurationHash}).Count -eq 0) 'GATE K sensitivity hashes missing.'
    Assert-Gate (@($sensitivity.Runs|Where-Object {$_.EngineVersion -ne $spec.EngineVersion -or @($_.Provenance).Count -eq 0}).Count -eq 0) 'GATE L sensitivity version/provenance missing.'
    $runCountBefore=@($snapshot.Runs).Count;$replay=Invoke-RapSensitivityAnalysis $spec $independentData $sqlite GATE-SENSITIVITY;$runCountAfter=@((Get-RapSynthesisFixtureSnapshot $db).Runs).Count
    Assert-Gate ($replay.PayloadHash -eq $sensitivity.PayloadHash -and $runCountAfter -eq $runCountBefore) 'GATE X sensitivity replay duplicated state.'
    $changedRecords=New-RapBasicSynthesisFixture;$changedRecords[0].EffectValue=.11;$changedDataset=New-RapTestAnalysisDataset $spec $changedRecords
    Assert-GateThrows {Invoke-RapSensitivityAnalysis $spec $changedDataset $sqlite GATE-SENSITIVITY} 'PAYLOAD_CONFLICT' 'GATE Y sensitivity payload conflict not blocked.'
    $restartDb=Join-Path $tempRoot 'restart.db';$script=Join-Path $PSScriptRoot 'SensitivityRecoveryProcess.ps1';$writer=& pwsh -NoProfile -File $script -Mode Write -DatabasePath $restartDb;if($LASTEXITCODE -ne 0){throw 'Sensitivity recovery writer failed.'};$reader=& pwsh -NoProfile -File $script -Mode Read -DatabasePath $restartDb;if($LASTEXITCODE -ne 0){throw 'Sensitivity recovery reader failed.'};$reloaded=($reader -join "`n")|ConvertFrom-Json -Depth 60
    Assert-Gate (@($reloaded.Children).Count -eq 3 -and @($reloaded.Children|Where-Object ParentAnalysisId -ne 'AN-RECOVERY').Count -eq 0) 'GATE M restart did not recover parent-child runs.'
}finally{if(Test-Path $tempRoot){Remove-Item -LiteralPath $tempRoot -Recurse -Force}}

Assert-Gate (@($independentResult.Run.Lineage|Where-Object {-not $_.PaperNodeId -or -not $_.AnalysisDatasetNodeId -or -not $_.EffectSizeNodeId}).Count -eq 0) 'GATE N complete lineage missing.'
$one=New-RapSynthesisRecord 'LIB:L000104' ES-GL .3;$brokenEffectGraph=New-RapSynthesisGraphHarness @($one);$edgeToRemove=$brokenEffectGraph.State.Edges.Values|Where-Object RelationType -eq 'HAS_EFFECT_SIZE'|Select-Object -First 1;[void]$brokenEffectGraph.State.Edges.Remove($edgeToRemove.EdgeId)
Assert-GateThrows {New-RapAnalysisDataset $spec @($one) $brokenEffectGraph.Dependencies} 'BROKEN_ANALYSIS_EFFECT_PAPER_LINEAGE' 'GATE O broken analysis-effect lineage admitted.'
$brokenPaperGraph=New-RapSynthesisGraphHarness @($one);[void]$brokenPaperGraph.State.Nodes.Remove("PAPER:$($one.LibraryId)")
Assert-GateThrows {New-RapAnalysisDataset $spec @($one) $brokenPaperGraph.Dependencies} 'BROKEN_ANALYSIS_EFFECT_PAPER_LINEAGE' 'GATE P broken paper lineage admitted.'
Assert-Gate ($validDerivedData.Lineage[0].DerivedValueNodeId -like 'DERIVED_VALUE:*' -and @($validDerivedData.Lineage[0].StatisticalInputNodeIds).Count -eq 6) 'GATE Q derived transformation lineage missing.'

Assert-GateThrows {New-RapAnalysisSpecification -AnalysisId AN-NOMODEL -ProjectId PR001 -Estimator DL} 'ANALYSIS_MODEL_REQUIRED' 'GATE R missing model defaulted.'
Assert-GateThrows {New-RapAnalysisSpecification -AnalysisId AN-NOEST -ProjectId PR001 -Model RANDOM} 'ANALYSIS_ESTIMATOR_REQUIRED' 'GATE S missing estimator defaulted.'
$explicit=New-RapAnalysisSpecification -AnalysisId AN-EXPLICIT -ProjectId PR001 -Model RANDOM -Estimator DL
Assert-Gate ($explicit.Ownership -eq 'RESEARCHER_SPECIFIED' -and $explicit.Model -eq 'RANDOM' -and $explicit.Estimator -eq 'DL') 'GATE T explicit decision not retained.'
$human=$one.PSObject.Copy();$human|Add-Member ReviewerMemo '';$humanGraph=New-RapSynthesisGraphHarness @($one)
Assert-GateThrows {New-RapAnalysisDataset $spec @($human) $humanGraph.Dependencies} 'HUMAN_OWNED_FIELD_BLOCKED' 'GATE U HUMAN_OWNED regression.'
$otherProject=New-RapSynthesisRecord 'LIB:L000105' ES-GP .2 -ProjectId PR002;$otherGraph=New-RapSynthesisGraphHarness @($otherProject)
Assert-GateThrows {New-RapAnalysisDataset $spec @($otherProject) $otherGraph.Dependencies} 'PROJECT_SCOPE_MISMATCH' 'GATE V cross-project record admitted.'
$repositoryRoot=[IO.Path]::GetFullPath((Join-Path $root '../../..'));$cfg=Get-Content (Join-Path $repositoryRoot 'src/Local/ResearchAutomation.Local/config/config.json') -Raw|ConvertFrom-Json
Assert-Gate (-not $cfg.capabilities.ProductionAIProvider -and -not $cfg.capabilities.ProductionNotionWrite -and -not $cfg.capabilities.ProductionZoteroWrite -and -not $cfg.capabilities.ProductionDriveMigration -and -not $cfg.capabilities.SynthesisProductionWrite -and $independentResult.ProductionWrite -eq 'DISABLED') 'GATE W production safety regression.'

Write-Host "SPR-009 Gate remediation tests: 25/25 PASS; assertions: $script:Assertions; numerical assertions: $script:NumericalAssertions"
