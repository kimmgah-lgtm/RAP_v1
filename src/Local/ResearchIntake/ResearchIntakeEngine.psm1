Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'ResearchIntakePersistence.psm1') -Force

function Copy-RapIntakeValue { param([AllowNull()]$Value) if($null-eq$Value){return $null};$Value|ConvertTo-Json -Depth 60|ConvertFrom-Json -Depth 60 }
function Get-RapIntakeHash { param([AllowNull()]$Value) $json=$Value|ConvertTo-Json -Depth 60 -Compress;[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($json))).ToLowerInvariant() }
function Assert-RapProjectId { param([string]$ProjectId) if($ProjectId-notmatch'^PR\d{3,6}$'){throw 'PROJECT_CONTEXT_AMBIGUOUS'} }
function Add-RapIntakeAudit { param($Store,[string]$Event,[string]$State,[hashtable]$Data) $entry=[pscustomobject][ordered]@{Sequence=$Store.Audit.Count+1;Event=$Event;State=$State;Timestamp=[DateTimeOffset]::UtcNow.ToString('o');Data=[pscustomobject]$Data;ProductionWrite='DISABLED'};$Store.Audit.Add($entry);if($Store.DatabasePath){[void](Save-RapResearchIntakeStore $Store)};$entry }
function Get-RapProperty { param($Object,[string]$Name) if($null-ne$Object-and$Object.PSObject.Properties[$Name]){$Object.$Name}else{$null} }
function Normalize-RapText { param([AllowNull()][string]$Text) if([string]::IsNullOrWhiteSpace($Text)){return ''};(($Text.Trim().ToLowerInvariant()-replace'[^\p{L}\p{Nd}]+',' ') -replace'\s+',' ').Trim() }
function Normalize-RapDoi {
    param([AllowNull()][string]$Doi)
    if([string]::IsNullOrWhiteSpace($Doi)){return $null}
    $value=$Doi.Trim().ToLowerInvariant()
    $value=$value-replace'^doi\s*:\s*',''
    $value=$value-replace'^https?://(dx\.)?doi\.org/',''
    $value=$value.Trim()
    if($value-notmatch'^10\.\d{4,9}/[-._;()/:a-z0-9]+$'-or$value-match'\s'){throw 'INVALID_DOI'}
    $value
}
function Get-RapMetadataSignature { param($Paper) "$(Normalize-RapText ([string](Get-RapProperty $Paper 'Title')))|$(Normalize-RapText ([string](Get-RapProperty $Paper 'FirstAuthor')))|$([string](Get-RapProperty $Paper 'Year'))" }
function Test-RapStrongMetadataConflict { param($A,$B) $titleA=Normalize-RapText ([string](Get-RapProperty $A 'Title'));$titleB=Normalize-RapText ([string](Get-RapProperty $B 'Title'));$authorA=Normalize-RapText ([string](Get-RapProperty $A 'FirstAuthor'));$authorB=Normalize-RapText ([string](Get-RapProperty $B 'FirstAuthor'));$yearA=[string](Get-RapProperty $A 'Year');$yearB=[string](Get-RapProperty $B 'Year');($titleA-and$titleB-and$titleA-cne$titleB)-or($authorA-and$authorB-and$authorA-cne$authorB)-or($yearA-and$yearB-and$yearA-cne$yearB) }

