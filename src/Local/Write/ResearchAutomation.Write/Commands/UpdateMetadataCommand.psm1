Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot '../CommandBase.psm1') -Force
function New-UpdateMetadataCommand {<#
.SYNOPSIS
Creates an allowlisted metadata update command.
.DESCRIPTION
Returns a command object implementing Validate, Execute, Verify, and Rollback.
#>[CmdletBinding()]param([Parameter(Mandatory)][string]$ItemKey,[Parameter(Mandatory)][hashtable]$Fields,[string]$OperationID=([guid]::NewGuid().ToString()),[string]$Operator=[Environment]::UserName) New-RapWriteCommand UpdateMetadata $ItemKey @{Fields=$Fields} $OperationID $Operator}
Export-ModuleMember -Function New-UpdateMetadataCommand
