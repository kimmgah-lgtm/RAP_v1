Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '../ResearchAutomation.Local/modules/Queue.psm1') -Force

function Get-RapIntakePersistenceHash([string]$Text){[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($Text))).ToLowerInvariant()}
function ConvertTo-RapIntakeSql([string]$Text){"'"+$Text.Replace("'","''")+"'"}
function ConvertTo-RapIntakeMapObject($Map){$o=[ordered]@{};foreach($k in @($Map.Keys|Sort-Object)){$o[$k]=$Map[$k]};[pscustomobject]$o}
function ConvertFrom-RapIntakeMap($Object,[string]$TypeName){$h=@{};if($null-ne$Object){foreach($p in $Object.PSObject.Properties){$v=$p.Value;if($TypeName-and$v){$v.PSObject.TypeNames.Insert(0,$TypeName)};$h[$p.Name]=$v}};$h}
function Get-RapResearchIntakeBody($Store){
    [ordered]@{SchemaVersion=2;KnownProjectIds=@($Store.KnownProjectIds);Questions=ConvertTo-RapIntakeMapObject $Store.Questions;Searches=ConvertTo-RapIntakeMapObject $Store.Searches;Inbox=ConvertTo-RapIntakeMapObject $Store.Inbox;Promotions=ConvertTo-RapIntakeMapObject $Store.Promotions;IdentityResults=ConvertTo-RapIntakeMapObject $Store.IdentityResults;LookupSnapshot=$Store.LookupSnapshot;LookupResults=ConvertTo-RapIntakeMapObject $Store.LookupResults;Decisions=ConvertTo-RapIntakeMapObject $Store.Decisions;Lifecycles=ConvertTo-RapIntakeMapObject $Store.Lifecycles;CanonicalPapers=@($Store.CanonicalPapers);ZoteroItems=@($Store.ZoteroItems);Audit=@($Store.Audit);Counters=$Store.Counters;ProductionWrite=[string]$Store.ProductionWrite;ProductionPilot=[string]$Store.ProductionPilot}
}
function Initialize-RapResearchIntakeStore {
    [CmdletBinding()]param([Parameter(Mandatory)][string]$DatabasePath)
    $path=Initialize-RapQueue $DatabasePath 5000;[Rap.NativeSqlite]::Execute($path,'CREATE TABLE IF NOT EXISTS ResearchIntakeStore(StoreId TEXT PRIMARY KEY,Payload TEXT NOT NULL,RecordHash TEXT NOT NULL,SchemaVersion INTEGER NOT NULL,UpdatedUtc TEXT NOT NULL);',5000);$path
}
function Save-RapResearchIntakeStore {
    [CmdletBinding()]param([Parameter(Mandatory)]$Store)
    if([string]::IsNullOrWhiteSpace([string]$Store.DatabasePath)){return $Store};if($Store.ProductionWrite-cne'DISABLED'){throw 'UNSAFE_RESEARCH_INTAKE_STORE'}
    $path=Initialize-RapResearchIntakeStore $Store.DatabasePath;$body=Get-RapResearchIntakeBody $Store;$json=$body|ConvertTo-Json -Depth 80 -Compress;$hash=Get-RapIntakePersistenceHash $json;$payload=[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($json));$now=[DateTimeOffset]::UtcNow.ToString('o');$sql="BEGIN IMMEDIATE;INSERT INTO ResearchIntakeStore(StoreId,Payload,RecordHash,SchemaVersion,UpdatedUtc) VALUES('PRIMARY',$(ConvertTo-RapIntakeSql $payload),'$hash',2,$(ConvertTo-RapIntakeSql $now)) ON CONFLICT(StoreId) DO UPDATE SET Payload=excluded.Payload,RecordHash=excluded.RecordHash,SchemaVersion=excluded.SchemaVersion,UpdatedUtc=excluded.UpdatedUtc;COMMIT;";[Rap.NativeSqlite]::Execute($path,$sql,5000);$Store
}
function Assert-RapIntakePersistedBody($Body){
    if($null-eq$Body-or[long]$Body.SchemaVersion-ne2){throw 'RESEARCH_INTAKE_SCHEMA_UNSUPPORTED'}
    foreach($n in @('KnownProjectIds','Questions','Searches','Inbox','Promotions','IdentityResults','LookupSnapshot','LookupResults','Decisions','Lifecycles','Audit','Counters','ProductionWrite','ProductionPilot')){if(-not$Body.PSObject.Properties[$n]){throw "RESEARCH_INTAKE_PERSISTENCE_MISSING:$n"}}
    if($Body.ProductionWrite-cne'DISABLED'-or$Body.ProductionPilot-cne'TEST_DEFERRED'){throw 'UNSAFE_RESEARCH_INTAKE_STORE'}
    foreach($p in $Body.Inbox.PSObject.Properties){$c=$p.Value;if($p.Name-cne$c.CandidateId-or$c.ProjectId-notmatch'^PR\d{3,6}$'-or$c.State-notin@('INBOXED','PROMOTED')){throw 'RESEARCH_INTAKE_PERSISTENCE_CORRUPT'}}
    if($Body.LookupSnapshot.Status-notin@('PASS','LOOKUP_FAILED')-or$Body.LookupSnapshot.CanonicalStatus-notin@('AUTHORITATIVE','UNKNOWN')-or$Body.LookupSnapshot.ZoteroStatus-notin@('AUTHORITATIVE','UNKNOWN')){throw 'RESEARCH_INTAKE_PERSISTENCE_CORRUPT'}
    foreach($p in $Body.Promotions.PSObject.Properties){$x=$p.Value;if($p.Name-cne$x.CandidateId-or-not$Body.Inbox.PSObject.Properties[$p.Name]-or$x.State-cne'PROMOTED'){throw 'RESEARCH_INTAKE_PERSISTENCE_CORRUPT'};foreach($n in @('SearchExecutionId','SearchMode','SearchSource','SearchProvenance','CandidateIdentityHash','PromotedAt','PromotionHash')){if(-not$x.PSObject.Properties[$n]){throw 'RESEARCH_INTAKE_PERSISTENCE_CORRUPT'}}}
    foreach($p in $Body.Lifecycles.PSObject.Properties){if([string]$p.Value-notin@('SEARCHED','INBOXED','PROMOTED','IDENTITY_RESOLVING','IDENTITY_RESOLVED','DEDUP_CHECKED','CREATE_CANDIDATE','REUSE_EXISTING','AMBIGUOUS','IDENTITY_CONFLICT','BLOCKED')){throw 'RESEARCH_INTAKE_INVALID_STATE'}}
}
function Open-RapResearchIntakeStore {
    [CmdletBinding()]param([Parameter(Mandatory)][string]$DatabasePath)
    $path=Initialize-RapResearchIntakeStore $DatabasePath;$payload=[Rap.NativeSqlite]::Scalar($path,"SELECT Payload FROM ResearchIntakeStore WHERE StoreId='PRIMARY';",5000);if(-not$payload){return $null};$columnHash=[Rap.NativeSqlite]::Scalar($path,"SELECT RecordHash FROM ResearchIntakeStore WHERE StoreId='PRIMARY';",5000);$schema=[Rap.NativeSqlite]::Scalar($path,"SELECT SchemaVersion FROM ResearchIntakeStore WHERE StoreId='PRIMARY';",5000)
    try{$json=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String([string]$payload));$body=$json|ConvertFrom-Json -Depth 80 -DateKind String}catch{throw 'RESEARCH_INTAKE_PERSISTENCE_CORRUPT'};if((Get-RapIntakePersistenceHash $json)-cne$columnHash){throw 'RESEARCH_INTAKE_PERSISTENCE_CORRUPT'};if([long]$schema-ne2){throw 'RESEARCH_INTAKE_SCHEMA_UNSUPPORTED'};Assert-RapIntakePersistedBody $body
    $audit=[Collections.Generic.List[object]]::new();foreach($e in @($body.Audit)){$audit.Add($e)}
    [pscustomobject]@{PSTypeName='Rap.ResearchIntakeStore';SchemaVersion=2;DatabasePath=[IO.Path]::GetFullPath($DatabasePath);KnownProjectIds=@($body.KnownProjectIds);Questions=ConvertFrom-RapIntakeMap $body.Questions 'Rap.ResearchQuestion';Searches=ConvertFrom-RapIntakeMap $body.Searches '';Inbox=ConvertFrom-RapIntakeMap $body.Inbox 'Rap.ResearchInboxCandidate';Promotions=ConvertFrom-RapIntakeMap $body.Promotions 'Rap.ResearchPromotion';IdentityResults=ConvertFrom-RapIntakeMap $body.IdentityResults 'Rap.IdentityResolution';LookupSnapshot=$body.LookupSnapshot;LookupResults=ConvertFrom-RapIntakeMap $body.LookupResults 'Rap.IntakeLookupResult';Decisions=ConvertFrom-RapIntakeMap $body.Decisions 'Rap.ZoteroDecision';Lifecycles=ConvertFrom-RapIntakeMap $body.Lifecycles '';CanonicalPapers=@($body.CanonicalPapers);ZoteroItems=@($body.ZoteroItems);Audit=$audit;Counters=$body.Counters;ProductionWrite='DISABLED';ProductionPilot='TEST_DEFERRED'}
}
function Test-RapResearchIntakeStoreIntegrity {[CmdletBinding()]param([Parameter(Mandatory)][string]$DatabasePath)try{[void](Open-RapResearchIntakeStore $DatabasePath);$true}catch{$false}}
Export-ModuleMember -Function Initialize-RapResearchIntakeStore,Save-RapResearchIntakeStore,Open-RapResearchIntakeStore,Test-RapResearchIntakeStoreIntegrity
