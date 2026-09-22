Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot '../CommandBase.psm1') -Force
function New-WriteExtraCommand {<#
.SYNOPSIS
Creates a transactional Extra update command.
.DESCRIPTION
Returns a command object implementing Validate, Execute, Verify, and Rollback.
#>[CmdletBinding()]param([Parameter(Mandatory)][string]$ItemKey,[Parameter(Mandatory)][AllowEmptyString()][string]$Extra,[string]$OperationID=([guid]::NewGuid().ToString()),[string]$Operator=[Environment]::UserName) New-RapWriteCommand WriteExtra $ItemKey @{Extra=$Extra} $OperationID $Operator}
Export-ModuleMember -Function New-WriteExtraCommand
