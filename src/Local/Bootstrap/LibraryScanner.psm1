Set-StrictMode -Version Latest
function Invoke-RapLibraryScan {<#
.SYNOPSIS
Reads the complete normalized Zotero library through an injected connector.
#>[CmdletBinding()]param([Parameter(Mandatory)][scriptblock]$ReadItems)@(& $ReadItems)}
Export-ModuleMember -Function Invoke-RapLibraryScan
