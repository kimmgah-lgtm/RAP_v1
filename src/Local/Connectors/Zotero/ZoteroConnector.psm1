Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'SQLiteReader.psm1') -Force -ErrorAction Stop
Import-Module (Join-Path $PSScriptRoot 'WebApiReader.psm1') -Force -ErrorAction Stop
Import-Module (Join-Path $PSScriptRoot 'Normalizer.psm1') -Force -ErrorAction Stop

function Assert-RapZoteroItemKey { param([string]$ItemKey) if($ItemKey -notmatch '^[A-Z0-9]{8}$'){throw "Invalid Zotero item key: $ItemKey"} }

function Get-RapZoteroSqliteAggregates {
    param([string]$DatabasePath,[string]$ItemKey,[int]$BusyTimeoutMilliseconds)
    $where = "it.typeName NOT IN ('attachment','note','annotation') AND di.itemID IS NULL"
    if($ItemKey){Assert-RapZoteroItemKey $ItemKey;$where += " AND i.key = '$ItemKey'"}
    $items=Invoke-RapZoteroSqliteRead $DatabasePath "SELECT i.itemID AS ItemId,i.key AS ItemKey,i.version AS Version,CASE WHEN i.libraryID IS NULL OR i.libraryID=0 THEN 'user' ELSE 'group' END AS LibraryType FROM items i JOIN itemTypes it ON it.itemTypeID=i.itemTypeID LEFT JOIN deletedItems di ON di.itemID=i.itemID WHERE $where ORDER BY i.itemID;" $BusyTimeoutMilliseconds
    $fields=Invoke-RapZoteroSqliteRead $DatabasePath 'SELECT d.itemID AS ItemId,f.fieldName AS FieldName,v.value AS FieldValue FROM itemData d JOIN fields f ON f.fieldID=d.fieldID JOIN itemDataValues v ON v.valueID=d.valueID;' $BusyTimeoutMilliseconds
    $creators=Invoke-RapZoteroSqliteRead $DatabasePath "SELECT ic.itemID AS ItemId,ct.creatorType AS CreatorType,CASE WHEN c.fieldMode=0 THEN c.firstName ELSE '' END AS FirstName,CASE WHEN c.fieldMode=0 THEN c.lastName ELSE '' END AS LastName,CASE WHEN c.fieldMode=1 THEN c.lastName ELSE '' END AS Name FROM itemCreators ic JOIN creators c ON c.creatorID=ic.creatorID JOIN creatorTypes ct ON ct.creatorTypeID=ic.creatorTypeID ORDER BY ic.itemID,ic.orderIndex;" $BusyTimeoutMilliseconds
    $tags=Invoke-RapZoteroSqliteRead $DatabasePath 'SELECT it.itemID AS ItemId,t.name AS Tag FROM itemTags it JOIN tags t ON t.tagID=it.tagID ORDER BY it.itemID,t.name;' $BusyTimeoutMilliseconds
    $collections=Invoke-RapZoteroSqliteRead $DatabasePath 'SELECT ci.itemID AS ItemId,c.key AS CollectionKey,c.collectionName AS Name FROM collectionItems ci JOIN collections c ON c.collectionID=ci.collectionID ORDER BY ci.itemID,c.collectionName;' $BusyTimeoutMilliseconds
    $notes=Invoke-RapZoteroSqliteRead $DatabasePath 'SELECT parentItemID AS ItemId,note AS Note FROM itemNotes WHERE parentItemID IS NOT NULL ORDER BY itemID;' $BusyTimeoutMilliseconds
    $attachments=Invoke-RapZoteroSqliteRead $DatabasePath "SELECT a.parentItemID AS ItemId,i.itemID AS AttachmentId,i.key AS ItemKey,a.linkMode AS LinkMode,a.contentType AS ContentType,a.path AS Path,COALESCE(v.value,'') AS Title FROM itemAttachments a JOIN items i ON i.itemID=a.itemID LEFT JOIN itemData d ON d.itemID=i.itemID LEFT JOIN fields f ON f.fieldID=d.fieldID AND f.fieldName='title' LEFT JOIN itemDataValues v ON v.valueID=d.valueID WHERE a.parentItemID IS NOT NULL ORDER BY a.parentItemID,i.itemID;" $BusyTimeoutMilliseconds
    $annotations=Invoke-RapZoteroSqliteRead $DatabasePath 'SELECT a.parentItemID AS AttachmentId,i.key AS ItemKey,a.type AS Type,a.text AS Text,a.comment AS Comment,a.color AS Color,a.pageLabel AS PageLabel,a.position AS Position FROM itemAnnotations a JOIN items i ON i.itemID=a.itemID ORDER BY a.parentItemID,i.itemID;' $BusyTimeoutMilliseconds
    foreach($row in $items){
        $id=[string]$row.ItemId;$fieldMap=@{};foreach($f in @($fields|Where-Object ItemId -eq $id)){$fieldMap[$f.FieldName]=$f.FieldValue}
        $itemAttachments=@($attachments|Where-Object ItemId -eq $id|ForEach-Object{$attachment=$_;$attachmentId=[string]$attachment.AttachmentId;[pscustomobject]@{ItemKey=$attachment.ItemKey;Title=$attachment.Title;ContentType=$attachment.ContentType;Path=$attachment.Path;LinkMode=$attachment.LinkMode;Annotations=@($annotations|Where-Object AttachmentId -eq $attachmentId)}})
        [pscustomobject]@{ItemKey=$row.ItemKey;LibraryType=$row.LibraryType;Version=$row.Version;Fields=$fieldMap;Creators=@($creators|Where-Object ItemId -eq $id);Tags=@($tags|Where-Object ItemId -eq $id|ForEach-Object Tag);Collections=@($collections|Where-Object ItemId -eq $id);Notes=@($notes|Where-Object ItemId -eq $id|ForEach-Object Note);Attachments=$itemAttachments}
    }
}

