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
    $state=[pscustomobject]@{Exceptions=@();Plans=@();Reconciliations=@();Verifications=@()}
    $operations=@{};$audits=[Collections.Generic.List[object]]::new()
    $dependencies=[pscustomobject]@{
        GetOperation={param($id)$operations[$id]}.GetNewClosure()
        ReadState={Copy-RapWorkflowFixture $state}.GetNewClosure()
        CommitWorkflow={param($newState,$operation,$audit)$state.Exceptions=@($newState.Exceptions);$state.Plans=@($newState.Plans);$state.Reconciliations=@($newState.Reconciliations);$state.Verifications=@($newState.Verifications);$operations[$operation.OperationId]=$operation;$audits.Add($audit)}.GetNewClosure()
    }
    [pscustomobject]@{State=$state;Operations=$operations;Audits=$audits;Dependencies=$dependencies}
}
