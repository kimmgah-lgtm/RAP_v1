Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

function Invoke-RapSandboxRequest {
    param($Context,[string]$Method,[string]$Resource,$Body=$null,[hashtable]$Headers=@{})
    $uri=$Context.BaseUrl.TrimEnd('/')+'/'+$Resource.TrimStart('/');$all=@{'Zotero-API-Version'='3';'Zotero-API-Key'=$Context.ApiKey};foreach($k in $Headers.Keys){$all[$k]=$Headers[$k]}
    $request=@{Method=$Method;Uri=$uri;Headers=$all};if($null -ne $Body){$request.Body=($Body|ConvertTo-Json -Depth 30 -Compress);$request.ContentType='application/json'}
    if($Context.Transport){return & $Context.Transport $request}
    Invoke-RestMethod @request -ErrorAction Stop
}

function New-RapSandboxWriteContext {
    <#
    .SYNOPSIS
    Creates a write context restricted to a verified Sandbox group library.
    .DESCRIPTION
    Verifies the target is a Zotero group whose name contains Sandbox and returns protected connector callbacks.
    .PARAMETER SandboxLibraryId
    Approved Zotero Sandbox group ID.
    .PARAMETER ApiKey
    Zotero API key with Sandbox permissions.
    .PARAMETER AuditPath
    Append-only JSONL audit path.
    .PARAMETER Transport
    Optional test transport.
    .OUTPUTS
    Sandboxed write context.
    #>
    [CmdletBinding()]param([Parameter(Mandatory)][string]$SandboxLibraryId,[Parameter(Mandatory)][string]$ApiKey,[Parameter(Mandatory)][string]$AuditPath,[uri]$BaseUrl=[uri]'https://api.zotero.org/',[scriptblock]$Transport,[scriptblock]$QueueSink,[scriptblock]$EventSink)
    if($SandboxLibraryId -notmatch '^\d+$'){throw 'SandboxLibraryId must be a numeric Zotero group ID.'}
    if([string]::IsNullOrWhiteSpace($ApiKey)){throw 'A Sandbox API key is required.'}
    $context=[pscustomobject]@{LibraryType='groups';LibraryId=$SandboxLibraryId;BaseUrl=$BaseUrl.AbsoluteUri;ApiKey=$ApiKey;AuditPath=[IO.Path]::GetFullPath($AuditPath);Transport=$Transport;QueueSink=$QueueSink;EventSink=$EventSink;CompletedOperations=[Collections.Generic.HashSet[string]]::new()}
    $group=Invoke-RapSandboxRequest $context GET "groups/$SandboxLibraryId"
    $name=[string]$(if($group.data.name){$group.data.name}else{$group.name});if($name -notmatch '(?i)sandbox'){throw "Write target is not a Sandbox Library: $name"}
    $context|Add-Member NoteProperty SandboxName $name
    $requestCommand=${function:Invoke-RapSandboxRequest};$applyCommand=${function:Invoke-RapConnectorApply};$restoreCommand=${function:Invoke-RapConnectorRestore}
    $context|Add-Member NoteProperty GetItem ({param($itemKey)$item=& $requestCommand $context GET "groups/$($context.LibraryId)/items/$itemKey";$children=@(& $requestCommand $context GET "groups/$($context.LibraryId)/items/$itemKey/children?limit=100");$item|Add-Member NoteProperty children $children -Force;return $item}.GetNewClosure())
    $context|Add-Member NoteProperty Apply ({param($command,$snapshot)& $applyCommand $context $command $snapshot}.GetNewClosure())
    $context|Add-Member NoteProperty Restore ({param($command,$snapshot,$result)& $restoreCommand $context $command $snapshot $result}.GetNewClosure())
    return $context
}

function Invoke-RapConnectorApply {
    param($Context,$Command,$Snapshot)
    $data=$Snapshot.Item.data|ConvertTo-Json -Depth 30|ConvertFrom-Json -Depth 30;$createdKey=$null
    switch($Command.Command){
        'WriteLibraryId'{$line="Library_ID: $($Command.Payload.LibraryId)";$extra=[string]$data.extra;$data.extra=$(if([string]::IsNullOrWhiteSpace($extra)){$line}else{"$extra`n$line"})}
        'WriteExtra'{$data.extra=$Command.Payload.Extra}
        'WriteTag'{$data.tags=@($data.tags)+@([pscustomobject]@{tag=$Command.Payload.Tag;type=1})}
        'AddCollection'{$data.collections=@($data.collections)+$Command.Payload.CollectionKey}
        'UpdateMetadata'{foreach($key in $Command.Payload.Fields.Keys){$data.$key=$Command.Payload.Fields[$key]}}
        'CreateLinkedAttachment'{$body=@([ordered]@{itemType='attachment';parentItem=$Command.ItemKey;linkMode='linked_file';title=$Command.Payload.Title;path=$Command.Payload.Path;contentType=$Command.Payload.ContentType;note="RAP_OperationID:$($Command.OperationID)"});$response=Invoke-RapSandboxRequest $Context POST "groups/$($Context.LibraryId)/items" $body;$createdKey=[string]$response.successful.'0'.key;return [pscustomobject]@{CreatedKey=$createdKey;OperationID=$Command.OperationID}}
    }
    [void](Invoke-RapSandboxRequest $Context PATCH "groups/$($Context.LibraryId)/items/$($Command.ItemKey)" $data @{'If-Unmodified-Since-Version'=[string]$Snapshot.Version})
    [pscustomobject]@{CreatedKey=$null;OperationID=$Command.OperationID}
}

function Invoke-RapConnectorRestore {
    param($Context,$Command,$Snapshot,$WriteResult)
    if($Command.Command -eq 'CreateLinkedAttachment'){
        if($WriteResult.OperationID -ne $Command.OperationID -or $WriteResult.CreatedKey -notmatch '^[A-Z0-9]{8}$'){throw 'Rollback refused: attachment ownership could not be proven.'}
        [void](Invoke-RapSandboxRequest $Context DELETE "groups/$($Context.LibraryId)/items/$($WriteResult.CreatedKey)");return
    }
    [void](Invoke-RapSandboxRequest $Context PATCH "groups/$($Context.LibraryId)/items/$($Command.ItemKey)" $Snapshot.Item.data)
}

Export-ModuleMember -Function New-RapSandboxWriteContext,Invoke-RapSandboxRequest,Invoke-RapConnectorApply,Invoke-RapConnectorRestore
