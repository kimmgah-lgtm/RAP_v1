Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

function Invoke-RapDriveReadRequest {
 param($Context,[string]$Resource,[switch]$Raw)
 $uri=$Context.BaseUrl.TrimEnd('/')+'/'+$Resource.TrimStart('/');$request=@{Method='GET';Uri=$uri;Headers=@{Authorization="Bearer $($Context.AccessToken)"}}
 if($Context.Transport){return & $Context.Transport $request ([bool]$Raw)}
 if($Raw){return Invoke-WebRequest @request -ErrorAction Stop|ForEach-Object Content}
 Invoke-RestMethod @request -ErrorAction Stop
}
function New-RapGoogleDriveContext {
 <#
 .SYNOPSIS Creates a read-only Google Drive connector context.
 .DESCRIPTION Configures GET-only Drive API access and optional injected test transport.
 .PARAMETER FolderId Approved root folder ID.
 .PARAMETER AccessToken OAuth access token held in memory only.
 .PARAMETER AuditPath Verification audit JSONL path.
 .PARAMETER Transport Optional test transport.
 .OUTPUTS Read-only connector context.
 #>
 [CmdletBinding()]param([Parameter(Mandatory)][string]$FolderId,[Parameter(Mandatory)][string]$AccessToken,[Parameter(Mandatory)][string]$AuditPath,[uri]$BaseUrl=[uri]'https://www.googleapis.com/drive/v3/',[scriptblock]$Transport)
 if($FolderId -notmatch '^[A-Za-z0-9_-]+$'){throw 'Invalid Drive folder ID.'};if([string]::IsNullOrWhiteSpace($AccessToken)){throw 'Drive access token is required.'}
 [pscustomobject]@{FolderId=$FolderId;AccessToken=$AccessToken;AuditPath=[IO.Path]::GetFullPath($AuditPath);BaseUrl=$BaseUrl.AbsoluteUri;Transport=$Transport}
}
function Connect-RapGoogleDrive {
 <# .SYNOPSIS Verifies read-only Google Drive API availability. #>
 [CmdletBinding()]param([Parameter(Mandatory)]$Context)
 try{[void](Invoke-RapDriveReadRequest $Context 'about?fields=user(displayName)');$true}catch{$false}
}
function Get-RapDriveFileMetadata {
 <# .SYNOPSIS Reads metadata for one Google Drive file. #>
 [CmdletBinding()]param([Parameter(Mandatory)]$Context,[Parameter(Mandatory)][string]$FileId)
 Invoke-RapDriveReadRequest $Context "files/$FileId`?fields=id,name,mimeType,size,modifiedTime,parents,appProperties,trashed"
}
function Get-RapDriveFileContent {
 [CmdletBinding()]param([Parameter(Mandatory)]$Context,[Parameter(Mandatory)][string]$FileId)
 [byte[]](Invoke-RapDriveReadRequest $Context "files/$FileId`?alt=media" -Raw)
}
function Find-RapDriveFile {
 <# .SYNOPSIS Finds non-trashed files by exact name under the approved Drive folder. #>
 [CmdletBinding()]param([Parameter(Mandatory)]$Context,[Parameter(Mandatory)][string]$FileName)
 $escaped=$FileName.Replace("'","\'");$q=[uri]::EscapeDataString("name = '$escaped' and '$($Context.FolderId)' in parents and trashed = false")
 @((Invoke-RapDriveReadRequest $Context "files?q=$q&fields=files(id,name,mimeType,size,modifiedTime,parents,appProperties,trashed)").files)
}
function Scan-RapDriveFolder {
 <#
 .SYNOPSIS Recursively scans the approved Drive folder without modifying it.
 .DESCRIPTION Reads folder children and returns PDF metadata with relative folder paths.
 #>
 [CmdletBinding()]param([Parameter(Mandatory)]$Context)
 $results=[Collections.Generic.List[object]]::new();$pending=[Collections.Generic.Queue[object]]::new();$pending.Enqueue([pscustomobject]@{Id=$Context.FolderId;Path=''})
 while($pending.Count){$folder=$pending.Dequeue();$q=[uri]::EscapeDataString("'$($folder.Id)' in parents and trashed = false");$response=Invoke-RapDriveReadRequest $Context "files?q=$q&fields=files(id,name,mimeType,size,modifiedTime,parents,appProperties,trashed)&pageSize=1000";foreach($file in @($response.files)){if($file.mimeType -eq 'application/vnd.google-apps.folder'){$path=if($folder.Path){"$($folder.Path)/$($file.name)"}else{$file.name};$pending.Enqueue([pscustomobject]@{Id=$file.id;Path=$path})}elseif($file.mimeType -eq 'application/pdf'){$file|Add-Member NoteProperty RelativeFolder $folder.Path -Force;$results.Add($file)}}}
 return $results.ToArray()
}
Export-ModuleMember -Function New-RapGoogleDriveContext,Connect-RapGoogleDrive,Find-RapDriveFile,Get-RapDriveFileMetadata,Get-RapDriveFileContent,Scan-RapDriveFolder
