Set-StrictMode -Version Latest
function Build-RapLibraryIndex {<#
.SYNOPSIS
Builds a deterministic Library_ID keyed index without modifying source data.
#>[CmdletBinding()]param([Parameter(Mandatory)][object[]]$Items)@($Items|ForEach-Object{[pscustomobject]@{LibraryId=$_.LibraryId;ItemKey=$_.ItemKey;Title=$_.Title;DOI=$_.DOI;DriveFileId=$_.DriveFileId;SHA256=$_.SHA256;Status=$_.Status}})}
Export-ModuleMember -Function Build-RapLibraryIndex
