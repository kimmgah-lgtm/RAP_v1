Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'ResearchAutomation.Output.psd1') -Force
. (Join-Path $PSScriptRoot 'TestHarness.ps1')
$script:A = 0

function A($condition, $message) {
    $script:A++
    if (-not $condition) { throw "Assertion $script:A failed: $message" }
}
function T($action, $pattern, $message) {
    $script:A++
    $errorMessage = $null
    try { & $action } catch { $errorMessage = $_.Exception.Message }
    if ($errorMessage -notmatch $pattern) { throw "Assertion $script:A failed: $message; actual=$errorMessage" }
}

$records = New-RapOutputFixture
$spec = New-RapOutputSpecification -OutputSpecId OUT-CORE -ProjectId PR001 -OutputType EFFECT_SIZE_TABLE -OutputName Effects -SourceScope CONFIRMED -AnalysisId AN-PRIMARY -IncludedFields @('Effect') -FormattingProfile MACHINE
$spec2 = New-RapOutputSpecification -OutputSpecId OUT-CORE -ProjectId PR001 -OutputType EFFECT_SIZE_TABLE -OutputName Effects -SourceScope CONFIRMED -AnalysisId AN-PRIMARY -IncludedFields @('Effect') -FormattingProfile MACHINE
$dataset = New-RapOutputDataset $spec $records
$dataset2 = New-RapOutputDataset $spec @($records | Sort-Object RecordId -Descending)
$artifact = New-RapResearchArtifact $spec $dataset
$artifact2 = New-RapResearchArtifact $spec2 $dataset2
$manifest = New-RapReproducibilityManifest $spec $dataset @($artifact)

# Specification, determinism, operation idempotency (12)
A ($spec.OutputSpecId -eq 'OUT-CORE') 'stable spec id'
A ($spec.ConfigHash -eq $spec2.ConfigHash) 'stable config hash'
T { New-RapOutputSpecification -OutputSpecId OUT-X -ProjectId BAD -OutputType EFFECT_SIZE_TABLE -OutputName x -SourceScope CONFIRMED -IncludedFields x -FormattingProfile x } 'validate|pattern' 'project id validation'
$crossProject = $records[0].PSObject.Copy(); $crossProject.ProjectId = 'PR002'
T { New-RapOutputDataset $spec @($crossProject) } 'OUTPUT_PROJECT_SCOPE_MISMATCH' 'cross project input'
A ($dataset.OutputDatasetId -eq $dataset2.OutputDatasetId) 'dataset id deterministic'
A ($dataset.SourceDatasetHash -eq $dataset2.SourceDatasetHash) 'dataset hash deterministic'
$changedRecords = New-RapOutputFixture; $changedRecords[3].Data.Effect = .2
$changedDataset = New-RapOutputDataset $spec $changedRecords
A ($changedDataset.SourceDatasetHash -ne $dataset.SourceDatasetHash) 'source change changes hash'
A ($artifact.ArtifactId -eq $artifact2.ArtifactId) 'artifact id deterministic'
A ($artifact.ContentHash -eq $artifact2.ContentHash) 'artifact content deterministic'
$memory = New-RapMemoryOutputDependencies
$first = Invoke-RapOutputGeneration $spec $dataset $artifact $manifest OP-1 $memory.Dependencies
$again = Invoke-RapOutputGeneration $spec $dataset $artifact $manifest OP-1 $memory.Dependencies
A ($first.Status -eq 'COMPLETED') 'first generation completed'
A ($again.Status -eq 'ALREADY_COMPLETED') 'repeat generation idempotent'
A ($memory.State.Artifacts.Count -eq 1) 'idempotent generation does not duplicate artifact'

