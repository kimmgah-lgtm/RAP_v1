Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '../ResearchAutomation.Local/modules/Queue.psm1') -Force -ErrorAction Stop

function ConvertTo-RapGraphStoreText {param($Value)[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($Value|ConvertTo-Json -Depth 60 -Compress)))}
function ConvertFrom-RapGraphStoreText {param([string]$Value)if([string]::IsNullOrWhiteSpace($Value)){return $null};[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($Value))|ConvertFrom-Json -Depth 60}
function Assert-RapGraphStoreId {param([string]$Value,[string]$Name)if($Value -notmatch '^[A-Za-z0-9:._|\-]+$'){throw "Invalid $Name for Evidence Graph store."}}

function Initialize-RapEvidenceGraphStore {
    [CmdletBinding()]param([Parameter(Mandatory)][string]$DatabasePath,[ValidateRange(0,60000)][int]$BusyTimeoutMilliseconds=5000)
    Queue\Initialize-RapQueue $DatabasePath $BusyTimeoutMilliseconds|Out-Null
    $resolved=[IO.Path]::GetFullPath($DatabasePath)
    $empty=ConvertTo-RapGraphStoreText ([pscustomobject]@{Nodes=@();Edges=@()})
    $schema="PRAGMA foreign_keys=ON;CREATE TABLE IF NOT EXISTS EvidenceGraphNodes(NodeId TEXT PRIMARY KEY,NodeType TEXT NOT NULL,LibraryId TEXT,ProjectId TEXT,NodePayload TEXT NOT NULL,UpdatedUtc TEXT NOT NULL);CREATE TABLE IF NOT EXISTS EvidenceGraphEdges(EdgeId TEXT PRIMARY KEY,SourceNodeId TEXT NOT NULL,TargetNodeId TEXT NOT NULL,RelationType TEXT NOT NULL,ProjectId TEXT,EdgePayload TEXT NOT NULL,UpdatedUtc TEXT NOT NULL,FOREIGN KEY(SourceNodeId) REFERENCES EvidenceGraphNodes(NodeId),FOREIGN KEY(TargetNodeId) REFERENCES EvidenceGraphNodes(NodeId));CREATE TABLE IF NOT EXISTS EvidenceGraphState(Id INTEGER PRIMARY KEY CHECK(Id=1),GraphPayload TEXT NOT NULL,UpdatedUtc TEXT NOT NULL);CREATE TABLE IF NOT EXISTS EvidenceGraphAudit(Id INTEGER PRIMARY KEY AUTOINCREMENT,OperationId TEXT NOT NULL,EventPayload TEXT NOT NULL,CreatedUtc TEXT NOT NULL);INSERT OR IGNORE INTO EvidenceGraphState(Id,GraphPayload,UpdatedUtc) VALUES(1,'$empty','$([DateTimeOffset]::UtcNow.ToString('o'))');"
    [Rap.NativeSqlite]::Execute($resolved,$schema,$BusyTimeoutMilliseconds)
    $resolved
}

