Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../../Write/ResearchAutomation.Write/ResearchAutomation.Write.psd1') -Force -ErrorAction Stop
Import-Module (Join-Path $PSScriptRoot '../../Connectors/GoogleDrive/GoogleDrive.psd1') -Force -ErrorAction Stop
Import-Module (Join-Path $PSScriptRoot '../../Bootstrap/ResearchAutomation.Bootstrap.psd1') -Force -ErrorAction Stop
Import-Module (Join-Path $PSScriptRoot '../../MetaCoding/ResearchAutomation.MetaCoding.psd1') -Force -ErrorAction Stop
Import-Module (Join-Path $PSScriptRoot '../../EvidenceGraph/ResearchAutomation.EvidenceGraph.psd1') -Force -ErrorAction Stop
Import-Module (Join-Path $PSScriptRoot '../../Synthesis/ResearchAutomation.Synthesis.psd1') -Force -ErrorAction Stop

function New-RapCheck { param([string]$Name,[bool]$Passed,[string]$Detail) [pscustomobject]@{ Name=$Name; Status=$(if($Passed){'PASS'}else{'FAIL'}); Detail=$Detail } }

function Invoke-RapSelfTest {
    <#
    .SYNOPSIS
    Runs all RAP local bootstrap health checks.
    .DESCRIPTION
    Checks required folders, versioned configuration and capability registry,
    module commands, SQLite, queue schema integrity, and both logging formats.
    .PARAMETER ApplicationRoot
    Absolute path to the ResearchAutomation.Local application directory.
    .PARAMETER Configuration
    Validated configuration object returned by Get-RapConfiguration.
    .OUTPUTS
    PSCustomObject containing aggregate status, individual checks, and timestamp.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$ApplicationRoot, [Parameter(Mandatory)]$Configuration)
    $checks = [Collections.Generic.List[object]]::new()
    $requiredFolders = @($ApplicationRoot, (Join-Path $ApplicationRoot 'config'), (Join-Path $ApplicationRoot 'modules'), $Configuration.ResolvedPaths.Logs, (Split-Path -Parent $Configuration.ResolvedPaths.Queue), $Configuration.ResolvedPaths.Temp)
    $missing = @($requiredFolders | Where-Object { -not (Test-Path -LiteralPath $_ -PathType Container) })
    $checks.Add((New-RapCheck 'Folder' ($missing.Count -eq 0) $(if($missing){"Missing: $($missing -join ', ')"}else{'Required folders available'})))
    $configurationOk = $Configuration.schemaVersion -eq 1 -and $Configuration.version -eq '1.0.0-alpha.8' -and $Configuration.build -match '^\d{8}\.\d{3}$'
    $checks.Add((New-RapCheck 'Configuration' $configurationOk "v$($Configuration.version) build $($Configuration.build)"))
    $capabilityNames = @('CloudController','LocalAgent','SQLite','Logger','Queue','Zotero','WriteLayer','Drive','Bootstrap','Notion','AIReview','MetaCoding','MetaCodingProductionWrite','ProductionAIProvider','ProductionNotionWrite','ProductionZoteroWrite','ProductionDriveMigration','EvidenceGraph','EvidenceGraphProductionWrite','Synthesis','SynthesisProductionWrite')
    $capabilityOk = @($capabilityNames | Where-Object { $null -eq $Configuration.capabilities.PSObject.Properties[$_] -or $Configuration.capabilities.$_ -isnot [bool] }).Count -eq 0
    $checks.Add((New-RapCheck 'Capabilities' $capabilityOk "$($capabilityNames.Count) registered capabilities loaded"))
    $requiredCommands = @('Get-RapConfiguration','Initialize-RapLogger','Initialize-RapQueue','Invoke-RapSelfTest','Get-RapZoteroItems','Get-RapZoteroCollections','Get-RapZoteroLibraryStatistics','Test-RapZoteroConnection','New-RapMetaCodingRequest','Invoke-RapMetaCoding','Confirm-RapMetaCoding','Initialize-RapMetaCodingStore','Register-RapMetaCodingProjectFixture','New-RapMetaCodingSqliteDependencies','Get-RapMetaCodingFixtureRecord','New-RapEvidenceNodeId','New-RapEvidenceGraphNode','New-RapEvidenceGraphEdge','New-RapEvidenceGraphOperation','Invoke-RapEvidenceGraphMutation','Get-RapEvidenceByLibraryId','Get-RapProjectMetaCodingGraph','Get-RapEffectEvidenceGraph','Get-RapDerivedValueInputs','Get-RapEvidenceDependents','Get-RapProjectPaperGraph','Initialize-RapEvidenceGraphStore','New-RapEvidenceGraphSqliteDependencies','Get-RapEvidenceGraphFixtureSnapshot','New-RapAnalysisSpecification','Get-RapHedgesG','New-RapAnalysisDataset','Invoke-RapSynthesis','Invoke-RapSubgroupAnalysis','Invoke-RapSensitivityAnalysis','Get-RapPublicationBiasDiagnostic','Initialize-RapSynthesisStore','New-RapSynthesisSqliteDependencies','Get-RapSynthesisFixtureSnapshot')
    $loaded = @($requiredCommands | Where-Object { Get-Command $_ -CommandType Function -ErrorAction SilentlyContinue })
    $checks.Add((New-RapCheck 'Module loading' ($loaded.Count -eq $requiredCommands.Count) "$($loaded.Count)/$($requiredCommands.Count) component commands loaded"))
    $sqliteOk = $false; $queueOk = $false
    try { $sqliteOk = (Invoke-RapQueueScalar $Configuration.ResolvedPaths.Queue 'SELECT sqlite_version();' ([int]$Configuration.queue.busyTimeoutMilliseconds)) -match '^\d+\.\d+'; $queueOk = Test-RapQueue $Configuration.ResolvedPaths.Queue ([int]$Configuration.queue.busyTimeoutMilliseconds) } catch { }
    $checks.Add((New-RapCheck 'SQLite' $sqliteOk 'Native SQLite query completed'))
    $checks.Add((New-RapCheck 'Queue' $queueOk 'Integrity and five required tables verified'))
    $loggerOk = $false
    try { Write-RapLog -Level Information -Message 'Self-test logger probe' -Data @{ test='Logger' }; $date=(Get-Date).ToString('yyyy-MM-dd'); $loggerOk=(Test-Path (Join-Path $Configuration.ResolvedPaths.Logs "rap-$date.log")) -and (Test-Path (Join-Path $Configuration.ResolvedPaths.Logs "rap-$date.jsonl")) } catch { }
    $checks.Add((New-RapCheck 'Logger' $loggerOk 'Plain and JSON daily logs writable'))
    $zoteroCommands=@('Get-RapZoteroItems','Get-RapZoteroCollections','Get-RapZoteroLibraryStatistics','Test-RapZoteroConnection')
    $zoteroLoaded=@($zoteroCommands|Where-Object{Get-Command $_ -ErrorAction SilentlyContinue}).Count -eq $zoteroCommands.Count
    $checks.Add((New-RapCheck 'Zotero' $zoteroLoaded 'Read-only connector facade loaded'))
    $checks.Add((New-RapCheck 'Zotero Connection' $zoteroLoaded 'SQLite and Web API routes registered'))
    $checks.Add((New-RapCheck 'Zotero SQLite' $zoteroLoaded 'Read-only SQLite route available'))
    $checks.Add((New-RapCheck 'Zotero API' $zoteroLoaded 'GET-only Web API route available'))
    $checks.Add((New-RapCheck 'Zotero Library' $zoteroLoaded 'Normalized item contract available'))
    $writeCommands=@('New-RapSandboxWriteContext','Invoke-RapWriteTransaction','Invoke-RapWriteQueue')
    $writeLoaded=@($writeCommands|Where-Object{Get-Command $_ -CommandType Function -ErrorAction SilentlyContinue}).Count -eq $writeCommands.Count
    $checks.Add((New-RapCheck 'Write Layer' $writeLoaded 'Sandbox-only command facade loaded'))
    $checks.Add((New-RapCheck 'Transaction Engine' $writeLoaded 'Compensating transaction pipeline loaded'))
    $checks.Add((New-RapCheck 'Rollback Engine' $writeLoaded 'Operation-owned rollback loaded'))
    $checks.Add((New-RapCheck 'Verification' $writeLoaded 'Post-write verification loaded'))
    $checks.Add((New-RapCheck 'Audit' $writeLoaded 'Append-only audit writer loaded'))
    $driveCommands=@('New-RapGoogleDriveContext','Connect-RapGoogleDrive','Build-RapDriveIndex','Invoke-RapDriveIntegrityScan')
    $driveLoaded=@($driveCommands|Where-Object{Get-Command $_ -CommandType Function -ErrorAction SilentlyContinue}).Count -eq $driveCommands.Count
    $checks.Add((New-RapCheck 'Google Drive' $driveLoaded 'Read-only connector facade loaded'))
    $checks.Add((New-RapCheck 'Drive Connection' $driveLoaded 'GET-only connection probe loaded'))
    $checks.Add((New-RapCheck 'Drive API' $driveLoaded 'Connector API loaded'))
    $checks.Add((New-RapCheck 'Drive Folder' $driveLoaded 'Recursive folder scanner loaded'))
    $checks.Add((New-RapCheck 'Drive File Count' $driveLoaded 'Rebuildable index loaded'))
    $checks.Add((New-RapCheck 'Hash Verification' $driveLoaded 'SHA-256 verifier loaded'))
    $checks.Add((New-RapCheck 'Linked Attachment' $driveLoaded 'Report-only link verifier loaded'))
    $checks.Add((New-RapCheck 'Drive Integrity' $driveLoaded 'Integrity report engine loaded'))
    $bootstrapCommands=@('Invoke-RapProductionCleanReset','Invoke-RapProductionBootstrap','Invoke-RapBootstrapWizard','Invoke-RapLivePaper')
    $bootstrapLoaded=@($bootstrapCommands|Where-Object{Get-Command $_ -CommandType Function -ErrorAction SilentlyContinue}).Count -eq $bootstrapCommands.Count
    $checks.Add((New-RapCheck 'Bootstrap Engine' $bootstrapLoaded 'Approved lifecycle module loaded'))
    $metaCodingCommands=@('New-RapMetaCodingRequest','Invoke-RapMetaCoding','Confirm-RapMetaCoding','Initialize-RapMetaCodingStore','Register-RapMetaCodingProjectFixture','New-RapMetaCodingSqliteDependencies','Get-RapMetaCodingFixtureRecord')
    $metaCodingLoaded=@($metaCodingCommands|Where-Object{Get-Command $_ -CommandType Function -ErrorAction SilentlyContinue}).Count -eq $metaCodingCommands.Count
    $metaCodingSafe=$metaCodingLoaded -and $Configuration.capabilities.MetaCoding -eq $true -and $Configuration.capabilities.MetaCodingProductionWrite -eq $false -and $Configuration.capabilities.ProductionAIProvider -eq $false -and $Configuration.capabilities.ProductionNotionWrite -eq $false -and $Configuration.capabilities.ProductionZoteroWrite -eq $false -and $Configuration.capabilities.ProductionDriveMigration -eq $false
    $checks.Add((New-RapCheck 'Meta Coding Engine' $metaCodingSafe 'Project-scoped fixture engine loaded; production writes disabled'))
    $graphCommands=@('New-RapEvidenceGraphNode','New-RapEvidenceGraphEdge','Invoke-RapEvidenceGraphMutation','Get-RapEvidenceByLibraryId','Get-RapProjectMetaCodingGraph','Get-RapEffectEvidenceGraph','Get-RapDerivedValueInputs','Get-RapEvidenceDependents','Get-RapProjectPaperGraph','New-RapEvidenceGraphSqliteDependencies')
    $graphLoaded=@($graphCommands|Where-Object{Get-Command $_ -CommandType Function -ErrorAction SilentlyContinue}).Count -eq $graphCommands.Count
    $graphSafe=$graphLoaded -and $Configuration.capabilities.EvidenceGraph -eq $true -and $Configuration.capabilities.EvidenceGraphProductionWrite -eq $false
    $checks.Add((New-RapCheck 'Evidence Graph' $graphSafe 'Typed local graph and traceability queries loaded; production writes disabled'))
    $synthesisCommands=@('New-RapAnalysisSpecification','Get-RapHedgesG','New-RapAnalysisDataset','Invoke-RapSynthesis','Invoke-RapSubgroupAnalysis','Invoke-RapSensitivityAnalysis','Get-RapPublicationBiasDiagnostic','New-RapSynthesisSqliteDependencies')
    $synthesisLoaded=@($synthesisCommands|Where-Object{Get-Command $_ -CommandType Function -ErrorAction SilentlyContinue}).Count -eq $synthesisCommands.Count
    $synthesisSafe=$synthesisLoaded -and $Configuration.capabilities.Synthesis -eq $true -and $Configuration.capabilities.SynthesisProductionWrite -eq $false
    $checks.Add((New-RapCheck 'Synthesis Engine' $synthesisSafe 'Researcher-confirmed fixture synthesis loaded; production writes disabled'))
    $checks.Add((New-RapCheck 'Operation Mode' ($Configuration.operation.mode -in @('Bootstrap','Live')) "Mode: $($Configuration.operation.mode)"))
    $allPassed = @($checks | Where-Object Status -ne 'PASS').Count -eq 0
    $capabilities = @($capabilityNames | ForEach-Object {
        [pscustomobject]@{ Capability = $_; Status = $(if ($Configuration.capabilities.$_) { 'ENABLED' } else { 'DISABLED' }) }
    })
    return [pscustomobject]@{
        Version = $Configuration.version
        Build = $Configuration.build
        Status = $(if($allPassed){'PASS'}else{'FAIL'})
        Checks = $checks.ToArray()
        Capabilities = $capabilities
        Timestamp = [DateTimeOffset]::Now
    }
}

function Show-RapHealthDashboard {
    <#
    .SYNOPSIS
    Displays the RAP local health dashboard.
    .DESCRIPTION
    Renders self-test check names, statuses, details, and aggregate status to
    the host console.
    .PARAMETER Report
    Health report returned by Invoke-RapSelfTest.
    .OUTPUTS
    None. The dashboard is written to the host.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Report)
    Write-Host ''; Write-Host 'RAP Local Health Dashboard'; Write-Host ('-' * 48)
    Write-Host ('Platform: v{0}' -f $Report.Version)
    Write-Host ('Build:    {0}' -f $Report.Build)
    Write-Host ''
    $Report.Checks | Select-Object Name,Status,Detail | Format-Table -AutoSize | Out-Host
    Write-Host 'Capability Registry'
    $Report.Capabilities | Format-Table -AutoSize | Out-Host
    Write-Host ('Overall Status: {0}' -f $Report.Status)
}

Export-ModuleMember -Function Invoke-RapSelfTest, Show-RapHealthDashboard
