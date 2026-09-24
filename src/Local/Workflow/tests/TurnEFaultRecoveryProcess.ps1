#Requires -Version 7.0
# SPR-011 Turn E — cross-process interruption helper. Each phase runs in its own pwsh process.
[CmdletBinding()]param(
    [Parameter(Mandatory)][ValidateSet('Fault','Inspect','Complete','Replay')][string]$Phase,
    [Parameter(Mandatory)][string]$DatabasePath,
    [ValidateSet('None','AFTER_STATE','AFTER_AUDIT','AFTER_EVENTS','BEFORE_COMMIT')][string]$FaultPoint='None'
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'ResearchAutomation.Workflow.psd1') -Force
. (Join-Path $PSScriptRoot 'TestHarness.ps1')
$stale=New-RapWorkflowTurnEFixture;$stale.VersionState.SourceVersion=2
$operationId='TURN-E-INTERRUPT'
switch($Phase){
    'Fault'{
        $dependencies=New-RapWorkflowSqliteDependencies -DatabasePath $DatabasePath -FaultPoint $FaultPoint
        try{$null=Invoke-RapWorkflowExceptionOperation -Snapshot $stale -OperationId $operationId -Dependencies $dependencies}catch{Write-Host "FAULT RAISED: $($_.Exception.Message)";exit 3}
        Write-Host 'FAULT NOT RAISED';exit 0
    }
    'Complete'{
        $dependencies=New-RapWorkflowSqliteDependencies -DatabasePath $DatabasePath
        $r=Invoke-RapWorkflowExceptionOperation -Snapshot $stale -OperationId $operationId -Dependencies $dependencies
        if($r.Status-ne'COMPLETED'){throw "UNEXPECTED_STATUS:$($r.Status)"};exit 0
    }
    'Replay'{
        $dependencies=New-RapWorkflowSqliteDependencies -DatabasePath $DatabasePath
        $r=Invoke-RapWorkflowExceptionOperation -Snapshot $stale -OperationId $operationId -Dependencies $dependencies
        if($r.Status-ne'ALREADY_COMPLETED'){throw "UNEXPECTED_STATUS:$($r.Status)"};exit 0
    }
    'Inspect'{
        $dependencies=New-RapWorkflowSqliteDependencies -DatabasePath $DatabasePath
        $path=$dependencies.DatabasePath
        $events=@(&$dependencies.ReadEvents)
        $failed=@($events|Where-Object EventType -eq 'OPERATION_FAILED')
        $state=&$dependencies.ReadState
        [pscustomobject]@{
            Operations=[int][Rap.NativeSqlite]::Scalar($path,"SELECT COUNT(*) FROM Operations WHERE Type='WorkflowException';",5000)
            Audits=[int][Rap.NativeSqlite]::Scalar($path,'SELECT COUNT(*) FROM WorkflowExceptionAudit;',5000)
            StateRows=[int][Rap.NativeSqlite]::Scalar($path,'SELECT COUNT(*) FROM WorkflowExceptionState;',5000)
            Exceptions=@($state.Exceptions).Count
            FailedEvents=$failed.Count
            FailureReason=$(if($failed.Count){$failed[0].FailureReason}else{$null})
            CompletedEvents=@($events|Where-Object EventType -eq 'OPERATION_COMPLETED').Count
            ChainValid=(Test-RapWorkflowAuditChain -DatabasePath $DatabasePath).Valid
        }|ConvertTo-Json -Compress
        exit 0
    }
}
