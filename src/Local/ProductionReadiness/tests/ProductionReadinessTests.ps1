. (Join-Path $PSScriptRoot 'TestHarness.ps1')
$script:N=0;function A([string]$id,[bool]$ok,[string]$m){$script:N++;if(!$ok){throw "$id failed: $m"};Write-Host "$id PASS $m"}
$e=New-RapPrExpected;$a=New-RapPrActual;$g=New-RapPrGuard
A PR01 ((Get-RapPrThrown {New-RapEnvironmentGuard Production PRODUCTION})-match'CLASSIFICATION') 'environment misclassification fails closed'
A PR02 ((Get-RapPrThrown {Invoke-RapProductionWriteFirewall DELETE})-match'WRITE_BLOCKED') 'write firewall blocks mutation'
A PR03 ((Get-RapPrThrown {Invoke-RapProductionWriteFirewall UPDATE})-match'WRITE_BLOCKED') 'unauthorized write attempt blocked'
$zp=Invoke-RapExternalReadProbe (New-RapPrProbe Zotero $a);A PR04 ($zp.Status-eq'PASS'-and$zp.System-eq'Zotero'-and!$zp.ChangesApplied) 'Zotero read adapter'
$dp=Invoke-RapExternalReadProbe (New-RapPrProbe GoogleDrive $a);A PR05 ($dp.Status-eq'PASS'-and$dp.System-eq'GoogleDrive'-and!$dp.ChangesApplied) 'Drive read adapter'
$np=Invoke-RapExternalReadProbe (New-RapPrProbe Notion $a);A PR06 ($np.Status-eq'PASS'-and$np.System-eq'Notion'-and!$np.ChangesApplied) 'Notion read adapter'
A PR07 ((Invoke-RapExternalReadProbe (New-RapPrProbe Zotero $a $true $true $false)).Status-eq'SCHEMA_MISMATCH') 'schema mismatch blocked'
A PR08 ((Invoke-RapExternalReadProbe (New-RapPrProbe GoogleDrive $a $true $false)).Status-eq'PERMISSION_FAILURE') 'permission failure blocked'
A PR09 ((Invoke-RapExternalReadProbe (New-RapPrProbe Notion $a $true $true $true $false)).Status-eq'MISSING_EXTERNAL_OBJECT') 'missing object blocked'
$amb=Copy-RapPr $a;$amb.IdentityAmbiguous=$true;$r=Invoke-RapProductionDryRun (New-RapPrProbe Zotero $amb) $e $g PR10;A PR10 ($r.Status-eq'BLOCKED'-and!$r.ChangesApplied-and$r.MutationManifests.Count-eq0) 'ambiguous identity blocks mutation'
$human=Copy-RapPr $a;$human.Records[1].Value='changed';$r=Invoke-RapProductionDryRun (New-RapPrProbe Zotero $human) $e $g PR11;A PR11 ($r.Status-eq'BLOCKED'-and$r.Preflight.Reasons-match'OWNERSHIP') 'HUMAN_OWNED conflict blocked'
$p=Test-RapProductionPreflight $g $true $false $true $true $true $true $true @() $true;A PR12 ($p.Status-eq'BLOCKED'-and$p.Reasons-match'STALE') 'stale snapshot blocked'
$m=New-RapMutationManifest PR13 'Zotero:DERIVED:1' $a.Records[0].Value $e.Records[0].Value 'RECONCILIATION_PLAN' AUTO_OWNED $false 'READ_BACK_HASH_AND_COMPARE';A PR13 ($m.OperationId-and$m.Target-and$m.BeforeStateHash-and$m.ProposedAfterState-and$m.Reason-and$m.Ownership-and$null-ne$m.Destructive-and$m.VerificationMethod-and!$m.ApplyPermitted) 'mutation manifest complete'
$secret=('canary'+'-credential-value');[Environment]::SetEnvironmentVariable('RAP_TEST_CREDENTIAL',$secret);try{$json=(Invoke-RapExternalReadProbe (New-RapPrProbe Zotero $a))|ConvertTo-Json -Depth 20;A PR14 ($json-notmatch[regex]::Escape($secret)-and$json-match'CredentialPresent') 'secret leakage zero'}finally{[Environment]::SetEnvironmentVariable('RAP_TEST_CREDENTIAL',$null)}
$timeout=New-RapExternalReadAdapter Zotero ([uri]'https://api.zotero.org/') RAP_TEST_CREDENTIAL {throw 'request timed out'};A PR15 ((Invoke-RapExternalReadProbe $timeout).Status-eq'EXTERNAL_TIMEOUT') 'external timeout fails closed'
$adapter=New-RapPrProbe Zotero $a;$one=Invoke-RapProductionDryRun $adapter $e $g PR16;$two=Invoke-RapProductionDryRun $adapter $e $g PR16;A PR16 (($one|ConvertTo-Json -Depth 60 -Compress)-eq($two|ConvertTo-Json -Depth 60 -Compress)-and$one.Status-eq'DRY_RUN_COMPLETE') 'repeated dry-run deterministic'
if($script:N-ne16){throw "Expected 16 PR assertions, got $script:N"};Write-Host "SPR-012 production readiness focused: PR01-PR16 16/16 PASS; assertions: $script:N"
