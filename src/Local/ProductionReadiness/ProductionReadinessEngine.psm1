Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '../Reconciliation/ResearchAutomation.Reconciliation.psd1') -Force -ErrorAction Stop
function Get-RapReadinessHash {param($Value)$json=$Value|ConvertTo-Json -Depth 60 -Compress;[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($json))).ToLowerInvariant()}

function New-RapEnvironmentGuard {
    [CmdletBinding()]param([Parameter(Mandatory)][string]$Environment,[Parameter(Mandatory)][string]$ExpectedEnvironment,[hashtable]$Endpoints=@{},[string[]]$CredentialEnvironmentVariables=@())
    $allowed=@('LOCAL','TEST','PRODUCTION');if($Environment-cnotin$allowed-or$ExpectedEnvironment-cnotin$allowed){throw 'ENVIRONMENT_CLASSIFICATION_INVALID'};if($Environment-cne$ExpectedEnvironment){throw 'ENVIRONMENT_MISMATCH'}
    $endpointUse=@{};foreach($k in $Endpoints.Keys){$u=[uri]$Endpoints[$k];if($u.Scheme-ne'https' -and -not$u.IsLoopback){throw 'ENVIRONMENT_ENDPOINT_UNSAFE'};$endpointUse[$k]=[pscustomobject]@{Host=$u.Host;ProductionEndpoint=(-not$u.IsLoopback)}}
    $credentialUse=@{};foreach($name in $CredentialEnvironmentVariables){if($name-notmatch'^[A-Z][A-Z0-9_]{2,127}$'){throw 'CREDENTIAL_ENVIRONMENT_NAME_INVALID'};$credentialUse[$name]=-not[string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($name))}
    [pscustomobject]@{Environment=$Environment;ExpectedEnvironment=$ExpectedEnvironment;Valid=$true;EndpointUse=[pscustomobject]$endpointUse;CredentialPresence=[pscustomobject]$credentialUse;ProductionWrite='DISABLED'}
}

function Invoke-RapProductionWriteFirewall {
    [CmdletBinding()]param([Parameter(Mandatory)][string]$Action,[switch]$DryRun)
    $normalized=$Action.ToUpperInvariant();$mutating=@('CREATE','UPDATE','DELETE','MOVE','MERGE','APPLY','UPSERT','PATCH','POST','PUT')
    if($normalized-in$mutating){if($DryRun){return [pscustomobject]@{Status='DRY_RUN_ONLY';Action=$normalized;Allowed=$true;ChangesApplied=$false;ProductionWrite='DISABLED'}};throw "PRODUCTION_WRITE_BLOCKED:$normalized"}
    if($normalized-notin@('READ','PROBE','SNAPSHOT','COMPARE','PLAN','MANIFEST')){throw 'UNKNOWN_OPERATION_FAIL_CLOSED'}
    [pscustomobject]@{Status='READ_ONLY_ALLOWED';Action=$normalized;Allowed=$true;ChangesApplied=$false;ProductionWrite='DISABLED'}
}

