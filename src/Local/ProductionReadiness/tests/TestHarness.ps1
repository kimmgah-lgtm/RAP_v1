Set-StrictMode -Version Latest;$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '../ResearchAutomation.ProductionReadiness.psd1') -Force
function Copy-RapPr($v){$v|ConvertTo-Json -Depth 60|ConvertFrom-Json -Depth 60}
function New-RapPrExpected {[pscustomobject]@{LibraryId='LIB:L000001';ProjectId='PR001';EvidenceComplete=$true;IdentityAmbiguous=$false;Records=@([pscustomobject]@{RecordId='DERIVED:1';Value=[pscustomobject]@{Version=2;Status='CURRENT'};Ownership='AUTO_OWNED';Evidence=[pscustomobject]@{Source='local';Version=2}},[pscustomobject]@{RecordId='HUMAN:1';Value='keep';Ownership='HUMAN_OWNED';Evidence=[pscustomobject]@{Source='researcher'}},[pscustomobject]@{RecordId='CONFIRMED:1';Value='confirmed';Ownership='ResearcherConfirmed';Evidence=[pscustomobject]@{Source='researcher';Confirmed=$true}})} }
function New-RapPrActual {$x=Copy-RapPr (New-RapPrExpected);$x.Records[0].Value.Version=1;$x}
function New-RapPrProbe([string]$system,$snapshot,[bool]$authorized=$true,[bool]$permission=$true,[bool]$schema=$true,[bool]$exists=$true){New-RapFixtureReadAdapter $system ([pscustomobject]@{Authorized=$authorized;PermissionGranted=$permission;SchemaCompatible=$schema;RequiredObjectFound=$exists;Snapshot=$snapshot})}
function New-RapPrGuard {New-RapEnvironmentGuard LOCAL LOCAL @{Zotero='https://api.zotero.org/'} @('RAP_TEST_CREDENTIAL')}
function Get-RapPrThrown([scriptblock]$s){try{&$s;$null}catch{$_.Exception.Message}}
