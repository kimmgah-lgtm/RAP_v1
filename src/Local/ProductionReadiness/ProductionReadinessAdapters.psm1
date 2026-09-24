Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$script:ReadCapabilities=@{}

function Get-RapCredentialPresence {
    [CmdletBinding()]param([Parameter(Mandatory)][ValidatePattern('^[A-Z][A-Z0-9_]{2,127}$')][string]$EnvironmentVariable)
    -not [string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($EnvironmentVariable))
}

function New-RapReadCapabilityToken {
    param([Parameter(Mandatory)]$Capability)
    $id=[Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(32)).ToLowerInvariant()
    $script:ReadCapabilities[$id]=$Capability
    [pscustomobject]@{PSTypeName='Rap.ReadOnlyCapabilityToken';CapabilityId=$id;System=$Capability.System;AllowedMethod='GET';ProductionWrite='DISABLED'}
}

function Resolve-RapReadCapability {
    param([Parameter(Mandatory)]$Adapter)
    if($Adapter.PSObject.TypeNames-cnotcontains'Rap.ReadOnlyCapabilityToken'){throw 'UNTRUSTED_ADAPTER_CAPABILITY'}
    $id=[string]$Adapter.CapabilityId
    if($id-notmatch'^[a-f0-9]{64}$'-or-not$script:ReadCapabilities.ContainsKey($id)){throw 'UNTRUSTED_ADAPTER_CAPABILITY'}
    $script:ReadCapabilities[$id]
}

function New-RapExternalReadAdapter {
    [CmdletBinding()]param(
        [Parameter(Mandatory)][ValidateSet('Zotero','GoogleDrive','Notion')][string]$System,
        [Parameter(Mandatory)][uri]$Endpoint,
        [Parameter(Mandatory)][ValidatePattern('^[A-Z][A-Z0-9_]{2,127}$')][string]$CredentialEnvironmentVariable,
        [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9_?&=.%/()-]{1,512}$')][string]$ResourcePath
    )
    if($Endpoint.Scheme-ne'https' -and -not$Endpoint.IsLoopback){throw 'EXTERNAL_ENDPOINT_REQUIRES_HTTPS'}
    if($ResourcePath-match'(^|/)\.\.(/|$)'-or$ResourcePath-match'^[a-z]+:'){throw 'EXTERNAL_RESOURCE_PATH_INVALID'}
    New-RapReadCapabilityToken ([pscustomobject]@{Kind='LIVE_GET';System=$System;Endpoint=$Endpoint.AbsoluteUri;EndpointHost=$Endpoint.Host;CredentialEnvironmentVariable=$CredentialEnvironmentVariable;ResourcePath=$ResourcePath;AllowedMethod='GET';ProductionWrite='DISABLED'})
}

function New-RapFixtureReadAdapter {
    [CmdletBinding()]param(
        [Parameter(Mandatory)][ValidateSet('Zotero','GoogleDrive','Notion')][string]$System,
        [Parameter(Mandatory)][AllowNull()]$Response,
        [ValidateSet('None','EXTERNAL_TIMEOUT','EXTERNAL_FAILURE')][string]$FailureKind='None',
        [string]$CredentialEnvironmentVariable='RAP_TEST_CREDENTIAL'
    )
    $copy=if($null-eq$Response){$null}else{$Response|ConvertTo-Json -Depth 60|ConvertFrom-Json -Depth 60}
    New-RapReadCapabilityToken ([pscustomobject]@{Kind='FIXTURE_READ_ONLY';System=$System;Endpoint='https://fixture.invalid/';EndpointHost='fixture.invalid';CredentialEnvironmentVariable=$CredentialEnvironmentVariable;FixtureResponse=$copy;FailureKind=$FailureKind;AllowedMethod='GET';ProductionWrite='DISABLED'})
}

function Invoke-RapSealedGet {
    param([Parameter(Mandatory)]$Capability)
    if($Capability.AllowedMethod-cne'GET'-or$Capability.ProductionWrite-cne'DISABLED'){throw 'UNSAFE_EXTERNAL_CAPABILITY'}
    if($Capability.Kind-eq'FIXTURE_READ_ONLY'){
        if($Capability.FailureKind-ne'None'){throw $Capability.FailureKind}
        return $Capability.FixtureResponse
    }
    if($Capability.Kind-cne'LIVE_GET'){throw 'UNKNOWN_CAPABILITY_FAIL_CLOSED'}
    $secret=[Environment]::GetEnvironmentVariable($Capability.CredentialEnvironmentVariable)
    if([string]::IsNullOrWhiteSpace($secret)){throw 'AUTHENTICATION_FAILURE'}
    $base=$Capability.Endpoint.TrimEnd('/')+'/';$uri=[uri]::new([uri]$base,$Capability.ResourcePath.TrimStart('/'))
    if($uri.AbsoluteUri-notlike"$base*"){throw 'EXTERNAL_RESOURCE_ESCAPED_ENDPOINT'}
    $headers=@{}
    switch($Capability.System){'Zotero'{$headers['Zotero-API-Version']='3';$headers['Zotero-API-Key']=$secret}default{$headers.Authorization="Bearer $secret"}}
    Microsoft.PowerShell.Utility\Invoke-RestMethod -Method Get -Uri $uri.AbsoluteUri -Headers $headers -ErrorAction Stop
}

