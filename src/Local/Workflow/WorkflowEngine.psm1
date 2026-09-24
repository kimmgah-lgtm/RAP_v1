Set-StrictMode -Version Latest

$script:RapExceptionTaxonomy = @(
    [pscustomobject]@{ ExceptionClass='ZOTERO_SOURCE_DELETED'; DefaultResolution='BLOCKED'; Severity='P1'; Component='ZOTERO' },
    [pscustomobject]@{ ExceptionClass='DUPLICATE_BIBLIOGRAPHIC_REGISTRATION'; DefaultResolution='HUMAN_REVIEW_REQUIRED'; Severity='P1'; Component='BIBLIOGRAPHY' },
    [pscustomobject]@{ ExceptionClass='NOTION_REVIEW_MISSING'; DefaultResolution='HUMAN_REVIEW_REQUIRED'; Severity='P2'; Component='NOTION_REVIEW' },
    [pscustomobject]@{ ExceptionClass='MANUALLY_CREATED_NOTION_REVIEW'; DefaultResolution='HUMAN_REVIEW_REQUIRED'; Severity='P2'; Component='NOTION_REVIEW' },
    [pscustomobject]@{ ExceptionClass='LIBRARY_ID_LINKAGE_BROKEN'; DefaultResolution='BLOCKED'; Severity='P1'; Component='IDENTITY' },
    [pscustomobject]@{ ExceptionClass='PDF_MISSING_OR_REPLACED'; DefaultResolution='HUMAN_REVIEW_REQUIRED'; Severity='P1'; Component='PDF' },
    [pscustomobject]@{ ExceptionClass='PROJECT_LINKAGE_INCONSISTENCY'; DefaultResolution='HUMAN_REVIEW_REQUIRED'; Severity='P1'; Component='PROJECT' },
    [pscustomobject]@{ ExceptionClass='AUTOMATION_MANUAL_EDIT_CONFLICT'; DefaultResolution='HUMAN_REVIEW_REQUIRED'; Severity='P1'; Component='EDIT_OWNERSHIP' },
    [pscustomobject]@{ ExceptionClass='AI_ASSISTED_RESEARCHER_CONFIRMED_CONFLICT'; DefaultResolution='HUMAN_REVIEW_REQUIRED'; Severity='P1'; Component='META_CODING' },
    [pscustomobject]@{ ExceptionClass='ORPHAN'; DefaultResolution='HUMAN_REVIEW_REQUIRED'; Severity='P2'; Component='LINKAGE' },
    [pscustomobject]@{ ExceptionClass='STALE'; DefaultResolution='AUTO_SAFE'; Severity='P2'; Component='DERIVED_STATE' },
    [pscustomobject]@{ ExceptionClass='BROKEN_LINK'; DefaultResolution='HUMAN_REVIEW_REQUIRED'; Severity='P1'; Component='LINKAGE' },
    [pscustomobject]@{ ExceptionClass='UNKNOWN_EXCEPTION'; DefaultResolution='BLOCKED'; Severity='P1'; Component='UNKNOWN' }
)
$script:RapResolutionStates = @('AUTO_SAFE','HUMAN_REVIEW_REQUIRED','BLOCKED','IGNORE_WITH_JUSTIFICATION')
$script:RapForbiddenActions = @('DELETE','MERGE','SELECT_CANONICAL','OVERWRITE_HUMAN_OWNED','OVERWRITE_RESEARCHER_CONFIRMED','PRODUCTION_WRITE')
$script:RapWorkflowPolicyVersion = 'SPR-011-TURN-C-1'

function ConvertTo-RapWorkflowCanonical {
    param($Value)
    if ($null -eq $Value) { return $null }
    if ($Value -is [Collections.IDictionary]) {
        $result=[ordered]@{}; foreach($key in @($Value.Keys|ForEach-Object{[string]$_}|Sort-Object)){$result[$key]=ConvertTo-RapWorkflowCanonical $Value[$key]}; return $result
    }
    if ($Value -is [Management.Automation.PSCustomObject]) {
        $result=[ordered]@{}; foreach($property in @($Value.PSObject.Properties|Sort-Object Name)){$result[$property.Name]=ConvertTo-RapWorkflowCanonical $property.Value}; return $result
    }
    if ($Value -is [Collections.IEnumerable] -and $Value -isnot [string]) { return @($Value|ForEach-Object{ConvertTo-RapWorkflowCanonical $_}) }
    return $Value
}

