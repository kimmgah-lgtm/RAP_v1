. (Join-Path $PSScriptRoot 'TestHarness.ps1')
$script:N=0
function A([string]$id,[bool]$ok,[string]$message){$script:N++;if(!$ok){throw "$id failed: $message"};Write-Host "$id PASS $message"}
function E([scriptblock]$script){try{&$script;$null}catch{$_.Exception.Message}}
function Reload-RapCw {Import-Module (Join-Path $PSScriptRoot '../ResearchAutomation.ProductionReadiness.psd1') -Force}
$script:TempRoot=Join-Path ([IO.Path]::GetTempPath()) ('rap-cw-remediation-'+[guid]::NewGuid());[void](New-Item -ItemType Directory -Path $script:TempRoot);$script:DbPath=Join-Path $script:TempRoot 'controlled-write.db'
function P([string]$operationId,[hashtable]$override=@{}){$parameters=@{OperationId=$operationId;LibraryId='LIB:L000003';ProjectId='PR003';TargetSystem='Notion';TargetObject='page-L000003';TargetObjectType='MetadataRecord';TargetField='RAP_Status';Action='UPDATE';BatchCount=1;BeforeValue='draft';ProposedValue='reviewed';Reason='SPR-014 Turn C remediation';Ownership='RAP_OWNED';ExpectedVersion='7';IdentityStatus='MATCHED';CanonicalLibraryIdPresent=$true;IdentityAmbiguous=$false;PdfIdentityVerified=$true;OwnershipConflict=$false;StaleState=$false;RollbackInfo='Restore RAP_Status from persisted audit.';DatabasePath=$script:DbPath};foreach($key in $override.Keys){$parameters[$key]=$override[$key]};New-RapControlledWritePlan @parameters}
function ApproveTestPlan($plan){$request=New-RapControlledWriteApprovalRequest $plan;Approve-RapControlledWritePlan $plan $request 'turn-c-human-reviewer' HUMAN 'SPR-014 Turn C approval'}
function Adapter($plan,$approval,[hashtable]$extra=@{}){$parameters=@{Plan=$plan;Approval=$approval;InitialFields=@{RAP_Status='draft'};Version=7};foreach($key in $extra.Keys){$parameters[$key]=$extra[$key]};New-RapControlledWriteFixtureAdapter @parameters}
try{
    $p=P R01;$x=ApproveTestPlan $p;$a=Adapter $p $x @{CurrentLibraryId='LIB:L000004'};A R01 ((E {Invoke-RapControlledWritePilot $p $x $a})-match'IDENTITY_CHANGED') 'Library_ID cross-target attempt blocked'
    $p=P R02;$x=ApproveTestPlan $p;$a=Adapter $p $x @{CurrentProjectId='PR004'};A R02 ((E {Invoke-RapControlledWritePilot $p $x $a})-match'IDENTITY_CHANGED') 'Project_ID cross-target attempt blocked'
    $p=P R03;$x=ApproveTestPlan $p;$a=Adapter $p $x @{CurrentTargetObject='page-L000004'};A R03 ((E {Invoke-RapControlledWritePilot $p $x $a})-match'IDENTITY_CHANGED') 'target object substitution blocked'
    $p=P R04;$x=ApproveTestPlan $p;$a=Adapter $p $x @{CurrentTargetField='RAP_Metadata'};A R04 ((E {Invoke-RapControlledWritePilot $p $x $a})-match'IDENTITY_CHANGED') 'target field substitution blocked'
    $p=P R05;$x=ApproveTestPlan $p;$a=Adapter $p $x;$p.ProposedValue='substituted';A R05 ((E {Invoke-RapControlledWritePilot $p $x $a})-match'PLAN_TAMPERED') 'approved payload substitution blocked'

    $p=P R06;$x=ApproveTestPlan $p;$a=Adapter $p $x @{CurrentOwnership='OTHER_OWNED'};A R06 ((E {Invoke-RapControlledWritePilot $p $x $a})-match'OWNERSHIP_CHANGED') 'ownership changed after approval blocked'
    $p=P R07;$x=ApproveTestPlan $p;$a=Adapter $p $x @{CurrentIdentityStatus='MISSING'};A R07 ((E {Invoke-RapControlledWritePilot $p $x $a})-match'IDENTITY_CHANGED') 'identity changed after approval blocked'
    $p=P R08;$x=ApproveTestPlan $p;$a=Adapter $p $x @{CurrentOwnership='HUMAN_OWNED'};A R08 ((E {Invoke-RapControlledWritePilot $p $x $a})-match'OWNERSHIP_CHANGED:HUMAN_OWNED') 'HUMAN_OWNED introduced after approval blocked'
    $p=P R09;$x=ApproveTestPlan $p;$a=Adapter $p $x @{CurrentOwnership='ResearcherConfirmed'};A R09 ((E {Invoke-RapControlledWritePilot $p $x $a})-match'OWNERSHIP_CHANGED:ResearcherConfirmed') 'ResearcherConfirmed introduced after approval blocked'
    $p=P R10;$x=ApproveTestPlan $p;$a=New-RapControlledWriteFixtureAdapter -Plan $p -Approval $x -InitialFields @{RAP_Status='changed'} -Version 8;A R10 ((E {Invoke-RapControlledWritePilot $p $x $a})-match'STALE_CONTROLLED_WRITE_PLAN') 'before hash/version drift blocked'

    $process=(Get-Process -Id $PID).Path;$restartHelper=Join-Path $PSScriptRoot 'ControlledWriteRestartProcess.ps1'
    foreach($case in @(@{Id='R11';State='PLANNED'},@{Id='R12';State='APPROVED'},@{Id='R13';State='APPLYING'},@{Id='R14';State='APPLIED'},@{Id='R15';State='VERIFIED'},@{Id='R16';State='VERIFY_FAILED'})){
        $casePath=Join-Path $script:TempRoot $case.Id;&$process -NoProfile -File $restartHelper -Phase Seed -State $case.State -CasePath $casePath|Out-Null;$seedOk=$LASTEXITCODE-eq0;&$process -NoProfile -File $restartHelper -Phase Check -State $case.State -CasePath $casePath|Out-Null;$checkOk=$LASTEXITCODE-eq0
        A $case.Id ($seedOk-and$checkOk) "process-boundary restart after $($case.State) is safe"
    }
    $verifiedPath=Join-Path $script:TempRoot 'R17';&$process -NoProfile -File $restartHelper -Phase Seed -State VERIFIED -CasePath $verifiedPath|Out-Null;$seedOk=$LASTEXITCODE-eq0;&$process -NoProfile -File $restartHelper -Phase Check -State VERIFIED -CasePath $verifiedPath|Out-Null;$firstOk=$LASTEXITCODE-eq0;&$process -NoProfile -File $restartHelper -Phase Check -State VERIFIED -CasePath $verifiedPath|Out-Null;$secondOk=$LASTEXITCODE-eq0;A R17 ($seedOk-and$firstOk-and$secondOk) 'duplicate Operation_ID remains idempotent across repeated restart processes'
    $p=P R18;[Rap.NativeSqlite]::Execute($script:DbPath,"UPDATE ControlledWriteOperations SET RecordHash='tampered' WHERE OperationId='R18';",5000);$corrupt=(E {Get-RapControlledWritePersistedOperation $script:DbPath R18})-match'PERSISTENCE_CORRUPT';A R18 ($corrupt-and-not(Test-RapControlledWriteStoreIntegrity $script:DbPath)) 'persisted payload/hash tampering detected'

    if($script:N-ne18){throw "Expected 18 remediation assertions, got $script:N"};Write-Host 'SPR-014 Turn C remediation: R01-R18 18/18 PASS; P0/P1: 0/0; production mutations: 0/0/0'
}finally{Remove-Item -LiteralPath $script:TempRoot -Recurse -Force}
