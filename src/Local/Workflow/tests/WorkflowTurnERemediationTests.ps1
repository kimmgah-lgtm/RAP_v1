#Requires -Version 7.0
# SPR-011 Turn E — P1 remediation assertions for RISK-SPR011-002 ~ 006.
# Every assertion has a stable ID (E1-*, E2-*, E3-*, E5-*) referenced by docs/SPR-011-SCENARIO-MATRIX.md.
# The suite collects every result (instead of stopping at the first failure) so the same file
# produces the RED evidence before repair and the GREEN evidence after repair.
[CmdletBinding()]param([string]$ResultPath)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'ResearchAutomation.Workflow.psd1') -Force
. (Join-Path $PSScriptRoot 'TestHarness.ps1')
$script:Results=[Collections.Generic.List[object]]::new()
function Check([string]$Id,[string]$Name,[scriptblock]$Body){
    $ok=$false;$detail=$null
    try{$ok=[bool](&$Body)}catch{$detail=$_.Exception.Message}
    $script:Results.Add([pscustomobject]@{Id=$Id;Name=$Name;Result=$(if($ok){'PASS'}else{'FAIL'});Detail=$detail})
}
function Throws([scriptblock]$Action,[string]$Pattern){try{&$Action;return $false}catch{return $_.Exception.Message-match$Pattern}}
function Get-ThrownMessage([scriptblock]$Action){try{&$Action;return $null}catch{return $_.Exception.Message}}
function Get-TestHash($Value){[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes(($Value|ConvertTo-Json -Depth 80 -Compress)))).ToLowerInvariant()}
function Invoke-Op($Snapshot,[string]$Id,$Memory){Invoke-RapWorkflowExceptionOperation -Snapshot $Snapshot -OperationId $Id -Dependencies $Memory.Dependencies}
function Unchanged($Result){@($Result.Result.Reconciliations|Where-Object{$_.BeforeHash-ne$_.AfterHash}).Count-eq0}

$base=New-RapWorkflowTurnEFixture

# ------------------------------------------------------------------ E1 — RISK-SPR011-002 taxonomy
$tax=@(Get-RapExceptionTaxonomy)
Check 'E1-01' 'taxonomy contains AUTOMATION_FAILURE with non-AUTO_SAFE default' {$e=$tax|Where-Object ExceptionClass -eq 'AUTOMATION_FAILURE';$e-and$e.DefaultResolution-eq'BLOCKED'}
Check 'E1-02' 'taxonomy has 14 unique classes' {$tax.Count-eq14-and@($tax.ExceptionClass|Sort-Object -Unique).Count-eq14}
$masked=Copy-RapWorkflowFixture $base;$masked.AutomationRuns=@([pscustomobject]@{RunId='RUN-M';ExitCode=0;Status='SUCCEEDED';ErrorEvidence=@('Get-FileHash : term not recognized')})
Check 'E1-03' 'masked failure (exit 0 + error evidence) detected as AUTOMATION_FAILURE' {$d=@(Find-RapWorkflowExceptions $masked|Where-Object ExceptionClass -eq 'AUTOMATION_FAILURE');$d.Count-eq1-and$d[0].Evidence.Masked-eq$true-and$d[0].Evidence.RunId-eq'RUN-M'}
$nonzero=Copy-RapWorkflowFixture $base;$nonzero.AutomationRuns=@([pscustomobject]@{RunId='RUN-N';ExitCode=1;Status='FAILED';ErrorEvidence=@()})
Check 'E1-04' 'non-zero exit detected as unmasked AUTOMATION_FAILURE' {$d=@(Find-RapWorkflowExceptions $nonzero|Where-Object ExceptionClass -eq 'AUTOMATION_FAILURE');$d.Count-eq1-and$d[0].Evidence.Masked-eq$false}
Check 'E1-05' 'successful automation run produces no AUTOMATION_FAILURE' {@(Find-RapWorkflowExceptions $base).Count-eq0}
$n=0;foreach($raw in @('NOT_A_CLASS',$null,'stale',' STALE ','')){$n++;$value=$raw;Check "E1-0$(5+$n)" "unsupported type normalizes to UNKNOWN_EXCEPTION [$n]" {(ConvertTo-RapExceptionClass $value).ExceptionClass-eq'UNKNOWN_EXCEPTION'}}
Check 'E1-11' 'raw unsupported exception normalizes to blocked UNKNOWN_EXCEPTION with original class evidence' {$x=ConvertTo-RapNormalizedException -RawException ([pscustomobject]@{ExceptionClass='DriveQuotaWeird';Detail='x'}) -Snapshot $base;$x.ExceptionClass-eq'UNKNOWN_EXCEPTION'-and$x.DefaultResolution-eq'BLOCKED'-and$x.Evidence.OriginalClass-eq'DriveQuotaWeird'}
Check 'E1-12' 'normalized unsupported exception forces composite BLOCKED' {$stale=Copy-RapWorkflowFixture $base;$stale.VersionState.SourceVersion=2;$x=ConvertTo-RapNormalizedException -RawException ([pscustomobject]@{ExceptionClass=$null}) -Snapshot $stale;$p=Get-RapCompositeResolutionPolicy (@(Find-RapWorkflowExceptions $stale)+@($x)) $stale;$p.CompositeResolution-eq'BLOCKED'-and-not$p.AutoSafeEligible}
Check 'E1-13' 'forged exception with unsupported class fails closed' {$f=[pscustomobject]@{ExceptionId='EXC-FORGED';ExceptionClass='NOT_REAL';DefaultResolution='AUTO_SAFE';Evidence=[pscustomobject]@{}};$p=Get-RapCompositeResolutionPolicy @($f) $base;$p.CompositeResolution-eq'BLOCKED'-and$p.PolicyEvaluationFailed}
Check 'E1-14' 'forged DefaultResolution on known class fails closed' {$f=[pscustomobject]@{ExceptionId='EXC-FORGED2';ExceptionClass='UNKNOWN_EXCEPTION';DefaultResolution='AUTO_SAFE';Evidence=[pscustomobject]@{}};$p=Get-RapCompositeResolutionPolicy @($f) $base;$p.CompositeResolution-eq'BLOCKED'-and$p.PolicyEvaluationFailed}
$autoStale=Copy-RapWorkflowFixture $nonzero;$autoStale.VersionState.SourceVersion=2
Check 'E1-15' 'AUTOMATION_FAILURE + STALE is BLOCKED with zero mutation' {$m=New-RapMemoryWorkflowDependencies;$r=Invoke-Op $autoStale 'E1-15' $m;$r.Result.SafetyContext.CompositeResolution-eq'BLOCKED'-and@($r.Result.Plans|Where-Object ResolutionState -eq 'AUTO_SAFE').Count-eq0-and(Unchanged $r)}