function New-RapEvidenceGraphSqliteDependencies {
    [CmdletBinding()]param([Parameter(Mandatory)][string]$DatabasePath,[ValidateRange(0,60000)][int]$BusyTimeoutMilliseconds=5000)
    $resolved=Initialize-RapEvidenceGraphStore $DatabasePath $BusyTimeoutMilliseconds
    $encode=${function:ConvertTo-RapGraphStoreText};$decode=${function:ConvertFrom-RapGraphStoreText};$assertId=${function:Assert-RapGraphStoreId}
    $scalar={param($sql)[Rap.NativeSqlite]::Scalar($resolved,$sql,$BusyTimeoutMilliseconds)}.GetNewClosure();$execute={param($sql)[Rap.NativeSqlite]::Execute($resolved,$sql,$BusyTimeoutMilliseconds)}.GetNewClosure()
    $readState={& $decode (& $scalar 'SELECT GraphPayload FROM EvidenceGraphState WHERE Id=1;')}.GetNewClosure()
    $writeState={param($state)$payload=& $encode $state;$now=[DateTimeOffset]::UtcNow.ToString('o');& $execute "UPDATE EvidenceGraphState SET GraphPayload='$payload',UpdatedUtc='$now' WHERE Id=1;"}.GetNewClosure()
    $getOperation={param($operationId)& $assertId $operationId 'OperationId';& $decode (& $scalar "SELECT Payload FROM Operations WHERE OperationKey='$operationId' AND Type='EvidenceGraph';")}.GetNewClosure()
    $saveOperation={param($operation)& $assertId ([string]$operation.OperationId) 'OperationId';$payload=& $encode $operation;$now=[DateTimeOffset]::UtcNow.ToString('o');$id=[string]$operation.OperationId;$status=[string]$operation.State;& $execute "INSERT OR IGNORE INTO Operations(OperationKey,Type,Payload,Status,CreatedUtc,UpdatedUtc) VALUES('$id','EvidenceGraph','$payload','$status','$now','$now');UPDATE Operations SET Payload='$payload',Status='$status',UpdatedUtc='$now' WHERE OperationKey='$id' AND Type='EvidenceGraph';"}.GetNewClosure()
    $getNode={param($nodeId)$state=& $readState;$state.Nodes|Where-Object NodeId -EQ $nodeId|Select-Object -First 1}.GetNewClosure()
    $upsertNode={param($node)& $assertId ([string]$node.NodeId) 'NodeId';$state=& $readState;$nodes=[Collections.Generic.List[object]]::new();foreach($n in @($state.Nodes)){if($n.NodeId -ne $node.NodeId){$nodes.Add($n)}};$nodes.Add($node);$next=[pscustomobject]@{Nodes=$nodes.ToArray();Edges=@($state.Edges)};& $writeState $next;$payload=& $encode $node;$now=[DateTimeOffset]::UtcNow.ToString('o');$library=[string]$node.LibraryId;$project=[string]$node.ProjectId;& $execute "INSERT OR REPLACE INTO EvidenceGraphNodes(NodeId,NodeType,LibraryId,ProjectId,NodePayload,UpdatedUtc) VALUES('$($node.NodeId)','$($node.NodeType)','$library','$project','$payload','$now');";[pscustomobject]@{Status='UPSERTED';NodeId=$node.NodeId}}.GetNewClosure()
    $getEdge={param($edgeId)$state=& $readState;$state.Edges|Where-Object EdgeId -EQ $edgeId|Select-Object -First 1}.GetNewClosure()
    $upsertEdge={param($edge)& $assertId ([string]$edge.EdgeId) 'EdgeId';$state=& $readState;$edges=[Collections.Generic.List[object]]::new();foreach($e in @($state.Edges)){if($e.EdgeId -ne $edge.EdgeId){$edges.Add($e)}};$edges.Add($edge);$next=[pscustomobject]@{Nodes=@($state.Nodes);Edges=$edges.ToArray()};& $writeState $next;$payload=& $encode $edge;$now=[DateTimeOffset]::UtcNow.ToString('o');$project=[string]$edge.ProjectId;& $execute "INSERT OR REPLACE INTO EvidenceGraphEdges(EdgeId,SourceNodeId,TargetNodeId,RelationType,ProjectId,EdgePayload,UpdatedUtc) VALUES('$($edge.EdgeId)','$($edge.SourceNodeId)','$($edge.TargetNodeId)','$($edge.RelationType)','$project','$payload','$now');";[pscustomobject]@{Status='UPSERTED';EdgeId=$edge.EdgeId}}.GetNewClosure()
    $findNodes={@((& $readState).Nodes)}.GetNewClosure();$findEdges={@((& $readState).Edges)}.GetNewClosure()
    $appendAudit={param($record)$payload=& $encode $record;$now=[DateTimeOffset]::UtcNow.ToString('o');$id=[string]$record.OperationId;& $execute "INSERT INTO EvidenceGraphAudit(OperationId,EventPayload,CreatedUtc) VALUES('$id','$payload','$now');"}.GetNewClosure()
    [pscustomobject]@{GetOperation=$getOperation;SaveOperation=$saveOperation;GetNode=$getNode;UpsertNode=$upsertNode;GetEdge=$getEdge;UpsertEdge=$upsertEdge;FindNodes=$findNodes;FindEdges=$findEdges;AppendAudit=$appendAudit}
}

function Get-RapEvidenceGraphFixtureSnapshot {
    [CmdletBinding()]param([Parameter(Mandatory)][string]$DatabasePath,[ValidateRange(0,60000)][int]$BusyTimeoutMilliseconds=5000)
    $resolved=Initialize-RapEvidenceGraphStore $DatabasePath $BusyTimeoutMilliseconds;$value=[Rap.NativeSqlite]::Scalar($resolved,'SELECT GraphPayload FROM EvidenceGraphState WHERE Id=1;',$BusyTimeoutMilliseconds);ConvertFrom-RapGraphStoreText $value
}

Export-ModuleMember -Function Initialize-RapEvidenceGraphStore,New-RapEvidenceGraphSqliteDependencies,Get-RapEvidenceGraphFixtureSnapshot
