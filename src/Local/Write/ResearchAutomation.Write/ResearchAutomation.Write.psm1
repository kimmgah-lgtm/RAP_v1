Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'WriteConnector.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Transaction.psm1') -Force
Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'Commands') -Filter '*.psm1' | ForEach-Object {Import-Module $_.FullName -Force}

function Write-RapLibraryId {<#
.SYNOPSIS
Transactionally assigns a Library_ID in Extra within a Sandbox Library.
.DESCRIPTION
Creates and executes a WriteLibraryId command with verification, rollback, audit, and idempotency.
#>[CmdletBinding()]param($Context,[string]$ItemKey,[string]$LibraryId,[string]$OperationID=([guid]::NewGuid().ToString()),[switch]$DryRun) Invoke-RapWriteTransaction (New-WriteLibraryIdCommand $ItemKey $LibraryId $OperationID) $Context -DryRun:$DryRun}
function Write-RapExtra {<#
.SYNOPSIS
Transactionally updates Extra within a Sandbox Library.
.DESCRIPTION
Creates and executes a WriteExtra command through the protected pipeline.
#>[CmdletBinding()]param($Context,[string]$ItemKey,[AllowEmptyString()][string]$Extra,[string]$OperationID=([guid]::NewGuid().ToString()),[switch]$DryRun) Invoke-RapWriteTransaction (New-WriteExtraCommand $ItemKey $Extra $OperationID) $Context -DryRun:$DryRun}
function Write-RapTag {<#
.SYNOPSIS
Transactionally adds one rap: system tag within a Sandbox Library.
.DESCRIPTION
Creates and executes a WriteTag command; removal is limited to operation-owned rollback.
#>[CmdletBinding()]param($Context,[string]$ItemKey,[string]$Tag,[string]$OperationID=([guid]::NewGuid().ToString()),[switch]$DryRun) Invoke-RapWriteTransaction (New-WriteTagCommand $ItemKey $Tag $OperationID) $Context -DryRun:$DryRun}
function Add-RapCollection {<#
.SYNOPSIS
Transactionally adds an item to a collection within a Sandbox Library.
.DESCRIPTION
Creates and executes an AddCollection command through the protected pipeline.
#>[CmdletBinding()]param($Context,[string]$ItemKey,[string]$CollectionKey,[string]$OperationID=([guid]::NewGuid().ToString()),[switch]$DryRun) Invoke-RapWriteTransaction (New-AddCollectionCommand $ItemKey $CollectionKey $OperationID) $Context -DryRun:$DryRun}
function Update-RapMetadata {<#
.SYNOPSIS
Transactionally updates approved metadata fields within a Sandbox Library.
.DESCRIPTION
Creates and executes an UpdateMetadata command using the metadata allowlist.
#>[CmdletBinding()]param($Context,[string]$ItemKey,[hashtable]$Fields,[string]$OperationID=([guid]::NewGuid().ToString()),[switch]$DryRun) Invoke-RapWriteTransaction (New-UpdateMetadataCommand $ItemKey $Fields $OperationID) $Context -DryRun:$DryRun}
function New-RapLinkedAttachment {<#
.SYNOPSIS
Transactionally registers a linked attachment within a Sandbox Library.
.DESCRIPTION
Creates and verifies a linked attachment; rollback may delete only the attachment created by the same OperationID.
#>[CmdletBinding()]param($Context,[string]$ItemKey,[string]$Path,[string]$Title,[string]$ContentType='application/pdf',[string]$OperationID=([guid]::NewGuid().ToString()),[switch]$DryRun) Invoke-RapWriteTransaction (New-CreateLinkedAttachmentCommand $ItemKey $Path $Title $ContentType $OperationID) $Context -DryRun:$DryRun}
Export-ModuleMember -Function New-RapSandboxWriteContext,Invoke-RapWriteTransaction,Invoke-RapWriteQueue,Write-RapLibraryId,Write-RapExtra,Write-RapTag,Add-RapCollection,Update-RapMetadata,New-RapLinkedAttachment,New-WriteLibraryIdCommand,New-WriteExtraCommand,New-WriteTagCommand,New-AddCollectionCommand,New-UpdateMetadataCommand,New-CreateLinkedAttachmentCommand
