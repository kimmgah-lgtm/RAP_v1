. (Join-Path $PSScriptRoot 'TestHarness.ps1')
$script:N=0
function A($id,$ok,$message){$script:N++;if(-not$ok){throw "$id failed: $message"};Write-Host "$id PASS $message"}
function Test-LookupBlock([string]$outcome){
    $c=New-RapIntakeContext;$p=Promote-RapFixture $c;$null=Invoke-RapResearchIntakeReadOnlyLookup $c.Store $outcome
    $r=Invoke-RapResearchIntakeDecision $c.Store $p
    $r.Decision.Decision-ceq'BLOCKED'-and$r.Decision.Reason-match'^LOOKUP_NOT_AUTHORITATIVE:'-and$c.Store.Counters.ZoteroCreateDecision-eq0
}

A 'REM-P1A-01' (Test-LookupBlock 'TIMEOUT') 'TIMEOUT remains blocked'
A 'REM-P1A-02' (Test-LookupBlock 'PARTIAL') 'PARTIAL remains blocked'
$c=New-RapIntakeContext;$p=Promote-RapFixture $c;$c.Store.Inbox['C-001'].SearchExecutionId='SE-SUBSTITUTED'
A 'REM-P1B-01' ((Get-RapIntakeThrown {Invoke-RapResearchIntakeDecision $c.Store $p})-match'CANDIDATE_SUBSTITUTION') 'search lineage substitution blocked'

$lookupCases=@('MALFORMED','AUTH_FAILURE','PERMISSION_AMBIGUITY','UNKNOWN','MULTIPLE')
foreach($outcome in $lookupCases){A "REM-LU-$outcome" (Test-LookupBlock $outcome) "$outcome is not NOT_FOUND"}
$c=New-RapIntakeContext @() @() @((New-RapIntakeFixture)) '' $true;$p=Promote-RapFixture $c;$r=Invoke-RapResearchIntakeDecision $c.Store $p
A 'REM-LU-MISSING' ($r.Decision.Decision-ceq'BLOCKED'-and$r.Decision.Reason-ceq'LOOKUP_NOT_AUTHORITATIVE:LOOKUP_REQUIRED') 'default constructor cannot imply NOT_FOUND'

$lineageCases=@(
    @('PROJECT',{param($candidate)$candidate.ProjectId='PR999'}),
    @('QUESTION',{param($candidate)$candidate.ResearchQuestionId='RQ-SUBSTITUTED'}),
    @('CANDIDATE',{param($candidate)$candidate.CandidateId='C-SUBSTITUTED'}),
    @('DOI',{param($candidate)$candidate.Doi='10.9999/substituted'}),
    @('PMID',{param($candidate)$candidate.Pmid='999999'})
)
foreach($case in $lineageCases){$c=New-RapIntakeContext;$p=Promote-RapFixture $c;&$case[1] $c.Store.Inbox['C-001'];A "REM-LN-$($case[0])" ((Get-RapIntakeThrown {Invoke-RapResearchIntakeDecision $c.Store $p})-match'CANDIDATE_SUBSTITUTION') "$($case[0]) substitution blocked"}

$temp=Join-Path ([IO.Path]::GetTempPath()) ('rap-rem-'+[guid]::NewGuid());New-Item $temp -ItemType Directory|Out-Null
try{
    foreach($outcome in @('TIMEOUT','PARTIAL','UNKNOWN')){$db=Join-Path $temp "$outcome.db";$c=New-RapIntakeContext @() @() @((New-RapIntakeFixture)) $db;$p=Promote-RapFixture $c;$null=Invoke-RapResearchIntakeReadOnlyLookup $c.Store $outcome;$r=Open-RapResearchIntakeStore $db;$result=Invoke-RapResearchIntakeDecision $r $r.Promotions['C-001'];A "REM-RS-$outcome" ($result.Decision.Decision-ceq'BLOCKED'-and$r.Counters.ZoteroCreateDecision-eq0) "$outcome survives restart as blocked"}
    $db=Join-Path $temp 'lineage.db';$c=New-RapIntakeContext @() @() @((New-RapIntakeFixture)) $db;$p=Promote-RapFixture $c;$r=Open-RapResearchIntakeStore $db;$r.Inbox['C-001'].SearchExecutionId='SE-SUBSTITUTED';Save-RapResearchIntakeStore $r|Out-Null;$r2=Open-RapResearchIntakeStore $db;A 'REM-RS-LINEAGE' ((Get-RapIntakeThrown {Invoke-RapResearchIntakeDecision $r2 $r2.Promotions['C-001']})-match'CANDIDATE_SUBSTITUTION') 'lineage binding survives restart and valid envelope rewrite'
    $legacy=Join-Path $temp 'legacy.db';$c=New-RapIntakeContext @() @() @((New-RapIntakeFixture)) $legacy;[Rap.NativeSqlite]::Execute($legacy,"UPDATE ResearchIntakeStore SET SchemaVersion=1 WHERE StoreId='PRIMARY';",5000);A 'REM-SCHEMA-LEGACY' ((Get-RapIntakeThrown {Open-RapResearchIntakeStore $legacy})-match'SCHEMA_UNSUPPORTED') 'legacy schema fails closed'
}finally{Remove-Item $temp -Recurse -Force}

if($script:N-ne19){throw "Expected 19 remediation assertions, got $script:N"}
Write-Host 'SPR-015 Turn C remediation: 19/19 PASS; production mutations 0/0/0'