# ------------------------------------------------------------------ E2 — RISK-SPR011-003 downstream semantics
# E05 canonical PDF missing
$pdfMissing=Copy-RapWorkflowFixture $base;$pdfMissing.Pdf.Exists=$false;$pdfMissing.Pdf.CurrentHash=$null
$pdfEx=@(Find-RapWorkflowExceptions $pdfMissing|Where-Object ExceptionClass -eq 'PDF_MISSING_OR_REPLACED')
Check 'E2-01' 'E05 evidence models the downstream block' {$pdfEx.Count-eq1-and$pdfEx[0].Evidence.Condition-eq'MISSING'-and$pdfEx[0].Evidence.DownstreamBlockModeled-eq$true}
Check 'E2-02' 'E05 evidence lists PDF-dependent artifacts as BLOCKED' {$a=@($pdfEx[0].Evidence.AffectedArtifacts);@($a|Where-Object{$_.ArtifactId-in@('REVIEW-EV-1','CODING-EV-1')-and$_.EffectiveStatus-eq'BLOCKED'}).Count-eq2}
Check 'E2-03' 'E05 PDF-dependent operation is executably refused' {$t=Test-RapDependentOperationPermitted -Snapshot $pdfMissing -ArtifactId 'CODING-EV-1' -Operation 'EXTRACT';-not$t.Permitted-and$t.Reason-eq'PDF_MISSING'}
Check 'E2-04' 'E05 block propagates transitively to Synthesis and Output' {$i=@(Get-RapDownstreamImpact -Snapshot $pdfMissing);@($i|Where-Object{$_.ArtifactId-in@('SYNTH-1','OUTPUT-1')-and$_.EffectiveStatus-eq'BLOCKED'}).Count-eq2}
Check 'E2-05' 'E05 metadata/review/coding preserved with no delete' {$m=New-RapMemoryWorkflowDependencies;$r=Invoke-Op $pdfMissing 'E2-05' $m;(Unchanged $r)-and@($r.Result.Plans|Where-Object{-not$_.NoDelete-or$_.Actions-contains'DELETE'}).Count-eq0-and$r.Result.SafetyContext.CompositeResolution-ne'AUTO_SAFE'}
# E06 PDF replaced / hash changed
$pdfChanged=Copy-RapWorkflowFixture $base;$pdfChanged.Pdf.CurrentHash='pdf-hash-v2'
$chgEx=@(Find-RapWorkflowExceptions $pdfChanged|Where-Object ExceptionClass -eq 'PDF_MISSING_OR_REPLACED')
Check 'E2-06' 'E06 evidence enumerates all four dependent artifacts' {$chgEx.Count-eq1-and$chgEx[0].Evidence.Condition-eq'HASH_CHANGED'-and@($chgEx[0].Evidence.AffectedArtifacts).Count-eq4}
Check 'E2-07' 'E06 every dependent is REVALIDATION_REQUIRED, none CURRENT' {$a=@($chgEx[0].Evidence.AffectedArtifacts);@($a|Where-Object EffectiveStatus -ne 'REVALIDATION_REQUIRED').Count-eq0}
Check 'E2-08' 'E06 no automatic recomputation' {$m=New-RapMemoryWorkflowDependencies;$r=Invoke-Op $pdfChanged 'E2-08' $m;@($r.Result.Plans|Where-Object{$_.Actions-match'RECOMPUTE|REGENERATE'}).Count-eq0-and@($r.Result.Reconciliations|Where-Object{(Get-TestHash $_.UpdatedSnapshot.Dependents)-ne(Get-TestHash $pdfChanged.Dependents)}).Count-eq0}
Check 'E2-09' 'E06 status transitions CURRENT to REVALIDATION_REQUIRED recorded as lifecycle events' {$m=New-RapMemoryWorkflowDependencies;$null=Invoke-Op $pdfChanged 'E2-09' $m;$t=@($m.Events|Where-Object{$_.EventType-eq'DEPENDENT_STATUS_TRANSITION'-and$_.FromState-eq'CURRENT'-and$_.ToState-eq'REVALIDATION_REQUIRED'});$t.Count-eq4}
# E10 AI-assisted vs researcher-confirmed conflict
$ai=Copy-RapWorkflowFixture $base;$ai.CodingState.AiResearcherConflict=$true;$ai.CodingState.ConflictingFields=@('Outcome');$ai.CodingState.AiSuggestions=@([pscustomobject]@{Field='Outcome';Value='AI-OUT-9';ModelId='fixture-model';ModelVersion='2026-09-01';RunId='AI-RUN-7'})
$aiEx=@(Find-RapWorkflowExceptions $ai|Where-Object ExceptionClass -eq 'AI_ASSISTED_RESEARCHER_CONFIRMED_CONFLICT')
Check 'E2-10' 'E10 evidence records AI value, model, version and run' {$c=@($aiEx[0].Evidence.Conflicts)[0];$c.AiValue-eq'AI-OUT-9'-and$c.AiModelId-eq'fixture-model'-and$c.AiModelVersion-eq'2026-09-01'-and$c.AiRunId-eq'AI-RUN-7'-and$c.AiProvenanceComplete-eq$true}
Check 'E2-11' 'E10 evidence records researcher value and confirmation provenance' {$c=@($aiEx[0].Evidence.Conflicts)[0];$c.ResearcherValue-eq'OUT-1'-and$c.ConfirmationProvenance.ConfirmedBy-eq'researcher:kim'}
$aiMem=New-RapMemoryWorkflowDependencies;$aiRun=$null;try{$aiRun=Invoke-Op $ai 'E2-12' $aiMem}catch{}
Check 'E2-12' 'E10 typed retention: AI branch retained, not applied' {$rec=@($aiRun.Result.Reconciliations|Where-Object ExceptionClass -eq 'AI_ASSISTED_RESEARCHER_CONFIRMED_CONFLICT')[0];$ra=@($rec.RetainedAlternatives);$ra.Count-eq1-and$ra[0].Disposition-eq'RETAINED_NOT_APPLIED'-and$ra[0].Applied-eq$false-and$ra[0].AiValue-eq'AI-OUT-9'}
Check 'E2-13' 'E10 researcher-confirmed unchanged and alternative persisted in registry' {(@($aiRun.Result.Reconciliations|Where-Object{(Get-TestHash $_.UpdatedSnapshot.ResearcherConfirmed)-ne(Get-TestHash $ai.ResearcherConfirmed)}).Count-eq0)-and@($aiMem.State.RetainedAlternatives).Count-eq1}
$aiNoProv=Copy-RapWorkflowFixture $ai;$aiNoProv.CodingState.AiSuggestions=@([pscustomobject]@{Field='Outcome';Value='AI-OUT-9'})
Check 'E2-14' 'E10 incomplete AI provenance is flagged and never AUTO_SAFE' {$c=@((Find-RapWorkflowExceptions $aiNoProv|Where-Object ExceptionClass -eq 'AI_ASSISTED_RESEARCHER_CONFIRMED_CONFLICT').Evidence.Conflicts)[0];$p=Get-RapCompositeResolutionPolicy @(Find-RapWorkflowExceptions $aiNoProv) $aiNoProv;$c.AiProvenanceComplete-eq$false-and$p.CompositeResolution-eq'HUMAN_REVIEW_REQUIRED'}
# E11 stale derived artifact
$stale=Copy-RapWorkflowFixture $base;$stale.VersionState.SourceVersion=2
$staleEx=@(Find-RapWorkflowExceptions $stale|Where-Object ExceptionClass -eq 'STALE')
Check 'E2-15' 'E11 evidence records dependent artifact identity and status' {$a=@($staleEx[0].Evidence.AffectedArtifacts);@($a|Where-Object{$_.ArtifactId-eq'SYNTH-1'-and$_.EffectiveStatus-eq'REVALIDATION_REQUIRED'-and$_.RecordedStatus-eq'CURRENT'}).Count-eq1-and@($a|Where-Object{$_.ArtifactId-eq'OUTPUT-1'-and$_.EffectiveStatus-eq'REVALIDATION_REQUIRED'}).Count-eq1}
$staleMem=New-RapMemoryWorkflowDependencies;$staleRun=$null;try{$staleRun=Invoke-Op $stale 'E2-16' $staleMem}catch{}
Check 'E2-16' 'E11 DerivedVersion refresh alone does not mark dependents CURRENT' {$u=$staleRun.Result.Reconciliations[0].UpdatedSnapshot;$u.VersionState.DerivedVersion-eq2-and(@(Get-RapDownstreamImpact -Snapshot $u)|Where-Object ArtifactId -eq 'SYNTH-1').EffectiveStatus-eq'REVALIDATION_REQUIRED'}
Check 'E2-17' 'E11 stale artifact cannot be consumed as current' {$u=$staleRun.Result.Reconciliations[0].UpdatedSnapshot;$t=Test-RapDependentOperationPermitted -Snapshot $u -ArtifactId 'OUTPUT-1' -Operation 'CONSUME';-not$t.Permitted-and$t.EffectiveStatus-eq'REVALIDATION_REQUIRED'}
Check 'E2-18' 'E11 explicit revalidation evidence restores CURRENT' {$u=Copy-RapWorkflowFixture $staleRun.Result.Reconciliations[0].UpdatedSnapshot;foreach($d in $u.Dependents){$d.BasisVersion=2};(Test-RapDependentOperationPermitted -Snapshot $u -ArtifactId 'OUTPUT-1' -Operation 'CONSUME').Permitted}
Check 'E2-19' 'unknown artifact is refused (fail closed)' {-not(Test-RapDependentOperationPermitted -Snapshot $base -ArtifactId 'NOT-IN-LINEAGE' -Operation 'CONSUME').Permitted}
Check 'E2-20' 'lineage reference to missing artifact blocks the dependent' {$x=Copy-RapWorkflowFixture $base;$x.Dependents[3].Upstream=@('GHOST-1');$i=@(Get-RapDownstreamImpact -Snapshot $x)|Where-Object ArtifactId -eq 'OUTPUT-1';$i.EffectiveStatus-eq'BLOCKED'-and$i.Cause-eq'LINEAGE_REFERENCE_MISSING'}
Check 'E2-21' 'lineage cycle blocks instead of looping' {$x=Copy-RapWorkflowFixture $base;$x.Dependents[2].Upstream=@('OUTPUT-1');$i=@(Get-RapDownstreamImpact -Snapshot $x)|Where-Object ArtifactId -eq 'SYNTH-1';$i.EffectiveStatus-eq'BLOCKED'}
# E01-E12 semantic re-verification (detector + disposition + preservation), Turn-E fixture
$sem=[ordered]@{}
$x=Copy-RapWorkflowFixture $base;$x.Zotero.Exists=$false;$sem['E01']=@($x,'BLOCKED')
$x=Copy-RapWorkflowFixture $base;$x.Zotero.Registrations=@('ZOT-1','ZOT-2');$sem['E02']=@($x,'HUMAN_REVIEW_REQUIRED')
$x=Copy-RapWorkflowFixture $base;$x.NotionReview.Exists=$false;$sem['E03']=@($x,'HUMAN_REVIEW_REQUIRED')
$x=Copy-RapWorkflowFixture $base;$x.NotionReview.CreationSource='MANUAL';$x.NotionReview.Registered=$false;$sem['E04']=@($x,'HUMAN_REVIEW_REQUIRED')
$sem['E05']=@($pdfMissing,'HUMAN_REVIEW_REQUIRED')
$sem['E06']=@($pdfChanged,'HUMAN_REVIEW_REQUIRED')
$x=Copy-RapWorkflowFixture $base;$x.LibraryLinkage.Valid=$false;$x.LibraryLinkage.LinkedLibraryId='LIB:OTHER';$sem['E07']=@($x,'BLOCKED')
$x=Copy-RapWorkflowFixture $base;$x.ProjectLinkage.Valid=$false;$x.ProjectLinkage.LinkedProjectId='PR002';$sem['E08']=@($x,'HUMAN_REVIEW_REQUIRED')
$x=Copy-RapWorkflowFixture $base;$x.EditState.AutomationManualConflict=$true;$x.EditState.ConflictingFields=@('ReviewerMemo');$sem['E09']=@($x,'HUMAN_REVIEW_REQUIRED')
$sem['E10']=@($ai,'HUMAN_REVIEW_REQUIRED')
$sem['E11']=@($stale,'AUTO_SAFE')
$x=Copy-RapWorkflowFixture $base;$x.UnknownSignals=@('unclassified');$sem['E12']=@($x,'BLOCKED')
foreach($k in $sem.Keys){$s=$sem[$k][0];$exp=$sem[$k][1];Check "E2-S-$k" "semantic $k disposition $exp and protected data preserved" {
    $m=New-RapMemoryWorkflowDependencies;$r=Invoke-Op $s "SEM-$k" $m
    $ok=$r.Result.SafetyContext.CompositeResolution-eq$exp-and@($r.Result.Verifications|Where-Object Status -ne 'VERIFIED').Count-eq0
    $ok=$ok-and@($r.Result.Reconciliations|Where-Object{(Get-TestHash $_.UpdatedSnapshot.HumanOwned)-ne(Get-TestHash $s.HumanOwned)-or(Get-TestHash $_.UpdatedSnapshot.ResearcherConfirmed)-ne(Get-TestHash $s.ResearcherConfirmed)-or$_.UpdatedSnapshot.LibraryId-ne$s.LibraryId}).Count-eq0
    if($exp-ne'AUTO_SAFE'){$ok=$ok-and(Unchanged $r)}
    $ok}}

