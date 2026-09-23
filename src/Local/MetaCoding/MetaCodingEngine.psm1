Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:RapMetaCollections=@('Outcomes','Comparisons','EffectSizes','SampleSizes','Moderators','StudyArms','Measurements','TimePoints','StatisticalInputs')
$script:RapMetaHumanOwnedFields=@('EffectSizeInclusion','OutcomeSelection','ComparisonSelection','ModeratorClassification','DependencyHandling','RiskJudgment','StudyExclusion','StatisticalTransformationDecision','MetaAnalysisEligibility','ConflictResolution','ResearcherMemo','CriticalAppraisal','ReviewerInterpretation','ReviewerMemo')
$script:RapMetaCommonReviewFields=@('Title','Abstract','CommonStudyReview','NotionStudyReview','CommonReviewUpdates','BibliographicMetadata','CanonicalPdf')
$script:RapEvidenceStatuses=@('SUPPORTED','INFERRED','NOT_REPORTED','UNCERTAIN','CONFLICTING_EVIDENCE')

function ConvertTo-RapCanonicalValue {
    param($Value)
    if($null -eq $Value){return $null}
    if($Value -is [Collections.IDictionary]){$result=[ordered]@{};foreach($key in @($Value.Keys|ForEach-Object{[string]$_}|Sort-Object)){$result[$key]=ConvertTo-RapCanonicalValue $Value[$key]};return $result}
    if($Value -is [Management.Automation.PSCustomObject]){$result=[ordered]@{};foreach($property in @($Value.PSObject.Properties|Sort-Object Name)){$result[$property.Name]=ConvertTo-RapCanonicalValue $property.Value};return $result}
    if($Value -is [Collections.IEnumerable] -and $Value -isnot [string]){return @($Value|ForEach-Object{ConvertTo-RapCanonicalValue $_})}
    $Value
}

function Get-RapMetaHash {param([Parameter(Mandatory)]$Value)$json=(ConvertTo-RapCanonicalValue $Value)|ConvertTo-Json -Depth 50 -Compress;[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($json))).ToLowerInvariant()}
function Get-RapMetaEntries {param($Value)if($null -eq $Value){return @()};if($Value -is [Collections.IDictionary]){return @($Value.GetEnumerator()|ForEach-Object{[pscustomobject]@{Name=[string]$_.Key;Value=$_.Value}})};@($Value.PSObject.Properties|ForEach-Object{[pscustomobject]@{Name=$_.Name;Value=$_.Value}})}
function Get-RapMetaPropertyValue {param($Object,[Parameter(Mandatory)][string]$Name)if($null -eq $Object){return $null};if($Object -is [Collections.IDictionary]){foreach($key in $Object.Keys){if([string]$key -ieq $Name){return $Object[$key]}};return $null};$property=$Object.PSObject.Properties|Where-Object Name -IEQ $Name|Select-Object -First 1;if($property){$property.Value}else{$null}}

function New-RapMetaCodingRequest {
    [CmdletBinding()]param(
        [Parameter(Mandatory)][ValidatePattern('^LIB:L\d{6}$')][string]$LibraryId,
        [Parameter(Mandatory)][ValidatePattern('^PR\d{3}$')][string]$ProjectId,
        [Parameter(Mandatory)]$SourceEvidence,
        [string]$SchemaVersion='spr-007.2',
        [ValidatePattern('^[A-Za-z0-9._:-]+$')][string]$OperationId
    )
    $inputHash=Get-RapMetaHash ([ordered]@{LibraryId=$LibraryId;ProjectId=$ProjectId;SchemaVersion=$SchemaVersion;SourceEvidence=$SourceEvidence})
    $payloadHash=Get-RapMetaHash ([ordered]@{LibraryId=$LibraryId;ProjectId=$ProjectId;InputHash=$inputHash;SchemaVersion=$SchemaVersion})
    if([string]::IsNullOrWhiteSpace($OperationId)){$OperationId='META-'+$payloadHash.Substring(0,24)}
    [pscustomobject]@{OperationId=$OperationId;LibraryId=$LibraryId;ProjectId=$ProjectId;ScopeKey="$LibraryId|$ProjectId";SchemaVersion=$SchemaVersion;SourceEvidence=$SourceEvidence;InputHash=$inputHash;PayloadHash=$payloadHash}
}

