Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot '../../EvidenceGraph/ResearchAutomation.EvidenceGraph.psd1')
. (Join-Path $PSScriptRoot '../../EvidenceGraph/tests/TestHarness.ps1')
function New-RapSynthesisRecord {
    param([string]$LibraryId,[string]$EffectSizeId,[double]$Effect,[double]$Variance=.04,[string]$ProjectId='PR001',[string]$ConfirmationState='RESEARCHER_CONFIRMED',[string]$EvidenceStatus='SUPPORTED',[string]$DependencyGroupId,[string]$DirectionAction='NONE',[bool]$DirectionConfirmed=$false,$Moderator=$null,[string]$EffectOrigin='REPORTED_EFFECT',$StatisticalInputs=$null,$Transformation=$null,[int]$SampleSize=100)
    if(!$DependencyGroupId){$DependencyGroupId="STUDY-$LibraryId"}
    [pscustomobject]@{ProjectId=$ProjectId;LibraryId=$LibraryId;MetaCodingId="META-$LibraryId-$ProjectId";EffectSizeId=$EffectSizeId;OutcomeId='OUT-1';ComparisonId='CMP-1';StudyArmId='ARM-1';MeasurementId='MEAS-1';TimePointId='TP-POST';DependencyGroupId=$DependencyGroupId;EffectSizeType='Hedges_g';EffectValue=$Effect;Variance=$Variance;SampleSize=$SampleSize;Moderator=$Moderator;DirectionAction=$DirectionAction;DirectionConfirmed=$DirectionConfirmed;EffectOrigin=$EffectOrigin;StatisticalInputs=$StatisticalInputs;Transformation=$Transformation;ConfirmationState=$ConfirmationState;EvidenceStatus=$EvidenceStatus;ProvenanceReference="EVIDENCE-$EffectSizeId"}
}
function New-RapBasicSynthesisFixture {
    @(
        New-RapSynthesisRecord 'LIB:L000001' ES-1 .1 .04 -Moderator ([pscustomobject]@{Region='A'});
        New-RapSynthesisRecord 'LIB:L000002' ES-2 .5 .04 -Moderator ([pscustomobject]@{Region='A'});
        New-RapSynthesisRecord 'LIB:L000003' ES-3 1.2 .04 -Moderator ([pscustomobject]@{Region='B'})
    )
}
function New-RapMemorySynthesisDependencies {
    $state=[pscustomobject]@{Operations=@{};Specifications=[Collections.Generic.List[object]]::new();Runs=[Collections.Generic.List[object]]::new();Audits=[Collections.Generic.List[object]]::new()}
    $deps=[pscustomobject]@{
        GetOperation={param($id)$state.Operations[$id]}.GetNewClosure()
        SaveOperation={param($o)$state.Operations[$o.OperationId]=$o}.GetNewClosure()
        SaveSpecification={param($s)if(-not @($state.Specifications|Where-Object{$_.AnalysisId -eq $s.AnalysisId -and $_.ConfigurationHash -eq $s.ConfigurationHash})){$state.Specifications.Add($s)}}.GetNewClosure()
        SaveRun={param($r)$existing=@($state.Runs|Where-Object RunId -eq $r.RunId);if(!$existing){$state.Runs.Add($r)}}.GetNewClosure()
        AppendAudit={param($a)$state.Audits.Add($a)}.GetNewClosure()
    }
    [pscustomobject]@{State=$state;Dependencies=$deps}
}

