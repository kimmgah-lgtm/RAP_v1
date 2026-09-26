$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'TestHarness.ps1')
$script:Pass=0;$script:Fail=0
function Assert-GR([string]$id,[bool]$ok,[string]$detail){if($ok){$script:Pass++;Write-Host "$id PASS $detail"}else{$script:Fail++;Write-Host "$id FAIL $detail"}}
function Audit-GR($store,[string]$event){@($store.Audit|Where-Object{$_.Event-ceq$event})[0]}
function New-GR([string]$db=''){$c=New-RapIntakeContext @() @() @((New-RapIntakeFixture)) $db;$p=Promote-RapFixture $c;$null=Invoke-RapResearchIntakeDecision $c.Store $p;[pscustomobject]@{Context=$c;Promotion=$p}}
function Blocked-GR($x){try{(Invoke-RapResearchIntakeDecision $x.Context.Store $x.Promotion).Decision.Decision-ceq'BLOCKED'}catch{$true}}

$x=New-GR;(Audit-GR $x.Context.Store 'CANDIDATE_PROMOTED').Event='PROMOTION_AUDIT_REMOVED';Assert-GR GR01 (Blocked-GR $x) 'missing promotion audit blocked'
$x=New-GR;(Audit-GR $x.Context.Store 'CANDIDATE_PROMOTED').Sequence=(Audit-GR $x.Context.Store 'PRE_ZOTERO_DEDUP_DECIDED').Sequence+1;Assert-GR GR02 (Blocked-GR $x) 'promotion after decision blocked'
$x=New-GR;(Audit-GR $x.Context.Store 'CANDIDATE_PROMOTED').Data.CandidateId='C-EVIL';Assert-GR GR03 (Blocked-GR $x) 'wrong Candidate promotion audit blocked'
$x=New-GR;(Audit-GR $x.Context.Store 'CANDIDATE_PROMOTED').Data.ProjectId='PR999';Assert-GR GR04 (Blocked-GR $x) 'wrong Project promotion audit blocked'
$x=New-GR;(Audit-GR $x.Context.Store 'CANDIDATE_PROMOTED').Data.SearchExecutionId='SE-EVIL';Assert-GR GR05 (Blocked-GR $x) 'wrong SearchExecution promotion audit blocked'
$x=New-GR;(Audit-GR $x.Context.Store 'CANDIDATE_PROMOTED').Data.PromotionHash='forged';Assert-GR GR06 (Blocked-GR $x) 'promotion binding mismatch blocked'
$x=New-GR;$a=Audit-GR $x.Context.Store 'CANDIDATE_PROMOTED';$dup=$a|ConvertTo-Json -Depth 30|ConvertFrom-Json -Depth 30;$dup.Sequence=$x.Context.Store.Audit.Count+1;$dup.Data.CandidateId='C-EVIL';$x.Context.Store.Audit.Add($dup);Assert-GR GR07 (Blocked-GR $x) 'conflicting promotion events blocked'
$c=New-RapIntakeContext;$p1=Promote-RapFixture $c;$p2=Promote-RapFixture $c;$null=Invoke-RapResearchIntakeDecision $c.Store $p1;$promotionCount=@($c.Store.Audit|Where-Object{$_.Event-ceq'CANDIDATE_PROMOTED'}).Count;$r=Invoke-RapResearchIntakeDecision $c.Store $p2;Assert-GR GR08 ($promotionCount-eq1-and$r.Decision.Decision-ceq'CREATE_CANDIDATE') 'idempotent promotion replay keeps one authoritative event'

$temp=Join-Path ([IO.Path]::GetTempPath()) ('ri-turn-g-rem-'+[guid]::NewGuid().ToString('N'));New-Item $temp -ItemType Directory|Out-Null
try{
    $db=Join-Path $temp 'missing.db';$x=New-GR $db;(Audit-GR $x.Context.Store 'CANDIDATE_PROMOTED').Event='PROMOTION_AUDIT_REMOVED';Save-RapResearchIntakeStore $x.Context.Store|Out-Null;$s=Open-RapResearchIntakeStore $db;$y=[pscustomobject]@{Context=[pscustomobject]@{Store=$s};Promotion=$s.Promotions['C-001']};Assert-GR GR09 (Blocked-GR $y) 'restart plus missing promotion audit blocked'
    $db=Join-Path $temp 'reordered.db';$x=New-GR $db;(Audit-GR $x.Context.Store 'CANDIDATE_PROMOTED').Sequence=(Audit-GR $x.Context.Store 'PRE_ZOTERO_DEDUP_DECIDED').Sequence+1;Save-RapResearchIntakeStore $x.Context.Store|Out-Null;$s=Open-RapResearchIntakeStore $db;$y=[pscustomobject]@{Context=[pscustomobject]@{Store=$s};Promotion=$s.Promotions['C-001']};Assert-GR GR10 (Blocked-GR $y) 'restart plus reordered promotion audit blocked'
    $x=New-GR;(Audit-GR $x.Context.Store 'CANDIDATE_PROMOTED').Data.EvidenceHash='forged';Assert-GR GR11 (Blocked-GR $x) 'promotion evidence hash substitution blocked'
    $x=New-GR;$x.Context.Store.Decisions['C-001'].PromotionAuditSequence=$x.Context.Store.Decisions['C-001'].IdentityAuditSequence;Assert-GR GR12 (Blocked-GR $x) 'decision promotion-audit reference substitution blocked'
    $x=New-GR;(Audit-GR $x.Context.Store 'PRE_ZOTERO_DEDUP_DECIDED').Data.PromotionAuditEvidenceHash='';Assert-GR GR13 (Blocked-GR $x) 'decision audit omission of promotion authority blocked'
    $db=Join-Path $temp 'valid.db';$x=New-GR $db;$s=Open-RapResearchIntakeStore $db;$y=[pscustomobject]@{Context=[pscustomobject]@{Store=$s};Promotion=$s.Promotions['C-001']};$r=Invoke-RapResearchIntakeDecision $s $y.Promotion;Assert-GR GR14 ($r.Decision.Decision-ceq'CREATE_CANDIDATE'-and$r.Decision.BindingVersion-eq4) 'valid restart replay remains idempotent under binding v4'
}finally{Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue}

Write-Host "SPR-015 Turn G remediation probes: PASS=$script:Pass FAIL=$script:Fail TOTAL=$($script:Pass+$script:Fail)"
if($script:Fail-gt0){Write-Host 'TURN_G_REMEDIATION_PROBES=FAIL';exit 1}
Write-Host 'TURN_G_REMEDIATION_PROBES=PASS'
