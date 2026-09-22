#Requires -Version 7.0
<#
.SYNOPSIS
Installs and validates the RAP local bootstrap runtime.
.DESCRIPTION
Creates required directories and configuration, initializes the SQLite queue and
daily logger, executes the complete self-test, and prints an installation summary.
#>
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try {
    $applicationRoot = $PSScriptRoot
    Import-Module (Join-Path $applicationRoot 'ResearchAutomation.Local.psd1') -Force -ErrorAction Stop
    foreach ($directory in @('config','modules','queue','logs','temp','tests')) { [void][IO.Directory]::CreateDirectory((Join-Path $applicationRoot $directory)) }
    $configuration = Initialize-RapConfiguration -ApplicationRoot $applicationRoot
    [void][IO.Directory]::CreateDirectory($configuration.ResolvedPaths.Logs)
    [void][IO.Directory]::CreateDirectory($configuration.ResolvedPaths.Temp)
    Initialize-RapLogger -Directory $configuration.ResolvedPaths.Logs -PlainEnabled $configuration.logging.plainEnabled -JsonEnabled $configuration.logging.jsonEnabled | Out-Null
    $database = Initialize-RapQueue -DatabasePath $configuration.ResolvedPaths.Queue -BusyTimeoutMilliseconds $configuration.queue.busyTimeoutMilliseconds
    Write-RapLog -Level Information -Message 'Local bootstrap installation completed' -Data @{ database=$database }
    $report = Invoke-RapSelfTest -ApplicationRoot $applicationRoot -Configuration $configuration
    Show-RapHealthDashboard -Report $report
    Write-Host ''; Write-Host 'Installation Summary'; Write-Host "Root:   $applicationRoot"; Write-Host "Config: $(Join-Path $applicationRoot 'config/config.json')"; Write-Host "Queue:  $database"; Write-Host "Status: $($report.Status)"
    if ($report.Status -ne 'PASS') { exit 1 }
} catch {
    Write-Error "RAP local installation failed: $($_.Exception.Message)"
    exit 1
}

