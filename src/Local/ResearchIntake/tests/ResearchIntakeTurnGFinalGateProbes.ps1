$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'TestHarness.ps1')
$script:Pass=0;$script:Fail=0
function Gate-G([string]$id,[bool]$ok,[string]$detail){if($ok){$script:Pass++;Write-Host "$id PASS $detail"}else{$script:Fail++;Write-Host "$id FAIL $detail"}}
function Existing-G([string]$id='Z-GOOD',[string]$library='LIBRARY-1'){[pscustomobject]@{CanonicalKey='doi:10.1234/rap.001';ZoteroItemId=$id;LibraryId=$library;Title='Research Intake Safety';FirstAuthor='Kim';Year='2026'}}
function New-Create-G([string]$db=''){$c=New-RapIntakeContext @() @() @((New-RapIntakeFixture)) $db;$p=Promote-RapFixture $c;$null=Invoke-RapResearchIntakeDecision $c.Store $p;[pscustomobject]@{Context=$c;Promotion=$p}}
function New-Reuse-G([string]$db=''){$e=Existing-G;$c=New-RapIntakeContext @($e) @($e) @((New-RapIntakeFixture)) $db;$p=Promote-RapFixture $c;$null=Invoke-RapResearchIntakeDecision $c.Store $p;[pscustomobject]@{Context=$c;Promotion=$p}}
function Replay-Blocked-G($x){try{(Invoke-RapResearchIntakeDecision $x.Context.Store $x.Promotion).Decision.Decision-ceq'BLOCKED'}catch{$true}}
function Audit-G($store,[string]$event){@($store.Audit|Where-Object{$_.Event-ceq$event})[0]}
function Identity-Attack-G([scriptblock]$change){$c=New-RapIntakeContext;$p=Promote-RapFixture $c;$i=Resolve-RapCanonicalPaperIdentity $c.Store $p;&$change $i;(Get-RapIntakeThrown {Get-RapPreZoteroDedupDecision $c.Store $p $i})-match'(IDENTITY_BINDING_MISMATCH|CANDIDATE_SUBSTITUTION)'}
function Lookup-Attack-G([string]$outcome){$c=New-RapIntakeContext;$p=Promote-RapFixture $c;$null=Invoke-RapResearchIntakeReadOnlyLookup $c.Store $outcome;$r=Invoke-RapResearchIntakeDecision $c.Store $p;$r.Decision.Decision-cne'CREATE_CANDIDATE'-and$c.Store.Counters.ZoteroCreateDecision-eq0}
function Reuse-Attack-G([scriptblock]$change){$x=New-Reuse-G;&$change $x.Context.Store.Decisions['C-001'];Replay-Blocked-G $x}

