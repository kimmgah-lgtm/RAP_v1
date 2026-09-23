#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'ResearchAutomation.MetaCoding.psd1') -Force
. (Join-Path $PSScriptRoot 'TestHarness.ps1')

$script:Assertions=0
function Assert-RapMetaTest {param([bool]$Condition,[string]$Message)$script:Assertions++;if(-not $Condition){throw $Message}}
function Assert-RapThrows {param([scriptblock]$Action,[string]$Pattern,[string]$Message)$script:Assertions++;$caught=$null;try{& $Action}catch{$caught=$_.Exception.Message};if($null -eq $caught -or $caught -notmatch $Pattern){throw "$Message Actual=$caught"}}
function Copy-RapFixture {param($Value)($Value|ConvertTo-Json -Depth 50)|ConvertFrom-Json -Depth 50}
function New-RapBlockedHarness {param([string]$Field,$Value)$h=New-RapMetaCodingTestHarness;$output=Copy-RapFixture $h.DefaultOutput;$output|Add-Member -NotePropertyName $Field -NotePropertyValue $Value -Force;$h.Dependencies.ExtractAssistedCoding={$output}.GetNewClosure();$h}

$source=[pscustomobject]@{ReviewId='REVIEW-1';ReviewVersion='v1';TextHash='abc'}
$h=New-RapMetaCodingTestHarness
$request=New-RapMetaCodingRequest -LibraryId 'LIB:L000001' -ProjectId PR001 -SourceEvidence $source
$request2=New-RapMetaCodingRequest -LibraryId 'LIB:L000001' -ProjectId PR002 -SourceEvidence $source
$h.State.Codings[$request.ScopeKey]=[pscustomobject]@{LibraryId='LIB:L000001';ProjectId='PR001';ScopeKey=$request.ScopeKey;SchemaVersion='old';AiAssisted=[pscustomobject]@{};ResearcherConfirmed=[pscustomobject]@{ResearcherMemo='keep me';CriticalAppraisal='human appraisal';ReviewerInterpretation='human interpretation';ReviewerMemo=''};Ownership=[pscustomobject]@{}}
$first=Invoke-RapMetaCoding -Request $request -Dependencies $h.Dependencies -Mode Fixture
$second=Invoke-RapMetaCoding -Request $request2 -Dependencies $h.Dependencies -Mode Fixture

# TEST 01-04: identity and project/Common Review boundaries
Assert-RapMetaTest ($first.ScopeKey -ne $second.ScopeKey -and $h.State.Codings.Count -eq 2) 'TEST 01 independent project coding failed.'
$sameContext=New-RapMetaCodingRequest -LibraryId 'LIB:L000001' -ProjectId PR001 -SourceEvidence $source
Assert-RapMetaTest ($sameContext.ScopeKey -eq $request.ScopeKey -and $sameContext.OperationId -eq $request.OperationId) 'TEST 02 same project context resolution failed.'
Assert-RapMetaTest ($first.Record.LibraryId -eq 'LIB:L000001' -and $null -eq $first.Record.PSObject.Properties['GlobalCanonicalMutation']) 'TEST 03 canonical paper identity was mutated.'
$common=New-RapBlockedHarness 'CommonReviewUpdates' ([pscustomobject]@{ProjectOutcome='forbidden'})
Assert-RapThrows {Invoke-RapMetaCoding -Request $request -Dependencies $common.Dependencies -Mode Fixture} 'COMMON_REVIEW_FIELD_BLOCKED' 'TEST 04 Common Review firewall failed.'

