$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'TestHarness.ps1')
$script:Pass=0;$script:Fail=0
function Assert-FR([string]$id,[bool]$ok,[string]$detail){if($ok){$script:Pass++;Write-Host "$id PASS $detail"}else{$script:Fail++;Write-Host "$id FAIL $detail"}}
function Existing-FR([string]$id='Z-GOOD',[string]$library='LIBRARY-1'){[pscustomobject]@{CanonicalKey='doi:10.1234/rap.001';ZoteroItemId=$id;LibraryId=$library;Title='Research Intake Safety';FirstAuthor='Kim';Year='2026'}}
function New-Create-FR([string]$db=''){$c=New-RapIntakeContext @() @() @((New-RapIntakeFixture)) $db;$p=Promote-RapFixture $c;$null=Invoke-RapResearchIntakeDecision $c.Store $p;[pscustomobject]@{Context=$c;Promotion=$p}}
function New-Reuse-FR([string]$db=''){$e=Existing-FR;$c=New-RapIntakeContext @($e) @($e) @((New-RapIntakeFixture)) $db;$p=Promote-RapFixture $c;$null=Invoke-RapResearchIntakeDecision $c.Store $p;[pscustomobject]@{Context=$c;Promotion=$p}}
function Replay-Blocked-FR($x){try{(Invoke-RapResearchIntakeDecision $x.Context.Store $x.Promotion).Decision.Decision-ceq'BLOCKED'}catch{$true}}
function Audit-FR($store,[string]$event){@($store.Audit|Where-Object{$_.Event-ceq$event})[0]}

$x=New-Create-FR;(Audit-FR $x.Context.Store 'IDENTITY_RESOLVED').Data.CandidateId='C-EVIL';Assert-FR FR01 (Replay-Blocked-FR $x) 'identity audit wrong Candidate blocked'
$x=New-Create-FR;(Audit-FR $x.Context.Store 'IDENTITY_RESOLVED').Data.ProjectId='PR999';Assert-FR FR02 (Replay-Blocked-FR $x) 'identity audit wrong Project blocked'
$x=New-Create-FR;(Audit-FR $x.Context.Store 'IDENTITY_RESOLVED').Data.IdentityBindingHash='forged';Assert-FR FR03 (Replay-Blocked-FR $x) 'identity audit wrong IdentityBindingHash blocked'
$x=New-Create-FR;(Audit-FR $x.Context.Store 'CANONICAL_LOOKUP_AUTHORITY_VALIDATED').Data.CandidateId='C-EVIL';Assert-FR FR04 (Replay-Blocked-FR $x) 'canonical lookup audit wrong Candidate blocked'
$x=New-Create-FR;(Audit-FR $x.Context.Store 'CANONICAL_LOOKUP_AUTHORITY_VALIDATED').Data.IdentityBindingHash='forged';Assert-FR FR05 (Replay-Blocked-FR $x) 'canonical lookup audit wrong identity blocked'
$x=New-Create-FR;(Audit-FR $x.Context.Store 'CANONICAL_LOOKUP_AUTHORITY_VALIDATED').Data.Status='FOUND';Assert-FR FR06 (Replay-Blocked-FR $x) 'canonical lookup outcome contradiction blocked'
$x=New-Reuse-FR;(Audit-FR $x.Context.Store 'ZOTERO_LOOKUP_AUTHORITY_VALIDATED').Data.CandidateId='C-EVIL';Assert-FR FR07 (Replay-Blocked-FR $x) 'Zotero lookup audit wrong Candidate blocked'
$x=New-Reuse-FR;(Audit-FR $x.Context.Store 'ZOTERO_LOOKUP_AUTHORITY_VALIDATED').Data.ZoteroItemId='Z-EVIL';Assert-FR FR08 (Replay-Blocked-FR $x) 'Zotero lookup audit wrong exact target blocked'
$x=New-Create-FR;(Audit-FR $x.Context.Store 'IDENTITY_RESOLVED').Event='IDENTITY_AUDIT_REMOVED';Assert-FR FR09 (Replay-Blocked-FR $x) 'missing identity audit blocked'
$x=New-Create-FR;(Audit-FR $x.Context.Store 'CANONICAL_LOOKUP_AUTHORITY_VALIDATED').Event='CANONICAL_AUDIT_REMOVED';Assert-FR FR10 (Replay-Blocked-FR $x) 'missing canonical lookup audit blocked'
$x=New-Reuse-FR;$a=Audit-FR $x.Context.Store 'ZOTERO_LOOKUP_AUTHORITY_VALIDATED';$duplicate=$a|ConvertTo-Json -Depth 30|ConvertFrom-Json -Depth 30;$duplicate.Sequence=$x.Context.Store.Audit.Count+1;$x.Context.Store.Audit.Add($duplicate);Assert-FR FR11 (Replay-Blocked-FR $x) 'conflicting duplicate audit chain blocked'
$x=New-Create-FR;$before=$x.Context.Store.Counters.ZoteroCreateDecision;$x.Context.Store.Audit=$null;$thrown=Get-RapIntakeThrown {Invoke-RapResearchIntakeDecision $x.Context.Store $x.Promotion};Assert-FR FR12 (($thrown-ne'')-and$x.Context.Store.Counters.ZoteroCreateDecision-eq$before) 'upstream audit failure cannot grant replay authority'

$temp=Join-Path ([IO.Path]::GetTempPath()) ('ri-fr-'+[guid]::NewGuid().ToString('N'));New-Item $temp -ItemType Directory|Out-Null
try{
    $db=Join-Path $temp 'fresh-envelope.db';$x=New-Create-FR $db;(Audit-FR $x.Context.Store 'READ_ONLY_LOOKUP_EXECUTED').Data.CanonicalCount=9;Save-RapResearchIntakeStore $x.Context.Store|Out-Null;$s=Open-RapResearchIntakeStore $db;$reloaded=[pscustomobject]@{Context=[pscustomobject]@{Store=$s};Promotion=$s.Promotions['C-001']};Assert-FR FR13 (Replay-Blocked-FR $reloaded) 'restart plus substituted upstream audit blocked'
    $db=Join-Path $temp 'ordering.db';$x=New-Reuse-FR $db;$d=$x.Context.Store.Decisions['C-001'];$d.CanonicalLookupAuditSequence=$d.ZoteroLookupAuditSequence;Save-RapResearchIntakeStore $x.Context.Store|Out-Null;$s=Open-RapResearchIntakeStore $db;$reloaded=[pscustomobject]@{Context=[pscustomobject]@{Store=$s};Promotion=$s.Promotions['C-001']};Assert-FR FR14 (Replay-Blocked-FR $reloaded) 'forged upstream ordering/reference blocked'
}finally{Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue}

Write-Host "SPR-015 Turn F remediation probes: PASS=$script:Pass FAIL=$script:Fail TOTAL=$($script:Pass+$script:Fail)"
if($script:Fail-gt0){Write-Host 'TURN_F_REMEDIATION_PROBES=FAIL';exit 1}
Write-Host 'TURN_F_REMEDIATION_PROBES=PASS'