function Invoke-RapExternalReadProbe {
    [CmdletBinding()]param([Parameter(Mandatory)]$Adapter)
    $capability=Resolve-RapReadCapability $Adapter
    $credentialPresent=Get-RapCredentialPresence $capability.CredentialEnvironmentVariable
    try{
        $response=Invoke-RapSealedGet $capability
        if($null-eq$response){throw 'UNKNOWN_EXTERNAL_STATE'}
        $authorized=$response.PSObject.Properties['Authorized'] -and $response.Authorized-eq$true
        $permitted=$response.PSObject.Properties['PermissionGranted'] -and $response.PermissionGranted-eq$true
        $schema=$response.PSObject.Properties['SchemaCompatible'] -and $response.SchemaCompatible-eq$true
        $exists=$response.PSObject.Properties['RequiredObjectFound'] -and $response.RequiredObjectFound-eq$true
        $status=if(!$authorized){'AUTHENTICATION_FAILURE'}elseif(!$permitted){'PERMISSION_FAILURE'}elseif(!$schema){'SCHEMA_MISMATCH'}elseif(!$exists){'MISSING_EXTERNAL_OBJECT'}else{'PASS'}
        [pscustomobject]@{System=$capability.System;Status=$status;Connected=$status-eq'PASS';Authenticated=$authorized;PermissionGranted=$permitted;SchemaCompatible=$schema;RequiredObjectFound=$exists;CredentialPresent=$credentialPresent;EndpointHost=$capability.EndpointHost;Snapshot=$(if($response.PSObject.Properties['Snapshot']){$response.Snapshot}else{$null});ProductionWrite='DISABLED';ChangesApplied=$false}
    }catch{
        $kind=if($_.Exception.Message-match'(?i)timeout'){'EXTERNAL_TIMEOUT'}elseif($_.Exception.Message-match'AUTHENTICATION'){'AUTHENTICATION_FAILURE'}else{'EXTERNAL_FAILURE'}
        [pscustomobject]@{System=$capability.System;Status=$kind;Connected=$false;Authenticated=$false;PermissionGranted=$false;SchemaCompatible=$false;RequiredObjectFound=$false;CredentialPresent=$credentialPresent;EndpointHost=$capability.EndpointHost;Snapshot=$null;ProductionWrite='DISABLED';ChangesApplied=$false}
    }
}

function New-RapProductionReadAdapters {
    [CmdletBinding()]param(
        [Parameter(Mandatory)][string]$ZoteroResourcePath,[Parameter(Mandatory)][string]$DriveResourcePath,[Parameter(Mandatory)][string]$NotionResourcePath,
        [uri]$ZoteroEndpoint=[uri]'https://api.zotero.org/',[uri]$DriveEndpoint=[uri]'https://www.googleapis.com/drive/v3/',[uri]$NotionEndpoint=[uri]'https://api.notion.com/v1/',
        [string]$ZoteroCredentialEnvironmentVariable='ZOTERO_API_KEY',[string]$DriveCredentialEnvironmentVariable='GOOGLE_DRIVE_ACCESS_TOKEN',[string]$NotionCredentialEnvironmentVariable='NOTION_API_TOKEN'
    )
    [pscustomobject]@{
        Zotero=New-RapExternalReadAdapter Zotero $ZoteroEndpoint $ZoteroCredentialEnvironmentVariable $ZoteroResourcePath
        GoogleDrive=New-RapExternalReadAdapter GoogleDrive $DriveEndpoint $DriveCredentialEnvironmentVariable $DriveResourcePath
        Notion=New-RapExternalReadAdapter Notion $NotionEndpoint $NotionCredentialEnvironmentVariable $NotionResourcePath
    }
}

Export-ModuleMember -Function Get-RapCredentialPresence,New-RapExternalReadAdapter,New-RapFixtureReadAdapter,Invoke-RapExternalReadProbe,New-RapProductionReadAdapters
