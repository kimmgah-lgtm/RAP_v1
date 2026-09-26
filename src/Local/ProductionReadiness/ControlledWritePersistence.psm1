Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../ResearchAutomation.Local/modules/Queue.psm1') -Force

function ConvertTo-RapControlledWriteSqlLiteral {
    param([AllowNull()][string]$Value)
    if ($null -eq $Value) { return 'NULL' }
    "'" + $Value.Replace("'", "''") + "'"
}

function ConvertTo-RapControlledWriteStoreText {
    param([Parameter(Mandatory)]$Value)
    [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($Value | ConvertTo-Json -Depth 80 -Compress)))
}

function ConvertFrom-RapControlledWriteStoreText {
    param([Parameter(Mandatory)][string]$Value)
    [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($Value)) | ConvertFrom-Json -Depth 80
}

function Get-RapControlledWriteStoreHash {
    param([Parameter(Mandatory)]$Value)
    $json = $Value | ConvertTo-Json -Depth 80 -Compress
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($json))).ToLowerInvariant()
}

function Get-RapControlledWriteStoreTextHash {
    param([Parameter(Mandatory)][string]$Text)
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($Text))).ToLowerInvariant()
}

function Get-RapControlledWriteRecordBody {
    param([Parameter(Mandatory)]$Record)
    [ordered]@{
        OperationId = [string]$Record.OperationId
        PlanHash = [string]$Record.PlanHash
        LibraryId = [string]$Record.LibraryId
        ProjectId = [string]$Record.ProjectId
        TargetSystem = [string]$Record.TargetSystem
        TargetObject = [string]$Record.TargetObject
        TargetField = [string]$Record.TargetField
        PayloadHash = [string]$Record.PayloadHash
        ApprovalBinding = $Record.ApprovalBinding
        State = [string]$Record.State
        BeforeHash = [string]$Record.BeforeHash
        BeforeVersion = [string]$Record.BeforeVersion
        ApplyResult = $Record.ApplyResult
        ReadBackResult = $Record.ReadBackResult
        VerificationResult = $Record.VerificationResult
        CreatedAt = [string]$Record.CreatedAt
        UpdatedAt = [string]$Record.UpdatedAt
        AuditTrail = @($Record.AuditTrail)
        ProductionWrite = [string]$Record.ProductionWrite
    }
}

function Initialize-RapControlledWriteStore {
    [CmdletBinding()]param([Parameter(Mandatory)][string]$DatabasePath)
    $path = Initialize-RapQueue $DatabasePath 5000
    [Rap.NativeSqlite]::Execute($path, 'CREATE TABLE IF NOT EXISTS ControlledWriteOperations(OperationId TEXT PRIMARY KEY,Payload TEXT NOT NULL,RecordHash TEXT NOT NULL,State TEXT NOT NULL,UpdatedUtc TEXT NOT NULL);', 5000)
    $path
}

function Set-RapControlledWritePersistedOperation {
    [CmdletBinding()]param([Parameter(Mandatory)][string]$DatabasePath,[Parameter(Mandatory)]$Record)
    $path = Initialize-RapControlledWriteStore $DatabasePath
    if ([string]$Record.OperationId -notmatch '^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$') { throw 'INVALID_PERSISTED_OPERATION_ID' }
    if ($Record.ProductionWrite -cne 'DISABLED') { throw 'UNSAFE_PERSISTED_OPERATION' }
    $Record.UpdatedAt = [DateTimeOffset]::UtcNow.ToString('o')
    $body = Get-RapControlledWriteRecordBody $Record
    $bodyJson = $body | ConvertTo-Json -Depth 80 -Compress
    $hash = Get-RapControlledWriteStoreTextHash $bodyJson
    $envelope = [pscustomobject][ordered]@{BodyText=[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($bodyJson));RecordHash=$hash}
    $payload = ConvertTo-RapControlledWriteStoreText $envelope
    $sql = "BEGIN IMMEDIATE;INSERT INTO ControlledWriteOperations(OperationId,Payload,RecordHash,State,UpdatedUtc) VALUES($(ConvertTo-RapControlledWriteSqlLiteral ([string]$Record.OperationId)),'$payload','$hash',$(ConvertTo-RapControlledWriteSqlLiteral ([string]$Record.State)),$(ConvertTo-RapControlledWriteSqlLiteral ([string]$Record.UpdatedAt))) ON CONFLICT(OperationId) DO UPDATE SET Payload=excluded.Payload,RecordHash=excluded.RecordHash,State=excluded.State,UpdatedUtc=excluded.UpdatedUtc;COMMIT;"
    [Rap.NativeSqlite]::Execute($path, $sql, 5000)
    $Record
}

