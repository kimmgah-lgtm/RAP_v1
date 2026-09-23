Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$moduleDirectory = Join-Path $PSScriptRoot 'modules'
@('Config', 'Logger', 'Queue', 'SelfTest') | ForEach-Object {
    Import-Module (Join-Path $moduleDirectory "$_.psm1") -Force -ErrorAction Stop
}
Import-Module (Join-Path $PSScriptRoot '../Connectors/Zotero/ZoteroConnector.psm1') -Force -ErrorAction Stop
Import-Module (Join-Path $PSScriptRoot '../Write/ResearchAutomation.Write/ResearchAutomation.Write.psm1') -Force -ErrorAction Stop
Import-Module (Join-Path $PSScriptRoot '../Bootstrap/ResearchAutomation.Bootstrap.psd1') -Force -ErrorAction Stop
Import-Module (Join-Path $PSScriptRoot '../MetaCoding/ResearchAutomation.MetaCoding.psd1') -Force -ErrorAction Stop
Import-Module (Join-Path $PSScriptRoot '../EvidenceGraph/ResearchAutomation.EvidenceGraph.psd1') -Force -ErrorAction Stop
Import-Module (Join-Path $PSScriptRoot '../Synthesis/ResearchAutomation.Synthesis.psd1') -Force -ErrorAction Stop

function Get-RapZoteroItems {
    <#
    .SYNOPSIS
    Reads normalized Zotero items through the connector boundary.
    .DESCRIPTION
    Delegates to the read-only Zotero connector facade without exposing reader schemas.
    .PARAMETER Connector
    SQLite or WebApi.
    .PARAMETER DatabasePath
    Zotero SQLite path.
    .PARAMETER StorageRoot
    Zotero data directory for storage path resolution.
    .PARAMETER BaseUrl
    Zotero Web API base URL.
    .PARAMETER LibraryType
    users or groups.
    .PARAMETER LibraryId
    Zotero library ID.
    .PARAMETER ApiKey
    Optional API key.
    .PARAMETER ItemKey
    Optional Zotero item key.
    .PARAMETER RequestInvoker
    Optional isolated test transport.
    .PARAMETER BusyTimeoutMilliseconds
    SQLite lock wait timeout.
    .OUTPUTS
    Normalized RapZoteroItem objects.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][ValidateSet('SQLite','WebApi')][string]$Connector,[string]$DatabasePath,[string]$StorageRoot,[uri]$BaseUrl=[uri]'https://api.zotero.org/',[ValidateSet('users','groups')][string]$LibraryType='users',[string]$LibraryId,[string]$ApiKey,[string]$ItemKey,[scriptblock]$RequestInvoker,[ValidateRange(0,60000)][int]$BusyTimeoutMilliseconds=5000)
    ZoteroConnector\Get-RapZoteroItems @PSBoundParameters
}

function Get-RapZoteroCollections {
    <#
    .SYNOPSIS
    Reads normalized Zotero collections through the connector boundary.
    .DESCRIPTION
    Delegates to the read-only Zotero connector facade.
    .PARAMETER Connector
    SQLite or WebApi.
    .PARAMETER DatabasePath
    Zotero SQLite path.
    .PARAMETER BaseUrl
    Zotero Web API base URL.
    .PARAMETER LibraryType
    users or groups.
    .PARAMETER LibraryId
    Zotero library ID.
    .PARAMETER ApiKey
    Optional API key.
    .PARAMETER RequestInvoker
    Optional isolated test transport.
    .PARAMETER BusyTimeoutMilliseconds
    SQLite lock wait timeout.
    .OUTPUTS
    Normalized RapZoteroCollection objects.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][ValidateSet('SQLite','WebApi')][string]$Connector,[string]$DatabasePath,[uri]$BaseUrl=[uri]'https://api.zotero.org/',[ValidateSet('users','groups')][string]$LibraryType='users',[string]$LibraryId,[string]$ApiKey,[scriptblock]$RequestInvoker,[ValidateRange(0,60000)][int]$BusyTimeoutMilliseconds=5000)
    ZoteroConnector\Get-RapZoteroCollections @PSBoundParameters
}

