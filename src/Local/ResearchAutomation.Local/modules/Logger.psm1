Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:RapLogger = $null

function Initialize-RapLogger {
    <#
    .SYNOPSIS
    Initializes daily RAP logging.
    .DESCRIPTION
    Ensures the log directory exists and configures plain-text and JSON-lines
    output for subsequent Write-RapLog calls.
    .PARAMETER Directory
    Directory in which daily log files are written.
    .PARAMETER PlainEnabled
    Enables the daily plain-text log when true.
    .PARAMETER JsonEnabled
    Enables the daily JSON-lines log when true.
    .OUTPUTS
    PSCustomObject describing the active logger configuration.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Directory, [bool]$PlainEnabled = $true, [bool]$JsonEnabled = $true)
    [void][IO.Directory]::CreateDirectory($Directory)
    $script:RapLogger = [pscustomobject]@{ Directory = [IO.Path]::GetFullPath($Directory); PlainEnabled = $PlainEnabled; JsonEnabled = $JsonEnabled }
    return $script:RapLogger
}

function Write-RapLog {
    <#
    .SYNOPSIS
    Writes one event to the enabled daily RAP logs.
    .DESCRIPTION
    Appends an event to the configured plain-text and JSON-lines files using a
    local ISO 8601 timestamp and the current date as the rotation boundary.
    .PARAMETER Level
    Event severity: Debug, Information, Warning, or Error.
    .PARAMETER Message
    Human-readable event message.
    .PARAMETER Data
    Optional structured properties included in the JSON-lines record.
    .OUTPUTS
    None.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet('Debug','Information','Warning','Error')][string]$Level,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Message,
        [hashtable]$Data = @{}
    )
    if ($null -eq $script:RapLogger) { throw 'Logger has not been initialized.' }
    $now = [DateTimeOffset]::Now
    $date = $now.ToString('yyyy-MM-dd')
    $entry = [ordered]@{ timestamp = $now.ToString('o'); level = $Level; message = $Message; data = $Data }
    if ($script:RapLogger.PlainEnabled) {
        $plain = '[{0}] [{1}] {2}' -f $entry.timestamp, $Level.ToUpperInvariant(), ($Message -replace "[\r\n]+", ' ')
        Add-Content -LiteralPath (Join-Path $script:RapLogger.Directory "rap-$date.log") -Value $plain -Encoding utf8NoBOM
    }
    if ($script:RapLogger.JsonEnabled) {
        Add-Content -LiteralPath (Join-Path $script:RapLogger.Directory "rap-$date.jsonl") -Value ($entry | ConvertTo-Json -Compress -Depth 8) -Encoding utf8NoBOM
    }
}

Export-ModuleMember -Function Initialize-RapLogger, Write-RapLog
