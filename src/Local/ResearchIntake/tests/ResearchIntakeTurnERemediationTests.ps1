$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'TestHarness.ps1')
$script:Pass=0;$script:Fail=0
function Assert-ER([string]$id,[bool]$ok,[string]$detail){if($ok){$script:Pass++;Write-Host "$id PASS $detail"}else{$script:Fail++;Write-Host "$id FAIL $detail"}}
function Existing([string]$id='Z-GOOD',[string]$library='LIBRARY-1'){[pscustomobject]@{CanonicalKey='doi:10.1234/rap.001';ZoteroItemId=$id;LibraryId=$library;Title='Research Intake Safety';FirstAuthor='Kim';Year='2026'}}
function Identity-Attack([scriptblock]$change){$c=New-RapIntakeContext;$p=Promote-RapFixture $c;$i=Resolve-RapCanonicalPaperIdentity $c.Store $p;&$change $i;(Get-RapIntakeThrown {Get-RapPreZoteroDedupDecision $c.Store $p $i})-match'(IDENTITY_BINDING_MISMATCH|CANDIDATE_SUBSTITUTION)'}
function Reuse-Attack([scriptblock]$change){$e=Existing;$c=New-RapIntakeContext @($e) @($e);$p=Promote-RapFixture $c;$null=Invoke-RapResearchIntakeDecision $c.Store $p;&$change $c.Store.Decisions['C-001'];(Invoke-RapResearchIntakeDecision $c.Store $p).Decision.Decision-ceq'BLOCKED'}

Assert-ER ER01 (Identity-Attack {$args[0].CanonicalKey='doi:10.9999/other'}) 'canonical identity substitution blocked'
Assert-ER ER02 (Identity-Attack {$args[0].NormalizedDoi='10.9999/other'}) 'normalized DOI substitution blocked'
$c=New-RapIntakeContext -Results @((New-RapIntakeFixture C-PMID '' 'Research Intake Safety' 'Kim' '2026' '123'));$p=Promote-RapFixture $c C-PMID;$i=Resolve-RapCanonicalPaperIdentity $c.Store $p;$i.Pmid='999';Assert-ER ER03 ((Get-RapIntakeThrown {Get-RapPreZoteroDedupDecision $c.Store $p $i})-match'IDENTITY_BINDING_MISMATCH') 'PMID substitution blocked'
Assert-ER ER04 (Identity-Attack {$args[0].CandidateId='C-OTHER'}) 'Candidate identity artifact substitution blocked'
Assert-ER ER05 (Identity-Attack {$args[0].ProjectId='PR999'}) 'Project identity artifact substitution blocked'
$c=New-RapIntakeContext;$p=Promote-RapFixture $c;$i=Resolve-RapCanonicalPaperIdentity $c.Store $p;$c.Store.Inbox['C-001'].Doi='10.9999/changed';Assert-ER ER06 ((Get-RapIntakeThrown {Get-RapPreZoteroDedupDecision $c.Store $p $i})-match'CANDIDATE_SUBSTITUTION') 'stale identity after source evidence change blocked'
Assert-ER ER07 (Reuse-Attack {$args[0].ZoteroItemId='Z-EVIL'}) 'ZoteroItemId substitution blocked'
Assert-ER ER08 (Reuse-Attack {$args[0].ZoteroLibraryContext='LIBRARY-EVIL'}) 'Zotero library context substitution blocked'
Assert-ER ER09 (Reuse-Attack {$args[0].CanonicalTargetIdentity='doi:10.9999/evil'}) 'canonical target substitution blocked'
Assert-ER ER10 (Reuse-Attack {$args[0].CandidateId='C-OTHER'}) 'Candidate A REUSE cannot become Candidate B authority'

$temp=Join-Path ([IO.Path]::GetTempPath()) ('ri-er-'+[guid]::NewGuid().ToString('N'));New-Item $temp -ItemType Directory|Out-Null
try{
    $db=Join-Path $temp 'reuse-envelope.db';$e=Existing;$c=New-RapIntakeContext @($e) @($e) @((New-RapIntakeFixture)) $db;$p=Promote-RapFixture $c;$null=Invoke-RapResearchIntakeDecision $c.Store $p;$c.Store.Decisions['C-001'].ZoteroItemId='Z-EVIL';Save-RapResearchIntakeStore $c.Store|Out-Null;$s=Open-RapResearchIntakeStore $db;$r=Invoke-RapResearchIntakeDecision $s $s.Promotions['C-001'];Assert-ER ER11 ($r.Decision.Decision-ceq'BLOCKED') 'stale REUSE plus fresh envelope blocked'
    $db=Join-Path $temp 'audit.db';$e=Existing;$c=New-RapIntakeContext @($e) @($e) @((New-RapIntakeFixture)) $db;$p=Promote-RapFixture $c;$r=Invoke-RapResearchIntakeDecision $c.Store $p;$s=Open-RapResearchIntakeStore $db;$d=$s.Decisions['C-001'];$a=@($s.Audit|Where-Object{$_.Event-ceq'PRE_ZOTERO_DEDUP_DECIDED'-and$_.Data.DecisionId-ceq$d.DecisionId});Assert-ER ER12 ($a.Count-eq1-and$a[0].Data.ZoteroItemId-ceq'Z-GOOD'-and$a[0].Data.ZoteroLibraryContext-ceq'LIBRARY-1'-and$a[0].Data.CanonicalTargetIdentity-ceq'doi:10.1234/rap.001'-and$a[0].Data.ExactTargetEvidenceHash-ceq$d.ExactTargetEvidenceHash-and$a[0].Data.DecisionBindingHash-ceq$d.DecisionBindingHash) 'REUSE audit reconstructs exact target authority'
}finally{Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue}

Write-Host "SPR-015 Turn E remediation probes: PASS=$script:Pass FAIL=$script:Fail TOTAL=$($script:Pass+$script:Fail)"
if($script:Fail-gt0){Write-Host 'TURN_E_REMEDIATION_PROBES=FAIL';exit 1}
Write-Host 'TURN_E_REMEDIATION_PROBES=PASS'