# TEST 05-10: multiple records and dependency identity
Assert-RapMetaTest (@($first.Record.AiAssisted.Outcomes).Count -eq 2) 'TEST 05 multiple outcomes failed.'
Assert-RapMetaTest (@($first.Record.AiAssisted.Comparisons).Count -eq 2) 'TEST 06 multiple comparisons failed.'
Assert-RapMetaTest (@($first.Record.AiAssisted.TimePoints|Select-Object -ExpandProperty TimePointId -Unique).Count -eq 2) 'TEST 07 multiple time points collided.'
Assert-RapMetaTest (@($first.Record.AiAssisted.EffectSizes|Select-Object -ExpandProperty EffectSizeId -Unique).Count -eq 2) 'TEST 08 multiple effect identities failed.'
Assert-RapMetaTest (@($first.Record.AiAssisted.EffectSizes[0].StudyArmIds).Count -eq 2 -and $first.Record.AiAssisted.StudyArms[0].StudyArmId -eq 'ARM-I') 'TEST 09 study-arm identity failed.'
Assert-RapMetaTest ($first.Record.AiAssisted.EffectSizes[0].DependencyGroupId -eq 'STUDY-1' -and $first.Record.AiAssisted.EffectSizes[1].DependencyGroupId -eq 'STUDY-1') 'TEST 10 dependency identity was flattened.'

# TEST 11-16: effect/statistical evidence
Assert-RapMetaTest ($first.Record.AiAssisted.EffectSizes[0].EffectSizeType -eq 'Hedges_g' -and $first.Record.AiAssisted.EffectSizes[1].EffectSizeType -eq 'Cohens_d') 'TEST 11 effect-size type failed.'
Assert-RapMetaTest ($first.Record.AiAssisted.EffectSizes[0].EffectValue.Value -eq .42 -and @($first.Record.AiAssisted.EffectSizes[0].StatisticalInputIds).Count -eq 4) 'TEST 12 effect/statistical linkage failed.'
Assert-RapMetaTest ($first.Record.AiAssisted.SampleSizes[0].TotalN.Value -eq 80 -and $first.Record.AiAssisted.SampleSizes[0].AnalyticN.Value -eq 38) 'TEST 13 sample size failed.'
Assert-RapMetaTest ($first.Record.AiAssisted.SampleSizes[1].TotalN.EvidenceStatus -eq 'NOT_REPORTED' -and $null -eq $first.Record.AiAssisted.SampleSizes[1].TotalN.Value) 'TEST 14 missing N was fabricated.'
Assert-RapMetaTest (($first.Record.AiAssisted.StatisticalInputs|Where-Object InputId -eq 'STAT-CONFLICT').Value.EvidenceStatus -eq 'CONFLICTING_EVIDENCE') 'TEST 15 conflicting evidence failed.'
Assert-RapMetaTest (($first.Record.AiAssisted.StatisticalInputs|Where-Object InputId -eq 'STAT-UNCLEAR').Value.EvidenceStatus -eq 'UNCERTAIN') 'TEST 16 uncertainty failed.'

# TEST 17-21: ownership
Assert-RapMetaTest ($first.Record.AiAssisted.CodingStatus -eq 'AI_ASSISTED' -and $null -ne $first.Record.ResearcherConfirmed) 'TEST 17 coding ownership distinction failed.'
$noHuman=New-RapMetaCodingTestHarness;$noHumanResult=Invoke-RapMetaCoding -Request $request -Dependencies $noHuman.Dependencies -Mode Fixture
Assert-RapMetaTest ($noHumanResult.Record.AiAssisted.CodingStatus -eq 'AI_ASSISTED' -and $null -eq $noHumanResult.Record.ResearcherConfirmed) 'TEST 18 AI silently confirmed coding.'
Assert-RapMetaTest ($first.Record.ResearcherConfirmed.ResearcherMemo -eq 'keep me') 'TEST 19 researcher value was overwritten.'
Assert-RapMetaTest ($first.Record.ResearcherConfirmed.CriticalAppraisal -eq 'human appraisal' -and $first.Record.ResearcherConfirmed.ReviewerInterpretation -eq 'human interpretation') 'TEST 20 existing HUMAN_OWNED fields were overwritten.'
$blankHuman=New-RapBlockedHarness 'ReviewerMemo' ''
Assert-RapThrows {Invoke-RapMetaCoding -Request $request -Dependencies $blankHuman.Dependencies -Mode Fixture} 'HUMAN_OWNED_FIELD_BLOCKED' 'TEST 21 blank HUMAN_OWNED field was treated as writable.'

