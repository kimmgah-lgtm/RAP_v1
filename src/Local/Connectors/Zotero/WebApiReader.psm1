Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-RapZoteroWebApiRead {
    <#
    .SYNOPSIS Reads a Zotero Web API resource using HTTP GET.
    .DESCRIPTION Builds a URI beneath the configured API base URL and performs
    a GET request. No mutating HTTP method is implemented.
    .PARAMETER BaseUrl Zotero API base URL.
    .PARAMETER Resource Relative API resource beginning with users or groups.
    .PARAMETER ApiKey Optional Zotero API key used only in the request header.
    .PARAMETER RequestInvoker Optional test transport accepting a request map.
    .OUTPUTS Deserialized API response.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][uri]$BaseUrl,
        [Parameter(Mandatory)][ValidatePattern('^(users|groups)/')][string]$Resource,
        [AllowEmptyString()][string]$ApiKey,
        [scriptblock]$RequestInvoker
    )
    $base = $BaseUrl.AbsoluteUri.TrimEnd('/') + '/'
    $uri = [uri]::new([uri]$base, $Resource)
    if ($uri.Scheme -ne 'https' -and -not $uri.IsLoopback) { throw 'Remote Zotero API URLs must use HTTPS.' }
    if ($uri.AbsoluteUri -notlike "$base*") { throw 'Zotero API resource escaped the configured base URL.' }
    $headers = @{ 'Zotero-API-Version' = '3' }
    if (-not [string]::IsNullOrWhiteSpace($ApiKey)) { $headers['Zotero-API-Key'] = $ApiKey }
    $request = @{ Method='GET'; Uri=$uri.AbsoluteUri; Headers=$headers }
    if ($RequestInvoker) { return & $RequestInvoker $request }
    return Invoke-RestMethod @request -ErrorAction Stop
}

function Test-RapZoteroWebApiConnection {
    [CmdletBinding()]
    param([Parameter(Mandatory)][uri]$BaseUrl, [Parameter(Mandatory)][ValidateSet('users','groups')][string]$LibraryType, [Parameter(Mandatory)][string]$LibraryId, [string]$ApiKey, [scriptblock]$RequestInvoker)
    try { [void](Invoke-RapZoteroWebApiRead -BaseUrl $BaseUrl -Resource "$LibraryType/$LibraryId/items?limit=1" -ApiKey $ApiKey -RequestInvoker $RequestInvoker); return $true } catch { return $false }
}

Export-ModuleMember -Function Invoke-RapZoteroWebApiRead, Test-RapZoteroWebApiConnection
