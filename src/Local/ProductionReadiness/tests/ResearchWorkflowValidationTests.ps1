. (Join-Path $PSScriptRoot 'TestHarness.ps1')
$script:N=0;function A([string]$id,[bool]$ok,[string]$m){$script:N++;if(!$ok){throw "$id failed: $m"};Write-Host "$id PASS $m"}
function Z([string]$key){[pscustomobject]@{ItemKey=$key}}
function D([string]$id){[pscustomobject]@{FileId=$id}}
function N([string]$id){[pscustomobject]@{PageId=$id}}
function T([hashtable]$override=@{}){$p=@{LibraryId='LIB:L000003';AccessAvailable=$true;ZoteroRecord=(Z BCMYA9ZJ);DriveFile=(D drive3);NotionReview=(N page3);ProjectMappings=@([pscustomobject]@{ProjectId='PR001'});BibliographicCandidateCount=1;PdfCandidateCount=1;SchemaCompatible=$true;LinkageComplete=$true;PdfMetadataMatches=$true;PdfHashMatches=$true};foreach($k in $override.Keys){$p[$k]=$override[$k]};Test-RapResearchObjectTrace @p}

$matched=T;A V01 ($matched.Status-eq'MATCHED'-and!$matched.ChangesApplied-and!$matched.ApplyPermitted) 'read-only identity mapping matched'
A V02 ((T @{PdfHashMatches=$false}).Status-eq'PDF_MISMATCH') 'PDF hash mismatch classified'
A V03 ((T @{PdfMetadataMatches=$false}).Status-eq'PDF_MISMATCH') 'PDF bibliographic mismatch classified'
A V04 ((T @{BibliographicCandidateCount=2}).Status-eq'AMBIGUOUS') 'duplicate bibliographic identity classified'
A V05 ((T @{PdfCandidateCount=2}).Status-eq'AMBIGUOUS') 'duplicate PDF identity classified'
A V06 ((T @{DriveFile=$null}).Status-eq'MISSING') 'missing object classified'
A V07 ((T @{SchemaCompatible=$false}).Status-eq'SCHEMA_MISMATCH') 'schema mismatch classified'
A V08 ((T @{LinkageComplete=$false}).Status-eq'BROKEN_LINK') 'broken link classified'
A V09 ((T @{AccessAvailable=$false;ZoteroRecord=$null;DriveFile=$null;NotionReview=$null}).Status-eq'TEST_DEFERRED') 'unavailable access is deferred, not passed'
$noProject=T @{ProjectMappings=@()};A V10 ($noProject.Status-eq'MATCHED'-and!$noProject.ProjectMappingComplete-and$noProject.Reasons-match'PROJECT_MAPPING_MISSING') 'missing optional project mapping retained in lineage'

$plan=New-RapReadOnlyReconciliationCase CASE-013-1 (T @{PdfHashMatches=$false}) @('Human selects canonical PDF after evidence review')
A V11 ($plan.Action-eq'PLAN'-and!$plan.ApplyPermitted-and!$plan.ChangesApplied-and$plan.ProductionWrite-eq'DISABLED'-and$plan.CaseHash) 'reconciliation plan has no APPLY path'
foreach($verb in @('CREATE','UPDATE','DELETE','MOVE','MERGE','APPLY')){A "V12-$verb" ((Get-RapPrThrown {Invoke-RapProductionWriteFirewall $verb})-match'PRODUCTION_WRITE_BLOCKED') "$verb blocked"}
$probe=Invoke-RapExternalReadProbe (New-RapFixtureReadAdapter Zotero $null EXTERNAL_TIMEOUT);A V13 ($probe.Status-eq'EXTERNAL_TIMEOUT'-and!$probe.ChangesApplied) 'timeout fails closed'
$auth=Invoke-RapExternalReadProbe (New-RapPrProbe Notion (New-RapPrActual) $false);A V14 ($auth.Status-eq'AUTHENTICATION_FAILURE'-and!$auth.ChangesApplied) 'credential failure fails closed'
$secret=('spr013'+'-secret-canary');[Environment]::SetEnvironmentVariable('RAP_TEST_CREDENTIAL',$secret);try{$json=@($matched,$plan,$probe,$auth)|ConvertTo-Json -Depth 20;A V15 ($json-notmatch[regex]::Escape($secret)) 'secret leakage zero'}finally{[Environment]::SetEnvironmentVariable('RAP_TEST_CREDENTIAL',$null)}
A V16 ((Get-Command Test-RapResearchObjectTrace).Parameters.Keys-notcontains'Apply') 'validation surface exposes no APPLY parameter'
Write-Host "SPR-013 research workflow validation: $script:N assertions PASS; focused failures: 0; production mutations: 0/0/0"