# Source gates and artifact families (26; cumulative 38)
$aiRecord = $records[2].PSObject.Copy(); $aiRecord.VerificationState = 'AI_ASSISTED'
A ($null -ne ($dataset.Rows | Where-Object { $_.RecordType -eq 'META_CODING' })) 'confirmed data admitted'
T { New-RapOutputDataset $spec @($aiRecord) } 'OUTPUT_SOURCE_NOT_VERIFIED' 'AI-assisted data blocked'
$conflicting = $records[10].PSObject.Copy(); $conflicting.EvidenceStatus = 'CONFLICTING_EVIDENCE'
$conflictingDataset = New-RapOutputDataset $spec @($conflicting)
A ($conflictingDataset.Readiness -eq 'CONFLICTING_INPUT') 'conflict flagged'
$study = New-RapFixtureArtifact STUDY_CHARACTERISTICS_TABLE
A ($study.Artifact.Content.Data[1].Sample -eq 'NOT_REPORTED') 'missing study value not fabricated'
$unverifiedAnalysis = $records[5].PSObject.Copy(); $unverifiedAnalysis.VerificationState = 'PENDING'
T { New-RapOutputDataset $spec @($unverifiedAnalysis) } 'OUTPUT_SOURCE_NOT_VERIFIED' 'unverified synthesis blocked'
$synthesis = New-RapFixtureArtifact SYNTHESIS_RESULT_TABLE
A ($synthesis.Artifact.Content.Data[0].PooledEstimate -eq .6) 'verified synthesis output'
A ((New-RapFixtureArtifact STUDY_CHARACTERISTICS_TABLE).Artifact.ContentHash -eq $study.Artifact.ContentHash) 'study artifact deterministic'
$meta = New-RapFixtureArtifact META_CODING_TABLE
A ($meta.Artifact.Content.Data[0].ProjectId -eq 'PR001') 'meta coding project scoped'
A ($artifact.Content.Data.EffectSizeId -contains 'ES-1') 'effect size identity retained'
A (@($artifact.Content.Data | Select-Object -ExpandProperty EffectOrigin -Unique).Count -eq 2) 'reported and derived origins retained'
A ($synthesis.Artifact.Content.Data[0].PooledEstimate -eq $records[5].Data.PooledEstimate) 'authoritative result reused'
$heterogeneity = New-RapFixtureArtifact HETEROGENEITY_TABLE
A ($heterogeneity.Artifact.Content.Data[0].Q -eq 15.5) 'Q retained'
A ($heterogeneity.Artifact.Content.Data[0].I2 -eq 87.096774) 'I2 retained'
A ($heterogeneity.Artifact.Content.Data[0].Tau2 -eq .27) 'tau squared retained'
$moderator = New-RapFixtureArtifact MODERATOR_SUBGROUP_TABLE
$missingModeratorRecord = $records[6].PSObject.Copy()
$missingModeratorRecord.Data = $records[6].Data.PSObject.Copy()
$missingModeratorRecord.Data.Group = $null
$missingModerator = New-RapFixtureArtifact MODERATOR_SUBGROUP_TABLE @($missingModeratorRecord) OUT-MISSING-MOD
A ($moderator.Artifact.Content.Data[0].Group -eq 'A' -and $null -eq $missingModerator.Artifact.Content.Data[0].Group) 'moderator identity and missingness retained'
$sensitivity = New-RapFixtureArtifact SENSITIVITY_TABLE
A ($sensitivity.Artifact.Content.Data[0].ParentAnalysisId -eq 'AN-PRIMARY') 'sensitivity parent retained'
$flow = New-RapFixtureArtifact SCREENING_FLOW_DATA
A ($flow.Artifact.Content.Data[0].Screened -eq 8) 'screening flow derived'
$noScreen = @($records | Where-Object { $_.RecordType -ne 'SCREENING' })
$missingFlow = New-RapFixtureArtifact SCREENING_FLOW_DATA $noScreen OUT-NOSCREEN
A ($missingFlow.Artifact.Status -eq 'MISSING_REQUIRED_DATA') 'missing screening state explicit'
A ($missingFlow.Artifact.PSObject.Properties.Name -notcontains 'Content') 'no invented flow content'
$figure = New-RapFixtureArtifact FIGURE_DATASET
A ($figure.Artifact.Content.Data.Effects[0].Effect -eq .1) 'forest dataset effect'
A ($figure.Artifact.Content.Data.Pooled[0].PooledEstimate -eq .6) 'forest dataset pooled result'
$bias = New-RapFixtureArtifact PUBLICATION_BIAS_DIAGNOSTIC_TABLE
A ($bias.Artifact.Content.Data[0].Points[0].EffectSizeId -eq 'ES-1') 'funnel point identity'
A ($figure.Artifact.Content.Data.AnalysisId -eq 'AN-PRIMARY') 'figure analysis identity'
A ($figure.Artifact.Status -eq 'READY') 'figure dataset ready independently of renderer'
$evidence = New-RapFixtureArtifact EVIDENCE_SUMMARY_TABLE
A ($evidence.Artifact.Content.Data[0].Status -eq 'SUPPORTED') 'evidence status retained'
A ($evidence.Artifact.Content.Data[0].Lineage.PaperNodeId -like 'PAPER:*') 'evidence lineage retained'

