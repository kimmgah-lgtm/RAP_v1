#Requires -Version 7.0
# SPR-011 Turn E — adversarial attempts against the remediated engine. Expected outcome for every case:
# fail closed, BLOCKED, or HUMAN_REVIEW_REQUIRED; never destructive guessing.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'ResearchAutomation.Workflow.psd1') -Force
. (Join-Path $PSScriptRoot 'TestHarness.ps1')
$script:N=0
function A([string]$Id,[bool]$Condition,[string]$Message){$script:N++;if(!$Condition){throw "$Id failed: $Message"};Write-Host "$Id PASS $Message"}
function Throws([scriptblock]$Action,[string]$Pattern){try{&$Action;return $false}catch{return $_.Exception.Message-match$Pattern}}
function Get-TestHash($Value){[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes(($Value|ConvertTo-Json -Depth 80 -Compress)))).ToLowerInvariant()}
$base=New-RapWorkflowTurnEFixture

# EA-01 masked automation failure disguised as success on an otherwise AUTO_SAFE entity
$x=Copy-RapWorkflowFixture $base;$x.VersionState.SourceVersion=2;$x.AutomationRuns=@([pscustomobject]@{RunId='RUN-OK';ExitCode=0;Status='SUCCEEDED';ErrorEvidence=@()},[pscustomobject]@{RunId='RUN-MASK';ExitCode=0;Status='SUCCEEDED';ErrorEvidence=@('Exception: script terminated')})
$m=New-RapMemoryWorkflowDependencies;$r=Invoke-RapWorkflowExceptionOperation $x 'EA-01' $m.Dependencies
A 'EA-01' ($r.Result.SafetyContext.CompositeResolution-eq'BLOCKED'-and@($r.Result.Reconciliations|Where-Object{$_.BeforeHash-ne$_.AfterHash}).Count-eq0) 'masked success cannot unlock AUTO_SAFE'

# EA-02 PDF replaced + researcher-confirmed coding conflict on the same paper
$x=Copy-RapWorkflowFixture $base;$x.Pdf.CurrentHash='replaced';$x.CodingState.AiResearcherConflict=$true;$x.CodingState.ConflictingFields=@('Outcome');$x.CodingState.AiSuggestions=@([pscustomobject]@{Field='Outcome';Value='AI';ModelId='m';ModelVersion='v';RunId='r'})
$m=New-RapMemoryWorkflowDependencies;$r=Invoke-RapWorkflowExceptionOperation $x 'EA-02' $m.Dependencies
A 'EA-02' ($r.Result.SafetyContext.CompositeResolution-eq'HUMAN_REVIEW_REQUIRED'-and@($r.Result.Reconciliations|Where-Object{(Get-TestHash $_.UpdatedSnapshot.ResearcherConfirmed)-ne(Get-TestHash $x.ResearcherConfirmed)}).Count-eq0-and@($r.Result.DownstreamImpact|Where-Object EffectiveStatus -eq 'CURRENT').Count-eq0) 'combined PDF change and coding conflict keeps researcher value and invalidates dependents'

# EA-03 dependent record lies: recorded CURRENT but lineage basis is stale
$x=Copy-RapWorkflowFixture $base;$x.VersionState.SourceVersion=5;$x.VersionState.DerivedVersion=5
A 'EA-03' ((Test-RapDependentOperationPermitted -Snapshot $x -ArtifactId 'SYNTH-1' -Operation 'CONSUME').Permitted-eq$false) 'recorded CURRENT is not trusted over lineage evidence'

# EA-04..07 forged human decisions
$m=New-RapMemoryWorkflowDependencies;$dup=Copy-RapWorkflowFixture $base;$dup.Zotero.Registrations=@('A','B');$r=Invoke-RapWorkflowExceptionOperation $dup 'EA-DUP' $m.Dependencies;$caseId=$r.Result.Detected[0].ExceptionId
A 'EA-04' (Throws {Submit-RapHumanReviewDecision -ExceptionId $caseId -Decision KEEP_BLOCKED -Actor 'researcher:kim' -ActorType AUTOMATION -Rationale 'x' -DecisionId 'F1' -Dependencies $m.Dependencies} 'AUTOMATION_CANNOT_DECIDE') 'automation actor type rejected'
A 'EA-05' (Throws {Submit-RapHumanReviewDecision -ExceptionId $caseId -Decision KEEP_BLOCKED -Actor 'RAP-AUTOMATION:engine' -ActorType RESEARCHER -Rationale 'x' -DecisionId 'F2' -Dependencies $m.Dependencies} 'AUTOMATION_CANNOT_DECIDE') 'case-varied automation identity rejected'
A 'EA-06' (Throws {Submit-RapHumanReviewDecision -ExceptionId $caseId -Decision KEEP_BLOCKED -Actor 'researcher:kim' -ActorType researcher -Rationale 'x' -DecisionId 'F3' -Dependencies $m.Dependencies} 'AUTOMATION_CANNOT_DECIDE') 'non-canonical actor type rejected'
A 'EA-07' (Throws {Submit-RapHumanReviewDecision -ExceptionId $caseId -Decision MERGE -Actor 'researcher:kim' -ActorType RESEARCHER -Rationale 'x' -DecisionId 'F4' -Dependencies $m.Dependencies} 'INVALID_DECISION') 'destructive decision vocabulary rejected'
A 'EA-08' (@($m.Events|Where-Object EventType -eq 'HUMAN_REVIEW_DECISION').Count-eq0) 'no forged decision reached the lifecycle store'

