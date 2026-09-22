Set-StrictMode -Version Latest
function Invoke-RapBootstrapWizard {<#
.SYNOPSIS
Guides scan, report, dry-run, approval, backup, execution, verification, and reporting.
#>[CmdletBinding()]param([Parameter(Mandatory)]$Dependencies,[Parameter(Mandatory)][scriptblock]$Engine,[switch]$Execute,[string]$ApprovalToken)
 $dry=& $Engine $Dependencies $true $null;if(-not $Execute){return $dry};if($ApprovalToken -ne 'APPROVE_PRODUCTION_BOOTSTRAP'){throw 'Wizard stopped before execution: approval is required.'};& $Engine $Dependencies $false $ApprovalToken}
Export-ModuleMember -Function Invoke-RapBootstrapWizard
