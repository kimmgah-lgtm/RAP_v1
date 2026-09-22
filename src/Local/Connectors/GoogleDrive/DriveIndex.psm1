Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'DriveHash.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'GoogleDriveConnector.psm1') -Force
. (Join-Path $PSScriptRoot 'Models/DriveFile.ps1')
function Build-RapDriveIndex {
 <#
 .SYNOPSIS Rebuilds the complete local in-memory Drive PDF index.
 .PARAMETER Context Read-only Drive connector context.
 .PARAMETER Files Optional injected scan result.
 .OUTPUTS RapDriveFile entries.
 #>
 [CmdletBinding()]param([Parameter(Mandatory)]$Context,[object[]]$Files)
 if($null -eq $Files){$Files=@(Scan-RapDriveFolder $Context)}
 @($Files|ForEach-Object{$entry=[RapDriveFile]::new();$entry.FileId=$_.id;$entry.FileName=$_.name;$entry.FileSize=[long]$_.size;$entry.ModifiedTime=$_.modifiedTime;$entry.RelativeFolder=$_.RelativeFolder;$entry.MimeType=$_.mimeType;$apps=$_.PSObject.Properties['appProperties'];if($apps){$library=$apps.Value.PSObject.Properties['Library_ID'];if($library){$entry.LibraryId=[string]$library.Value}};try{$bytes=Get-RapDriveFileContent $Context $_.id;$entry.SHA256=Get-RapDriveSHA256 $bytes;$entry.Status='INDEXED'}catch{$entry.Status='UNAVAILABLE'};$entry})
}
Export-ModuleMember -Function Build-RapDriveIndex