# EA-09 researcher decision does not bypass validation when the same problem is observed again
$broken=Copy-RapWorkflowFixture $base;$broken.VersionState.SourceVersion=2;$broken.LibraryLinkage.Valid=$false;$broken.LibraryLinkage.LinkedLibraryId='LIB:AMBIGUOUS'
$m=New-RapMemoryWorkflowDependencies;$r=Invoke-RapWorkflowExceptionOperation $broken 'EA-09-A' $m.Dependencies;$blocked=@($r.Result.Detected|Where-Object ExceptionClass -eq 'LIBRARY_ID_LINKAGE_BROKEN')[0].ExceptionId
$null=Submit-RapHumanReviewDecision -ExceptionId $blocked -Decision ACCEPT_WITH_JUSTIFICATION -Actor 'researcher:kim' -ActorType RESEARCHER -Rationale 'Known legacy link.' -DecisionId 'EA-09' -Dependencies $m.Dependencies
$again=Copy-RapWorkflowFixture $broken;$again.NotionReview.PageId='NOTION-1b'
$r2=Invoke-RapWorkflowExceptionOperation $again 'EA-09-B' $m.Dependencies
A 'EA-09' ($r2.Result.SafetyContext.CompositeResolution-eq'BLOCKED'-and@($r2.Result.Reconciliations|Where-Object{$_.BeforeHash-ne$_.AfterHash}).Count-eq0-and(@($m.State.CaseStatus|Where-Object ExceptionId -eq $blocked)[0].Status-eq'BLOCKED')) 're-observed identity blocker reopens the case and stays BLOCKED'

# EA-10 appended forged event without chain head update
$temp=Join-Path ([IO.Path]::GetTempPath()) "rap-turn-e-adv-$PID";[void][IO.Directory]::CreateDirectory($temp)
try{
    $db=Join-Path $temp 'wf.db';$sql=New-RapWorkflowSqliteDependencies -DatabasePath $db -AuthorizedResearchers @('researcher:kim')
    $stale=Copy-RapWorkflowFixture $base;$stale.VersionState.SourceVersion=2;$null=Invoke-RapWorkflowExceptionOperation $stale 'EA-10' $sql
    $forged=[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('{"EventType":"FINAL_RESOLUTION","ExceptionId":"EXC-X"}'))
    [Rap.NativeSqlite]::Execute($sql.DatabasePath,"INSERT INTO WorkflowLifecycleEvents(EventType,ExceptionId,Payload,PrevHash,RowHash) VALUES('FINAL_RESOLUTION','EXC-X','$forged','forged-prev','forged-row');",5000)
    A 'EA-10' (-not(Test-RapWorkflowAuditChain -DatabasePath $db).Valid) 'appended forged event detected'
    # EA-11 operation audit row deleted
    $db2=Join-Path $temp 'wf2.db';$sql2=New-RapWorkflowSqliteDependencies -DatabasePath $db2;$null=Invoke-RapWorkflowExceptionOperation $stale 'EA-11' $sql2
    [Rap.NativeSqlite]::Execute($sql2.DatabasePath,'DELETE FROM WorkflowExceptionAudit;',5000)
    A 'EA-11' (-not(Test-RapWorkflowAuditChain -DatabasePath $db2).Valid) 'deleted operation audit row detected'
}finally{Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue}

