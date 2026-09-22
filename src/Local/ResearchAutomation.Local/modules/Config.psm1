Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-RapDataPath {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$ApplicationRoot, [Parameter(Mandatory)][string]$RelativePath)

    if ([IO.Path]::IsPathRooted($RelativePath)) { throw "Configured path must be relative: $RelativePath" }
    $root = [IO.Path]::GetFullPath($ApplicationRoot).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    $resolved = [IO.Path]::GetFullPath((Join-Path $root $RelativePath))
    if (-not $resolved.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) { throw "Configured path escapes the application root: $RelativePath" }
    return $resolved
}

function Initialize-RapConfiguration {
    <#
    .SYNOPSIS
    Initializes the RAP local configuration.
    .DESCRIPTION
    Creates the default configuration file when it is absent, preserves an
    existing file, and returns the validated configuration object.
    .PARAMETER ApplicationRoot
    Absolute path to the ResearchAutomation.Local application directory.
    .OUTPUTS
    PSCustomObject containing validated settings and resolved data paths.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$ApplicationRoot)

    $configDirectory = Join-Path $ApplicationRoot 'config'
    $configPath = Join-Path $configDirectory 'config.json'
    [void][IO.Directory]::CreateDirectory($configDirectory)
    if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
        $default = [ordered]@{
            schemaVersion = 1; version = '1.0.0-alpha.5'; build = '20260922.001'; environment = 'Local'
            paths = [ordered]@{ queue = 'queue/queue.db'; logs = 'logs'; temp = 'temp' }
            logging = [ordered]@{ minimumLevel = 'Information'; plainEnabled = $true; jsonEnabled = $true }
            queue = [ordered]@{ busyTimeoutMilliseconds = 5000 }
            zotero = [ordered]@{ preferredConnector='SQLite'; databasePath=''; storageRoot=''; webApiBaseUrl='https://api.zotero.org/'; libraryType='users'; libraryId=''; apiKeyEnvironmentVariable='ZOTERO_API_KEY' }
            writeLayer = [ordered]@{ enabled=$false; sandboxLibraryType='groups'; sandboxLibraryId=''; sandboxNamePattern='(?i)sandbox'; auditPath='logs/write-audit.jsonl' }
            googleDrive = [ordered]@{ folderId=''; accessTokenEnvironmentVariable='GOOGLE_DRIVE_ACCESS_TOKEN'; auditPath='logs/drive-audit.jsonl' }
            operation = [ordered]@{ mode='Bootstrap' }
            capabilities = [ordered]@{
                CloudController = $true; LocalAgent = $true; SQLite = $true; Logger = $true; Queue = $true
                Zotero = $true; WriteLayer = $true; Drive = $true; Bootstrap = $true; Notion = $true; AIReview = $false
            }
        }
        $default | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $configPath -Encoding utf8NoBOM
    }
    Get-RapConfiguration -Path $configPath -ApplicationRoot $ApplicationRoot
}

