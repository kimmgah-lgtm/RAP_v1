Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'GoogleDriveConnector.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'DriveHash.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'DriveIndex.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'LinkedAttachmentVerifier.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'IntegrityEngine.psm1') -Force
Export-ModuleMember -Function New-RapGoogleDriveContext,Connect-RapGoogleDrive,Find-RapDriveFile,Get-RapDriveFileMetadata,Scan-RapDriveFolder,Get-RapDriveSHA256,Test-RapDriveSHA256,Build-RapDriveIndex,Test-RapLinkedAttachment,Find-RapDriveDuplicates,Invoke-RapDriveIntegrityScan
