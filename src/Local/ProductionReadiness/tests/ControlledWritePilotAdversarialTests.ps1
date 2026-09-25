. (Join-Path $PSScriptRoot 'TestHarness.ps1')
$script:N=0
function A([string]$id,[bool]$ok,[string]$message){$script:N++;if(!$ok){throw "$id failed: $message"};Write-Host "$id PASS $message"}
function E([scriptblock]$script){try{&$script;$null}catch{$_.Exception.Message}}
function P([string]$operationId,[object]$before='draft',[object]$proposed='reviewed',[hashtable]$override=@{}){
    $parameters=@{OperationId=$operationId;LibraryId='LIB:L000003';ProjectId='';TargetSystem='Notion';TargetObject='page-L000003';TargetObjectType='MetadataRecord';TargetField='RAP_TestField';Action='UPDATE';BatchCount=1;BeforeValue=$before;ProposedValue=$proposed;Reason='SPR-014 adversarial fixture validation';Ownership='RAP_OWNED';ExpectedVersion='7';IdentityStatus='MATCHED';CanonicalLibraryIdPresent=$true;IdentityAmbiguous=$false;PdfIdentityVerified=$true;OwnershipConflict=$false;StaleState=$false;RollbackInfo='Restore RAP_TestField to its before value using the audit record.'}
    foreach($key in $override.Keys){$parameters[$key]=$override[$key]}
    New-RapControlledWritePlan @parameters
}
function ApproveTestPlan($plan){$request=New-RapControlledWriteApprovalRequest $plan;Approve-RapControlledWritePlan $plan $request 'fixture-human-reviewer' HUMAN 'SPR-014 adversarial fixture approval'}

A CW11 ((E {P CW11 'draft' 'reviewed' @{Action='DELETE'}})-match'ACTION_BLOCKED') 'DELETE is blocked'
A CW12 ((E {P CW12 'draft' 'reviewed' @{Action='MERGE'}})-match'ACTION_BLOCKED') 'MERGE is blocked'
A CW13 ((E {P CW13 'draft' 'reviewed' @{Action='MOVE'}})-match'ACTION_BLOCKED') 'MOVE is blocked'
A CW14 ((E {P CW14 'draft' 'reviewed' @{TargetObjectType='PDF'}})-match'PDF_MUTATION_BLOCKED') 'PDF mutation is blocked'

$plan=P CW15;$approval=ApproveTestPlan $plan;$forged=[pscustomobject]@{TargetSystem='Notion';TargetObject='page-L000003';Apply={throw 'malicious callback invoked'}}
A CW15 ((E {Invoke-RapControlledWritePilot $plan $approval $forged})-match'UNTRUSTED_CONTROLLED_WRITE_ADAPTER') 'indirect adapter bypass is blocked'

$adapter=New-RapControlledWriteFixtureAdapter Notion 'page-L000003' @{RAP_TestField='draft'} 7
$adapter|Add-Member Apply {throw 'malicious callback invoked'}
$result=Invoke-RapControlledWritePilot $plan $approval $adapter
A CW16 ($result.Status-eq'VERIFIED'-and(Get-RapControlledWriteFixtureState $adapter).MutationCount-eq1) 'caller callback is ignored by sealed capability'

$adapter=New-RapControlledWriteFixtureAdapter Notion 'page-L000003' @{RAP_TestField='draft'} 7 -ReadBackMismatch;$plan=P CW17;$approval=ApproveTestPlan $plan;$result=Invoke-RapControlledWritePilot $plan $approval $adapter
A CW17 ($result.Status-eq'VERIFY_FAILED'-and$result.Verification-eq'FAIL'-and$result.HumanReview-and$result.Audit.Result-eq'VERIFY_FAILED') 'read-back mismatch is not reported as success'

$adapter=New-RapControlledWriteFixtureAdapter Notion 'page-L000003' @{RAP_TestField='draft'} 7 -TimeoutAfterApply;$plan=P CW18;$approval=ApproveTestPlan $plan;$result=Invoke-RapControlledWritePilot $plan $approval $adapter
A CW18 ($result.Status-eq'PARTIAL_FAILURE'-and$result.ChangesApplied-and$result.Verification-eq'UNKNOWN'-and$result.HumanReview-and$result.Audit.Result-eq'PARTIAL_FAILURE') 'timeout after apply remains an explicit partial failure'

$secret=('SPR014-'+'SECRET-'+[guid]::NewGuid().ToString('N'));[Environment]::SetEnvironmentVariable('RAP_TEST_CREDENTIAL',$secret)
try{$adapter=New-RapControlledWriteFixtureAdapter Notion 'page-L000003' @{RAP_TestField='draft'} 7;$plan=P CW19;$approval=ApproveTestPlan $plan;$result=Invoke-RapControlledWritePilot $plan $approval $adapter;$json=$result|ConvertTo-Json -Depth 60;A CW19 ($json-notmatch[regex]::Escape($secret)-and$json-notmatch'Authorization|Bearer|Zotero-API-Key') 'audit and result leak no secret'}finally{[Environment]::SetEnvironmentVariable('RAP_TEST_CREDENTIAL',$null)}

$adapter=New-RapControlledWriteFixtureAdapter Notion 'page-L000003' @{RAP_TestField='draft'} 7
$batchBlocked=(E {P CW20 'draft' 'reviewed' @{BatchCount=2}})-match'BATCH_WRITE_BLOCKED'
$otherPlan=P CW20B 'draft' 'reviewed' @{TargetObject='page-L000001'};$otherApproval=ApproveTestPlan $otherPlan
$secondBlocked=(E {Invoke-RapControlledWritePilot $otherPlan $otherApproval $adapter})-match'TARGET_MISMATCH'
A CW20 ($batchBlocked-and$secondBlocked-and(Get-RapControlledWriteFixtureState $adapter).MutationCount-eq0) 'batch and second-object mutation are blocked'

$policyPlan=P POLICY01;$policyApproval=ApproveTestPlan $policyPlan
if((E {Invoke-RapControlledWritePilot $policyPlan $policyApproval $adapter PRODUCTION PRODUCTION})-notmatch'PRODUCTION_WRITE_PILOT_TEST_DEFERRED'){throw 'Production pilot policy did not defer'}
Write-Host 'SPR-014 actual production pilot policy: TEST_DEFERRED; production mutations: 0/0/0'
if($script:N-ne10){throw "Expected 10 adversarial controlled-write assertions, got $script:N"}
Write-Host "SPR-014 controlled write adversarial: CW11-CW20 10/10 PASS; production mutations: 0/0/0"