$c=New-RapIntakeContext;$p=Promote-RapFixture $c;$p.Researcher='attacker';Gate-G G01 ((Get-RapIntakeThrown {Invoke-RapResearchIntakeDecision $c.Store $p})-match'PROMOTION_BINDING_MISMATCH') 'PROMOTE substitution blocked'
$c=New-RapIntakeContext;$p=Promote-RapFixture $c;$c.Store.Inbox['C-001'].SearchExecutionId='SE-EVIL';Gate-G G02 ((Get-RapIntakeThrown {Invoke-RapResearchIntakeDecision $c.Store $p})-match'CANDIDATE_SUBSTITUTION') 'SearchExecution substitution blocked'
$c=New-RapIntakeContext;$p=Promote-RapFixture $c;$p.CandidateId='C-EVIL';Gate-G G03 ((Get-RapIntakeThrown {Invoke-RapResearchIntakeDecision $c.Store $p})-ne'') 'Candidate substitution blocked'
Gate-G G04 (Identity-Attack-G {$args[0].NormalizedDoi='10.9999/evil'}) 'DOI substitution blocked'
$c=New-RapIntakeContext -Results @((New-RapIntakeFixture C-PMID '' 'Research Intake Safety' 'Kim' '2026' '123'));$p=Promote-RapFixture $c C-PMID;$i=Resolve-RapCanonicalPaperIdentity $c.Store $p;$i.Pmid='999';Gate-G G05 ((Get-RapIntakeThrown {Get-RapPreZoteroDedupDecision $c.Store $p $i})-match'IDENTITY_BINDING_MISMATCH') 'PMID substitution blocked'
Gate-G G06 (Identity-Attack-G {$args[0].CanonicalKey='doi:10.9999/evil'}) 'canonical identity substitution blocked'
$ca=New-RapIntakeContext -Results @((New-RapIntakeFixture C-A));$pa=Promote-RapFixture $ca C-A;$ia=Resolve-RapCanonicalPaperIdentity $ca.Store $pa;$cb=New-RapIntakeContext -Results @((New-RapIntakeFixture C-B '10.1234/RAP.002' 'Second Paper'));$pb=Promote-RapFixture $cb C-B;Gate-G G07 ((Get-RapIntakeThrown {Get-RapPreZoteroDedupDecision $cb.Store $pb $ia})-match'CANDIDATE_SUBSTITUTION') 'identity artifact cross-candidate replay blocked'
$c=New-RapIntakeContext @() @() @((New-RapIntakeFixture)) '' $true;$p=Promote-RapFixture $c;$r=Invoke-RapResearchIntakeDecision $c.Store $p;Gate-G G08 ($r.Decision.Decision-cne'CREATE_CANDIDATE') 'LOOKUP_REQUIRED bypass blocked'
Gate-G G09 (Lookup-Attack-G TIMEOUT) 'TIMEOUT bypass blocked'
Gate-G G10 (Lookup-Attack-G PARTIAL) 'PARTIAL bypass blocked'
$c=New-RapIntakeContext;$p=Promote-RapFixture $c;$c.Store.PSObject.Properties.Remove('LookupSnapshot');Gate-G G11 ((Get-RapIntakeThrown {Invoke-RapResearchIntakeDecision $c.Store $p})-ne'') 'missing lookup evidence blocked'
$x=New-Create-G;$e=Existing-G;$null=Invoke-RapResearchIntakeReadOnlyLookup $x.Context.Store PASS @($e) @();Gate-G G12 (Replay-Blocked-G $x) 'post-decision canonical lookup mutation blocked'
$x=New-Create-G;$e=Existing-G;$null=Invoke-RapResearchIntakeReadOnlyLookup $x.Context.Store PASS @() @($e);Gate-G G13 (Replay-Blocked-G $x) 'post-decision Zotero lookup mutation blocked'
Gate-G G14 (Reuse-Attack-G {$args[0].ZoteroItemId='Z-EVIL'}) 'ZoteroItemId substitution blocked'
Gate-G G15 (Reuse-Attack-G {$args[0].ZoteroLibraryContext='LIB-EVIL'}) 'library/context substitution blocked'
Gate-G G16 (Reuse-Attack-G {$args[0].ExactTargetEvidenceHash='forged'}) 'exact-target substitution blocked'
$x=New-Create-G;$x.Context.Store.Decisions['C-001'].Decision='REUSE_EXISTING';$x.Context.Store.Decisions['C-001'].State='REUSE_EXISTING';Gate-G G17 (Replay-Blocked-G $x) 'CREATE to REUSE substitution blocked'
$x=New-Reuse-G;$x.Context.Store.Decisions['C-001'].Decision='CREATE_CANDIDATE';$x.Context.Store.Decisions['C-001'].State='CREATE_CANDIDATE';Gate-G G18 (Replay-Blocked-G $x) 'REUSE to CREATE substitution blocked'

