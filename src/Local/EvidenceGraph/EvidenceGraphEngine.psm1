Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

$script:RapGraphNodeTypes=@('PAPER','PROJECT','PROJECT_PAPER','COMMON_REVIEW','EVIDENCE','AI_EXTRACTION','META_CODING','OUTCOME','COMPARISON','EFFECT_SIZE','MEASUREMENT','TIME_POINT','STATISTICAL_INPUT','DERIVED_VALUE','RESEARCHER_CONFIRMED_RECORD')
$script:RapGraphProjectTypes=@('PROJECT_PAPER','META_CODING','OUTCOME','COMPARISON','EFFECT_SIZE','MEASUREMENT','TIME_POINT','STATISTICAL_INPUT','DERIVED_VALUE','RESEARCHER_CONFIRMED_RECORD')
$script:RapGraphEvidenceStatuses=@('SUPPORTED','INFERRED','NOT_REPORTED','UNCERTAIN','CONFLICTING_EVIDENCE')
$script:RapGraphHumanOwned=@('CriticalAppraisal','ReviewerInterpretation','ReviewerMemo','EffectSizeInclusion','OutcomeSelection','ComparisonSelection','ModeratorClassification','DependencyHandling','RiskJudgment','StudyExclusion','StatisticalTransformationDecision','MetaAnalysisEligibility','ConflictResolution','ResearcherMemo')
$script:RapGraphRelations=[ordered]@{
    HAS_COMMON_REVIEW=@('PAPER','COMMON_REVIEW');HAS_EVIDENCE=@('PAPER','EVIDENCE');INCLUDES_PAPER_RELATIONSHIP=@('PROJECT','PROJECT_PAPER');REFERENCES=@('PROJECT_PAPER','PAPER');HAS_META_CODING=@('PROJECT_PAPER','META_CODING');HAS_OUTCOME=@('META_CODING','OUTCOME');HAS_COMPARISON=@('META_CODING','COMPARISON');HAS_EFFECT_SIZE=@('META_CODING','EFFECT_SIZE');HAS_STATISTICAL_INPUT=@('EFFECT_SIZE','STATISTICAL_INPUT');HAS_DERIVED_VALUE=@('EFFECT_SIZE','DERIVED_VALUE');SUPPORTED_BY=@('*','EVIDENCE');DERIVED_FROM=@('DERIVED_VALUE','STATISTICAL_INPUT');EXTRACTED_FROM=@('AI_EXTRACTION','EVIDENCE');CONFIRMS=@('RESEARCHER_CONFIRMED_RECORD','AI_EXTRACTION')
}

function ConvertTo-RapGraphCanonical {param($Value)if($null -eq $Value){return $null};if($Value -is [Collections.IDictionary]){$o=[ordered]@{};foreach($k in @($Value.Keys|ForEach-Object{[string]$_}|Sort-Object)){$o[$k]=ConvertTo-RapGraphCanonical $Value[$k]};return $o};if($Value -is [Management.Automation.PSCustomObject]){$o=[ordered]@{};foreach($p in @($Value.PSObject.Properties|Sort-Object Name)){$o[$p.Name]=ConvertTo-RapGraphCanonical $p.Value};return $o};if($Value -is [Collections.IEnumerable] -and $Value -isnot [string]){return @($Value|ForEach-Object{ConvertTo-RapGraphCanonical $_})};$Value}
function Get-RapGraphHash {param($Value)$json=(ConvertTo-RapGraphCanonical $Value)|ConvertTo-Json -Depth 60 -Compress;[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($json))).ToLowerInvariant()}
function Get-RapGraphValue {param($Object,[string]$Name)if($null -eq $Object){return $null};if($Object -is [Collections.IDictionary]){foreach($k in $Object.Keys){if([string]$k -ieq $Name){return $Object[$k]}};return $null};$p=$Object.PSObject.Properties|Where-Object Name -IEQ $Name|Select-Object -First 1;if($p){$p.Value}else{$null}}
function Get-RapGraphEntries {param($Value)if($null -eq $Value){return @()};if($Value -is [Collections.IDictionary]){return @($Value.GetEnumerator()|ForEach-Object{[pscustomobject]@{Name=[string]$_.Key;Value=$_.Value}})};@($Value.PSObject.Properties|ForEach-Object{[pscustomobject]@{Name=$_.Name;Value=$_.Value}})}

