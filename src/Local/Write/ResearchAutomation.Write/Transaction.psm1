Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'Backup.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Verification.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Rollback.psm1') -Force

function Write-RapAuditRecord {
    param($Context,$Record)
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $Context.AuditPath));Add-Content -LiteralPath $Context.AuditPath -Value ($Record|ConvertTo-Json -Depth 30 -Compress) -Encoding utf8NoBOM
}

function Invoke-RapWriteTransaction {
    <#
    .SYNOPSIS
    Executes one validated, verifiable, compensating Zotero transaction.
    .DESCRIPTION
    Applies validation, dry-run, snapshot, write, verification, audit, and operation-owned rollback rules.
    .PARAMETER Command
    RAP write command object.
    .PARAMETER Context
    Verified Sandbox write context.
    .PARAMETER DryRun
    Runs validation and planning without applying a write.
    .OUTPUTS
    Transaction result.
    #>
    [CmdletBinding()]param([Parameter(Mandatory)]$Command,[Parameter(Mandatory)]$Context,[switch]$DryRun)
    $started=[DateTimeOffset]::UtcNow;$rollback=$false;$verification=$false;$old=$null;$new=$Command.Payload
    if($Context.LibraryType -ne 'groups' -or $Context.SandboxName -notmatch '(?i)sandbox'){throw 'Transaction refused: target is not a verified Sandbox Library.'}
    if($Context.CompletedOperations.Contains($Command.OperationID)){return [pscustomobject]@{OperationID=$Command.OperationID;Status='ALREADY_EXISTS';Command=$Command.Command;ItemKey=$Command.ItemKey;DryRun=[bool]$DryRun}}
    try{$current=& $Context.GetItem $Command.ItemKey}catch{$current=$null}
    $validation=& $Command.Validate $Command $Context $current
    if(-not $validation.Valid){$result=[pscustomobject]@{OperationID=$Command.OperationID;Status='VALIDATION_FAILED';Command=$Command.Command;ItemKey=$Command.ItemKey;Reason=$validation.Reason;HumanReview=$true};if($Context.QueueSink){& $Context.QueueSink $result};return $result}
    if($validation.Status -eq 'ALREADY_EXISTS'){$Context.CompletedOperations.Add($Command.OperationID)|Out-Null;return [pscustomobject]@{OperationID=$Command.OperationID;Status='ALREADY_EXISTS';Command=$Command.Command;ItemKey=$Command.ItemKey;Reason=$validation.Reason}}
    if($DryRun){return [pscustomobject]@{OperationID=$Command.OperationID;Status='DRY_RUN';Command=$Command.Command;ItemKey=$Command.ItemKey;WouldWrite=$Command.Payload;ChangesApplied=$false}}
    $snapshot=Backup-RapItem $current;$old=$snapshot;$writeResult=$null
    try{
        $writeResult=& $Command.Execute $Command $Context $snapshot
        $actual=& $Context.GetItem $Command.ItemKey
        $verification=[bool](& $Command.Verify $Command $Context $actual $writeResult)
        if(-not $verification){throw 'Verification failed.'}
        $Context.CompletedOperations.Add($Command.OperationID)|Out-Null
        $eventName=@{WriteLibraryId='LibraryIdAssigned';WriteExtra='ExtraUpdated';WriteTag='TagAdded';AddCollection='CollectionAdded';UpdateMetadata='MetadataUpdated';CreateLinkedAttachment='AttachmentLinked'}[$Command.Command]
        if($Context.EventSink){& $Context.EventSink ([pscustomobject]@{OperationID=$Command.OperationID;Event=$eventName;ItemKey=$Command.ItemKey;Timestamp=[DateTimeOffset]::UtcNow.ToString('o')})}
        $result=[pscustomobject]@{OperationID=$Command.OperationID;Status='SUCCESS';Command=$Command.Command;ItemKey=$Command.ItemKey;VerificationResult='PASS';RollbackExecuted=$false}
    }catch{
        try{if($null -ne $snapshot){Invoke-RapRollback $Command $Context $snapshot $writeResult;$rollback=$true}}catch{$rollback=$true}
        $result=[pscustomobject]@{OperationID=$Command.OperationID;Status='ROLLBACK';Command=$Command.Command;ItemKey=$Command.ItemKey;VerificationResult='FAIL';RollbackExecuted=$rollback;Reason=$_.Exception.Message;HumanReview=$true}
        if($Context.QueueSink){& $Context.QueueSink $result};if($Context.EventSink){& $Context.EventSink ([pscustomobject]@{OperationID=$Command.OperationID;Event='RollbackExecuted';ItemKey=$Command.ItemKey;Timestamp=[DateTimeOffset]::UtcNow.ToString('o')})}
    }
    $audit=[ordered]@{Timestamp=[DateTimeOffset]::UtcNow.ToString('o');OperationID=$Command.OperationID;Command=$Command.Command;ItemKey=$Command.ItemKey;OldValue=$old;NewValue=$new;Duration=([DateTimeOffset]::UtcNow-$started).TotalMilliseconds;VerificationResult=$result.VerificationResult;RollbackExecuted=$result.RollbackExecuted;Operator=$Command.Operator;Status=$result.Status;SandboxLibraryId=$Context.LibraryId}
    Write-RapAuditRecord $Context $audit
    return $result
}

function Invoke-RapWriteQueue {
    <#
    .SYNOPSIS
    Executes write command objects sequentially and idempotently.
    .DESCRIPTION
    Sends every command through the same Sandbox transaction pipeline and returns all results.
    #>
    [CmdletBinding()]param([Parameter(Mandatory)][object[]]$Commands,[Parameter(Mandatory)]$Context,[switch]$DryRun)
    @($Commands|ForEach-Object{Invoke-RapWriteTransaction -Command $_ -Context $Context -DryRun:$DryRun})
}
Export-ModuleMember -Function Invoke-RapWriteTransaction,Invoke-RapWriteQueue
