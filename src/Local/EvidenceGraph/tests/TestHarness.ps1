Set-StrictMode -Version Latest

function New-RapGraphEvidenceAttributes {
    param($Value,[string]$Status='SUPPORTED',[string]$Reference='fixture:table-2',[string]$Location='p. 12')
    [pscustomobject]@{Value=$Value;EvidenceStatus=$Status;SourceType='FIXTURE_PDF';SourceReference=$Reference;EvidenceLocation=$Location;EvidenceSnippet='compact fixture evidence';ExtractionMethod='DETERMINISTIC_MOCK';Confidence=.9;GeneratedAt='2026-09-22T00:00:00Z';PromptVersion='fixture-v1';SchemaVersion='spr-008.1'}
}

function New-RapEvidenceGraphFixture {
    $evA=New-RapEvidenceNodeId (New-RapGraphEvidenceAttributes 120 'CONFLICTING_EVIDENCE' 'fixture:table-a')
    $evB=New-RapEvidenceNodeId (New-RapGraphEvidenceAttributes 118 'CONFLICTING_EVIDENCE' 'fixture:table-b')
    $evUncertain=New-RapEvidenceNodeId (New-RapGraphEvidenceAttributes $null 'UNCERTAIN' 'fixture:text')
    $evMissing=New-RapEvidenceNodeId (New-RapGraphEvidenceAttributes $null 'NOT_REPORTED' '')
    $nodes=@(
        New-RapEvidenceGraphNode 'PAPER:LIB:L000001' PAPER -LibraryId 'LIB:L000001' -Attributes ([pscustomobject]@{ReferenceOnly=$true});
        New-RapEvidenceGraphNode 'PROJECT:PR001' PROJECT -ProjectId PR001 -Attributes ([pscustomobject]@{ReferenceOnly=$true});
        New-RapEvidenceGraphNode 'PROJECT:PR002' PROJECT -ProjectId PR002 -Attributes ([pscustomobject]@{ReferenceOnly=$true});
        New-RapEvidenceGraphNode 'PROJECT_PAPER:LIB:L000001|PR001' PROJECT_PAPER -LibraryId 'LIB:L000001' -ProjectId PR001;
        New-RapEvidenceGraphNode 'PROJECT_PAPER:LIB:L000001|PR002' PROJECT_PAPER -LibraryId 'LIB:L000001' -ProjectId PR002;
        New-RapEvidenceGraphNode 'COMMON_REVIEW:LIB:L000001' COMMON_REVIEW -LibraryId 'LIB:L000001' -Attributes ([pscustomobject]@{ReferenceId='REVIEW-1'});
        New-RapEvidenceGraphNode $evA EVIDENCE -LibraryId 'LIB:L000001' -Attributes (New-RapGraphEvidenceAttributes 120 'CONFLICTING_EVIDENCE' 'fixture:table-a');
        New-RapEvidenceGraphNode $evB EVIDENCE -LibraryId 'LIB:L000001' -Attributes (New-RapGraphEvidenceAttributes 118 'CONFLICTING_EVIDENCE' 'fixture:table-b');
        New-RapEvidenceGraphNode $evUncertain EVIDENCE -LibraryId 'LIB:L000001' -Attributes (New-RapGraphEvidenceAttributes $null 'UNCERTAIN' 'fixture:text');
        New-RapEvidenceGraphNode $evMissing EVIDENCE -LibraryId 'LIB:L000001' -Attributes (New-RapGraphEvidenceAttributes $null 'NOT_REPORTED' '');
        New-RapEvidenceGraphNode 'AI_EXTRACTION:AE-1' AI_EXTRACTION -LibraryId 'LIB:L000001' -Attributes ([pscustomobject]@{OriginState='AI_ASSISTED';ExtractedValue=120});
        New-RapEvidenceGraphNode 'META_CODING:LIB:L000001|PR001' META_CODING -LibraryId 'LIB:L000001' -ProjectId PR001 -Attributes ([pscustomobject]@{ReferenceId='META-PR001'});
        New-RapEvidenceGraphNode 'META_CODING:LIB:L000001|PR002' META_CODING -LibraryId 'LIB:L000001' -ProjectId PR002 -Attributes ([pscustomobject]@{ReferenceId='META-PR002'});
        New-RapEvidenceGraphNode 'OUTCOME:OUT-1|PR001' OUTCOME -LibraryId 'LIB:L000001' -ProjectId PR001 -Attributes ([pscustomobject]@{ReferenceId='OUT-1'});
        New-RapEvidenceGraphNode 'OUTCOME:OUT-2|PR001' OUTCOME -LibraryId 'LIB:L000001' -ProjectId PR001 -Attributes ([pscustomobject]@{ReferenceId='OUT-2'});
        New-RapEvidenceGraphNode 'COMPARISON:CMP-1|PR001' COMPARISON -LibraryId 'LIB:L000001' -ProjectId PR001 -Attributes ([pscustomobject]@{ReferenceId='CMP-1'});
        New-RapEvidenceGraphNode 'EFFECT_SIZE:ES-1|PR001' EFFECT_SIZE -LibraryId 'LIB:L000001' -ProjectId PR001 -Attributes ([pscustomobject]@{ReferenceId='ES-1';DependencyGroupId='STUDY-1'});
        New-RapEvidenceGraphNode 'EFFECT_SIZE:ES-2|PR001' EFFECT_SIZE -LibraryId 'LIB:L000001' -ProjectId PR001 -Attributes ([pscustomobject]@{ReferenceId='ES-2';DependencyGroupId='STUDY-1'});
        New-RapEvidenceGraphNode 'MEASUREMENT:MEAS-1|PR001' MEASUREMENT -LibraryId 'LIB:L000001' -ProjectId PR001;
        New-RapEvidenceGraphNode 'TIME_POINT:TP-POST|PR001' TIME_POINT -LibraryId 'LIB:L000001' -ProjectId PR001;
        New-RapEvidenceGraphNode 'STATISTICAL_INPUT:MEAN|PR001' STATISTICAL_INPUT -LibraryId 'LIB:L000001' -ProjectId PR001 -Attributes ([pscustomobject]@{StatisticType='MEAN';Value=12.4});
        New-RapEvidenceGraphNode 'STATISTICAL_INPUT:SD|PR001' STATISTICAL_INPUT -LibraryId 'LIB:L000001' -ProjectId PR001 -Attributes ([pscustomobject]@{StatisticType='SD';Value=3.1});
        New-RapEvidenceGraphNode 'STATISTICAL_INPUT:N|PR001' STATISTICAL_INPUT -LibraryId 'LIB:L000001' -ProjectId PR001 -Attributes ([pscustomobject]@{StatisticType='N';Value=120});
        New-RapEvidenceGraphNode 'DERIVED_VALUE:HEDGES_G|PR001' DERIVED_VALUE -LibraryId 'LIB:L000001' -ProjectId PR001 -Attributes ([pscustomobject]@{Value=.42;TransformationMethod='SMD_TO_HEDGES_G';FormulaVersion='1.0';ConfirmationState='AI_ASSISTED'});
        New-RapEvidenceGraphNode 'RESEARCHER_CONFIRMED:RC-1|PR001' RESEARCHER_CONFIRMED_RECORD -LibraryId 'LIB:L000001' -ProjectId PR001 -Attributes ([pscustomobject]@{ReferenceId='RC-1';ConfirmationState='RESEARCHER_CONFIRMED'})
    )
    $edges=@(
        New-RapEvidenceGraphEdge 'PAPER:LIB:L000001' HAS_COMMON_REVIEW 'COMMON_REVIEW:LIB:L000001';
        New-RapEvidenceGraphEdge 'PROJECT:PR001' INCLUDES_PAPER_RELATIONSHIP 'PROJECT_PAPER:LIB:L000001|PR001' -ProjectId PR001;
        New-RapEvidenceGraphEdge 'PROJECT:PR002' INCLUDES_PAPER_RELATIONSHIP 'PROJECT_PAPER:LIB:L000001|PR002' -ProjectId PR002;
        New-RapEvidenceGraphEdge 'PROJECT_PAPER:LIB:L000001|PR001' REFERENCES 'PAPER:LIB:L000001' -ProjectId PR001;
        New-RapEvidenceGraphEdge 'PROJECT_PAPER:LIB:L000001|PR002' REFERENCES 'PAPER:LIB:L000001' -ProjectId PR002;
        New-RapEvidenceGraphEdge 'PROJECT_PAPER:LIB:L000001|PR001' HAS_META_CODING 'META_CODING:LIB:L000001|PR001' -ProjectId PR001;
        New-RapEvidenceGraphEdge 'PROJECT_PAPER:LIB:L000001|PR002' HAS_META_CODING 'META_CODING:LIB:L000001|PR002' -ProjectId PR002;
        New-RapEvidenceGraphEdge 'META_CODING:LIB:L000001|PR001' HAS_OUTCOME 'OUTCOME:OUT-1|PR001' -ProjectId PR001;
        New-RapEvidenceGraphEdge 'META_CODING:LIB:L000001|PR001' HAS_OUTCOME 'OUTCOME:OUT-2|PR001' -ProjectId PR001;
        New-RapEvidenceGraphEdge 'META_CODING:LIB:L000001|PR001' HAS_COMPARISON 'COMPARISON:CMP-1|PR001' -ProjectId PR001;
        New-RapEvidenceGraphEdge 'META_CODING:LIB:L000001|PR001' HAS_EFFECT_SIZE 'EFFECT_SIZE:ES-1|PR001' -ProjectId PR001;
        New-RapEvidenceGraphEdge 'META_CODING:LIB:L000001|PR001' HAS_EFFECT_SIZE 'EFFECT_SIZE:ES-2|PR001' -ProjectId PR001;
        New-RapEvidenceGraphEdge 'EFFECT_SIZE:ES-1|PR001' HAS_STATISTICAL_INPUT 'STATISTICAL_INPUT:MEAN|PR001' -ProjectId PR001;
        New-RapEvidenceGraphEdge 'EFFECT_SIZE:ES-1|PR001' HAS_STATISTICAL_INPUT 'STATISTICAL_INPUT:SD|PR001' -ProjectId PR001;
        New-RapEvidenceGraphEdge 'EFFECT_SIZE:ES-1|PR001' HAS_STATISTICAL_INPUT 'STATISTICAL_INPUT:N|PR001' -ProjectId PR001;
        New-RapEvidenceGraphEdge 'EFFECT_SIZE:ES-1|PR001' HAS_DERIVED_VALUE 'DERIVED_VALUE:HEDGES_G|PR001' -ProjectId PR001;
        New-RapEvidenceGraphEdge 'DERIVED_VALUE:HEDGES_G|PR001' DERIVED_FROM 'STATISTICAL_INPUT:MEAN|PR001' -ProjectId PR001;
        New-RapEvidenceGraphEdge 'DERIVED_VALUE:HEDGES_G|PR001' DERIVED_FROM 'STATISTICAL_INPUT:SD|PR001' -ProjectId PR001;
        New-RapEvidenceGraphEdge 'DERIVED_VALUE:HEDGES_G|PR001' DERIVED_FROM 'STATISTICAL_INPUT:N|PR001' -ProjectId PR001;
        New-RapEvidenceGraphEdge 'AI_EXTRACTION:AE-1' EXTRACTED_FROM $evA;
        New-RapEvidenceGraphEdge 'RESEARCHER_CONFIRMED:RC-1|PR001' CONFIRMS 'AI_EXTRACTION:AE-1' -ProjectId PR001
    )
    foreach($ev in @($evA,$evB,$evUncertain,$evMissing)){$edges+=New-RapEvidenceGraphEdge 'PAPER:LIB:L000001' HAS_EVIDENCE $ev}
    foreach($input in @('STATISTICAL_INPUT:MEAN|PR001','STATISTICAL_INPUT:SD|PR001','STATISTICAL_INPUT:N|PR001')){$edges+=New-RapEvidenceGraphEdge $input SUPPORTED_BY $evA -ProjectId PR001}
    $edges+=New-RapEvidenceGraphEdge 'EFFECT_SIZE:ES-1|PR001' SUPPORTED_BY $evA -ProjectId PR001
    [pscustomobject]@{Nodes=$nodes;Edges=$edges;EvidenceA=$evA;EvidenceB=$evB;Uncertain=$evUncertain;Missing=$evMissing}
}