function Assert-RapMetaNoProtectedKeys {
    param($Value,[string]$Path='AiAssisted')
    foreach($entry in @(Get-RapMetaEntries $Value)){
        if($script:RapMetaHumanOwnedFields -icontains $entry.Name){throw "HUMAN_OWNED_FIELD_BLOCKED: $Path.$($entry.Name)"}
        if($script:RapMetaCommonReviewFields -icontains $entry.Name){throw "COMMON_REVIEW_FIELD_BLOCKED: $Path.$($entry.Name)"}
        if($entry.Value -is [Collections.IDictionary] -or $entry.Value -is [Management.Automation.PSCustomObject]){Assert-RapMetaNoProtectedKeys $entry.Value "$Path.$($entry.Name)"}
        elseif($entry.Value -is [Collections.IEnumerable] -and $entry.Value -isnot [string]){foreach($item in $entry.Value){if($item -is [Collections.IDictionary] -or $item -is [Management.Automation.PSCustomObject]){Assert-RapMetaNoProtectedKeys $item "$Path.$($entry.Name)"}}}
    }
}

function Assert-RapEvidenceValue {
    param($Value,[string]$Path)
    $status=[string](Get-RapMetaPropertyValue $Value 'EvidenceStatus')
    if($script:RapEvidenceStatuses -inotcontains $status){throw "INVALID_EVIDENCE_STATUS: $Path"}
    $confidence=Get-RapMetaPropertyValue $Value 'Confidence'
    if($null -ne $confidence -and ([double]$confidence -lt 0 -or [double]$confidence -gt 1)){throw "INVALID_CONFIDENCE: $Path"}
    if($status -ne 'NOT_REPORTED' -and [string]::IsNullOrWhiteSpace([string](Get-RapMetaPropertyValue $Value 'SourceReference'))){throw "SOURCE_REFERENCE_REQUIRED: $Path"}
    if([string]::IsNullOrWhiteSpace([string](Get-RapMetaPropertyValue $Value 'ExtractionMethod'))){throw "EXTRACTION_METHOD_REQUIRED: $Path"}
}

function Assert-RapUniqueMetaIds {
    param([object[]]$Items,[string]$IdName,[string]$Collection)
    $seen=@{};foreach($item in $Items){$id=[string](Get-RapMetaPropertyValue $item $IdName);if([string]::IsNullOrWhiteSpace($id)){throw "IDENTITY_REQUIRED: $Collection.$IdName"};if($seen.ContainsKey($id)){throw "DUPLICATE_ID: $Collection.$id"};$seen[$id]=$true};$seen
}

