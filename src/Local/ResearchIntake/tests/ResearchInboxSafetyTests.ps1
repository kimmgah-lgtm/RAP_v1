. (Join-Path $PSScriptRoot 'TestHarness.ps1')
$script:N=0
function A([string]$id,[bool]$ok,[string]$message){$script:N++;if(!$ok){throw "$id failed: $message"};Write-Host "$id PASS $message"}
$c=New-RapIntakeContext -Results @((New-RapIntakeFixture C-A),(New-RapIntakeFixture C-B '10.1234/rap.002' 'Second Paper' 'Lee' '2025'))
A RI01 ($c.Store.Counters.ZoteroCreateDecision-eq0-and$c.Store.Counters.ZoteroMutation-eq0) 'search only has zero Zotero decision and mutation'
A RI02 ($c.Store.Counters.LibraryIdAllocation-eq0) 'search only allocates no Library_ID'
A RI03 ($c.Store.Counters.PaperReviewCreation-eq0) 'search only creates no Paper Review'
A RI04 ($c.Store.Decisions.Count-eq0-and$c.Store.Inbox.Count-eq2) 'inbox insertion does not canonicalize'
A RI05 ($c.Store.Inbox['C-B'].State-eq'INBOXED'-and$c.Store.Counters.DriveMutation-eq0-and$c.Store.Counters.NotionMutation-eq0) 'non-promoted candidate has zero downstream side effect'
$p=Promote-RapFixture $c C-A;$c.Store.Inbox['C-A'].CandidateId='C-B';A RI06 ((Get-RapIntakeThrown {Resolve-RapCanonicalPaperIdentity $c.Store $p})-match'CANDIDATE_SUBSTITUTION') 'promoted candidate cannot be substituted'
A RI07 ((Get-RapIntakeThrown {New-RapResearchQuestion $c.Store PR999 RQ-X x p})-match'UNKNOWN_PROJECT_ID') 'unknown Project_ID blocked'
A RI08 ((Get-RapIntakeThrown {New-RapResearchQuestion $c.Store ambiguous RQ-Y x p})-match'PROJECT_CONTEXT_AMBIGUOUS') 'ambiguous Project_ID blocked'
if($script:N-ne8){throw "Expected 8 inbox safety assertions, got $script:N"};Write-Host 'SPR-015 Research Inbox safety: RI01-RI08 8/8 PASS; production mutations: 0/0/0'
