Set-StrictMode -Version Latest

$script:RapExceptionTaxonomy = @(
    [pscustomobject]@{ ExceptionClass='ZOTERO_SOURCE_DELETED'; DefaultResolution='BLOCKED'; Severity='P1'; Component='ZOTERO' },
    [pscustomobject]@{ ExceptionClass='DUPLICATE_BIBLIOGRAPHIC_REGISTRATION'; DefaultResolution='HUMAN_REVIEW_REQUIRED'; Severity='P1'; Component='BIBLIOGRAPHY' },
    [pscustomobject]@{ ExceptionClass='NOTION_REVIEW_MISSING'; DefaultResolution='HUMAN_REVIEW_REQUIRED'; Severity='P2'; Component='NOTION_REVIEW' },
    [pscustomobject]@{ ExceptionClass='MANUALLY_CREATED_NOTION_REVIEW'; DefaultResolution='HUMAN_REVIEW_REQUIRED'; Severity='P2'; Component='NOTION_REVIEW' },
    [pscustomobject]@{ ExceptionClass='LIBRARY_ID_LINKAGE_BROKEN'; DefaultResolution='BLOCKED'; Severity='P1'; Component='IDENTITY' },
    [pscustomobject]@{ ExceptionClass='PDF_MISSING_OR_REPLACED'; DefaultResolution='HUMAN_REVIEW_REQUIRED'; Severity='P1'; Component='PDF' },
    [pscustomobject]@{ ExceptionClass='PROJECT_LINKAGE_INCONSISTENCY'; DefaultResolution='HUMAN_REVIEW_REQUIRED'; Severity='P1'; Component='PROJECT' },
    [pscustomobject]@{ ExceptionClass='AUTOMATION_MANUAL_EDIT_CONFLICT'; DefaultResolution='HUMAN_REVIEW_REQUIRED'; Severity='P1'; Component='EDIT_OWNERSHIP' },
    [pscustomobject]@{ ExceptionClass='AI_ASSISTED_RESEARCHER_CONFIRMED_CONFLICT'; DefaultResolution='HUMAN_REVIEW_REQUIRED'; Severity='P1'; Component='META_CODING' },
    [pscustomobject]@{ ExceptionClass='ORPHAN'; DefaultResolution='HUMAN_REVIEW_REQUIRED'; Severity='P2'; Component='LINKAGE' },
    [pscustomobject]@{ ExceptionClass='STALE'; DefaultResolution='AUTO_SAFE'; Severity='P2'; Component='DERIVED_STATE' },
    [pscustomobject]@{ ExceptionClass='BROKEN_LINK'; DefaultResolution='HUMAN_REVIEW_REQUIRED'; Severity='P1'; Component='LINKAGE' },
    [pscustomobject]@{ ExceptionClass='UNKNOWN_EXCEPTION'; DefaultResolution='BLOCKED'; Severity='P1'; Component='UNKNOWN' },
    [pscustomobject]@{ ExceptionClass='AUTOMATION_FAILURE'; DefaultResolution='BLOCKED'; Severity='P1'; Component='AUTOMATION' }
)
$script:RapResolutionStates = @('AUTO_SAFE','HUMAN_REVIEW_REQUIRED','BLOCKED','IGNORE_WITH_JUSTIFICATION')
$script:RapForbiddenActions = @('DELETE','MERGE','SELECT_CANONICAL','OVERWRITE_HUMAN_OWNED','OVERWRITE_RESEARCHER_CONFIRMED','PRODUCTION_WRITE')
$script:RapWorkflowPolicyVersion = 'SPR-011-TURN-E-1'
$script:RapAutomationActor = 'rap-automation:workflow-engine'
$script:RapAutomationActorPrefix = 'rap-automation:'
$script:RapArtifactStatusRank = @{ CURRENT=0; STALE=1; REVALIDATION_REQUIRED=2; BLOCKED=3 }
$script:RapArtifactTypes = @('REVIEW_EVIDENCE','META_CODING_EVIDENCE','SYNTHESIS','RESEARCH_OUTPUT','EVIDENCE_GRAPH_NODE')
$script:RapArtifactRequirements = @('PDF','SOURCE_VERSION')
$script:RapHumanDecisions = [ordered]@{ KEEP_BLOCKED='NONE'; KEEP_RESEARCHER_VALUE='NONE'; REQUIRE_REVALIDATION='MARK_REVALIDATION_REQUIRED'; ACCEPT_WITH_JUSTIFICATION='RECORD_IGNORE_WITH_JUSTIFICATION' }
$script:RapMaxSnapshotBytes = 262144
$script:RapLineageMaxDepth = 32

function ConvertTo-RapWorkflowCanonical {
    param($Value)
    if ($null -eq $Value) { return $null }
    if ($Value -is [Collections.IDictionary]) {
        $result=[ordered]@{}; foreach($key in @($Value.Keys|ForEach-Object{[string]$_}|Sort-Object)){$result[$key]=ConvertTo-RapWorkflowCanonical $Value[$key]}; return $result
    }
    if ($Value -is [Management.Automation.PSCustomObject]) {
        $result=[ordered]@{}; foreach($property in @($Value.PSObject.Properties|Sort-Object Name)){$result[$property.Name]=ConvertTo-RapWorkflowCanonical $property.Value}; return $result
    }
    if ($Value -is [Collections.IEnumerable] -and $Value -isnot [string]) { return @($Value|ForEach-Object{ConvertTo-RapWorkflowCanonical $_}) }
    return $Value
}

function Get-RapWorkflowHash {
    param($Value)
    $json=(ConvertTo-RapWorkflowCanonical $Value)|ConvertTo-Json -Depth 80 -Compress
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($json))).ToLowerInvariant()
}

function Copy-RapWorkflowValue {
    param($Value)
    $Value | ConvertTo-Json -Depth 80 | ConvertFrom-Json -Depth 80
}

function Get-RapExceptionTaxonomy {
    [CmdletBinding()]param()
    return @($script:RapExceptionTaxonomy | ForEach-Object { $_.PSObject.Copy() })
}

function Get-RapWorkflowProperty {
    param($Object,[string]$Name)
    if($null-eq$Object){return $null}
    if($Object-is[Collections.IDictionary]){if($Object.Contains($Name)){return $Object[$Name]};return $null}
    $property=$Object.PSObject.Properties[$Name]
    if($property){return $property.Value}
    return $null
}

function Test-RapWorkflowInteger {param($Value)($Value-is[int]-or$Value-is[long]-or$Value-is[int16]-or$Value-is[byte])}

function ConvertTo-RapExceptionClass {
    <#
    .SYNOPSIS
    Normalizes an externally supplied exception class. Only an exact, ordinal match of a taxonomy class is
    accepted; null, empty, whitespace-padded, differently cased, or unsupported values fail closed to
    UNKNOWN_EXCEPTION (Turn E, RISK-SPR011-002).
    #>
    [CmdletBinding()]param([AllowNull()][AllowEmptyString()][Parameter(Position=0)]$Class)
    $text=if($Class-is[string]){$Class}else{$null}
    $known=$null
    if($null-ne$text){$known=$script:RapExceptionTaxonomy|Where-Object{[string]::Equals($_.ExceptionClass,$text,[StringComparison]::Ordinal)}|Select-Object -First 1}
    if($known){return [pscustomobject]@{ExceptionClass=$known.ExceptionClass;Supported=$true;OriginalClass=$text}}
    [pscustomobject]@{ExceptionClass='UNKNOWN_EXCEPTION';Supported=$false;OriginalClass=$(if($null-eq$Class){$null}else{[string]$Class})}
}

function ConvertTo-RapNormalizedException {
    <#
    .SYNOPSIS
    Converts a raw exception record from another RAP component into a registered exception. Unsupported
    classes become UNKNOWN_EXCEPTION (BLOCKED) and keep the original class as evidence.
    #>
    [CmdletBinding()]param([Parameter(Mandatory)][AllowNull()]$RawException,[Parameter(Mandatory)]$Snapshot)
    $normalized=ConvertTo-RapExceptionClass (Get-RapWorkflowProperty $RawException 'ExceptionClass')
    $detail=Get-RapWorkflowProperty $RawException 'Detail'
    $component=($script:RapExceptionTaxonomy|Where-Object ExceptionClass -eq $normalized.ExceptionClass|Select-Object -First 1).Component
    $evidence=[pscustomobject]@{Normalized=$true;Supported=$normalized.Supported;OriginalClass=$normalized.OriginalClass;Detail=$(if($null-eq$detail){$null}else{[string]$detail})}
    New-RapDetectedException $normalized.ExceptionClass $Snapshot $component $evidence
}

