Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'Models/IntegrityReport.ps1')
Import-Module (Join-Path $PSScriptRoot 'LinkedAttachmentVerifier.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'DriveAudit.psm1') -Force
function Find-RapDriveDuplicates {<#
.SYNOPSIS
Reports duplicate PDFs by SHA-256, filename, Drive ID, or Library_ID.
#>[CmdletBinding()]param([Parameter(Mandatory)][object[]]$DriveIndex)$duplicates=[Collections.Generic.List[object]]::new();foreach($field in @('SHA256','FileName','FileId','LibraryId')){foreach($group in @($DriveIndex|Where-Object{-not[string]::IsNullOrWhiteSpace([string]$_.$field)}|Group-Object $field|Where-Object Count -gt 1)){$duplicates.Add([pscustomobject]@{Basis=$field;Value=$group.Name;Count=$group.Count;Files=@($group.Group.FileId)})}};$duplicates.ToArray()}
function Invoke-RapDriveIntegrityScan {<#
.SYNOPSIS
Builds a complete report-only Drive and linked-attachment integrity result.
.DESCRIPTION
Reports verified, missing, broken, duplicate, mismatched, and orphan PDFs without repair.
#>[CmdletBinding()]param([Parameter(Mandatory)][object[]]$DriveIndex,[Parameter(Mandatory)][object[]]$Attachments,[Parameter(Mandatory)][string]$AuditPath)$started=[DateTimeOffset]::UtcNow;$details=@($Attachments|ForEach-Object{$attachment=$_;$check=Test-RapLinkedAttachment $attachment $DriveIndex;[pscustomobject]@{ItemKey=$attachment.ItemKey;LibraryId=$attachment.LibraryId;Path=$attachment.Path;Status=$check.Status;File=$check.File}});$duplicates=@(Find-RapDriveDuplicates $DriveIndex);$linkedIds=@($details|Where-Object{$_.File}|ForEach-Object{$_.File.FileId}|Sort-Object -Unique);$report=[RapIntegrityReport]::new();$report.Timestamp=[DateTimeOffset]::UtcNow.ToString('o');$report.TotalPDFs=$DriveIndex.Count;$report.Verified=@($details|Where-Object Status -eq VERIFIED).Count;$report.Missing=@($details|Where-Object Status -in @('MISSING_PDF','MISSING_ATTACHMENT')).Count;$report.BrokenLinks=@($details|Where-Object Status -in @('MISSING_PDF','MISSING_ATTACHMENT','WRONG_FILE')).Count;$report.DuplicatePDFs=$duplicates.Count;$report.HashFailures=@($details|Where-Object Status -eq HASH_MISMATCH).Count;$report.OrphanPDFs=@($DriveIndex|Where-Object FileId -notin $linkedIds).Count;$report.Details=$details;$report.Warnings=@($duplicates);$report.Status=$(if($report.Missing+$report.BrokenLinks+$report.DuplicatePDFs+$report.HashFailures){'FAIL'}else{'PASS'});foreach($detail in $details){$file=$detail.File;$fileId=$(if($file){$file.FileId}else{$null});$hash=$(if($file){$file.SHA256}else{$null});Write-RapDriveAudit $AuditPath ([ordered]@{Timestamp=[DateTimeOffset]::UtcNow.ToString('o');Operation='VerifyLinkedAttachment';FileID=$fileId;Library_ID=$detail.LibraryId;SHA256=$hash;VerificationResult=$detail.Status;Duration=([DateTimeOffset]::UtcNow-$started).TotalMilliseconds})};return $report}
Export-ModuleMember -Function Find-RapDriveDuplicates,Invoke-RapDriveIntegrityScan
