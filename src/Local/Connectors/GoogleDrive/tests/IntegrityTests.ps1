#Requires -Version 7.0
Set-StrictMode -Version Latest;$ErrorActionPreference='Stop';$root=Split-Path -Parent $PSScriptRoot;Import-Module (Join-Path $root 'GoogleDrive.psd1') -Force;. (Join-Path $PSScriptRoot 'TestHarness.ps1')
$audit=Join-Path ([IO.Path]::GetTempPath()) "integrity-audit-$PID.jsonl";$h=New-RapDriveTestHarness $audit;$index=@(Build-RapDriveIndex $h.Context @(Scan-RapDriveFolder $h.Context))
$good=[pscustomobject]@{ItemKey='ITEM0001';LibraryId='LIB:L000001';Path='G:\Drive\paper.pdf';DriveFileId='FILE0001';ExpectedSHA256=$index[0].SHA256}
$result=Test-RapLinkedAttachment $good $index;if($result.Status -ne 'VERIFIED'){throw 'Linked verification failed'}
$missing=[pscustomobject]@{ItemKey='ITEM0002';LibraryId='LIB:L000099';Path='G:\Drive\missing.pdf';DriveFileId='MISSING1';ExpectedSHA256=$null};if((Test-RapLinkedAttachment $missing $index).Status -ne 'MISSING_PDF'){throw 'Missing PDF detection failed'}
$wrongHash=$good.PSObject.Copy();$wrongHash.ExpectedSHA256='0'*64;if((Test-RapLinkedAttachment $wrongHash $index).Status -ne 'HASH_MISMATCH'){throw 'Hash mismatch detection failed'}
$duplicate=@($index)+$index[0];if(@(Find-RapDriveDuplicates $duplicate).Count -eq 0){throw 'Duplicate detection failed'}
$report=Invoke-RapDriveIntegrityScan $index @($good,$missing,$wrongHash) $audit;if($report.Status -ne 'FAIL' -or $report.Missing -ne 1 -or $report.HashFailures -ne 1){throw 'Integrity report failed'}
if(-not(Test-Path $audit)){throw 'Drive audit missing'};Remove-Item -LiteralPath $audit -Force
Write-Host 'SPR-004 integrity/broken-link/duplicate tests: PASS'
