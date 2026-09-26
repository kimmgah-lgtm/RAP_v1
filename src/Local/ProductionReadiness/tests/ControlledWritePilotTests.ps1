. (Join-Path $PSScriptRoot 'TestHarness.ps1')
$script:N=0
function A([string]$id,[bool]$ok,[string]$message){$script:N++;if(!$ok){throw "$id failed: $message"};Write-Host "$id PASS $message"}
function E([scriptblock]$script){try{&$script;$null}catch{$_.Exception.Message}}
$script:TempRoot=Join-Path ([IO.Path]::GetTempPath()) ('rap-cw-focused-'+[guid]::NewGuid())
[void](New-Item -ItemType Directory -Path $script:TempRoot)
$script:DbPath=Join-Path $script:TempRoot 'controlled-write.db'
function P([string]$operationId,[object]$before='draft',[object]$proposed='reviewed',[hashtable]$override=@{}){
    $parameters=@{OperationId=$operationId;LibraryId='LIB:L000003';ProjectId='';TargetSystem='Notion';TargetObject='page-L000003';TargetObjectType='MetadataRecord';TargetField='RAP_Status';Action='UPDATE';BatchCount=1;BeforeValue=$before;ProposedValue=$proposed;Reason='SPR-014 controlled fixture validation';Ownership='RAP_OWNED';ExpectedVersion='7';IdentityStatus='MATCHED';CanonicalLibraryIdPresent=$true;IdentityAmbiguous=$false;PdfIdentityVerified=$true;OwnershipConflict=$false;StaleState=$false;RollbackInfo='Restore RAP_Status to its before value using the audit record.';DatabasePath=$script:DbPath}
    foreach($key in $override.Keys){$parameters[$key]=$override[$key]}
    New-RapControlledWritePlan @parameters
}
function ApproveTestPlan($plan){$request=New-RapControlledWriteApprovalRequest $plan;Approve-RapControlledWritePlan $plan $request 'fixture-human-reviewer' HUMAN 'SPR-014 fixture approval'}
function Adapter($plan,$approval,[hashtable]$fields=@{RAP_Status='draft'},[int]$version=7,[hashtable]$extra=@{}){$parameters=@{Plan=$plan;Approval=$approval;InitialFields=$fields;Version=$version};foreach($key in $extra.Keys){$parameters[$key]=$extra[$key]};New-RapControlledWriteFixtureAdapter @parameters}
try{
    $plan=P CW01;$approval=ApproveTestPlan $plan;$adapter=Adapter $plan $approval;$result=Invoke-RapControlledWritePilot $plan $approval $adapter
    $state=Get-RapControlledWriteFixtureState $adapter
    A CW01 ($result.Status-eq'VERIFIED'-and$result.Verification-eq'PASS'-and$state.Fields.RAP_Status-eq'reviewed'-and$state.MutationCount-eq1-and$result.Audit.ReadBackVerified-and($result.StateHistory-join'>')-eq'PLANNED>AWAITING_APPROVAL>APPROVED>APPLYING>APPLIED>VERIFIED') 'approved single mutation is read back, verified, audited, and persisted'

    $plan=P CW02;$request=New-RapControlledWriteApprovalRequest $plan
    $noApproval=(E {Invoke-RapControlledWritePilot $plan $null ([pscustomobject]@{})})-match'HUMAN_APPROVAL_REQUIRED'
    $selfApproval=(E {Approve-RapControlledWritePlan $plan $request 'rap-ai-agent' AI 'automation self approval'})-match'SELF_APPROVAL_BLOCKED'
    A CW02 ($noApproval-and$selfApproval) 'missing or automated self-approval blocks apply'

    A CW03 ((E {P CW03 'draft' 'reviewed' @{IdentityStatus='AMBIGUOUS';IdentityAmbiguous=$true}})-match'IDENTITY_INELIGIBLE') 'ambiguous identity is ineligible'
    A CW04 ((E {P CW04 'draft' 'reviewed' @{Ownership='HUMAN_OWNED'}})-match'PROTECTED_OWNERSHIP') 'HUMAN_OWNED is protected'
    A CW05 ((E {P CW05 'draft' 'reviewed' @{Ownership='ResearcherConfirmed'}})-match'PROTECTED_OWNERSHIP') 'ResearcherConfirmed is protected'

    $plan=P CW06;$approval=ApproveTestPlan $plan;$adapter=Adapter $plan $approval @{RAP_Status='changed-after-plan'} 7
    A CW06 ((E {Invoke-RapControlledWritePilot $plan $approval $adapter})-match'STALE_CONTROLLED_WRITE_PLAN'-and(Get-RapControlledWriteFixtureState $adapter).MutationCount-eq0) 'before-state mismatch blocks stale plan'

    $plan=P CW07;$approval=ApproveTestPlan $plan;$adapter=Adapter $plan $approval;$plan.ProposedValue='tampered'
    A CW07 ((E {Invoke-RapControlledWritePilot $plan $approval $adapter})-match'PLAN_TAMPERED'-and(Get-RapControlledWriteFixtureState $adapter).MutationCount-eq0) 'payload change invalidates approval and plan'

    $plan=P CW08;$approval=ApproveTestPlan $plan;$adapter=Adapter $plan $approval;$null=Invoke-RapControlledWritePilot $plan $approval $adapter;$again=Invoke-RapControlledWritePilot $plan $approval $adapter
    A CW08 ($again.Status-eq'ALREADY_COMPLETED'-and!$again.ChangesApplied-and(Get-RapControlledWriteFixtureState $adapter).MutationCount-eq1) 'duplicate execution is idempotent'

    A CW09 ((E {P CW08 'draft' 'different'})-match'OPERATION_REPLAY_CONFLICT') 'reused Operation_ID with new payload is blocked'
    A CW10 ((E {P CW10 'draft' 'reviewed' @{TargetField='Title'}})-match'FIELD_NOT_ALLOWLISTED') 'non-allowlisted field is blocked'

    if($script:N-ne10){throw "Expected 10 focused controlled-write assertions, got $script:N"}
    Write-Host "SPR-014 controlled write focused: CW01-CW10 10/10 PASS; production mutations: 0/0/0"
}finally{Remove-Item -LiteralPath $script:TempRoot -Recurse -Force}
