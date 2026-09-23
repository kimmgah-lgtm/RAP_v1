Set-StrictMode -Version Latest
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