function Get-RapZoteroLibraryStatistics {
    <#
    .SYNOPSIS
    Returns read-only normalized Zotero library statistics.
    .DESCRIPTION
    Delegates to the connector facade and returns aggregate counts.
    .PARAMETER Connector
    SQLite or WebApi.
    .PARAMETER DatabasePath
    Zotero SQLite path.
    .PARAMETER BaseUrl
    Zotero Web API base URL.
    .PARAMETER LibraryType
    users or groups.
    .PARAMETER LibraryId
    Zotero library ID.
    .PARAMETER ApiKey
    Optional API key.
    .PARAMETER RequestInvoker
    Optional isolated test transport.
    .PARAMETER BusyTimeoutMilliseconds
    SQLite lock wait timeout.
    .OUTPUTS
    PSCustomObject containing library counts.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][ValidateSet('SQLite','WebApi')][string]$Connector,[string]$DatabasePath,[uri]$BaseUrl=[uri]'https://api.zotero.org/',[ValidateSet('users','groups')][string]$LibraryType='users',[string]$LibraryId,[string]$ApiKey,[scriptblock]$RequestInvoker,[ValidateRange(0,60000)][int]$BusyTimeoutMilliseconds=5000)
    ZoteroConnector\Get-RapZoteroLibraryStatistics @PSBoundParameters
}

function Test-RapZoteroConnection {
    <#
    .SYNOPSIS
    Tests a configured Zotero read-only connection.
    .DESCRIPTION
    Delegates to the SQLite quick-check or Web API GET-only probe.
    .PARAMETER Connector
    SQLite or WebApi.
    .PARAMETER DatabasePath
    Zotero SQLite path.
    .PARAMETER BaseUrl
    Zotero Web API base URL.
    .PARAMETER LibraryType
    users or groups.
    .PARAMETER LibraryId
    Zotero library ID.
    .PARAMETER ApiKey
    Optional API key.
    .PARAMETER RequestInvoker
    Optional isolated test transport.
    .PARAMETER BusyTimeoutMilliseconds
    SQLite lock wait timeout.
    .OUTPUTS
    Boolean connection status.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][ValidateSet('SQLite','WebApi')][string]$Connector,[string]$DatabasePath,[uri]$BaseUrl=[uri]'https://api.zotero.org/',[ValidateSet('users','groups')][string]$LibraryType='users',[string]$LibraryId,[string]$ApiKey,[scriptblock]$RequestInvoker,[ValidateRange(0,60000)][int]$BusyTimeoutMilliseconds=5000)
    ZoteroConnector\Test-RapZoteroConnection @PSBoundParameters
}

Export-ModuleMember -Function @(
    'Get-RapConfiguration', 'Initialize-RapConfiguration',
    'Initialize-RapLogger', 'Write-RapLog',
    'Initialize-RapQueue', 'Test-RapQueue', 'Invoke-RapQueueScalar',
    'Invoke-RapSelfTest', 'Show-RapHealthDashboard',
    'Get-RapZoteroItems', 'Get-RapZoteroCollections', 'Get-RapZoteroLibraryStatistics', 'Test-RapZoteroConnection',
    'New-RapMetaCodingRequest', 'Invoke-RapMetaCoding', 'Confirm-RapMetaCoding',
    'Initialize-RapMetaCodingStore', 'Register-RapMetaCodingProjectFixture', 'New-RapMetaCodingSqliteDependencies', 'Get-RapMetaCodingFixtureRecord',
    'New-RapEvidenceNodeId', 'New-RapEvidenceGraphNode', 'New-RapEvidenceGraphEdge', 'New-RapEvidenceGraphOperation', 'Invoke-RapEvidenceGraphMutation',
    'Get-RapEvidenceByLibraryId', 'Get-RapProjectMetaCodingGraph', 'Get-RapEffectEvidenceGraph', 'Get-RapDerivedValueInputs', 'Get-RapEvidenceDependents', 'Get-RapProjectPaperGraph',
    'Initialize-RapEvidenceGraphStore', 'New-RapEvidenceGraphSqliteDependencies', 'Get-RapEvidenceGraphFixtureSnapshot',
    'New-RapAnalysisSpecification', 'Get-RapHedgesG', 'New-RapAnalysisDataset', 'Invoke-RapSynthesis',
    'Invoke-RapSubgroupAnalysis', 'Invoke-RapSensitivityAnalysis', 'Get-RapPublicationBiasDiagnostic',
    'Initialize-RapSynthesisStore', 'New-RapSynthesisSqliteDependencies', 'Get-RapSynthesisFixtureSnapshot'
)
