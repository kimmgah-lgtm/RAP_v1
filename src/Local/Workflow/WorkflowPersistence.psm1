Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot '../ResearchAutomation.Local/modules/Queue.psm1') -Force

# SPR-011 Turn E: lifecycle events are stored append-only in a SHA-256 hash chain.
# Each row stores PrevHash and RowHash = SHA256(PrevHash + '|' + event JSON). PrevHash is UNIQUE, so two
# writers cannot fork the chain; WorkflowChainHead anchors the count and last hash so tail deletion is
# detectable. Operation audit rows are bound to the chain through the AuditJsonHash carried by each
# OPERATION_COMPLETED event.
$script:RapWorkflowFaultPoints=@('None','AFTER_STATE','AFTER_AUDIT','AFTER_EVENTS','BEFORE_COMMIT')

function Get-RapWorkflowTextHash {param([string]$Text)[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($Text))).ToLowerInvariant()}
function ConvertTo-RapWorkflowStoreText {param([string]$Json)[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Json))}
function ConvertFrom-RapWorkflowStoreText {param([string]$Value)if([string]::IsNullOrEmpty($Value)){return $null};[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($Value))}
function ConvertTo-RapSqlLiteral {param([string]$Value)if($null-eq$Value){return 'NULL'};"'"+$Value.Replace("'","''")+"'"}

function Initialize-RapWorkflowExceptionStore {
    [CmdletBinding()]param([Parameter(Mandatory)][string]$DatabasePath)
    Import-Module (Join-Path $PSScriptRoot '../ResearchAutomation.Local/modules/Queue.psm1') -Force
    $path=Initialize-RapQueue $DatabasePath 5000
    [Rap.NativeSqlite]::Execute($path,'CREATE TABLE IF NOT EXISTS WorkflowExceptionState(Id INTEGER PRIMARY KEY CHECK(Id=1),Payload TEXT NOT NULL);CREATE TABLE IF NOT EXISTS WorkflowExceptionAudit(Id INTEGER PRIMARY KEY AUTOINCREMENT,Payload TEXT NOT NULL);CREATE TABLE IF NOT EXISTS WorkflowLifecycleEvents(Id INTEGER PRIMARY KEY AUTOINCREMENT,EventType TEXT NOT NULL,ExceptionId TEXT,Payload TEXT NOT NULL,PrevHash TEXT NOT NULL UNIQUE,RowHash TEXT NOT NULL);CREATE TABLE IF NOT EXISTS WorkflowChainHead(Id INTEGER PRIMARY KEY CHECK(Id=1),EventCount INTEGER NOT NULL,LastHash TEXT NOT NULL);',5000)
    return $path
}

function Get-RapWorkflowChainHead {
    param([string]$Path)
    $value=[Rap.NativeSqlite]::Scalar($Path,"SELECT EventCount||'|'||LastHash FROM WorkflowChainHead WHERE Id=1;",5000)
    if(!$value){return [pscustomobject]@{EventCount=0;LastHash='GENESIS'}}
    $parts=$value.Split('|');[pscustomobject]@{EventCount=[int64]$parts[0];LastHash=$parts[1]}
}

function New-RapWorkflowEventSql {
    param([object[]]$Events,$Head)
    $sql=[Text.StringBuilder]::new();$prev=$Head.LastHash;$count=$Head.EventCount
    foreach($event in @($Events|Where-Object{$null-ne$_})){
        $json=$event|ConvertTo-Json -Depth 80 -Compress
        $rowHash=Get-RapWorkflowTextHash "$prev|$json"
        $exceptionId=if($event.PSObject.Properties['ExceptionId']){[string]$event.ExceptionId}else{$null}
        [void]$sql.Append("INSERT INTO WorkflowLifecycleEvents(EventType,ExceptionId,Payload,PrevHash,RowHash) VALUES($(ConvertTo-RapSqlLiteral ([string]$event.EventType)),$(if([string]::IsNullOrEmpty($exceptionId)){'NULL'}else{ConvertTo-RapSqlLiteral $exceptionId}),'$(ConvertTo-RapWorkflowStoreText $json)','$prev','$rowHash');")
        $prev=$rowHash;$count++
    }
    [void]$sql.Append("INSERT INTO WorkflowChainHead(Id,EventCount,LastHash) VALUES(1,$count,'$prev') ON CONFLICT(Id) DO UPDATE SET EventCount=excluded.EventCount,LastHash=excluded.LastHash;")
    $sql.ToString()
}