function Get-RapDownstreamImpact {
    <#
    .SYNOPSIS
    Computes the effective status of every dependent artifact from the snapshot's normalized Evidence Graph
    lineage projection (Dependents). Status is derived only from evidence; it never trusts a recorded CURRENT.
    Order: BLOCKED > REVALIDATION_REQUIRED > STALE > CURRENT. Missing references and cycles block.
    #>
    [CmdletBinding()]param([Parameter(Mandatory)]$Snapshot)
    $dependents=@(Get-RapWorkflowProperty $Snapshot 'Dependents'|Where-Object{$null-ne$_})
    if(-not$dependents.Count){return @()}
    $pdf=Get-RapWorkflowProperty $Snapshot 'Pdf';$pdfExists=(Get-RapWorkflowProperty $pdf 'Exists')-eq$true;$pdfHash=Get-RapWorkflowProperty $pdf 'CurrentHash'
    $sourceVersion=[int64](Get-RapWorkflowProperty (Get-RapWorkflowProperty $Snapshot 'VersionState') 'SourceVersion')
    $byId=@{};foreach($d in $dependents){$byId[[string]$d.ArtifactId]=$d}
    $rank=$script:RapArtifactStatusRank
    $own=@{}
    foreach($d in $dependents){
        $id=[string]$d.ArtifactId;$recorded=[string]$d.Status;if(-not$rank.ContainsKey($recorded)){$recorded='BLOCKED'}
        $status=$recorded;$causes=[Collections.Generic.List[string]]::new();if($recorded-ne'CURRENT'){$causes.Add("RECORDED_$recorded")}
        $requires=@(Get-RapWorkflowProperty $d 'Requires')
        if($requires-contains'PDF'){
            if(-not$pdfExists){$causes.Add('PDF_MISSING');if($rank['BLOCKED']-gt$rank[$status]){$status='BLOCKED'}}
            elseif([string](Get-RapWorkflowProperty $d 'BasisPdfHash')-ne[string]$pdfHash){$causes.Add('PDF_HASH_CHANGED');if($rank['REVALIDATION_REQUIRED']-gt$rank[$status]){$status='REVALIDATION_REQUIRED'}}
        }
        if($requires-contains'SOURCE_VERSION'){
            $basis=Get-RapWorkflowProperty $d 'BasisVersion'
            if($null-eq$basis-or[int64]$basis-lt$sourceVersion){$causes.Add('SOURCE_VERSION_ADVANCED');if($rank['REVALIDATION_REQUIRED']-gt$rank[$status]){$status='REVALIDATION_REQUIRED'}}
        }
        foreach($up in @(Get-RapWorkflowProperty $d 'Upstream'|Where-Object{$_})){if(-not$byId.ContainsKey([string]$up)){$causes.Add('LINEAGE_REFERENCE_MISSING');$status='BLOCKED'}}
        $own[$id]=[pscustomobject]@{Status=$status;Causes=@($causes);Recorded=$recorded}
    }
    $memo=@{}
    $resolve=$null
    $resolve={param([string]$id,[string[]]$visiting,[int]$depth)
        if($memo.ContainsKey($id)){return $memo[$id]}
        $self=$own[$id];$status=$self.Status;$roots=[Collections.Generic.List[string]]::new();foreach($c in $self.Causes){$roots.Add($c)}
        $cause=if($self.Causes.Count){$self.Causes[0]}else{$null}
        if($depth-gt$script:RapLineageMaxDepth){$status='BLOCKED';$roots.Add('LINEAGE_DEPTH_EXCEEDED');if(!$cause){$cause='LINEAGE_DEPTH_EXCEEDED'}}
        else{
            foreach($up in @(Get-RapWorkflowProperty $byId[$id] 'Upstream'|Where-Object{$_}|ForEach-Object{[string]$_}|Sort-Object)){
                if(-not$byId.ContainsKey($up)){continue}
                if($visiting-contains$up){$status='BLOCKED';$roots.Add('LINEAGE_CYCLE');if(!$cause-or$cause-notlike'LINEAGE*'){$cause='LINEAGE_CYCLE'};continue}
                $u=&$resolve $up (@($visiting)+@($up)) ($depth+1)
                if($u.EffectiveStatus-ne'CURRENT'){foreach($r in $u.RootCauses){$roots.Add($r)}}
                if($rank[$u.EffectiveStatus]-gt$rank[$status]){$status=$u.EffectiveStatus;$cause="UPSTREAM:${up}"}
            }
        }
        $result=[pscustomobject]@{ArtifactId=$id;ArtifactType=[string]$byId[$id].ArtifactType;RecordedStatus=$self.Recorded;EffectiveStatus=$status;Cause=$(if($status-eq'CURRENT'){$null}else{$cause});RootCauses=@($roots|Sort-Object -Unique);Transition=$status-ne$self.Recorded}
        if(-not(@($result.RootCauses)-match'LINEAGE_CYCLE')){$memo[$id]=$result}
        $result
    }
    @($byId.Keys|Sort-Object|ForEach-Object{&$resolve $_ @($_) 0})
}

function Test-RapDependentOperationPermitted {
    <#
    .SYNOPSIS
    Executable downstream gate: an operation on a dependent artifact is permitted only when its effective
    status is CURRENT. Unknown artifacts are refused (fail closed).
    #>
    [CmdletBinding()]param([Parameter(Mandatory)]$Snapshot,[Parameter(Mandatory)][string]$ArtifactId,[Parameter(Mandatory)][string]$Operation)
    $impact=@(Get-RapDownstreamImpact -Snapshot $Snapshot)|Where-Object ArtifactId -eq $ArtifactId|Select-Object -First 1
    if(-not$impact){return [pscustomobject]@{ArtifactId=$ArtifactId;Operation=$Operation;Permitted=$false;EffectiveStatus=$null;Reason='ARTIFACT_NOT_IN_LINEAGE'}}
    $reason=if($impact.EffectiveStatus-eq'CURRENT'){'CURRENT'}elseif(@($impact.RootCauses)-contains'PDF_MISSING'){'PDF_MISSING'}elseif(@($impact.RootCauses).Count){@($impact.RootCauses)[0]}else{$impact.EffectiveStatus}
    [pscustomobject]@{ArtifactId=$ArtifactId;Operation=$Operation;Permitted=$impact.EffectiveStatus-eq'CURRENT';EffectiveStatus=$impact.EffectiveStatus;Reason=$reason}
}