$temp=Join-Path ([IO.Path]::GetTempPath()) ('ri-turn-g-'+[guid]::NewGuid().ToString('N'));New-Item $temp -ItemType Directory|Out-Null
try{
    $db=Join-Path $temp 'stale-envelope.db';$x=New-Create-G $db;$x.Context.Store.Decisions['C-001'].Reason='FORGED';Save-RapResearchIntakeStore $x.Context.Store|Out-Null;$s=Open-RapResearchIntakeStore $db;$y=[pscustomobject]@{Context=[pscustomobject]@{Store=$s};Promotion=$s.Promotions['C-001']};Gate-G G19 (Replay-Blocked-G $y) 'stale decision plus fresh envelope blocked'
    $x=New-Create-G;$x.Context.Store.Decisions['C-001'].ProjectId='PR999';Gate-G G20 (Replay-Blocked-G $x) 'cross-project decision replay blocked'
    $x=New-Create-G;(Audit-G $x.Context.Store 'IDENTITY_RESOLVED').Data.CandidateId='C-EVIL';Gate-G G21 (Replay-Blocked-G $x) 'wrong identity audit blocked'
    $x=New-Create-G;(Audit-G $x.Context.Store 'CANONICAL_LOOKUP_AUTHORITY_VALIDATED').Data.Status='FOUND';Gate-G G22 (Replay-Blocked-G $x) 'wrong canonical lookup audit blocked'
    $x=New-Reuse-G;(Audit-G $x.Context.Store 'ZOTERO_LOOKUP_AUTHORITY_VALIDATED').Data.CandidateId='C-EVIL';Gate-G G23 (Replay-Blocked-G $x) 'wrong Zotero lookup audit blocked'
    $x=New-Reuse-G;(Audit-G $x.Context.Store 'ZOTERO_LOOKUP_AUTHORITY_VALIDATED').Data.ZoteroItemId='Z-EVIL';Gate-G G24 (Replay-Blocked-G $x) 'wrong target audit blocked'
    $x=New-Create-G;(Audit-G $x.Context.Store 'IDENTITY_RESOLVED').Event='IDENTITY_AUDIT_REMOVED';Gate-G G25 (Replay-Blocked-G $x) 'missing upstream audit blocked'
    $x=New-Create-G;$a=Audit-G $x.Context.Store 'CANONICAL_LOOKUP_AUTHORITY_VALIDATED';$dup=$a|ConvertTo-Json -Depth 30|ConvertFrom-Json -Depth 30;$dup.Sequence=$x.Context.Store.Audit.Count+1;$dup.Data.Status='FOUND';$x.Context.Store.Audit.Add($dup);Gate-G G26 (Replay-Blocked-G $x) 'contradictory audit blocked'
    $x=New-Reuse-G;$d=$x.Context.Store.Decisions['C-001'];$d.CanonicalLookupAuditSequence=$d.ZoteroLookupAuditSequence;Gate-G G27 (Replay-Blocked-G $x) 'wrong audit ordering blocked'
    $db=Join-Path $temp 'restart-authority.db';$x=New-Create-G $db;(Audit-G $x.Context.Store 'READ_ONLY_LOOKUP_EXECUTED').Data.CanonicalCount=7;Save-RapResearchIntakeStore $x.Context.Store|Out-Null;$s=Open-RapResearchIntakeStore $db;$y=[pscustomobject]@{Context=[pscustomobject]@{Store=$s};Promotion=$s.Promotions['C-001']};Gate-G G28 (Replay-Blocked-G $y) 'restart plus changed authority evidence blocked'
    $db=Join-Path $temp 'legacy.db';$x=New-Create-G $db;[Rap.NativeSqlite]::Execute($db,"UPDATE ResearchIntakeStore SET SchemaVersion=3 WHERE StoreId='PRIMARY';",5000);Gate-G G29 ((Get-RapIntakeThrown {Open-RapResearchIntakeStore $db})-match'SCHEMA_UNSUPPORTED') 'legacy authority escalation blocked'
    $db=Join-Path $temp 'combined.db';$x=New-Reuse-G $db;$x.Context.Store.IdentityResults['C-001'].CanonicalKey='doi:10.9999/evil';$x.Context.Store.LookupSnapshot.Reason='FORGED';(Audit-G $x.Context.Store 'ZOTERO_LOOKUP_AUTHORITY_VALIDATED').Data.ZoteroItemId='Z-EVIL';$x.Context.Store.Decisions['C-001'].Reason='FORGED';Save-RapResearchIntakeStore $x.Context.Store|Out-Null;$s=Open-RapResearchIntakeStore $db;$y=[pscustomobject]@{Context=[pscustomobject]@{Store=$s};Promotion=$s.Promotions['C-001']};Gate-G G30 (Replay-Blocked-G $y) 'combined identity lookup audit envelope attack blocked'
    $x=New-Create-G;(Audit-G $x.Context.Store 'CANDIDATE_PROMOTED').Event='PROMOTION_AUDIT_REMOVED';Gate-G G31 (Replay-Blocked-G $x) 'missing promotion audit blocks replay'
    $x=New-Create-G;$a=Audit-G $x.Context.Store 'CANDIDATE_PROMOTED';$a.Sequence=(Audit-G $x.Context.Store 'PRE_ZOTERO_DEDUP_DECIDED').Sequence+1;Gate-G G32 (Replay-Blocked-G $x) 'promotion audit after decision blocks replay'
}finally{Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue}

Write-Host "SPR-015 Turn G independent probes: PASS=$script:Pass FAIL=$script:Fail TOTAL=$($script:Pass+$script:Fail)"
if($script:Fail-gt0){Write-Host 'TURN_G_FINAL_GATE_PROBES=FAIL';exit 1}
Write-Host 'TURN_G_FINAL_GATE_PROBES=PASS'