# ------------------------------------------------------------------ E3 — RISK-SPR011-004 lifecycle audit (SQLite)
$temp=Join-Path ([IO.Path]::GetTempPath()) "rap-turn-e-$PID-$([guid]::NewGuid().ToString('N'))";[void][IO.Directory]::CreateDirectory($temp)
try{
    $db=Join-Path $temp 'wf.db'
    $sql=$null;try{$sql=New-RapWorkflowSqliteDependencies -DatabasePath $db -AuthorizedResearchers @('researcher:kim')}catch{}
    $review=Copy-RapWorkflowFixture $base;$review.Zotero.Registrations=@('ZOT-1','ZOT-2')
    $rv=$null;$sv=$null
    try{$rv=Invoke-RapWorkflowExceptionOperation -Snapshot $review -OperationId 'E3-REVIEW' -Dependencies $sql}catch{}
    try{$sv=Invoke-RapWorkflowExceptionOperation -Snapshot $stale -OperationId 'E3-STALE' -Dependencies $sql}catch{}
    $snap=$null;try{$snap=Get-RapWorkflowExceptionSnapshot $db}catch{}
    Check 'E3-01' 'audit records actor identity and actor type' {$snap.LastAudit.Actor-eq'rap-automation:workflow-engine'-and$snap.LastAudit.ActorType-eq'AUTOMATION'}
    Check 'E3-02' 'audit persists actual prior state, not only its hash' {(Get-TestHash $snap.LastAudit.PriorState)-eq(Get-TestHash $stale)-and$snap.LastAudit.PriorStateHash.Length-eq64}
    $reviewId='UNAVAILABLE';$staleId='UNAVAILABLE';try{$reviewId=@($rv.Result.Detected)[0].ExceptionId;$staleId=@($sv.Result.Detected)[0].ExceptionId}catch{}
    Check 'E3-03' 'review case lifecycle sequence reconstructed' {(@(Get-RapExceptionLifecycle -ExceptionId $reviewId -Dependencies $sql).EventType-join'>')-eq'DETECTED>PLANNED>STATE_PRESERVED>VERIFIED>AWAITING_HUMAN_REVIEW'}
    Check 'E3-04' 'AUTO_SAFE case lifecycle ends in FINAL_RESOLUTION' {$l=@(Get-RapExceptionLifecycle -ExceptionId $staleId -Dependencies $sql);($l.EventType-join'>')-eq'DETECTED>PLANNED>RECONCILIATION_APPLIED>VERIFIED>FINAL_RESOLUTION'-and$l[-1].ToState-eq'RECONCILED'}
    Check 'E3-05' 'every transition event has from/to state, actor and timestamp' {$l=@(Get-RapExceptionLifecycle -ExceptionId $staleId -Dependencies $sql);@($l|Where-Object{-not$_.ToState-or-not$_.Timestamp-or-not$_.Actor-or-not$_.PSObject.Properties['FromState']}).Count-eq0}
    $decision=$null;try{$decision=Submit-RapHumanReviewDecision -ExceptionId $reviewId -Decision 'KEEP_BLOCKED' -Actor 'researcher:kim' -ActorType RESEARCHER -Rationale 'Both registrations kept; manual merge in Zotero later.' -DecisionId 'D-1' -Dependencies $sql}catch{}
    Check 'E3-06' 'human review decision event records decision, actor, timestamp, provenance and permitted action' {$e=@(Get-RapExceptionLifecycle -ExceptionId $reviewId -Dependencies $sql|Where-Object EventType -eq 'HUMAN_REVIEW_DECISION')[0];$e.Actor-eq'researcher:kim'-and$e.ActorType-eq'RESEARCHER'-and$e.Detail.Decision-eq'KEEP_BLOCKED'-and$e.Detail.DecisionId-eq'D-1'-and$e.Detail.PermittedAction-eq'NONE'-and$e.Timestamp}
    Check 'E3-07' 'final resolution is a distinct event from operation completion' {$l=@(Get-RapExceptionLifecycle -ExceptionId $reviewId -Dependencies $sql);$l[-1].EventType-eq'FINAL_RESOLUTION'-and$l[-1].ToState-eq'RESOLVED_KEEP_BLOCKED'-and@((&$sql.ReadEvents)|Where-Object EventType -eq 'OPERATION_COMPLETED').Count-ge2}
    Check 'E3-08' 'automation actor cannot write a human review decision' {Throws {Submit-RapHumanReviewDecision -ExceptionId $reviewId -Decision 'KEEP_BLOCKED' -Actor 'rap-automation:workflow-engine' -ActorType RESEARCHER -Rationale 'x' -DecisionId 'D-2' -Dependencies $sql} 'AUTOMATION_CANNOT_DECIDE'}
    Check 'E3-09' 'unauthorized researcher decision rejected' {Throws {Submit-RapHumanReviewDecision -ExceptionId $reviewId -Decision 'KEEP_BLOCKED' -Actor 'researcher:intruder' -ActorType RESEARCHER -Rationale 'x' -DecisionId 'D-3' -Dependencies $sql} 'RESEARCHER_NOT_AUTHORIZED'}
    Check 'E3-10' 'decision on a case not awaiting review rejected' {Throws {Submit-RapHumanReviewDecision -ExceptionId $staleId -Decision 'KEEP_BLOCKED' -Actor 'researcher:kim' -ActorType RESEARCHER -Rationale 'x' -DecisionId 'D-4' -Dependencies $sql} 'CASE_NOT_AWAITING_DECISION'}
    Check 'E3-11' 'decision permits no destructive action and changes no source data' {$decision.Status-eq'COMPLETED'-and$decision.PermittedAction-notin@('DELETE','MERGE','SELECT_CANONICAL','OVERWRITE_HUMAN_OWNED','OVERWRITE_RESEARCHER_CONFIRMED','PRODUCTION_WRITE')-and@((Get-RapWorkflowExceptionSnapshot $db).Exceptions).Count-eq2}
    Check 'E3-12' 'decision replay idempotent; changed decision payload conflicts' {$again=Submit-RapHumanReviewDecision -ExceptionId $reviewId -Decision 'KEEP_BLOCKED' -Actor 'researcher:kim' -ActorType RESEARCHER -Rationale 'Both registrations kept; manual merge in Zotero later.' -DecisionId 'D-1' -Dependencies $sql;$again.Status-eq'ALREADY_COMPLETED'-and(Throws {Submit-RapHumanReviewDecision -ExceptionId $reviewId -Decision 'REQUIRE_REVALIDATION' -Actor 'researcher:kim' -ActorType RESEARCHER -Rationale 'changed' -DecisionId 'D-1' -Dependencies $sql} 'PAYLOAD_CONFLICT')}
    Check 'E3-13' 'lifecycle reconstructed from a freshly opened store equals expected sequence' {$fresh=New-RapWorkflowSqliteDependencies -DatabasePath $db -AuthorizedResearchers @('researcher:kim');(@(Get-RapExceptionLifecycle -ExceptionId $reviewId -Dependencies $fresh).EventType-join'>')-eq'DETECTED>PLANNED>STATE_PRESERVED>VERIFIED>AWAITING_HUMAN_REVIEW>HUMAN_REVIEW_DECISION>FINAL_RESOLUTION'}
    $eventCount=-1;try{$eventCount=@(&$sql.ReadEvents).Count}catch{}
    Check 'E3-14' 'operation replay adds no lifecycle events' {$r=Invoke-RapWorkflowExceptionOperation -Snapshot $stale -OperationId 'E3-STALE' -Dependencies $sql;$r.Status-eq'ALREADY_COMPLETED'-and@(&$sql.ReadEvents).Count-eq$eventCount}
    Check 'E3-15' 'audit chain valid on untampered store' {(Test-RapWorkflowAuditChain -DatabasePath $db).Valid}
    Check 'E3-16' 'module exposes no audit update/delete command' {@((Get-Module ResearchAutomation.Workflow).ExportedCommands.Keys|Where-Object{$_-match'^(Remove|Clear|Set|Update|Edit)-.*(Audit|Lifecycle|Event)'}).Count-eq0}
    # tamper copies
    $t1=Join-Path $temp 't1.db';try{Copy-Item $db $t1 -ErrorAction Stop}catch{};foreach($s in @('-wal','-shm')){if(Test-Path "$db$s"){Copy-Item "$db$s" "$t1$s"}}
    try{[Rap.NativeSqlite]::Execute($t1,"UPDATE WorkflowExceptionAudit SET Payload=(SELECT Payload FROM WorkflowExceptionAudit ORDER BY Id LIMIT 1) WHERE Id=(SELECT MAX(Id) FROM WorkflowExceptionAudit);",5000)}catch{}
    Check 'E3-17' 'in-place operation audit edit is detected' {-not(Test-RapWorkflowAuditChain -DatabasePath $t1).Valid}
    $t2=Join-Path $temp 't2.db';try{Copy-Item $db $t2 -ErrorAction Stop}catch{};foreach($s in @('-wal','-shm')){if(Test-Path "$db$s"){Copy-Item "$db$s" "$t2$s"}}
    try{[Rap.NativeSqlite]::Execute($t2,"UPDATE WorkflowLifecycleEvents SET Payload=(SELECT Payload FROM WorkflowLifecycleEvents ORDER BY Id LIMIT 1) WHERE Id=3;",5000)}catch{}
    Check 'E3-18' 'in-place lifecycle event edit is detected' {-not(Test-RapWorkflowAuditChain -DatabasePath $t2).Valid}
    $t3=Join-Path $temp 't3.db';try{Copy-Item $db $t3 -ErrorAction Stop}catch{};foreach($s in @('-wal','-shm')){if(Test-Path "$db$s"){Copy-Item "$db$s" "$t3$s"}}
    try{[Rap.NativeSqlite]::Execute($t3,"DELETE FROM WorkflowLifecycleEvents WHERE Id=(SELECT MAX(Id) FROM WorkflowLifecycleEvents);",5000)}catch{}
    Check 'E3-19' 'tail deletion of lifecycle events is detected' {-not(Test-RapWorkflowAuditChain -DatabasePath $t3).Valid}
    # failure reason as a general lifecycle field (fault in the atomic commit)
    $fdb=Join-Path $temp 'fault.db';$faulty=$null;try{$faulty=New-RapWorkflowSqliteDependencies -DatabasePath $fdb -FaultPoint AFTER_AUDIT}catch{}
    $msg=Get-ThrownMessage {Invoke-RapWorkflowExceptionOperation -Snapshot $stale -OperationId 'E3-FAIL' -Dependencies $faulty}
    Check 'E3-20' 'failed operation records OPERATION_FAILED with FailureReason and no completed state' {$ev=@(&$faulty.ReadEvents);$msg-match'INJECTED_FAULT:AFTER_AUDIT'-and$ev.Count-eq1-and$ev[0].EventType-eq'OPERATION_FAILED'-and$ev[0].FailureReason-match'INJECTED_FAULT:AFTER_AUDIT'-and$null-eq(&$faulty.GetOperation 'E3-FAIL')-and(Get-RapWorkflowExceptionSnapshot $fdb).AuditCount-eq0}
}finally{Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue}