# Human-owned boundaries and factual narrative (10; cumulative 48)
foreach ($field in @('Introduction', 'Discussion', 'Conclusion', 'ReviewerInterpretation')) {
    $blocked = $records[0].PSObject.Copy(); $blocked | Add-Member $field ''
    T { New-RapOutputDataset $spec @($blocked) } 'HUMAN_OWNED_OUTPUT_BLOCKED' "protect $field"
}
$blankHuman = $records[0].PSObject.Copy(); $blankHuman | Add-Member Introduction ''
T { New-RapOutputDataset $spec @($blankHuman) } 'HUMAN_OWNED_OUTPUT_BLOCKED' 'blank human field protected'
$statement = New-RapFactualResultStatement $records[5]
A ($null -eq $statement.Interpretation) 'factual statement has no interpretation'
A ($statement.Text -notmatch 'caus|effective') 'no causal claim'
A ($statement.Text -notmatch 'large|small|important') 'no magnitude interpretation'
A ($null -eq $bias.Artifact.Content.Data[0].Interpretation) 'no publication bias interpretation'
A ($statement.Ownership -eq 'SYSTEM_GENERATED_FACT') 'narrative ownership explicit'

# Lineage and reproducibility manifest (18; cumulative 66)
A ($artifact.Lineage.OutputSpecId -eq $spec.OutputSpecId) 'spec lineage'
A ($artifact.Lineage.OutputDatasetId -eq $dataset.OutputDatasetId) 'dataset lineage'
A ($artifact.Lineage.SourceRecordIds.Count -eq $dataset.Rows.Count) 'source record lineage'
A ($synthesis.Artifact.Lineage.AnalysisIds -contains 'AN-PRIMARY') 'analysis lineage'
A ($artifact.Lineage.EffectSizeIds -contains 'ES-1') 'effect lineage'
A (@($artifact.Lineage.Upstream | Where-Object { $_.PaperNodeId }).Count -gt 0) 'graph lineage'
A (($artifact.Content.Data | Where-Object { $_.EffectOrigin -eq 'DERIVED_EFFECT' }).Provenance.EffectSizeNodeId -like 'EFFECT_SIZE:*') 'derived provenance'
$brokenLineage = $records[3].PSObject.Copy(); $brokenLineage.Lineage = $null
T { New-RapOutputDataset $spec @($brokenLineage) } 'OUTPUT_LINEAGE_REQUIRED' 'broken lineage blocked'
A ($manifest.ManifestId -like 'MAN-*') 'manifest identity'
A ($manifest.Body.SourceDatasetHash -eq $dataset.SourceDatasetHash) 'manifest dataset hash'
A ($manifest.Body.OutputConfigHash -eq $spec.ConfigHash) 'manifest config hash'
A ($manifest.Body.OutputGeneratorVersion -eq 'spr-010.1') 'manifest generator version'
A ($manifest.Body.AnalysisEngineVersions -contains 'spr-009.2') 'analysis engine version'
A ($artifact.ContentHash -eq $artifact2.ContentHash) 'semantic equivalent regeneration'
$specVariant = New-RapOutputSpecification -OutputSpecId OUT-CORE -ProjectId PR001 -OutputType EFFECT_SIZE_TABLE -OutputName Effects -SourceScope CONFIRMED -AnalysisId AN-PRIMARY -IncludedFields @('Effect', 'SE') -FormattingProfile MACHINE
$artifactVariant = New-RapResearchArtifact $specVariant $dataset
A ($artifactVariant.ArtifactVersion -ne $artifact.ArtifactVersion) 'scientific config change creates distinct artifact version'
A ($artifact.Status -eq 'READY') 'historical artifact remains preserved'
A ($manifest.Body.SourceRecordCount -eq $dataset.Rows.Count) 'manifest source count'
A ($manifest.Body.Artifacts[0].ContentHash -eq $artifact.ContentHash) 'manifest artifact hash'

