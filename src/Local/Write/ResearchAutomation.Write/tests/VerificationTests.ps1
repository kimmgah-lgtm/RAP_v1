#Requires -Version 7.0
Set-StrictMode -Version Latest;$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot;Import-Module (Join-Path $root 'ResearchAutomation.Write.psd1') -Force;. (Join-Path $PSScriptRoot 'TestHarness.ps1')
$audit=Join-Path ([IO.Path]::GetTempPath()) ("rap-verify-$PID.jsonl");$h=New-RapWriteTestHarness $audit
$dry=Write-RapTag $h.Context ITEM0001 'rap:reviewed' 'op-dry' -DryRun
if($dry.Status -ne 'DRY_RUN' -or $h.State.PatchCount -ne 0 -or $h.State.Item.data.tags.Count -ne 0){throw 'Dry run changed state'}
$invalid=Write-RapLibraryId $h.Context BADKEY00 'LIB:L000002' 'op-invalid';if($invalid.Status -ne 'VALIDATION_FAILED' -or $h.State.Queue.Count -ne 1){throw 'Invalid item handling failed'}
Write-Host 'SPR-003 verification/dry-run/validation tests: PASS'

