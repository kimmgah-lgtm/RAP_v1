#Requires -Version 7.0
Set-StrictMode -Version Latest;$ErrorActionPreference='Stop';$root=Split-Path -Parent $PSScriptRoot;Import-Module (Join-Path $root 'GoogleDrive.psd1') -Force;. (Join-Path $PSScriptRoot 'TestHarness.ps1')
$audit=Join-Path ([IO.Path]::GetTempPath()) "drive-audit-$PID.jsonl";$h=New-RapDriveTestHarness $audit
if(-not(Connect-RapGoogleDrive $h.Context)){throw 'Drive connection failed'}
$files=@(Scan-RapDriveFolder $h.Context);if($files.Count -ne 2){throw 'Recursive Drive scan failed'}
$index=@(Build-RapDriveIndex $h.Context $files);if($index.Count -ne 2 -or @($index|Where-Object{$_.SHA256 -match '^[0-9a-f]{64}$'}).Count -ne 2){throw 'Drive index/hash failed'}
if(@($h.State.Requests|Where-Object Method -ne GET).Count){throw 'Drive connector attempted a write'}
$h.State.Unavailable=$true;if(Connect-RapGoogleDrive $h.Context){throw 'API unavailable was not handled'}
Write-Host 'SPR-004 connector/scan/SHA256 tests: PASS'