function Get-RapWorkflowHash {
    param($Value)
    $json=(ConvertTo-RapWorkflowCanonical $Value)|ConvertTo-Json -Depth 80 -Compress
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($json))).ToLowerInvariant()
}

function Copy-RapWorkflowValue {
    param($Value)
    $Value | ConvertTo-Json -Depth 80 | ConvertFrom-Json -Depth 80
}

function Get-RapExceptionTaxonomy {
    [CmdletBinding()]param()
    return @($script:RapExceptionTaxonomy | ForEach-Object { $_.PSObject.Copy() })
}

function New-RapDetectedException {
    param([string]$Class,$Snapshot,[string]$Component,$Evidence)
    $taxonomy=$script:RapExceptionTaxonomy|Where-Object ExceptionClass -eq $Class|Select-Object -First 1
    if(-not $taxonomy){throw "UNKNOWN_EXCEPTION_CLASS:$Class"}
    $identity=[ordered]@{ExceptionClass=$Class;ProjectId=$Snapshot.ProjectId;LibraryId=$Snapshot.LibraryId;Component=$Component;Evidence=$Evidence}
    $hash=Get-RapWorkflowHash $identity
    [pscustomobject]@{
        ExceptionId="EXC-$($hash.Substring(0,24))";Fingerprint=$hash;ExceptionClass=$Class
        ProjectId=$Snapshot.ProjectId;LibraryId=$Snapshot.LibraryId;Component=$Component
        Severity=$taxonomy.Severity;DefaultResolution=$taxonomy.DefaultResolution;Evidence=$Evidence
        SnapshotHash=Get-RapWorkflowHash $Snapshot;Status='OPEN';DetectedAt=[DateTimeOffset]::UtcNow.ToString('o')
        ProductionWrite='DISABLED'
    }
}

function Find-RapWorkflowExceptions {
    [CmdletBinding()]param([Parameter(Mandatory)]$Snapshot)
    if([string]::IsNullOrWhiteSpace([string]$Snapshot.ProjectId)-or[string]::IsNullOrWhiteSpace([string]$Snapshot.LibraryId)){throw 'WORKFLOW_CONTEXT_REQUIRED'}
    $found=[Collections.Generic.List[object]]::new()
    if(-not $Snapshot.Zotero.Exists){$found.Add((New-RapDetectedException ZOTERO_SOURCE_DELETED $Snapshot ZOTERO ([pscustomobject]@{SourceKey=$Snapshot.Zotero.SourceKey;Observed='MISSING'})))}
    if(@($Snapshot.Zotero.Registrations).Count -gt 1){$found.Add((New-RapDetectedException DUPLICATE_BIBLIOGRAPHIC_REGISTRATION $Snapshot BIBLIOGRAPHY ([pscustomobject]@{RegistrationIds=@($Snapshot.Zotero.Registrations)})))}
    if(-not $Snapshot.NotionReview.Exists){$found.Add((New-RapDetectedException NOTION_REVIEW_MISSING $Snapshot NOTION_REVIEW ([pscustomobject]@{ExpectedLibraryId=$Snapshot.LibraryId})))}
    elseif($Snapshot.NotionReview.CreationSource -eq 'MANUAL' -and -not $Snapshot.NotionReview.Registered){$found.Add((New-RapDetectedException MANUALLY_CREATED_NOTION_REVIEW $Snapshot NOTION_REVIEW ([pscustomobject]@{PageId=$Snapshot.NotionReview.PageId;CreationSource='MANUAL'})))}
    if(-not $Snapshot.LibraryLinkage.Valid -or $Snapshot.LibraryLinkage.LinkedLibraryId -ne $Snapshot.LibraryId){$found.Add((New-RapDetectedException LIBRARY_ID_LINKAGE_BROKEN $Snapshot IDENTITY ([pscustomobject]@{Expected=$Snapshot.LibraryId;Actual=$Snapshot.LibraryLinkage.LinkedLibraryId})))}
    if(-not $Snapshot.Pdf.Exists -or $Snapshot.Pdf.ExpectedHash -ne $Snapshot.Pdf.CurrentHash){$found.Add((New-RapDetectedException PDF_MISSING_OR_REPLACED $Snapshot PDF ([pscustomobject]@{Exists=$Snapshot.Pdf.Exists;ExpectedHash=$Snapshot.Pdf.ExpectedHash;CurrentHash=$Snapshot.Pdf.CurrentHash})))}
    if(-not $Snapshot.ProjectLinkage.Valid){$found.Add((New-RapDetectedException PROJECT_LINKAGE_INCONSISTENCY $Snapshot PROJECT ([pscustomobject]@{ExpectedProjectId=$Snapshot.ProjectId;LinkedProjectId=$Snapshot.ProjectLinkage.LinkedProjectId})))}
    if($Snapshot.EditState.AutomationManualConflict){$found.Add((New-RapDetectedException AUTOMATION_MANUAL_EDIT_CONFLICT $Snapshot EDIT_OWNERSHIP ([pscustomobject]@{Fields=@($Snapshot.EditState.ConflictingFields)})))}
    if($Snapshot.CodingState.AiResearcherConflict){$found.Add((New-RapDetectedException AI_ASSISTED_RESEARCHER_CONFIRMED_CONFLICT $Snapshot META_CODING ([pscustomobject]@{Fields=@($Snapshot.CodingState.ConflictingFields)})))}
    if(@($Snapshot.OrphanReferences).Count -gt 0){$found.Add((New-RapDetectedException ORPHAN $Snapshot LINKAGE ([pscustomobject]@{References=@($Snapshot.OrphanReferences)})))}
    if([int64]$Snapshot.VersionState.SourceVersion -gt [int64]$Snapshot.VersionState.DerivedVersion){$found.Add((New-RapDetectedException STALE $Snapshot DERIVED_STATE ([pscustomobject]@{SourceVersion=$Snapshot.VersionState.SourceVersion;DerivedVersion=$Snapshot.VersionState.DerivedVersion})))}
    foreach($link in @($Snapshot.Links|Where-Object{-not $_.Reachable})){$found.Add((New-RapDetectedException BROKEN_LINK $Snapshot LINKAGE ([pscustomobject]@{LinkId=$link.LinkId;Target=$link.Target})))}
    foreach($signal in @($Snapshot.UnknownSignals)){$found.Add((New-RapDetectedException UNKNOWN_EXCEPTION $Snapshot UNKNOWN ([pscustomobject]@{Signal=[string]$signal})))}
    return @($found|Sort-Object ExceptionClass,ExceptionId)
}

