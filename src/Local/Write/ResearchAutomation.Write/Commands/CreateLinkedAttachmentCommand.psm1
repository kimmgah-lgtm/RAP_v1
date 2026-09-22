Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot '../CommandBase.psm1') -Force
function New-CreateLinkedAttachmentCommand {<#
.SYNOPSIS
Creates a linked attachment registration command.
.DESCRIPTION
Returns a command whose rollback may remove only its own created attachment.
#>[CmdletBinding()]param([Parameter(Mandatory)][string]$ItemKey,[Parameter(Mandatory)][string]$Path,[Parameter(Mandatory)][string]$Title,[string]$ContentType='application/pdf',[string]$OperationID=([guid]::NewGuid().ToString()),[string]$Operator=[Environment]::UserName) New-RapWriteCommand CreateLinkedAttachment $ItemKey @{Path=$Path;Title=$Title;ContentType=$ContentType} $OperationID $Operator}
Export-ModuleMember -Function New-CreateLinkedAttachmentCommand
