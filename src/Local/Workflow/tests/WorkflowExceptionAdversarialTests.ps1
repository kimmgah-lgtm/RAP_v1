#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'ResearchAutomation.Workflow.psd1') -Force
. (Join-Path $PSScriptRoot 'TestHarness.ps1')
$script:N=0
function A([bool]$condition,[string]$message){$script:N++;if(!$condition){throw "Assertion $script:N failed: $message"}}
function T([scriptblock]$action,[string]$pattern,[string]$message){$script:N++;$actual=$null;try{&$action}catch{$actual=$_.Exception.Message};if($actual-notmatch$pattern){throw "Assertion $script:N failed: $message actual=$actual"}}

$clean=New-RapWorkflowFixture
$compound=Copy-RapWorkflowFixture $clean;$compound.Zotero.Exists=$false;$compound.Pdf.Exists=$false;$compound.LibraryLinkage.Valid=$false
$compoundDetected=@(Find-RapWorkflowExceptions $compound)
A (@($compoundDetected.ExceptionClass|Where-Object{$_-in@('ZOTERO_SOURCE_DELETED','PDF_MISSING_OR_REPLACED','LIBRARY_ID_LINKAGE_BROKEN')}).Count-eq3) 'compound failures collapsed'
A (@($compoundDetected|Where-Object DefaultResolution -eq BLOCKED).Count-eq2) 'blocking classification wrong'

$duplicate=Copy-RapWorkflowFixture $clean;$duplicate.Zotero.Registrations=@('A','B')
$duplicateException=Find-RapWorkflowExceptions $duplicate
T {New-RapExceptionResolutionPlan $duplicateException -RequestedState AUTO_SAFE} 'AUTO_SAFE_NOT_PERMITTED' 'duplicate auto merged'
$duplicatePlan=New-RapExceptionResolutionPlan $duplicateException
$duplicateResult=Invoke-RapExceptionReconciliation $duplicateException $duplicatePlan $duplicate
A ($duplicateResult.BeforeHash-eq$duplicateResult.AfterHash-and$duplicateResult.Actions[0]-eq'NONE') 'review-required state mutated'

$stale=Copy-RapWorkflowFixture $clean;$stale.VersionState.SourceVersion=7;$staleException=Find-RapWorkflowExceptions $stale;$staleContext=Get-RapCompositeResolutionPolicy -Exceptions @($staleException) -Snapshot $stale;$stalePlan=New-RapExceptionResolutionPlan $staleException -SafetyContext $staleContext
$staleResult=Invoke-RapExceptionReconciliation $staleException $stalePlan $stale
$tamperedHuman=Copy-RapWorkflowFixture $staleResult.UpdatedSnapshot;$tamperedHuman.HumanOwned.Introduction='Automation overwrite';$staleResultHuman=$staleResult.PSObject.Copy();$staleResultHuman.UpdatedSnapshot=$tamperedHuman
A (-not(Test-RapExceptionResolution $staleException $stalePlan $staleResultHuman $stale).Valid) 'HUMAN_OWNED tamper verified'
$tamperedCoding=Copy-RapWorkflowFixture $staleResult.UpdatedSnapshot;$tamperedCoding.ResearcherConfirmed.Outcome='AI-OUT';$staleResultCoding=$staleResult.PSObject.Copy();$staleResultCoding.UpdatedSnapshot=$tamperedCoding
A (-not(Test-RapExceptionResolution $staleException $stalePlan $staleResultCoding $stale).Valid) 'confirmed coding tamper verified'
$tamperedId=Copy-RapWorkflowFixture $staleResult.UpdatedSnapshot;$tamperedId.LibraryId='LIB:CHANGED';$staleResultId=$staleResult.PSObject.Copy();$staleResultId.UpdatedSnapshot=$tamperedId
A (-not(Test-RapExceptionResolution $staleException $stalePlan $staleResultId $stale).Valid) 'Library_ID tamper verified'

$unknown=Copy-RapWorkflowFixture $clean;$unknown.UnknownSignals=@('unexpected-fixture')
$unknownException=Find-RapWorkflowExceptions $unknown
A ($unknownException.ExceptionClass-eq'UNKNOWN_EXCEPTION'-and$unknownException.DefaultResolution-eq'BLOCKED') 'unknown not blocked'

$links=Copy-RapWorkflowFixture $clean;$links.Links=@([pscustomobject]@{LinkId='L1';Target='x';Reachable=$false},[pscustomobject]@{LinkId='L2';Target='y';Reachable=$false})
$broken=@(Find-RapWorkflowExceptions $links|Where-Object ExceptionClass -eq BROKEN_LINK)
A ($broken.Count-eq2-and@($broken.ExceptionId|Sort-Object -Unique).Count-eq2) 'broken links lost identity'

$memory=New-RapMemoryWorkflowDependencies
$null=Invoke-RapWorkflowExceptionOperation $stale ADV-1 $memory.Dependencies
$null=Invoke-RapWorkflowExceptionOperation $stale ADV-2 $memory.Dependencies
A ($memory.State.Exceptions.Count-eq1) 'registry duplicated same exception across operations'
A ($memory.State.Plans.Count-eq2-and$memory.Audits.Count-eq2) 'operation history not preserved'
A ($memory.Audits[0].DeleteCount-eq0-and$memory.Audits[0].MergeCount-eq0-and$memory.Audits[0].CanonicalSelectionCount-eq0) 'destructive audit action'

$failed=[pscustomobject]@{Committed=$false}
$dependencies=[pscustomobject]@{GetOperation={param($id)$null};ReadState={[pscustomobject]@{Exceptions=@();Plans=@();Reconciliations=@();Verifications=@()}};CommitWorkflow={param($state,$operation,$audit)throw 'INJECTED_ATOMIC_FAILURE'}}
T {Invoke-RapWorkflowExceptionOperation $stale ADV-FAIL $dependencies} 'INJECTED_ATOMIC_FAILURE' 'commit failure hidden'
A (-not$failed.Committed) 'partial commit marked complete'

T {New-RapExceptionResolutionPlan $unknownException -RequestedState IGNORE_WITH_JUSTIFICATION -Justification ''} 'IGNORE_JUSTIFICATION_REQUIRED' 'blank ignore accepted'
$unknownContext=Get-RapCompositeResolutionPolicy -Exceptions @($unknownException) -Snapshot $unknown
$ignore=New-RapExceptionResolutionPlan $unknownException -RequestedState IGNORE_WITH_JUSTIFICATION -Justification 'Authorized researcher documented fixture exception.' -SafetyContext $unknownContext -AuthorizedResearcher
A ($ignore.ResolutionState-eq'IGNORE_WITH_JUSTIFICATION'-and$ignore.ProductionWrite-eq'DISABLED') 'justified ignore unsafe'

if($script:N-ne16){throw "Expected 16 assertions, got $script:N"}
Write-Host "SPR-011 workflow exception adversarial tests: 16/16 PASS; assertions: $script:N"
