Set-StrictMode -Version Latest

function New-RapWorkflowFixture {
    [pscustomobject]@{
        ProjectId='PR001';LibraryId='LIB:L000001'
        Zotero=[pscustomobject]@{Exists=$true;SourceKey='ZOT-1';Registrations=@('ZOT-1')}
        NotionReview=[pscustomobject]@{Exists=$true;PageId='NOTION-1';CreationSource='AUTOMATION';Registered=$true}
        LibraryLinkage=[pscustomobject]@{Valid=$true;LinkedLibraryId='LIB:L000001'}
        Pdf=[pscustomobject]@{Exists=$true;ExpectedHash='pdf-hash';CurrentHash='pdf-hash'}
        ProjectLinkage=[pscustomobject]@{Valid=$true;LinkedProjectId='PR001'}
        EditState=[pscustomobject]@{AutomationManualConflict=$false;ConflictingFields=@()}
        CodingState=[pscustomobject]@{AiResearcherConflict=$false;ConflictingFields=@()}
        OrphanReferences=@()
        VersionState=[pscustomobject]@{SourceVersion=1;DerivedVersion=1}
        Links=@([pscustomobject]@{LinkId='LINK-1';Target='fixture://valid';Reachable=$true})
        UnknownSignals=@()
        HumanOwned=[pscustomobject]@{Introduction='Researcher text';Discussion='Researcher discussion';ReviewerMemo='Keep'}
        ResearcherConfirmed=[pscustomobject]@{Outcome='OUT-1';Decision='INCLUDE'}
    }
}

function Copy-RapWorkflowFixture {param($Value)$Value|ConvertTo-Json -Depth 80|ConvertFrom-Json -Depth 80}

function New-RapMemoryWorkflowDependencies {
    param([string[]]$AuthorizedResearchers=@('researcher:kim'))
    $state=[pscustomobject]@{Exceptions=@();Plans=@();Reconciliations=@();Verifications=@();CaseStatus=@();RetainedAlternatives=@()}
    $operations=@{};$audits=[Collections.Generic.List[object]]::new();$events=[Collections.Generic.List[object]]::new()
    $dependencies=[pscustomobject]@{
        GetOperation={param($id)$operations[$id]}.GetNewClosure()
        ReadState={Copy-RapWorkflowFixture $state}.GetNewClosure()
        CommitWorkflow={param($newState,$operation,$audit,$lifecycle)foreach($name in @('Exceptions','Plans','Reconciliations','Verifications','CaseStatus','RetainedAlternatives')){if($newState.PSObject.Properties[$name]){$state.$name=@($newState.$name)}};$operations[$operation.OperationId]=$operation;$audits.Add($audit);foreach($event in @($lifecycle)){if($null-ne$event){$events.Add($event)}}}.GetNewClosure()
        RecordFailure={param($event)$events.Add($event)}.GetNewClosure()
        ReadEvents={@($events|ForEach-Object{Copy-RapWorkflowFixture $_})}.GetNewClosure()
        AuthorizedResearchers=@($AuthorizedResearchers)
    }
    [pscustomobject]@{State=$state;Operations=$operations;Audits=$audits;Events=$events;Dependencies=$dependencies}
}

# SPR-011 Turn E fixture: clean snapshot plus a normalized Evidence Graph lineage projection
# (review evidence and Meta Coding evidence depend on the canonical PDF; Synthesis depends on
# the Meta Coding evidence and on the source version; Output depends on Synthesis).
function New-RapWorkflowTurnEFixture {
    $x=New-RapWorkflowFixture
    $x|Add-Member -NotePropertyName AutomationRuns -NotePropertyValue @([pscustomobject]@{RunId='RUN-1';ExitCode=0;Status='SUCCEEDED';ErrorEvidence=@()})
    $x|Add-Member -NotePropertyName Dependents -NotePropertyValue @(
        [pscustomobject]@{ArtifactId='REVIEW-EV-1';ArtifactType='REVIEW_EVIDENCE';Requires=@('PDF');Upstream=@();Status='CURRENT';BasisPdfHash='pdf-hash';BasisVersion=1},
        [pscustomobject]@{ArtifactId='CODING-EV-1';ArtifactType='META_CODING_EVIDENCE';Requires=@('PDF');Upstream=@();Status='CURRENT';BasisPdfHash='pdf-hash';BasisVersion=1},
        [pscustomobject]@{ArtifactId='SYNTH-1';ArtifactType='SYNTHESIS';Requires=@('SOURCE_VERSION');Upstream=@('CODING-EV-1');Status='CURRENT';BasisPdfHash=$null;BasisVersion=1},
        [pscustomobject]@{ArtifactId='OUTPUT-1';ArtifactType='RESEARCH_OUTPUT';Requires=@();Upstream=@('SYNTH-1');Status='CURRENT';BasisPdfHash=$null;BasisVersion=1}
    )
    $x.CodingState|Add-Member -NotePropertyName AiSuggestions -NotePropertyValue @()
    $x.CodingState|Add-Member -NotePropertyName ConfirmationProvenance -NotePropertyValue ([pscustomobject]@{ConfirmedBy='researcher:kim';ConfirmedAt='2026-09-20T09:00:00+09:00';Method='MANUAL_CONFIRMATION'})
    return $x
}
