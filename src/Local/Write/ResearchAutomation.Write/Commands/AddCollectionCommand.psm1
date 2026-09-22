Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot '../CommandBase.psm1') -Force
function New-AddCollectionCommand {<#
.SYNOPSIS
Creates a command that adds one collection membership.
.DESCRIPTION
Returns a command object implementing Validate, Execute, Verify, and Rollback.
#>[CmdletBinding()]param([Parameter(Mandatory)][string]$ItemKey,[Parameter(Mandatory)][string]$CollectionKey,[string]$OperationID=([guid]::NewGuid().ToString()),[string]$Operator=[Environment]::UserName) New-RapWriteCommand AddCollection $ItemKey @{CollectionKey=$CollectionKey} $OperationID $Operator}
Export-ModuleMember -Function New-AddCollectionCommand
