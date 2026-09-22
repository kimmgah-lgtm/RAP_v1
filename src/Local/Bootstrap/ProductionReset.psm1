Set-StrictMode -Version Latest
function Invoke-RapProductionCleanReset {<#
.SYNOPSIS
Resets only explicitly scoped RAP test state after dry-run and approval.
.DESCRIPTION
Never receives or deletes research asset paths. Execution is delegated to an approved reset callback.
#>[CmdletBinding()]param([Parameter(Mandatory)][scriptblock]$ResetTestState,[switch]$DryRun,[string]$ApprovalToken)
 $targets=@('TestRegistry','TestQueue','TestAutomationLog','NEXT_LIBRARY_SEQ','NEXT_PROJECT_SEQ');if($DryRun){return [pscustomobject]@{Status='DRY_RUN';Targets=$targets;ResearchAssetsPreserved=$true}};if($ApprovalToken -ne 'APPROVE_PRODUCTION_CLEAN_RESET'){throw 'Production Clean Reset requires the exact approval token.'};& $ResetTestState $targets;[pscustomobject]@{Status='SUCCESS';Targets=$targets;ResearchAssetsPreserved=$true}}
Export-ModuleMember -Function Invoke-RapProductionCleanReset