# Staleness, export package, and output safety (18; cumulative 84)
A ((Test-RapOutputStale $artifact $changedDataset.SourceDatasetHash $spec.ConfigHash PR001) -eq 'STALE') 'analysis input staleness'
A ((Test-RapOutputStale $artifact changed $spec.ConfigHash PR001) -eq 'STALE') 'coding staleness'
A ((Test-RapOutputStale $artifact changed $spec.ConfigHash PR002) -eq 'NOT_APPLICABLE') 'other project isolated'
A ((Test-RapOutputStale $artifact $dataset.SourceDatasetHash $spec.ConfigHash PR001) -eq 'CURRENT') 'current artifact recognized'
$package = New-RapExportPackage $spec $dataset @($artifact) $manifest
A ($package.PackageId -like 'PKG-*') 'package id'
A ($package.Body.Artifacts.Count -eq 1) 'package artifact list'
A ($package.Body.Artifacts[0].ContentHash -eq $artifact.ContentHash) 'package artifact hash'
T { New-RapExportPackage $spec $dataset @($artifact) $manifest @([pscustomobject]@{ Name = 'credential.txt' }) } 'EXPORT_PRIVATE' 'credential blocked'
T { New-RapExportPackage $spec $dataset @($artifact) $manifest @([pscustomobject]@{ Name = 'api_token.txt' }) } 'EXPORT_PRIVATE' 'token blocked'
T { New-RapExportPackage $spec $dataset @($artifact) $manifest @([pscustomobject]@{ Name = 'paper.pdf' }) } 'EXPORT_PRIVATE' 'canonical PDF blocked'
T { New-RapExportPackage $spec $dataset @($artifact) $manifest @([pscustomobject]@{ Name = 'private_notes.md' }) } 'EXPORT_PRIVATE' 'private notes blocked'
$missingTest = Test-RapOutputPackage $package @() $manifest
A (-not $missingTest.Valid) 'missing artifact detected'
$tampered = $artifact.PSObject.Copy(); $tampered.ContentHash = 'bad'
$tamperTest = Test-RapOutputPackage $package @($tampered) $manifest
A (-not $tamperTest.Valid) 'tamper detected'
A ($tamperTest.Status -eq 'FAILED') 'tampered package not finalized'
T { New-RapOutputSpecification -OutputSpecId OUT-P -ProjectId PR001 -OutputType EFFECT_SIZE_TABLE -OutputName x -SourceScope CONFIRMED -IncludedFields x -FormattingProfile x -LogicalDestination '../escape' } 'UNSAFE_OUTPUT_PATH' 'traversal blocked'
T { New-RapOutputSpecification -OutputSpecId OUT-P -ProjectId PR001 -OutputType EFFECT_SIZE_TABLE -OutputName x -SourceScope CONFIRMED -IncludedFields x -FormattingProfile x -LogicalDestination 'C:\escape' } 'UNSAFE_OUTPUT_PATH' 'absolute path blocked'
A ((New-RapExportPackage $spec $dataset @($artifact) $manifest).PackageId -eq $package.PackageId) 'package collision deterministic'
A ($package.ProductionWrite -eq 'DISABLED') 'production write disabled'

