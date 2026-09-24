Set-StrictMode -Version Latest

$script:RapOutputTypes = @(
    'STUDY_CHARACTERISTICS_TABLE', 'META_CODING_TABLE', 'EFFECT_SIZE_TABLE',
    'SYNTHESIS_RESULT_TABLE', 'HETEROGENEITY_TABLE', 'MODERATOR_SUBGROUP_TABLE',
    'SENSITIVITY_TABLE', 'PUBLICATION_BIAS_DIAGNOSTIC_TABLE', 'SCREENING_FLOW_DATA',
    'EVIDENCE_SUMMARY_TABLE', 'FIGURE_DATASET'
)
$script:RapOutputHumanFields = @(
    'Introduction', 'Discussion', 'Conclusion', 'ReviewerInterpretation',
    'ReviewerMemo', 'Reviewer Memo', 'CriticalAppraisal', 'Critical Appraisal'
)
$script:RapAnalysisOutputTypes = @(
    'SYNTHESIS_RESULT_TABLE', 'HETEROGENEITY_TABLE',
    'PUBLICATION_BIAS_DIAGNOSTIC_TABLE', 'FIGURE_DATASET'
)

function ConvertTo-RapOutputCanonical {
    param($Value)
    if ($null -eq $Value) { return $null }
    if ($Value -is [Collections.IDictionary]) {
        $result = [ordered]@{}
        foreach ($key in @($Value.Keys | ForEach-Object { [string]$_ } | Sort-Object)) {
            $result[$key] = ConvertTo-RapOutputCanonical $Value[$key]
        }
        return $result
    }
    if ($Value -is [Management.Automation.PSCustomObject]) {
        $result = [ordered]@{}
        foreach ($property in @($Value.PSObject.Properties | Sort-Object Name)) {
            $result[$property.Name] = ConvertTo-RapOutputCanonical $property.Value
        }
        return $result
    }
    if ($Value -is [Collections.IEnumerable] -and $Value -isnot [string]) {
        return @($Value | ForEach-Object { ConvertTo-RapOutputCanonical $_ })
    }
    return $Value
}

function Get-RapOutputHash {
    param($Value)
    $json = (ConvertTo-RapOutputCanonical $Value) | ConvertTo-Json -Depth 80 -Compress
    return [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($json))
    ).ToLowerInvariant()
}

function Assert-RapOutputNoHumanWrite {
    param($Value, [string]$Path = 'Output')
    if ($null -eq $Value) { return }
    if ($Value -is [Collections.IEnumerable] -and $Value -isnot [string] -and $Value -isnot [Collections.IDictionary]) {
        foreach ($item in $Value) { Assert-RapOutputNoHumanWrite $item $Path }
        return
    }
    $entries = if ($Value -is [Collections.IDictionary]) {
        $Value.GetEnumerator() | ForEach-Object { [pscustomobject]@{ Name = $_.Key; Value = $_.Value } }
    } else { $Value.PSObject.Properties }
    foreach ($entry in @($entries)) {
        if ($script:RapOutputHumanFields -icontains $entry.Name) {
            throw "HUMAN_OWNED_OUTPUT_BLOCKED: $Path.$($entry.Name)"
        }
        if ($entry.Value -is [Collections.IDictionary] -or $entry.Value -is [Management.Automation.PSCustomObject]) {
            Assert-RapOutputNoHumanWrite $entry.Value "$Path.$($entry.Name)"
        }
    }
}

