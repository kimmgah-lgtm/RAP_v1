Set-StrictMode -Version Latest
$script:ProtectedOwnership=@('HUMAN_OWNED','ResearcherConfirmed')

function Get-RapIntegrityCanonicalJson { param($Value) $Value|ConvertTo-Json -Depth 60 -Compress }
function Get-RapIntegrityHash { param($Value) $json=Get-RapIntegrityCanonicalJson $Value;[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($json))).ToLowerInvariant() }
function Get-RapIntegrityProperty { param($Object,[string]$Name) if($null-eq$Object){return $null};$p=$Object.PSObject.Properties[$Name];if($p){$p.Value}else{$null} }

function Test-RapIntegritySnapshot {
    [CmdletBinding()]param([Parameter(Mandatory)][AllowNull()]$Snapshot)
    $errors=[Collections.Generic.List[string]]::new()
    if($null-eq$Snapshot-or$Snapshot-is[string]-or$Snapshot-is[ValueType]){return [pscustomobject]@{Valid=$false;Errors=@('NOT_AN_OBJECT')}}
    if([string](Get-RapIntegrityProperty $Snapshot 'LibraryId')-notmatch'^LIB:L\d{6}$'){$errors.Add('INVALID_LIBRARY_ID')}
    if([string](Get-RapIntegrityProperty $Snapshot 'ProjectId')-notmatch'^PR\d{3,6}$'){$errors.Add('INVALID_PROJECT_ID')}
    foreach($name in @('EvidenceComplete','IdentityAmbiguous')){if((Get-RapIntegrityProperty $Snapshot $name)-isnot[bool]){$errors.Add("INVALID_$($name.ToUpperInvariant())")}}
    $records=@(Get-RapIntegrityProperty $Snapshot 'Records')
    if($null-eq(Get-RapIntegrityProperty $Snapshot 'Records')){$errors.Add('MISSING_RECORDS')}
    $ids=@{};foreach($r in $records){
        $id=[string](Get-RapIntegrityProperty $r 'RecordId');$owner=[string](Get-RapIntegrityProperty $r 'Ownership')
        if($id-notmatch'^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$'){$errors.Add('INVALID_RECORD_ID')}
        elseif($ids.ContainsKey($id)){$errors.Add("DUPLICATE_RECORD_ID:$id")}else{$ids[$id]=$true}
        if(-not(@('AUTO_OWNED','HUMAN_OWNED','ResearcherConfirmed') -ccontains $owner)){$errors.Add("INVALID_OWNERSHIP:$id")}
        if($null-eq(Get-RapIntegrityProperty $r 'Evidence')){$errors.Add("MISSING_EVIDENCE:$id")}
    }
    [pscustomobject]@{Valid=$errors.Count-eq0;Errors=@($errors)}
}

function Compare-RapIntegritySnapshot {
    [CmdletBinding()]param([Parameter(Mandatory)]$Expected,[Parameter(Mandatory)]$Actual)
    $ev=Test-RapIntegritySnapshot $Expected;$av=Test-RapIntegritySnapshot $Actual
    if(!$ev.Valid){throw "INVALID_EXPECTED_SNAPSHOT:$($ev.Errors-join',')"};if(!$av.Valid){throw "INVALID_ACTUAL_SNAPSHOT:$($av.Errors-join',')"}
    if($Expected.LibraryId-ne$Actual.LibraryId-or$Expected.ProjectId-ne$Actual.ProjectId){throw 'SCOPE_ISOLATION_VIOLATION'}
    $actualById=@{};foreach($r in @($Actual.Records)){$actualById[[string]$r.RecordId]=$r}
    $diffs=[Collections.Generic.List[object]]::new()
    foreach($e in @($Expected.Records)){
        $a=$actualById[[string]$e.RecordId]
        if($null-eq$a){$diffs.Add([pscustomobject]@{RecordId=$e.RecordId;Kind='MISSING';Ownership=$e.Ownership;Expected=$e.Value;Actual=$null;Evidence=$e.Evidence});continue}
        if([string]$e.Ownership-ne[string]$a.Ownership){$diffs.Add([pscustomobject]@{RecordId=$e.RecordId;Kind='OWNERSHIP_CONFLICT';Ownership=$e.Ownership;Expected=$e.Ownership;Actual=$a.Ownership;Evidence=$a.Evidence});continue}
        if((Get-RapIntegrityHash $e.Value)-ne(Get-RapIntegrityHash $a.Value)){$diffs.Add([pscustomobject]@{RecordId=$e.RecordId;Kind='VALUE_MISMATCH';Ownership=$e.Ownership;Expected=$e.Value;Actual=$a.Value;Evidence=$a.Evidence})}
    }
    $expectedIds=@($Expected.Records|ForEach-Object{[string]$_.RecordId})
    foreach($a in @($Actual.Records)){if([string]$a.RecordId-notin$expectedIds){$diffs.Add([pscustomobject]@{RecordId=$a.RecordId;Kind='UNEXPECTED';Ownership=$a.Ownership;Expected=$null;Actual=$a.Value;Evidence=$a.Evidence})}}
    [pscustomobject]@{LibraryId=$Actual.LibraryId;ProjectId=$Actual.ProjectId;ExpectedHash=Get-RapIntegrityHash $Expected;ActualHash=Get-RapIntegrityHash $Actual;Differences=@($diffs);DifferenceCount=$diffs.Count;EvidenceComplete=($Expected.EvidenceComplete-and$Actual.EvidenceComplete);IdentityAmbiguous=($Expected.IdentityAmbiguous-or$Actual.IdentityAmbiguous)}
}

