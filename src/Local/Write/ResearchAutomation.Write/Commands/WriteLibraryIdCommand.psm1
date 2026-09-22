Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot '../CommandBase.psm1') -Force
function New-WriteLibraryIdCommand {<#
.SYNOPSIS
Creates a command that assigns a validated Library_ID in Extra.
.DESCRIPTION
Returns a command object implementing Validate, Execute, Verify, and Rollback.
#>[CmdletBinding()]param([Parameter(Mandatory)][string]$ItemKey,[Parameter(Mandatory)][string]$LibraryId,[string]$OperationID=([guid]::NewGuid().ToString()),[string]$Operator=[Environment]::UserName) New-RapWriteCommand WriteLibraryId $ItemKey @{LibraryId=$LibraryId} $OperationID $Operator}
Export-ModuleMember -Function New-WriteLibraryIdCommand