function New-RapOutputSpecification {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidatePattern('^OUT-[A-Za-z0-9._-]+$')][string]$OutputSpecId,
        [Parameter(Mandatory)][ValidatePattern('^PR\d{3}$')][string]$ProjectId,
        [Parameter(Mandatory)][string]$OutputType,
        [Parameter(Mandatory)][string]$OutputName,
        [Parameter(Mandatory)][string]$SourceScope,
        [string]$AnalysisId,
        [Parameter(Mandatory)][string[]]$IncludedFields,
        [Parameter(Mandatory)][string]$FormattingProfile,
        [string]$Language = 'en',
        [string]$TemplateVersion = '1.0',
        [string]$SchemaVersion = 'spr-010.1',
        [string]$GeneratorVersion = 'spr-010.1',
        [string]$LogicalDestination = 'LOCAL_FIXTURE',
        [string[]]$SortSpecification = @(),
        [string[]]$FilterSpecification = @()
    )
    if ($script:RapOutputTypes -notcontains $OutputType) { throw 'OUTPUT_TYPE_UNSUPPORTED' }
    if ($script:RapAnalysisOutputTypes -contains $OutputType -and [string]::IsNullOrWhiteSpace($AnalysisId)) {
        throw 'OUTPUT_ANALYSIS_ID_REQUIRED'
    }
    if ([string]::IsNullOrWhiteSpace($OutputName) -or [IO.Path]::IsPathRooted($LogicalDestination) -or $LogicalDestination -match '\.\.') {
        throw 'UNSAFE_OUTPUT_PATH'
    }
    $scientific = [ordered]@{
        ProjectId = $ProjectId; OutputType = $OutputType; OutputName = $OutputName
        SourceScope = $SourceScope; AnalysisId = $AnalysisId; IncludedFields = @($IncludedFields)
        FormattingProfile = $FormattingProfile; Language = $Language; TemplateVersion = $TemplateVersion
        SchemaVersion = $SchemaVersion; LogicalDestination = $LogicalDestination
        Sort = @($SortSpecification); Filter = @($FilterSpecification); GeneratorVersion = $GeneratorVersion
    }
    return [pscustomobject]@{
        OutputSpecId = $OutputSpecId; ProjectId = $ProjectId; OutputType = $OutputType
        OutputName = $OutputName; SourceScope = $SourceScope; AnalysisId = $AnalysisId
        IncludedFields = @($IncludedFields); FormattingProfile = $FormattingProfile
        Language = $Language; TemplateVersion = $TemplateVersion; SchemaVersion = $SchemaVersion
        GeneratorVersion = $GeneratorVersion; LogicalDestination = $LogicalDestination
        SortSpecification = @($SortSpecification); FilterSpecification = @($FilterSpecification)
        ConfigHash = Get-RapOutputHash $scientific; Status = 'RESEARCHER_CONFIRMED'
        CreatedBy = 'RESEARCHER'; CreatedAt = [DateTimeOffset]::UtcNow.ToString('o')
    }
}

function New-RapOutputDataset {
    [CmdletBinding()]
    param($Specification, [object[]]$Records)
    Assert-RapOutputNoHumanWrite $Records
    $canonical = [Collections.Generic.List[object]]::new()
    $warnings = [Collections.Generic.List[string]]::new()
    foreach ($record in $Records) {
        if ([string]$record.ProjectId -ne $Specification.ProjectId) { throw 'OUTPUT_PROJECT_SCOPE_MISMATCH' }
        if ([string]::IsNullOrWhiteSpace([string]$record.RecordId)) { throw 'OUTPUT_SOURCE_ID_REQUIRED' }
        $verification = [string]$record.VerificationState
        if ($Specification.SourceScope -eq 'CONFIRMED' -and $verification -ne 'RESEARCHER_CONFIRMED') { throw 'OUTPUT_SOURCE_NOT_VERIFIED' }
        if ($record.EvidenceStatus -eq 'CONFLICTING_EVIDENCE') { $warnings.Add("CONFLICTING_INPUT:$($record.RecordId)") }
        if ($record.RecordType -in @('EFFECT', 'ANALYSIS')) {
            if (-not $record.Lineage -or -not $record.Lineage.PaperNodeId -or @($record.Lineage.EvidenceNodeIds).Count -eq 0) {
                throw 'OUTPUT_LINEAGE_REQUIRED'
            }
            if ($record.RecordType -eq 'EFFECT' -and [string]::IsNullOrWhiteSpace([string]$record.Lineage.EffectSizeNodeId)) {
                throw 'OUTPUT_LINEAGE_REQUIRED'
            }
        }
        if ($record.RecordType -eq 'EFFECT' -and $record.Data.EffectOrigin -eq 'DERIVED_EFFECT') {
            $statisticalInputNodeIds = if ($record.Lineage.PSObject.Properties['StatisticalInputNodeIds']) {
                @($record.Lineage.StatisticalInputNodeIds)
            } else { @() }
            if ([string]::IsNullOrWhiteSpace([string]$record.Data.Transformation.Method) -or
                [string]::IsNullOrWhiteSpace([string]$record.Data.Transformation.Version) -or
                $statisticalInputNodeIds.Count -eq 0) {
                throw 'OUTPUT_DERIVED_LINEAGE_REQUIRED'
            }
        }
        $canonical.Add([pscustomobject]@{
            RecordId = $record.RecordId; RecordType = $record.RecordType; ProjectId = $record.ProjectId
            LibraryId = $record.LibraryId; EffectSizeId = $record.EffectSizeId; AnalysisId = $record.AnalysisId
            VerificationState = $verification; EvidenceStatus = $record.EvidenceStatus; Version = $record.Version
            Data = $record.Data; Lineage = $record.Lineage
        })
    }
    $rows = @($canonical | Sort-Object RecordType, RecordId)
    $hash = Get-RapOutputHash $rows
    return [pscustomobject]@{
        OutputDatasetId = "OD-$($hash.Substring(0,24))"; OutputSpecId = $Specification.OutputSpecId
        ProjectId = $Specification.ProjectId; SourceRecordIds = @($rows.RecordId); SourceRecordVersions = @($rows.Version)
        Rows = $rows; SourceDatasetHash = $hash; GeneratorVersion = $Specification.GeneratorVersion
        Readiness = $(if ($warnings.Count) { 'CONFLICTING_INPUT' } else { 'READY' })
        Warnings = @($warnings); CreatedAt = [DateTimeOffset]::UtcNow.ToString('o')
    }
}

