#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'ResearchAutomation.Workflow.psd1') -Force
. (Join-Path $PSScriptRoot 'TestHarness.ps1')
$script:Assertions=0
function A([bool]$condition,[string]$message){$script:Assertions++;if(!$condition){throw "Assertion $script:Assertions failed: $message"}}

$clean=New-RapWorkflowFixture
$compound=Copy-RapWorkflowFixture $clean;$compound.VersionState.SourceVersion=999;$compound.LibraryLinkage.Valid=$false;$compound.LibraryLinkage.LinkedLibraryId='MISLEADING-CANDIDATE'
$detected=@(Find-RapWorkflowExceptions $compound);$policy=Get-RapCompositeResolutionPolicy $detected $compound
A ($policy.CompositeResolution-eq'BLOCKED') 'A identity blocker did not win'
A (-not$policy.AutoSafeEligible-and-not$policy.NoIdentityBlocker) 'A safety predicates weakened'

$forward=Get-RapCompositeResolutionPolicy $detected $compound
$reverse=Get-RapCompositeResolutionPolicy @($detected|Sort-Object ExceptionClass -Descending) $compound
A ($forward.CompositeResolution-eq$reverse.CompositeResolution) 'B order changed resolution'
A ($forward.PolicyHash-eq$reverse.PolicyHash) 'B order changed policy hash'

$duplicatePolicy=Get-RapCompositeResolutionPolicy @($detected+$detected) $compound
A ($duplicatePolicy.CompositeResolution-eq$forward.CompositeResolution) 'C duplicate exception weakened policy'
A ($duplicatePolicy.PolicyHash-eq$forward.PolicyHash) 'C duplicate exception changed deterministic hash'

$unknown=Copy-RapWorkflowFixture $clean;$unknown.VersionState.SourceVersion=2;$unknown.UnknownSignals=@('unclassified')
$unknownDetected=@(Find-RapWorkflowExceptions $unknown);$unknownPolicy=Get-RapCompositeResolutionPolicy $unknownDetected $unknown
A ($unknownPolicy.CompositeResolution-eq'BLOCKED') 'D unknown exception failed open'
A (-not$unknownPolicy.AutoSafeEligible) 'D unknown exception allowed AUTO_SAFE'

$malformed=Copy-RapWorkflowFixture $clean;$malformed.VersionState.SourceVersion=2;$malformed.LibraryLinkage=[pscustomobject]@{Valid=$true}
$staleException=@(Find-RapWorkflowExceptions (Copy-RapWorkflowFixture $unknown)|Where-Object ExceptionClass -eq STALE)
$malformedPolicy=Get-RapCompositeResolutionPolicy $staleException $malformed
A ($malformedPolicy.PolicyEvaluationFailed) 'E malformed identity evidence not detected'
A ($malformedPolicy.CompositeResolution-eq'BLOCKED') 'E malformed identity evidence failed open'

$memory=New-RapMemoryWorkflowDependencies
$stale=Copy-RapWorkflowFixture $clean;$stale.VersionState.SourceVersion=2
$first=Invoke-RapWorkflowExceptionOperation $stale 'ADV-F-1' $memory.Dependencies
$newBlocker=Copy-RapWorkflowFixture $clean;$newBlocker.LibraryLinkage.Valid=$false;$newBlocker.LibraryLinkage.LinkedLibraryId='LIB:NEW-AMBIGUITY'
$second=Invoke-RapWorkflowExceptionOperation $newBlocker 'ADV-F-2' $memory.Dependencies
A ($first.Result.SafetyContext.CompositeResolution-eq'AUTO_SAFE'-and$second.Result.SafetyContext.CompositeResolution-eq'BLOCKED') 'F new blocker left entity trusted'
A ($memory.State.Exceptions.ExceptionClass-contains'LIBRARY_ID_LINKAGE_BROKEN'-and$memory.Audits.Count-eq2) 'F blocker/audit history missing'

$missingReview=Copy-RapWorkflowFixture $stale;$missingReview.NotionReview.Exists=$false
$missingPolicy=Get-RapCompositeResolutionPolicy @(Find-RapWorkflowExceptions $missingReview) $missingReview
A ($missingPolicy.CompositeResolution-eq'HUMAN_REVIEW_REQUIRED') 'G missing record weakened STALE policy'

$manualRecord=Copy-RapWorkflowFixture $stale;$manualRecord.NotionReview.CreationSource='MANUAL';$manualRecord.NotionReview.Registered=$false
$manualPolicy=Get-RapCompositeResolutionPolicy @(Find-RapWorkflowExceptions $manualRecord) $manualRecord
A ($manualPolicy.CompositeResolution-eq'HUMAN_REVIEW_REQUIRED'-and-not$manualPolicy.NoIdentityBlocker) 'H manual ambiguous record weakened STALE policy'

$automationFailure=[pscustomobject]@{ExceptionId='EXC-AUTOMATION-FAILURE';ExceptionClass='AUTOMATION_FAILURE';DefaultResolution='BLOCKED';Evidence=[pscustomobject]@{Failure='injected'};ProjectId=$stale.ProjectId;LibraryId=$stale.LibraryId}
$automationPolicy=Get-RapCompositeResolutionPolicy @($staleException[0],$automationFailure) $stale
A ($automationPolicy.CompositeResolution-eq'BLOCKED'-and-not$automationPolicy.AutoSafeEligible) 'I automation failure weakened STALE policy'

if($script:Assertions-ne15){throw "Expected 15 assertions, got $script:Assertions"}
Write-Host "SPR-011 Turn-C composite adversarial policy tests: 9/9 cases PASS; assertions: $script:Assertions"