function New-RapWorkflowSqliteDependencies {
    [CmdletBinding()]param(
        [Parameter(Mandatory)][string]$DatabasePath,
        [string[]]$AuthorizedResearchers=@(),
        [ValidateSet('None','AFTER_STATE','AFTER_AUDIT','AFTER_EVENTS','BEFORE_COMMIT')][string]$FaultPoint='None'
    )
    $path=Initialize-RapWorkflowExceptionStore $DatabasePath
    # GetNewClosure() binds to a dynamic module, so module-private helpers are captured explicitly.
    $fnHead=${function:Get-RapWorkflowChainHead};$fnEventSql=${function:New-RapWorkflowEventSql};$fnToStore=${function:ConvertTo-RapWorkflowStoreText};$fnFromStore=${function:ConvertFrom-RapWorkflowStoreText};$fnLiteral=${function:ConvertTo-RapSqlLiteral}
    $toJson={param($value)$value|ConvertTo-Json -Depth 80 -Compress}.GetNewClosure()
    $encode={param($value)&$fnToStore ($value|ConvertTo-Json -Depth 80 -Compress)}.GetNewClosure()
    $decode={param($value)if(!$value){return $null};(&$fnFromStore $value)|ConvertFrom-Json -Depth 80}.GetNewClosure()
    $fault={param($point)if($FaultPoint-eq$point){"INSERT INTO RapInjectedFault_$point(Value) VALUES(1);"}else{''}}.GetNewClosure()
    $readState={
        $value=[Rap.NativeSqlite]::Scalar($path,'SELECT Payload FROM WorkflowExceptionState WHERE Id=1;',5000)
        $state=if($value){&$decode $value}else{[pscustomobject]@{Exceptions=@();Plans=@();Reconciliations=@();Verifications=@()}}
        foreach($name in @('CaseStatus','RetainedAlternatives')){if(-not$state.PSObject.Properties[$name]){$state|Add-Member -NotePropertyName $name -NotePropertyValue @()}}
        $state
    }.GetNewClosure()
    $getOperation={param($operationId)$value=[Rap.NativeSqlite]::Scalar($path,"SELECT Payload FROM Operations WHERE OperationKey=$(&$fnLiteral ([string]$operationId)) AND Type='WorkflowException';",5000);&$decode $value}.GetNewClosure()
    $commitWorkflow={param($state,$operation,$audit,$events)
        $stateValue=&$encode $state;$operationValue=&$encode $operation;$auditValue=&$fnToStore (&$toJson $audit);$now=[DateTimeOffset]::UtcNow.ToString('o')
        $eventSql=&$fnEventSql -Events @($events) -Head (&$fnHead $path)
        $sql="BEGIN IMMEDIATE;INSERT OR REPLACE INTO WorkflowExceptionState(Id,Payload) VALUES(1,'$stateValue');$(&$fault 'AFTER_STATE')INSERT INTO WorkflowExceptionAudit(Payload) VALUES('$auditValue');$(&$fault 'AFTER_AUDIT')$eventSql$(&$fault 'AFTER_EVENTS')INSERT OR REPLACE INTO Operations(OperationKey,Type,Payload,Status,CreatedUtc,UpdatedUtc) VALUES($(&$fnLiteral ([string]$operation.OperationId)),'WorkflowException','$operationValue',$(&$fnLiteral ([string]$operation.State)),'$now','$now');$(&$fault 'BEFORE_COMMIT')COMMIT;"
        try{[Rap.NativeSqlite]::Execute($path,$sql,5000)}
        catch{
            $message=$_.Exception.Message
            if($FaultPoint-ne'None'-and$message-match'RapInjectedFault_'){throw "INJECTED_FAULT:${FaultPoint}: transaction rolled back ($message)"}
            throw
        }
    }.GetNewClosure()
    $recordFailure={param($event)
        $sql="BEGIN IMMEDIATE;$(&$fnEventSql -Events @($event) -Head (&$fnHead $path))COMMIT;"
        [Rap.NativeSqlite]::Execute($path,$sql,5000)
    }.GetNewClosure()
    $readEvents={
        $value=[Rap.NativeSqlite]::Scalar($path,"SELECT group_concat(Payload,',') FROM (SELECT Payload FROM WorkflowLifecycleEvents ORDER BY Id);",5000)
        if(!$value){return @()}
        @($value.Split(',')|ForEach-Object{(&$fnFromStore $_)|ConvertFrom-Json -Depth 80})
    }.GetNewClosure()
    $readLastAudit={param()$value=[Rap.NativeSqlite]::Scalar($path,'SELECT Payload FROM WorkflowExceptionAudit ORDER BY Id DESC LIMIT 1;',5000);&$decode $value}.GetNewClosure()
    [pscustomobject]@{GetOperation=$getOperation;ReadState=$readState;CommitWorkflow=$commitWorkflow;RecordFailure=$recordFailure;ReadEvents=$readEvents;ReadLastAudit=$readLastAudit;DatabasePath=$path;AuthorizedResearchers=@($AuthorizedResearchers);FaultPoint=$FaultPoint}
}

