param(
    [Parameter(Mandatory)][ValidateSet('Seed','Check')][string]$Phase,
    [Parameter(Mandatory)][ValidateSet('PLANNED','APPROVED','APPLYING','APPLIED','VERIFIED','VERIFY_FAILED')][string]$State,
    [Parameter(Mandatory)][string]$CasePath
)
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot '../ResearchAutomation.ProductionReadiness.psd1') -Force
[void][IO.Directory]::CreateDirectory($CasePath)
$db=Join-Path $CasePath 'controlled-write.db';$planPath=Join-Path $CasePath 'plan.xml';$approvalPath=Join-Path $CasePath 'approval.xml';$operationId="PROC-$State"
function Err([scriptblock]$script){try{&$script|Out-Null;''}catch{$_.Exception.Message}}
if($Phase-eq'Seed'){
    $plan=New-RapControlledWritePlan -OperationId $operationId -LibraryId 'LIB:L000003' -ProjectId 'PR003' -TargetSystem Notion -TargetObject 'page-L000003' -TargetField RAP_Status -BeforeValue draft -ProposedValue reviewed -Reason 'process boundary restart test' -Ownership RAP_OWNED -ExpectedVersion 7 -RollbackInfo 'restore from persisted audit' -DatabasePath $db
    $plan|Export-Clixml -LiteralPath $planPath
    if($State-eq'PLANNED'){Write-Host 'PLANNED SEEDED';exit 0}
    $request=New-RapControlledWriteApprovalRequest $plan;$approval=Approve-RapControlledWritePlan $plan $request 'process-human-reviewer' HUMAN 'process boundary approval';$approval|Export-Clixml -LiteralPath $approvalPath
    if($State-eq'APPROVED'){Write-Host 'APPROVED SEEDED';exit 0}
    $adapterArgs=@{Plan=$plan;Approval=$approval;InitialFields=@{RAP_Status='draft'};Version=7}
    if($State-eq'APPLYING'){$adapterArgs.FaultPoint='AFTER_APPLYING'}
    if($State-eq'APPLIED'){$adapterArgs.FaultPoint='AFTER_APPLIED'}
    if($State-eq'VERIFY_FAILED'){$adapterArgs.ReadBackMismatch=$true}
    $adapter=New-RapControlledWriteFixtureAdapter @adapterArgs
    if($State-in@('APPLYING','APPLIED')){$message=Err {Invoke-RapControlledWritePilot $plan $approval $adapter};if($message-notmatch"AFTER_$State"){throw "FAULT_NOT_REACHED:${State}:$message"}}
    else{$result=Invoke-RapControlledWritePilot $plan $approval $adapter;if($result.Status-ne$State){throw "STATE_NOT_REACHED:${State}:$($result.Status)"}}
    Write-Host "$State SEEDED";exit 0
}
$plan=Import-Clixml -LiteralPath $planPath
$operation=Get-RapControlledWritePersistedOperation $db $operationId
if($operation.State-ne$State){throw "PERSISTED_STATE_MISMATCH:${State}:$($operation.State)"}
if($State-eq'PLANNED'){$message=Err {Invoke-RapControlledWritePilot $plan $null ([pscustomobject]@{})};if($message-notmatch'HUMAN_APPROVAL_REQUIRED'){throw "PLANNED_RESTART_UNSAFE:$message"};Write-Host 'PLANNED RESTART PASS';exit 0}
$approval=Import-Clixml -LiteralPath $approvalPath
$approval.PSObject.TypeNames.Insert(0,'Rap.ControlledWriteApproval')
if($State-eq'APPROVED'){$adapter=New-RapControlledWriteFixtureAdapter -Plan $plan -Approval $approval -InitialFields @{RAP_Status='draft'} -Version 7;$result=Invoke-RapControlledWritePilot $plan $approval $adapter;if($result.Status-ne'VERIFIED'){throw "APPROVED_RESTART_FAILED:$($result.Status)"};Write-Host 'APPROVED RESTART PASS';exit 0}
$result=Invoke-RapControlledWritePilot $plan $approval ([pscustomobject]@{})
if($State-eq'VERIFIED'){
    if($result.Status-ne'ALREADY_COMPLETED'-or$result.MutationCount-ne0){throw 'VERIFIED_RESTART_NOT_IDEMPOTENT'}
}else{
    if($result.Status-ne'RECOVERY_REQUIRED'-or$result.PersistedState-ne$State-or$result.MutationCount-ne0){throw "UNCERTAIN_RESTART_UNSAFE:$State"}
}
Write-Host "$State RESTART PASS"