function New-RapSynthesisGraphHarness {
    param([Parameter(Mandatory)][object[]]$Records)
    $h=New-RapEvidenceGraphTestHarness;$nodes=[Collections.Generic.List[object]]::new();$edges=[Collections.Generic.List[object]]::new();$nodeIds=@{};$edgeIds=@{}
    function Add-Node($node){if(!$nodeIds.ContainsKey($node.NodeId)){$nodeIds[$node.NodeId]=$true;$nodes.Add($node)}}
    function Add-Edge($edge){if(!$edgeIds.ContainsKey($edge.EdgeId)){$edgeIds[$edge.EdgeId]=$true;$edges.Add($edge)}}
    foreach($r in $Records){
        $paperId="PAPER:$($r.LibraryId)";$projectId="PROJECT:$($r.ProjectId)";$ppId="PROJECT_PAPER:$($r.LibraryId)|$($r.ProjectId)";$metaId="META_CODING:$($r.LibraryId)|$($r.ProjectId)";$effectId="EFFECT_SIZE:$($r.EffectSizeId)|$($r.ProjectId)";$evidenceId=[string]$r.ProvenanceReference
        Add-Node (New-RapEvidenceGraphNode $paperId PAPER -LibraryId $r.LibraryId -Attributes ([pscustomobject]@{ReferenceOnly=$true}));Add-Node (New-RapEvidenceGraphNode $projectId PROJECT -ProjectId $r.ProjectId -Attributes ([pscustomobject]@{ReferenceOnly=$true}));Add-Node (New-RapEvidenceGraphNode $ppId PROJECT_PAPER -LibraryId $r.LibraryId -ProjectId $r.ProjectId);Add-Node (New-RapEvidenceGraphNode $metaId META_CODING -LibraryId $r.LibraryId -ProjectId $r.ProjectId -Attributes ([pscustomobject]@{ReferenceId=$r.MetaCodingId}));Add-Node (New-RapEvidenceGraphNode $effectId EFFECT_SIZE -LibraryId $r.LibraryId -ProjectId $r.ProjectId -Attributes ([pscustomobject]@{ReferenceId=$r.EffectSizeId;DependencyGroupId=$r.DependencyGroupId}));Add-Node (New-RapEvidenceGraphNode $evidenceId EVIDENCE -LibraryId $r.LibraryId -Attributes (New-RapGraphEvidenceAttributes $r.EffectValue 'SUPPORTED' "fixture:$($r.EffectSizeId)"))
        Add-Edge (New-RapEvidenceGraphEdge $projectId INCLUDES_PAPER_RELATIONSHIP $ppId -ProjectId $r.ProjectId);Add-Edge (New-RapEvidenceGraphEdge $ppId REFERENCES $paperId -ProjectId $r.ProjectId);Add-Edge (New-RapEvidenceGraphEdge $ppId HAS_META_CODING $metaId -ProjectId $r.ProjectId);Add-Edge (New-RapEvidenceGraphEdge $metaId HAS_EFFECT_SIZE $effectId -ProjectId $r.ProjectId);Add-Edge (New-RapEvidenceGraphEdge $paperId HAS_EVIDENCE $evidenceId);Add-Edge (New-RapEvidenceGraphEdge $effectId SUPPORTED_BY $evidenceId -ProjectId $r.ProjectId)
        if($r.EffectOrigin -eq 'DERIVED_EFFECT'){
            $derivedId="DERIVED_VALUE:$($r.EffectSizeId)|$($r.ProjectId)";$method=[string]$r.Transformation.Method;$version=[string]$r.Transformation.Version;Add-Node (New-RapEvidenceGraphNode $derivedId DERIVED_VALUE -LibraryId $r.LibraryId -ProjectId $r.ProjectId -Attributes ([pscustomobject]@{Value=$r.EffectValue;TransformationMethod=$method;FormulaVersion=$version;ConfirmationState=$r.ConfirmationState}));Add-Edge (New-RapEvidenceGraphEdge $effectId HAS_DERIVED_VALUE $derivedId -ProjectId $r.ProjectId)
            foreach($p in @($r.StatisticalInputs.PSObject.Properties)){$inputId="STATISTICAL_INPUT:$($r.EffectSizeId)-$($p.Name)|$($r.ProjectId)";Add-Node (New-RapEvidenceGraphNode $inputId STATISTICAL_INPUT -LibraryId $r.LibraryId -ProjectId $r.ProjectId -Attributes ([pscustomobject]@{StatisticType=$p.Name;Value=$p.Value}));Add-Edge (New-RapEvidenceGraphEdge $effectId HAS_STATISTICAL_INPUT $inputId -ProjectId $r.ProjectId);Add-Edge (New-RapEvidenceGraphEdge $derivedId DERIVED_FROM $inputId -ProjectId $r.ProjectId);Add-Edge (New-RapEvidenceGraphEdge $inputId SUPPORTED_BY $evidenceId -ProjectId $r.ProjectId)}
        }
    }
    $op=New-RapEvidenceGraphOperation @($nodes) @($edges);[void](Invoke-RapEvidenceGraphMutation $op $h.Dependencies -Mode Fixture);$h
}

function New-RapTestAnalysisDataset {
    param($Specification,[object[]]$Records)
    $graph=New-RapSynthesisGraphHarness $Records
    New-RapAnalysisDataset $Specification $Records $graph.Dependencies
}