function New-RapResearchIntakeStore {
    [CmdletBinding()]param([Parameter(Mandatory)][string[]]$KnownProjectIds,[object[]]$ExistingCanonicalPapers=@(),[object[]]$ExistingZoteroItems=@(),[string]$DatabasePath='')
    foreach($project in $KnownProjectIds){Assert-RapProjectId $project}
    $s=[pscustomobject]@{PSTypeName='Rap.ResearchIntakeStore';SchemaVersion=1;DatabasePath=$(if($DatabasePath){[IO.Path]::GetFullPath($DatabasePath)}else{''});KnownProjectIds=@($KnownProjectIds|Sort-Object -Unique);Questions=@{};Searches=@{};Inbox=@{};Promotions=@{};IdentityResults=@{};LookupResults=@{};Decisions=@{};Lifecycles=@{};CanonicalPapers=@($ExistingCanonicalPapers|ForEach-Object{Copy-RapIntakeValue $_});ZoteroItems=@($ExistingZoteroItems|ForEach-Object{Copy-RapIntakeValue $_});Audit=[Collections.Generic.List[object]]::new();Counters=[pscustomobject]@{ZoteroCreateDecision=0;ZoteroMutation=0;DriveMutation=0;NotionMutation=0;LibraryIdAllocation=0;PaperReviewCreation=0};ProductionWrite='DISABLED';ProductionPilot='TEST_DEFERRED'};if($s.DatabasePath){[void](Save-RapResearchIntakeStore $s)};$s
}

