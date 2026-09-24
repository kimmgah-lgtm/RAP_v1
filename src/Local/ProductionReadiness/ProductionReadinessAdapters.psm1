Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

function Get-RapCredentialPresence {
    [CmdletBinding()]param([Parameter(Mandatory)][ValidatePattern('^[A-Z][A-Z0-9_]{2,127}$')][string]$EnvironmentVariable)
    -not [string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($EnvironmentVariable))
}

function New-RapExternalReadAdapter {
    [CmdletBinding()]param([Parameter(Mandatory)][ValidateSet('Zotero','GoogleDrive','Notion')][string]$System,[Parameter(Mandatory)][uri]$Endpoint,[Parameter(Mandatory)][ValidatePattern('^[A-Z][A-Z0-9_]{2,127}$')][string]$CredentialEnvironmentVariable,[Parameter(Mandatory)][scriptblock]$ReadProbe)
    if($Endpoint.Scheme-ne'https' -and -not$Endpoint.IsLoopback){throw 'EXTERNAL_ENDPOINT_REQUIRES_HTTPS'}
    [pscustomobject]@{System=$System;Endpoint=$Endpoint.AbsoluteUri;EndpointHost=$Endpoint.Host;CredentialEnvironmentVariable=$CredentialEnvironmentVariable;ReadProbe=$ReadProbe;AllowedMethod='GET';ProductionWrite='DISABLED'}
}

function Invoke-RapExternalReadProbe {
    [CmdletBinding()]param([Parameter(Mandatory)]$Adapter)
    if($Adapter.AllowedMethod-ne'GET'-or$Adapter.ProductionWrite-ne'DISABLED'){throw 'UNSAFE_EXTERNAL_ADAPTER'}
    $credentialPresent=Get-RapCredentialPresence $Adapter.CredentialEnvironmentVariable
    try{
        $response=&$Adapter.ReadProbe ([pscustomobject]@{Method='GET';Endpoint=$Adapter.Endpoint;CredentialEnvironmentVariable=$Adapter.CredentialEnvironmentVariable})
        if($null-eq$response){throw 'UNKNOWN_EXTERNAL_STATE'}
        $authorized=$response.PSObject.Properties['Authorized'] -and $response.Authorized -eq $true
        $permitted=$response.PSObject.Properties['PermissionGranted'] -and $response.PermissionGranted -eq $true
        $schema=$response.PSObject.Properties['SchemaCompatible'] -and $response.SchemaCompatible -eq $true
        $exists=$response.PSObject.Properties['RequiredObjectFound'] -and $response.RequiredObjectFound -eq $true
        $status=if(!$authorized){'AUTHENTICATION_FAILURE'}elseif(!$permitted){'PERMISSION_FAILURE'}elseif(!$schema){'SCHEMA_MISMATCH'}elseif(!$exists){'MISSING_EXTERNAL_OBJECT'}else{'PASS'}
        [pscustomobject]@{System=$Adapter.System;Status=$status;Connected=$status-eq'PASS';Authenticated=$authorized;PermissionGranted=$permitted;SchemaCompatible=$schema;RequiredObjectFound=$exists;CredentialPresent=$credentialPresent;EndpointHost=$Adapter.EndpointHost;Snapshot=$(if($response.PSObject.Properties['Snapshot']){$response.Snapshot}else{$null});ProductionWrite='DISABLED';ChangesApplied=$false}
    }catch{
        $kind=if($_.Exception.Message-match'(?i)timeout|timed out'){'EXTERNAL_TIMEOUT'}else{'EXTERNAL_FAILURE'}
        [pscustomobject]@{System=$Adapter.System;Status=$kind;Connected=$false;Authenticated=$false;PermissionGranted=$false;SchemaCompatible=$false;RequiredObjectFound=$false;CredentialPresent=$credentialPresent;EndpointHost=$Adapter.EndpointHost;Snapshot=$null;ProductionWrite='DISABLED';ChangesApplied=$false}
    }
}

function New-RapProductionReadAdapters {
    [CmdletBinding()]param([Parameter(Mandatory)][scriptblock]$ZoteroReadProbe,[Parameter(Mandatory)][scriptblock]$DriveReadProbe,[Parameter(Mandatory)][scriptblock]$NotionReadProbe,[uri]$ZoteroEndpoint=[uri]'https://api.zotero.org/',[uri]$DriveEndpoint=[uri]'https://www.googleapis.com/drive/v3/',[uri]$NotionEndpoint=[uri]'https://api.notion.com/v1/',[string]$ZoteroCredentialEnvironmentVariable='ZOTERO_API_KEY',[string]$DriveCredentialEnvironmentVariable='GOOGLE_DRIVE_ACCESS_TOKEN',[string]$NotionCredentialEnvironmentVariable='NOTION_API_TOKEN')
    [pscustomobject]@{Zotero=New-RapExternalReadAdapter Zotero $ZoteroEndpoint $ZoteroCredentialEnvironmentVariable $ZoteroReadProbe;GoogleDrive=New-RapExternalReadAdapter GoogleDrive $DriveEndpoint $DriveCredentialEnvironmentVariable $DriveReadProbe;Notion=New-RapExternalReadAdapter Notion $NotionEndpoint $NotionCredentialEnvironmentVariable $NotionReadProbe}
}

Export-ModuleMember -Function Get-RapCredentialPresence,New-RapExternalReadAdapter,Invoke-RapExternalReadProbe,New-RapProductionReadAdapters
