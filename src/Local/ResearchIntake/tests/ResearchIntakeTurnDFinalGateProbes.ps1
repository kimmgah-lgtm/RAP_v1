. (Join-Path $PSScriptRoot 'TestHarness.ps1')
$script:Pass=0;$script:Fail=0
function G($id,$ok,$message){if($ok){$script:Pass++;Write-Host "$id PASS $message"}else{$script:Fail++;Write-Host "$id FAIL $message"}}
function LookupAttack([string]$outcome){$c=New-RapIntakeContext;$p=Promote-RapFixture $c;$null=Invoke-RapResearchIntakeReadOnlyLookup $c.Store $outcome;$r=Invoke-RapResearchIntakeDecision $c.Store $p;$r.Decision.Decision-cne'CREATE_CANDIDATE'-and$c.Store.Counters.ZoteroCreateDecision-eq0}
function LineageAttack([scriptblock]$change){$c=New-RapIntakeContext;$p=Promote-RapFixture $c;&$change $c.Store.Inbox['C-001'];(Get-RapIntakeThrown {Invoke-RapResearchIntakeDecision $c.Store $p})-match'(CANDIDATE_SUBSTITUTION|PROMOTION_BINDING_MISMATCH)'}

G D01 (LookupAttack 'TIMEOUT') 'TIMEOUT bypass blocked'
G D02 (LookupAttack 'PARTIAL') 'PARTIAL bypass blocked'
$c=New-RapIntakeContext @() @() @((New-RapIntakeFixture)) '' $true;$p=Promote-RapFixture $c;$r=Invoke-RapResearchIntakeDecision $c.Store $p;G D03 ($r.Decision.Decision-ceq'BLOCKED'-and$c.Store.Counters.ZoteroCreateDecision-eq0) 'LOOKUP_REQUIRED bypass blocked'
$c=New-RapIntakeContext;$p=Promote-RapFixture $c;$c.Store.PSObject.Properties.Remove('LookupSnapshot');G D04 ((Get-RapIntakeThrown {Invoke-RapResearchIntakeDecision $c.Store $p})-ne'') 'missing lookup evidence fails closed'
G D05 (LookupAttack 'MALFORMED') 'malformed lookup blocked'
G D06 (LookupAttack 'AUTH_FAILURE') 'auth failure blocked'
G D07 (LookupAttack 'MULTIPLE') 'multiple/uncertain lookup blocked'
G D08 (LineageAttack {param($x)$x.SearchExecutionId='SE-B'}) 'SearchExecutionId substitution blocked'
G D09 (LineageAttack {param($x)$x.ProjectId='PR999'}) 'Project_ID substitution blocked'
G D10 (LineageAttack {param($x)$x.CandidateId='C-B'}) 'Candidate_ID substitution blocked'
G D11 (LineageAttack {param($x)$x.Doi='10.9999/substituted'}) 'DOI substitution blocked'

