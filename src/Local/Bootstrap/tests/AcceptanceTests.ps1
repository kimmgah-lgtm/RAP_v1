#Requires -Version 7.0
Set-StrictMode -Version Latest;$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot;Import-Module (Join-Path $root 'ResearchAutomation.Bootstrap.psd1') -Force;. (Join-Path $PSScriptRoot 'TestHarness.ps1')
$h=New-RapBootstrapTestHarness
$first=Invoke-RapBootstrapWizard -Dependencies $h.Dependencies -Engine {param($d,$dry,$token)Invoke-RapProductionBootstrap -Dependencies $d -DryRun:$dry -ApprovalToken $token} -Execute -ApprovalToken 'APPROVE_PRODUCTION_BOOTSTRAP'
if($first.Status -ne 'PASS' -or $first.Mode -ne 'Live' -or $h.State.Ids.Count -ne 2 -or $h.State.Master.Count -ne 2 -or $h.State.Notion.Count -ne 2){throw 'First bootstrap acceptance failed.'}
$assignments=$h.State.Assignments;$second=Invoke-RapProductionBootstrap -Dependencies $h.Dependencies -ApprovalToken 'APPROVE_PRODUCTION_BOOTSTRAP'
if($second.Status -ne 'PASS' -or $h.State.Assignments -ne $assignments -or $h.State.Ids.Count -ne 2 -or $h.State.Notion.Count -ne 2){throw 'Second bootstrap idempotency failed.'}
$newItem=[pscustomobject]@{ItemKey='C0000003';Title='Paper C'};$live=Invoke-RapLivePaper -Item $newItem -Dependencies $h.Dependencies
if($live.Status -ne 'PASS' -or $h.State.Ids.Count -ne 3 -or $h.State.Master.Count -ne 3 -or $h.State.Notion.Count -ne 3 -or $h.State.Queue -ne 1 -or $h.State.Dashboard -ne 1){throw 'Live mode acceptance failed.'}
if($h.State.Resets -ne 2 -or $h.State.Backups -ne 2){throw 'Reset or backup lifecycle failed.'}
Write-Host 'SPR-005 acceptance tests: PASS'