# TEST 22-27: researcher-judgment firewall
foreach($case in @(
    [pscustomobject]@{Number=22;Field='EffectSizeInclusion'},
    [pscustomobject]@{Number=23;Field='OutcomeSelection'},
    [pscustomobject]@{Number=24;Field='ComparisonSelection'},
    [pscustomobject]@{Number=25;Field='DependencyHandling'},
    [pscustomobject]@{Number=26;Field='StudyExclusion'},
    [pscustomobject]@{Number=27;Field='StatisticalTransformationDecision'}
)){
    $blocked=New-RapBlockedHarness $case.Field $true
    Assert-RapThrows {Invoke-RapMetaCoding -Request $request -Dependencies $blocked.Dependencies -Mode Fixture} 'HUMAN_OWNED_FIELD_BLOCKED' "TEST $($case.Number) judgment firewall failed for $($case.Field)."
}

# TEST 28-30: provenance and derivation
$effect=$first.Record.AiAssisted.EffectSizes[0]
Assert-RapMetaTest ($effect.EffectValue.SourceReference -eq 'fixture:table-2' -and $effect.EffectValue.EvidenceLocation -eq 'p. 12' -and $effect.EffectValue.ExtractionMethod -eq 'DETERMINISTIC_MOCK') 'TEST 28 quantitative provenance failed.'
Assert-RapMetaTest ($effect.Derivation.IsDerived -eq $true -and $first.Record.AiAssisted.EffectSizes[1].Derivation.IsDerived -eq $false) 'TEST 29 derived/direct distinction failed.'
Assert-RapMetaTest ($effect.Derivation.TransformationMethod -eq 'SMD_TO_HEDGES_G' -and $effect.Derivation.FormulaVersion -eq '1.0' -and @($effect.Derivation.SourceValueReferences).Count -eq 4) 'TEST 30 transformation provenance failed.'

# TEST 31-33: idempotency and conflict
$extractCalls=$h.State.ExtractCalls;$upsertCalls=$h.State.UpsertCalls;$replay=Invoke-RapMetaCoding -Request $request -Dependencies $h.Dependencies -Mode Fixture
Assert-RapMetaTest ($replay.Status -eq 'ALREADY_COMPLETED' -and $h.State.ExtractCalls -eq $extractCalls -and $h.State.UpsertCalls -eq $upsertCalls) 'TEST 31 idempotent replay failed.'
$conflict=New-RapMetaCodingTestHarness;$fixed='META-fixed-operation';$one=New-RapMetaCodingRequest -LibraryId 'LIB:L000001' -ProjectId PR001 -SourceEvidence ([pscustomobject]@{A=1}) -OperationId $fixed;[void](Invoke-RapMetaCoding -Request $one -Dependencies $conflict.Dependencies -Mode Fixture);$two=New-RapMetaCodingRequest -LibraryId 'LIB:L000001' -ProjectId PR001 -SourceEvidence ([pscustomobject]@{A=2}) -OperationId $fixed
Assert-RapThrows {Invoke-RapMetaCoding -Request $two -Dependencies $conflict.Dependencies -Mode Fixture} 'PAYLOAD_CONFLICT' 'TEST 32 payload conflict failed.'
Assert-RapMetaTest (@($h.State.Codings[$request.ScopeKey].AiAssisted.EffectSizes|Select-Object -ExpandProperty EffectSizeId -Unique).Count -eq 2) 'TEST 33 replay duplicated effect-size records.'