function ConvertTo-RapValidatedAssistedCoding {
    param([Parameter(Mandatory)]$Output)
    Assert-RapMetaNoProtectedKeys $Output
    foreach($entry in @(Get-RapMetaEntries $Output)){
        if($entry.Name -ieq 'CodingStatus'){if([string]$entry.Value -ne 'AI_ASSISTED'){throw 'AI_CODING_STATUS_INVALID'};continue}
        if($script:RapMetaCollections -inotcontains $entry.Name){throw "UNAPPROVED_META_COLLECTION: $($entry.Name)"}
    }
    $collections=[ordered]@{};foreach($name in $script:RapMetaCollections){$value=Get-RapMetaPropertyValue $Output $name;$collections[$name]=@($value)}
    $outcomeIds=Assert-RapUniqueMetaIds $collections.Outcomes 'OutcomeId' 'Outcomes'
    $comparisonIds=Assert-RapUniqueMetaIds $collections.Comparisons 'ComparisonId' 'Comparisons'
    [void](Assert-RapUniqueMetaIds $collections.EffectSizes 'EffectSizeId' 'EffectSizes')
    [void](Assert-RapUniqueMetaIds $collections.SampleSizes 'SampleSizeId' 'SampleSizes')
    [void](Assert-RapUniqueMetaIds $collections.Moderators 'ModeratorId' 'Moderators')
    $armIds=Assert-RapUniqueMetaIds $collections.StudyArms 'StudyArmId' 'StudyArms'
    [void](Assert-RapUniqueMetaIds $collections.Measurements 'MeasurementId' 'Measurements')
    $timeIds=Assert-RapUniqueMetaIds $collections.TimePoints 'TimePointId' 'TimePoints'
    $inputIds=Assert-RapUniqueMetaIds $collections.StatisticalInputs 'InputId' 'StatisticalInputs'
    foreach($item in $collections.Outcomes){Assert-RapEvidenceValue (Get-RapMetaPropertyValue $item 'Name') "Outcomes.$(Get-RapMetaPropertyValue $item 'OutcomeId').Name"}
    foreach($item in $collections.Comparisons){$outcomeId=[string](Get-RapMetaPropertyValue $item 'OutcomeId');if(-not $outcomeIds.ContainsKey($outcomeId)){throw 'COMPARISON_OUTCOME_REFERENCE_INVALID'}}
    foreach($item in $collections.Measurements){$outcomeId=[string](Get-RapMetaPropertyValue $item 'OutcomeId');if(-not $outcomeIds.ContainsKey($outcomeId)){throw 'MEASUREMENT_OUTCOME_REFERENCE_INVALID'}}
    foreach($item in $collections.StatisticalInputs){Assert-RapEvidenceValue (Get-RapMetaPropertyValue $item 'Value') "StatisticalInputs.$(Get-RapMetaPropertyValue $item 'InputId').Value"}
    foreach($item in $collections.SampleSizes){foreach($field in @('TotalN','GroupN','AnalyticN')){$value=Get-RapMetaPropertyValue $item $field;if($null -ne $value){Assert-RapEvidenceValue $value "SampleSizes.$(Get-RapMetaPropertyValue $item 'SampleSizeId').$field"}}}
    foreach($item in $collections.Moderators){Assert-RapEvidenceValue (Get-RapMetaPropertyValue $item 'Value') "Moderators.$(Get-RapMetaPropertyValue $item 'ModeratorId').Value"}
    foreach($effect in $collections.EffectSizes){
        $effectId=[string](Get-RapMetaPropertyValue $effect 'EffectSizeId');$outcomeId=[string](Get-RapMetaPropertyValue $effect 'OutcomeId');$comparisonId=[string](Get-RapMetaPropertyValue $effect 'ComparisonId')
        if(-not $outcomeIds.ContainsKey($outcomeId)){throw 'EFFECT_OUTCOME_REFERENCE_INVALID'};if(-not $comparisonIds.ContainsKey($comparisonId)){throw 'EFFECT_COMPARISON_REFERENCE_INVALID'}
        $timePointId=[string](Get-RapMetaPropertyValue $effect 'TimePointId');if($timePointId -and -not $timeIds.ContainsKey($timePointId)){throw 'EFFECT_TIMEPOINT_REFERENCE_INVALID'}
        foreach($armId in @((Get-RapMetaPropertyValue $effect 'StudyArmIds'))){if(-not $armIds.ContainsKey([string]$armId)){throw 'EFFECT_STUDY_ARM_REFERENCE_INVALID'}}
        foreach($inputId in @((Get-RapMetaPropertyValue $effect 'StatisticalInputIds'))){if(-not $inputIds.ContainsKey([string]$inputId)){throw 'EFFECT_STATISTICAL_INPUT_REFERENCE_INVALID'}}
        if([string]::IsNullOrWhiteSpace([string](Get-RapMetaPropertyValue $effect 'DependencyGroupId'))){throw "DEPENDENCY_ID_REQUIRED: $effectId"}
        if([string]::IsNullOrWhiteSpace([string](Get-RapMetaPropertyValue $effect 'EffectSizeType'))){throw "EFFECT_SIZE_TYPE_REQUIRED: $effectId"}
        Assert-RapEvidenceValue (Get-RapMetaPropertyValue $effect 'EffectValue') "EffectSizes.$effectId.EffectValue"
        $derivation=Get-RapMetaPropertyValue $effect 'Derivation';if($null -ne $derivation -and [bool](Get-RapMetaPropertyValue $derivation 'IsDerived')){if([string]::IsNullOrWhiteSpace([string](Get-RapMetaPropertyValue $derivation 'TransformationMethod')) -or [string]::IsNullOrWhiteSpace([string](Get-RapMetaPropertyValue $derivation 'FormulaVersion')) -or @((Get-RapMetaPropertyValue $derivation 'SourceValueReferences')).Count -eq 0){throw "DERIVATION_PROVENANCE_REQUIRED: $effectId"}}
    }
    [pscustomobject]@{CodingStatus='AI_ASSISTED';Outcomes=$collections.Outcomes;Comparisons=$collections.Comparisons;EffectSizes=$collections.EffectSizes;SampleSizes=$collections.SampleSizes;Moderators=$collections.Moderators;StudyArms=$collections.StudyArms;Measurements=$collections.Measurements;TimePoints=$collections.TimePoints;StatisticalInputs=$collections.StatisticalInputs}
}