# SQLite persistence and audit operation (8; cumulative 92)
$temporary = Join-Path ([IO.Path]::GetTempPath()) "rap-output-$PID-$([guid]::NewGuid().ToString('N'))"
[void][IO.Directory]::CreateDirectory($temporary)
try {
    $database = Join-Path $temporary 'output.db'
    $sqlite = New-RapOutputSqliteDependencies $database
    $null = Invoke-RapOutputGeneration $spec $dataset $artifact $manifest SQL-1 $sqlite
    $manifestVariant = New-RapReproducibilityManifest $specVariant $dataset @($artifactVariant)
    $null = Invoke-RapOutputGeneration $specVariant $dataset $artifactVariant $manifestVariant SQL-2 $sqlite
    $snapshot = Get-RapOutputSnapshot $database
    A ($snapshot.Specifications[0].ConfigHash -eq $specVariant.ConfigHash) 'latest specification reload'
    A ($snapshot.Artifacts[0].ArtifactId -eq $artifact.ArtifactId) 'artifact reload'
    A ($snapshot.Manifests[0].ManifestId -eq $manifest.ManifestId) 'manifest reload'
    A ($snapshot.Artifacts[0].Lineage.OutputDatasetId -eq $dataset.OutputDatasetId) 'lineage reload'
    A ($snapshot.Artifacts.Count -eq 2) 'artifact version history reload'
    A ($snapshot.AuditCount -eq 2 -and $null -ne (& $sqlite.GetOperation SQL-1)) 'audit and operation persisted'
    $replayed = Invoke-RapOutputGeneration $spec $dataset $artifact $manifest SQL-1 $sqlite
    A ($replayed.Status -eq 'ALREADY_COMPLETED') 'persistent replay idempotent'
    T { Invoke-RapOutputGeneration $specVariant $dataset $artifact $manifest SQL-1 $sqlite } 'PAYLOAD_CONFLICT' 'persistent payload conflict'
} finally {
    Remove-Item -LiteralPath $temporary -Recurse -Force
}

# Production-safety controls (9 additional executable assertions)
$configuration = Get-Content -LiteralPath (Join-Path $root '../ResearchAutomation.Local/config/config.json') -Raw | ConvertFrom-Json
A ($configuration.capabilities.ProductionAIProvider -eq $false) 'production AI provider disabled'
A ($configuration.capabilities.ProductionZoteroWrite -eq $false) 'production Zotero write disabled'
A ($configuration.capabilities.ProductionDriveMigration -eq $false) 'production Drive migration disabled'
A ($configuration.capabilities.ProductionNotionWrite -eq $false) 'production Notion write disabled'
A ($configuration.capabilities.SynthesisProductionWrite -eq $false) 'synthesis production write disabled'
A ($configuration.capabilities.OutputProductionWrite -eq $false) 'output production write disabled'
A ($configuration.environment -eq 'Local' -and [string]::IsNullOrEmpty($configuration.googleDrive.folderId)) 'external tests remain deferred'
A (-not $configuration.writeLayer.enabled -and -not $configuration.capabilities.ProductionDriveMigration -and -not $configuration.capabilities.ProductionNotionWrite) 'production mutation paths disabled'
A ($package.Body.ExcludedByDefault -contains 'CANONICAL_PDF') 'no real PDF can be transmitted by default'

if ($script:A -ne 101) { throw "Expected 101 assertions, got $script:A" }
Write-Host "SPR-010 output core scenarios: 92/92 PASS; assertions: $script:A"
