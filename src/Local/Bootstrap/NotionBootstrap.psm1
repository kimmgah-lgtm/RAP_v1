Set-StrictMode -Version Latest
function Invoke-RapNotionBootstrap {<#
.SYNOPSIS
Idempotently creates missing Notion review pages through an injected connector.
#>[CmdletBinding()]param([Parameter(Mandatory)][object[]]$Items,[Parameter(Mandatory)][scriptblock]$FindByLibraryId,[Parameter(Mandatory)][scriptblock]$CreateReview)
 @($Items|ForEach-Object{$existing=& $FindByLibraryId $_.LibraryId;if($existing){[pscustomobject]@{LibraryId=$_.LibraryId;Status='ALREADY_EXISTS';PageId=$existing.PageId}}else{$page=& $CreateReview $_;[pscustomobject]@{LibraryId=$_.LibraryId;Status='CREATED';PageId=$page.PageId}}})}
Export-ModuleMember -Function Invoke-RapNotionBootstrap