function Test-RapWorkflowSnapshot {
    <#
    .SYNOPSIS
    Deterministic structural validation of a workflow snapshot before any detection or persistence.
    #>
    [CmdletBinding()]param([Parameter(Mandatory)][AllowNull()]$Snapshot)
    $errors=[Collections.Generic.List[string]]::new()
    if($null-eq$Snapshot-or$Snapshot-is[string]-or$Snapshot-is[ValueType]){return [pscustomobject]@{Valid=$false;Errors=@('NOT_AN_OBJECT')}}
    $json=$Snapshot|ConvertTo-Json -Depth 80 -Compress -WarningAction SilentlyContinue
    if([Text.Encoding]::UTF8.GetByteCount($json)-gt$script:RapMaxSnapshotBytes){$errors.Add('OVERSIZED')}
    $has={param($o,$n)$null-ne$o-and$o-isnot[string]-and$null-ne$o.PSObject.Properties[$n]}
    foreach($n in @('ProjectId','LibraryId')){if(-not(&$has $Snapshot $n)){$errors.Add("MISSING:$n")}}
    if((&$has $Snapshot 'ProjectId')-and([string]$Snapshot.ProjectId-notmatch'^PR\d{3,6}$'-or$Snapshot.ProjectId-isnot[string])){$errors.Add('INVALID_ID:ProjectId')}
    if((&$has $Snapshot 'LibraryId')-and([string]$Snapshot.LibraryId-notmatch'^LIB:L\d{6}$'-or$Snapshot.LibraryId-isnot[string])){$errors.Add('INVALID_ID:LibraryId')}
    $objects=[ordered]@{Zotero=@('Exists');NotionReview=@('Exists');LibraryLinkage=@('Valid');Pdf=@('Exists');ProjectLinkage=@('Valid');EditState=@('AutomationManualConflict');CodingState=@('AiResearcherConflict');VersionState=@();HumanOwned=@();ResearcherConfirmed=@()}
    foreach($name in $objects.Keys){
        if(-not(&$has $Snapshot $name)){$errors.Add("MISSING:$name");continue}
        $value=$Snapshot.$name
        if($null-eq$value-or$value-is[string]-or$value-is[ValueType]){$errors.Add("WRONG_TYPE:$name");continue}
        foreach($flag in $objects[$name]){if(-not(&$has $value $flag)){$errors.Add("MISSING:$name.$flag")}elseif($value.$flag-isnot[bool]){$errors.Add("WRONG_TYPE:$name.$flag")}}
    }
    if((&$has $Snapshot 'VersionState')-and$null-ne$Snapshot.VersionState-and$Snapshot.VersionState-isnot[string]){
        foreach($n in @('SourceVersion','DerivedVersion')){
            if(-not(&$has $Snapshot.VersionState $n)){$errors.Add("MISSING:VersionState.$n")}
            elseif(-not(Test-RapWorkflowInteger $Snapshot.VersionState.$n)-or[int64]$Snapshot.VersionState.$n-lt0){$errors.Add("WRONG_TYPE:VersionState.$n")}
        }
    }
    foreach($n in @('Links','OrphanReferences','UnknownSignals','AutomationRuns','Dependents')){if((&$has $Snapshot $n)-and$null-ne$Snapshot.$n-and$Snapshot.$n-isnot[Array]){$errors.Add("WRONG_TYPE:$n")}}
    if(&$has $Snapshot 'AutomationRuns'){
        $i=0;foreach($run in @($Snapshot.AutomationRuns)){
            if(-not(&$has $run 'RunId')-or[string]::IsNullOrWhiteSpace([string]$run.RunId)){$errors.Add("MISSING:AutomationRuns[$i].RunId")}
            if(-not(&$has $run 'ExitCode')-or-not(Test-RapWorkflowInteger $run.ExitCode)){$errors.Add("WRONG_TYPE:AutomationRuns[$i].ExitCode")}
            $i++
        }
    }
    if(&$has $Snapshot 'Dependents'){
        $i=0;$ids=@{}
        foreach($d in @($Snapshot.Dependents)){
            $p="Dependents[$i]"
            if(-not(&$has $d 'ArtifactId')-or[string]$d.ArtifactId-notmatch'^[A-Za-z0-9:._|\-]{1,128}$'){$errors.Add("INVALID_ID:$p.ArtifactId")}elseif($ids.ContainsKey([string]$d.ArtifactId)){$errors.Add("DUPLICATE_ID:$p.ArtifactId")}else{$ids[[string]$d.ArtifactId]=$true}
            if(-not(&$has $d 'ArtifactType')-or[string]$d.ArtifactType-notin$script:RapArtifactTypes){$errors.Add("INVALID_VALUE:$p.ArtifactType")}
            if(-not(&$has $d 'Status')-or-not$script:RapArtifactStatusRank.ContainsKey([string]$d.Status)){$errors.Add("INVALID_VALUE:$p.Status")}
            if((&$has $d 'Requires')-and@($d.Requires|Where-Object{$_-notin$script:RapArtifactRequirements}).Count){$errors.Add("INVALID_VALUE:$p.Requires")}
            if((&$has $d 'BasisVersion')-and$null-ne$d.BasisVersion-and-not(Test-RapWorkflowInteger $d.BasisVersion)){$errors.Add("WRONG_TYPE:$p.BasisVersion")}
            $i++
        }
    }
    [pscustomobject]@{Valid=$errors.Count-eq0;Errors=@($errors|Sort-Object -Unique)}
}

function New-RapLifecycleEvent {
    param([string]$EventType,[string]$ExceptionId,[string]$OperationId,[string]$Actor,[string]$ActorType,[string]$FromState,[string]$ToState,[string]$FailureReason,[string]$Timestamp,$Detail)
    [pscustomobject][ordered]@{EventType=$EventType;ExceptionId=$(if($ExceptionId){$ExceptionId}else{$null});OperationId=$OperationId;Actor=$Actor;ActorType=$ActorType;FromState=$(if($FromState){$FromState}else{$null});ToState=$ToState;FailureReason=$(if($FailureReason){$FailureReason}else{$null});Timestamp=$Timestamp;PolicyVersion=$script:RapWorkflowPolicyVersion;Detail=$Detail}
}

function Get-RapExceptionLifecycle {
    <#
    .SYNOPSIS
    Reconstructs one exception's lifecycle solely from the append-only lifecycle store.
    #>
    [CmdletBinding()]param([Parameter(Mandatory)][string]$ExceptionId,[Parameter(Mandatory)]$Dependencies)
    if($Dependencies.ReadEvents-isnot[scriptblock]){throw 'WORKFLOW_DEPENDENCY_REQUIRED:ReadEvents'}
    @(&$Dependencies.ReadEvents|Where-Object{$_.ExceptionId-eq$ExceptionId})
}

function New-RapDetectedException {
    param([string]$Class,$Snapshot,[string]$Component,$Evidence)
    $taxonomy=$script:RapExceptionTaxonomy|Where-Object ExceptionClass -eq $Class|Select-Object -First 1
    if(-not $taxonomy){throw "UNKNOWN_EXCEPTION_CLASS:$Class"}
    $identity=[ordered]@{ExceptionClass=$Class;ProjectId=$Snapshot.ProjectId;LibraryId=$Snapshot.LibraryId;Component=$Component;Evidence=$Evidence}
    $hash=Get-RapWorkflowHash $identity
    [pscustomobject]@{
        ExceptionId="EXC-$($hash.Substring(0,24))";Fingerprint=$hash;ExceptionClass=$Class
        ProjectId=$Snapshot.ProjectId;LibraryId=$Snapshot.LibraryId;Component=$Component
        Severity=$taxonomy.Severity;DefaultResolution=$taxonomy.DefaultResolution;Evidence=$Evidence
        SnapshotHash=Get-RapWorkflowHash $Snapshot;Status='OPEN';DetectedAt=[DateTimeOffset]::UtcNow.ToString('o')
        ProductionWrite='DISABLED'
    }
}