# ------------------------------------------------------------------ E5 — RISK-SPR011-006 malformed payloads & interruption
$malformed=[ordered]@{}
$x=Copy-RapWorkflowFixture $base;$x.PSObject.Properties.Remove('Pdf');$malformed['missing-field']=@($x,'MALFORMED_SNAPSHOT:.*MISSING:Pdf')
$x=Copy-RapWorkflowFixture $base;$x.VersionState.SourceVersion='two';$malformed['wrong-type']=@($x,'MALFORMED_SNAPSHOT:.*WRONG_TYPE:VersionState.SourceVersion')
$x=Copy-RapWorkflowFixture $base;$x.HumanOwned.Introduction=('x'*300000);$malformed['oversized']=@($x,'MALFORMED_SNAPSHOT:.*OVERSIZED')
$x=Copy-RapWorkflowFixture $base;$x.LibraryId='L1; DROP';$malformed['invalid-library-id']=@($x,'MALFORMED_SNAPSHOT:.*INVALID_ID:LibraryId')
$x=Copy-RapWorkflowFixture $base;$x.ProjectId='../PR001';$malformed['invalid-project-id']=@($x,'MALFORMED_SNAPSHOT:.*INVALID_ID:ProjectId')
$x=Copy-RapWorkflowFixture $base;$x.Dependents[0].Status='WHATEVER';$malformed['invalid-dependent']=@($x,'MALFORMED_SNAPSHOT:.*INVALID_VALUE:Dependents\[0\].Status')
$x=Copy-RapWorkflowFixture $base;$x.Pdf.Exists='yes';$malformed['wrong-bool']=@($x,'MALFORMED_SNAPSHOT:.*WRONG_TYPE:Pdf.Exists')
$i=0;foreach($k in $malformed.Keys){$i++;$s=$malformed[$k][0];$p=$malformed[$k][1];Check ("E5-{0:d2}" -f $i) "malformed payload rejected deterministically with zero mutation [$k]" {
    $m=New-RapMemoryWorkflowDependencies
    $a=Get-ThrownMessage {Invoke-Op $s "MAL-$k" $m};$b=Get-ThrownMessage {Invoke-Op $s "MAL-$k" $m}
    $a-match$p-and$a-eq$b-and$m.Audits.Count-eq0-and$m.Operations.Count-eq0-and@($m.State.Exceptions).Count-eq0}}