function New-RapResearchArtifact {
    [CmdletBinding()]
    param($Specification, $Dataset)
    if ($Dataset.Readiness -ne 'READY') { throw "OUTPUT_NOT_READY: $($Dataset.Readiness)" }
    $rows = @($Dataset.Rows)
    $scopedRecordTypes = switch ($Specification.OutputType) {
        'SYNTHESIS_RESULT_TABLE' { @('ANALYSIS') }
        'HETEROGENEITY_TABLE' { @('ANALYSIS') }
        'EFFECT_SIZE_TABLE' { @('EFFECT') }
        'PUBLICATION_BIAS_DIAGNOSTIC_TABLE' { @('BIAS_DIAGNOSTIC') }
        'FIGURE_DATASET' { @('EFFECT', 'ANALYSIS') }
        default { @() }
    }
    foreach ($scopedRow in @($rows | Where-Object { $scopedRecordTypes -contains $_.RecordType })) {
        if ($Specification.AnalysisId -and $scopedRow.AnalysisId -ne $Specification.AnalysisId) {
            throw "OUTPUT_ANALYSIS_SCOPE_MISMATCH: $($scopedRow.RecordId)"
        }
    }
    $data = switch ($Specification.OutputType) {
        'STUDY_CHARACTERISTICS_TABLE' {
            @($rows | Where-Object { $_.RecordType -eq 'STUDY' } | ForEach-Object {
                [pscustomobject]@{ LibraryId = $_.LibraryId; Citation = $_.Data.Citation; Year = $_.Data.Year
                    Country = $_.Data.Country; Sample = $(if ($null -eq $_.Data.Sample) { 'NOT_REPORTED' } else { $_.Data.Sample })
                    Population = $_.Data.Population; StudyDesign = $_.Data.StudyDesign
                    InterventionExposure = $_.Data.InterventionExposure; Comparison = $_.Data.Comparison
                    Outcome = $_.Data.Outcome; Measurement = $_.Data.Measurement; TimePoint = $_.Data.TimePoint
                    SourceRecordId = $_.RecordId }
            })
        }
        'META_CODING_TABLE' {
            @($rows | Where-Object { $_.RecordType -eq 'META_CODING' } | ForEach-Object {
                [pscustomobject]@{ ProjectId = $_.ProjectId; LibraryId = $_.LibraryId; Outcome = $_.Data.Outcome
                    Comparison = $_.Data.Comparison; EffectSize = $_.Data.EffectSize; EffectSizeType = $_.Data.EffectSizeType
                    SampleSize = $_.Data.SampleSize; Moderator = $_.Data.Moderator; StudyArm = $_.Data.StudyArm
                    Measurement = $_.Data.Measurement; TimePoint = $_.Data.TimePoint
                    StatisticalInputs = $_.Data.StatisticalInputs; SourceRecordId = $_.RecordId }
            })
        }
        'EFFECT_SIZE_TABLE' {
            @($rows | Where-Object { $_.RecordType -eq 'EFFECT' } | ForEach-Object {
                [pscustomobject]@{ ProjectId = $_.ProjectId; LibraryId = $_.LibraryId; EffectSizeId = $_.EffectSizeId
                    Outcome = $_.Data.Outcome; Comparison = $_.Data.Comparison; TimePoint = $_.Data.TimePoint
                    EffectType = $_.Data.EffectType; EffectOrigin = $_.Data.EffectOrigin; Effect = $_.Data.Effect
                    Variance = $_.Data.Variance; SE = $_.Data.SE; N = $_.Data.N
                    DirectionState = $_.Data.DirectionState; DependencyGroupId = $_.Data.DependencyGroupId
                    AnalysisInclusion = $_.Data.AnalysisInclusion; Transformation = $_.Data.Transformation
                    Provenance = $_.Lineage }
            })
        }
        'SYNTHESIS_RESULT_TABLE' { @($rows | Where-Object { $_.RecordType -eq 'ANALYSIS' } | ForEach-Object { $_.Data }) }
        'HETEROGENEITY_TABLE' {
            @($rows | Where-Object { $_.RecordType -eq 'ANALYSIS' } | ForEach-Object {
                [pscustomobject]@{ AnalysisId = $_.AnalysisId; Q = $_.Data.Q; I2 = $_.Data.I2; Tau2 = $_.Data.Tau2 }
            })
        }
        'MODERATOR_SUBGROUP_TABLE' { @($rows | Where-Object { $_.RecordType -eq 'MODERATOR' } | ForEach-Object { $_.Data }) }
        'SENSITIVITY_TABLE' { @($rows | Where-Object { $_.RecordType -eq 'SENSITIVITY' } | ForEach-Object { $_.Data }) }
        'PUBLICATION_BIAS_DIAGNOSTIC_TABLE' {
            @($rows | Where-Object { $_.RecordType -eq 'BIAS_DIAGNOSTIC' } | ForEach-Object {
                [pscustomobject]@{ AnalysisId = $_.AnalysisId; Points = $_.Data.Points; Interpretation = $null }
            })
        }
        'SCREENING_FLOW_DATA' { @($rows | Where-Object { $_.RecordType -eq 'SCREENING' } | ForEach-Object { $_.Data }) }
        'EVIDENCE_SUMMARY_TABLE' {
            @($rows | Where-Object { $_.RecordType -eq 'EVIDENCE' } | ForEach-Object {
                [pscustomobject]@{ RecordId = $_.RecordId; Status = $_.EvidenceStatus; Value = $_.Data.Value; Lineage = $_.Lineage }
            })
        }
        'FIGURE_DATASET' {
            [pscustomobject]@{
                AnalysisId = $Specification.AnalysisId
                Effects = @($rows | Where-Object { $_.RecordType -eq 'EFFECT' } | ForEach-Object {
                    [pscustomobject]@{ LibraryId = $_.LibraryId; EffectSizeId = $_.EffectSizeId; Effect = $_.Data.Effect
                        Lower = $_.Data.Lower; Upper = $_.Data.Upper; SE = $_.Data.SE
                        Weight = $_.Data.Weight; Subgroup = $_.Data.Subgroup }
                })
                Pooled = @($rows | Where-Object { $_.RecordType -eq 'ANALYSIS' } | ForEach-Object { $_.Data })
            }
        }
        default { throw 'OUTPUT_TYPE_REQUIRES_SPECIAL_BUILDER' }
    }
    if ($Specification.OutputType -eq 'SCREENING_FLOW_DATA' -and @($data).Count -eq 0) {
        return [pscustomobject]@{ Status = 'MISSING_REQUIRED_DATA'; MissingRequirements = @('SCREENING_HISTORY'); ArtifactType = $Specification.OutputType }
    }
    $content = [ordered]@{ OutputType = $Specification.OutputType; ProjectId = $Specification.ProjectId; AnalysisId = $Specification.AnalysisId; Data = $data }
    $hash = Get-RapOutputHash $content
    $lineage = [pscustomobject]@{
        OutputSpecId = $Specification.OutputSpecId; OutputDatasetId = $Dataset.OutputDatasetId
        SourceRecordIds = @($Dataset.SourceRecordIds)
        AnalysisIds = @($rows.AnalysisId | Where-Object { $_ } | Sort-Object -Unique)
        EffectSizeIds = @($rows.EffectSizeId | Where-Object { $_ } | Sort-Object -Unique)
        Upstream = @($rows.Lineage | Where-Object { $_ })
    }
    return [pscustomobject]@{
        ArtifactId = "ART-$($hash.Substring(0,24))"; OutputSpecId = $Specification.OutputSpecId
        OutputDatasetId = $Dataset.OutputDatasetId; ProjectId = $Specification.ProjectId; ArtifactType = $Specification.OutputType
        ArtifactVersion = $Specification.ConfigHash.Substring(0,12); AnalysisId = $Specification.AnalysisId
        ArtifactRecordId = "ART-$($hash.Substring(0,24))@$($Specification.ConfigHash.Substring(0,12))"
        SourceDatasetHash = $Dataset.SourceDatasetHash; OutputConfigHash = $Specification.ConfigHash
        GeneratorVersion = $Specification.GeneratorVersion; Content = $content; ContentHash = $hash
        Lineage = $lineage; Status = 'READY'; GeneratedAt = [DateTimeOffset]::UtcNow.ToString('o'); ProductionWrite = 'DISABLED'
    }
}