function Test-RapWorkflowAuditChain {
    <#
    .SYNOPSIS
    Verifies that the Workflow lifecycle/audit store has not been edited in place, truncated, or forked.
    #>
    [CmdletBinding()]param([Parameter(Mandatory)][string]$DatabasePath)
    $path=Initialize-RapWorkflowExceptionStore $DatabasePath
    $errors=[Collections.Generic.List[string]]::new()
    $rows=[Rap.NativeSqlite]::Scalar($path,"SELECT group_concat(Id||':'||PrevHash||':'||RowHash||':'||Payload,',') FROM (SELECT * FROM WorkflowLifecycleEvents ORDER BY Id);",5000)
    $prev='GENESIS';$count=0;$auditHashes=[Collections.Generic.List[string]]::new()
    foreach($row in @(if($rows){$rows.Split(',')})){
        $parts=$row.Split(':');$count++
        if($parts.Count-ne4){$errors.Add("MALFORMED_ROW:$count");continue}
        $json=ConvertFrom-RapWorkflowStoreText $parts[3]
        if($parts[1]-ne$prev){$errors.Add("CHAIN_BROKEN:$($parts[0])")}
        if((Get-RapWorkflowTextHash "$($parts[1])|$json")-ne$parts[2]){$errors.Add("EVENT_TAMPERED:$($parts[0])")}
        $event=$json|ConvertFrom-Json -Depth 80
        if($event.EventType-eq'OPERATION_COMPLETED'-and$event.Detail-and$event.Detail.PSObject.Properties['AuditJsonHash']){$auditHashes.Add([string]$event.Detail.AuditJsonHash)}
        $prev=$parts[2]
    }
    $head=Get-RapWorkflowChainHead $path
    if($head.EventCount-ne$count-or$head.LastHash-ne$prev){$errors.Add("CHAIN_HEAD_MISMATCH:head=$($head.EventCount) rows=$count")}
    $audits=[Rap.NativeSqlite]::Scalar($path,"SELECT group_concat(Payload,',') FROM (SELECT Payload FROM WorkflowExceptionAudit ORDER BY Id);",5000)
    $chained=[Collections.Generic.List[string]]::new();$legacy=0
    foreach($value in @(if($audits){$audits.Split(',')})){
        $json=ConvertFrom-RapWorkflowStoreText $value
        if($json-match'"AuditSchema":"SPR-011-TURN-E"'){$chained.Add((Get-RapWorkflowTextHash $json))}else{$legacy++}
    }
    $a=@($chained|Sort-Object)-join',';$b=@($auditHashes|Sort-Object)-join','
    if($a-ne$b){$errors.Add('AUDIT_ROW_NOT_BOUND_TO_CHAIN')}
    [pscustomobject]@{Valid=$errors.Count-eq0;EventCount=$count;ChainedAuditRows=$chained.Count;LegacyUnchainedAuditRows=$legacy;Errors=@($errors)}
}

function Get-RapWorkflowExceptionSnapshot {
    [CmdletBinding()]param([Parameter(Mandatory)][string]$DatabasePath)
    $dependencies=New-RapWorkflowSqliteDependencies $DatabasePath
    $state=&$dependencies.ReadState
    $state|Add-Member -NotePropertyName AuditCount -NotePropertyValue ([int][Rap.NativeSqlite]::Scalar($dependencies.DatabasePath,'SELECT COUNT(*) FROM WorkflowExceptionAudit;',5000)) -Force
    $state|Add-Member -NotePropertyName LastAudit -NotePropertyValue (&$dependencies.ReadLastAudit) -Force
    $state|Add-Member -NotePropertyName LifecycleEventCount -NotePropertyValue ([int][Rap.NativeSqlite]::Scalar($dependencies.DatabasePath,'SELECT COUNT(*) FROM WorkflowLifecycleEvents;',5000)) -Force
    return $state
}

Export-ModuleMember -Function Initialize-RapWorkflowExceptionStore,New-RapWorkflowSqliteDependencies,Get-RapWorkflowExceptionSnapshot,Test-RapWorkflowAuditChain
