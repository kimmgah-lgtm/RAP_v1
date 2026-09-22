Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'LibraryScanner.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'BootstrapReport.psm1') -Force

function Assert-RapBootstrapDependencies {
    param([Parameter(Mandatory)]$Dependencies,[Parameter(Mandatory)][string[]]$Names)
    foreach($name in $Names){if($null -eq $Dependencies.PSObject.Properties[$name] -or $Dependencies.$name -isnot [scriptblock]){throw "Bootstrap dependency must be a script block: $name"}}
}

function Invoke-RapProductionBootstrap {
    <#
    .SYNOPSIS Runs the approved production bootstrap pipeline through injected boundaries.
    .DESCRIPTION A dry run has no side effects. Execution requires the exact approval token, performs the safe reset first, rescans, backs up, applies idempotent upserts, verifies, and switches to Live only after all checks pass.
    .PARAMETER Dependencies Required connector and persistence script blocks.
    .PARAMETER DryRun Produces a plan without reset, backup, writes, or mode changes.
    .PARAMETER ApprovalToken Exact token APPROVE_PRODUCTION_BOOTSTRAP.
    .OUTPUTS Immutable bootstrap report object.
    #>
    [CmdletBinding()]param([Parameter(Mandatory)]$Dependencies,[switch]$DryRun,[string]$ApprovalToken)
    $required=@('Reset','ReadItems','VerifyDrive','GetNextLibrarySequence','GetLibraryId','Backup','AssignLibraryId','UpsertMaster','UpsertNotion','VerifyFinal','SetMode')
    Assert-RapBootstrapDependencies $Dependencies $required
    if(-not $DryRun -and $ApprovalToken -ne 'APPROVE_PRODUCTION_BOOTSTRAP'){throw 'Bootstrap execution requires the exact approval token.'}
    if(-not $DryRun){$reset=& $Dependencies.Reset;if($null -eq $reset -or $reset.Status -ne 'SUCCESS' -or -not $reset.ResearchAssetsPreserved){throw 'Production Clean Reset did not complete safely.'}}
    $operationId=[guid]::NewGuid().ToString();$items=@(Invoke-RapLibraryScan $Dependencies.ReadItems);$integrity=& $Dependencies.VerifyDrive $items
    if($null -eq $integrity -or $integrity.Status -ne 'PASS'){$warnings=if($null -ne $integrity -and $null -ne $integrity.PSObject.Properties['Warnings']){@($integrity.Warnings)}else{@('Drive integrity verification failed.')};return New-RapBootstrapReport $operationId 'INTEGRITY_FAILED' @() $warnings 'Bootstrap'}
    $sequence=[int](& $Dependencies.GetNextLibrarySequence)
    $plan=@($items|ForEach-Object{$existing=& $Dependencies.GetLibraryId $_;if([string]::IsNullOrWhiteSpace([string]$existing)){$id='LIB:L{0:D6}' -f $sequence;$sequence++;$state='PLANNED'}else{$id=[string]$existing;$state='ALREADY_EXISTS'};[pscustomobject]@{Source=$_;ItemKey=$_.ItemKey;LibraryId=$id;Status=$state}})
    if($DryRun){return New-RapBootstrapReport $operationId 'DRY_RUN' $plan @() 'Bootstrap'}
    $snapshot=& $Dependencies.Backup $plan;if($null -eq $snapshot){throw 'Backup snapshot was not created.'};$results=[Collections.Generic.List[object]]::new()
    foreach($entry in $plan){try{if($entry.Status -ne 'ALREADY_EXISTS'){& $Dependencies.AssignLibraryId $entry};& $Dependencies.UpsertMaster $entry;& $Dependencies.UpsertNotion $entry;$results.Add([pscustomobject]@{ItemKey=$entry.ItemKey;LibraryId=$entry.LibraryId;Status='SUCCESS'})}catch{$results.Add([pscustomobject]@{ItemKey=$entry.ItemKey;LibraryId=$entry.LibraryId;Status='FAILED';Reason=$_.Exception.Message})}}
    $final=& $Dependencies.VerifyFinal $results.ToArray();if(@($results|Where-Object Status -eq 'FAILED').Count -gt 0 -or $null -eq $final -or $final.Status -ne 'PASS'){$warnings=if($null -ne $final -and $null -ne $final.PSObject.Properties['Warnings']){@($final.Warnings)}else{@('Final verification failed.')};return New-RapBootstrapReport $operationId 'VERIFICATION_FAILED' $results.ToArray() $warnings 'Bootstrap'}
    & $Dependencies.SetMode 'Live';New-RapBootstrapReport $operationId 'PASS' $results.ToArray() @() 'Live'
}

function Invoke-RapLivePaper {
    <#
    .SYNOPSIS Processes one newly detected paper in Live mode.
    .DESCRIPTION Verifies Drive, reuses or assigns a Library_ID, idempotently upserts Master and Notion records, queues AI review, and refreshes the dashboard.
    .PARAMETER Item Normalized Zotero item.
    .PARAMETER Dependencies Required connector and persistence script blocks.
    .OUTPUTS Item processing status.
    #>
    [CmdletBinding()]param([Parameter(Mandatory)]$Item,[Parameter(Mandatory)]$Dependencies)
    Assert-RapBootstrapDependencies $Dependencies @('GetMode','VerifyDrive','GetLibraryId','GetNextLibrarySequence','AssignLibraryId','UpsertMaster','UpsertNotion','QueueAiReview','UpdateDashboard')
    if((& $Dependencies.GetMode) -ne 'Live'){throw 'Live paper processing requires Live mode.'};$integrity=& $Dependencies.VerifyDrive @($Item);if($null -eq $integrity -or $integrity.Status -ne 'PASS'){throw 'The paper failed Drive integrity verification.'}
    $libraryId=& $Dependencies.GetLibraryId $Item;$entry=[pscustomobject]@{Source=$Item;ItemKey=$Item.ItemKey;LibraryId=$libraryId;Status='ALREADY_EXISTS'}
    if([string]::IsNullOrWhiteSpace([string]$libraryId)){$entry.LibraryId='LIB:L{0:D6}' -f [int](& $Dependencies.GetNextLibrarySequence);$entry.Status='PLANNED';& $Dependencies.AssignLibraryId $entry}
    & $Dependencies.UpsertMaster $entry;& $Dependencies.UpsertNotion $entry;& $Dependencies.QueueAiReview $entry;& $Dependencies.UpdateDashboard $entry
    [pscustomobject]@{Status='PASS';Mode='Live';ItemKey=$entry.ItemKey;LibraryId=$entry.LibraryId}
}
Export-ModuleMember -Function Invoke-RapProductionBootstrap,Invoke-RapLivePaper