function New-RapFactualResultStatement {
    param($AnalysisRecord)
    if ($AnalysisRecord.VerificationState -ne 'RESEARCHER_CONFIRMED') { throw 'OUTPUT_SOURCE_NOT_VERIFIED' }
    return [pscustomobject]@{
        Ownership = 'SYSTEM_GENERATED_FACT'
        Text = "The $($AnalysisRecord.Data.Model.ToLowerInvariant()) analysis included $($AnalysisRecord.Data.StudyCount) studies and $($AnalysisRecord.Data.EffectCount) effects. The pooled effect was $($AnalysisRecord.Data.PooledEstimate) with a 95% confidence interval from $($AnalysisRecord.Data.ConfidenceLow) to $($AnalysisRecord.Data.ConfidenceHigh)."
        Interpretation = $null
    }
}

function New-RapReproducibilityManifest {
    param($Specification, $Dataset, [object[]]$Artifacts)
    foreach ($artifact in $Artifacts) {
        $actualHash = Get-RapOutputHash $artifact.Content
        if ($artifact.ContentHash -ne $actualHash) { throw "ARTIFACT_CONTENT_TAMPERED: $($artifact.ArtifactId)" }
        if ($artifact.ProjectId -ne $Specification.ProjectId -or
            $artifact.OutputSpecId -ne $Specification.OutputSpecId -or
            $artifact.OutputDatasetId -ne $Dataset.OutputDatasetId) {
            throw "MANIFEST_ARTIFACT_CONTEXT_MISMATCH: $($artifact.ArtifactId)"
        }
    }
    $body = [ordered]@{
        ManifestVersion = 'spr-010.1'; ProjectId = $Specification.ProjectId; OutputSpecId = $Specification.OutputSpecId
        OutputDatasetId = $Dataset.OutputDatasetId; SourceDatasetHash = $Dataset.SourceDatasetHash
        OutputConfigHash = $Specification.ConfigHash
        AnalysisIds = @($Artifacts.AnalysisId | Where-Object { $_ } | Sort-Object -Unique)
        AnalysisConfigHashes = @($Dataset.Rows | Where-Object { $_.RecordType -eq 'ANALYSIS' } | ForEach-Object { $_.Data.ConfigurationHash })
        AnalysisEngineVersions = @($Dataset.Rows | Where-Object { $_.RecordType -eq 'ANALYSIS' } | ForEach-Object { $_.Data.EngineVersion })
        OutputGeneratorVersion = $Specification.GeneratorVersion; SchemaVersion = $Specification.SchemaVersion
        SourceRecordCount = @($Dataset.Rows).Count
        Artifacts = @($Artifacts | ForEach-Object { [pscustomobject]@{ ArtifactId = $_.ArtifactId; ArtifactRecordId = $_.ArtifactRecordId; ArtifactVersion = $_.ArtifactVersion; ContentHash = $_.ContentHash; ArtifactType = $_.ArtifactType } })
    }
    $hash = Get-RapOutputHash $body
    return [pscustomobject]@{ ManifestId = "MAN-$($hash.Substring(0,24))"; Body = [pscustomobject]$body; ContentHash = $hash; GeneratedAt = [DateTimeOffset]::UtcNow.ToString('o'); Status = 'READY' }
}

