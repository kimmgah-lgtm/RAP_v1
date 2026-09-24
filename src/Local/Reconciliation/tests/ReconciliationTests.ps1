. (Join-Path $PSScriptRoot 'TestHarness.ps1')
$script:N=0
function A([string]$id,[bool]$ok,[string]$message){$script:N++;if(!$ok){throw "$id failed: $message"};Write-Host "$id PASS $message"}
$e=New-RapRecExpected;$a=New-RapRecActual;$x=Get-RapRecPlan $e $a
A RC01 (Test-RapIntegritySnapshot $e).Valid 'snapshot validation'
A RC02 ($x.Diff.DifferenceCount-eq1-and$x.Diff.Differences[0].Kind-eq'VALUE_MISMATCH') 'difference detector'
A RC03 ($x.Decision.Decision-eq'AUTO_SAFE') 'ownership-aware AUTO_SAFE decision'
A RC04 ($x.Plan.Actions.Count-eq1-and$x.Plan.PlanHash) 'plan-before-apply recovery plan'
$m=New-RapRecMemory $a;$dry=Invoke-RapRecoveryPlan $x.Plan $e $m.Dependencies DryRun
A RC05 ($dry.Status-eq'DRY_RUN'-and!$dry.ChangesApplied-and$m.State.Snapshot.Records[0].Value.Version-eq1) 'dry-run isolation'
$r=Invoke-RapRecoveryPlan $x.Plan $e $m.Dependencies Fixture
A RC06 ($r.Status-eq'RECOVERED'-and$r.ChangesApplied) 'fixture apply'
A RC07 ($r.Verification.Valid-and$r.Verification.DifferenceCount-eq0) 'read-back verification'
A RC08 ($m.State.Audits.Count-eq1-and$m.State.Audits[0].PlanHash-eq$x.Plan.PlanHash) 'audit and lineage'
$replay=Invoke-RapRecoveryPlan $x.Plan $e $m.Dependencies Fixture
A RC09 ($replay.Status-eq'ALREADY_COMPLETED'-and$m.State.Audits.Count-eq1) 'idempotent replay'
$other=Copy-RapRec $a;$other.ProjectId='PR002'
A RC10 ((Get-RapThrown {Compare-RapIntegritySnapshot $e $other})-match'SCOPE_ISOLATION') 'Library_ID + Project_ID isolation'
A RC11 ($x.Plan.ExpectedSnapshotHash-eq$x.Diff.ExpectedHash-and$x.Plan.ActualSnapshotHash-eq$x.Diff.ActualHash) 'plan binds both snapshots'
A RC12 ($x.Plan.DestructiveActionCount-eq0-and@($x.Plan.Actions|Where-Object{$_.Action-match'DELETE|MERGE'}).Count-eq0) 'non-destructive plan'
A RC13 ($x.Plan.ProductionWrite-eq'DISABLED'-and$r.ProductionWrite-eq'DISABLED') 'production write disabled'
$missing=Copy-RapRec $a;$missing.Records=@($missing.Records|Where-Object{$_.RecordId-ne'DERIVED:1'});$mx=Get-RapRecPlan $e $missing 'RC-MISSING';$mm=New-RapRecMemory $missing;$mr=Invoke-RapRecoveryPlan $mx.Plan $e $mm.Dependencies Fixture
A RC14 ($mr.Verification.Valid-and@($mm.State.Snapshot.Records|Where-Object{$_.RecordId-eq'DERIVED:1'}).Count-eq1) 'local missing derived record recovery'
$same=Copy-RapRec $e;$sx=Get-RapRecPlan $e $same 'RC-SAME'
A RC15 ($sx.Diff.DifferenceCount-eq0-and$sx.Decision.Decision-eq'NO_ACTION'-and$sx.Plan.Actions.Count-eq0) 'no-action decision'
$temp=Join-Path ([IO.Path]::GetTempPath()) ('rap-rec-'+[guid]::NewGuid());New-Item $temp -ItemType Directory|Out-Null
try{$db=Join-Path $temp 'rec.db';$d=New-RapReconciliationSqliteDependencies $db;Register-RapReconciliationFixture $a $d;$px=Get-RapRecPlan $e $a 'RC-SQL';$null=Invoke-RapRecoveryPlan $px.Plan $e $d Fixture;$reload=Get-RapReconciliationSnapshot $db $e.LibraryId $e.ProjectId;$aud=@(Get-RapReconciliationAudit $db);A RC16 ((Test-RapRecoveryReadBack $e $reload).Valid-and$aud.Count-eq1) 'persistent reload'}finally{Remove-Item $temp -Recurse -Force}
if($script:N-ne16){throw "Expected 16 RC assertions, got $script:N"}
Write-Host "SPR-011.5 reconciliation core: RC01-RC16 16/16 PASS; assertions: $script:N"
