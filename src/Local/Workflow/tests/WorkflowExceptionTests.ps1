#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'ResearchAutomation.Workflow.psd1') -Force
. (Join-Path $PSScriptRoot 'TestHarness.ps1')
$script:Assertions=0
function A([bool]$condition,[string]$message){$script:Assertions++;if(!$condition){throw "Assertion $script:Assertions failed: $message"}}
function T([scriptblock]$action,[string]$pattern,[string]$message){$script:Assertions++;$actual=$null;try{&$action}catch{$actual=$_.Exception.Message};if($actual-notmatch$pattern){throw "Assertion $script:Assertions failed: $message actual=$actual"}}

# Taxonomy and clean baseline.
$taxonomy=@(Get-RapExceptionTaxonomy)
$required=@('ZOTERO_SOURCE_DELETED','DUPLICATE_BIBLIOGRAPHIC_REGISTRATION','NOTION_REVIEW_MISSING','MANUALLY_CREATED_NOTION_REVIEW','LIBRARY_ID_LINKAGE_BROKEN','PDF_MISSING_OR_REPLACED','PROJECT_LINKAGE_INCONSISTENCY','AUTOMATION_MANUAL_EDIT_CONFLICT','AI_ASSISTED_RESEARCHER_CONFIRMED_CONFLICT','ORPHAN','STALE','BROKEN_LINK','UNKNOWN_EXCEPTION','AUTOMATION_FAILURE')
A ($taxonomy.Count-eq14) 'taxonomy count'
A (@($required|Where-Object{$taxonomy.ExceptionClass-notcontains$_}).Count-eq0) 'taxonomy completeness'
A (@($taxonomy.DefaultResolution|Sort-Object -Unique|Where-Object{$_-notin@('AUTO_SAFE','HUMAN_REVIEW_REQUIRED','BLOCKED')}).Count-eq0) 'taxonomy states'
$clean=New-RapWorkflowFixture
A (@(Find-RapWorkflowExceptions $clean).Count-eq0) 'clean state detected exception'

# One deterministic detector assertion for every required class.
$cases=[ordered]@{}
$x=Copy-RapWorkflowFixture $clean;$x.Zotero.Exists=$false;$cases.ZOTERO_SOURCE_DELETED=$x
$x=Copy-RapWorkflowFixture $clean;$x.Zotero.Registrations=@('ZOT-1','ZOT-2');$cases.DUPLICATE_BIBLIOGRAPHIC_REGISTRATION=$x
$x=Copy-RapWorkflowFixture $clean;$x.NotionReview.Exists=$false;$cases.NOTION_REVIEW_MISSING=$x
$x=Copy-RapWorkflowFixture $clean;$x.NotionReview.CreationSource='MANUAL';$x.NotionReview.Registered=$false;$cases.MANUALLY_CREATED_NOTION_REVIEW=$x
$x=Copy-RapWorkflowFixture $clean;$x.LibraryLinkage.Valid=$false;$x.LibraryLinkage.LinkedLibraryId='LIB:OTHER';$cases.LIBRARY_ID_LINKAGE_BROKEN=$x
$x=Copy-RapWorkflowFixture $clean;$x.Pdf.CurrentHash='replaced';$cases.PDF_MISSING_OR_REPLACED=$x
$x=Copy-RapWorkflowFixture $clean;$x.ProjectLinkage.Valid=$false;$x.ProjectLinkage.LinkedProjectId='PR002';$cases.PROJECT_LINKAGE_INCONSISTENCY=$x
$x=Copy-RapWorkflowFixture $clean;$x.EditState.AutomationManualConflict=$true;$x.EditState.ConflictingFields=@('Title');$cases.AUTOMATION_MANUAL_EDIT_CONFLICT=$x
$x=Copy-RapWorkflowFixture $clean;$x.CodingState.AiResearcherConflict=$true;$x.CodingState.ConflictingFields=@('Outcome');$cases.AI_ASSISTED_RESEARCHER_CONFIRMED_CONFLICT=$x
$x=Copy-RapWorkflowFixture $clean;$x.OrphanReferences=@('ORPHAN-1');$cases.ORPHAN=$x
$x=Copy-RapWorkflowFixture $clean;$x.VersionState.SourceVersion=2;$cases.STALE=$x
$x=Copy-RapWorkflowFixture $clean;$x.Links[0].Reachable=$false;$cases.BROKEN_LINK=$x
$x=Copy-RapWorkflowFixture $clean;$x.UnknownSignals=@('fixture-unknown');$cases.UNKNOWN_EXCEPTION=$x
foreach($entry in $cases.GetEnumerator()){$detected=@(Find-RapWorkflowExceptions $entry.Value);A ($detected.ExceptionClass-contains$entry.Key) "detector $($entry.Key)";A (($detected|Where-Object ExceptionClass -eq $entry.Key).ExceptionId-like'EXC-*') "identity $($entry.Key)"}
$repeatA=Find-RapWorkflowExceptions $cases.STALE;$repeatB=Find-RapWorkflowExceptions $cases.STALE
A ($repeatA.ExceptionId-eq$repeatB.ExceptionId) 'exception identity deterministic'
A ($repeatA.SnapshotHash-eq$repeatB.SnapshotHash) 'snapshot hash deterministic'

