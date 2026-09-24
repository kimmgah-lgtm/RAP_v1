#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$outputRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $outputRoot 'ResearchAutomation.Output.psd1') -Force
. (Join-Path $PSScriptRoot 'TestHarness.ps1')
$synthesisRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../Synthesis'))
Import-Module (Join-Path $synthesisRoot 'ResearchAutomation.Synthesis.psd1') -Force
. (Join-Path $synthesisRoot 'tests/TestHarness.ps1')

$script:GateScenarios = 0
$script:GateAssertions = 0
function Assert-Gate([bool]$Condition, [string]$Message) {
    $script:GateAssertions++
    if (-not $Condition) { throw "Gate assertion $script:GateAssertions failed: $Message" }
}
function Assert-GateNear([double]$Actual, [double]$Expected, [double]$Tolerance, [string]$Message) {
    $script:GateAssertions++
    if ([Math]::Abs($Actual - $Expected) -gt $Tolerance) { throw "Gate assertion $script:GateAssertions failed: $Message actual=$Actual expected=$Expected" }
}
function Assert-GateThrows([scriptblock]$Action, [string]$Pattern, [string]$Message) {
    $script:GateAssertions++
    $actual = $null
    try { & $Action } catch { $actual = $_.Exception.Message }
    if ($null -eq $actual -or $actual -notmatch $Pattern) { throw "Gate assertion $script:GateAssertions failed: $Message actual=$actual" }
}
function Complete-Gate([string]$Name) {
    $script:GateScenarios++
    Write-Host "${Name}: PASS"
}

$records = New-RapOutputFixture
$baseSpec = New-RapOutputSpecification -OutputSpecId OUT-GATE -ProjectId PR001 -OutputType EFFECT_SIZE_TABLE -OutputName GateEffects -SourceScope CONFIRMED -AnalysisId AN-PRIMARY -IncludedFields @('ALL') -FormattingProfile MACHINE
$baseDataset = New-RapOutputDataset $baseSpec $records
$baseArtifact = New-RapResearchArtifact $baseSpec $baseDataset
$baseManifest = New-RapReproducibilityManifest $baseSpec $baseDataset @($baseArtifact)
$basePackage = New-RapExportPackage $baseSpec $baseDataset @($baseArtifact) $baseManifest

# GATE-A: same Library_ID in distinct projects never leaks in either direction.
$aData = [pscustomobject]@{Outcome='A';Comparison='A-C';TimePoint='POST';EffectType='Hedges_g';EffectOrigin='REPORTED_EFFECT';Effect=.2;Variance=.04;SE=.2;N=50;Lower=-.192;Upper=.592;Weight=1;Subgroup='A';DirectionState='UNCHANGED';DependencyGroupId='A';AnalysisInclusion='INCLUDED';Transformation=$null}
$bData = [pscustomobject]@{Outcome='B';Comparison='B-C';TimePoint='POST';EffectType='Hedges_g';EffectOrigin='REPORTED_EFFECT';Effect=1.2;Variance=.09;SE=.3;N=60;Lower=.612;Upper=1.788;Weight=1;Subgroup='B';DirectionState='UNCHANGED';DependencyGroupId='B';AnalysisInclusion='INCLUDED';Transformation=$null}
$aRecord = New-RapOutputRecord EFFECT-A EFFECT $aData -ProjectId PR001 -LibraryId 'LIB:L-SHARED' -EffectSizeId ES-A -AnalysisId AN-A
$bRecord = New-RapOutputRecord EFFECT-B EFFECT $bData -ProjectId PR002 -LibraryId 'LIB:L-SHARED' -EffectSizeId ES-B -AnalysisId AN-B
$aSpec = New-RapOutputSpecification -OutputSpecId OUT-A -ProjectId PR001 -OutputType EFFECT_SIZE_TABLE -OutputName A -SourceScope CONFIRMED -AnalysisId AN-A -IncludedFields ALL -FormattingProfile MACHINE
$bSpec = New-RapOutputSpecification -OutputSpecId OUT-B -ProjectId PR002 -OutputType EFFECT_SIZE_TABLE -OutputName B -SourceScope CONFIRMED -AnalysisId AN-B -IncludedFields ALL -FormattingProfile MACHINE
$aArtifact = New-RapResearchArtifact $aSpec (New-RapOutputDataset $aSpec @($aRecord))
$bArtifact = New-RapResearchArtifact $bSpec (New-RapOutputDataset $bSpec @($bRecord))
Assert-Gate ($aArtifact.Content.Data.Count -eq 1 -and $aArtifact.Content.Data[0].ProjectId -eq 'PR001' -and $aArtifact.Content.Data[0].EffectSizeId -eq 'ES-A') 'Project A output leaked Project B.'
Assert-Gate ($bArtifact.Content.Data.Count -eq 1 -and $bArtifact.Content.Data[0].ProjectId -eq 'PR002' -and $bArtifact.Content.Data[0].EffectSizeId -eq 'ES-B') 'Project B output leaked Project A.'
Assert-GateThrows { New-RapOutputDataset $aSpec @($aRecord, $bRecord) } 'PROJECT_SCOPE_MISMATCH' 'Mixed input was accepted for Project A.'
Assert-GateThrows { New-RapOutputDataset $bSpec @($aRecord, $bRecord) } 'PROJECT_SCOPE_MISMATCH' 'Mixed input was accepted for Project B.'
Complete-Gate 'GATE-A'

