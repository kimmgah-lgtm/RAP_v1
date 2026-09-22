#Requires -Version 7.0
Set-StrictMode -Version Latest;$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot;Import-Module (Join-Path $root 'ResearchAutomation.Write.psd1') -Force;. (Join-Path $PSScriptRoot 'TestHarness.ps1')
$audit=Join-Path ([IO.Path]::GetTempPath()) ("rap-rollback-$PID.jsonl");$h=New-RapWriteTestHarness $audit;$h.State.FailVerification=$true
$result=Write-RapExtra $h.Context ITEM0001 'New value' 'op-rollback'
if($result.Status -ne 'ROLLBACK' -or -not $result.RollbackExecuted -or $h.State.Item.data.extra -ne ''){throw 'Verification rollback failed'}
if($h.State.Queue.Count -ne 1 -or $h.State.Events.Event -notcontains 'RollbackExecuted'){throw 'Rollback queue/event failed'}
Remove-Item -LiteralPath $audit -Force
Write-Host 'SPR-003 rollback/error queue tests: PASS'

