Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot '../ResearchAutomation.Local/modules/Queue.psm1') -Force -ErrorAction Stop

function ConvertTo-RapMetaStoreText {
    param($Value)
    $json = $Value | ConvertTo-Json -Depth 50 -Compress
    [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($json))
}

function ConvertFrom-RapMetaStoreText {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
    [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($Value)) | ConvertFrom-Json -Depth 50
}

function Assert-RapMetaStoreToken {
    param([string]$Value,[string]$Name,[string]$Pattern)
    if ($Value -notmatch $Pattern) { throw "Invalid $Name for Meta Coding store." }
}

function Invoke-RapMetaStoreExecute {
    param([string]$DatabasePath,[string]$Sql,[int]$BusyTimeoutMilliseconds=5000)
    Queue\Initialize-RapQueue -DatabasePath $DatabasePath -BusyTimeoutMilliseconds $BusyTimeoutMilliseconds | Out-Null
    [Rap.NativeSqlite]::Execute([IO.Path]::GetFullPath($DatabasePath),$Sql,$BusyTimeoutMilliseconds)
}

function Initialize-RapMetaCodingStore {
    <# .SYNOPSIS Adds project/meta-coding tables to the existing RAP SQLite queue database. #>
    [CmdletBinding()]param(
        [Parameter(Mandatory)][string]$DatabasePath,
        [ValidateRange(0,60000)][int]$BusyTimeoutMilliseconds=5000
    )
    $schema=@'
PRAGMA foreign_keys=ON;
CREATE TABLE IF NOT EXISTS ProjectRegistry (ProjectId TEXT PRIMARY KEY, Name TEXT NOT NULL, CreatedUtc TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS ProjectPaperMap (ScopeKey TEXT PRIMARY KEY, LibraryId TEXT NOT NULL, ProjectId TEXT NOT NULL, CreatedUtc TEXT NOT NULL, FOREIGN KEY(ProjectId) REFERENCES ProjectRegistry(ProjectId));
CREATE UNIQUE INDEX IF NOT EXISTS IX_ProjectPaperMap_Identity ON ProjectPaperMap(LibraryId, ProjectId);
CREATE TABLE IF NOT EXISTS MetaCodingRecords (ScopeKey TEXT PRIMARY KEY, LibraryId TEXT NOT NULL, ProjectId TEXT NOT NULL, RecordPayload TEXT NOT NULL, UpdatedUtc TEXT NOT NULL, FOREIGN KEY(ScopeKey) REFERENCES ProjectPaperMap(ScopeKey));
CREATE TABLE IF NOT EXISTS MetaCodingAudit (Id INTEGER PRIMARY KEY AUTOINCREMENT, ScopeKey TEXT NOT NULL, EventPayload TEXT NOT NULL, CreatedUtc TEXT NOT NULL);
'@
    Invoke-RapMetaStoreExecute $DatabasePath $schema $BusyTimeoutMilliseconds
    [IO.Path]::GetFullPath($DatabasePath)
}

function Register-RapMetaCodingProjectFixture {
    <# .SYNOPSIS Registers deterministic fixture-only Project and Project-Paper identities. #>
    [CmdletBinding()]param(
        [Parameter(Mandatory)][string]$DatabasePath,
        [Parameter(Mandatory)][ValidatePattern('^PR\d{3}$')][string]$ProjectId,
        [Parameter(Mandatory)][ValidatePattern('^LIB:L\d{6}$')][string]$LibraryId,
        [string]$Name='Fixture Project',
        [ValidateRange(0,60000)][int]$BusyTimeoutMilliseconds=5000
    )
    Initialize-RapMetaCodingStore $DatabasePath $BusyTimeoutMilliseconds | Out-Null
    $scopeKey="$LibraryId|$ProjectId"
    $name64=ConvertTo-RapMetaStoreText $Name
    $now=[DateTimeOffset]::UtcNow.ToString('o')
    $sql="INSERT OR IGNORE INTO ProjectRegistry(ProjectId,Name,CreatedUtc) VALUES('$ProjectId','$name64','$now');INSERT OR IGNORE INTO ProjectPaperMap(ScopeKey,LibraryId,ProjectId,CreatedUtc) VALUES('$scopeKey','$LibraryId','$ProjectId','$now');"
    Invoke-RapMetaStoreExecute $DatabasePath $sql $BusyTimeoutMilliseconds
    [pscustomobject]@{LibraryId=$LibraryId;ProjectId=$ProjectId;ScopeKey=$scopeKey}
}

function New-RapMetaCodingSqliteDependencies {
    <#
    .SYNOPSIS Creates fixture/local SQLite dependencies using RAP's existing Operations ledger.
    .DESCRIPTION No external service is contacted. The extractor must be deterministic and injected by the caller.
    #>
    [CmdletBinding()]param(
        [Parameter(Mandatory)][string]$DatabasePath,
        [Parameter(Mandatory)][scriptblock]$ExtractAssistedCoding,
        [ValidateRange(0,60000)][int]$BusyTimeoutMilliseconds=5000
    )
    $resolved=Initialize-RapMetaCodingStore $DatabasePath $BusyTimeoutMilliseconds
    $execute={param($sql)[Rap.NativeSqlite]::Execute($resolved,$sql,$BusyTimeoutMilliseconds)}.GetNewClosure()
    $encode=${function:ConvertTo-RapMetaStoreText}
    $decode=${function:ConvertFrom-RapMetaStoreText}
    $assertToken=${function:Assert-RapMetaStoreToken}
    $scalar={param($sql)[Rap.NativeSqlite]::Scalar($resolved,$sql,$BusyTimeoutMilliseconds)}.GetNewClosure()
    $getProjectPaper={
        param($libraryId,$projectId)
        $scope="$libraryId|$projectId"
        $count=& $scalar "SELECT COUNT(*) FROM ProjectPaperMap WHERE ScopeKey='$scope';"
        if([int]$count -eq 1){[pscustomobject]@{LibraryId=$libraryId;ProjectId=$projectId;ScopeKey=$scope}}else{$null}
    }.GetNewClosure()
    $getOperation={
        param($operationId)
        & $assertToken $operationId 'OperationId' '^[A-Za-z0-9._:-]+$'
        $value=& $scalar "SELECT Payload FROM Operations WHERE OperationKey='$operationId' AND Type='MetaCoding';"
        & $decode $value
    }.GetNewClosure()
    $saveOperation={
        param($operation)
        & $assertToken ([string]$operation.OperationId) 'OperationId' '^[A-Za-z0-9._:-]+$'
        $payload=& $encode $operation
        $now=[DateTimeOffset]::UtcNow.ToString('o')
        $id=[string]$operation.OperationId;$status=[string]$operation.State
        $sql="INSERT OR IGNORE INTO Operations(OperationKey,Type,Payload,Status,CreatedUtc,UpdatedUtc) VALUES('$id','MetaCoding','$payload','$status','$now','$now');UPDATE Operations SET Payload='$payload',Status='$status',UpdatedUtc='$now' WHERE OperationKey='$id' AND Type='MetaCoding';"
        & $execute $sql
    }.GetNewClosure()
    $getExistingCoding={
        param($libraryId,$projectId)
        $scope="$libraryId|$projectId"
        $value=& $scalar "SELECT RecordPayload FROM MetaCodingRecords WHERE ScopeKey='$scope';"
        & $decode $value
    }.GetNewClosure()
    $upsertProjectCoding={
        param($record)
        $scope=[string]$record.ScopeKey;$library=[string]$record.LibraryId;$project=[string]$record.ProjectId
        $payload=& $encode $record;$now=[DateTimeOffset]::UtcNow.ToString('o')
        $sql="INSERT OR REPLACE INTO MetaCodingRecords(ScopeKey,LibraryId,ProjectId,RecordPayload,UpdatedUtc) VALUES('$scope','$library','$project','$payload','$now');"
        & $execute $sql
        [pscustomobject]@{Status='UPSERTED';ScopeKey=$scope}
    }.GetNewClosure()
    $appendAudit={
        param($record)
        $scope=[string]$record.ScopeKey;$payload=& $encode $record;$now=[DateTimeOffset]::UtcNow.ToString('o')
        & $execute "INSERT INTO MetaCodingAudit(ScopeKey,EventPayload,CreatedUtc) VALUES('$scope','$payload','$now');"
    }.GetNewClosure()
    [pscustomobject]@{
        GetProjectPaper=$getProjectPaper;GetOperation=$getOperation;SaveOperation=$saveOperation
        ExtractAssistedCoding=$ExtractAssistedCoding;GetExistingCoding=$getExistingCoding
        UpsertProjectCoding=$upsertProjectCoding;AppendAudit=$appendAudit
    }
}

function Get-RapMetaCodingFixtureRecord {
    [CmdletBinding()]param(
        [Parameter(Mandatory)][string]$DatabasePath,
        [Parameter(Mandatory)][ValidatePattern('^LIB:L\d{6}$')][string]$LibraryId,
        [Parameter(Mandatory)][ValidatePattern('^PR\d{3}$')][string]$ProjectId,
        [ValidateRange(0,60000)][int]$BusyTimeoutMilliseconds=5000
    )
    Initialize-RapMetaCodingStore $DatabasePath $BusyTimeoutMilliseconds | Out-Null
    $scope="$LibraryId|$ProjectId"
    $value=Queue\Invoke-RapQueueScalar $DatabasePath "SELECT RecordPayload FROM MetaCodingRecords WHERE ScopeKey='$scope';" $BusyTimeoutMilliseconds
    ConvertFrom-RapMetaStoreText $value
}

Export-ModuleMember -Function Initialize-RapMetaCodingStore,Register-RapMetaCodingProjectFixture,New-RapMetaCodingSqliteDependencies,Get-RapMetaCodingFixtureRecord