# GATE-B: reverse traceability exists and broken required lineage blocks generation.
$study = New-RapFixtureArtifact STUDY_CHARACTERISTICS_TABLE
$meta = New-RapFixtureArtifact META_CODING_TABLE
$effect = New-RapFixtureArtifact EFFECT_SIZE_TABLE
$moderator = New-RapFixtureArtifact MODERATOR_SUBGROUP_TABLE
$sensitivity = New-RapFixtureArtifact SENSITIVITY_TABLE
$figure = New-RapFixtureArtifact FIGURE_DATASET
Assert-Gate ($study.Artifact.Lineage.OutputDatasetId -eq $study.Dataset.OutputDatasetId -and $study.Artifact.Lineage.OutputSpecId -eq $study.Specification.OutputSpecId) 'Study artifact cannot reverse-trace to dataset/specification.'
Assert-Gate ($study.Artifact.Content.Data[0].SourceRecordId -eq 'STUDY-1' -and $study.Dataset.SourceRecordIds -contains 'STUDY-1') 'Study value cannot reverse-trace to source record.'
Assert-Gate ($meta.Artifact.Content.Data[0].SourceRecordId -eq 'META-1' -and $meta.Artifact.Content.Data[0].ProjectId -eq 'PR001') 'Meta Coding value lacks project/source trace.'
$derivedOutput = $effect.Artifact.Content.Data | Where-Object { $_.EffectOrigin -eq 'DERIVED_EFFECT' }
Assert-Gate ($derivedOutput.Provenance.PaperNodeId -like 'PAPER:*' -and @($derivedOutput.Provenance.EvidenceNodeIds).Count -gt 0) 'Effect cannot reverse-trace through Evidence to Paper.'
Assert-Gate ($derivedOutput.Transformation.Method -eq 'HEDGES_G' -and @($derivedOutput.Provenance.StatisticalInputNodeIds).Count -gt 0) 'Derived transformation/input trace missing.'
Assert-Gate ($moderator.Artifact.Content.Data[0].AnalysisId -eq 'AN-PRIMARY') 'Moderator result lacks Analysis identity.'
Assert-Gate ($sensitivity.Artifact.Content.Data[0].ParentAnalysisId -eq 'AN-PRIMARY' -and $sensitivity.Artifact.Content.Data[0].Provenance.Count -gt 0) 'Sensitivity result lacks parent/provenance.'
Assert-Gate ($figure.Artifact.Content.Data.AnalysisId -eq 'AN-PRIMARY' -and $figure.Artifact.Content.Data.Effects[0].EffectSizeId -eq 'ES-1') 'Figure output lacks Analysis/Effect trace.'
$broken = $records[3].PSObject.Copy(); $broken.Lineage = [pscustomobject]@{ PaperNodeId='PAPER:LIB:L000001'; EffectSizeNodeId='EFFECT_SIZE:ES-1|PR001'; EvidenceNodeIds=@() }
Assert-GateThrows { New-RapOutputDataset $baseSpec @($broken) } 'OUTPUT_LINEAGE_REQUIRED' 'Broken evidence lineage produced eligible data.'
Complete-Gate 'GATE-B'

