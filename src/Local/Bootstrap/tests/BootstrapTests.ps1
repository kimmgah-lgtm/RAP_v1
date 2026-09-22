#Requires -Version 7.0
Set-StrictMode -Version Latest;$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot;Import-Module (Join-Path $root 'ResearchAutomation.Bootstrap.psd1') -Force;. (Join-Path $PSScriptRoot 'TestHarness.ps1')
$h=New-RapBootstrapTestHarness
$dry=Invoke-RapProductionBootstrap -Dependencies $h.Dependencies -DryRun
if($dry.Status -ne 'DRY_RUN' -or $dry.Total -ne 2 -or $h.State.Resets -ne 0 -or $h.State.Assignments -ne 0){throw 'Dry-run isolation failed.'}
$rejected=$false;try{Invoke-RapProductionBootstrap -Dependencies $h.Dependencies -ApprovalToken 'wrong'|Out-Null}catch{$rejected=$true};if(-not $rejected){throw 'Approval guard failed.'}
$resetCalls=0;$reset=Invoke-RapProductionCleanReset -ResetTestState {param($targets)$script:resetCalls++} -DryRun
if($reset.Status -ne 'DRY_RUN' -or -not $reset.ResearchAssetsPreserved){throw 'Reset dry-run failed.'}
$notion=@{};$notionItems=@([pscustomobject]@{LibraryId='LIB:L000001'})
$first=Invoke-RapNotionBootstrap $notionItems {param($id)if($notion.ContainsKey($id)){[pscustomobject]@{PageId=$notion[$id]}}} {param($item)$notion[$item.LibraryId]='PAGE-1';[pscustomobject]@{PageId='PAGE-1'}}
$second=Invoke-RapNotionBootstrap $notionItems {param($id)if($notion.ContainsKey($id)){[pscustomobject]@{PageId=$notion[$id]}}} {throw 'Duplicate Notion page attempted.'}
if($first.Status -ne 'CREATED' -or $second.Status -ne 'ALREADY_EXISTS'){throw 'Notion idempotency failed.'}
Write-Host 'SPR-005 bootstrap unit tests: PASS'