function Get-RapControlledWritePersistedOperation {
    [CmdletBinding()]param([Parameter(Mandatory)][string]$DatabasePath,[Parameter(Mandatory)][string]$OperationId)
    $path = Initialize-RapControlledWriteStore $DatabasePath
    $payload = [Rap.NativeSqlite]::Scalar($path, "SELECT Payload FROM ControlledWriteOperations WHERE OperationId=$(ConvertTo-RapControlledWriteSqlLiteral $OperationId);", 5000)
    if (-not $payload) { return $null }
    try { $envelope = ConvertFrom-RapControlledWriteStoreText $payload } catch { throw 'CONTROLLED_WRITE_PERSISTENCE_CORRUPT' }
    if ($null -eq $envelope -or [string]::IsNullOrWhiteSpace([string]$envelope.BodyText) -or [string]::IsNullOrWhiteSpace([string]$envelope.RecordHash)) { throw 'CONTROLLED_WRITE_PERSISTENCE_CORRUPT' }
    try{$bodyJson=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String([string]$envelope.BodyText))}catch{throw 'CONTROLLED_WRITE_PERSISTENCE_CORRUPT'}
    $actual = Get-RapControlledWriteStoreTextHash $bodyJson
    if ($actual -cne [string]$envelope.RecordHash) { throw 'CONTROLLED_WRITE_PERSISTENCE_CORRUPT' }
    $columnHash = [Rap.NativeSqlite]::Scalar($path, "SELECT RecordHash FROM ControlledWriteOperations WHERE OperationId=$(ConvertTo-RapControlledWriteSqlLiteral $OperationId);", 5000)
    if ($columnHash -cne $actual) { throw 'CONTROLLED_WRITE_PERSISTENCE_CORRUPT' }
    try{$bodyJson|ConvertFrom-Json -Depth 80}catch{throw 'CONTROLLED_WRITE_PERSISTENCE_CORRUPT'}
}

function Enter-RapControlledWritePersistedApply {
    [CmdletBinding()]param([Parameter(Mandatory)][string]$DatabasePath,[Parameter(Mandatory)]$Record,[Parameter(Mandatory)][string]$ClaimId)
    $path=Initialize-RapControlledWriteStore $DatabasePath
    if($Record.State-cne'APPLYING'-or[string]::IsNullOrWhiteSpace($ClaimId)){throw 'INVALID_CONTROLLED_WRITE_APPLY_CLAIM'}
    $currentHash=[Rap.NativeSqlite]::Scalar($path,"SELECT RecordHash FROM ControlledWriteOperations WHERE OperationId=$(ConvertTo-RapControlledWriteSqlLiteral ([string]$Record.OperationId)) AND State='APPROVED';",5000)
    if(-not$currentHash){return $false}
    $Record.UpdatedAt=[DateTimeOffset]::UtcNow.ToString('o');$body=Get-RapControlledWriteRecordBody $Record;$bodyJson=$body|ConvertTo-Json -Depth 80 -Compress;$hash=Get-RapControlledWriteStoreTextHash $bodyJson;$envelope=[pscustomobject][ordered]@{BodyText=[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($bodyJson));RecordHash=$hash};$payload=ConvertTo-RapControlledWriteStoreText $envelope
    $sql="UPDATE ControlledWriteOperations SET Payload='$payload',RecordHash='$hash',State='APPLYING',UpdatedUtc=$(ConvertTo-RapControlledWriteSqlLiteral ([string]$Record.UpdatedAt)) WHERE OperationId=$(ConvertTo-RapControlledWriteSqlLiteral ([string]$Record.OperationId)) AND State='APPROVED' AND RecordHash='$currentHash';"
    [Rap.NativeSqlite]::Execute($path,$sql,5000)
    $claimed=Get-RapControlledWritePersistedOperation $path $Record.OperationId
    $last=@($claimed.AuditTrail)[-1]
    $claimed.State-ceq'APPLYING'-and$last.PSObject.Properties['ClaimId']-and$last.ClaimId-ceq$ClaimId
}

function Test-RapControlledWriteStoreIntegrity {
    [CmdletBinding()]param([Parameter(Mandatory)][string]$DatabasePath)
    $path = Initialize-RapControlledWriteStore $DatabasePath
    if ([Rap.NativeSqlite]::Scalar($path, 'PRAGMA integrity_check;', 5000) -ne 'ok') { return $false }
    $ids = [Rap.NativeSqlite]::Scalar($path, "SELECT group_concat(OperationId,',') FROM (SELECT OperationId FROM ControlledWriteOperations ORDER BY OperationId);", 5000)
    try { foreach ($id in @(if($ids){$ids.Split(',')})) { [void](Get-RapControlledWritePersistedOperation $path $id) }; $true } catch { $false }
}

Export-ModuleMember -Function Initialize-RapControlledWriteStore,Set-RapControlledWritePersistedOperation,Get-RapControlledWritePersistedOperation,Enter-RapControlledWritePersistedApply,Test-RapControlledWriteStoreIntegrity