# TEST 34-37: SQLite persistence and independent restart recovery
$tempRoot=Join-Path ([IO.Path]::GetTempPath()) ("rap-meta-$PID-$([guid]::NewGuid().ToString('N'))");[void][IO.Directory]::CreateDirectory($tempRoot)
try{
    $database=Join-Path $tempRoot 'meta.db';Register-RapMetaCodingProjectFixture -DatabasePath $database -ProjectId PR001 -LibraryId 'LIB:L000001'|Out-Null
    $fixture=New-RapMetaCodingFixtureOutput;$sqliteDeps=New-RapMetaCodingSqliteDependencies -DatabasePath $database -ExtractAssistedCoding ({$fixture}.GetNewClosure())
    $persistRequest=New-RapMetaCodingRequest -LibraryId 'LIB:L000001' -ProjectId PR001 -SourceEvidence ([pscustomobject]@{Fixture='persistence'})
    [void](Invoke-RapMetaCoding -Request $persistRequest -Dependencies $sqliteDeps -Mode Fixture)
    $reloadedDeps=New-RapMetaCodingSqliteDependencies -DatabasePath $database -ExtractAssistedCoding {throw 'RELOAD_MUST_NOT_EXTRACT'}
    $reloaded=Get-RapMetaCodingFixtureRecord -DatabasePath $database -LibraryId 'LIB:L000001' -ProjectId PR001
    Assert-RapMetaTest ($reloaded.ScopeKey -eq 'LIB:L000001|PR001' -and @($reloaded.AiAssisted.EffectSizes).Count -eq 2) 'TEST 34 project coding did not survive reload.'
    [void](Confirm-RapMetaCoding -LibraryId 'LIB:L000001' -ProjectId PR001 -ConfirmedValues ([pscustomobject]@{EffectSizeInclusion=[pscustomobject]@{'ES-1'=$true}}) -Dependencies $reloadedDeps)
    $confirmedReload=Get-RapMetaCodingFixtureRecord -DatabasePath $database -LibraryId 'LIB:L000001' -ProjectId PR001
    Assert-RapMetaTest ($confirmedReload.ResearcherConfirmed.EffectSizeInclusion.'ES-1' -eq $true) 'TEST 35 confirmation did not survive reload.'
    Assert-RapMetaTest ($confirmedReload.AiAssisted.EffectSizes[0].EffectValue.SourceReference -eq 'fixture:table-2' -and $confirmedReload.AiAssisted.EffectSizes[0].Derivation.FormulaVersion -eq '1.0') 'TEST 36 provenance did not survive reload.'
    $recoveryDb=Join-Path $tempRoot 'recovery.db';$powerShell=(Get-Process -Id $PID).Path;$recoveryScript=Join-Path $PSScriptRoot 'RecoveryProcess.ps1'
    $processA=& $powerShell -NoProfile -File $recoveryScript -Phase Prepare -DatabasePath $recoveryDb;if($LASTEXITCODE -ne 0){throw 'Independent Process A failed.'}
    $processB=& $powerShell -NoProfile -File $recoveryScript -Phase Resume -DatabasePath $recoveryDb;if($LASTEXITCODE -ne 0){throw 'Independent Process B failed.'}
    Assert-RapMetaTest (($processA -contains 'PROCESS_A_PATCH_PREPARED') -and ($processB -contains 'PROCESS_B_RECOVERED_WITHOUT_REEXTRACTION')) 'TEST 37 independent Process B recovery failed.'
}finally{
    if(Test-Path -LiteralPath $tempRoot){Remove-Item -LiteralPath $tempRoot -Recurse -Force}
}

# TEST 38-42: production safety and zero external changes
$repositoryRoot=[IO.Path]::GetFullPath((Join-Path $root '../../..'));$configuration=Get-Content -LiteralPath (Join-Path $repositoryRoot 'src/Local/ResearchAutomation.Local/config/config.json') -Raw|ConvertFrom-Json
Assert-RapMetaTest ($configuration.capabilities.ProductionNotionWrite -eq $false) 'TEST 38 Production Notion Write is enabled.'
Assert-RapMetaTest ($configuration.capabilities.ProductionZoteroWrite -eq $false) 'TEST 39 Production Zotero Write is enabled.'
Assert-RapMetaTest ($configuration.capabilities.ProductionDriveMigration -eq $false) 'TEST 40 Production Drive Migration is enabled.'
Assert-RapMetaTest ($configuration.capabilities.ProductionAIProvider -eq $false -and $configuration.capabilities.AIReview -eq $false) 'TEST 41 external AI Provider is enabled.'
Assert-RapMetaTest ($h.State.ProductionWrites -eq 0 -and $h.State.CommonReviewWrites -eq 0 -and $first.ProductionWrite -eq 'DISABLED') 'TEST 42 fixture caused production changes.'

Write-Host "SPR-007 Meta Coding focused tests: 42/42 PASS; assertions: $script:Assertions"