function New-RapExportPackage {
    param($Specification, $Dataset, [object[]]$Artifacts, $Manifest, [object[]]$RequestedExtras = @())
    foreach ($extra in $RequestedExtras) {
        $name = [string]$extra.Name
        if ($name -match '(?i)(api.?key|token|credential|connection.?string|private.?notes)' -or $name -match '(?i)\.pdf$') {
            throw 'EXPORT_PRIVATE_CONTENT_BLOCKED'
        }
    }
    if ((Get-RapOutputHash $Manifest.Body) -ne $Manifest.ContentHash) { throw 'MANIFEST_CONTENT_TAMPERED' }
    foreach ($artifact in $Artifacts) {
        if ((Get-RapOutputHash $artifact.Content) -ne $artifact.ContentHash) { throw "ARTIFACT_CONTENT_TAMPERED: $($artifact.ArtifactId)" }
    }
    $body = [ordered]@{
        ProjectId = $Specification.ProjectId; OutputSpecId = $Specification.OutputSpecId; DatasetId = $Dataset.OutputDatasetId
        ManifestId = $Manifest.ManifestId; ManifestContentHash = $Manifest.ContentHash
        GeneratorVersion = $Specification.GeneratorVersion; SchemaVersion = $Specification.SchemaVersion
        Artifacts = @($Artifacts | ForEach-Object { [pscustomobject]@{ ArtifactId = $_.ArtifactId; ArtifactRecordId = $_.ArtifactRecordId; ArtifactVersion = $_.ArtifactVersion; ContentHash = $_.ContentHash } })
        ExcludedByDefault = @('CANONICAL_PDF', 'CREDENTIALS', 'API_TOKENS', 'PRIVATE_RESEARCHER_NOTES')
    }
    $hash = Get-RapOutputHash $body
    return [pscustomobject]@{ PackageId = "PKG-$($hash.Substring(0,24))"; ProjectId = $Specification.ProjectId; GeneratorVersion = $Specification.GeneratorVersion; Body = [pscustomobject]$body; ContentHash = $hash; ValidationStatus = 'READY'; Status = 'READY'; ProductionWrite = 'DISABLED' }
}

