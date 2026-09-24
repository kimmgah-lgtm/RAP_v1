param([Parameter(Mandatory)][ValidateSet('Seed','Fault','Complete','Replay','Inspect')][string]$Phase,[Parameter(Mandatory)][string]$DatabasePath,[ValidateSet('AFTER_STATE','BEFORE_COMMIT')][string]$FaultPoint='AFTER_STATE')
. (Join-Path $PSScriptRoot 'TestHarness.ps1')
$e=New-RapRecExpected;$a=New-RapRecActual
if($Phase-eq'Seed'){$d=New-RapReconciliationSqliteDependencies $DatabasePath;Register-RapReconciliationFixture $a $d;Write-Host 'SEEDED';exit 0}
$d=New-RapReconciliationSqliteDependencies $DatabasePath -FaultPoint $(if($Phase-eq'Fault'){$FaultPoint}else{'None'});$x=Get-RapRecPlan $e $a 'RECOVERY-OP'
if($Phase-eq'Inspect'){$s=Get-RapReconciliationSnapshot $DatabasePath $e.LibraryId $e.ProjectId;$op=&$d.GetOperation 'RECOVERY-OP';if($s.Records[0].Value.Version-ne1-or$null-ne$op){throw 'ROLLBACK_FAILED'};Write-Host 'ROLLBACK PASS';exit 0}
$r=Invoke-RapRecoveryPlan $x.Plan $e $d Fixture
if($Phase-eq'Fault'){throw 'FAULT_DID_NOT_FIRE'}
if($Phase-eq'Complete'-and$r.Status-ne'RECOVERED'){throw 'COMPLETE_FAILED'}
if($Phase-eq'Replay'-and$r.Status-ne'ALREADY_COMPLETED'){throw 'REPLAY_FAILED'}
Write-Host "$Phase PASS"