function Get-RapCompositeResolutionPolicy {
    [CmdletBinding()]param([Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Exceptions,[Parameter(Mandatory)]$Snapshot)
    $classes=@($Exceptions|ForEach-Object{if($_.PSObject.Properties['ExceptionClass']){$_.ExceptionClass}}|Where-Object{$_}|Sort-Object -Unique)
    $ids=@($Exceptions|ForEach-Object{if($_.PSObject.Properties['ExceptionId']){$_.ExceptionId}}|Where-Object{$_}|Sort-Object -Unique)
    $requiredSnapshotProperties=@('ProjectId','LibraryId','LibraryLinkage','ProjectLinkage','HumanOwned','ResearcherConfirmed','VersionState')
    $missing=[Collections.Generic.List[string]]::new()
    if($null-eq$Snapshot){$missing.Add('Snapshot')}
    else{
        foreach($name in $requiredSnapshotProperties){if(-not$Snapshot.PSObject.Properties[$name]){$missing.Add($name)}}
        if($Snapshot.PSObject.Properties['ProjectId']-and[string]::IsNullOrWhiteSpace([string]$Snapshot.ProjectId)){$missing.Add('ProjectId.Value')}
        if($Snapshot.PSObject.Properties['LibraryId']-and[string]::IsNullOrWhiteSpace([string]$Snapshot.LibraryId)){$missing.Add('LibraryId.Value')}
        if($Snapshot.PSObject.Properties['LibraryLinkage']){
            if($null-eq$Snapshot.LibraryLinkage){$missing.Add('LibraryLinkage.Value')}
            else{foreach($name in @('Valid','LinkedLibraryId')){if(-not$Snapshot.LibraryLinkage.PSObject.Properties[$name]){$missing.Add("LibraryLinkage.$name")}}}
        }
        if($Snapshot.PSObject.Properties['ProjectLinkage']){
            if($null-eq$Snapshot.ProjectLinkage){$missing.Add('ProjectLinkage.Value')}
            else{foreach($name in @('Valid','LinkedProjectId')){if(-not$Snapshot.ProjectLinkage.PSObject.Properties[$name]){$missing.Add("ProjectLinkage.$name")}}}
        }
        if($Snapshot.PSObject.Properties['VersionState']){
            if($null-eq$Snapshot.VersionState){$missing.Add('VersionState.Value')}
            else{foreach($name in @('SourceVersion','DerivedVersion')){if(-not$Snapshot.VersionState.PSObject.Properties[$name]){$missing.Add("VersionState.$name")}}}
        }
        if($Snapshot.PSObject.Properties['HumanOwned']-and$null-eq$Snapshot.HumanOwned){$missing.Add('HumanOwned.Value')}
        if($Snapshot.PSObject.Properties['ResearcherConfirmed']-and$null-eq$Snapshot.ResearcherConfirmed){$missing.Add('ResearcherConfirmed.Value')}
    }
    foreach($exception in $Exceptions){foreach($name in @('ExceptionId','ExceptionClass','DefaultResolution','Evidence')){if(-not$exception.PSObject.Properties[$name]){$missing.Add("Exception.$name")}}}

    $identityBlockerClasses=@(
        'LIBRARY_ID_LINKAGE_BROKEN','DUPLICATE_BIBLIOGRAPHIC_REGISTRATION','MANUALLY_CREATED_NOTION_REVIEW',
        'PROJECT_LINKAGE_INCONSISTENCY','ORPHAN','ZOTERO_SOURCE_DELETED','UNKNOWN_EXCEPTION'
    )
    $humanConflictClasses=@('AUTOMATION_MANUAL_EDIT_CONFLICT','AI_ASSISTED_RESEARCHER_CONFIRMED_CONFLICT')
    $lineageBlockerClasses=@('BROKEN_LINK','PDF_MISSING_OR_REPLACED','PROJECT_LINKAGE_INCONSISTENCY','ORPHAN','ZOTERO_SOURCE_DELETED','UNKNOWN_EXCEPTION')
    $hasIdentityBlocker=@($classes|Where-Object{$identityBlockerClasses-contains$_}).Count-gt0
    $hasHumanConflict=@($classes|Where-Object{$humanConflictClasses-contains$_}).Count-gt0
    $hasLineageBlocker=@($classes|Where-Object{$lineageBlockerClasses-contains$_}).Count-gt0
    $defaultStates=@($Exceptions|ForEach-Object{if($_.PSObject.Properties['DefaultResolution']){$_.DefaultResolution}})
    $hasBlocked=$defaultStates-contains'BLOCKED'
    $hasHumanReview=$defaultStates-contains'HUMAN_REVIEW_REQUIRED'
    $policyError=$missing.Count-gt0-or@($defaultStates|Where-Object{$_-notin@('AUTO_SAFE','HUMAN_REVIEW_REQUIRED','BLOCKED')}).Count-gt0

    $identityUnambiguous=-not$hasIdentityBlocker-and-not$policyError
    $canonicalResolved=$identityUnambiguous
    $noIdentityBlocker=-not$hasIdentityBlocker-and-not$policyError
    $noHumanOwnedConflict=-not$hasHumanConflict-and-not$policyError
    $noResearcherConflict=-not($classes-contains'AI_ASSISTED_RESEARCHER_CONFIRMED_CONFLICT')-and-not$policyError
    $operationNonDestructive=-not$policyError
    $operationIdempotent=-not$policyError
    $verificationAvailable=-not$policyError
    $requiredLineageValid=-not$hasLineageBlocker-and-not$policyError
    $noHigherPriority=-not$hasBlocked-and-not$hasHumanReview-and-not$hasIdentityBlocker-and-not$hasHumanConflict-and-not$hasLineageBlocker-and-not$policyError
    $autoSafeEligible=$Exceptions.Count-gt0-and$identityUnambiguous-and$canonicalResolved-and$noIdentityBlocker-and$noHumanOwnedConflict-and$noResearcherConflict-and$operationNonDestructive-and$operationIdempotent-and$verificationAvailable-and$requiredLineageValid-and$noHigherPriority-and@($defaultStates|Where-Object{$_-ne'AUTO_SAFE'}).Count-eq0
    $resolution=if($policyError-or$hasBlocked){'BLOCKED'}elseif($hasHumanReview-or$hasIdentityBlocker-or$hasHumanConflict-or$hasLineageBlocker){'HUMAN_REVIEW_REQUIRED'}elseif($autoSafeEligible){'AUTO_SAFE'}else{'BLOCKED'}
    $reason=if($policyError){"POLICY_EVIDENCE_MISSING:$(@($missing|Sort-Object -Unique)-join',')"}elseif($hasBlocked){'BLOCKING_EXCEPTION_ACTIVE'}elseif($hasIdentityBlocker){'IDENTITY_BLOCKER_ACTIVE'}elseif($hasHumanConflict){'HUMAN_JUDGMENT_REQUIRED'}elseif($hasHumanReview-or$hasLineageBlocker){'HIGHER_PRIORITY_EXCEPTION_ACTIVE'}elseif($autoSafeEligible){'ALL_AUTO_SAFE_PREDICATES_VERIFIED'}else{'AUTO_SAFE_NOT_PROVEN'}
    $body=[ordered]@{PolicyVersion=$script:RapWorkflowPolicyVersion;ActiveExceptionIds=$ids;ActiveExceptionClasses=$classes;Resolution=$resolution;Reason=$reason;MissingEvidence=@($missing|Sort-Object -Unique)}
    [pscustomobject]@{
        PolicyVersion=$script:RapWorkflowPolicyVersion;PolicyHash=Get-RapWorkflowHash $body
        ActiveExceptionIds=$ids;ActiveExceptionClasses=$classes;CompositeResolution=$resolution;DecisionReason=$reason
        IdentityUnambiguous=$identityUnambiguous;CanonicalEntityResolved=$canonicalResolved;NoIdentityBlocker=$noIdentityBlocker
        NoHumanOwnedConflict=$noHumanOwnedConflict;NoResearcherConfirmedConflict=$noResearcherConflict
        OperationNonDestructive=$operationNonDestructive;OperationIdempotent=$operationIdempotent
        VerificationAvailable=$verificationAvailable;RequiredLineageValid=$requiredLineageValid;NoHigherPriorityException=$noHigherPriority
        AutoSafeEligible=$autoSafeEligible;PolicyEvaluationFailed=$policyError;MissingEvidence=@($missing|Sort-Object -Unique)
    }
}

function Test-RapAutoSafePolicyContext {
    param($SafetyContext)
    if($null-eq$SafetyContext){return $false}
    foreach($name in @('IdentityUnambiguous','CanonicalEntityResolved','NoIdentityBlocker','NoHumanOwnedConflict','NoResearcherConfirmedConflict','OperationNonDestructive','OperationIdempotent','VerificationAvailable','RequiredLineageValid','NoHigherPriorityException','AutoSafeEligible')){
        if(-not$SafetyContext.PSObject.Properties[$name]-or$SafetyContext.$name-ne$true){return $false}
    }
    return $SafetyContext.PolicyEvaluationFailed-ne$true
}

function New-RapExceptionResolutionPlan {
    [CmdletBinding()]param([Parameter(Mandatory)]$Exception,[string]$RequestedState,[string]$Justification,$SafetyContext,[switch]$AuthorizedResearcher)
    $state=if($RequestedState){$RequestedState}elseif($SafetyContext){$SafetyContext.CompositeResolution}elseif($Exception.DefaultResolution-eq'AUTO_SAFE'){'BLOCKED'}else{$Exception.DefaultResolution}
    if($script:RapResolutionStates -notcontains $state){throw 'INVALID_RESOLUTION_STATE'}
    if($state -eq 'IGNORE_WITH_JUSTIFICATION' -and [string]::IsNullOrWhiteSpace($Justification)){throw 'IGNORE_JUSTIFICATION_REQUIRED'}
    if($state-eq'IGNORE_WITH_JUSTIFICATION'-and$SafetyContext-and$SafetyContext.NoIdentityBlocker-ne$true-and-not$AuthorizedResearcher){throw 'IDENTITY_BLOCKER_REQUIRES_AUTHORIZED_RESEARCHER'}
    if($state-eq'AUTO_SAFE'-and($Exception.DefaultResolution-ne'AUTO_SAFE'-or-not(Test-RapAutoSafePolicyContext $SafetyContext))){throw 'AUTO_SAFE_NOT_PERMITTED'}
    $actions=if($state-eq'AUTO_SAFE'-and$Exception.ExceptionClass-eq'STALE'){@('REFRESH_LOCAL_DERIVED_STATE')}else{@('PRESERVE_STATE','REQUEST_REVIEW')}
    if(@($actions|Where-Object{$script:RapForbiddenActions-contains$_}).Count){throw 'UNSAFE_RESOLUTION_ACTION'}
    $policyVersion=if($SafetyContext){$SafetyContext.PolicyVersion}else{$script:RapWorkflowPolicyVersion}
    $policyHash=if($SafetyContext){$SafetyContext.PolicyHash}else{$null}
    $decisionReason=if($SafetyContext){$SafetyContext.DecisionReason}else{'NO_COMPOSITE_CONTEXT_FAIL_CLOSED'}
    $body=[ordered]@{ExceptionId=$Exception.ExceptionId;ResolutionState=$state;Actions=@($actions);Justification=$Justification;PolicyVersion=$policyVersion;PolicyHash=$policyHash}
    $hash=Get-RapWorkflowHash $body
    [pscustomobject]@{PlanId="PLAN-$($hash.Substring(0,24))";ExceptionId=$Exception.ExceptionId;ExceptionClass=$Exception.ExceptionClass;ProjectId=$Exception.ProjectId;LibraryId=$Exception.LibraryId;ResolutionState=$state;Actions=@($actions);Justification=$Justification;PlanHash=$hash;Status='PLANNED';NoDelete=$true;NoMerge=$true;NoCanonicalSelection=$true;ProductionWrite='DISABLED';PolicyVersion=$policyVersion;PolicyHash=$policyHash;PolicyDecisionReason=$decisionReason}
}

function Invoke-RapExceptionReconciliation {
    [CmdletBinding()]param([Parameter(Mandatory)]$Exception,[Parameter(Mandatory)]$Plan,[Parameter(Mandatory)]$Snapshot)
    $before=Get-RapWorkflowHash $Snapshot
    if($Plan.ResolutionState -ne 'AUTO_SAFE'){
        return [pscustomobject]@{ExceptionId=$Exception.ExceptionId;PlanId=$Plan.PlanId;Status=$Plan.ResolutionState;Actions=@('NONE');BeforeHash=$before;AfterHash=$before;UpdatedSnapshot=Copy-RapWorkflowValue $Snapshot;ProductionWrite='DISABLED'}
    }
    if($Exception.ExceptionClass -ne 'STALE'){throw 'AUTO_SAFE_RECONCILIATION_UNSUPPORTED'}
    $updated=Copy-RapWorkflowValue $Snapshot
    $updated.VersionState.DerivedVersion=$updated.VersionState.SourceVersion
    [pscustomobject]@{ExceptionId=$Exception.ExceptionId;PlanId=$Plan.PlanId;Status='RECONCILED';Actions=@('REFRESH_LOCAL_DERIVED_STATE');BeforeHash=$before;AfterHash=Get-RapWorkflowHash $updated;UpdatedSnapshot=$updated;ProductionWrite='DISABLED'}
}

function Test-RapExceptionResolution {
    [CmdletBinding()]param([Parameter(Mandatory)]$Exception,[Parameter(Mandatory)]$Plan,[Parameter(Mandatory)]$Reconciliation,[Parameter(Mandatory)]$OriginalSnapshot)
    $errors=[Collections.Generic.List[string]]::new()
    $updated=$Reconciliation.UpdatedSnapshot
    if($updated.LibraryId-ne$OriginalSnapshot.LibraryId){$errors.Add('LIBRARY_ID_CHANGED')}
    if((Get-RapWorkflowHash $updated.HumanOwned)-ne(Get-RapWorkflowHash $OriginalSnapshot.HumanOwned)){$errors.Add('HUMAN_OWNED_CHANGED')}
    if((Get-RapWorkflowHash $updated.ResearcherConfirmed)-ne(Get-RapWorkflowHash $OriginalSnapshot.ResearcherConfirmed)){$errors.Add('RESEARCHER_CONFIRMED_CHANGED')}
    if(@($Reconciliation.Actions|Where-Object{$script:RapForbiddenActions-contains$_}).Count){$errors.Add('FORBIDDEN_ACTION')}
    if($Plan.ResolutionState-eq'AUTO_SAFE'){
        $remaining=@(Find-RapWorkflowExceptions $updated|Where-Object ExceptionClass -eq $Exception.ExceptionClass)
        if($remaining.Count){$errors.Add('EXCEPTION_NOT_RESOLVED')}
    }elseif($Reconciliation.AfterHash-ne$Reconciliation.BeforeHash){$errors.Add('NON_AUTO_STATE_MUTATED')}
    [pscustomobject]@{ExceptionId=$Exception.ExceptionId;PlanId=$Plan.PlanId;Valid=$errors.Count-eq0;Status=$(if($errors.Count){'FAILED'}else{'VERIFIED'});Errors=@($errors);VerifiedAt=[DateTimeOffset]::UtcNow.ToString('o')}
}

function Invoke-RapWorkflowExceptionOperation {
    [CmdletBinding()]param([Parameter(Mandatory)]$Snapshot,[Parameter(Mandatory)][string]$OperationId,[Parameter(Mandatory)]$Dependencies,[ValidateSet('Fixture')][string]$Mode='Fixture')
    foreach($name in @('GetOperation','ReadState','CommitWorkflow')){if($Dependencies.$name-isnot[scriptblock]){throw "WORKFLOW_DEPENDENCY_REQUIRED:$name"}}
    $payloadHash=Get-RapWorkflowHash $Snapshot
    $existing=&$Dependencies.GetOperation $OperationId
    if($existing-and$existing.PayloadHash-ne$payloadHash){throw 'PAYLOAD_CONFLICT'}
    if($existing-and$existing.State-eq'COMPLETED'){return [pscustomobject]@{Status='ALREADY_COMPLETED';Result=$existing.Result;ProductionWrite='DISABLED'}}
    $detected=@(Find-RapWorkflowExceptions $Snapshot)
    $safetyContext=Get-RapCompositeResolutionPolicy -Exceptions $detected -Snapshot $Snapshot
    $plans=[Collections.Generic.List[object]]::new();$reconciliations=[Collections.Generic.List[object]]::new();$verifications=[Collections.Generic.List[object]]::new()
    foreach($exception in $detected){$plan=New-RapExceptionResolutionPlan $exception -SafetyContext $safetyContext;$plans.Add($plan);$reconciliation=Invoke-RapExceptionReconciliation $exception $plan $Snapshot;$reconciliations.Add($reconciliation);$verifications.Add((Test-RapExceptionResolution $exception $plan $reconciliation $Snapshot))}
    $current=&$Dependencies.ReadState
    $registered=@($current.Exceptions)
    foreach($exception in $detected){if(-not@($registered|Where-Object ExceptionId -eq $exception.ExceptionId)){$registered+=@($exception)}}
    $state=[pscustomobject]@{Exceptions=@($registered);Plans=@($current.Plans)+@($plans);Reconciliations=@($current.Reconciliations)+@($reconciliations);Verifications=@($current.Verifications)+@($verifications)}
    $result=[pscustomobject]@{OperationId=$OperationId;Detected=@($detected);Plans=@($plans);Reconciliations=@($reconciliations);Verifications=@($verifications);SafetyContext=$safetyContext;Status='COMPLETED';ProductionWrite='DISABLED'}
    $operation=[pscustomobject]@{OperationId=$OperationId;PayloadHash=$payloadHash;State='COMPLETED';Result=$result}
    $audit=[pscustomobject]@{OperationId=$OperationId;ProjectId=$Snapshot.ProjectId;LibraryId=$Snapshot.LibraryId;DetectedExceptionIds=@($detected.ExceptionId);ResolutionStates=@($plans.ResolutionState);VerificationStatuses=@($verifications.Status);PolicyVersion=$safetyContext.PolicyVersion;PolicyHash=$safetyContext.PolicyHash;PolicyDecision=$safetyContext.CompositeResolution;PolicyDecisionReason=$safetyContext.DecisionReason;DeleteCount=0;MergeCount=0;CanonicalSelectionCount=0;HumanOwnedWriteCount=0;ResearcherConfirmedWriteCount=0;ProductionWrite='DISABLED';Status='COMPLETED';Timestamp=[DateTimeOffset]::UtcNow.ToString('o')}
    &$Dependencies.CommitWorkflow $state $operation $audit
    [pscustomobject]@{Status='COMPLETED';Result=$result;ProductionWrite='DISABLED'}
}

Export-ModuleMember -Function Get-RapExceptionTaxonomy,Find-RapWorkflowExceptions,Get-RapCompositeResolutionPolicy,New-RapExceptionResolutionPlan,Invoke-RapExceptionReconciliation,Test-RapExceptionResolution,Invoke-RapWorkflowExceptionOperation
