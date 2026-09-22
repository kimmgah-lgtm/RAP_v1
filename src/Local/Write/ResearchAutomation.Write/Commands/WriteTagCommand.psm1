Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot '../CommandBase.psm1') -Force
function New-WriteTagCommand {<#
.SYNOPSIS
Creates a command that adds one rap: system tag.
.DESCRIPTION
Returns a command object implementing Validate, Execute, Verify, and Rollback.
#>[CmdletBinding()]param([Parameter(Mandatory)][string]$ItemKey,[Parameter(Mandatory)][string]$Tag,[string]$OperationID=([guid]::NewGuid().ToString()),[string]$Operator=[Environment]::UserName) New-RapWriteCommand WriteTag $ItemKey @{Tag=$Tag} $OperationID $Operator}
Export-ModuleMember -Function New-WriteTagCommand
