#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'ResearchAutomation.Workflow.psd1') -Force
. (Join-Path $PSScriptRoot 'TestHarness.ps1')
$script:Assertions=0
$script:Scenarios=0
function Assert-RapRemediation([string]$id,[bool]$condition,[string]$message){$script:Scenarios++;$script:Assertions++;if(!$condition){throw "$id failed: $message"}}
function ThrowsLike([scriptblock]$action,[string]$pattern){try{&$action;$false}catch{$_.Exception.Message-match$pattern}}

$clean=New-RapWorkflowFixture

$stale=Copy-RapWorkflowFixture $clean;$stale.VersionState.SourceVersion=2
$m=New-RapMemoryWorkflowDependencies;$r=Invoke-RapWorkflowExceptionOperation $stale R01 $m.Dependencies
Assert-RapRemediation R01 ($r.Result.SafetyContext.AutoSafeEligible-and$r.Result.Plans[0].ResolutionState-eq'AUTO_SAFE'-and$r.Result.Reconciliations[0].Status-eq'RECONCILED') 'safe STALE did not reconcile'

$broken=Copy-RapWorkflowFixture $stale;$broken.LibraryLinkage.Valid=$false;$broken.LibraryLinkage.LinkedLibraryId='LIB:OTHER'
$m=New-RapMemoryWorkflowDependencies;$rBroken=Invoke-RapWorkflowExceptionOperation $broken R02 $m.Dependencies
Assert-RapRemediation R02 ($rBroken.Result.SafetyContext.CompositeResolution-eq'BLOCKED'-and@($rBroken.Result.Plans|Where-Object ResolutionState -eq AUTO_SAFE).Count-eq0-and@($rBroken.Result.Reconciliations|Where-Object{$_.BeforeHash-ne$_.AfterHash}).Count-eq0) 'broken Library_ID allowed AUTO_SAFE'

$duplicate=Copy-RapWorkflowFixture $stale;$duplicate.Zotero.Registrations=@('ZOT-1','ZOT-2')
$m=New-RapMemoryWorkflowDependencies;$rDuplicate=Invoke-RapWorkflowExceptionOperation $duplicate R03 $m.Dependencies
Assert-RapRemediation R03 ($rDuplicate.Result.SafetyContext.CompositeResolution-eq'HUMAN_REVIEW_REQUIRED'-and@($rDuplicate.Result.Plans|Where-Object ResolutionState -eq AUTO_SAFE).Count-eq0) 'ambiguous duplicate allowed AUTO_SAFE'

$orphan=Copy-RapWorkflowFixture $stale;$orphan.OrphanReferences=@('ORPHAN-IDENTITY-1')
$m=New-RapMemoryWorkflowDependencies;$rOrphan=Invoke-RapWorkflowExceptionOperation $orphan R04 $m.Dependencies
Assert-RapRemediation R04 ($rOrphan.Result.SafetyContext.CompositeResolution-eq'HUMAN_REVIEW_REQUIRED'-and-not$rOrphan.Result.SafetyContext.NoIdentityBlocker) 'orphan identity allowed AUTO_SAFE'

$ownership=Copy-RapWorkflowFixture $stale;$ownership.EditState.AutomationManualConflict=$true;$ownership.EditState.ConflictingFields=@('ReviewerMemo')
$m=New-RapMemoryWorkflowDependencies;$rOwner=Invoke-RapWorkflowExceptionOperation $ownership R05 $m.Dependencies
Assert-RapRemediation R05 ($rOwner.Result.SafetyContext.CompositeResolution-eq'HUMAN_REVIEW_REQUIRED'-and-not$rOwner.Result.SafetyContext.NoHumanOwnedConflict) 'ownership conflict allowed AUTO_SAFE'

$blocked=Copy-RapWorkflowFixture $stale;$blocked.UnknownSignals=@('blocking-signal')
$m=New-RapMemoryWorkflowDependencies;$rBlocked=Invoke-RapWorkflowExceptionOperation $blocked R06 $m.Dependencies
Assert-RapRemediation R06 ($rBlocked.Result.SafetyContext.CompositeResolution-eq'BLOCKED'-and@($rBlocked.Result.Plans|Where-Object ResolutionState -ne BLOCKED).Count-eq0) 'BLOCKED did not win'

$review=Copy-RapWorkflowFixture $stale;$review.Links[0].Reachable=$false
$m=New-RapMemoryWorkflowDependencies;$rReview=Invoke-RapWorkflowExceptionOperation $review R07 $m.Dependencies
Assert-RapRemediation R07 ($rReview.Result.SafetyContext.CompositeResolution-eq'HUMAN_REVIEW_REQUIRED'-and@($rReview.Result.Plans|Where-Object ResolutionState -ne HUMAN_REVIEW_REQUIRED).Count-eq0) 'human review did not win'

$staleException=@(Find-RapWorkflowExceptions $stale)
$twoAuto=@($staleException[0],$staleException[0].PSObject.Copy())
$twoAutoPolicy=Get-RapCompositeResolutionPolicy -Exceptions $twoAuto -Snapshot $stale
Assert-RapRemediation R08 ($twoAutoPolicy.CompositeResolution-eq'AUTO_SAFE'-and$twoAutoPolicy.AutoSafeEligible) 'compatible AUTO_SAFE set rejected'

$unknownContext=[pscustomobject]@{CompositeResolution='AUTO_SAFE';PolicyVersion='test';PolicyHash='test';DecisionReason='unknown'}
Assert-RapRemediation R09 (ThrowsLike {New-RapExceptionResolutionPlan $staleException[0] -SafetyContext $unknownContext} 'AUTO_SAFE_NOT_PERMITTED') 'unknown predicate failed open'

