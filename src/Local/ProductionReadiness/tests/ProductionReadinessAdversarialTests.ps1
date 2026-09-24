. (Join-Path $PSScriptRoot 'TestHarness.ps1')
$script:N=0;function A([bool]$ok,[string]$m){$script:N++;if(!$ok){throw "ADV$script:N failed: $m"}}
$e=New-RapPrExpected;$a=New-RapPrActual;$g=New-RapPrGuard
foreach($action in @('CREATE','UPDATE','DELETE','MOVE','MERGE','APPLY','UPSERT','PATCH','POST','PUT')){A ((Get-RapPrThrown {Invoke-RapProductionWriteFirewall $action})-match'WRITE_BLOCKED') "$action blocked"}
A ((Invoke-RapProductionWriteFirewall CREATE -DryRun).Status-eq'DRY_RUN_ONLY') 'mutation dry-run allowed without apply'
A ((Get-RapPrThrown {Invoke-RapProductionWriteFirewall EXECUTE})-match'UNKNOWN_OPERATION') 'unknown operation fails closed'
A ((Get-RapPrThrown {New-RapExternalReadAdapter Zotero ([uri]'http://example.com/') RAP_TEST_CREDENTIAL 'users/1/items?limit=1'})-match'HTTPS') 'remote HTTP rejected'
A ((Get-RapPrThrown {New-RapMutationManifest ADV14 x 1 2 reason HUMAN_OWNED $false verify})-match'PROTECTED') 'protected ownership manifest rejected'
$other=Copy-RapPr $a;$other.ProjectId='PR002';A ((Get-RapPrThrown {Invoke-RapProductionDryRun (New-RapPrProbe Zotero $other) $e $g ADV15})-match'SCOPE_ISOLATION') 'cross-project snapshot rejected'
$unknown=New-RapFixtureReadAdapter Notion ([pscustomobject]@{Authorized=$true});A ((Invoke-RapExternalReadProbe $unknown).Status-ne'PASS') 'partial external state fails closed'
$r=Invoke-RapProductionDryRun (New-RapPrProbe Zotero $a) $e $g ADV17;A (!$r.ChangesApplied-and!$r.LocalTruthOverwritten-and$r.ProductionWrite-eq'DISABLED') 'dry-run never overwrites local truth'
if($script:N-ne17){throw "Expected 17 adversarial assertions, got $script:N"};Write-Host "SPR-012 production readiness adversarial: 17/17 PASS; assertions: $script:N"