# EA-12..16 malformed payload permutations
$cases=[ordered]@{}
$x=Copy-RapWorkflowFixture $base;$x.Links='not-an-array';$cases['EA-12']=@($x,'WRONG_TYPE:Links')
$x=Copy-RapWorkflowFixture $base;$x.AutomationRuns[0].ExitCode='0';$cases['EA-13']=@($x,'WRONG_TYPE:AutomationRuns\[0\].ExitCode')
$x=Copy-RapWorkflowFixture $base;$x.Dependents[1].ArtifactId='REVIEW-EV-1';$cases['EA-14']=@($x,'DUPLICATE_ID:Dependents\[1\].ArtifactId')
$x=Copy-RapWorkflowFixture $base;$x.Dependents[0].Requires=@('PDF','TELEPATHY');$cases['EA-15']=@($x,'INVALID_VALUE:Dependents\[0\].Requires')
$x=Copy-RapWorkflowFixture $base;$x.VersionState.DerivedVersion=-1;$cases['EA-16']=@($x,'WRONG_TYPE:VersionState.DerivedVersion')
foreach($k in $cases.Keys){$m=New-RapMemoryWorkflowDependencies;$snap=$cases[$k][0];$pattern=$cases[$k][1];A $k ((Throws {Invoke-RapWorkflowExceptionOperation $snap $k $m.Dependencies} "MALFORMED_SNAPSHOT:.*$pattern")-and$m.Audits.Count-eq0) "malformed payload permutation rejected ($pattern)"}

# EA-17 exception order permutation across Turn-E classes
$x=Copy-RapWorkflowFixture $base;$x.VersionState.SourceVersion=2;$x.Pdf.CurrentHash='replaced';$x.CodingState.AiResearcherConflict=$true;$x.CodingState.ConflictingFields=@('Outcome');$x.AutomationRuns=@([pscustomobject]@{RunId='R';ExitCode=2;Status='FAILED';ErrorEvidence=@()})
$ex=@(Find-RapWorkflowExceptions $x);$raw=ConvertTo-RapNormalizedException -RawException ([pscustomobject]@{ExceptionClass='mystery'}) -Snapshot $x;$all=@($ex)+@($raw)
$p1=Get-RapCompositeResolutionPolicy $all $x;$p2=Get-RapCompositeResolutionPolicy @($all|Sort-Object ExceptionClass -Descending) $x;$p3=Get-RapCompositeResolutionPolicy @($all[2],$all[0],$all[4],$all[1],$all[3]) $x
A 'EA-17' ($p1.PolicyHash-eq$p2.PolicyHash-and$p2.PolicyHash-eq$p3.PolicyHash-and$p1.CompositeResolution-eq'BLOCKED') 'order permutation of new classes gives identical BLOCKED policy'

# EA-18 lineage order permutation
$y=Copy-RapWorkflowFixture $x;$y.Dependents=@($y.Dependents[3],$y.Dependents[1],$y.Dependents[0],$y.Dependents[2])
A 'EA-18' ((Get-TestHash @(Get-RapDownstreamImpact -Snapshot $x))-eq(Get-TestHash @(Get-RapDownstreamImpact -Snapshot $y))) 'dependent order permutation gives identical impact'

# EA-19 unsupported class smuggled with a permissive default into an operation result path
$forged=[pscustomobject]@{ExceptionId='EXC-SMUGGLED';ExceptionClass='STALE ';DefaultResolution='AUTO_SAFE';Evidence=[pscustomobject]@{};ProjectId='PR001';LibraryId='LIB:L000001'}
$stale=Copy-RapWorkflowFixture $base;$stale.VersionState.SourceVersion=2
$policy=Get-RapCompositeResolutionPolicy (@(Find-RapWorkflowExceptions $stale)+@($forged)) $stale
A 'EA-19' ($policy.CompositeResolution-eq'BLOCKED'-and(Throws {New-RapExceptionResolutionPlan $forged -SafetyContext $policy -RequestedState AUTO_SAFE} 'AUTO_SAFE_NOT_PERMITTED')) 'whitespace-padded class cannot borrow STALE AUTO_SAFE'

# EA-20 interrupted decision commit leaves the case awaiting review
$m=New-RapMemoryWorkflowDependencies;$r=Invoke-RapWorkflowExceptionOperation $dup 'EA-20' $m.Dependencies;$case=$r.Result.Detected[0].ExceptionId
$failing=[pscustomobject]@{GetOperation=$m.Dependencies.GetOperation;ReadState=$m.Dependencies.ReadState;CommitWorkflow={param($s,$o,$a,$e)throw 'INJECTED_DECISION_FAILURE'};AuthorizedResearchers=@('researcher:kim')}
$threw=Throws {Submit-RapHumanReviewDecision -ExceptionId $case -Decision KEEP_BLOCKED -Actor 'researcher:kim' -ActorType RESEARCHER -Rationale 'x' -DecisionId 'EA-20' -Dependencies $failing} 'INJECTED_DECISION_FAILURE'
A 'EA-20' ($threw-and(@($m.State.CaseStatus|Where-Object ExceptionId -eq $case)[0].Status-eq'HUMAN_REVIEW_REQUIRED')-and$null-eq(&$m.Dependencies.GetOperation 'DECISION:EA-20')) 'failed decision commit does not resolve the case'

if($script:N-ne20){throw "Expected 20 assertions, got $script:N"}
Write-Host "SPR-011 Turn-E adversarial tests: 20/20 cases PASS; assertions: $script:N"