function New-RapEvidenceGraphTestHarness {
    $state=[ordered]@{Operations=@{};Nodes=@{};Edges=@{};Audit=[Collections.Generic.List[object]]::new();NodeUpserts=0;EdgeUpserts=0;ProductionWrites=0;ExternalCalls=0;CommonReviewWrites=0;FailNextEdge=$false;ExternalTests='TEST_DEFERRED'}
    $deps=[pscustomobject]@{
        GetOperation={param($id)if($state.Operations.ContainsKey($id)){$state.Operations[$id]}else{$null}}.GetNewClosure()
        SaveOperation={param($op)$state.Operations[$op.OperationId]=$op}.GetNewClosure()
        GetNode={param($id)if($state.Nodes.ContainsKey($id)){$state.Nodes[$id]}else{$null}}.GetNewClosure()
        UpsertNode={param($node)$state.NodeUpserts++;$state.Nodes[$node.NodeId]=$node;[pscustomobject]@{Status='UPSERTED'}}.GetNewClosure()
        GetEdge={param($id)if($state.Edges.ContainsKey($id)){$state.Edges[$id]}else{$null}}.GetNewClosure()
        UpsertEdge={param($edge)if($state.FailNextEdge){$state.FailNextEdge=$false;throw 'SIMULATED_GRAPH_INTERRUPTION'};$state.EdgeUpserts++;$state.Edges[$edge.EdgeId]=$edge;[pscustomobject]@{Status='UPSERTED'}}.GetNewClosure()
        FindNodes={@($state.Nodes.Values)}.GetNewClosure()
        FindEdges={@($state.Edges.Values)}.GetNewClosure()
        AppendAudit={param($record)$state.Audit.Add($record)}.GetNewClosure()
    }
    [pscustomobject]@{State=$state;Dependencies=$deps}
}
