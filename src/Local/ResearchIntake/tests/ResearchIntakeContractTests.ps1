. (Join-Path $PSScriptRoot 'TestHarness.ps1')
$script:N=0
function A([string]$id,[bool]$ok,[string]$message){$script:N++;if(!$ok){throw "$id failed: $message"};Write-Host "$id PASS $message"}
$c=New-RapIntakeContext
A CT01 ($c.Request.Mode-eq'QUICK'-and@($c.Request.Criteria.PSObject.Properties).Count-eq0) 'unified search request supports QUICK with extensible criteria'
A CT02 ($c.Search[0].PSObject.TypeNames-ccontains'Rap.SearchResult') 'search result has a distinct entity type'
A CT03 ($c.Store.Inbox['C-001'].PSObject.TypeNames-ccontains'Rap.ResearchInboxCandidate') 'inbox candidate has a distinct entity type'
A CT04 ($c.Search[0].State-eq'SEARCHED'-and$c.Store.Inbox['C-001'].State-eq'INBOXED') 'SEARCHED to INBOXED state boundary preserved'
A CT05 ($c.Store.Counters.ZoteroCreateDecision-eq0-and$c.Store.Counters.ZoteroMutation-eq0-and$c.Store.Counters.LibraryIdAllocation-eq0-and$c.Store.Counters.PaperReviewCreation-eq0) 'search and inbox produce no canonical side effect'
$p=Promote-RapFixture $c;$r=Invoke-RapResearchIntakeDecision $c.Store $p
A CT06 ($p.PSObject.TypeNames-ccontains'Rap.ResearchPromotion'-and$r.Decision.PSObject.TypeNames-ccontains'Rap.ZoteroDecision') 'promotion and decision remain separate typed entities'
A CT07 ($r.Identity.State-eq'IDENTITY_RESOLVED'-and$r.Decision.State-eq'CREATE_CANDIDATE') 'valid state path reaches CREATE_CANDIDATE decision'
A CT08 ($r.Decision.ChangesApplied-eq$false-and$r.ProductionWrite-eq'DISABLED'-and$r.ProductionPilot-eq'TEST_DEFERRED') 'decision is non-mutating and production-disabled'
$events=@(Get-RapResearchIntakeAudit $c.Store)
A CT09 (($events.Event-join',')-match'RESEARCH_QUESTION_DEFINED.*SEARCH_EXECUTED.*CANDIDATE_INBOXED.*CANDIDATE_PROMOTED.*IDENTITY_RESOLVED.*PRE_ZOTERO_DEDUP_DECIDED') 'end-to-end lineage is reconstructable'
A CT10 ((Get-RapIntakeThrown {New-RapSearchRequest $c.Store PR999 RQ-015 QUICK x @{} p SE-X})-match'PROJECT_ID_SUBSTITUTION') 'Project_ID substitution blocked'
if($script:N-ne10){throw "Expected 10 contract assertions, got $script:N"};Write-Host 'SPR-015 Research Intake contract tests: CT01-CT10 10/10 PASS'
