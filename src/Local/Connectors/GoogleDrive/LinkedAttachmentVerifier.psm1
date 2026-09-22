Set-StrictMode -Version Latest
function Test-RapLinkedAttachment {
 <#
 .SYNOPSIS Verifies one Zotero linked attachment against the Drive index.
 .DESCRIPTION Reports missing, broken, wrong-file, duplicate-link, or verified status without repair.
 #>
 [CmdletBinding()]param([Parameter(Mandatory)]$Attachment,[Parameter(Mandatory)][object[]]$DriveIndex)
 if([string]::IsNullOrWhiteSpace([string]$Attachment.Path)){return [pscustomobject]@{Status='MISSING_ATTACHMENT';Matches=0;File=$null}}
 if([string]::IsNullOrWhiteSpace([string]$Attachment.DriveFileId)){return [pscustomobject]@{Status='MISSING_DRIVE_ID';Matches=0;File=$null}}
 $matches=@($DriveIndex|Where-Object FileId -eq $Attachment.DriveFileId)
 if($matches.Count -eq 0){return [pscustomobject]@{Status='MISSING_PDF';Matches=0;File=$null}}
 if($matches.Count -gt 1){return [pscustomobject]@{Status='DUPLICATE_LINK';Matches=$matches.Count;File=$null}}
 if($matches[0].MimeType -ne 'application/pdf'){return [pscustomobject]@{Status='WRONG_FILE';Matches=1;File=$matches[0]}}
 if($Attachment.ExpectedSHA256 -and $Attachment.ExpectedSHA256 -ne $matches[0].SHA256){return [pscustomobject]@{Status='HASH_MISMATCH';Matches=1;File=$matches[0]}}
 [pscustomobject]@{Status='VERIFIED';Matches=1;File=$matches[0]}
}
Export-ModuleMember -Function Test-RapLinkedAttachment