function Assert-RapMetaDependencies {param($Dependencies,[string[]]$Names)foreach($name in $Names){if($null -eq $Dependencies.PSObject.Properties[$name] -or $Dependencies.$name -isnot [scriptblock]){throw "Meta Coding dependency must be a script block: $name"}}}
function New-RapMetaOperationState {param($Request,[string]$State,$AssistedCoding,$Patch)[pscustomobject]@{OperationId=$Request.OperationId;PayloadHash=$Request.PayloadHash;InputHash=$Request.InputHash;LibraryId=$Request.LibraryId;ProjectId=$Request.ProjectId;ScopeKey=$Request.ScopeKey;SchemaVersion=$Request.SchemaVersion;State=$State;AssistedCoding=$AssistedCoding;Patch=$Patch;UpdatedAt=[DateTimeOffset]::UtcNow.ToString('o')}}

function Invoke-RapMetaCoding {
    [CmdletBinding()]param([Parameter(Mandatory)]$Request,[Parameter(Mandatory)]$Dependencies,[ValidateSet('DryRun','Fixture')][string]$Mode='DryRun')
    Assert-RapMetaDependencies $Dependencies @('GetProjectPaper','GetOperation','SaveOperation','ExtractAssistedCoding','GetExistingCoding','UpsertProjectCoding','AppendAudit')
    $membership=& $Dependencies.GetProjectPaper $Request.LibraryId $Request.ProjectId;if($null -eq $membership){throw 'PROJECT_PAPER_MEMBERSHIP_REQUIRED'}
    if([string](Get-RapMetaPropertyValue $membership 'LibraryId') -ne $Request.LibraryId -or [string](Get-RapMetaPropertyValue $membership 'ProjectId') -ne $Request.ProjectId){throw 'PROJECT_PAPER_SCOPE_MISMATCH'}
    $existingOperation=& $Dependencies.GetOperation $Request.OperationId;if($existingOperation -and [string]$existingOperation.PayloadHash -ne $Request.PayloadHash){throw 'PAYLOAD_CONFLICT'}
    if($existingOperation -and [string]$existingOperation.State -eq 'COMPLETED'){return [pscustomobject]@{Status='ALREADY_COMPLETED';Mode=$Mode;OperationId=$Request.OperationId;ScopeKey=$Request.ScopeKey;Record=$existingOperation.Patch}}
    $existingCoding=& $Dependencies.GetExistingCoding $Request.LibraryId $Request.ProjectId
    if($Mode -eq 'DryRun'){return [pscustomobject]@{Status='DRY_RUN';Mode=$Mode;OperationId=$Request.OperationId;ScopeKey=$Request.ScopeKey;Existing=$existingCoding;ProductionWrite='DISABLED';ChangesApplied=$false}}
    $operation=$existingOperation;if($null -eq $operation){$operation=New-RapMetaOperationState $Request 'PLANNED' $null $null;& $Dependencies.SaveOperation $operation}
    $assisted=$operation.AssistedCoding
    if($null -eq $assisted){$assisted=ConvertTo-RapValidatedAssistedCoding (& $Dependencies.ExtractAssistedCoding $Request);$operation=New-RapMetaOperationState $Request 'EXTRACTED' $assisted $null;& $Dependencies.SaveOperation $operation}else{$assisted=ConvertTo-RapValidatedAssistedCoding $assisted}
    $operation=New-RapMetaOperationState $Request 'VALIDATED' $assisted $operation.Patch;& $Dependencies.SaveOperation $operation
    $patch=$operation.Patch
    if($null -eq $patch){$patch=[pscustomobject]@{LibraryId=$Request.LibraryId;ProjectId=$Request.ProjectId;ScopeKey=$Request.ScopeKey;SchemaVersion=$Request.SchemaVersion;AiAssisted=$assisted;ResearcherConfirmed=(Get-RapMetaPropertyValue $existingCoding 'ResearcherConfirmed');Ownership=[pscustomobject]@{AiAssisted=$script:RapMetaCollections;HumanOwned=$script:RapMetaHumanOwnedFields};CommonReviewMutation=$false;ProductionWrite='DISABLED';UpdatedAt=[DateTimeOffset]::UtcNow.ToString('o')};$operation=New-RapMetaOperationState $Request 'PATCH_PREPARED' $assisted $patch;& $Dependencies.SaveOperation $operation}
    $writeResult=& $Dependencies.UpsertProjectCoding $patch;$operation=New-RapMetaOperationState $Request 'COMPLETED' $assisted $patch;& $Dependencies.SaveOperation $operation
    & $Dependencies.AppendAudit ([pscustomobject]@{OperationId=$Request.OperationId;LibraryId=$Request.LibraryId;ProjectId=$Request.ProjectId;ScopeKey=$Request.ScopeKey;Action='META_CODING_FIXTURE_UPSERT';Status='COMPLETED';Timestamp=[DateTimeOffset]::UtcNow.ToString('o')})
    [pscustomobject]@{Status='COMPLETED';Mode=$Mode;OperationId=$Request.OperationId;ScopeKey=$Request.ScopeKey;Record=$patch;WriteResult=$writeResult;ProductionWrite='DISABLED'}
}