# Planner and safety invariants.
$staleException=(Find-RapWorkflowExceptions $cases.STALE|Where-Object ExceptionClass -eq STALE)
$staleContext=Get-RapCompositeResolutionPolicy -Exceptions @($staleException) -Snapshot $cases.STALE
$stalePlan=New-RapExceptionResolutionPlan $staleException -SafetyContext $staleContext
A ($stalePlan.ResolutionState-eq'AUTO_SAFE') 'stale not auto safe'
A ($stalePlan.Actions.Count-eq1-and$stalePlan.Actions[0]-eq'REFRESH_LOCAL_DERIVED_STATE') 'unsafe stale action'
$deleted=(Find-RapWorkflowExceptions $cases.ZOTERO_SOURCE_DELETED|Where-Object ExceptionClass -eq ZOTERO_SOURCE_DELETED)
A ((New-RapExceptionResolutionPlan $deleted).ResolutionState-eq'BLOCKED') 'deleted source not blocked'
$duplicate=(Find-RapWorkflowExceptions $cases.DUPLICATE_BIBLIOGRAPHIC_REGISTRATION|Where-Object ExceptionClass -eq DUPLICATE_BIBLIOGRAPHIC_REGISTRATION)
A ((New-RapExceptionResolutionPlan $duplicate).ResolutionState-eq'HUMAN_REVIEW_REQUIRED') 'duplicate not review'
T {New-RapExceptionResolutionPlan $duplicate -RequestedState AUTO_SAFE} 'AUTO_SAFE_NOT_PERMITTED' 'unsafe escalation'
T {New-RapExceptionResolutionPlan $duplicate -RequestedState IGNORE_WITH_JUSTIFICATION} 'IGNORE_JUSTIFICATION_REQUIRED' 'ignore without reason'
$ignored=New-RapExceptionResolutionPlan $duplicate -RequestedState IGNORE_WITH_JUSTIFICATION -Justification 'Known imported duplicate retained for audit.'
A ($ignored.ResolutionState-eq'IGNORE_WITH_JUSTIFICATION'-and$ignored.Justification) 'justified ignore'
foreach($plan in @($stalePlan,(New-RapExceptionResolutionPlan $deleted),(New-RapExceptionResolutionPlan $duplicate),$ignored)){A ($plan.NoDelete-and$plan.NoMerge-and$plan.NoCanonicalSelection-and$plan.ProductionWrite-eq'DISABLED') 'plan safety flags'}

# Reconciliation and verification preserve authoritative state.
$reconciliation=Invoke-RapExceptionReconciliation $staleException $stalePlan $cases.STALE
$verification=Test-RapExceptionResolution $staleException $stalePlan $reconciliation $cases.STALE
A ($reconciliation.Status-eq'RECONCILED') 'stale not reconciled'
A ($reconciliation.UpdatedSnapshot.VersionState.DerivedVersion-eq2) 'derived version not refreshed'
A ($reconciliation.UpdatedSnapshot.LibraryId-eq$cases.STALE.LibraryId) 'Library ID changed'
A (($reconciliation.UpdatedSnapshot.HumanOwned|ConvertTo-Json -Compress)-eq($cases.STALE.HumanOwned|ConvertTo-Json -Compress)) 'human content changed'
A (($reconciliation.UpdatedSnapshot.ResearcherConfirmed|ConvertTo-Json -Compress)-eq($cases.STALE.ResearcherConfirmed|ConvertTo-Json -Compress)) 'confirmed coding changed'
A ($verification.Valid-and$verification.Status-eq'VERIFIED') 'reconciliation verification'
$reviewPlan=New-RapExceptionResolutionPlan $duplicate
$reviewResult=Invoke-RapExceptionReconciliation $duplicate $reviewPlan $cases.DUPLICATE_BIBLIOGRAPHIC_REGISTRATION
A ($reviewResult.Status-eq'HUMAN_REVIEW_REQUIRED'-and$reviewResult.BeforeHash-eq$reviewResult.AfterHash) 'review state mutated'
A ((Test-RapExceptionResolution $duplicate $reviewPlan $reviewResult $cases.DUPLICATE_BIBLIOGRAPHIC_REGISTRATION).Valid) 'review preservation verification'