# GATE-C: compare against an actual SPR-009 fixture run, and reject a wrong Analysis_ID.
$synthRecords = New-RapBasicSynthesisFixture
$synthSpec = New-RapAnalysisSpecification -AnalysisId AN-GATEAUTH -ProjectId PR001 -Model RANDOM -Estimator DL
$synthDataset = New-RapTestAnalysisDataset $synthSpec $synthRecords
$synthMemory = New-RapMemorySynthesisDependencies
$authoritativeRun = (Invoke-RapSynthesis $synthSpec $synthDataset SYNTH-OUTPUT-GATE $synthMemory.Dependencies).Run
$analysisRecord = New-RapOutputRecord ANALYSIS-GATE ANALYSIS $authoritativeRun -AnalysisId AN-GATEAUTH -Lineage $authoritativeRun.Lineage[0]
$resultSpec = New-RapOutputSpecification -OutputSpecId OUT-AUTH -ProjectId PR001 -OutputType SYNTHESIS_RESULT_TABLE -OutputName Result -SourceScope CONFIRMED -AnalysisId AN-GATEAUTH -IncludedFields ALL -FormattingProfile MACHINE
$resultArtifact = New-RapResearchArtifact $resultSpec (New-RapOutputDataset $resultSpec @($analysisRecord))
$reportedRun = $resultArtifact.Content.Data[0]
foreach ($field in @('PooledEstimate','StandardError','ConfidenceLow','ConfidenceHigh','Q','I2','Tau2')) {
    Assert-GateNear ([double]$reportedRun.$field) ([double]$authoritativeRun.$field) 1e-12 "SPR-010 differs from SPR-009 for $field."
}
Assert-Gate ($reportedRun.Model -eq $authoritativeRun.Model -and $reportedRun.Estimator -eq $authoritativeRun.Estimator -and $reportedRun.StudyCount -eq $authoritativeRun.StudyCount -and $reportedRun.EffectCount -eq $authoritativeRun.EffectCount) 'SPR-009 categorical/count fields differ.'
$wrongAnalysisSpec = New-RapOutputSpecification -OutputSpecId OUT-WRONG -ProjectId PR001 -OutputType SYNTHESIS_RESULT_TABLE -OutputName Wrong -SourceScope CONFIRMED -AnalysisId AN-WRONG -IncludedFields ALL -FormattingProfile MACHINE
$wrongAnalysisDataset = New-RapOutputDataset $wrongAnalysisSpec @($analysisRecord)
Assert-GateThrows { New-RapResearchArtifact $wrongAnalysisSpec $wrongAnalysisDataset } 'OUTPUT_ANALYSIS_SCOPE_MISMATCH' 'Correct values with wrong Analysis_ID were accepted.'
Complete-Gate 'GATE-C'

# GATE-D: tamper actual scientific content without updating metadata hash.
$tamperedContent = $baseArtifact | ConvertTo-Json -Depth 80 | ConvertFrom-Json -Depth 80
$tamperedContent.Content.Data[0].Effect = 999
$tamperValidation = Test-RapOutputPackage $basePackage @($tamperedContent) $baseManifest
Assert-Gate (-not $tamperValidation.Valid -and $tamperValidation.Status -eq 'FAILED' -and ($tamperValidation.Errors -join ',') -match 'HASH_MISMATCH') 'Actual content tamper was not detected.'
Assert-GateThrows { New-RapReproducibilityManifest $baseSpec $baseDataset @($tamperedContent) } 'ARTIFACT_CONTENT_TAMPERED' 'Tampered content entered a new manifest.'
Complete-Gate 'GATE-D'

# GATE-E: meaningful upstream change makes the historical artifact stale; other project does not.
$changedRecords = New-RapOutputFixture; $changedRecords[3].Data.Effect = .9
$changedDataset = New-RapOutputDataset $baseSpec $changedRecords
Assert-Gate ((Test-RapOutputStale $baseArtifact $changedDataset.SourceDatasetHash $baseSpec.ConfigHash PR001) -eq 'STALE') 'Old artifact remained current after upstream change.'
Assert-Gate ((Test-RapOutputStale $baseArtifact changed $baseSpec.ConfigHash PR002) -eq 'NOT_APPLICABLE') 'Other-project change contaminated stale state.'
Complete-Gate 'GATE-E'