function Assert-RapGraphNoHumanContent {
    param($Value,[string]$Path='Attributes')
    foreach($entry in @(Get-RapGraphEntries $Value)){
        if($script:RapGraphHumanOwned -icontains $entry.Name){throw "HUMAN_OWNED_GRAPH_WRITE_BLOCKED: $Path.$($entry.Name)"}
        if($entry.Value -is [Collections.IDictionary] -or $entry.Value -is [Management.Automation.PSCustomObject]){Assert-RapGraphNoHumanContent $entry.Value "$Path.$($entry.Name)"}
        elseif($entry.Value -is [Collections.IEnumerable] -and $entry.Value -isnot [string]){foreach($i in $entry.Value){if($i -is [Collections.IDictionary] -or $i -is [Management.Automation.PSCustomObject]){Assert-RapGraphNoHumanContent $i "$Path.$($entry.Name)"}}}
    }
}

function New-RapEvidenceNodeId {
    [CmdletBinding()]param([Parameter(Mandatory)]$Provenance)
    'EVIDENCE:'+(Get-RapGraphHash $Provenance).Substring(0,24)
}

function New-RapEvidenceGraphNode {
    [CmdletBinding()]param(
        [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9:._|\-]+$')][string]$NodeId,
        [Parameter(Mandatory)][ValidateSet('PAPER','PROJECT','PROJECT_PAPER','COMMON_REVIEW','EVIDENCE','AI_EXTRACTION','META_CODING','OUTCOME','COMPARISON','EFFECT_SIZE','MEASUREMENT','TIME_POINT','STATISTICAL_INPUT','DERIVED_VALUE','RESEARCHER_CONFIRMED_RECORD')][string]$NodeType,
        [ValidatePattern('^LIB:L\d{6}$')][string]$LibraryId,
        [ValidatePattern('^PR\d{3}$')][string]$ProjectId,
        $Attributes=[pscustomobject]@{}
    )
    Assert-RapGraphNoHumanContent $Attributes
    if($NodeType -eq 'PAPER' -and [string]::IsNullOrWhiteSpace($LibraryId)){throw 'PAPER_LIBRARY_ID_REQUIRED'}
    if($NodeType -eq 'PROJECT' -and [string]::IsNullOrWhiteSpace($ProjectId)){throw 'PROJECT_ID_REQUIRED'}
    if($script:RapGraphProjectTypes -contains $NodeType -and ([string]::IsNullOrWhiteSpace($LibraryId) -or [string]::IsNullOrWhiteSpace($ProjectId))){throw "PROJECT_CONTEXT_REQUIRED: $NodeType"}
    if($NodeType -eq 'EVIDENCE'){
        $status=[string](Get-RapGraphValue $Attributes 'EvidenceStatus');if($script:RapGraphEvidenceStatuses -inotcontains $status){throw 'EVIDENCE_STATUS_INVALID'}
        if($status -eq 'NOT_REPORTED' -and $null -ne (Get-RapGraphValue $Attributes 'Value')){throw 'NOT_REPORTED_VALUE_MUST_BE_NULL'}
        if([string]::IsNullOrWhiteSpace([string](Get-RapGraphValue $Attributes 'SourceReference')) -and $status -ne 'NOT_REPORTED'){throw 'EVIDENCE_SOURCE_REQUIRED'}
    }
    if($NodeType -eq 'AI_EXTRACTION' -and [string](Get-RapGraphValue $Attributes 'OriginState') -ne 'AI_ASSISTED'){throw 'AI_ORIGIN_STATE_REQUIRED'}
    [pscustomobject]@{NodeId=$NodeId;NodeType=$NodeType;LibraryId=$LibraryId;ProjectId=$ProjectId;ScopeKey=$(if($LibraryId -and $ProjectId){"$LibraryId|$ProjectId"}else{$null});Attributes=$Attributes}
}