function New-RapMutationManifest {
    [CmdletBinding()]param([Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$')][string]$OperationId,[Parameter(Mandatory)][string]$Target,[Parameter(Mandatory)][AllowNull()]$BeforeState,[Parameter(Mandatory)]$ProposedAfterState,[Parameter(Mandatory)][string]$Reason,[Parameter(Mandatory)][ValidateSet('AUTO_OWNED','HUMAN_OWNED','ResearcherConfirmed')][string]$Ownership,[Parameter(Mandatory)][bool]$Destructive,[Parameter(Mandatory)][string]$VerificationMethod)
    if($Ownership-in@('HUMAN_OWNED','ResearcherConfirmed')){throw 'PROTECTED_OWNERSHIP_MANIFEST_BLOCKED'};if([string]::IsNullOrWhiteSpace($Target)-or[string]::IsNullOrWhiteSpace($Reason)-or[string]::IsNullOrWhiteSpace($VerificationMethod)){throw 'INCOMPLETE_MUTATION_MANIFEST'}
    $body=[ordered]@{OperationId=$OperationId;Target=$Target;BeforeStateHash=Get-RapReadinessHash $BeforeState;BeforeState=$BeforeState;ProposedAfterState=$ProposedAfterState;Reason=$Reason;Ownership=$Ownership;Destructive=$Destructive;VerificationMethod=$VerificationMethod;ApplyPermitted=$false;ProductionWrite='DISABLED'}
    $body.ManifestHash=Get-RapReadinessHash $body;[pscustomobject]$body
}

function Test-RapProductionPreflight {
    [CmdletBinding()]param([Parameter(Mandatory)]$EnvironmentGuard,[Parameter(Mandatory)][bool]$IdentityValid,[Parameter(Mandatory)][bool]$IdentityAmbiguous,[Parameter(Mandatory)][bool]$OwnershipSafe,[Parameter(Mandatory)][bool]$PermissionGranted,[Parameter(Mandatory)][bool]$SchemaCompatible,[Parameter(Mandatory)][bool]$LineageComplete,[Parameter(Mandatory)][bool]$StaleState,[Parameter(Mandatory)][AllowEmptyCollection()][object[]]$PlannedMutations,[Parameter(Mandatory)][bool]$RecoveryCapable)
    $reasons=[Collections.Generic.List[string]]::new();if(!$EnvironmentGuard.Valid){$reasons.Add('ENVIRONMENT_INVALID')};if(!$IdentityValid){$reasons.Add('IDENTITY_INVALID')};if($IdentityAmbiguous){$reasons.Add('AMBIGUOUS_IDENTITY')};if(!$OwnershipSafe){$reasons.Add('OWNERSHIP_CONFLICT')};if(!$PermissionGranted){$reasons.Add('PERMISSION_FAILURE')};if(!$SchemaCompatible){$reasons.Add('SCHEMA_MISMATCH')};if(!$LineageComplete){$reasons.Add('LINEAGE_INCOMPLETE')};if($StaleState){$reasons.Add('STALE_STATE')};if(!$RecoveryCapable){$reasons.Add('RECOVERY_UNAVAILABLE')};if(@($PlannedMutations|Where-Object{$_.Destructive-or$_.Ownership-in@('HUMAN_OWNED','ResearcherConfirmed')}).Count){$reasons.Add('PROHIBITED_MUTATION')}
    [pscustomobject]@{Status=$(if($reasons.Count){'BLOCKED'}else{'PASS'});Reasons=@($reasons);Checks=[pscustomobject]@{Environment=$EnvironmentGuard.Valid;Identity=$IdentityValid-and!$IdentityAmbiguous;Ownership=$OwnershipSafe;Permissions=$PermissionGranted;Schema=$SchemaCompatible;Lineage=$LineageComplete;StaleState=!$StaleState;PlannedMutations=$true;Recovery=$RecoveryCapable};ApplyPermitted=$false;ProductionWrite='DISABLED'}
}

function Invoke-RapProductionDryRun {
    [CmdletBinding()]param([Parameter(Mandatory)]$Adapter,[Parameter(Mandatory)]$ExpectedSnapshot,[Parameter(Mandatory)]$EnvironmentGuard,[Parameter(Mandatory)][string]$OperationId,[bool]$LineageComplete=$true,[bool]$RecoveryCapable=$true,[bool]$StaleState=$false)
    [void](Invoke-RapProductionWriteFirewall PROBE);$probe=Invoke-RapExternalReadProbe $Adapter
    if($probe.Status-ne'PASS'){return [pscustomobject]@{Status='BLOCKED';System=$Adapter.System;Probe=$probe;Preflight=$null;Difference=$null;Plan=$null;MutationManifests=@();LocalTruthOverwritten=$false;ChangesApplied=$false;ProductionWrite='DISABLED'}}
    $actual=$probe.Snapshot;$difference=Compare-RapIntegritySnapshot $ExpectedSnapshot $actual;$decision=New-RapReconciliationDecision $difference;$plan=New-RapRecoveryPlan $difference $decision $OperationId
    $manifests=@();foreach($a in @($plan.Actions)){$before=@($actual.Records|Where-Object RecordId -eq $a.RecordId|Select-Object -First 1);$manifests+=New-RapMutationManifest $OperationId "$($Adapter.System):$($a.RecordId)" $(if($before){$before[0].Value}else{$null}) $a.Value 'RECONCILIATION_PLAN' $a.Ownership $false 'READ_BACK_HASH_AND_COMPARE'}
    $ownershipSafe=@($difference.Differences|Where-Object{$_.Ownership-in@('HUMAN_OWNED','ResearcherConfirmed')-or$_.Kind-eq'OWNERSHIP_CONFLICT'}).Count-eq0
    $preflight=Test-RapProductionPreflight $EnvironmentGuard $true $difference.IdentityAmbiguous $ownershipSafe $probe.PermissionGranted $probe.SchemaCompatible $LineageComplete $StaleState $manifests $RecoveryCapable
    [pscustomobject]@{Status=$(if($preflight.Status-eq'PASS'){'DRY_RUN_COMPLETE'}else{'BLOCKED'});System=$Adapter.System;Probe=$probe;Preflight=$preflight;Difference=$difference;Plan=$plan;MutationManifests=@($manifests);LocalTruthOverwritten=$false;ChangesApplied=$false;ProductionWrite='DISABLED'}
}
Export-ModuleMember -Function New-RapEnvironmentGuard,Invoke-RapProductionWriteFirewall,New-RapMutationManifest,Test-RapProductionPreflight,Invoke-RapProductionDryRun