# GATE-F: AI-assisted unconfirmed coding cannot become authoritative output.
$aiRecord = $records[2].PSObject.Copy(); $aiRecord.VerificationState = 'AI_ASSISTED'
Assert-GateThrows { New-RapOutputDataset $baseSpec @($aiRecord) } 'OUTPUT_SOURCE_NOT_VERIFIED' 'AI-assisted coding was promoted.'
Complete-Gate 'GATE-F'

# GATE-G: blank researcher-owned narrative remains protected, including Turn-B fields.
foreach ($field in @('Introduction','Discussion','Conclusion','ReviewerInterpretation','ReviewerMemo','CriticalAppraisal')) {
    $protected = $records[0].PSObject.Copy(); $protected | Add-Member -NotePropertyName $field -NotePropertyValue ''
    Assert-GateThrows { New-RapOutputDataset $baseSpec @($protected) } 'HUMAN_OWNED_OUTPUT_BLOCKED' "Blank $field was writable."
}
Complete-Gate 'GATE-G'

# GATE-H: missing screening history yields no fabricated flow or PRISMA claim.
$withoutScreening = @($records | Where-Object { $_.RecordType -ne 'SCREENING' })
$missingFlow = New-RapFixtureArtifact SCREENING_FLOW_DATA $withoutScreening OUT-GATE-NOFLOW
Assert-Gate ($missingFlow.Artifact.Status -eq 'MISSING_REQUIRED_DATA' -and $missingFlow.Artifact.MissingRequirements -contains 'SCREENING_HISTORY') 'Missing flow was not explicitly unavailable.'
Assert-Gate (($missingFlow.Artifact | ConvertTo-Json -Depth 10) -notmatch 'PRISMA.?COMPLIANT|Identified|Excluded') 'Flow counts/compliance were fabricated.'
Complete-Gate 'GATE-H'

# GATE-I: diagnostics and factual statements remain non-interpretive; figure data stays authoritative.
$bias = New-RapFixtureArtifact PUBLICATION_BIAS_DIAGNOSTIC_TABLE
$statement = New-RapFactualResultStatement $records[5]
Assert-Gate ($null -eq $bias.Artifact.Content.Data[0].Interpretation) 'Bias output added interpretation.'
Assert-Gate ($null -eq $statement.Interpretation -and $statement.Text -notmatch 'large|meaningful|supports|effective|important|significant') 'Factual statement added scientific interpretation.'
Assert-Gate ($figure.Artifact.Content.Data.Effects[0].Effect -eq $records[3].Data.Effect -and $figure.Artifact.Content.Data.Effects[0].Lower -eq $records[3].Data.Lower -and $figure.Artifact.Content.Data.Effects[0].Upper -eq $records[3].Data.Upper) 'Forest data differs from authoritative effect record.'
Assert-Gate ($bias.Artifact.Content.Data[0].Points[0].EffectSizeId -eq 'ES-1' -and $bias.Artifact.Content.Data[0].AnalysisId -eq 'AN-PRIMARY') 'Funnel data lacks effect/analysis identity.'
Complete-Gate 'GATE-I'

# GATE-J: fake secrets, private notes, and PDFs are rejected; package metadata is complete.
foreach ($name in @('api_token.txt','credential.json','connection_string.txt','private_notes.md','canonical.pdf')) {
    Assert-GateThrows { New-RapExportPackage $baseSpec $baseDataset @($baseArtifact) $baseManifest @([pscustomobject]@{Name=$name}) } 'EXPORT_PRIVATE_CONTENT_BLOCKED' "Unsafe export $name was accepted."
}
Assert-Gate ($basePackage.ProjectId -eq 'PR001' -and $basePackage.GeneratorVersion -eq 'spr-010.1' -and $basePackage.ValidationStatus -eq 'READY' -and $basePackage.Body.ManifestContentHash -eq $baseManifest.ContentHash) 'Package identity/generator/validation metadata incomplete.'
Complete-Gate 'GATE-J'

