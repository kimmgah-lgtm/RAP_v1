Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Models/Item.ps1')
. (Join-Path $PSScriptRoot 'Models/Attachment.ps1')
. (Join-Path $PSScriptRoot 'Models/Collection.ps1')

function Get-RapZoteroValue {
    param($Object,[string]$Name,$Default=$null)
    if($null -eq $Object){return $Default}
    $property=$Object.PSObject.Properties[$Name]
    if($null -eq $property){return $Default}
    return $property.Value
}

function ConvertTo-RapZoteroNormalizedItem {
    <#
    .SYNOPSIS Converts connector-specific item data to the RAP Zotero contract.
    .PARAMETER InputObject Internal SQLite aggregate or Zotero Web API item.
    .PARAMETER Source Identifies the source shape.
    .PARAMETER StorageRoot Optional Zotero data directory for storage path discovery.
    .OUTPUTS RapZoteroItem.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)]$InputObject, [Parameter(Mandatory)][ValidateSet('SQLite','WebApi')][string]$Source, [string]$StorageRoot)
    $item = [RapZoteroItem]::new()
    if ($Source -eq 'WebApi') {
        $data = Get-RapZoteroValue $InputObject 'data'
        $library=Get-RapZoteroValue $InputObject 'library';$item.ItemKey=[string](Get-RapZoteroValue $InputObject 'key');$item.LibraryType=[string](Get-RapZoteroValue $library 'type');$item.Version=[long](Get-RapZoteroValue $InputObject 'version' 0)
        $item.Title=[string](Get-RapZoteroValue $data 'title');$item.Creators=@(Get-RapZoteroValue $data 'creators' @()|ForEach-Object{[pscustomobject]@{CreatorType=Get-RapZoteroValue $_ 'creatorType';FirstName=Get-RapZoteroValue $_ 'firstName';LastName=Get-RapZoteroValue $_ 'lastName';Name=Get-RapZoteroValue $_ 'name'}})
        $item.DOI=[string](Get-RapZoteroValue $data 'DOI');$item.ISBN=[string](Get-RapZoteroValue $data 'ISBN');$item.Date=[string](Get-RapZoteroValue $data 'date');$publication=Get-RapZoteroValue $data 'publicationTitle';$item.Publication=[string]$(if($publication){$publication}else{Get-RapZoteroValue $data 'bookTitle'})
        $item.Collections=@(Get-RapZoteroValue $data 'collections' @());$item.Tags=@(Get-RapZoteroValue $data 'tags' @()|ForEach-Object{[string](Get-RapZoteroValue $_ 'tag')});$item.Extra=[string](Get-RapZoteroValue $data 'extra')
        $children=@(Get-RapZoteroValue $InputObject 'children' @());$item.Notes=@($children|Where-Object{(Get-RapZoteroValue $_.data 'itemType') -eq 'note'}|ForEach-Object{Get-RapZoteroValue $_.data 'note'})
        $item.Attachments=@($children|Where-Object{(Get-RapZoteroValue $_.data 'itemType') -eq 'attachment'}|ForEach-Object{ConvertTo-RapZoteroAttachment -InputObject $_ -Source WebApi -StorageRoot $StorageRoot})
    } else {
        $item.ItemKey=[string]$InputObject.ItemKey; $item.LibraryType=[string]$InputObject.LibraryType; $item.Version=[long]$InputObject.Version
        $item.Title=[string]$InputObject.Fields['title']; $item.Creators=@($InputObject.Creators); $item.DOI=[string]$InputObject.Fields['DOI']; $item.ISBN=[string]$InputObject.Fields['ISBN']
        $item.Date=[string]$InputObject.Fields['date']; $item.Publication=[string]$(if($InputObject.Fields['publicationTitle']){$InputObject.Fields['publicationTitle']}else{$InputObject.Fields['bookTitle']})
        $item.Collections=@($InputObject.Collections); $item.Tags=@($InputObject.Tags); $item.Extra=[string]$InputObject.Fields['extra']; $item.Notes=@($InputObject.Notes)
        $item.Attachments=@($InputObject.Attachments | ForEach-Object { ConvertTo-RapZoteroAttachment -InputObject $_ -Source SQLite -StorageRoot $StorageRoot })
    }
    $annotations=@($item.Attachments | ForEach-Object {$_.Annotations})
    $item.AnnotationSummary=[pscustomobject]@{ Count=$annotations.Count; Types=@($annotations | ForEach-Object {$_.Type} | Sort-Object -Unique) }
    return $item
}

function ConvertTo-RapZoteroAttachment {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$InputObject, [Parameter(Mandatory)][ValidateSet('SQLite','WebApi')][string]$Source, [string]$StorageRoot)
    $attachment=[RapZoteroAttachment]::new()
    if($Source -eq 'WebApi'){$d=Get-RapZoteroValue $InputObject 'data';$attachment.ItemKey=Get-RapZoteroValue $InputObject 'key';$attachment.Title=Get-RapZoteroValue $d 'title';$attachment.ContentType=Get-RapZoteroValue $d 'contentType';$attachment.Path=Get-RapZoteroValue $d 'path';$attachment.IsLinked=(Get-RapZoteroValue $d 'linkMode') -in @('linked_file','linked_url');$attachment.Annotations=@(Get-RapZoteroValue $InputObject 'children' @()|Where-Object{(Get-RapZoteroValue $_.data 'itemType') -eq 'annotation'}|ForEach-Object{$_.data})}
    else{$attachment.ItemKey=$InputObject.ItemKey;$attachment.Title=$InputObject.Title;$attachment.ContentType=$InputObject.ContentType;$attachment.Path=$InputObject.Path;$attachment.IsLinked=[int]$InputObject.LinkMode -in @(2,3);$attachment.Annotations=@($InputObject.Annotations)}
    if($attachment.Path -like 'storage:*' -and $StorageRoot){$attachment.Path=Join-Path (Join-Path $StorageRoot 'storage') (Join-Path $attachment.ItemKey $attachment.Path.Substring(8))}
    if(-not [string]::IsNullOrWhiteSpace($attachment.Path) -and -not $attachment.Path.StartsWith('http')){$attachment.FileExists=Test-Path -LiteralPath $attachment.Path -PathType Leaf}
    return $attachment
}

function ConvertTo-RapZoteroCollection {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$InputObject,[Parameter(Mandatory)][ValidateSet('SQLite','WebApi')][string]$Source)
    $collection=[RapZoteroCollection]::new()
    if($Source -eq 'WebApi'){$collection.CollectionKey=$InputObject.key;$collection.Name=$InputObject.data.name;$collection.ParentCollectionKey=$InputObject.data.parentCollection;$collection.Version=[long]$InputObject.version}
    else{$collection.CollectionKey=$InputObject.CollectionKey;$collection.Name=$InputObject.Name;$collection.ParentCollectionKey=$InputObject.ParentCollectionKey;$collection.Version=[long]$InputObject.Version}
    return $collection
}

Export-ModuleMember -Function ConvertTo-RapZoteroNormalizedItem, ConvertTo-RapZoteroAttachment, ConvertTo-RapZoteroCollection
