Set-StrictMode -Version Latest

function New-RapEvidenceFixture {
    param($Value,[string]$Status='SUPPORTED',[string]$Reference='fixture:table-2',[string]$Location='p. 12',[string]$Method='DETERMINISTIC_MOCK',[double]$Confidence=.9)
    [pscustomobject]@{Value=$Value;EvidenceStatus=$Status;SourceType='FIXTURE_PDF';SourceReference=$Reference;EvidenceLocation=$Location;EvidenceSnippet='compact fixture evidence';ExtractionMethod=$Method;Confidence=$Confidence;GeneratedAt='2026-09-22T00:00:00Z';PromptVersion='fixture-v1';SchemaVersion='spr-007.2'}
}

function New-RapMetaCodingFixtureOutput {
    [pscustomobject]@{
        Outcomes=@(
            [pscustomobject]@{OutcomeId='OUT-1';Name=(New-RapEvidenceFixture 'Achievement');Construct='Academic achievement';Category='Primary'},
            [pscustomobject]@{OutcomeId='OUT-2';Name=(New-RapEvidenceFixture 'Engagement');Construct='Engagement';Category='Secondary'}
        )
        Comparisons=@(
            [pscustomobject]@{ComparisonId='CMP-1';OutcomeId='OUT-1';InterventionGroup='Intervention';ComparatorGroup='Control';Definition='Intervention versus control'},
            [pscustomobject]@{ComparisonId='CMP-2';OutcomeId='OUT-1';InterventionGroup='High dose';ComparatorGroup='Low dose';Definition='Dose comparison'}
        )
        StudyArms=@(
            [pscustomobject]@{StudyArmId='ARM-I';Name='Intervention';Role='INTERVENTION'},
            [pscustomobject]@{StudyArmId='ARM-C';Name='Control';Role='COMPARATOR'}
        )
        Measurements=@(
            [pscustomobject]@{MeasurementId='MEAS-1';OutcomeId='OUT-1';InstrumentName='Achievement Test';InstrumentVersion='1'}
        )
        TimePoints=@(
            [pscustomobject]@{TimePointId='TP-POST';Label='Post-test';Offset='0d'},
            [pscustomobject]@{TimePointId='TP-FU';Label='Follow-up';Offset='90d'}
        )
        StatisticalInputs=@(
            [pscustomobject]@{InputId='STAT-M1';StatisticType='MEAN';StudyArmId='ARM-I';Value=(New-RapEvidenceFixture 12.4)},
            [pscustomobject]@{InputId='STAT-SD1';StatisticType='SD';StudyArmId='ARM-I';Value=(New-RapEvidenceFixture 3.1)},
            [pscustomobject]@{InputId='STAT-M2';StatisticType='MEAN';StudyArmId='ARM-C';Value=(New-RapEvidenceFixture 10.8)},
            [pscustomobject]@{InputId='STAT-SD2';StatisticType='SD';StudyArmId='ARM-C';Value=(New-RapEvidenceFixture 3.0)},
            [pscustomobject]@{InputId='STAT-CONFLICT';StatisticType='SE';Value=(New-RapEvidenceFixture $null 'CONFLICTING_EVIDENCE')},
            [pscustomobject]@{InputId='STAT-UNCLEAR';StatisticType='CI';Value=(New-RapEvidenceFixture $null 'UNCERTAIN')}
        )
        SampleSizes=@(
            [pscustomobject]@{SampleSizeId='N-1';StudyArmId='ARM-I';TotalN=(New-RapEvidenceFixture 80);GroupN=(New-RapEvidenceFixture 40);AnalyticN=(New-RapEvidenceFixture 38)},
            [pscustomobject]@{SampleSizeId='N-2';StudyArmId='ARM-C';TotalN=(New-RapEvidenceFixture $null 'NOT_REPORTED' '' '' 'DETERMINISTIC_MOCK' 0)}
        )
        Moderators=@(
            [pscustomobject]@{ModeratorId='MOD-1';Name='School level';Category='Participant';Value=(New-RapEvidenceFixture 'Secondary')}
        )
        EffectSizes=@(
            [pscustomobject]@{EffectSizeId='ES-1';OutcomeId='OUT-1';ComparisonId='CMP-1';TimePointId='TP-POST';StudyArmIds=@('ARM-I','ARM-C');MeasurementId='MEAS-1';DependencyGroupId='STUDY-1';EffectSizeType='Hedges_g';EffectValue=(New-RapEvidenceFixture .42);StatisticalInputIds=@('STAT-M1','STAT-SD1','STAT-M2','STAT-SD2');Derivation=[pscustomobject]@{IsDerived=$true;TransformationMethod='SMD_TO_HEDGES_G';FormulaVersion='1.0';SourceValueReferences=@('STAT-M1','STAT-SD1','STAT-M2','STAT-SD2');DerivedValue=.42}},
            [pscustomobject]@{EffectSizeId='ES-2';OutcomeId='OUT-1';ComparisonId='CMP-2';TimePointId='TP-FU';StudyArmIds=@('ARM-I','ARM-C');MeasurementId='MEAS-1';DependencyGroupId='STUDY-1';EffectSizeType='Cohens_d';EffectValue=(New-RapEvidenceFixture .31 'INFERRED');StatisticalInputIds=@('STAT-M1','STAT-M2');Derivation=[pscustomobject]@{IsDerived=$false}}
        )
    }
}

function New-RapMetaCodingTestHarness {
    [CmdletBinding()]param()
    $state=[ordered]@{Operations=@{};Codings=@{};Membership=@{};Audit=[Collections.Generic.List[object]]::new();ExtractCalls=0;UpsertCalls=0;CommonReviewWrites=0;ProductionWrites=0;FailNextUpsert=$false}
    foreach($project in @('PR001','PR002')){$state.Membership["LIB:L000001|$project"]=[pscustomobject]@{LibraryId='LIB:L000001';ProjectId=$project}}
    $defaultOutput=New-RapMetaCodingFixtureOutput
    $dependencies=[pscustomobject]@{
        GetProjectPaper={param($libraryId,$projectId)$key="$libraryId|$projectId";if($state.Membership.ContainsKey($key)){$state.Membership[$key]}else{$null}}.GetNewClosure()
        GetOperation={param($operationId)if($state.Operations.ContainsKey($operationId)){$state.Operations[$operationId]}else{$null}}.GetNewClosure()
        SaveOperation={param($operation)$state.Operations[$operation.OperationId]=$operation}.GetNewClosure()
        ExtractAssistedCoding={param($request)$state.ExtractCalls++;$defaultOutput}.GetNewClosure()
        GetExistingCoding={param($libraryId,$projectId)$key="$libraryId|$projectId";if($state.Codings.ContainsKey($key)){$state.Codings[$key]}else{$null}}.GetNewClosure()
        UpsertProjectCoding={param($record)$state.UpsertCalls++;if($state.FailNextUpsert){$state.FailNextUpsert=$false;throw 'SIMULATED_WRITE_INTERRUPTION'};$state.Codings[$record.ScopeKey]=$record;[pscustomobject]@{Status='UPSERTED';ScopeKey=$record.ScopeKey}}.GetNewClosure()
        AppendAudit={param($record)$state.Audit.Add($record)}.GetNewClosure()
    }
    [pscustomobject]@{State=$state;Dependencies=$dependencies;DefaultOutput=$defaultOutput}
}