function Find-RapWorkflowExceptions {
    [CmdletBinding()]param([Parameter(Mandatory)]$Snapshot)
    if([string]::IsNullOrWhiteSpace([string]$Snapshot.ProjectId)-or[string]::IsNullOrWhiteSpace([string]$Snapshot.LibraryId)){throw 'WORKFLOW_CONTEXT_REQUIRED'}
    $found=[Collections.Generic.List[object]]::new()
    if(-not $Snapshot.Zotero.Exists){$found.Add((New-RapDetectedException ZOTERO_SOURCE_DELETED $Snapshot ZOTERO ([pscustomobject]@{SourceKey=$Snapshot.Zotero.SourceKey;Observed='MISSING'})))}
    if(@($Snapshot.Zotero.Registrations).Count -gt 1){$found.Add((New-RapDetectedException DUPLICATE_BIBLIOGRAPHIC_REGISTRATION $Snapshot BIBLIOGRAPHY ([pscustomobject]@{RegistrationIds=@($Snapshot.Zotero.Registrations)})))}
    if(-not $Snapshot.NotionReview.Exists){$found.Add((New-RapDetectedException NOTION_REVIEW_MISSING $Snapshot NOTION_REVIEW ([pscustomobject]@{ExpectedLibraryId=$Snapshot.LibraryId})))}
    elseif($Snapshot.NotionReview.CreationSource -eq 'MANUAL' -and -not $Snapshot.NotionReview.Registered){$found.Add((New-RapDetectedException MANUALLY_CREATED_NOTION_REVIEW $Snapshot NOTION_REVIEW ([pscustomobject]@{PageId=$Snapshot.NotionReview.PageId;CreationSource='MANUAL'})))}
    if(-not $Snapshot.LibraryLinkage.Valid -or $Snapshot.LibraryLinkage.LinkedLibraryId -ne $Snapshot.LibraryId){$found.Add((New-RapDetectedException LIBRARY_ID_LINKAGE_BROKEN $Snapshot IDENTITY ([pscustomobject]@{Expected=$Snapshot.LibraryId;Actual=$Snapshot.LibraryLinkage.LinkedLibraryId})))}
    $impact=@(Get-RapDownstreamImpact -Snapshot $Snapshot)
    $affected={param([string]$pattern)@($impact|Where-Object{@($_.RootCauses)-match$pattern}|ForEach-Object{[pscustomobject][ordered]@{ArtifactId=$_.ArtifactId;ArtifactType=$_.ArtifactType;RecordedStatus=$_.RecordedStatus;EffectiveStatus=$_.EffectiveStatus;Cause=$_.Cause}})}
    if(-not $Snapshot.Pdf.Exists -or $Snapshot.Pdf.ExpectedHash -ne $Snapshot.Pdf.CurrentHash){$found.Add((New-RapDetectedException PDF_MISSING_OR_REPLACED $Snapshot PDF ([pscustomobject][ordered]@{Condition=$(if(-not$Snapshot.Pdf.Exists){'MISSING'}else{'HASH_CHANGED'});Exists=$Snapshot.Pdf.Exists;ExpectedHash=$Snapshot.Pdf.ExpectedHash;CurrentHash=$Snapshot.Pdf.CurrentHash;DownstreamBlockModeled=$true;AffectedArtifacts=@(&$affected '^PDF_')})))}
    if(-not $Snapshot.ProjectLinkage.Valid){$found.Add((New-RapDetectedException PROJECT_LINKAGE_INCONSISTENCY $Snapshot PROJECT ([pscustomobject]@{ExpectedProjectId=$Snapshot.ProjectId;LinkedProjectId=$Snapshot.ProjectLinkage.LinkedProjectId})))}
    if($Snapshot.EditState.AutomationManualConflict){$found.Add((New-RapDetectedException AUTOMATION_MANUAL_EDIT_CONFLICT $Snapshot EDIT_OWNERSHIP ([pscustomobject]@{Fields=@($Snapshot.EditState.ConflictingFields)})))}
    if($Snapshot.CodingState.AiResearcherConflict){
        $suggestions=@(Get-RapWorkflowProperty $Snapshot.CodingState 'AiSuggestions'|Where-Object{$null-ne$_})
        $provenance=Get-RapWorkflowProperty $Snapshot.CodingState 'ConfirmationProvenance'
        $conflicts=@(@($Snapshot.CodingState.ConflictingFields)|ForEach-Object{[string]$_}|Sort-Object -Unique|ForEach-Object{
            $field=$_;$s=$suggestions|Where-Object{[string](Get-RapWorkflowProperty $_ 'Field')-eq$field}|Select-Object -First 1
            $modelId=Get-RapWorkflowProperty $s 'ModelId';$modelVersion=Get-RapWorkflowProperty $s 'ModelVersion';$runId=Get-RapWorkflowProperty $s 'RunId'
            $researcherValue=Get-RapWorkflowProperty $Snapshot.ResearcherConfirmed $field
            [pscustomobject][ordered]@{Field=$field;AiValue=Get-RapWorkflowProperty $s 'Value';AiModelId=$modelId;AiModelVersion=$modelVersion;AiRunId=$runId;AiProvenanceComplete=($null-ne$s-and-not[string]::IsNullOrWhiteSpace([string]$modelId)-and-not[string]::IsNullOrWhiteSpace([string]$modelVersion)-and-not[string]::IsNullOrWhiteSpace([string]$runId));ResearcherValue=$researcherValue;ResearcherValueHash=Get-RapWorkflowHash $researcherValue;ConfirmationProvenance=$provenance}
        })
        $found.Add((New-RapDetectedException AI_ASSISTED_RESEARCHER_CONFIRMED_CONFLICT $Snapshot META_CODING ([pscustomobject][ordered]@{Fields=@($Snapshot.CodingState.ConflictingFields);Conflicts=@($conflicts)})))
    }
    if(@($Snapshot.OrphanReferences).Count -gt 0){$found.Add((New-RapDetectedException ORPHAN $Snapshot LINKAGE ([pscustomobject]@{References=@($Snapshot.OrphanReferences)})))}
    if([int64]$Snapshot.VersionState.SourceVersion -gt [int64]$Snapshot.VersionState.DerivedVersion){$found.Add((New-RapDetectedException STALE $Snapshot DERIVED_STATE ([pscustomobject][ordered]@{SourceVersion=$Snapshot.VersionState.SourceVersion;DerivedVersion=$Snapshot.VersionState.DerivedVersion;AffectedArtifacts=@(&$affected '^SOURCE_VERSION_ADVANCED$')})))}
    foreach($link in @($Snapshot.Links|Where-Object{-not $_.Reachable})){$found.Add((New-RapDetectedException BROKEN_LINK $Snapshot LINKAGE ([pscustomobject]@{LinkId=$link.LinkId;Target=$link.Target})))}
    foreach($run in @(Get-RapWorkflowProperty $Snapshot 'AutomationRuns'|Where-Object{$null-ne$_}|Sort-Object{[string]$_.RunId})){
        $exit=Get-RapWorkflowProperty $run 'ExitCode';$status=[string](Get-RapWorkflowProperty $run 'Status');$errorsSeen=@(Get-RapWorkflowProperty $run 'ErrorEvidence'|Where-Object{-not[string]::IsNullOrWhiteSpace([string]$_)}|ForEach-Object{[string]$_})
        $statusFailed=$status-in@('FAILED','TIMEOUT','ERROR','CANCELLED')
        if(($null-eq$exit-or[int64]$exit-ne0)-or$statusFailed-or$errorsSeen.Count){
            $found.Add((New-RapDetectedException AUTOMATION_FAILURE $Snapshot AUTOMATION ([pscustomobject][ordered]@{RunId=[string]$run.RunId;ExitCode=$exit;Status=$status;Masked=($null-ne$exit-and[int64]$exit-eq0);ErrorEvidence=@($errorsSeen)})))
        }
    }
    foreach($signal in @($Snapshot.UnknownSignals)){$found.Add((New-RapDetectedException UNKNOWN_EXCEPTION $Snapshot UNKNOWN ([pscustomobject]@{Signal=[string]$signal})))}
    return @($found|Sort-Object ExceptionClass,ExceptionId)
}