function New-RapEvidenceGraphEdge {
    [CmdletBinding()]param(
        [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9:._|\-]+$')][string]$SourceNodeId,
        [Parameter(Mandatory)][ValidateSet('HAS_COMMON_REVIEW','HAS_EVIDENCE','INCLUDES_PAPER_RELATIONSHIP','REFERENCES','HAS_META_CODING','HAS_OUTCOME','HAS_COMPARISON','HAS_EFFECT_SIZE','HAS_STATISTICAL_INPUT','HAS_DERIVED_VALUE','SUPPORTED_BY','DERIVED_FROM','EXTRACTED_FROM','CONFIRMS')][string]$RelationType,
        [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9:._|\-]+$')][string]$TargetNodeId,
        [ValidatePattern('^PR\d{3}$')][string]$ProjectId,
        $Attributes=[pscustomobject]@{}
    )
    Assert-RapGraphNoHumanContent $Attributes
    $identity=[ordered]@{SourceNodeId=$SourceNodeId;RelationType=$RelationType;TargetNodeId=$TargetNodeId;ProjectId=$ProjectId}
    [pscustomobject]@{EdgeId='EDGE:'+(Get-RapGraphHash $identity).Substring(0,24);SourceNodeId=$SourceNodeId;RelationType=$RelationType;TargetNodeId=$TargetNodeId;ProjectId=$ProjectId;Attributes=$Attributes}
}

function Assert-RapEvidenceGraphEdge {
    param($Edge,[hashtable]$Nodes)
    if(-not $Nodes.ContainsKey([string]$Edge.SourceNodeId)){throw 'GRAPH_SOURCE_NODE_MISSING'}
    if(-not $Nodes.ContainsKey([string]$Edge.TargetNodeId)){throw 'GRAPH_TARGET_NODE_MISSING'}
    $source=$Nodes[[string]$Edge.SourceNodeId];$target=$Nodes[[string]$Edge.TargetNodeId];$rule=$script:RapGraphRelations[[string]$Edge.RelationType]
    if($null -eq $rule){throw 'GRAPH_RELATION_INVALID'}
    if($rule[0] -ne '*' -and ($source.NodeType -ne $rule[0] -or $target.NodeType -ne $rule[1])){throw 'GRAPH_RELATION_TYPE_MISMATCH'}
    if($rule[0] -eq '*' -and $target.NodeType -ne 'EVIDENCE'){throw 'GRAPH_RELATION_TYPE_MISMATCH'}
    if($source.NodeType -eq 'PROJECT' -and $target.ProjectId -and $source.ProjectId -ne $target.ProjectId){throw 'CROSS_PROJECT_GRAPH_EDGE_BLOCKED'}
    if($source.ProjectId -and $target.ProjectId -and $source.ProjectId -ne $target.ProjectId){throw 'CROSS_PROJECT_GRAPH_EDGE_BLOCKED'}
    if(($source.ProjectId -or $target.ProjectId) -and $Edge.RelationType -notin @('REFERENCES','SUPPORTED_BY','EXTRACTED_FROM') -and [string]::IsNullOrWhiteSpace([string]$Edge.ProjectId)){throw 'EDGE_PROJECT_ID_REQUIRED'}
    if($Edge.ProjectId -and (($source.ProjectId -and $source.ProjectId -ne $Edge.ProjectId) -or ($target.ProjectId -and $target.ProjectId -ne $Edge.ProjectId))){throw 'EDGE_PROJECT_CONTEXT_MISMATCH'}
    if($target.NodeType -eq 'COMMON_REVIEW' -and $source.NodeType -ne 'PAPER'){throw 'COMMON_REVIEW_GRAPH_FIREWALL'}
    $true
}

function New-RapEvidenceGraphOperation {
    [CmdletBinding()]param([Parameter(Mandatory)][object[]]$Nodes,[Parameter(Mandatory)][object[]]$Edges,[ValidatePattern('^[A-Za-z0-9._:\-]+$')][string]$OperationId)
    $payloadHash=Get-RapGraphHash ([ordered]@{Nodes=$Nodes;Edges=$Edges;SchemaVersion='spr-008.1'})
    if([string]::IsNullOrWhiteSpace($OperationId)){$OperationId='GRAPH-'+$payloadHash.Substring(0,24)}
    [pscustomobject]@{OperationId=$OperationId;PayloadHash=$payloadHash;SchemaVersion='spr-008.1';Nodes=$Nodes;Edges=$Edges}
}

