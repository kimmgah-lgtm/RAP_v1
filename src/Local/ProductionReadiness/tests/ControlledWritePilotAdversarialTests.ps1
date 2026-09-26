. (Join-Path $PSScriptRoot 'TestHarness.ps1')
$script:N=0
function A([string]$id,[bool]$ok,[string]$message){$script:N++;if(!$ok){throw "$id failed: $message"};Write-Host "$id PASS $message"}
function E([scriptblock]$script){try{&$script;$null}catch{$_.Exception.Message}}
$script:TempRoot=Join-Path ([IO.Path]::GetTempPath()) ('rap-cw-adversarial-'+[guid]::NewGuid());[void](New-Item -ItemType Directory -Path $script:TempRoot);$script:DbPath=Join-Path $script:TempRoot 'controlled-write.db'
function P([string]$operationId,[object]$before='draft',[object]$proposed='reviewed',[hashtable]$override=@{}){
    $parameters=@{OperationId=$operationId;LibraryId='LIB:L000003';ProjectId='';TargetSystem='Notion';TargetObject='page-L000003';TargetObjectType='MetadataRecord';TargetField='RAP_TestField';Action='UPDATE';BatchCount=1;BeforeValue=$before;ProposedValue=$proposed;Reason='SPR-014 adversarial fixture validation';Ownership='RAP_OWNED';ExpectedVersion='7';IdentityStatus='MATCHED';CanonicalLibraryIdPresent=$true;IdentityAmbiguous=$false;PdfIdentityVerified=$true;OwnershipConflict=$false;StaleState=$false;RollbackInfo='Restore RAP_TestField to its before value using the audit record.';DatabasePath=$script:DbPath}
    foreach($key in $override.Keys){$parameters[$key]=$override[$key]};New-RapControlledWritePlan @parameters
}
function ApproveTestPlan($plan){$request=New-RapControlledWriteApprovalRequest $plan;Approve-RapControlledWritePlan $plan $request 'fixture-human-reviewer' HUMAN 'SPR-014 adversarial fixture approval'}
function Adapter($plan,$approval,[hashtable]$extra=@{}){$parameters=@{Plan=$plan;Approval=$approval;InitialFields=@{RAP_TestField='draft'};Version=7};foreach($key in $extra.Keys){$parameters[$key]=$extra[$key]};New-RapControlledWriteFixtureAdapter @parameters}
try{
    A CW11 ((E {P CW11 'draft' 'reviewed' @{Action='DELETE'}})-match'ACTION_BLOCKED') 'DELETE is blocked'
    A CW12 ((E {P CW12 'draft' 'reviewed' @{Action='MERGE'}})-match'ACTION_BLOCKED') 'MERGE is blocked'
    A CW13 ((E {P CW13 'draft' 'reviewed' @{Action='MOVE'}})-match'ACTION_BLOCKED') 'MOVE is blocked'
    A CW14 ((E {P CW14 'draft' 'reviewed' @{TargetObjectType='PDF'}})-match'PDF_MUTATION_BLOCKED') 'PDF mutation is blocked'

    $plan=P CW15;$approval=ApproveTestPlan $plan;$forged=[pscustomobject]@{TargetSystem='Notion';TargetObject='page-L000003';Apply={throw 'malicious callback invoked'}}
    A CW15 ((E {Invoke-RapControlledWritePilot $plan $approval $forged})-match'UNTRUSTED_CONTROLLED_WRITE_ADAPTER') 'indirect adapter bypass is blocked'

    $plan=P CW16;$approval=ApproveTestPlan $plan;$adapter=Adapter $plan $approval;$adapter|Add-Member Apply {throw 'malicious callback invoked'};$result=Invoke-RapControlledWritePilot $plan $approval $adapter
    A CW16 ($result.Status-eq'VERIFIED'-and(Get-RapControlledWriteFixtureState $adapter).MutationCount-eq1) 'caller callback is ignored by sealed capability'

    $plan=P CW17;$approval=ApproveTestPlan $plan;$adapter=Adapter $plan $approval @{ReadBackMismatch=$true};$result=Invoke-RapControlledWritePilot $plan $approval $adapter
    A CW17 ($result.Status-eq'VERIFY_FAILED'-and$result.Verification-eq'FAIL'-and$result.HumanReview-and$result.Audit.Result-eq'VERIFY_FAILED') 'read-back mismatch is not reported as success'

    $plan=P CW18;$approval=ApproveTestPlan $plan;$adapter=Adapter $plan $approval @{TimeoutAfterApply=$true};$result=Invoke-RapControlledWritePilot $plan $approval $adapter
    A CW18 ($result.Status-eq'PARTIAL_FAILURE'-and$result.ChangesApplied-and$result.Verification-eq'UNKNOWN'-and$result.HumanReview-and$result.Audit.Result-eq'PARTIAL_FAILURE') 'timeout after apply remains an explicit partial failure'

    $secret=('SPR014-'+'SECRET-'+[guid]::NewGuid().ToString('N'));[Environment]::SetEnvironmentVariable('RAP_TEST_CREDENTIAL',$secret)
    try{$plan=P CW19;$approval=ApproveTestPlan $plan;$adapter=Adapter $plan $approval;$result=Invoke-RapControlledWritePilot $plan $approval $adapter;$persisted=Get-RapControlledWritePersistedOperation $script:DbPath CW19;$json=@($result,$persisted)|ConvertTo-Json -Depth 80;A CW19 ($json-notmatch[regex]::Escape($secret)-and$json-notmatch'Authorization|Bearer|Zotero-API-Key') 'audit and persistence leak no secret'}finally{[Environment]::SetEnvironmentVariable('RAP_TEST_CREDENTIAL',$null)}

    $batchBlocked=(E {P CW20 'draft' 'reviewed' @{BatchCount=2}})-match'BATCH_WRITE_BLOCKED'
    $basePlan=P CW20BASE;$baseApproval=ApproveTestPlan $basePlan;$baseAdapter=Adapter $basePlan $baseApproval
    $otherPlan=P CW20B 'draft' 'reviewed' @{TargetObject='page-L000001'};$otherApproval=ApproveTestPlan $otherPlan
    $secondBlocked=(E {Invoke-RapControlledWritePilot $otherPlan $otherApproval $baseAdapter})-match'CAPABILITY_BINDING_MISMATCH'
    A CW20 ($batchBlocked-and$secondBlocked-and(Get-RapControlledWriteFixtureState $baseAdapter).MutationCount-eq0) 'batch and second-object mutation are blocked'

    $policyPlan=P POLICY01;$policyApproval=ApproveTestPlan $policyPlan;$policyAdapter=Adapter $policyPlan $policyApproval
    if((E {Invoke-RapControlledWritePilot $policyPlan $policyApproval $policyAdapter PRODUCTION PRODUCTION})-notmatch'PRODUCTION_WRITE_PILOT_TEST_DEFERRED'){throw 'Production pilot policy did not defer'}
    Write-Host 'SPR-014 actual production pilot policy: TEST_DEFERRED; production mutations: 0/0/0'
    if($script:N-ne10){throw "Expected 10 adversarial controlled-write assertions, got $script:N"};Write-Host "SPR-014 controlled write adversarial: CW11-CW20 10/10 PASS; production mutations: 0/0/0"
}finally{Remove-Item -LiteralPath $script:TempRoot -Recurse -Force}
