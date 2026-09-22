#Requires -Version 7.0
<# .SYNOPSIS Runs SPR-002 unit, connector, Web API, and normalization tests. #>
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$connectorRoot=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $connectorRoot 'ZoteroConnector.psm1') -Force

$script:requests=[Collections.Generic.List[object]]::new()
$transport={param($request)$script:requests.Add($request);if($request.Uri -match '/children\?'){return @(
    [pscustomobject]@{key='ATTACH01';version=2;library=[pscustomobject]@{type='user'};data=[pscustomobject]@{itemType='attachment';title='PDF';contentType='application/pdf';path='storage:paper.pdf';linkMode='imported_file'}},
    [pscustomobject]@{key='NOTE0001';version=1;library=[pscustomobject]@{type='user'};data=[pscustomobject]@{itemType='note';note='<p>Read-only note</p>'}}
)};if($request.Uri -match '/collections\?'){return @([pscustomobject]@{key='COLL0001';version=3;data=[pscustomobject]@{name='Research';parentCollection=$false}})};return @([pscustomobject]@{key='ITEM0001';version=7;library=[pscustomobject]@{type='user'};data=[pscustomobject]@{title='Sample';creators=@([pscustomobject]@{creatorType='author';firstName='Ada';lastName='Lovelace';name=$null});DOI='10.1000/test';ISBN='';date='2026';publicationTitle='Journal';bookTitle='';collections=@('COLL0001');tags=@([pscustomobject]@{tag='automation'});extra='fixture'}})}

$items=@(Get-RapZoteroItems -Connector WebApi -LibraryId '123' -RequestInvoker $transport)
if($items.Count -ne 1 -or $items[0].ItemKey -ne 'ITEM0001' -or $items[0].Title -ne 'Sample'){throw 'Web API normalization test failed.'}
if($items[0].Attachments.Count -ne 1 -or $items[0].Notes.Count -ne 1){throw 'Child item normalization test failed.'}
$collections=@(Get-RapZoteroCollections -Connector WebApi -LibraryId '123' -RequestInvoker $transport)
if($collections.Count -ne 1 -or $collections[0].CollectionKey -ne 'COLL0001'){throw 'Collection connector test failed.'}
if(@($script:requests|Where-Object Method -ne 'GET').Count -ne 0){throw 'Web API connector attempted a non-GET request.'}
if(-not (Test-RapZoteroConnection -Connector WebApi -LibraryId '123' -RequestInvoker $transport)){throw 'Web API connection test failed.'}
$propertyNames=@($items[0].PSObject.Properties.Name)
foreach($required in @('ItemKey','LibraryType','Version','Title','Creators','DOI','ISBN','Date','Publication','Collections','Tags','Extra','Notes','Attachments','AnnotationSummary')){if($required -notin $propertyNames){throw "Normalized contract property missing: $required"}}
Write-Host 'SPR-002 unit/connector/Web API/normalization tests: PASS'