function Assert-RapGraphDependencies {param($Dependencies,[string[]]$Names)foreach($name in $Names){if($null -eq $Dependencies.PSObject.Properties[$name] -or $Dependencies.$name -isnot [scriptblock]){throw "Evidence Graph dependency required: $name"}}}

function Invoke-RapEvidenceGraphMutation {
    [CmdletBinding()]param([Parameter(Mandatory)]$Operation,[Parameter(Mandatory)]$Dependencies,[ValidateSet('DryRun','Fixture')][string]$Mode='DryRun')
    Assert-RapGraphDependencies $Dependencies @('GetOperation','SaveOperation','GetNode','UpsertNode','GetEdge','UpsertEdge','AppendAudit')
    $existing=& $Dependencies.GetOperation $Operation.OperationId;if($existing -and [string]$existing.PayloadHash -ne $Operation.PayloadHash){throw 'PAYLOAD_CONFLICT'}
    if($existing -and $existing.State -eq 'COMPLETED'){return [pscustomobject]@{Status='ALREADY_COMPLETED';OperationId=$Operation.OperationId;ProductionWrite='DISABLED'}}
    $nodes=@{};foreach($node in @($Operation.Nodes)){if($nodes.ContainsKey($node.NodeId)){continue};$nodes[$node.NodeId]=$node}
    foreach($edge in @($Operation.Edges)){foreach($id in @($edge.SourceNodeId,$edge.TargetNodeId)){if(-not $nodes.ContainsKey($id)){$persisted=& $Dependencies.GetNode $id;if($persisted){$nodes[$id]=$persisted}}};[void](Assert-RapEvidenceGraphEdge $edge $nodes)}
    if($Mode -eq 'DryRun'){return [pscustomobject]@{Status='DRY_RUN';OperationId=$Operation.OperationId;NodeCount=$nodes.Count;EdgeCount=@($Operation.Edges|Select-Object -ExpandProperty EdgeId -Unique).Count;ChangesApplied=$false;ProductionWrite='DISABLED'}}
    if(-not $existing){$existing=[pscustomobject]@{OperationId=$Operation.OperationId;PayloadHash=$Operation.PayloadHash;State='PREPARED';Nodes=$Operation.Nodes;Edges=$Operation.Edges;UpdatedAt=[DateTimeOffset]::UtcNow.ToString('o')};& $Dependencies.SaveOperation $existing}
    foreach($node in @($existing.Nodes)){& $Dependencies.UpsertNode $node|Out-Null}
    foreach($edge in @($existing.Edges|Sort-Object EdgeId -Unique)){& $Dependencies.UpsertEdge $edge|Out-Null}
    $completed=[pscustomobject]@{OperationId=$Operation.OperationId;PayloadHash=$Operation.PayloadHash;State='COMPLETED';Nodes=$existing.Nodes;Edges=$existing.Edges;UpdatedAt=[DateTimeOffset]::UtcNow.ToString('o')};& $Dependencies.SaveOperation $completed
    & $Dependencies.AppendAudit ([pscustomobject]@{OperationId=$Operation.OperationId;PayloadHash=$Operation.PayloadHash;Action='EVIDENCE_GRAPH_FIXTURE_UPSERT';NodeCount=@($nodes.Keys).Count;EdgeCount=@($existing.Edges|Select-Object -ExpandProperty EdgeId -Unique).Count;Status='COMPLETED';ProductionWrite='DISABLED';Timestamp=[DateTimeOffset]::UtcNow.ToString('o')})
    [pscustomobject]@{Status='COMPLETED';OperationId=$Operation.OperationId;NodeCount=$nodes.Count;EdgeCount=@($existing.Edges|Select-Object -ExpandProperty EdgeId -Unique).Count;ProductionWrite='DISABLED'}
}