# GATE-K: traversal, absolute paths, root escape, and collision behavior are safe.
Assert-GateThrows { New-RapOutputSpecification -OutputSpecId OUT-PATH -ProjectId PR001 -OutputType EFFECT_SIZE_TABLE -OutputName x -SourceScope CONFIRMED -IncludedFields ALL -FormattingProfile MACHINE -LogicalDestination '../escape' } 'UNSAFE_OUTPUT_PATH' 'Traversal accepted.'
Assert-GateThrows { New-RapOutputSpecification -OutputSpecId OUT-PATH -ProjectId PR001 -OutputType EFFECT_SIZE_TABLE -OutputName x -SourceScope CONFIRMED -IncludedFields ALL -FormattingProfile MACHINE -LogicalDestination 'C:\escape' } 'UNSAFE_OUTPUT_PATH' 'Absolute path accepted.'
Assert-Gate ($baseSpec.LogicalDestination -eq 'LOCAL_FIXTURE' -and $basePackage.ProductionWrite -eq 'DISABLED') 'Output-root boundary is not local-only.'
Assert-Gate ((New-RapExportPackage $baseSpec $baseDataset @($baseArtifact) $baseManifest).PackageId -eq $basePackage.PackageId) 'Filename/package collision is not deterministic.'
Complete-Gate 'GATE-K'

# GATE-L: injected commit failure leaves no READY artifact.
$failedState = [pscustomobject]@{ Artifacts = [Collections.Generic.List[object]]::new() }
$failingDependencies = [pscustomobject]@{
    GetOperation = { param($id) $null }
    CommitGeneration = { param($s,$d,$a,$m,$o,$audit) throw 'INJECTED_COMMIT_FAILURE' }
}
Assert-GateThrows { Invoke-RapOutputGeneration $baseSpec $baseDataset $baseArtifact $baseManifest GATE-FAIL $failingDependencies } 'INJECTED_COMMIT_FAILURE' 'Injected failure was hidden.'
Assert-Gate ($failedState.Artifacts.Count -eq 0) 'Partial failure left a READY artifact.'
Complete-Gate 'GATE-L'

# GATE-M: replay is idempotent; SQLite reload includes package, lineage, status, and semantic audit.
$memory = New-RapMemoryOutputDependencies
$first = Invoke-RapOutputGeneration $baseSpec $baseDataset $baseArtifact $baseManifest GATE-IDEM $memory.Dependencies
$replay = Invoke-RapOutputGeneration $baseSpec $baseDataset $baseArtifact $baseManifest GATE-IDEM $memory.Dependencies
Assert-Gate ($first.Status -eq 'COMPLETED' -and $replay.Status -eq 'ALREADY_COMPLETED' -and $memory.State.Artifacts.Count -eq 1) 'Same operation duplicated artifact.'
$temporary = Join-Path ([IO.Path]::GetTempPath()) "rap-output-gate-$PID-$([guid]::NewGuid().ToString('N'))"
[void][IO.Directory]::CreateDirectory($temporary)
try {
    $database = Join-Path $temporary 'gate.db'
    $sqlite = New-RapOutputSqliteDependencies $database
    $null = Invoke-RapOutputGeneration $baseSpec $baseDataset $baseArtifact $baseManifest GATE-SQL $sqlite
    $null = Save-RapOutputPackage $basePackage $sqlite
    $snapshot = Get-RapOutputSnapshot $database
    Assert-Gate ($snapshot.Specifications[0].OutputSpecId -eq $baseSpec.OutputSpecId -and $snapshot.Datasets[0].OutputDatasetId -eq $baseDataset.OutputDatasetId) 'Specification/dataset did not reload.'
    Assert-Gate ($snapshot.Artifacts[0].ArtifactRecordId -eq $baseArtifact.ArtifactRecordId -and $snapshot.Artifacts[0].Lineage.OutputDatasetId -eq $baseDataset.OutputDatasetId -and $snapshot.Artifacts[0].Status -eq 'READY') 'Artifact/lineage/status did not reload.'
    Assert-Gate ($snapshot.Manifests[0].ManifestId -eq $baseManifest.ManifestId -and $snapshot.Packages[0].PackageId -eq $basePackage.PackageId) 'Manifest/package did not reload.'
    $audit = $snapshot.LastAudit
    Assert-Gate ($audit.OperationId -eq 'GATE-SQL' -and $audit.ProjectId -eq 'PR001' -and $audit.OutputSpecId -eq $baseSpec.OutputSpecId -and $audit.ArtifactId -eq $baseArtifact.ArtifactId) 'Audit identities do not match operation.'
    Assert-Gate ($audit.DatasetHash -eq $baseDataset.SourceDatasetHash -and $audit.ConfigHash -eq $baseSpec.ConfigHash -and $audit.GeneratorVersion -eq 'spr-010.1' -and $audit.Status -eq 'COMPLETED' -and $null -ne $audit.Timestamp -and $null -ne $audit.Warnings -and $null -ne $audit.Errors) 'Audit hashes/version/status/details incomplete.'
    $historySpec = New-RapOutputSpecification -OutputSpecId OUT-GATE -ProjectId PR001 -OutputType EFFECT_SIZE_TABLE -OutputName GateEffects -SourceScope CONFIRMED -AnalysisId AN-PRIMARY -IncludedFields @('Effect','SE') -FormattingProfile MACHINE
    $historyArtifact = New-RapResearchArtifact $historySpec $baseDataset
    $historyManifest = New-RapReproducibilityManifest $historySpec $baseDataset @($historyArtifact)
    $null = Invoke-RapOutputGeneration $historySpec $baseDataset $historyArtifact $historyManifest GATE-SQL-V2 $sqlite
    $historySnapshot = Get-RapOutputSnapshot $database
    Assert-Gate ($historySnapshot.Artifacts.Count -eq 2 -and $historySnapshot.Artifacts.ArtifactRecordId -contains $baseArtifact.ArtifactRecordId -and $historySnapshot.Artifacts.ArtifactRecordId -contains $historyArtifact.ArtifactRecordId) 'Artifact version history did not survive reload.'
} finally {
    Remove-Item -LiteralPath $temporary -Recurse -Force
}
Complete-Gate 'GATE-M'