# Registry, idempotency, payload conflict, persistence, and semantic audit.
$memory=New-RapMemoryWorkflowDependencies
$first=Invoke-RapWorkflowExceptionOperation $cases.STALE WF-1 $memory.Dependencies
$again=Invoke-RapWorkflowExceptionOperation $cases.STALE WF-1 $memory.Dependencies
A ($first.Status-eq'COMPLETED'-and$again.Status-eq'ALREADY_COMPLETED') 'operation replay'
A ($memory.State.Exceptions.Count-eq1-and$memory.Audits.Count-eq1) 'registry/audit duplicate'
T {Invoke-RapWorkflowExceptionOperation $cases.BROKEN_LINK WF-1 $memory.Dependencies} 'PAYLOAD_CONFLICT' 'operation conflict'
$temp=Join-Path ([IO.Path]::GetTempPath()) "rap-workflow-$PID-$([guid]::NewGuid().ToString('N'))";[void][IO.Directory]::CreateDirectory($temp)
try{
    $db=Join-Path $temp workflow.db;$sqlite=New-RapWorkflowSqliteDependencies $db
    $null=Invoke-RapWorkflowExceptionOperation $cases.STALE WF-SQL $sqlite
    $snapshot=Get-RapWorkflowExceptionSnapshot $db
    A ($snapshot.Exceptions[0].ExceptionClass-eq'STALE') 'registry reload'
    A ($snapshot.Plans[0].ResolutionState-eq'AUTO_SAFE') 'plan reload'
    A ($snapshot.Reconciliations[0].Status-eq'RECONCILED') 'reconciliation reload'
    A ($snapshot.Verifications[0].Status-eq'VERIFIED') 'verification reload'
    A ($snapshot.AuditCount-eq1-and$snapshot.LastAudit.OperationId-eq'WF-SQL') 'audit reload'
    A ($snapshot.LastAudit.DeleteCount-eq0-and$snapshot.LastAudit.MergeCount-eq0-and$snapshot.LastAudit.CanonicalSelectionCount-eq0) 'destructive audit counts'
    A ($snapshot.LastAudit.HumanOwnedWriteCount-eq0-and$snapshot.LastAudit.ResearcherConfirmedWriteCount-eq0-and$snapshot.LastAudit.ProductionWrite-eq'DISABLED') 'ownership audit counts'
    A ($null-ne(&$sqlite.GetOperation 'WF-SQL')) 'operation ledger reload'
}finally{Remove-Item -LiteralPath $temp -Recurse -Force}

# Production-safety configuration.
$config=Get-Content -LiteralPath (Join-Path $root '../ResearchAutomation.Local/config/config.json') -Raw|ConvertFrom-Json
A ($config.capabilities.ProductionAIProvider-eq$false) 'production AI'
A ($config.capabilities.ProductionZoteroWrite-eq$false) 'production Zotero'
A ($config.capabilities.ProductionDriveMigration-eq$false) 'production Drive'
A ($config.capabilities.ProductionNotionWrite-eq$false) 'production Notion'
A ($config.capabilities.SynthesisProductionWrite-eq$false-and$config.capabilities.OutputProductionWrite-eq$false) 'upstream production writes'
A ($config.capabilities.WorkflowExceptionsProductionWrite-eq$false) 'workflow production write'
A (-not$config.writeLayer.enabled-and[string]::IsNullOrEmpty($config.googleDrive.folderId)) 'external tests deferred'

Write-Host "SPR-011 workflow exception core tests: PASS; assertions: $script:Assertions"
