#Requires -Version 7.0
Set-StrictMode -Version Latest;$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot;Import-Module (Join-Path $root 'ResearchAutomation.Write.psd1') -Force;. (Join-Path $PSScriptRoot 'TestHarness.ps1')
$audit=Join-Path ([IO.Path]::GetTempPath()) ("rap-accept-$PID.jsonl");$h=New-RapWriteTestHarness $audit
$commands=@(New-WriteTagCommand ITEM0001 'rap:system' 'q1')
$results=@(Invoke-RapWriteQueue $commands $h.Context);if($results[0].Status -ne 'SUCCESS'){throw 'Queue execution failed'}
$attachment=New-RapLinkedAttachment $h.Context ITEM0001 'C:\Sandbox\paper.pdf' 'Paper' 'application/pdf' 'att1';if($attachment.Status -ne 'SUCCESS' -or $h.State.Children.Count -ne 1){throw 'Linked attachment transaction failed'}
$blocked=$false;try{New-RapSandboxWriteContext -SandboxLibraryId 999 -ApiKey x -AuditPath $audit -Transport {param($r)[pscustomobject]@{data=[pscustomobject]@{name='Production Library'}}}|Out-Null}catch{$blocked=$true};if(-not $blocked){throw 'Production library guard failed'}
if(Test-Path $audit){Remove-Item -LiteralPath $audit -Force}
Write-Host 'SPR-003 acceptance/queue/sandbox tests: PASS'

