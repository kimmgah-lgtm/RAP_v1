#Requires -Version 7.0
Set-StrictMode -Version Latest;$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot;Import-Module (Join-Path $root 'ResearchAutomation.Write.psd1') -Force;. (Join-Path $PSScriptRoot 'TestHarness.ps1')
$audit=Join-Path ([IO.Path]::GetTempPath()) ("rap-audit-$PID.jsonl");$h=New-RapWriteTestHarness $audit
$result=Write-RapLibraryId $h.Context ITEM0001 'LIB:L000001' 'op-success'
if($result.Status -ne 'SUCCESS' -or $h.State.Item.data.extra -notmatch 'LIB:L000001'){throw 'Transaction commit failed'}
$again=Write-RapLibraryId $h.Context ITEM0001 'LIB:L000001' 'op-repeat';if($again.Status -ne 'ALREADY_EXISTS' -or $h.State.PatchCount -ne 1){throw 'Idempotency failed'}
if(-not(Test-Path $audit) -or @(Get-Content $audit).Count -ne 1){throw 'Audit write failed'}
Remove-Item -LiteralPath $audit -Force
Write-Host 'SPR-003 transaction/audit/idempotency tests: PASS'
