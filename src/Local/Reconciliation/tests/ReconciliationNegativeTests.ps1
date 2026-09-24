. (Join-Path $PSScriptRoot 'TestHarness.ps1')
$script:N=0
function A([string]$id,[bool]$ok,[string]$message){$script:N++;if(!$ok){throw "$id failed: $message"};Write-Host "$id PASS $message"}
$e=New-RapRecExpected;$a=New-RapRecActual
$v=Copy-RapRec $a;$v.IdentityAmbiguous=$true;$x=Get-RapRecPlan $e $v 'N01';A N01 ($x.Decision.Decision-ne'AUTO_SAFE'-and$x.Decision.Reasons-match'AMBIGUOUS') 'ambiguous identity fails closed'
$v=Copy-RapRec $a;$v.EvidenceComplete=$false;$x=Get-RapRecPlan $e $v 'N02';A N02 ($x.Decision.Decision-ne'AUTO_SAFE') 'incomplete evidence fails closed'
$v=Copy-RapRec $a;$v.Records[1].Value='changed';$x=Get-RapRecPlan $e $v 'N03';A N03 ($x.Decision.Decision-eq'HUMAN_REVIEW_REQUIRED'-and$x.Plan.Actions.Count-eq0) 'HUMAN_OWNED protected'
$v=Copy-RapRec $a;$v.Records[2].Value='changed';$x=Get-RapRecPlan $e $v 'N04';A N04 ($x.Decision.Decision-eq'HUMAN_REVIEW_REQUIRED'-and$x.Plan.Actions.Count-eq0) 'ResearcherConfirmed protected'
$v=Copy-RapRec $a;$v.Records+= [pscustomobject]@{RecordId='EXTRA';Value='x';Ownership='AUTO_OWNED';Evidence=@{Source='x'}};$x=Get-RapRecPlan $e $v 'N05';A N05 ($x.Decision.Decision-ne'AUTO_SAFE') 'unexpected record is not auto-deleted'
$v=Copy-RapRec $a;$v.Records[0].Ownership='HUMAN_OWNED';$x=Get-RapRecPlan $e $v 'N06';A N06 ($x.Decision.Decision-ne'AUTO_SAFE') 'ownership conflict blocked'
$v=Copy-RapRec $a;$v.LibraryId='bad';A N07 (-not(Test-RapIntegritySnapshot $v).Valid) 'invalid Library_ID rejected'
$v=Copy-RapRec $a;$v.ProjectId='bad';A N08 (-not(Test-RapIntegritySnapshot $v).Valid) 'invalid Project_ID rejected'
$v=Copy-RapRec $a;$v.Records+=Copy-RapRec $v.Records[0];A N09 (-not(Test-RapIntegritySnapshot $v).Valid) 'duplicate identity rejected'
$x=Get-RapRecPlan $e $a 'N10';$m=New-RapRecMemory $a;$m.State.Snapshot.Records[0].Value.Version=99;A N10 ((Get-RapThrown {Invoke-RapRecoveryPlan $x.Plan $e $m.Dependencies Fixture})-match'STALE_RECOVERY_PLAN') 'stale plan rejected'
$x=Get-RapRecPlan $e $a 'N11';$x.Plan.ProjectId='PR002';$m=New-RapRecMemory $a;A N11 ((Get-RapThrown {Invoke-RapRecoveryPlan $x.Plan $e $m.Dependencies Fixture})-match'PLAN_SCOPE') 'tampered scope rejected'
$x=Get-RapRecPlan $e $a 'N12';$changed=Copy-RapRec $e;$changed.Records[0].Value.Version=3;$m=New-RapRecMemory $a;A N12 ((Get-RapThrown {Invoke-RapRecoveryPlan $x.Plan $changed $m.Dependencies Fixture})-match'EXPECTED_HASH') 'expected hash mismatch rejected'
$x=Get-RapRecPlan $e $a 'N13';$x.Plan.ProductionWrite='ENABLED';$m=New-RapRecMemory $a;A N13 ((Get-RapThrown {Invoke-RapRecoveryPlan $x.Plan $e $m.Dependencies Fixture})-match'UNSAFE_RECOVERY_PLAN') 'production plan rejected'
$x=Get-RapRecPlan $e $a 'N14';$x.Plan.Decision='HUMAN_REVIEW_REQUIRED';$m=New-RapRecMemory $a;A N14 ((Get-RapThrown {Invoke-RapRecoveryPlan $x.Plan $e $m.Dependencies Fixture})-match'NON_AUTO_SAFE') 'non-auto plan cannot carry actions'
$x=Get-RapRecPlan $e $a 'N15';$x.Plan.Actions[0].Action='DELETE';$m=New-RapRecMemory $a;A N15 ((Get-RapThrown {Invoke-RapRecoveryPlan $x.Plan $e $m.Dependencies Fixture})-match'PROHIBITED') 'destructive action rejected'
$x=Get-RapRecPlan $e $a 'N16';$m=New-RapRecMemory $a;$null=Invoke-RapRecoveryPlan $x.Plan $e $m.Dependencies Fixture;$x.Plan.PlanHash='different';A N16 ((Get-RapThrown {Invoke-RapRecoveryPlan $x.Plan $e $m.Dependencies Fixture})-match'OPERATION_REPLAY_CONFLICT') 'changed replay rejected'
if($script:N-ne16){throw "Expected 16 N assertions, got $script:N"}
Write-Host "SPR-011.5 reconciliation negative: N01-N16 16/16 PASS; assertions: $script:N"