function Test-RapOutputPackage {
    param($Package, [object[]]$Artifacts, $Manifest)
    $errors = [Collections.Generic.List[string]]::new()
    if ((Get-RapOutputHash $Package.Body) -ne $Package.ContentHash) { $errors.Add('PACKAGE_CONTENT_HASH_MISMATCH') }
    if ($Package.Body.ManifestId -ne $Manifest.ManifestId) { $errors.Add('MANIFEST_MISSING') }
    if ((Get-RapOutputHash $Manifest.Body) -ne $Manifest.ContentHash -or $Package.Body.ManifestContentHash -ne $Manifest.ContentHash) {
        $errors.Add('MANIFEST_HASH_MISMATCH')
    }
    foreach ($listedArtifact in $Package.Body.Artifacts) {
        $actual = $Artifacts | Where-Object { $_.ArtifactId -eq $listedArtifact.ArtifactId } | Select-Object -First 1
        if (-not $actual) { $errors.Add("ARTIFACT_MISSING:$($listedArtifact.ArtifactId)") }
        else {
            $actualContentHash = Get-RapOutputHash $actual.Content
            if ($actualContentHash -ne $actual.ContentHash -or $actual.ContentHash -ne $listedArtifact.ContentHash) {
                $errors.Add("HASH_MISMATCH:$($listedArtifact.ArtifactId)")
            }
            if ($actual.ProjectId -ne $Package.Body.ProjectId) { $errors.Add("PROJECT_MISMATCH:$($listedArtifact.ArtifactId)") }
        }
    }
    return [pscustomobject]@{ Valid = $errors.Count -eq 0; Status = $(if ($errors.Count) { 'FAILED' } else { 'READY' }); Errors = @($errors) }
}