function Get-RapConfiguration {
    <#
    .SYNOPSIS
    Loads and validates the RAP local configuration.
    .DESCRIPTION
    Parses the JSON configuration, validates required properties and values,
    and resolves data paths while preventing escape from the application root.
    .PARAMETER Path
    Path to the configuration JSON file.
    .PARAMETER ApplicationRoot
    Absolute path used as the boundary for resolving configured relative paths.
    .OUTPUTS
    PSCustomObject containing validated settings and resolved data paths.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$ApplicationRoot)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Configuration file not found: $Path" }
    try { $configuration = Get-Content -LiteralPath $Path -Raw -Encoding utf8 | ConvertFrom-Json -ErrorAction Stop }
    catch { throw "Configuration is not valid JSON: $($_.Exception.Message)" }
    foreach ($property in @('schemaVersion', 'version', 'build', 'environment', 'paths', 'logging', 'queue', 'zotero', 'writeLayer', 'googleDrive', 'operation', 'capabilities')) {
        if ($null -eq $configuration.PSObject.Properties[$property]) { throw "Configuration property is required: $property" }
    }
    if ($configuration.schemaVersion -ne 1) { throw "Unsupported configuration schema version: $($configuration.schemaVersion)" }
    if ($configuration.version -notmatch '^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-(?:0|[1-9A-Za-z-][0-9A-Za-z-]*)(?:\.(?:0|[1-9A-Za-z-][0-9A-Za-z-]*))*)?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$') { throw 'version must be a valid Semantic Version.' }
    if ($configuration.build -notmatch '^\d{8}\.\d{3}$') { throw 'build must use YYYYMMDD.NNN format.' }
    foreach ($pathName in @('queue', 'logs', 'temp')) {
        if ($null -eq $configuration.paths.PSObject.Properties[$pathName] -or [string]::IsNullOrWhiteSpace($configuration.paths.$pathName)) { throw "Configuration path is required: $pathName" }
    }
    if ($configuration.logging.minimumLevel -notin @('Debug', 'Information', 'Warning', 'Error')) { throw 'logging.minimumLevel is invalid.' }
    $timeout = [int]$configuration.queue.busyTimeoutMilliseconds
    if ($timeout -lt 0 -or $timeout -gt 60000) { throw 'queue.busyTimeoutMilliseconds must be between 0 and 60000.' }
    if ($configuration.zotero.preferredConnector -notin @('SQLite','WebApi')) { throw 'zotero.preferredConnector must be SQLite or WebApi.' }
    if ($configuration.zotero.libraryType -notin @('users','groups')) { throw 'zotero.libraryType must be users or groups.' }
    if (-not [uri]::IsWellFormedUriString([string]$configuration.zotero.webApiBaseUrl,[UriKind]::Absolute)) { throw 'zotero.webApiBaseUrl must be an absolute URI.' }
    if($configuration.writeLayer.sandboxLibraryType -ne 'groups'){throw 'writeLayer.sandboxLibraryType must be groups.'}
    if($configuration.writeLayer.enabled -isnot [bool]){throw 'writeLayer.enabled must be Boolean.'}
    if([string]::IsNullOrWhiteSpace([string]$configuration.googleDrive.accessTokenEnvironmentVariable)){throw 'googleDrive.accessTokenEnvironmentVariable is required.'}
    if($configuration.operation.mode -notin @('Bootstrap','Live')){throw 'operation.mode must be Bootstrap or Live.'}
    foreach ($capabilityName in @('CloudController','LocalAgent','SQLite','Logger','Queue','Zotero','WriteLayer','Drive','Bootstrap','Notion','AIReview')) {
        $capability = $configuration.capabilities.PSObject.Properties[$capabilityName]
        if ($null -eq $capability) { throw "Configuration capability is required: $capabilityName" }
        if ($capability.Value -isnot [bool]) { throw "Configuration capability must be Boolean: $capabilityName" }
    }

    $configuration | Add-Member -NotePropertyName ResolvedPaths -NotePropertyValue ([pscustomobject]@{
        Queue = Resolve-RapDataPath $ApplicationRoot $configuration.paths.queue
        Logs  = Resolve-RapDataPath $ApplicationRoot $configuration.paths.logs
        Temp  = Resolve-RapDataPath $ApplicationRoot $configuration.paths.temp
        ZoteroDatabase = $(if([string]::IsNullOrWhiteSpace($configuration.zotero.databasePath)){''}else{[IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($configuration.zotero.databasePath))})
        ZoteroStorage = $(if([string]::IsNullOrWhiteSpace($configuration.zotero.storageRoot)){''}else{[IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($configuration.zotero.storageRoot))})
        WriteAudit = Resolve-RapDataPath $ApplicationRoot $configuration.writeLayer.auditPath
        DriveAudit = Resolve-RapDataPath $ApplicationRoot $configuration.googleDrive.auditPath
    }) -Force
    return $configuration
}

Export-ModuleMember -Function Get-RapConfiguration, Initialize-RapConfiguration