function New-RapResearchQuestion {
    [CmdletBinding()]param([Parameter(Mandatory)]$Store,[Parameter(Mandatory)][string]$ProjectId,[Parameter(Mandatory)][ValidatePattern('^RQ-[A-Za-z0-9._:-]{1,120}$')][string]$ResearchQuestionId,[Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Question,[Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Provenance)
    Assert-RapProjectId $ProjectId;if($ProjectId-cnotin$Store.KnownProjectIds){throw 'UNKNOWN_PROJECT_ID'}
    if($Store.Questions.ContainsKey($ResearchQuestionId)){throw 'DUPLICATE_RESEARCH_QUESTION_ID'}
    $record=[pscustomobject]@{PSTypeName='Rap.ResearchQuestion';ProjectId=$ProjectId;ResearchQuestionId=$ResearchQuestionId;Question=$Question.Trim();Provenance=$Provenance;CreatedAt=[DateTimeOffset]::UtcNow.ToString('o');State='DEFINED';ProductionWrite='DISABLED'}
    $Store.Questions[$ResearchQuestionId]=$record;[void](Add-RapIntakeAudit $Store 'RESEARCH_QUESTION_DEFINED' 'DEFINED' @{ProjectId=$ProjectId;ResearchQuestionId=$ResearchQuestionId;Provenance=$Provenance});Copy-RapIntakeValue $record
}

function New-RapSearchRequest {
    [CmdletBinding()]param([Parameter(Mandatory)]$Store,[Parameter(Mandatory)][string]$ProjectId,[Parameter(Mandatory)][string]$ResearchQuestionId,[Parameter(Mandatory)][ValidateSet('QUICK','SYSTEMATIC')][string]$Mode,[Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Query,[hashtable]$Criteria=@{},[Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Provenance,[Parameter(Mandatory)][ValidatePattern('^SE-[A-Za-z0-9._:-]{1,120}$')][string]$SearchExecutionId)
    Assert-RapProjectId $ProjectId;if(-not$Store.Questions.ContainsKey($ResearchQuestionId)){throw 'UNKNOWN_RESEARCH_QUESTION'};$question=$Store.Questions[$ResearchQuestionId];if($question.ProjectId-cne$ProjectId){throw 'PROJECT_ID_SUBSTITUTION'}
    if($Mode-ceq'SYSTEMATIC'-and$Criteria.Count-eq0){throw 'SYSTEMATIC_CRITERIA_REQUIRED'}
    if($Store.Searches.ContainsKey($SearchExecutionId)){throw 'DUPLICATE_SEARCH_EXECUTION_ID'}
    [pscustomobject]@{PSTypeName='Rap.SearchRequest';ProjectId=$ProjectId;ResearchQuestionId=$ResearchQuestionId;Mode=$Mode;Query=$Query.Trim();Criteria=[pscustomobject]$Criteria;Provenance=$Provenance;SearchExecutionId=$SearchExecutionId;RequestedAt=[DateTimeOffset]::UtcNow.ToString('o');ProductionWrite='DISABLED'}
}

function Invoke-RapMockResearchSearch {
    [CmdletBinding()]param([Parameter(Mandatory)]$Store,[Parameter(Mandatory)]$SearchRequest,[Parameter(Mandatory)][object[]]$FixtureResults)
    if($SearchRequest.PSObject.TypeNames-cnotcontains'Rap.SearchRequest'){throw 'UNTRUSTED_SEARCH_REQUEST'}
    if($SearchRequest.Mode-cne'QUICK'){throw 'SEARCH_MODE_NOT_IMPLEMENTED'}
    if($Store.Searches.ContainsKey($SearchRequest.SearchExecutionId)){throw 'DUPLICATE_SEARCH_EXECUTION_ID'}
    $seen=@{};$results=@();$rank=0
    foreach($fixture in $FixtureResults){$rank++;$candidateId=[string](Get-RapProperty $fixture 'CandidateId');if($candidateId-notmatch'^C-[A-Za-z0-9._:-]{1,120}$'){throw 'INVALID_CANDIDATE_ID'};if($seen.ContainsKey($candidateId)){throw 'DUPLICATE_CANDIDATE_ID'};$seen[$candidateId]=$true
        $results+=[pscustomobject]@{PSTypeName='Rap.SearchResult';ProjectId=$SearchRequest.ProjectId;ResearchQuestionId=$SearchRequest.ResearchQuestionId;SearchExecutionId=$SearchRequest.SearchExecutionId;SearchMode=$SearchRequest.Mode;CandidateId=$candidateId;Rank=$rank;Title=[string](Get-RapProperty $fixture 'Title');FirstAuthor=[string](Get-RapProperty $fixture 'FirstAuthor');Year=[string](Get-RapProperty $fixture 'Year');Doi=[string](Get-RapProperty $fixture 'Doi');Pmid=[string](Get-RapProperty $fixture 'Pmid');Pmcid=[string](Get-RapProperty $fixture 'Pmcid');PublisherId=[string](Get-RapProperty $fixture 'PublisherId');Source=[string](Get-RapProperty $fixture 'Source');RetrievedAt=[DateTimeOffset]::UtcNow.ToString('o');Provenance=[string](Get-RapProperty $fixture 'Provenance');State='SEARCHED';ProductionWrite='DISABLED'}
    }
    $Store.Searches[$SearchRequest.SearchExecutionId]=[pscustomobject]@{Request=Copy-RapIntakeValue $SearchRequest;Results=@($results|ForEach-Object{Copy-RapIntakeValue $_});State='SEARCHED'}
    [void](Add-RapIntakeAudit $Store 'SEARCH_EXECUTED' 'SEARCHED' @{ProjectId=$SearchRequest.ProjectId;ResearchQuestionId=$SearchRequest.ResearchQuestionId;SearchExecutionId=$SearchRequest.SearchExecutionId;Mode=$SearchRequest.Mode;CandidateCount=$results.Count})
    @($results)
}

function Add-RapResearchInboxCandidates {
    [CmdletBinding()]param([Parameter(Mandatory)]$Store,[Parameter(Mandatory)][object[]]$SearchResults,[Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Reason)
    $added=@();foreach($result in $SearchResults){if($result.PSObject.TypeNames-cnotcontains'Rap.SearchResult'){throw 'ENTITY_BOUNDARY_VIOLATION'};if([string]::IsNullOrWhiteSpace([string]$result.Provenance)){throw 'MISSING_PROVENANCE'};if($Store.Inbox.ContainsKey($result.CandidateId)){throw 'DUPLICATE_CANDIDATE_ID'}
        $candidate=[pscustomobject]@{PSTypeName='Rap.ResearchInboxCandidate';ProjectId=$result.ProjectId;ResearchQuestionId=$result.ResearchQuestionId;SearchExecutionId=$result.SearchExecutionId;SearchMode=$result.SearchMode;CandidateId=$result.CandidateId;Title=$result.Title;FirstAuthor=$result.FirstAuthor;Year=$result.Year;Doi=$result.Doi;Pmid=$result.Pmid;Pmcid=$result.Pmcid;PublisherId=$result.PublisherId;Source=$result.Source;SearchRank=$result.Rank;InboxReason=$Reason;SearchProvenance=$result.Provenance;InboxedAt=[DateTimeOffset]::UtcNow.ToString('o');State='INBOXED';Stale=$false;ProductionWrite='DISABLED'}
        $Store.Inbox[$candidate.CandidateId]=$candidate;$Store.Lifecycles[$candidate.CandidateId]='INBOXED';$added+=Copy-RapIntakeValue $candidate;[void](Add-RapIntakeAudit $Store 'CANDIDATE_INBOXED' 'INBOXED' @{ProjectId=$candidate.ProjectId;ResearchQuestionId=$candidate.ResearchQuestionId;SearchExecutionId=$candidate.SearchExecutionId;CandidateId=$candidate.CandidateId;Reason=$Reason})
    };@($added)
}

function Promote-RapResearchInboxCandidate {
    [CmdletBinding()]param([Parameter(Mandatory)]$Store,[Parameter(Mandatory)][string]$ProjectId,[Parameter(Mandatory)][string]$ResearchQuestionId,[Parameter(Mandatory)][string]$CandidateId,[Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Researcher,[Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Provenance)
    Assert-RapProjectId $ProjectId;if(-not$Store.Inbox.ContainsKey($CandidateId)){throw 'UNKNOWN_INBOX_CANDIDATE'};$candidate=$Store.Inbox[$CandidateId]
    if($candidate.ProjectId-cne$ProjectId-or$candidate.ResearchQuestionId-cne$ResearchQuestionId){throw 'CANDIDATE_SUBSTITUTION'}
    if($candidate.Stale){throw 'STALE_CANDIDATE'};if([string]::IsNullOrWhiteSpace($Provenance)){throw 'MISSING_PROVENANCE'}
    if($Store.Promotions.ContainsKey($CandidateId)){$existing=$Store.Promotions[$CandidateId];if($existing.ProjectId-cne$ProjectId-or$existing.ResearchQuestionId-cne$ResearchQuestionId-or$existing.Researcher-cne$Researcher-or$existing.Provenance-cne$Provenance){throw 'PROMOTION_REPLAY_CONFLICT'};return $existing}
    if(@($Store.Promotions.Values|Where-Object{$_.ResearchQuestionId-ceq$ResearchQuestionId}).Count-ge1){throw 'PROMOTE_ONE_LIMIT_EXCEEDED'}
    $binding=[ordered]@{ProjectId=$ProjectId;ResearchQuestionId=$ResearchQuestionId;CandidateId=$CandidateId;CandidateIdentityHash=Get-RapIntakeHash ([ordered]@{Title=$candidate.Title;FirstAuthor=$candidate.FirstAuthor;Year=$candidate.Year;Doi=$candidate.Doi;Pmid=$candidate.Pmid;Pmcid=$candidate.Pmcid;PublisherId=$candidate.PublisherId});Researcher=$Researcher;Provenance=$Provenance}
    $promotion=[pscustomobject]@{PSTypeName='Rap.ResearchPromotion';ProjectId=$ProjectId;ResearchQuestionId=$ResearchQuestionId;CandidateId=$CandidateId;CandidateIdentityHash=$binding.CandidateIdentityHash;Researcher=$Researcher;Provenance=$Provenance;PromotedAt=[DateTimeOffset]::UtcNow.ToString('o');PromotionHash=Get-RapIntakeHash $binding;State='PROMOTED';ProductionWrite='DISABLED'}
    $Store.Promotions[$CandidateId]=$promotion;$candidate.State='PROMOTED';$Store.Lifecycles[$CandidateId]='PROMOTED';[void](Add-RapIntakeAudit $Store 'CANDIDATE_PROMOTED' 'PROMOTED' @{ProjectId=$ProjectId;ResearchQuestionId=$ResearchQuestionId;CandidateId=$CandidateId;Researcher=$Researcher;PromotionHash=$promotion.PromotionHash;Provenance=$Provenance});$promotion
}

function Resolve-RapCanonicalPaperIdentity {
    [CmdletBinding()]param([Parameter(Mandatory)]$Store,[Parameter(Mandatory)]$Promotion)
    if($Promotion.PSObject.TypeNames-cnotcontains'Rap.ResearchPromotion'){throw 'UNTRUSTED_PROMOTION'};if(-not$Store.Promotions.ContainsKey($Promotion.CandidateId)){throw 'UNTRUSTED_PROMOTION'};$persisted=$Store.Promotions[$Promotion.CandidateId];if($persisted.PromotionHash-cne$Promotion.PromotionHash){throw 'PROMOTION_BINDING_MISMATCH'}
    $candidate=$Store.Inbox[$Promotion.CandidateId];if($candidate.CandidateId-cne$Promotion.CandidateId-or$candidate.ProjectId-cne$Promotion.ProjectId-or$candidate.ResearchQuestionId-cne$Promotion.ResearchQuestionId){throw 'CANDIDATE_SUBSTITUTION'};$currentHash=Get-RapIntakeHash ([ordered]@{Title=$candidate.Title;FirstAuthor=$candidate.FirstAuthor;Year=$candidate.Year;Doi=$candidate.Doi;Pmid=$candidate.Pmid;Pmcid=$candidate.Pmcid;PublisherId=$candidate.PublisherId});if($currentHash-cne$Promotion.CandidateIdentityHash){throw 'CANDIDATE_SUBSTITUTION'};$Store.Lifecycles[$candidate.CandidateId]='IDENTITY_RESOLVING';if($Store.DatabasePath){[void](Save-RapResearchIntakeStore $Store)}
    try{$doi=Normalize-RapDoi $candidate.Doi}catch{return [pscustomobject]@{PSTypeName='Rap.IdentityResolution';CandidateId=$candidate.CandidateId;Status='INVALID';Authority='NONE';CanonicalKey=$null;NormalizedDoi=$null;Evidence=@('MALFORMED_DOI');State='BLOCKED';ProductionWrite='DISABLED'}}
    $pmid=Normalize-RapText $candidate.Pmid;$pmcid=Normalize-RapText $candidate.Pmcid;$publisher=Normalize-RapText $candidate.PublisherId;$signature=Get-RapMetadataSignature $candidate
    $authority=if($doi){'DOI'}elseif($pmid-or$pmcid){'STRONG_EXTERNAL_ID'}elseif($publisher){'PUBLISHER_SOURCE'}elseif($signature-notmatch'^\|\|$' -and $candidate.Title -and $candidate.FirstAuthor -and $candidate.Year){'TITLE_AUTHOR_YEAR'}else{'FUZZY_ONLY'}
    $key=switch($authority){'DOI'{"doi:$doi"};'STRONG_EXTERNAL_ID'{if($pmid){"pmid:$pmid"}else{"pmcid:$pmcid"}};'PUBLISHER_SOURCE'{"publisher:$publisher"};'TITLE_AUTHOR_YEAR'{"tay:$signature"};default{$null}}
    $status=if($authority-eq'FUZZY_ONLY'){'AMBIGUOUS'}else{'RESOLVED'};$state=if($status-eq'RESOLVED'){'IDENTITY_RESOLVED'}else{'AMBIGUOUS'}
    $resolution=[pscustomobject]@{PSTypeName='Rap.IdentityResolution';CandidateId=$candidate.CandidateId;ProjectId=$candidate.ProjectId;ResearchQuestionId=$candidate.ResearchQuestionId;Status=$status;Authority=$authority;CanonicalKey=$key;NormalizedDoi=$doi;Pmid=$pmid;Pmcid=$pmcid;PublisherId=$publisher;MetadataSignature=$signature;Evidence=@($authority);State=$state;ProductionWrite='DISABLED'}
    $Store.IdentityResults[$candidate.CandidateId]=$resolution;$Store.Lifecycles[$candidate.CandidateId]=$state;[void](Add-RapIntakeAudit $Store 'IDENTITY_RESOLVED' $state @{CandidateId=$candidate.CandidateId;Status=$status;Authority=$authority;CanonicalKey=$key;ObservedIdentifiers="doi=$doi;pmid=$pmid;pmcid=$pmcid;publisher=$publisher"});$resolution
}

function Get-RapPreZoteroDedupDecision {
    [CmdletBinding()]param([Parameter(Mandatory)]$Store,[Parameter(Mandatory)]$Promotion,[Parameter(Mandatory)]$IdentityResolution)
    if($Promotion.CandidateId-cne$IdentityResolution.CandidateId){throw 'CANDIDATE_SUBSTITUTION'}
    if($IdentityResolution.Status-cne'RESOLVED'){return [pscustomobject]@{PSTypeName='Rap.ZoteroDecision';CandidateId=$Promotion.CandidateId;Decision=$(if($IdentityResolution.Status-eq'INVALID'){'BLOCKED'}else{'AMBIGUOUS'});Reason=$IdentityResolution.Status;CanonicalKey=$null;ZoteroItemId=$null;State=$(if($IdentityResolution.Status-eq'INVALID'){'BLOCKED'}else{'AMBIGUOUS'});ProductionWrite='DISABLED';ChangesApplied=$false}}
    if($Store.Decisions.ContainsKey($Promotion.CandidateId)){return $Store.Decisions[$Promotion.CandidateId]}
    $candidate=$Store.Inbox[$Promotion.CandidateId];$canonicalMatches=@($Store.CanonicalPapers|Where-Object{[string]$_.CanonicalKey-ceq$IdentityResolution.CanonicalKey});$zoteroMatches=@($Store.ZoteroItems|Where-Object{[string]$_.CanonicalKey-ceq$IdentityResolution.CanonicalKey});$Store.Lifecycles[$Promotion.CandidateId]='DEDUP_CHECKED';$Store.LookupResults[$Promotion.CandidateId]=[pscustomobject]@{PSTypeName='Rap.IntakeLookupResult';CandidateId=$Promotion.CandidateId;CanonicalStatus=$(if($canonicalMatches.Count-eq0){'NONE'}elseif($canonicalMatches.Count-eq1){'EXACT_MATCH'}else{'MULTIPLE_MATCHES'});ZoteroStatus=$(if($zoteroMatches.Count-eq0){'NONE'}elseif($zoteroMatches.Count-eq1){'EXACT_MATCH'}else{'MULTIPLE_MATCHES'});CanonicalCount=$canonicalMatches.Count;ZoteroCount=$zoteroMatches.Count;ReadOnly=$true;ProductionWrite='DISABLED'};if($Store.DatabasePath){[void](Save-RapResearchIntakeStore $Store)}
    $allExisting=@($Store.CanonicalPapers)+@($Store.ZoteroItems);$conflicts=@($canonicalMatches+$zoteroMatches|Where-Object{Test-RapStrongMetadataConflict $candidate $_});$strongConflicts=@($allExisting|Where-Object{(($IdentityResolution.Pmid-and([string](Get-RapProperty $_ 'Pmid')-eq$IdentityResolution.Pmid))-or($IdentityResolution.Pmcid-and([string](Get-RapProperty $_ 'Pmcid')-eq$IdentityResolution.Pmcid)))-and([string]$_.CanonicalKey-cne$IdentityResolution.CanonicalKey)});$titleConflicts=@();if($IdentityResolution.Authority-eq'TITLE_AUTHOR_YEAR'){$title=Normalize-RapText $candidate.Title;$titleConflicts=@($allExisting|Where-Object{(Normalize-RapText ([string](Get-RapProperty $_ 'Title')))-eq$title-and[string]$_.CanonicalKey-cne$IdentityResolution.CanonicalKey})}
    if($conflicts.Count-gt0-or$strongConflicts.Count-gt0-or$titleConflicts.Count-gt0){$decisionName='IDENTITY_CONFLICT';$reason='IDENTIFIER_METADATA_CONFLICT';$zoteroId=$null}
    elseif($canonicalMatches.Count-gt1-or$zoteroMatches.Count-gt1){$decisionName='AMBIGUOUS';$reason='MULTIPLE_EXISTING_MATCHES';$zoteroId=$null}
    elseif($canonicalMatches.Count-eq1-and$zoteroMatches.Count-eq0){$decisionName='BLOCKED';$reason='CANONICAL_EXISTS_ZOTERO_MAPPING_MISSING';$zoteroId=$null}
    elseif($canonicalMatches.Count-eq0-and$zoteroMatches.Count-eq1){$decisionName='BLOCKED';$reason='ZOTERO_EXISTS_CANONICAL_MAPPING_MISSING';$zoteroId=$null}
    elseif($zoteroMatches.Count-eq1){$decisionName='REUSE_EXISTING';$reason='CANONICAL_AND_ZOTERO_MATCH';$zoteroId=[string]$zoteroMatches[0].ZoteroItemId}
    else{$decisionName='CREATE_CANDIDATE';$reason='NO_EXISTING_CANONICAL_OR_ZOTERO_MATCH';$zoteroId=$null;$Store.Counters.ZoteroCreateDecision++}
    $decision=[pscustomobject]@{PSTypeName='Rap.ZoteroDecision';ProjectId=$Promotion.ProjectId;ResearchQuestionId=$Promotion.ResearchQuestionId;CandidateId=$Promotion.CandidateId;PromotionHash=$Promotion.PromotionHash;Decision=$decisionName;Reason=$reason;CanonicalKey=$IdentityResolution.CanonicalKey;CanonicalMatches=$canonicalMatches.Count;ZoteroMatches=$zoteroMatches.Count;ZoteroItemId=$zoteroId;State=$(if($decisionName-in@('CREATE_CANDIDATE','REUSE_EXISTING')){$decisionName}else{$decisionName});ProductionWrite='DISABLED';ChangesApplied=$false}
    $Store.Decisions[$Promotion.CandidateId]=$decision;$Store.Lifecycles[$Promotion.CandidateId]=$decision.State;[void](Add-RapIntakeAudit $Store 'PRE_ZOTERO_DEDUP_DECIDED' $decision.State @{CandidateId=$Promotion.CandidateId;CanonicalKey=$decision.CanonicalKey;CanonicalMatches=$decision.CanonicalMatches;ZoteroMatches=$decision.ZoteroMatches;Decision=$decision.Decision;Reason=$decision.Reason});$decision
}

function Invoke-RapResearchIntakeDecision {
    [CmdletBinding()]param([Parameter(Mandatory)]$Store,[Parameter(Mandatory)]$Promotion)
    if($Store.ProductionWrite-cne'DISABLED'-or$Store.ProductionPilot-cne'TEST_DEFERRED'){throw 'UNSAFE_RESEARCH_INTAKE_MODE'}
    $identity=Resolve-RapCanonicalPaperIdentity $Store $Promotion;$decision=Get-RapPreZoteroDedupDecision $Store $Promotion $identity
    [pscustomobject]@{Identity=$identity;Decision=$decision;ProductionWrite='DISABLED';ProductionPilot='TEST_DEFERRED';ProductionMutations=[pscustomobject]@{Zotero=$Store.Counters.ZoteroMutation;Drive=$Store.Counters.DriveMutation;Notion=$Store.Counters.NotionMutation};LibraryIdAllocations=$Store.Counters.LibraryIdAllocation;PaperReviewsCreated=$Store.Counters.PaperReviewCreation}
}
function Get-RapResearchIntakeAudit { [CmdletBinding()]param([Parameter(Mandatory)]$Store) @($Store.Audit|ForEach-Object{Copy-RapIntakeValue $_}) }
function Get-RapResearchIntakeRecoveryStatus {[CmdletBinding()]param([Parameter(Mandatory)]$Store,[Parameter(Mandatory)][string]$CandidateId)if(-not$Store.Lifecycles.ContainsKey($CandidateId)){throw 'UNKNOWN_INBOX_CANDIDATE'};$s=[string]$Store.Lifecycles[$CandidateId];[pscustomobject]@{CandidateId=$CandidateId;PersistedState=$s;Status=$(if($s-in@('IDENTITY_RESOLVING','DEDUP_CHECKED')){'RECOVERY_REQUIRED'}elseif($s-in@('CREATE_CANDIDATE','REUSE_EXISTING','AMBIGUOUS','IDENTITY_CONFLICT','BLOCKED')){'ALREADY_COMPLETED'}else{'RESUMABLE'});AutomaticAdvance=$false;ProductionWrite='DISABLED'} }
function Invoke-RapResearchIntakeReadOnlyLookup {[CmdletBinding()]param([Parameter(Mandatory)]$Store,[Parameter(Mandatory)][ValidateSet('PASS','TIMEOUT','NETWORK_FAILURE','MALFORMED','AUTH_FAILURE','PERMISSION_AMBIGUITY','PARTIAL')][string]$Outcome,[object[]]$CanonicalResults=@(),[object[]]$ZoteroResults=@())if($Store.ProductionWrite-cne'DISABLED'){throw 'UNSAFE_RESEARCH_INTAKE_MODE'};if($Outcome-cne'PASS'){return [pscustomobject]@{Status='LOOKUP_FAILED';Reason=$Outcome;CanonicalStatus='UNKNOWN';ZoteroStatus='UNKNOWN';ChangesApplied=$false;ProductionWrite='DISABLED'}};foreach($x in @($CanonicalResults+$ZoteroResults)){if(-not$x.PSObject.Properties['CanonicalKey']-or[string]::IsNullOrWhiteSpace([string]$x.CanonicalKey)){return [pscustomobject]@{Status='LOOKUP_FAILED';Reason='MALFORMED';CanonicalStatus='UNKNOWN';ZoteroStatus='UNKNOWN';ChangesApplied=$false;ProductionWrite='DISABLED'}}};$Store.CanonicalPapers=@($CanonicalResults|ForEach-Object{Copy-RapIntakeValue $_});$Store.ZoteroItems=@($ZoteroResults|ForEach-Object{Copy-RapIntakeValue $_});if($Store.DatabasePath){[void](Save-RapResearchIntakeStore $Store)};[pscustomobject]@{Status='PASS';Reason='READ_ONLY_FIXTURE';CanonicalStatus=$(if($CanonicalResults.Count){'AVAILABLE'}else{'NONE'});ZoteroStatus=$(if($ZoteroResults.Count){'AVAILABLE'}else{'NONE'});ChangesApplied=$false;ProductionWrite='DISABLED'} }

Export-ModuleMember -Function New-RapResearchIntakeStore,New-RapResearchQuestion,New-RapSearchRequest,Invoke-RapMockResearchSearch,Add-RapResearchInboxCandidates,Promote-RapResearchInboxCandidate,Resolve-RapCanonicalPaperIdentity,Get-RapPreZoteroDedupDecision,Invoke-RapResearchIntakeDecision,Get-RapResearchIntakeAudit,Initialize-RapResearchIntakeStore,Save-RapResearchIntakeStore,Open-RapResearchIntakeStore,Test-RapResearchIntakeStoreIntegrity,Get-RapResearchIntakeRecoveryStatus,Invoke-RapResearchIntakeReadOnlyLookup