function Get-RapZoteroItems {
    <#
    .SYNOPSIS Reads normalized Zotero items through the connector boundary.
    .DESCRIPTION Dispatches to the read-only SQLite or Web API connector and
    returns only the normalized RAP object contract.
    .PARAMETER Connector SQLite or WebApi.
    .PARAMETER DatabasePath Zotero SQLite path for the SQLite connector.
    .PARAMETER StorageRoot Zotero data directory used to resolve storage paths.
    .PARAMETER BaseUrl Zotero Web API base URL.
    .PARAMETER LibraryType users or groups for the Web API connector.
    .PARAMETER LibraryId Zotero user or group ID for the Web API connector.
    .PARAMETER ApiKey Optional Web API key. Prefer reading it from an environment variable.
    .PARAMETER ItemKey Optional eight-character Zotero item key.
    .PARAMETER RequestInvoker Optional isolated test transport for Web API reads.
    .OUTPUTS RapZoteroItem objects.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet('SQLite','WebApi')][string]$Connector,
        [string]$DatabasePath,[string]$StorageRoot,[uri]$BaseUrl=[uri]'https://api.zotero.org/',
        [ValidateSet('users','groups')][string]$LibraryType='users',[string]$LibraryId,[string]$ApiKey,
        [string]$ItemKey,[scriptblock]$RequestInvoker,[ValidateRange(0,60000)][int]$BusyTimeoutMilliseconds=5000
    )
    if($Connector -eq 'SQLite'){
        if([string]::IsNullOrWhiteSpace($DatabasePath)){throw 'DatabasePath is required for the SQLite connector.'}
        return @(Get-RapZoteroSqliteAggregates $DatabasePath $ItemKey $BusyTimeoutMilliseconds | ForEach-Object {ConvertTo-RapZoteroNormalizedItem $_ SQLite $StorageRoot})
    }
    if([string]::IsNullOrWhiteSpace($LibraryId)){throw 'LibraryId is required for the Web API connector.'}
    $resource="$LibraryType/$LibraryId/items?include=data&limit=100";if($ItemKey){Assert-RapZoteroItemKey $ItemKey;$resource="$LibraryType/$LibraryId/items/$ItemKey"}
    $response=@(Invoke-RapZoteroWebApiRead $BaseUrl $resource $ApiKey $RequestInvoker)
    foreach($apiItem in $response){
        $children=@(Invoke-RapZoteroWebApiRead $BaseUrl "$LibraryType/$LibraryId/items/$($apiItem.key)/children?include=data&limit=100" $ApiKey $RequestInvoker)
        $apiItem|Add-Member -NotePropertyName children -NotePropertyValue $children -Force
        ConvertTo-RapZoteroNormalizedItem $apiItem WebApi $StorageRoot
    }
}