Check 'E5-08' 'null snapshot rejected' {$m=New-RapMemoryWorkflowDependencies;Throws {Invoke-RapWorkflowExceptionOperation -Snapshot ([pscustomobject]@{}) -OperationId 'MAL-NULL' -Dependencies $m.Dependencies} 'MALFORMED_SNAPSHOT'}
Check 'E5-09' 'injection-shaped OperationId rejected before any store access' {$m=New-RapMemoryWorkflowDependencies;Throws {Invoke-Op $base "X'; DELETE FROM Operations; --" $m} 'MALFORMED_OPERATION_ID'}
# true interruption across process boundaries: fault → new process inspect → new process complete → new process replay
$powerShell=(Get-Process -Id $PID).Path;$helper=Join-Path $PSScriptRoot 'TurnEFaultRecoveryProcess.ps1'
$j=9;foreach($point in @('AFTER_STATE','AFTER_AUDIT','AFTER_EVENTS','BEFORE_COMMIT')){
    $dir=Join-Path ([IO.Path]::GetTempPath()) "rap-turn-e-fault-$PID-$point";[void][IO.Directory]::CreateDirectory($dir);$fdb=Join-Path $dir 'wf.db'
    try{
        $null=&$powerShell -NoProfile -File $helper -Phase Fault -FaultPoint $point -DatabasePath $fdb 2>&1;$faultExit=$LASTEXITCODE
        $inspect1=(&$powerShell -NoProfile -File $helper -Phase Inspect -DatabasePath $fdb 2>$null|Select-Object -Last 1)|ConvertFrom-Json
        $null=&$powerShell -NoProfile -File $helper -Phase Complete -DatabasePath $fdb 2>&1;$completeExit=$LASTEXITCODE
        $null=&$powerShell -NoProfile -File $helper -Phase Replay -DatabasePath $fdb 2>&1;$replayExit=$LASTEXITCODE
        $inspect2=(&$powerShell -NoProfile -File $helper -Phase Inspect -DatabasePath $fdb 2>$null|Select-Object -Last 1)|ConvertFrom-Json
        $j++;Check ("E5-{0:d2}" -f $j) "interruption $point rolls back fully and records failure (process boundary)" {$faultExit-ne0-and$inspect1.Operations-eq0-and$inspect1.Audits-eq0-and$inspect1.StateRows-eq0-and$inspect1.FailedEvents-eq1-and$inspect1.FailureReason-match"INJECTED_FAULT:$point"-and$inspect1.ChainValid}
        $j++;Check ("E5-{0:d2}" -f $j) "restart after $point completes once without duplicates (process boundary)" {$completeExit-eq0-and$replayExit-eq0-and$inspect2.Operations-eq1-and$inspect2.Audits-eq1-and$inspect2.Exceptions-eq1-and$inspect2.CompletedEvents-eq1-and$inspect2.ChainValid}
    }catch{$j++;Check ("E5-{0:d2}" -f $j) "interruption $point harness" {$false};$j++}
    finally{Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue}
}

# ------------------------------------------------------------------ report
$fail=@($script:Results|Where-Object Result -eq 'FAIL')
foreach($r in $script:Results){Write-Host ("{0,-9} {1,-4} {2}{3}" -f $r.Id,$r.Result,$r.Name,$(if($r.Detail){" :: $($r.Detail)"}else{''}))}
if($ResultPath){$script:Results|ConvertTo-Json -Depth 5|Set-Content -LiteralPath $ResultPath -Encoding utf8}
Write-Host ("SPR-011 Turn-E remediation tests: {0}/{1} PASS; failures: {2}" -f ($script:Results.Count-$fail.Count),$script:Results.Count,$fail.Count)
if($fail.Count){exit 1}
