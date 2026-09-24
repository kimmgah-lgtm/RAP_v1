Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot '../ResearchAutomation.Local/modules/Queue.psm1') -Force

function Initialize-RapWorkflowExceptionStore {
    [CmdletBinding()]param([Parameter(Mandatory)][string]$DatabasePath)
    Import-Module (Join-Path $PSScriptRoot '../ResearchAutomation.Local/modules/Queue.psm1') -Force
    $path=Initialize-RapQueue $DatabasePath 5000
    [Rap.NativeSqlite]::Execute($path,'CREATE TABLE IF NOT EXISTS WorkflowExceptionState(Id INTEGER PRIMARY KEY CHECK(Id=1),Payload TEXT NOT NULL);CREATE TABLE IF NOT EXISTS WorkflowExceptionAudit(Id INTEGER PRIMARY KEY AUTOINCREMENT,Payload TEXT NOT NULL);',5000)
    return $path
}

function New-RapWorkflowSqliteDependencies {
    [CmdletBinding()]param([Parameter(Mandatory)][string]$DatabasePath)
    $path=Initialize-RapWorkflowExceptionStore $DatabasePath
    $encode={param($value)[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($value|ConvertTo-Json -Depth 80 -Compress)))}.GetNewClosure()
    $decode={param($value)if(!$value){return $null};[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($value))|ConvertFrom-Json -Depth 80}.GetNewClosure()
    $readState={
        $value=[Rap.NativeSqlite]::Scalar($path,'SELECT Payload FROM WorkflowExceptionState WHERE Id=1;',5000)
        if($value){&$decode $value}else{[pscustomobject]@{Exceptions=@();Plans=@();Reconciliations=@();Verifications=@()}}
    }.GetNewClosure()
    $getOperation={param($operationId)$value=[Rap.NativeSqlite]::Scalar($path,"SELECT Payload FROM Operations WHERE OperationKey='$operationId' AND Type='WorkflowException';",5000);&$decode $value}.GetNewClosure()
    $commitWorkflow={param($state,$operation,$audit)
        $stateValue=&$encode $state;$operationValue=&$encode $operation;$auditValue=&$encode $audit;$now=[DateTimeOffset]::UtcNow.ToString('o')
        $sql="BEGIN IMMEDIATE;INSERT OR REPLACE INTO WorkflowExceptionState(Id,Payload) VALUES(1,'$stateValue');INSERT INTO WorkflowExceptionAudit(Payload) VALUES('$auditValue');INSERT OR REPLACE INTO Operations(OperationKey,Type,Payload,Status,CreatedUtc,UpdatedUtc) VALUES('$($operation.OperationId)','WorkflowException','$operationValue','$($operation.State)','$now','$now');COMMIT;"
        [Rap.NativeSqlite]::Execute($path,$sql,5000)
    }.GetNewClosure()
    $readLastAudit={param()$value=[Rap.NativeSqlite]::Scalar($path,'SELECT Payload FROM WorkflowExceptionAudit ORDER BY Id DESC LIMIT 1;',5000);&$decode $value}.GetNewClosure()
    [pscustomobject]@{GetOperation=$getOperation;ReadState=$readState;CommitWorkflow=$commitWorkflow;ReadLastAudit=$readLastAudit;DatabasePath=$path}
}

function Get-RapWorkflowExceptionSnapshot {
    [CmdletBinding()]param([Parameter(Mandatory)][string]$DatabasePath)
    $dependencies=New-RapWorkflowSqliteDependencies $DatabasePath
    $state=&$dependencies.ReadState
    $state|Add-Member -NotePropertyName AuditCount -NotePropertyValue ([int][Rap.NativeSqlite]::Scalar($dependencies.DatabasePath,'SELECT COUNT(*) FROM WorkflowExceptionAudit;',5000)) -Force
    $state|Add-Member -NotePropertyName LastAudit -NotePropertyValue (&$dependencies.ReadLastAudit) -Force
    return $state
}

Export-ModuleMember -Function Initialize-RapWorkflowExceptionStore,New-RapWorkflowSqliteDependencies,Get-RapWorkflowExceptionSnapshot
