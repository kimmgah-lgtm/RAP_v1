Set-StrictMode -Version Latest
function New-RapBootstrapTestHarness {
    [CmdletBinding()]param()
    $state=[ordered]@{Mode='Bootstrap';NextSequence=1;Ids=@{};Master=@{};Notion=@{};Backups=0;Resets=0;Assignments=0;Queue=0;Dashboard=0}
    $items=@([pscustomobject]@{ItemKey='A0000001';Title='Paper A'},[pscustomobject]@{ItemKey='B0000002';Title='Paper B'})
    $dependencies=[pscustomobject]@{
        Reset={ $state.Resets++;[pscustomobject]@{Status='SUCCESS';ResearchAssetsPreserved=$true} }.GetNewClosure()
        ReadItems={ @($items) }.GetNewClosure()
        VerifyDrive={param($values)[pscustomobject]@{Status='PASS';Warnings=@();Count=@($values).Count}}
        GetNextLibrarySequence={ $state.NextSequence }.GetNewClosure()
        GetLibraryId={param($item)if($state.Ids.ContainsKey($item.ItemKey)){$state.Ids[$item.ItemKey]}else{$null}}.GetNewClosure()
        Backup={param($plan)$state.Backups++;[pscustomobject]@{Id="SNAP-$($state.Backups)";Count=@($plan).Count}}.GetNewClosure()
        AssignLibraryId={param($entry)if(-not $state.Ids.ContainsKey($entry.ItemKey)){$state.Ids[$entry.ItemKey]=$entry.LibraryId;$state.Assignments++;$number=[int]($entry.LibraryId -replace '\D','');if($number -ge $state.NextSequence){$state.NextSequence=$number+1}}}.GetNewClosure()
        UpsertMaster={param($entry)$state.Master[$entry.LibraryId]=$entry.ItemKey}.GetNewClosure()
        UpsertNotion={param($entry)$state.Notion[$entry.LibraryId]="PAGE-$($entry.LibraryId)"}.GetNewClosure()
        VerifyFinal={param($results)[pscustomobject]@{Status=$(if(@($results|Where-Object Status -ne 'SUCCESS').Count -eq 0){'PASS'}else{'FAIL'});Warnings=@()}}
        SetMode={param($mode)$state.Mode=$mode}.GetNewClosure()
        GetMode={ $state.Mode }.GetNewClosure()
        QueueAiReview={param($entry)$state.Queue++}.GetNewClosure()
        UpdateDashboard={param($entry)$state.Dashboard++}.GetNewClosure()
    }
    [pscustomobject]@{State=$state;Items=$items;Dependencies=$dependencies}
}