function Confirm-RapMetaCoding {
    [CmdletBinding()]param([Parameter(Mandatory)][ValidatePattern('^LIB:L\d{6}$')][string]$LibraryId,[Parameter(Mandatory)][ValidatePattern('^PR\d{3}$')][string]$ProjectId,[Parameter(Mandatory)]$ConfirmedValues,[Parameter(Mandatory)]$Dependencies,[ValidateSet('Fixture')][string]$Mode='Fixture')
    Assert-RapMetaDependencies $Dependencies @('GetProjectPaper','GetExistingCoding','UpsertProjectCoding','AppendAudit');if($null -eq (& $Dependencies.GetProjectPaper $LibraryId $ProjectId)){throw 'PROJECT_PAPER_MEMBERSHIP_REQUIRED'}
    $confirmed=[ordered]@{};foreach($entry in @(Get-RapMetaEntries $ConfirmedValues)){if($script:RapMetaHumanOwnedFields -inotcontains $entry.Name){throw "RESEARCHER_CONFIRMATION_FIELD_NOT_ALLOWED: $($entry.Name)"};$confirmed[$entry.Name]=$entry.Value}
    $existing=& $Dependencies.GetExistingCoding $LibraryId $ProjectId;if($null -eq $existing){throw 'META_CODING_RECORD_REQUIRED'};$prior=Get-RapMetaPropertyValue $existing 'ResearcherConfirmed';foreach($entry in @(Get-RapMetaEntries $prior)){if(-not $confirmed.Contains($entry.Name)){$confirmed[$entry.Name]=$entry.Value}}
    $record=[pscustomobject]@{LibraryId=$LibraryId;ProjectId=$ProjectId;ScopeKey="$LibraryId|$ProjectId";SchemaVersion=(Get-RapMetaPropertyValue $existing 'SchemaVersion');AiAssisted=(Get-RapMetaPropertyValue $existing 'AiAssisted');ResearcherConfirmed=[pscustomobject]$confirmed;Ownership=(Get-RapMetaPropertyValue $existing 'Ownership');CommonReviewMutation=$false;ProductionWrite='DISABLED';UpdatedAt=[DateTimeOffset]::UtcNow.ToString('o')}
    $result=& $Dependencies.UpsertProjectCoding $record;& $Dependencies.AppendAudit ([pscustomobject]@{LibraryId=$LibraryId;ProjectId=$ProjectId;ScopeKey="$LibraryId|$ProjectId";Action='RESEARCHER_CONFIRMATION_FIXTURE';Status='COMPLETED';Timestamp=[DateTimeOffset]::UtcNow.ToString('o')})
    [pscustomobject]@{Status='CONFIRMED';Mode=$Mode;Record=$record;WriteResult=$result;ProductionWrite='DISABLED'}
}

Export-ModuleMember -Function New-RapMetaCodingRequest,Invoke-RapMetaCoding,Confirm-RapMetaCoding
