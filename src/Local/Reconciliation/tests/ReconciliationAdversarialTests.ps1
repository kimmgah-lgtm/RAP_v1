. (Join-Path $PSScriptRoot 'TestHarness.ps1')
$script:N=0;function A([bool]$ok,[string]$m){$script:N++;if(!$ok){throw "ADV-$script:N failed: $m"}}
$e=New-RapRecExpected;$a=New-RapRecActual
$permuted=Copy-RapRec $a;$permuted.Records=@($permuted.Records|Sort-Object RecordId -Descending);$d1=Compare-RapIntegritySnapshot $e $a;$d2=Compare-RapIntegritySnapshot $e $permuted;A ($d1.DifferenceCount-eq$d2.DifferenceCount) 'order invariant'
$v=Copy-RapRec $a;$v.IdentityAmbiguous=$true;$x=Get-RapRecPlan $e $v 'ADV2';A ($x.Plan.Actions.Count-eq0) 'ambiguous plan empty'
$v=Copy-RapRec $a;$v.Records[0].Evidence=$null;A (-not(Test-RapIntegritySnapshot $v).Valid) 'null evidence rejected'
$v=Copy-RapRec $a;$v.Records[0].Ownership='human_owned';A (-not(Test-RapIntegritySnapshot $v).Valid) 'noncanonical ownership rejected'
$x=Get-RapRecPlan $e $a 'ADV5';$x.Plan.DestructiveActionCount=1;$m=New-RapRecMemory $a;A ((Get-RapThrown {Invoke-RapRecoveryPlan $x.Plan $e $m.Dependencies Fixture})-match'UNSAFE') 'destructive count blocked'
$x=Get-RapRecPlan $e $a 'ADV6';$x.Plan.Actions[0].Ownership='HUMAN_OWNED';$m=New-RapRecMemory $a;A ((Get-RapThrown {Invoke-RapRecoveryPlan $x.Plan $e $m.Dependencies Fixture})-match'PROHIBITED') 'forged ownership blocked'
$x=Get-RapRecPlan $e $a 'ADV7';$m=New-RapRecMemory $a;$null=Invoke-RapRecoveryPlan $x.Plan $e $m.Dependencies DryRun;A ($m.State.Audits.Count-eq0) 'dry run has no audit mutation'
$temp=Join-Path ([IO.Path]::GetTempPath()) ('rap-rec-adv-'+[guid]::NewGuid());New-Item $temp -ItemType Directory|Out-Null
try{$db=Join-Path $temp 'rec.db';$ps=(Get-Process -Id $PID).Path;$h=Join-Path $PSScriptRoot 'RecoveryProcess.ps1';&$ps -NoProfile -File $h -Phase Seed -DatabasePath $db|Out-Null;foreach($point in @('AFTER_STATE','BEFORE_COMMIT')){&$ps -NoProfile -File $h -Phase Fault -FaultPoint $point -DatabasePath $db 2>$null|Out-Null;A ($LASTEXITCODE-ne0) "$point fault";&$ps -NoProfile -File $h -Phase Inspect -DatabasePath $db|Out-Null;A ($LASTEXITCODE-eq0) "$point rollback"};&$ps -NoProfile -File $h -Phase Complete -DatabasePath $db|Out-Null;A ($LASTEXITCODE-eq0) 'restart completion';&$ps -NoProfile -File $h -Phase Replay -DatabasePath $db|Out-Null;A ($LASTEXITCODE-eq0) 'restart replay'}finally{Remove-Item $temp -Recurse -Force}
if($script:N-ne13){throw "Expected 13 adversarial assertions, got $script:N"};Write-Host "SPR-011.5 reconciliation adversarial: 13/13 PASS; assertions: $script:N"