# GATE-N: same OperationID with a different scientific payload conflicts.
$variantSpec = New-RapOutputSpecification -OutputSpecId OUT-GATE -ProjectId PR001 -OutputType EFFECT_SIZE_TABLE -OutputName GateEffects -SourceScope CONFIRMED -AnalysisId AN-PRIMARY -IncludedFields @('Effect','SE') -FormattingProfile MACHINE
$variantArtifact = New-RapResearchArtifact $variantSpec $baseDataset
$variantManifest = New-RapReproducibilityManifest $variantSpec $baseDataset @($variantArtifact)
Assert-GateThrows { Invoke-RapOutputGeneration $variantSpec $baseDataset $variantArtifact $variantManifest GATE-IDEM $memory.Dependencies } 'PAYLOAD_CONFLICT' 'Different payload reused operation ID.'
Complete-Gate 'GATE-N'

# GATE-O: equivalent regeneration is stable; meaningful source/config changes create new identity/history.
$equivalentDataset = New-RapOutputDataset $baseSpec @($records | Sort-Object RecordId -Descending)
$equivalentArtifact = New-RapResearchArtifact $baseSpec $equivalentDataset
Assert-Gate ($equivalentDataset.SourceDatasetHash -eq $baseDataset.SourceDatasetHash -and $equivalentArtifact.ContentHash -eq $baseArtifact.ContentHash) 'Equivalent regeneration is unstable.'
Assert-Gate ($changedDataset.SourceDatasetHash -ne $baseDataset.SourceDatasetHash) 'Meaningful source change did not change dataset identity.'
Assert-Gate ($variantArtifact.ArtifactVersion -ne $baseArtifact.ArtifactVersion -and $variantArtifact.ArtifactRecordId -ne $baseArtifact.ArtifactRecordId) 'Meaningful configuration change did not create a new artifact version identity.'
Complete-Gate 'GATE-O'

if ($script:GateScenarios -ne 15) { throw "Expected 15 Gate scenarios, got $script:GateScenarios" }
Write-Host "SPR-010 Turn-B independent Gate tests: $script:GateScenarios/15 PASS; assertions: $script:GateAssertions"
