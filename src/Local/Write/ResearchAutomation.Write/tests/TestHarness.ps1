Set-StrictMode -Version Latest
function New-RapWriteTestHarness {
    param([string]$AuditPath)
    $state=[pscustomobject]@{Item=[pscustomobject]@{key='ITEM0001';version=1;data=[pscustomobject]@{key='ITEM0001';itemType='journalArticle';title='Original';extra='';tags=@();collections=@()}};Children=[Collections.Generic.List[object]]::new();FailVerification=$false;PatchCount=0;DeleteCount=0;Queue=[Collections.Generic.List[object]]::new();Events=[Collections.Generic.List[object]]::new()}
    $transport={param($request)
        if($request.Method -eq 'GET' -and $request.Uri -match '/groups/999$'){return [pscustomobject]@{data=[pscustomobject]@{name='RAP Sandbox Library'}}}
        if($request.Method -eq 'GET' -and $request.Uri -match '/items/ITEM0001/children'){return @($state.Children|ForEach-Object{$_|ConvertTo-Json -Depth 20|ConvertFrom-Json -Depth 20})}
        if($request.Method -eq 'GET' -and $request.Uri -match '/items/ITEM0001$'){$copy=$state.Item|ConvertTo-Json -Depth 20|ConvertFrom-Json -Depth 20;if($state.FailVerification -and $state.PatchCount -gt 0){$copy.data.extra='VERIFICATION_MISMATCH';$state.FailVerification=$false};return $copy}
        if($request.Method -eq 'GET' -and $request.Uri -match '/items/BADKEY00$'){throw '404 Not Found'}
        if($request.Method -eq 'PATCH' -and $request.Uri -match '/items/ITEM0001$'){$body=$request.Body|ConvertFrom-Json -Depth 30;$state.Item.data=$body;$state.Item.version++;$state.PatchCount++;return $null}
        if($request.Method -eq 'POST' -and $request.Uri -match '/items$'){$body=@($request.Body|ConvertFrom-Json -Depth 30)[0];$child=[pscustomobject]@{key='LINK0001';version=1;data=$body};$state.Children.Add($child);return [pscustomobject]@{successful=[pscustomobject]@{'0'=[pscustomobject]@{key='LINK0001'}}}}
        if($request.Method -eq 'DELETE' -and $request.Uri -match '/items/LINK0001$'){$state.DeleteCount++;$match=@($state.Children|Where-Object key -eq 'LINK0001');if($match.Count -ne 1 -or $match[0].data.note -notmatch '^RAP_OperationID:'){throw 'Unowned attachment delete refused'};$state.Children.Clear();return $null}
        throw "Unexpected request: $($request.Method) $($request.Uri)"
    }.GetNewClosure()
    $queue={param($record)$state.Queue.Add($record)}.GetNewClosure();$events={param($record)$state.Events.Add($record)}.GetNewClosure()
    $context=New-RapSandboxWriteContext -SandboxLibraryId 999 -ApiKey 'test-key' -AuditPath $AuditPath -Transport $transport -QueueSink $queue -EventSink $events
    [pscustomobject]@{State=$state;Context=$context}
}

