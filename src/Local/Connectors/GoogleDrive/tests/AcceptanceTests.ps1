#Requires -Version 7.0
Set-StrictMode -Version Latest;$ErrorActionPreference='Stop';$root=Split-Path -Parent $PSScriptRoot;Import-Module (Join-Path $root 'GoogleDrive.psd1') -Force;. (Join-Path $PSScriptRoot 'TestHarness.ps1')
$audit=Join-Path ([IO.Path]::GetTempPath()) "drive-accept-$PID.jsonl";$h=New-RapDriveTestHarness $audit;$files=@(Scan-RapDriveFolder $h.Context);$index=@(Build-RapDriveIndex $h.Context $files)
$link=[pscustomobject]@{ItemKey='ITEM0001';LibraryId='LIB:L000001';Path='G:\Drive\paper.pdf';DriveFileId='FILE0001';ExpectedSHA256=$index[0].SHA256};$report=Invoke-RapDriveIntegrityScan $index @($link) $audit
if($report.Verified -ne 1 -or $report.Status -ne 'PASS'){throw 'Acceptance scenario 1 failed'}
$before=@($h.State.Bytes.FILE0001);[void](Invoke-RapDriveIntegrityScan $index @($link) $audit);if([Convert]::ToBase64String($before) -ne [Convert]::ToBase64String($h.State.Bytes.FILE0001)){throw 'PDF content was modified'}
if(@($h.State.Requests|Where-Object Method -ne GET).Count){throw 'Write request detected'}
Remove-Item -LiteralPath $audit -Force
Write-Host 'SPR-004 acceptance/no-modification tests: PASS'