function Get-RapZoteroCollections {
    <#
    .SYNOPSIS Reads normalized Zotero collections without modification.
    .DESCRIPTION Dispatches to the read-only SQLite or Web API connector and
    returns only normalized collection objects.
    .PARAMETER Connector SQLite or WebApi.
    .PARAMETER DatabasePath Zotero SQLite path for the SQLite connector.
    .PARAMETER BaseUrl Zotero Web API base URL.
    .PARAMETER LibraryType users or groups for the Web API connector.
    .PARAMETER LibraryId Zotero user or group ID.
    .PARAMETER ApiKey Optional Zotero API key.
    .PARAMETER RequestInvoker Optional isolated test transport.
    .PARAMETER BusyTimeoutMilliseconds SQLite lock wait timeout.
    .OUTPUTS RapZoteroCollection objects.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][ValidateSet('SQLite','WebApi')][string]$Connector,[string]$DatabasePath,[uri]$BaseUrl=[uri]'https://api.zotero.org/',[ValidateSet('users','groups')][string]$LibraryType='users',[string]$LibraryId,[string]$ApiKey,[scriptblock]$RequestInvoker,[int]$BusyTimeoutMilliseconds=5000)
    if($Connector -eq 'SQLite'){
        $rows=Invoke-RapZoteroSqliteRead $DatabasePath 'SELECT c.key AS CollectionKey,c.collectionName AS Name,p.key AS ParentCollectionKey,c.version AS Version FROM collections c LEFT JOIN collections p ON p.collectionID=c.parentCollectionID ORDER BY c.collectionName;' $BusyTimeoutMilliseconds
        return @($rows|ForEach-Object{ConvertTo-RapZoteroCollection $_ SQLite})
    }
    if([string]::IsNullOrWhiteSpace($LibraryId)){throw 'LibraryId is required for the Web API connector.'}
    return @(Invoke-RapZoteroWebApiRead $BaseUrl "$LibraryType/$LibraryId/collections?limit=100" $ApiKey $RequestInvoker|ForEach-Object{ConvertTo-RapZoteroCollection $_ WebApi})
}

function Get-RapZoteroLibraryStatistics {
    <#
    .SYNOPSIS Returns read-only Zotero library statistics.
    .DESCRIPTION Reads normalized items and collections through the selected
    connector and calculates item, collection, attachment, note, and annotation counts.
    .PARAMETER Connector SQLite or WebApi.
    .PARAMETER DatabasePath Zotero SQLite path for the SQLite connector.
    .PARAMETER BaseUrl Zotero Web API base URL.
    .PARAMETER LibraryType users or groups for the Web API connector.
    .PARAMETER LibraryId Zotero user or group ID.
    .PARAMETER ApiKey Optional Zotero API key.
    .PARAMETER RequestInvoker Optional isolated test transport.
    .PARAMETER BusyTimeoutMilliseconds SQLite lock wait timeout.
    .OUTPUTS PSCustomObject containing aggregate library counts.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][ValidateSet('SQLite','WebApi')][string]$Connector,[string]$DatabasePath,[uri]$BaseUrl=[uri]'https://api.zotero.org/',[ValidateSet('users','groups')][string]$LibraryType='users',[string]$LibraryId,[string]$ApiKey,[scriptblock]$RequestInvoker,[int]$BusyTimeoutMilliseconds=5000)
    $items=@(Get-RapZoteroItems @PSBoundParameters);$collectionParameters=@{}+$PSBoundParameters;$collectionParameters.Remove('StorageRoot');$collections=@(Get-RapZoteroCollections @collectionParameters)
    [pscustomobject]@{Items=$items.Count;Collections=$collections.Count;Attachments=@($items.Attachments).Count;Notes=@($items.Notes).Count;Annotations=(@($items|ForEach-Object{$_.AnnotationSummary.Count})|Measure-Object -Sum).Sum}
}

function Test-RapZoteroConnection {
    <#
    .SYNOPSIS Tests the selected Zotero read-only connection.
    .DESCRIPTION Performs a read-only SQLite quick check or a one-item Web API GET.
    .PARAMETER Connector SQLite or WebApi.
    .PARAMETER DatabasePath Zotero SQLite path for the SQLite connector.
    .PARAMETER BaseUrl Zotero Web API base URL.
    .PARAMETER LibraryType users or groups for the Web API connector.
    .PARAMETER LibraryId Zotero user or group ID.
    .PARAMETER ApiKey Optional Zotero API key.
    .PARAMETER RequestInvoker Optional isolated test transport.
    .PARAMETER BusyTimeoutMilliseconds SQLite lock wait timeout.
    .OUTPUTS Boolean indicating whether the selected read route responded successfully.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][ValidateSet('SQLite','WebApi')][string]$Connector,[string]$DatabasePath,[uri]$BaseUrl=[uri]'https://api.zotero.org/',[ValidateSet('users','groups')][string]$LibraryType='users',[string]$LibraryId,[string]$ApiKey,[scriptblock]$RequestInvoker,[int]$BusyTimeoutMilliseconds=5000)
    if($Connector -eq 'SQLite'){return Test-RapZoteroSqliteConnection $DatabasePath $BusyTimeoutMilliseconds}
    return Test-RapZoteroWebApiConnection $BaseUrl $LibraryType $LibraryId $ApiKey $RequestInvoker
}

Export-ModuleMember -Function Get-RapZoteroItems,Get-RapZoteroCollections,Get-RapZoteroLibraryStatistics,Test-RapZoteroConnection
