#Requires -Version 7.0
<#
.SYNOPSIS
Starts and validates the RAP local agent.
.PARAMETER SelfTest
Explicitly requests the complete bootstrap self-test. Bootstrap health checks are
also run during normal startup so the agent never reports healthy on partial state.
#>
[CmdletBinding()]
param([switch]$SelfTest,[switch]$DryRun)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try {
    $applicationRoot = $PSScriptRoot
    Import-Module (Join-Path $applicationRoot 'ResearchAutomation.Local.psd1') -Force -ErrorAction Stop
    $configuration = Get-RapConfiguration -Path (Join-Path $applicationRoot 'config/config.json') -ApplicationRoot $applicationRoot
    Initialize-RapLogger -Directory $configuration.ResolvedPaths.Logs -PlainEnabled $configuration.logging.plainEnabled -JsonEnabled $configuration.logging.jsonEnabled | Out-Null
    [void](Initialize-RapQueue -DatabasePath $configuration.ResolvedPaths.Queue -BusyTimeoutMilliseconds $configuration.queue.busyTimeoutMilliseconds)
    Write-RapLog -Level Information -Message 'Local agent started' -Data @{ selfTest=[bool]$SelfTest }
    $report = Invoke-RapSelfTest -ApplicationRoot $applicationRoot -Configuration $configuration
    Show-RapHealthDashboard -Report $report
    if($DryRun){Write-Host '';Write-Host 'Write Layer: DRY RUN';Write-Host 'No queued write operations were applied.'}
    if ($report.Status -ne 'PASS') { Write-RapLog -Level Error -Message 'Local agent health check failed'; exit 1 }
    Write-RapLog -Level Information -Message 'Local agent health check passed'
} catch {
    Write-Error "RAP local agent failed: $($_.Exception.Message)"
    exit 1
}