function New-RapReconciliationDecision {
    [CmdletBinding()]param([Parameter(Mandatory)]$DifferenceSet)
    $reasons=[Collections.Generic.List[string]]::new();$auto=$true
    if($DifferenceSet.IdentityAmbiguous){$auto=$false;$reasons.Add('AMBIGUOUS_IDENTITY')}
    if(!$DifferenceSet.EvidenceComplete){$auto=$false;$reasons.Add('MISSING_OR_UNKNOWN_EVIDENCE')}
    foreach($d in @($DifferenceSet.Differences)){
        if($d.Ownership-in$script:ProtectedOwnership){$auto=$false;$reasons.Add("PROTECTED_OWNERSHIP:$($d.RecordId)")}
        if($d.Kind-in@('UNEXPECTED','OWNERSHIP_CONFLICT')){$auto=$false;$reasons.Add("DESTRUCTIVE_OR_AMBIGUOUS:$($d.RecordId)")}
        if($null-eq$d.Evidence){$auto=$false;$reasons.Add("MISSING_EVIDENCE:$($d.RecordId)")}
    }
    $state=if($DifferenceSet.DifferenceCount-eq0){'NO_ACTION'}elseif($auto){'AUTO_SAFE'}else{'HUMAN_REVIEW_REQUIRED'}
    [pscustomobject]@{LibraryId=$DifferenceSet.LibraryId;ProjectId=$DifferenceSet.ProjectId;Decision=$state;Reasons=@($reasons|Select-Object -Unique);DifferenceHash=Get-RapIntegrityHash $DifferenceSet;ProductionWrite='DISABLED'}
}

function New-RapRecoveryPlan {
    [CmdletBinding()]param([Parameter(Mandatory)]$DifferenceSet,[Parameter(Mandatory)]$Decision,[Parameter(Mandatory)][string]$OperationId)
    if($OperationId-notmatch'^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$'){throw 'INVALID_OPERATION_ID'}
    $actions=@();if($Decision.Decision-eq'AUTO_SAFE'){$actions=@($DifferenceSet.Differences|ForEach-Object{[pscustomobject]@{Action='UPSERT_LOCAL_DERIVED';RecordId=$_.RecordId;Ownership=$_.Ownership;Value=$_.Expected;Evidence=$_.Evidence}})}
    $body=[pscustomobject]@{OperationId=$OperationId;LibraryId=$DifferenceSet.LibraryId;ProjectId=$DifferenceSet.ProjectId;ExpectedSnapshotHash=$DifferenceSet.ExpectedHash;ActualSnapshotHash=$DifferenceSet.ActualHash;Decision=$Decision.Decision;Actions=$actions;DestructiveActionCount=0;ProductionWrite='DISABLED'}
    $body|Add-Member PlanHash (Get-RapIntegrityHash $body);$body
}

function Test-RapRecoveryReadBack {
    [CmdletBinding()]param([Parameter(Mandatory)]$Expected,[Parameter(Mandatory)]$Actual)
    $diff=Compare-RapIntegritySnapshot $Expected $Actual
    [pscustomobject]@{Valid=$diff.DifferenceCount-eq0;DifferenceCount=$diff.DifferenceCount;LibraryIdPreserved=$Expected.LibraryId-eq$Actual.LibraryId;ProjectIdPreserved=$Expected.ProjectId-eq$Actual.ProjectId;ExpectedHash=$diff.ExpectedHash;ActualHash=$diff.ActualHash}
}