function Get-RapCompositeResolutionPolicy {
    [CmdletBinding()]param([Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Exceptions,[Parameter(Mandatory)]$Snapshot)
    $classes=@($Exceptions|ForEach-Object{if($_.PSObject.Properties['ExceptionClass']){$_.ExceptionClass}}|Where-Object{$_}|Sort-Object -Unique)
    $ids=@($Exceptions|ForEach-Object{if($_.PSObject.Properties['ExceptionId']){$_.ExceptionId}}|Where-Object{$_}|Sort-Object -Unique)
    $requiredSnapshotProperties=@('ProjectId','LibraryId','LibraryLinkage','ProjectLinkage','HumanOwned','ResearcherConfirmed','VersionState')
    $missing=[Collections.Generic.List[string]]::new()
    if($null-eq$Snapshot){$missing.Add('Snapshot')}
    else{
        foreach($name in $requiredSnapshotProperties){if(-not$Snapshot.PSObject.Properties[$name]){$missing.Add($name)}}
        if($Snapshot.PSObject.Properties['ProjectId']-and[string]::IsNullOrWhiteSpace([string]$Snapshot.ProjectId)){$missing.Add('ProjectId.Value')}
        if($Snapshot.PSObject.Properties['LibraryId']-and[string]::IsNullOrWhiteSpace([string]$Snapshot.LibraryId)){$missing.Add('LibraryId.Value')}
        if($Snapshot.PSObject.Properties['LibraryLinkage']){
            if($null-eq$Snapshot.LibraryLinkage){$missing.Add('LibraryLinkage.Value')}
            else{foreach($name in @('Valid','LinkedLibraryId')){if(-not$Snapshot.LibraryLinkage.PSObject.Properties[$name]){$missing.Add("LibraryLinkage.$name")}}}
        }
        if($Snapshot.PSObject.Properties['ProjectLinkage']){
            if($null-eq$Snapshot.ProjectLinkage){$missing.Add('ProjectLinkage.Value')}
            else{foreach($name in @('Valid','LinkedProjectId')){if(-not$Snapshot.ProjectLinkage.PSObject.Properties[$name]){$missing.Add("ProjectLinkage.$name")}}}
        }
        if($Snapshot.PSObject.Properties['VersionState']){
            if($null-eq$Snapshot.VersionState){$missing.Add('VersionState.Value')}
            else{foreach($name in @('SourceVersion','DerivedVersion')){if(-not$Snapshot.VersionState.PSObject.Properties[$name]){$missing.Add("VersionState.$name")}}}
        }
        if($Snapshot.PSObject.Properties['HumanOwned']-and$null-eq$Snapshot.HumanOwned){$missing.Add('HumanOwned.Value')}
        if($Snapshot.PSObject.Properties['ResearcherConfirmed']-and$null-eq$Snapshot.ResearcherConfirmed){$missing.Add('ResearcherConfirmed.Value')}
    }
    foreach($exception in $Exceptions){foreach($name in @('ExceptionId','ExceptionClass','DefaultResolution','Evidence')){if(-not$exception.PSObject.Properties[$name]){$missing.Add("Exception.$name")}}}
    # Turn E (RISK-SPR011-002): exception objects are not trusted to describe themselves. The class must be an
    # exact taxonomy member and DefaultResolution must equal the taxonomy default; otherwise fail closed.
    foreach($exception in $Exceptions){
        if(-not$exception.PSObject.Properties['ExceptionClass']){continue}
        $known=$script:RapExceptionTaxonomy|Where-Object{[string]::Equals($_.ExceptionClass,[string]$exception.ExceptionClass,[StringComparison]::Ordinal)}|Select-Object -First 1
        if(-not$known){$missing.Add('Exception.UnsupportedClass');continue}
        if($exception.PSObject.Properties['DefaultResolution']-and$exception.DefaultResolution-ne$known.DefaultResolution){$missing.Add("Exception.DefaultResolutionMismatch:$($known.ExceptionClass)")}
    }

    $identityBlockerClasses=@(
        'LIBRARY_ID_LINKAGE_BROKEN','DUPLICATE_BIBLIOGRAPHIC_REGISTRATION','MANUALLY_CREATED_NOTION_REVIEW',
        'PROJECT_LINKAGE_INCONSISTENCY','ORPHAN','ZOTERO_SOURCE_DELETED','UNKNOWN_EXCEPTION'
    )
    $humanConflictClasses=@('AUTOMATION_MANUAL_EDIT_CONFLICT','AI_ASSISTED_RESEARCHER_CONFIRMED_CONFLICT')
    $lineageBlockerClasses=@('BROKEN_LINK','PDF_MISSING_OR_REPLACED','PROJECT_LINKAGE_INCONSISTENCY','ORPHAN','ZOTERO_SOURCE_DELETED','UNKNOWN_EXCEPTION','AUTOMATION_FAILURE')
    $hasIdentityBlocker=@($classes|Where-Object{$identityBlockerClasses-contains$_}).Count-gt0
    $hasHumanConflict=@($classes|Where-Object{$humanConflictClasses-contains$_}).Count-gt0
    $hasLineageBlocker=@($classes|Where-Object{$lineageBlockerClasses-contains$_}).Count-gt0
    $defaultStates=@($Exceptions|ForEach-Object{if($_.PSObject.Properties['DefaultResolution']){$_.DefaultResolution}})
    $hasBlocked=$defaultStates-contains'BLOCKED'
    $hasHumanReview=$defaultStates-contains'HUMAN_REVIEW_REQUIRED'
    $policyError=$missing.Count-gt0-or@($defaultStates|Where-Object{$_-notin@('AUTO_SAFE','HUMAN_REVIEW_REQUIRED','BLOCKED')}).Count-gt0

    $identityUnambiguous=-not$hasIdentityBlocker-and-not$policyError
    $canonicalResolved=$identityUnambiguous
    $noIdentityBlocker=-not$hasIdentityBlocker-and-not$policyError
    $noHumanOwnedConflict=-not$hasHumanConflict-and-not$policyError
    $noResearcherConflict=-not($classes-contains'AI_ASSISTED_RESEARCHER_CONFIRMED_CONFLICT')-and-not$policyError
    $operationNonDestructive=-not$policyError
    $operationIdempotent=-not$policyError
    $verificationAvailable=-not$policyError
    $requiredLineageValid=-not$hasLineageBlocker-and-not$policyError
    $noHigherPriority=-not$hasBlocked-and-not$hasHumanReview-and-not$hasIdentityBlocker-and-not$hasHumanConflict-and-not$hasLineageBlocker-and-not$policyError
    $autoSafeEligible=$Exceptions.Count-gt0-and$identityUnambiguous-and$canonicalResolved-and$noIdentityBlocker-and$noHumanOwnedConflict-and$noResearcherConflict-and$operationNonDestructive-and$operationIdempotent-and$verificationAvailable-and$requiredLineageValid-and$noHigherPriority-and@($defaultStates|Where-Object{$_-ne'AUTO_SAFE'}).Count-eq0
    $resolution=if($policyError-or$hasBlocked){'BLOCKED'}elseif($hasHumanReview-or$hasIdentityBlocker-or$hasHumanConflict-or$hasLineageBlocker){'HUMAN_REVIEW_REQUIRED'}elseif($autoSafeEligible){'AUTO_SAFE'}else{'BLOCKED'}
    $reason=if($policyError){"POLICY_EVIDENCE_MISSING:$(@($missing|Sort-Object -Unique)-join',')"}elseif($hasBlocked){'BLOCKING_EXCEPTION_ACTIVE'}elseif($hasIdentityBlocker){'IDENTITY_BLOCKER_ACTIVE'}elseif($hasHumanConflict){'HUMAN_JUDGMENT_REQUIRED'}elseif($hasHumanReview-or$hasLineageBlocker){'HIGHER_PRIORITY_EXCEPTION_ACTIVE'}elseif($autoSafeEligible){'ALL_AUTO_SAFE_PREDICATES_VERIFIED'}else{'AUTO_SAFE_NOT_PROVEN'}
    $body=[ordered]@{PolicyVersion=$script:RapWorkflowPolicyVersion;ActiveExceptionIds=$ids;ActiveExceptionClasses=$classes;Resolution=$resolution;Reason=$reason;MissingEvidence=@($missing|Sort-Object -Unique)}
    [pscustomobject]@{
        PolicyVersion=$script:RapWorkflowPolicyVersion;PolicyHash=Get-RapWorkflowHash $body
        ActiveExceptionIds=$ids;ActiveExceptionClasses=$classes;CompositeResolution=$resolution;DecisionReason=$reason
        IdentityUnambiguous=$identityUnambiguous;CanonicalEntityResolved=$canonicalResolved;NoIdentityBlocker=$noIdentityBlocker
        NoHumanOwnedConflict=$noHumanOwnedConflict;NoResearcherConfirmedConflict=$noResearcherConflict
        OperationNonDestructive=$operationNonDestructive;OperationIdempotent=$operationIdempotent
        VerificationAvailable=$verificationAvailable;RequiredLineageValid=$requiredLineageValid;NoHigherPriorityException=$noHigherPriority
        AutoSafeEligible=$autoSafeEligible;PolicyEvaluationFailed=$policyError;MissingEvidence=@($missing|Sort-Object -Unique)
    }
}

function Test-RapAutoSafePolicyContext {
    param($SafetyContext)
    if($null-eq$SafetyContext){return $false}
    foreach($name in @('IdentityUnambiguous','CanonicalEntityResolved','NoIdentityBlocker','NoHumanOwnedConflict','NoResearcherConfirmedConflict','OperationNonDestructive','OperationIdempotent','VerificationAvailable','RequiredLineageValid','NoHigherPriorityException','AutoSafeEligible')){
        if(-not$SafetyContext.PSObject.Properties[$name]-or$SafetyContext.$name-ne$true){return $false}
    }
    return $SafetyContext.PolicyEvaluationFailed-ne$true
}

function New-RapExceptionResolutionPlan {
    [CmdletBinding()]param([Parameter(Mandatory)]$Exception,[string]$RequestedState,[string]$Justification,$SafetyContext,[switch]$AuthorizedResearcher)
    $state=if($RequestedState){$RequestedState}elseif($SafetyContext){$SafetyContext.CompositeResolution}elseif($Exception.DefaultResolution-eq'AUTO_SAFE'){'BLOCKED'}else{$Exception.DefaultResolution}
    if($script:RapResolutionStates -notcontains $state){throw 'INVALID_RESOLUTION_STATE'}
    if($state -eq 'IGNORE_WITH_JUSTIFICATION' -and [string]::IsNullOrWhiteSpace($Justification)){throw 'IGNORE_JUSTIFICATION_REQUIRED'}
    if($state-eq'IGNORE_WITH_JUSTIFICATION'-and$SafetyContext-and$SafetyContext.NoIdentityBlocker-ne$true-and-not$AuthorizedResearcher){throw 'IDENTITY_BLOCKER_REQUIRES_AUTHORIZED_RESEARCHER'}
    if($state-eq'AUTO_SAFE'-and($Exception.DefaultResolution-ne'AUTO_SAFE'-or-not(Test-RapAutoSafePolicyContext $SafetyContext))){throw 'AUTO_SAFE_NOT_PERMITTED'}
    $actions=if($state-eq'AUTO_SAFE'-and$Exception.ExceptionClass-eq'STALE'){@('REFRESH_LOCAL_DERIVED_STATE')}else{@('PRESERVE_STATE','REQUEST_REVIEW')}
    if(@($actions|Where-Object{$script:RapForbiddenActions-contains$_}).Count){throw 'UNSAFE_RESOLUTION_ACTION'}
    $policyVersion=if($SafetyContext){$SafetyContext.PolicyVersion}else{$script:RapWorkflowPolicyVersion}
    $policyHash=if($SafetyContext){$SafetyContext.PolicyHash}else{$null}
    $decisionReason=if($SafetyContext){$SafetyContext.DecisionReason}else{'NO_COMPOSITE_CONTEXT_FAIL_CLOSED'}
    $body=[ordered]@{ExceptionId=$Exception.ExceptionId;ResolutionState=$state;Actions=@($actions);Justification=$Justification;PolicyVersion=$policyVersion;PolicyHash=$policyHash}
    $hash=Get-RapWorkflowHash $body
    [pscustomobject]@{PlanId="PLAN-$($hash.Substring(0,24))";ExceptionId=$Exception.ExceptionId;ExceptionClass=$Exception.ExceptionClass;ProjectId=$Exception.ProjectId;LibraryId=$Exception.LibraryId;ResolutionState=$state;Actions=@($actions);Justification=$Justification;PlanHash=$hash;Status='PLANNED';NoDelete=$true;NoMerge=$true;NoCanonicalSelection=$true;ProductionWrite='DISABLED';PolicyVersion=$policyVersion;PolicyHash=$policyHash;PolicyDecisionReason=$decisionReason}
}

function Get-RapRetainedAlternatives {
    param($Exception)
    if($Exception.ExceptionClass-ne'AI_ASSISTED_RESEARCHER_CONFIRMED_CONFLICT'){return @()}
    @(@(Get-RapWorkflowProperty $Exception.Evidence 'Conflicts')|Where-Object{$null-ne$_}|ForEach-Object{
        [pscustomobject][ordered]@{ExceptionId=$Exception.ExceptionId;Field=$_.Field;AiValue=$_.AiValue;AiModelId=$_.AiModelId;AiModelVersion=$_.AiModelVersion;AiRunId=$_.AiRunId;AiProvenanceComplete=$_.AiProvenanceComplete;ResearcherValueHash=$_.ResearcherValueHash;Disposition='RETAINED_NOT_APPLIED';Applied=$false}
    })
}

function Invoke-RapExceptionReconciliation {
    [CmdletBinding()]param([Parameter(Mandatory)]$Exception,[Parameter(Mandatory)]$Plan,[Parameter(Mandatory)]$Snapshot)
    $before=Get-RapWorkflowHash $Snapshot
    $retained=@(Get-RapRetainedAlternatives $Exception)
    if($Plan.ResolutionState -ne 'AUTO_SAFE'){
        return [pscustomobject]@{ExceptionId=$Exception.ExceptionId;ExceptionClass=$Exception.ExceptionClass;PlanId=$Plan.PlanId;Status=$Plan.ResolutionState;Actions=@('NONE');BeforeHash=$before;AfterHash=$before;UpdatedSnapshot=Copy-RapWorkflowValue $Snapshot;RetainedAlternatives=$retained;ProductionWrite='DISABLED'}
    }
    if($Exception.ExceptionClass -ne 'STALE'){throw 'AUTO_SAFE_RECONCILIATION_UNSUPPORTED'}
    $updated=Copy-RapWorkflowValue $Snapshot
    # Only the local derived-version marker is refreshed. Dependent artifacts are NOT touched: their effective
    # status is recomputed from lineage evidence and stays REVALIDATION_REQUIRED until revalidated (E11).
    $updated.VersionState.DerivedVersion=$updated.VersionState.SourceVersion
    [pscustomobject]@{ExceptionId=$Exception.ExceptionId;ExceptionClass=$Exception.ExceptionClass;PlanId=$Plan.PlanId;Status='RECONCILED';Actions=@('REFRESH_LOCAL_DERIVED_STATE');BeforeHash=$before;AfterHash=Get-RapWorkflowHash $updated;UpdatedSnapshot=$updated;RetainedAlternatives=$retained;ProductionWrite='DISABLED'}
}

function Test-RapExceptionResolution {
    [CmdletBinding()]param([Parameter(Mandatory)]$Exception,[Parameter(Mandatory)]$Plan,[Parameter(Mandatory)]$Reconciliation,[Parameter(Mandatory)]$OriginalSnapshot)
    $errors=[Collections.Generic.List[string]]::new()
    $updated=$Reconciliation.UpdatedSnapshot
    if($updated.LibraryId-ne$OriginalSnapshot.LibraryId){$errors.Add('LIBRARY_ID_CHANGED')}
    if((Get-RapWorkflowHash $updated.HumanOwned)-ne(Get-RapWorkflowHash $OriginalSnapshot.HumanOwned)){$errors.Add('HUMAN_OWNED_CHANGED')}
    if((Get-RapWorkflowHash $updated.ResearcherConfirmed)-ne(Get-RapWorkflowHash $OriginalSnapshot.ResearcherConfirmed)){$errors.Add('RESEARCHER_CONFIRMED_CHANGED')}
    if((Get-RapWorkflowHash (Get-RapWorkflowProperty $updated 'Dependents'))-ne(Get-RapWorkflowHash (Get-RapWorkflowProperty $OriginalSnapshot 'Dependents'))){$errors.Add('DEPENDENT_LINEAGE_REWRITTEN')}
    if(@($Reconciliation.Actions|Where-Object{$script:RapForbiddenActions-contains$_}).Count){$errors.Add('FORBIDDEN_ACTION')}
    if($Exception.ExceptionClass-eq'AI_ASSISTED_RESEARCHER_CONFIRMED_CONFLICT'){
        $expected=@(Get-RapWorkflowProperty $Exception.Evidence 'Conflicts'|Where-Object{$null-ne$_}).Count
        $retained=@(Get-RapWorkflowProperty $Reconciliation 'RetainedAlternatives'|Where-Object{$null-ne$_})
        if($retained.Count-ne$expected-or@($retained|Where-Object{$_.Applied-ne$false-or$_.Disposition-ne'RETAINED_NOT_APPLIED'}).Count){$errors.Add('AI_ALTERNATIVE_NOT_RETAINED')}
    }
    if($Plan.ResolutionState-eq'AUTO_SAFE'){
        $remaining=@(Find-RapWorkflowExceptions $updated|Where-Object ExceptionClass -eq $Exception.ExceptionClass)
        if($remaining.Count){$errors.Add('EXCEPTION_NOT_RESOLVED')}
    }elseif($Reconciliation.AfterHash-ne$Reconciliation.BeforeHash){$errors.Add('NON_AUTO_STATE_MUTATED')}
    [pscustomobject]@{ExceptionId=$Exception.ExceptionId;PlanId=$Plan.PlanId;Valid=$errors.Count-eq0;Status=$(if($errors.Count){'FAILED'}else{'VERIFIED'});Errors=@($errors);VerifiedAt=[DateTimeOffset]::UtcNow.ToString('o')}
}

function Merge-RapWorkflowRecords {
    param([object[]]$Existing,[object[]]$Incoming,[scriptblock]$Key)
    $map=[ordered]@{}
    foreach($item in @($Existing)+@($Incoming)){if($null-ne$item){$map[[string](&$Key $item)]=$item}}
    @($map.Values)
}

function Assert-RapWorkflowOperationId {
    param([string]$OperationId)
    if($OperationId-cnotmatch'^[A-Za-z0-9][A-Za-z0-9._:\-]{0,127}$'){throw 'MALFORMED_OPERATION_ID'}
}

function Invoke-RapWorkflowExceptionOperation {
    [CmdletBinding()]param(
        [Parameter(Mandatory)][AllowNull()]$Snapshot,[Parameter(Mandatory)][string]$OperationId,[Parameter(Mandatory)]$Dependencies,
        [ValidateSet('Fixture')][string]$Mode='Fixture',
        [string]$Actor=$script:RapAutomationActor
    )
    # Turn E (RISK-SPR011-006): reject malformed identifiers and payloads deterministically, before any
    # dependency is read or written.
    Assert-RapWorkflowOperationId $OperationId
    if(-not$Actor.StartsWith($script:RapAutomationActorPrefix,[StringComparison]::Ordinal)){throw 'OPERATION_ACTOR_MUST_BE_AUTOMATION'}
    foreach($name in @('GetOperation','ReadState','CommitWorkflow')){if($null-eq$Dependencies-or$Dependencies.$name-isnot[scriptblock]){throw "WORKFLOW_DEPENDENCY_REQUIRED:$name"}}
    $shape=Test-RapWorkflowSnapshot -Snapshot $Snapshot
    if(-not$shape.Valid){throw "MALFORMED_SNAPSHOT:$(@($shape.Errors)-join',')"}
    $payloadHash=Get-RapWorkflowHash $Snapshot
    $existing=&$Dependencies.GetOperation $OperationId
    if($existing-and$existing.PayloadHash-ne$payloadHash){throw 'PAYLOAD_CONFLICT'}
    if($existing-and$existing.State-eq'COMPLETED'){return [pscustomobject]@{Status='ALREADY_COMPLETED';Result=$existing.Result;ProductionWrite='DISABLED'}}
    $now=[DateTimeOffset]::UtcNow.ToString('o');$actorType='AUTOMATION'
    $detected=@(Find-RapWorkflowExceptions $Snapshot)
    $impact=@(Get-RapDownstreamImpact -Snapshot $Snapshot)
    $safetyContext=Get-RapCompositeResolutionPolicy -Exceptions $detected -Snapshot $Snapshot
    $plans=[Collections.Generic.List[object]]::new();$reconciliations=[Collections.Generic.List[object]]::new();$verifications=[Collections.Generic.List[object]]::new()
    $events=[Collections.Generic.List[object]]::new();$caseStatus=[Collections.Generic.List[object]]::new();$retained=[Collections.Generic.List[object]]::new()
    foreach($exception in $detected){
        $plan=New-RapExceptionResolutionPlan $exception -SafetyContext $safetyContext;$plans.Add($plan)
        $reconciliation=Invoke-RapExceptionReconciliation $exception $plan $Snapshot;$reconciliations.Add($reconciliation)
        $verification=Test-RapExceptionResolution $exception $plan $reconciliation $Snapshot;$verifications.Add($verification)
        foreach($alternative in @($reconciliation.RetainedAlternatives)){if($null-ne$alternative){$retained.Add($alternative)}}
        $id=$exception.ExceptionId
        $events.Add((New-RapLifecycleEvent DETECTED $id $OperationId $Actor $actorType 'NONE' 'DETECTED' $null $now ([pscustomobject]@{ExceptionClass=$exception.ExceptionClass;Fingerprint=$exception.Fingerprint;SnapshotHash=$exception.SnapshotHash})))
        $events.Add((New-RapLifecycleEvent PLANNED $id $OperationId $Actor $actorType 'DETECTED' $plan.ResolutionState $null $now ([pscustomobject]@{PlanId=$plan.PlanId;PolicyHash=$plan.PolicyHash;PolicyDecisionReason=$plan.PolicyDecisionReason;Actions=@($plan.Actions)})))
        $applied=$reconciliation.Status-eq'RECONCILED'
        $events.Add((New-RapLifecycleEvent $(if($applied){'RECONCILIATION_APPLIED'}else{'STATE_PRESERVED'}) $id $OperationId $Actor $actorType $plan.ResolutionState $(if($applied){'RECONCILED_PENDING_VERIFICATION'}else{'PRESERVED'}) $null $now ([pscustomobject]@{BeforeHash=$reconciliation.BeforeHash;AfterHash=$reconciliation.AfterHash;Actions=@($reconciliation.Actions);RetainedAlternatives=@($reconciliation.RetainedAlternatives).Count})))
        $verificationFailed=-not$verification.Valid
        $events.Add((New-RapLifecycleEvent $(if($verificationFailed){'VERIFICATION_FAILED'}else{'VERIFIED'}) $id $OperationId $Actor $actorType $(if($applied){'RECONCILED_PENDING_VERIFICATION'}else{'PRESERVED'}) $verification.Status $(if($verificationFailed){@($verification.Errors)-join','}else{$null}) $now ([pscustomobject]@{Errors=@($verification.Errors)})))
        $final=if($verificationFailed){'VERIFICATION_FAILED'}elseif($applied){'RECONCILED'}else{$plan.ResolutionState}
        if($final-eq'RECONCILED'){$events.Add((New-RapLifecycleEvent FINAL_RESOLUTION $id $OperationId $Actor $actorType $verification.Status 'RECONCILED' $null $now ([pscustomobject]@{ResolvedBy='AUTO_SAFE_POLICY';PolicyHash=$safetyContext.PolicyHash})))}
        else{$events.Add((New-RapLifecycleEvent AWAITING_HUMAN_REVIEW $id $OperationId $Actor $actorType $verification.Status $final $(if($verificationFailed){@($verification.Errors)-join','}else{$null}) $now ([pscustomobject]@{Reason=$safetyContext.DecisionReason})))}
        $caseStatus.Add([pscustomobject][ordered]@{ExceptionId=$id;Status=$final;OperationId=$OperationId;UpdatedAt=$now;UpdatedBy=$Actor})
    }
    foreach($item in @($impact|Where-Object Transition)){
        $events.Add((New-RapLifecycleEvent DEPENDENT_STATUS_TRANSITION $null $OperationId $Actor $actorType $item.RecordedStatus $item.EffectiveStatus $null $now ([pscustomobject]@{ArtifactId=$item.ArtifactId;ArtifactType=$item.ArtifactType;Cause=$item.Cause;RootCauses=@($item.RootCauses)})))
    }
    $current=&$Dependencies.ReadState
    $registered=@(Get-RapWorkflowProperty $current 'Exceptions'|Where-Object{$null-ne$_})
    foreach($exception in $detected){if(-not@($registered|Where-Object ExceptionId -eq $exception.ExceptionId)){$registered+=@($exception)}}
    $state=[pscustomobject]@{
        Exceptions=@($registered);Plans=@(Get-RapWorkflowProperty $current 'Plans')+@($plans);Reconciliations=@(Get-RapWorkflowProperty $current 'Reconciliations')+@($reconciliations);Verifications=@(Get-RapWorkflowProperty $current 'Verifications')+@($verifications)
        CaseStatus=@(Merge-RapWorkflowRecords @(Get-RapWorkflowProperty $current 'CaseStatus') @($caseStatus) {param($r)$r.ExceptionId})
        RetainedAlternatives=@(Merge-RapWorkflowRecords @(Get-RapWorkflowProperty $current 'RetainedAlternatives') @($retained) {param($r)"$($r.ExceptionId)|$($r.Field)"})
    }
    foreach($name in @('Plans','Reconciliations','Verifications')){$state.$name=@($state.$name|Where-Object{$null-ne$_})}
    $result=[pscustomobject]@{OperationId=$OperationId;Detected=@($detected);Plans=@($plans);Reconciliations=@($reconciliations);Verifications=@($verifications);SafetyContext=$safetyContext;DownstreamImpact=@($impact);RetainedAlternatives=@($retained);Status='COMPLETED';ProductionWrite='DISABLED'}
    $operation=[pscustomobject]@{OperationId=$OperationId;PayloadHash=$payloadHash;State='COMPLETED';Result=$result}
    $audit=[pscustomobject][ordered]@{
        AuditSchema='SPR-011-TURN-E';OperationId=$OperationId;OperationKind='EXCEPTION_OPERATION';Actor=$Actor;ActorType=$actorType;ProjectId=$Snapshot.ProjectId;LibraryId=$Snapshot.LibraryId
        PriorState=Copy-RapWorkflowValue $Snapshot;PriorStateHash=$payloadHash;AfterStateHashes=@($reconciliations|ForEach-Object{$_.AfterHash}|Sort-Object -Unique)
        DetectedExceptionIds=@($detected.ExceptionId);ResolutionStates=@($plans.ResolutionState);VerificationStatuses=@($verifications.Status);FinalStatuses=@($caseStatus|ForEach-Object{"$($_.ExceptionId)=$($_.Status)"})
        DownstreamTransitions=@($impact|Where-Object Transition|ForEach-Object{"$($_.ArtifactId):$($_.RecordedStatus)->$($_.EffectiveStatus)"});RetainedAlternativeCount=$retained.Count
        PolicyVersion=$safetyContext.PolicyVersion;PolicyHash=$safetyContext.PolicyHash;PolicyDecision=$safetyContext.CompositeResolution;PolicyDecisionReason=$safetyContext.DecisionReason
        DeleteCount=0;MergeCount=0;CanonicalSelectionCount=0;HumanOwnedWriteCount=0;ResearcherConfirmedWriteCount=0;ProductionWrite='DISABLED';FailureReason=$null;Status='COMPLETED';Timestamp=$now;LifecycleEventCount=$events.Count+1
    }
    $auditJson=$audit|ConvertTo-Json -Depth 80 -Compress
    $auditHash=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($auditJson))).ToLowerInvariant()
    $events.Add((New-RapLifecycleEvent OPERATION_COMPLETED $null $OperationId $Actor $actorType 'RUNNING' 'COMPLETED' $null $now ([pscustomobject]@{AuditJsonHash=$auditHash;DetectedCount=$detected.Count;PolicyDecision=$safetyContext.CompositeResolution})))
    try{&$Dependencies.CommitWorkflow $state $operation $audit @($events)}
    catch{
        $reason=$_.Exception.Message
        if($Dependencies.PSObject.Properties['RecordFailure']-and$Dependencies.RecordFailure-is[scriptblock]){
            try{&$Dependencies.RecordFailure (New-RapLifecycleEvent OPERATION_FAILED $null $OperationId $Actor $actorType 'RUNNING' 'FAILED' $reason ([DateTimeOffset]::UtcNow.ToString('o')) ([pscustomobject]@{PayloadHash=$payloadHash;RolledBack=$true}))}catch{}
        }
        throw
    }
    [pscustomobject]@{Status='COMPLETED';Result=$result;ProductionWrite='DISABLED'}
}