$missing=Copy-RapWorkflowFixture $stale;$missing.PSObject.Properties.Remove('LibraryLinkage')
$missingPolicy=Get-RapCompositeResolutionPolicy -Exceptions $staleException -Snapshot $missing
Assert-RapRemediation R10 ($missingPolicy.PolicyEvaluationFailed-and$missingPolicy.CompositeResolution-eq'BLOCKED'-and-not$missingPolicy.AutoSafeEligible) 'missing identity evidence failed open'

$malformedException=[pscustomobject]@{ExceptionId='EXC-MALFORMED';ExceptionClass='STALE';ProjectId=$stale.ProjectId;LibraryId=$stale.LibraryId}
$errorPolicy=Get-RapCompositeResolutionPolicy -Exceptions @($malformedException) -Snapshot $stale
$errorPlan=New-RapExceptionResolutionPlan $malformedException -SafetyContext $errorPolicy
$errorResult=Invoke-RapExceptionReconciliation $malformedException $errorPlan $stale
Assert-RapRemediation R11 ($errorPolicy.PolicyEvaluationFailed-and$errorPlan.ResolutionState-eq'BLOCKED'-and$errorResult.BeforeHash-eq$errorResult.AfterHash) 'policy evaluation error reconciled'

$brokenUpdates=@($rBroken.Result.Reconciliations.UpdatedSnapshot)
Assert-RapRemediation R12 (@($brokenUpdates|Where-Object{$_.LibraryId-ne$broken.LibraryId-or$_.LibraryLinkage.LinkedLibraryId-ne$broken.LibraryLinkage.LinkedLibraryId}).Count-eq0) 'replacement Library_ID issued'
Assert-RapRemediation R13 (@($rBroken.Result.Plans|Where-Object{-not$_.NoCanonicalSelection-or$_.Actions-contains'SELECT_CANONICAL'}).Count-eq0) 'canonical candidate selected'
Assert-RapRemediation R14 (@($rBroken.Result.Plans|Where-Object{-not$_.NoDelete-or-not$_.NoMerge}).Count-eq0-and@($rBroken.Result.Reconciliations|Where-Object{$_.BeforeHash-ne$_.AfterHash}).Count-eq0) 'destructive downstream rewrite'
Assert-RapRemediation R15 (@($brokenUpdates|Where-Object{($_.ResearcherConfirmed|ConvertTo-Json -Compress)-ne($broken.ResearcherConfirmed|ConvertTo-Json -Compress)}).Count-eq0) 'researcher-confirmed value changed'
Assert-RapRemediation R16 (@($brokenUpdates|Where-Object{($_.HumanOwned|ConvertTo-Json -Compress)-ne($broken.HumanOwned|ConvertTo-Json -Compress)}).Count-eq0) 'HUMAN_OWNED value changed'

$memory=New-RapMemoryWorkflowDependencies;$first=Invoke-RapWorkflowExceptionOperation $stale R17 $memory.Dependencies;$again=Invoke-RapWorkflowExceptionOperation $stale R17 $memory.Dependencies
Assert-RapRemediation R17 ($first.Status-eq'COMPLETED'-and$again.Status-eq'ALREADY_COMPLETED'-and$memory.Audits.Count-eq1) 'same replay not idempotent'
Assert-RapRemediation R18 (ThrowsLike {Invoke-RapWorkflowExceptionOperation $broken R17 $memory.Dependencies} 'PAYLOAD_CONFLICT') 'different payload conflict not rejected'

$resolved=Copy-RapWorkflowFixture $broken;$resolved.LibraryLinkage.Valid=$true;$resolved.LibraryLinkage.LinkedLibraryId=$resolved.LibraryId
$m=New-RapMemoryWorkflowDependencies;$rResolved=Invoke-RapWorkflowExceptionOperation $resolved R19 $m.Dependencies
Assert-RapRemediation R19 ($rResolved.Result.Detected.ExceptionClass-eq'STALE'-and$rResolved.Result.SafetyContext.AutoSafeEligible-and$rResolved.Result.Reconciliations[0].Status-eq'RECONCILED') 'verified identity resolution did not restore eligibility'

$temp=Join-Path ([IO.Path]::GetTempPath()) "rap-workflow-turn-c-$PID-$([guid]::NewGuid().ToString('N'))";[void][IO.Directory]::CreateDirectory($temp)
try{
    $db=Join-Path $temp 'workflow.db';$powerShell=(Get-Process -Id $PID).Path;$recoveryScript=Join-Path $PSScriptRoot 'CompositePolicyRecoveryProcess.ps1'
    &$powerShell -NoProfile -File $recoveryScript -Phase Write -DatabasePath $db
    if($LASTEXITCODE-ne0){throw 'R20 process A failed'}
    &$powerShell -NoProfile -File $recoveryScript -Phase Read -DatabasePath $db
    if($LASTEXITCODE-ne0){throw 'R20 process B failed'}
    $snapshot=Get-RapWorkflowExceptionSnapshot $db
    Assert-RapRemediation R20 ($snapshot.AuditCount-eq2-and$snapshot.Exceptions.Count-ge2-and$snapshot.LastAudit.PolicyVersion-eq'SPR-011-TURN-C-1') 'historical exception/audit trail lost'
}finally{Remove-Item -LiteralPath $temp -Recurse -Force}

if($script:Scenarios-ne20-or$script:Assertions-ne20){throw "Expected 20 scenarios/assertions, got $script:Scenarios/$script:Assertions"}
Write-Host "SPR-011 Turn-C remediation tests: R01-R20 20/20 PASS; assertions: $script:Assertions"