function Invoke-RapRecoveryPlan {
    [CmdletBinding()]param([Parameter(Mandatory)]$Plan,[Parameter(Mandatory)]$Expected,[Parameter(Mandatory)]$Dependencies,[ValidateSet('DryRun','Fixture')][string]$Mode='DryRun')
    if($Plan.ProductionWrite-ne'DISABLED'-or$Plan.DestructiveActionCount-ne0){throw 'UNSAFE_RECOVERY_PLAN'}
    if($Plan.LibraryId-ne$Expected.LibraryId-or$Plan.ProjectId-ne$Expected.ProjectId){throw 'PLAN_SCOPE_MISMATCH'}
    if((Get-RapIntegrityHash $Expected)-ne$Plan.ExpectedSnapshotHash){throw 'PLAN_EXPECTED_HASH_MISMATCH'}
    $existing=&$Dependencies.GetOperation $Plan.OperationId
    if($existing){if($existing.PlanHash-ne$Plan.PlanHash){throw 'OPERATION_REPLAY_CONFLICT'};return [pscustomobject]@{Status='ALREADY_COMPLETED';OperationId=$Plan.OperationId;ChangesApplied=$false;Verification=$existing.Verification;ProductionWrite='DISABLED'}}
    $current=&$Dependencies.ReadSnapshot $Plan.LibraryId $Plan.ProjectId
    if($null-eq$current){throw 'CURRENT_SNAPSHOT_REQUIRED'}
    if((Get-RapIntegrityHash $current)-ne$Plan.ActualSnapshotHash){throw 'STALE_RECOVERY_PLAN'}
    if($Plan.Decision-ne'AUTO_SAFE' -and $Plan.Actions.Count-gt0){throw 'NON_AUTO_SAFE_PLAN_HAS_ACTIONS'}
    if($Mode-eq'DryRun'){return [pscustomobject]@{Status='DRY_RUN';OperationId=$Plan.OperationId;ChangesApplied=$false;ActionCount=$Plan.Actions.Count;ProductionWrite='DISABLED'}}
    if($Plan.Decision-ne'AUTO_SAFE'){return [pscustomobject]@{Status='BLOCKED';OperationId=$Plan.OperationId;ChangesApplied=$false;ActionCount=0;ProductionWrite='DISABLED'}}
    foreach($a in @($Plan.Actions)){if($a.Action-ne'UPSERT_LOCAL_DERIVED'-or$a.Ownership-ne'AUTO_OWNED'){throw 'PROHIBITED_RECOVERY_ACTION'}}
    $candidate=$current|ConvertTo-Json -Depth 60|ConvertFrom-Json -Depth 60
    foreach($a in @($Plan.Actions)){$r=@($candidate.Records|Where-Object RecordId -eq $a.RecordId|Select-Object -First 1);if($r){$r[0].Value=$a.Value}else{$candidate.Records+= [pscustomobject]@{RecordId=$a.RecordId;Value=$a.Value;Ownership='AUTO_OWNED';Evidence=$a.Evidence}}}
    $verification=Test-RapRecoveryReadBack $Expected $candidate;if(!$verification.Valid){throw 'READ_BACK_VERIFICATION_FAILED'}
    $audit=[pscustomobject]@{OperationId=$Plan.OperationId;LibraryId=$Plan.LibraryId;ProjectId=$Plan.ProjectId;PlanHash=$Plan.PlanHash;BeforeHash=$Plan.ActualSnapshotHash;AfterHash=$verification.ActualHash;ActionCount=$Plan.Actions.Count;ProtectedWriteCount=0;DestructiveActionCount=0;ProductionWrite='DISABLED';Timestamp=[DateTimeOffset]::UtcNow.ToString('o')}
    &$Dependencies.CommitRecovery $candidate ([pscustomobject]@{OperationId=$Plan.OperationId;PlanHash=$Plan.PlanHash;State='COMPLETED';Verification=$verification}) $audit
    $readBack=&$Dependencies.ReadSnapshot $Plan.LibraryId $Plan.ProjectId;$final=Test-RapRecoveryReadBack $Expected $readBack
    if(!$final.Valid){throw 'PERSISTED_READ_BACK_VERIFICATION_FAILED'}
    [pscustomobject]@{Status='RECOVERED';OperationId=$Plan.OperationId;ChangesApplied=$true;ActionCount=$Plan.Actions.Count;Verification=$final;Audit=$audit;ProductionWrite='DISABLED'}
}

Export-ModuleMember -Function Test-RapIntegritySnapshot,Compare-RapIntegritySnapshot,New-RapReconciliationDecision,New-RapRecoveryPlan,Test-RapRecoveryReadBack,Invoke-RapRecoveryPlan
