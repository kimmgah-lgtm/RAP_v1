Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot '../ResearchAutomation.Local/modules/Queue.psm1') -Force

function Initialize-RapOutputStore {
    param([string]$DatabasePath)
    Import-Module (Join-Path $PSScriptRoot '../ResearchAutomation.Local/modules/Queue.psm1') -Force
    $path = Initialize-RapQueue $DatabasePath 5000
    [Rap.NativeSqlite]::Execute(
        $path,
        'CREATE TABLE IF NOT EXISTS OutputState(Id INTEGER PRIMARY KEY CHECK(Id=1),Payload TEXT NOT NULL);CREATE TABLE IF NOT EXISTS OutputAudit(Id INTEGER PRIMARY KEY AUTOINCREMENT,Payload TEXT NOT NULL);',
        5000
    )
    return $path
}

function New-RapOutputSqliteDependencies {
    param([string]$DatabasePath)
    $path = Initialize-RapOutputStore $DatabasePath
    $encode = {
        param($Value)
        $json = $Value | ConvertTo-Json -Depth 80 -Compress
        [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($json))
    }.GetNewClosure()
    $decode = {
        param($Value)
        if (-not $Value) { return $null }
        $json = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($Value))
        $json | ConvertFrom-Json -Depth 80
    }.GetNewClosure()
    $read = {
        $value = [Rap.NativeSqlite]::Scalar($path, 'SELECT Payload FROM OutputState WHERE Id=1;', 5000)
        $state = if ($value) { & $decode $value }
        else { [pscustomobject]@{ Specifications = @(); Datasets = @(); Artifacts = @(); Manifests = @(); Packages = @() } }
        if (-not $state.PSObject.Properties['Packages']) { $state | Add-Member -NotePropertyName Packages -NotePropertyValue @() }
        return $state
    }.GetNewClosure()
    $write = {
        param($State)
        $value = & $encode $State
        [Rap.NativeSqlite]::Execute($path, "INSERT OR REPLACE INTO OutputState(Id,Payload) VALUES(1,'$value');", 5000)
    }.GetNewClosure()
    $getOperation = {
        param($OperationId)
        $value = [Rap.NativeSqlite]::Scalar($path, "SELECT Payload FROM Operations WHERE OperationKey='$OperationId' AND Type='Output';", 5000)
        & $decode $value
    }.GetNewClosure()
    $saveOperation = {
        param($Operation)
        $value = & $encode $Operation
        $now = [DateTimeOffset]::UtcNow.ToString('o')
        [Rap.NativeSqlite]::Execute(
            $path,
            "INSERT OR REPLACE INTO Operations(OperationKey,Type,Payload,Status,CreatedUtc,UpdatedUtc) VALUES('$($Operation.OperationId)','Output','$value','$($Operation.State)','$now','$now');",
            5000
        )
    }.GetNewClosure()
    $saveEntity = {
        param($Kind, $Item, $IdProperty)
        $state = & $read
        $property = "${Kind}s"
        $items = @($state.$property | Where-Object { $_.$IdProperty -ne $Item.$IdProperty }) + @($Item)
        $state.$property = $items
        & $write $state
    }.GetNewClosure()
    $appendAudit = {
        param($Audit)
        $value = & $encode $Audit
        [Rap.NativeSqlite]::Execute($path, "INSERT INTO OutputAudit(Payload) VALUES('$value');", 5000)
    }.GetNewClosure()
    $commitGeneration = {
        param($Specification, $Dataset, $Artifact, $Manifest, $Operation, $Audit)
        $state = & $read
        $state.Specifications = @($state.Specifications | Where-Object { $_.OutputSpecId -ne $Specification.OutputSpecId }) + @($Specification)
        $state.Datasets = @($state.Datasets | Where-Object { $_.OutputDatasetId -ne $Dataset.OutputDatasetId }) + @($Dataset)
        $state.Artifacts = @($state.Artifacts | Where-Object { $_.ArtifactRecordId -ne $Artifact.ArtifactRecordId }) + @($Artifact)
        $state.Manifests = @($state.Manifests | Where-Object { $_.ManifestId -ne $Manifest.ManifestId }) + @($Manifest)
        $stateValue = & $encode $state
        $operationValue = & $encode $Operation
        $auditValue = & $encode $Audit
        $now = [DateTimeOffset]::UtcNow.ToString('o')
        $sql = "BEGIN IMMEDIATE;INSERT OR REPLACE INTO OutputState(Id,Payload) VALUES(1,'$stateValue');INSERT INTO OutputAudit(Payload) VALUES('$auditValue');INSERT OR REPLACE INTO Operations(OperationKey,Type,Payload,Status,CreatedUtc,UpdatedUtc) VALUES('$($Operation.OperationId)','Output','$operationValue','$($Operation.State)','$now','$now');COMMIT;"
        [Rap.NativeSqlite]::Execute($path, $sql, 5000)
    }.GetNewClosure()
    $readLastAudit = {
        $value = [Rap.NativeSqlite]::Scalar($path, 'SELECT Payload FROM OutputAudit ORDER BY Id DESC LIMIT 1;', 5000)
        & $decode $value
    }.GetNewClosure()
    return [pscustomobject]@{
        GetOperation = $getOperation
        SaveOperation = $saveOperation
        SaveSpecification = { param($Value) & $saveEntity 'Specification' $Value 'OutputSpecId' }.GetNewClosure()
        SaveDataset = { param($Value) & $saveEntity 'Dataset' $Value 'OutputDatasetId' }.GetNewClosure()
        SaveArtifact = { param($Value) & $saveEntity 'Artifact' $Value 'ArtifactRecordId' }.GetNewClosure()
        SaveManifest = { param($Value) & $saveEntity 'Manifest' $Value 'ManifestId' }.GetNewClosure()
        SavePackage = { param($Value) & $saveEntity 'Package' $Value 'PackageId' }.GetNewClosure()
        AppendAudit = $appendAudit
        CommitGeneration = $commitGeneration
        ReadLastAudit = $readLastAudit
        ReadState = $read
    }
}

function Get-RapOutputSnapshot {
    param([string]$DatabasePath)
    $dependencies = New-RapOutputSqliteDependencies $DatabasePath
    $state = & $dependencies.ReadState
    $auditCount = [int][Rap.NativeSqlite]::Scalar($DatabasePath, 'SELECT COUNT(*) FROM OutputAudit;', 5000)
    $state | Add-Member -NotePropertyName AuditCount -NotePropertyValue $auditCount -Force
    $state | Add-Member -NotePropertyName LastAudit -NotePropertyValue (& $dependencies.ReadLastAudit) -Force
    return $state
}

function Save-RapOutputPackage {
    param($Package, $Dependencies)
    if ($Dependencies.SavePackage -isnot [scriptblock]) { throw 'OUTPUT_DEPENDENCY_REQUIRED:SavePackage' }
    if ($Package.Status -ne 'READY' -or $Package.ValidationStatus -ne 'READY') { throw 'OUTPUT_PACKAGE_NOT_VALIDATED' }
    & $Dependencies.SavePackage $Package
    return $Package
}

Export-ModuleMember -Function Initialize-RapOutputStore, New-RapOutputSqliteDependencies, Get-RapOutputSnapshot, Save-RapOutputPackage