function Test-RapOutputStale {
    param($Artifact, [string]$CurrentDatasetHash, [string]$CurrentConfigHash, [string]$ProjectId)
    if ($Artifact.ProjectId -ne $ProjectId) { return 'NOT_APPLICABLE' }
    if ($Artifact.SourceDatasetHash -ne $CurrentDatasetHash -or $Artifact.OutputConfigHash -ne $CurrentConfigHash) { return 'STALE' }
    return 'CURRENT'
}

function Invoke-RapOutputGeneration {
    param($Specification, $Dataset, $Artifact, $Manifest, [string]$OperationId, $Dependencies)
    foreach ($name in @('GetOperation', 'CommitGeneration')) {
        if ($Dependencies.$name -isnot [scriptblock]) { throw "OUTPUT_DEPENDENCY_REQUIRED:$name" }
    }
    if ((Get-RapOutputHash $Artifact.Content) -ne $Artifact.ContentHash) { throw 'ARTIFACT_CONTENT_TAMPERED' }
    if ((Get-RapOutputHash $Manifest.Body) -ne $Manifest.ContentHash) { throw 'MANIFEST_CONTENT_TAMPERED' }
    if ($Artifact.ProjectId -ne $Specification.ProjectId -or $Artifact.OutputDatasetId -ne $Dataset.OutputDatasetId) {
        throw 'OUTPUT_GENERATION_CONTEXT_MISMATCH'
    }
    $payloadHash = Get-RapOutputHash ([ordered]@{ Spec = $Specification.ConfigHash; Dataset = $Dataset.SourceDatasetHash; Artifact = $Artifact.ContentHash })
    $existing = & $Dependencies.GetOperation $OperationId
    if ($existing -and $existing.PayloadHash -ne $payloadHash) { throw 'PAYLOAD_CONFLICT' }
    if ($existing -and $existing.State -eq 'COMPLETED') {
        return [pscustomobject]@{ Status = 'ALREADY_COMPLETED'; Artifact = $existing.Artifact; ProductionWrite = 'DISABLED' }
    }
    $audit = [pscustomobject]@{
        OperationId = $OperationId; ProjectId = $Specification.ProjectId; OutputSpecId = $Specification.OutputSpecId
        ArtifactId = $Artifact.ArtifactId; DatasetHash = $Dataset.SourceDatasetHash; ConfigHash = $Specification.ConfigHash
        GeneratorVersion = $Specification.GeneratorVersion; Status = 'COMPLETED'
        Warnings = @($Dataset.Warnings); Errors = @(); Timestamp = [DateTimeOffset]::UtcNow.ToString('o')
    }
    $operation = [pscustomobject]@{ OperationId = $OperationId; PayloadHash = $payloadHash; State = 'COMPLETED'; Artifact = $Artifact }
    & $Dependencies.CommitGeneration $Specification $Dataset $Artifact $Manifest $operation $audit
    return [pscustomobject]@{ Status = 'COMPLETED'; Artifact = $Artifact; ProductionWrite = 'DISABLED' }
}

Export-ModuleMember -Function New-RapOutputSpecification, New-RapOutputDataset, New-RapResearchArtifact, New-RapFactualResultStatement, New-RapReproducibilityManifest, New-RapExportPackage, Test-RapOutputPackage, Test-RapOutputStale, Invoke-RapOutputGeneration