function Submit-RapHumanReviewDecision {
    <#
    .SYNOPSIS
    Records a researcher decision for a case awaiting human review. Automation can prepare options but can
    never author this event. The decision itself mutates no research source; PermittedAction is advisory.
    #>
    [CmdletBinding()]param(
        [Parameter(Mandatory)][string]$ExceptionId,[Parameter(Mandatory)][string]$Decision,[Parameter(Mandatory)][string]$Actor,
        [Parameter(Mandatory)][string]$ActorType,[Parameter(Mandatory)][AllowEmptyString()][string]$Rationale,[Parameter(Mandatory)][string]$DecisionId,
        [Parameter(Mandatory)]$Dependencies
    )
    if($ActorType-cne'RESEARCHER'-or$Actor.StartsWith($script:RapAutomationActorPrefix,[StringComparison]::OrdinalIgnoreCase)){throw 'AUTOMATION_CANNOT_DECIDE'}
    if(-not$script:RapHumanDecisions.Contains($Decision)){throw 'INVALID_DECISION'}
    if([string]::IsNullOrWhiteSpace($Rationale)){throw 'DECISION_RATIONALE_REQUIRED'}
    Assert-RapWorkflowOperationId $DecisionId
    foreach($name in @('GetOperation','ReadState','CommitWorkflow')){if($Dependencies.$name-isnot[scriptblock]){throw "WORKFLOW_DEPENDENCY_REQUIRED:$name"}}
    if(-not$Dependencies.PSObject.Properties['AuthorizedResearchers']){throw 'RESEARCHER_AUTHORIZATION_UNAVAILABLE'}
    if(@($Dependencies.AuthorizedResearchers)-cnotcontains$Actor){throw 'RESEARCHER_NOT_AUTHORIZED'}
    $operationId="DECISION:$DecisionId"
    $payloadHash=Get-RapWorkflowHash ([ordered]@{ExceptionId=$ExceptionId;Decision=$Decision;Actor=$Actor;Rationale=$Rationale})
    $existing=&$Dependencies.GetOperation $operationId
    if($existing-and$existing.PayloadHash-ne$payloadHash){throw 'PAYLOAD_CONFLICT'}
    if($existing-and$existing.State-eq'COMPLETED'){return [pscustomobject]@{Status='ALREADY_COMPLETED';DecisionId=$DecisionId;PermittedAction=$existing.Result.PermittedAction;ProductionWrite='DISABLED'}}
    $current=&$Dependencies.ReadState
    $case=@(Get-RapWorkflowProperty $current 'CaseStatus')|Where-Object{$null-ne$_-and$_.ExceptionId-eq$ExceptionId}|Select-Object -First 1
    if(-not$case){throw 'CASE_NOT_FOUND'}
    if($case.Status-notin@('HUMAN_REVIEW_REQUIRED','BLOCKED','VERIFICATION_FAILED')){throw 'CASE_NOT_AWAITING_DECISION'}
    $permitted=$script:RapHumanDecisions[$Decision]
    if($permitted-in$script:RapForbiddenActions){throw 'UNSAFE_RESOLUTION_ACTION'}
    $now=[DateTimeOffset]::UtcNow.ToString('o');$finalState="RESOLVED_$Decision"
    $events=[Collections.Generic.List[object]]::new()
    $events.Add((New-RapLifecycleEvent HUMAN_REVIEW_DECISION $ExceptionId $operationId $Actor 'RESEARCHER' $case.Status 'DECIDED' $null $now ([pscustomobject][ordered]@{DecisionId=$DecisionId;Decision=$Decision;Rationale=$Rationale;PermittedAction=$permitted;Provenance='Submit-RapHumanReviewDecision';AuthorizedBy='AuthorizedResearchers'})))
    $events.Add((New-RapLifecycleEvent FINAL_RESOLUTION $ExceptionId $operationId $Actor 'RESEARCHER' 'DECIDED' $finalState $null $now ([pscustomobject]@{ResolvedBy='RESEARCHER_DECISION';DecisionId=$DecisionId})))
    $updatedCase=[pscustomobject][ordered]@{ExceptionId=$ExceptionId;Status=$finalState;OperationId=$operationId;UpdatedAt=$now;UpdatedBy=$Actor}
    $state=Copy-RapWorkflowValue $current
    $state.CaseStatus=@(Merge-RapWorkflowRecords @(Get-RapWorkflowProperty $current 'CaseStatus') @($updatedCase) {param($r)$r.ExceptionId})
    $result=[pscustomobject]@{DecisionId=$DecisionId;ExceptionId=$ExceptionId;Decision=$Decision;PermittedAction=$permitted;FinalState=$finalState;Status='COMPLETED'}
    $operation=[pscustomobject]@{OperationId=$operationId;PayloadHash=$payloadHash;State='COMPLETED';Result=$result}
    $audit=[pscustomobject][ordered]@{AuditSchema='SPR-011-TURN-E';OperationId=$operationId;OperationKind='HUMAN_REVIEW_DECISION';Actor=$Actor;ActorType='RESEARCHER';ExceptionId=$ExceptionId;PriorCaseStatus=$case.Status;Decision=$Decision;Rationale=$Rationale;PermittedAction=$permitted;FinalState=$finalState;DeleteCount=0;MergeCount=0;CanonicalSelectionCount=0;HumanOwnedWriteCount=0;ResearcherConfirmedWriteCount=0;ProductionWrite='DISABLED';FailureReason=$null;Status='COMPLETED';Timestamp=$now;LifecycleEventCount=$events.Count+1}
    $auditJson=$audit|ConvertTo-Json -Depth 80 -Compress
    $auditHash=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($auditJson))).ToLowerInvariant()
    $events.Add((New-RapLifecycleEvent OPERATION_COMPLETED $null $operationId $Actor 'RESEARCHER' 'RUNNING' 'COMPLETED' $null $now ([pscustomobject]@{AuditJsonHash=$auditHash;OperationKind='HUMAN_REVIEW_DECISION'})))
    &$Dependencies.CommitWorkflow $state $operation $audit @($events)
    [pscustomobject]@{Status='COMPLETED';DecisionId=$DecisionId;PermittedAction=$permitted;FinalState=$finalState;ProductionWrite='DISABLED'}
}

Export-ModuleMember -Function Get-RapExceptionTaxonomy,ConvertTo-RapExceptionClass,ConvertTo-RapNormalizedException,Find-RapWorkflowExceptions,Get-RapDownstreamImpact,Test-RapDependentOperationPermitted,Test-RapWorkflowSnapshot,Get-RapCompositeResolutionPolicy,New-RapExceptionResolutionPlan,Invoke-RapExceptionReconciliation,Test-RapExceptionResolution,Invoke-RapWorkflowExceptionOperation,Submit-RapHumanReviewDecision,Get-RapExceptionLifecycle