$temp=Join-Path ([IO.Path]::GetTempPath()) ('rap-turn-d-'+[guid]::NewGuid());New-Item $temp -ItemType Directory|Out-Null
try{
    $db=Join-Path $temp 'lineage.db';$c=New-RapIntakeContext @() @() @((New-RapIntakeFixture)) $db;$p=Promote-RapFixture $c;$r=Open-RapResearchIntakeStore $db;$r.Inbox['C-001'].SearchExecutionId='SE-B';Save-RapResearchIntakeStore $r|Out-Null;$r2=Open-RapResearchIntakeStore $db;G D12 ((Get-RapIntakeThrown {Invoke-RapResearchIntakeDecision $r2 $r2.Promotions['C-001']})-match'CANDIDATE_SUBSTITUTION') 'restart lineage substitution blocked'
    $v1=Join-Path $temp 'v1.db';$c=New-RapIntakeContext @() @() @((New-RapIntakeFixture)) $v1;[Rap.NativeSqlite]::Execute($v1,"UPDATE ResearchIntakeStore SET SchemaVersion=1 WHERE StoreId='PRIMARY';",5000);G D13 ((Get-RapIntakeThrown {Open-RapResearchIntakeStore $v1})-match'SCHEMA_UNSUPPORTED') 'legacy v1 continuation blocked'
    $future=Join-Path $temp 'future.db';$c=New-RapIntakeContext @() @() @((New-RapIntakeFixture)) $future;[Rap.NativeSqlite]::Execute($future,"UPDATE ResearchIntakeStore SET SchemaVersion=99 WHERE StoreId='PRIMARY';",5000);G D14 ((Get-RapIntakeThrown {Open-RapResearchIntakeStore $future})-match'SCHEMA_UNSUPPORTED') 'schema tampering blocked'
    $c=New-RapIntakeContext;$p=Promote-RapFixture $c;$first=Invoke-RapResearchIntakeDecision $c.Store $p;$null=Invoke-RapResearchIntakeReadOnlyLookup $c.Store TIMEOUT;$second=Invoke-RapResearchIntakeDecision $c.Store $p;G D15 ($second.Decision.Decision-cne'CREATE_CANDIDATE') 'changed lookup evidence invalidates existing decision'
    $c=New-RapIntakeContext;$p=Promote-RapFixture $c;$first=Invoke-RapResearchIntakeDecision $c.Store $p;$second=Invoke-RapResearchIntakeDecision $c.Store $p;G D16 ($c.Store.Decisions.Count-eq1-and$first.Decision.Decision-ceq$second.Decision.Decision-and$c.Store.Counters.ZoteroCreateDecision-eq1) 'duplicate replay remains idempotent'
    $existing=[pscustomobject]@{CanonicalKey='doi:10.1234/rap.001';ZoteroItemId='Z1';Title='Research Intake Safety';FirstAuthor='Kim';Year='2026'};$c=New-RapIntakeContext;$p=Promote-RapFixture $c;$first=Invoke-RapResearchIntakeDecision $c.Store $p;$null=Invoke-RapResearchIntakeReadOnlyLookup $c.Store PASS @($existing) @($existing);$second=Invoke-RapResearchIntakeDecision $c.Store $p;G D17 ($second.Decision.Decision-cne'CREATE_CANDIDATE') 'replacement FOUND evidence invalidates prior CREATE'
    $forged=Join-Path $temp 'forged-decision.db';$c=New-RapIntakeContext @() @() @((New-RapIntakeFixture)) $forged;$p=Promote-RapFixture $c;$null=Invoke-RapResearchIntakeReadOnlyLookup $c.Store TIMEOUT;$null=Invoke-RapResearchIntakeDecision $c.Store $p;$c.Store.Decisions['C-001'].Decision='CREATE_CANDIDATE';$c.Store.Decisions['C-001'].State='CREATE_CANDIDATE';Save-RapResearchIntakeStore $c.Store|Out-Null;$r=Open-RapResearchIntakeStore $forged;$second=Invoke-RapResearchIntakeDecision $r $r.Promotions['C-001'];G D18 ($second.Decision.Decision-cne'CREATE_CANDIDATE') 'valid envelope cannot bless semantically forged decision'
    $c=New-RapIntakeContext;$p=Promote-RapFixture $c;$null=Invoke-RapResearchIntakeDecision $c.Store $p;$audit=@(Get-RapResearchIntakeAudit $c.Store);$revalidation=@($audit|Where-Object{$_.Event-ceq'PROMOTION_LINEAGE_REVALIDATED'-or($_.Event-ceq'PRE_ZOTERO_DEDUP_DECIDED'-and$_.Data.PSObject.Properties['PromotionHash'])});G D19 ($revalidation.Count-gt0) 'audit proves pre-decision promotion-lineage revalidation'
}finally{Remove-Item $temp -Recurse -Force}

Write-Host "SPR-015 Turn D independent probes: PASS=$script:Pass FAIL=$script:Fail TOTAL=$($script:Pass+$script:Fail)"
if($script:Fail-gt0){Write-Host 'TURN_D_FINAL_GATE_PROBES=FAIL';exit 1}
Write-Host 'TURN_D_FINAL_GATE_PROBES=PASS'