function Find-RapGraphNodes {param($Dependencies,[scriptblock]$Predicate)@(& $Dependencies.FindNodes|Where-Object $Predicate)}
function Find-RapGraphEdges {param($Dependencies,[scriptblock]$Predicate)@(& $Dependencies.FindEdges|Where-Object $Predicate)}
function Get-RapEvidenceByLibraryId {[CmdletBinding()]param([string]$LibraryId,$Dependencies)$paper="PAPER:$LibraryId";$ids=@(Find-RapGraphEdges $Dependencies {$_.SourceNodeId -eq $paper -and $_.RelationType -eq 'HAS_EVIDENCE'}|ForEach-Object TargetNodeId);@(Find-RapGraphNodes $Dependencies {$_.NodeId -in $ids})}
function Get-RapProjectMetaCodingGraph {[CmdletBinding()]param([string]$LibraryId,[string]$ProjectId,$Dependencies)$pp="PROJECT_PAPER:$LibraryId|$ProjectId";$ids=@(Find-RapGraphEdges $Dependencies {$_.SourceNodeId -eq $pp -and $_.RelationType -eq 'HAS_META_CODING'}|ForEach-Object TargetNodeId);@(Find-RapGraphNodes $Dependencies {$_.NodeId -in $ids})}
function Get-RapEffectEvidenceGraph {[CmdletBinding()]param([string]$EffectSizeNodeId,$Dependencies)$edges=Find-RapGraphEdges $Dependencies {$_.SourceNodeId -eq $EffectSizeNodeId -and $_.RelationType -in @('SUPPORTED_BY','HAS_STATISTICAL_INPUT')};$inputs=@($edges|Where-Object RelationType -eq 'HAS_STATISTICAL_INPUT'|ForEach-Object TargetNodeId);$evidence=@($edges|Where-Object RelationType -eq 'SUPPORTED_BY'|ForEach-Object TargetNodeId);$evidence+=@(Find-RapGraphEdges $Dependencies {$_.SourceNodeId -in $inputs -and $_.RelationType -eq 'SUPPORTED_BY'}|ForEach-Object TargetNodeId);[pscustomobject]@{EffectSize=& $Dependencies.GetNode $EffectSizeNodeId;StatisticalInputs=@(Find-RapGraphNodes $Dependencies {$_.NodeId -in $inputs});Evidence=@(Find-RapGraphNodes $Dependencies {$_.NodeId -in $evidence})}}
function Get-RapDerivedValueInputs {[CmdletBinding()]param([string]$DerivedValueNodeId,$Dependencies)$ids=@(Find-RapGraphEdges $Dependencies {$_.SourceNodeId -eq $DerivedValueNodeId -and $_.RelationType -eq 'DERIVED_FROM'}|ForEach-Object TargetNodeId);@(Find-RapGraphNodes $Dependencies {$_.NodeId -in $ids})}
function Get-RapEvidenceDependents {[CmdletBinding()]param([string]$EvidenceNodeId,$Dependencies)$ids=@(Find-RapGraphEdges $Dependencies {$_.TargetNodeId -eq $EvidenceNodeId -and $_.RelationType -in @('SUPPORTED_BY','EXTRACTED_FROM','HAS_EVIDENCE')}|ForEach-Object SourceNodeId);@(Find-RapGraphNodes $Dependencies {$_.NodeId -in $ids})}
function Get-RapProjectPaperGraph {[CmdletBinding()]param([string]$ProjectId,$Dependencies)$project="PROJECT:$ProjectId";$ids=@(Find-RapGraphEdges $Dependencies {$_.SourceNodeId -eq $project -and $_.RelationType -eq 'INCLUDES_PAPER_RELATIONSHIP'}|ForEach-Object TargetNodeId);@(Find-RapGraphNodes $Dependencies {$_.NodeId -in $ids})}

Export-ModuleMember -Function New-RapEvidenceNodeId,New-RapEvidenceGraphNode,New-RapEvidenceGraphEdge,New-RapEvidenceGraphOperation,Invoke-RapEvidenceGraphMutation,Get-RapEvidenceByLibraryId,Get-RapProjectMetaCodingGraph,Get-RapEffectEvidenceGraph,Get-RapDerivedValueInputs,Get-RapEvidenceDependents,Get-RapProjectPaperGraph
