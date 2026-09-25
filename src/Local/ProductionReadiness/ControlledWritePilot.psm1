Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:ControlledWriteCapabilities = @{}
$script:ControlledWriteApprovalRequests = @{}
$script:ControlledWriteApprovals = @{}
$script:ControlledWriteAllowedFields = @('RAP_Metadata', 'RAP_Status', 'RAP_TestField')
$script:ControlledWriteProtectedOwnership = @('HUMAN_OWNED', 'ResearcherConfirmed')

function Copy-RapControlledWriteValue {
    param([AllowNull()]$Value)
    if ($null -eq $Value) { return $null }
    $Value | ConvertTo-Json -Depth 60 | ConvertFrom-Json -Depth 60
}

function Get-RapControlledWriteHash {
    param([AllowNull()]$Value)
    $json = $Value | ConvertTo-Json -Depth 60 -Compress
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($json))).ToLowerInvariant()
}

function Get-RapControlledWritePlanBody {
    param([Parameter(Mandatory)]$Plan)
    [ordered]@{
        OperationId = [string]$Plan.OperationId
        LibraryId = [string]$Plan.LibraryId
        ProjectId = [string]$Plan.ProjectId
        TargetSystem = [string]$Plan.TargetSystem
        TargetObject = [string]$Plan.TargetObject
        TargetObjectType = [string]$Plan.TargetObjectType
        TargetField = [string]$Plan.TargetField
        Action = [string]$Plan.Action
        BatchCount = [int]$Plan.BatchCount
        BeforeValue = $Plan.BeforeValue
        BeforeHash = [string]$Plan.BeforeHash
        ProposedValue = $Plan.ProposedValue
        PayloadHash = [string]$Plan.PayloadHash
        Reason = [string]$Plan.Reason
        Ownership = [string]$Plan.Ownership
        ExpectedVersion = [string]$Plan.ExpectedVersion
        ApprovalState = [string]$Plan.ApprovalState
        VerificationMethod = [string]$Plan.VerificationMethod
        RollbackInfo = [string]$Plan.RollbackInfo
        IdentityStatus = [string]$Plan.IdentityStatus
        CanonicalLibraryIdPresent = [bool]$Plan.CanonicalLibraryIdPresent
        IdentityAmbiguous = [bool]$Plan.IdentityAmbiguous
        PdfIdentityVerified = [bool]$Plan.PdfIdentityVerified
        OwnershipConflict = [bool]$Plan.OwnershipConflict
        StaleState = [bool]$Plan.StaleState
        CreatedAt = [string]$Plan.CreatedAt
        ExpiresAt = [string]$Plan.ExpiresAt
        ProductionWrite = [string]$Plan.ProductionWrite
    }
}

function Assert-RapControlledWritePlanIntegrity {
    param([Parameter(Mandatory)]$Plan)
    $actual = Get-RapControlledWriteHash (Get-RapControlledWritePlanBody $Plan)
    if ($actual -cne [string]$Plan.PlanHash) { throw 'CONTROLLED_WRITE_PLAN_TAMPERED' }
    if ($Plan.ProductionWrite -cne 'DISABLED') { throw 'GLOBAL_PRODUCTION_WRITE_MUST_REMAIN_DISABLED' }
    if ($Plan.ApprovalState -cne 'PLANNED') { throw 'CONTROLLED_WRITE_PLAN_STATE_INVALID' }
    if ($Plan.Action -cne 'UPDATE') { throw 'CONTROLLED_WRITE_ACTION_BLOCKED' }
    if ([int]$Plan.BatchCount -ne 1) { throw 'BATCH_WRITE_BLOCKED' }
    if ([string]$Plan.TargetObjectType -ceq 'PDF') { throw 'PDF_MUTATION_BLOCKED' }
    if ([string]$Plan.TargetField -cnotin $script:ControlledWriteAllowedFields) { throw 'CONTROLLED_WRITE_FIELD_NOT_ALLOWLISTED' }
    if ([string]$Plan.Ownership -cin $script:ControlledWriteProtectedOwnership) { throw 'PROTECTED_OWNERSHIP_BLOCKED' }
    if ([string]$Plan.Ownership -cne 'RAP_OWNED') { throw 'CONTROLLED_WRITE_OWNERSHIP_NOT_ALLOWED' }
    if ([string]$Plan.IdentityStatus -cne 'MATCHED' -or -not [bool]$Plan.CanonicalLibraryIdPresent -or [bool]$Plan.IdentityAmbiguous) { throw 'CONTROLLED_WRITE_IDENTITY_INELIGIBLE' }
    if (-not [bool]$Plan.PdfIdentityVerified) { throw 'PDF_IDENTITY_NOT_VERIFIED' }
    if ([bool]$Plan.OwnershipConflict) { throw 'CONTROLLED_WRITE_OWNERSHIP_CONFLICT' }
    if ([bool]$Plan.StaleState -or [DateTimeOffset]::UtcNow -gt [DateTimeOffset]::Parse([string]$Plan.ExpiresAt)) { throw 'STALE_CONTROLLED_WRITE_PLAN' }
    $true
}

function New-RapControlledWritePlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$')][string]$OperationId,
        [Parameter(Mandatory)][ValidatePattern('^LIB:L\d{6}$')][string]$LibraryId,
        [ValidatePattern('^$|^PR\d{3,6}$')][string]$ProjectId = '',
        [Parameter(Mandatory)][ValidateSet('Zotero', 'GoogleDrive', 'Notion')][string]$TargetSystem,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$TargetObject,
        [ValidateSet('MetadataRecord', 'PDF')][string]$TargetObjectType = 'MetadataRecord',
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$TargetField,
        [ValidateSet('UPDATE', 'DELETE', 'MERGE', 'MOVE')][string]$Action = 'UPDATE',
        [ValidateRange(1, 1000)][int]$BatchCount = 1,
        [Parameter(Mandatory)][AllowNull()]$BeforeValue,
        [Parameter(Mandatory)][ValidateNotNull()]$ProposedValue,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Reason,
        [Parameter(Mandatory)][ValidateSet('RAP_OWNED', 'HUMAN_OWNED', 'ResearcherConfirmed')][string]$Ownership,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ExpectedVersion,
        [ValidateSet('MATCHED', 'AMBIGUOUS', 'MISSING')][string]$IdentityStatus = 'MATCHED',
        [bool]$CanonicalLibraryIdPresent = $true,
        [bool]$IdentityAmbiguous = $false,
        [bool]$PdfIdentityVerified = $true,
        [bool]$OwnershipConflict = $false,
        [bool]$StaleState = $false,
        [string]$VerificationMethod = 'READ_BACK_VALUE_HASH_AND_VERSION',
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$RollbackInfo,
        [DateTimeOffset]$ExpiresAt = ([DateTimeOffset]::UtcNow.AddMinutes(15))
    )
    if ($Action -cne 'UPDATE') { throw "CONTROLLED_WRITE_ACTION_BLOCKED:$Action" }
    if ($BatchCount -ne 1) { throw 'BATCH_WRITE_BLOCKED' }
    if ($TargetObjectType -ceq 'PDF') { throw 'PDF_MUTATION_BLOCKED' }
    if ($TargetField -cnotin $script:ControlledWriteAllowedFields) { throw "CONTROLLED_WRITE_FIELD_NOT_ALLOWLISTED:$TargetField" }
    if ($Ownership -cin $script:ControlledWriteProtectedOwnership) { throw "PROTECTED_OWNERSHIP_BLOCKED:$Ownership" }
    if ($Ownership -cne 'RAP_OWNED') { throw 'CONTROLLED_WRITE_OWNERSHIP_NOT_ALLOWED' }
    if ($IdentityStatus -cne 'MATCHED' -or -not $CanonicalLibraryIdPresent -or $IdentityAmbiguous) { throw 'CONTROLLED_WRITE_IDENTITY_INELIGIBLE' }
    if (-not $PdfIdentityVerified) { throw 'PDF_IDENTITY_NOT_VERIFIED' }
    if ($OwnershipConflict) { throw 'CONTROLLED_WRITE_OWNERSHIP_CONFLICT' }
    if ($StaleState -or $ExpiresAt -le [DateTimeOffset]::UtcNow) { throw 'STALE_CONTROLLED_WRITE_PLAN' }

    $created = [DateTimeOffset]::UtcNow.ToString('o')
    $beforeCopy = Copy-RapControlledWriteValue $BeforeValue
    $proposedCopy = Copy-RapControlledWriteValue $ProposedValue
    $plan = [pscustomobject][ordered]@{
        PSTypeName = 'Rap.ControlledWritePlan'
        OperationId = $OperationId
        LibraryId = $LibraryId
        ProjectId = $ProjectId
        TargetSystem = $TargetSystem
        TargetObject = $TargetObject
        TargetObjectType = $TargetObjectType
        TargetField = $TargetField
        Action = $Action
        BatchCount = $BatchCount
        BeforeValue = $beforeCopy
        BeforeHash = Get-RapControlledWriteHash $beforeCopy
        ProposedValue = $proposedCopy
        PayloadHash = Get-RapControlledWriteHash $proposedCopy
        Reason = $Reason
        Ownership = $Ownership
        ExpectedVersion = $ExpectedVersion
        ApprovalState = 'PLANNED'
        VerificationMethod = $VerificationMethod
        RollbackInfo = $RollbackInfo
        IdentityStatus = $IdentityStatus
        CanonicalLibraryIdPresent = $CanonicalLibraryIdPresent
        IdentityAmbiguous = $IdentityAmbiguous
        PdfIdentityVerified = $PdfIdentityVerified
        OwnershipConflict = $OwnershipConflict
        StaleState = $StaleState
        CreatedAt = $created
        ExpiresAt = $ExpiresAt.ToString('o')
        ProductionWrite = 'DISABLED'
        PlanHash = ''
    }
    $plan.PlanHash = Get-RapControlledWriteHash (Get-RapControlledWritePlanBody $plan)
    $plan
}

function New-RapControlledWriteApprovalRequest {
    [CmdletBinding()]param([Parameter(Mandatory)]$Plan)
    [void](Assert-RapControlledWritePlanIntegrity $Plan)
    $requestId = [guid]::NewGuid().ToString()
    $record = [pscustomobject][ordered]@{
        RequestId = $requestId
        OperationId = $Plan.OperationId
        PlanHash = $Plan.PlanHash
        PayloadHash = $Plan.PayloadHash
        State = 'AWAITING_APPROVAL'
        RequestedAt = [DateTimeOffset]::UtcNow.ToString('o')
        ProductionWrite = 'DISABLED'
    }
    $script:ControlledWriteApprovalRequests[$requestId] = $record
    [pscustomobject][ordered]@{
        PSTypeName = 'Rap.ControlledWriteApprovalRequest'
        RequestId = $requestId
        OperationId = $Plan.OperationId
        PlanHash = $Plan.PlanHash
        PayloadHash = $Plan.PayloadHash
        State = 'AWAITING_APPROVAL'
        RequestedAt = [DateTimeOffset]::UtcNow.ToString('o')
        ProductionWrite = 'DISABLED'
    }
}

function Resolve-RapControlledWriteApprovalRequest {
    param([Parameter(Mandatory)]$ApprovalRequest)
    if ($ApprovalRequest.PSObject.TypeNames -cnotcontains 'Rap.ControlledWriteApprovalRequest') { throw 'UNTRUSTED_APPROVAL_REQUEST' }
    $id = [string]$ApprovalRequest.RequestId
    if ($id -notmatch '^[0-9a-f-]{36}$' -or -not $script:ControlledWriteApprovalRequests.ContainsKey($id)) { throw 'UNTRUSTED_APPROVAL_REQUEST' }
    $script:ControlledWriteApprovalRequests[$id]
}

function Approve-RapControlledWritePlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Plan,
        [Parameter(Mandatory)]$ApprovalRequest,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ApprovedBy,
        [Parameter(Mandatory)][ValidateSet('HUMAN', 'AI', 'AUTOMATION')][string]$ApproverType,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ApprovalProvenance
    )
    [void](Assert-RapControlledWritePlanIntegrity $Plan)
    if ($ApproverType -cne 'HUMAN') { throw 'SELF_APPROVAL_BLOCKED' }
    if ($ApprovedBy -match '(?i)\b(ai|automation|agent|bot)\b') { throw 'SELF_APPROVAL_BLOCKED' }
    $request = Resolve-RapControlledWriteApprovalRequest $ApprovalRequest
    if ($request.State -cne 'AWAITING_APPROVAL' -or $request.OperationId -cne $Plan.OperationId -or $request.PlanHash -cne $Plan.PlanHash -or $request.PayloadHash -cne $Plan.PayloadHash) { throw 'APPROVAL_BINDING_MISMATCH' }
    $approvalId = [guid]::NewGuid().ToString()
    $record = [pscustomobject][ordered]@{
        ApprovalId = $approvalId
        OperationId = $Plan.OperationId
        PlanHash = $Plan.PlanHash
        PayloadHash = $Plan.PayloadHash
        State = 'APPROVED'
        ApprovedBy = $ApprovedBy
        ApproverType = $ApproverType
        ApprovalProvenance = $ApprovalProvenance
        ApprovedAt = [DateTimeOffset]::UtcNow.ToString('o')
        ProductionWrite = 'DISABLED'
    }
    $script:ControlledWriteApprovals[$approvalId] = $record
    [pscustomobject][ordered]@{
        PSTypeName = 'Rap.ControlledWriteApproval'
        ApprovalId = $approvalId
        OperationId = $record.OperationId
        PlanHash = $record.PlanHash
        PayloadHash = $record.PayloadHash
        State = $record.State
        ApprovedBy = $record.ApprovedBy
        ApproverType = $record.ApproverType
        ApprovalProvenance = $record.ApprovalProvenance
        ApprovedAt = $record.ApprovedAt
        ProductionWrite = 'DISABLED'
    }
}

function Resolve-RapControlledWriteApproval {
    param([Parameter(Mandatory)]$Approval)
    if ($Approval.PSObject.TypeNames -cnotcontains 'Rap.ControlledWriteApproval') { throw 'UNTRUSTED_CONTROLLED_WRITE_APPROVAL' }
    $id = [string]$Approval.ApprovalId
    if ($id -notmatch '^[0-9a-f-]{36}$' -or -not $script:ControlledWriteApprovals.ContainsKey($id)) { throw 'UNTRUSTED_CONTROLLED_WRITE_APPROVAL' }
    $script:ControlledWriteApprovals[$id]
}

function New-RapControlledWriteFixtureAdapter {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet('Zotero', 'GoogleDrive', 'Notion')][string]$TargetSystem,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$TargetObject,
        [Parameter(Mandatory)][hashtable]$InitialFields,
        [Parameter(Mandatory)][ValidateRange(0, 2147483647)][int]$Version,
        [switch]$ReadBackMismatch,
        [switch]$TimeoutAfterApply,
        [switch]$FailBeforeApply
    )
    $fields = @{}
    foreach ($key in $InitialFields.Keys) { $fields[[string]$key] = Copy-RapControlledWriteValue $InitialFields[$key] }
    $id = [Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(32)).ToLowerInvariant()
    $script:ControlledWriteCapabilities[$id] = [pscustomobject]@{
        Kind = 'FIXTURE_CONTROLLED_WRITE'
        TargetSystem = $TargetSystem
        TargetObject = $TargetObject
        Fields = $fields
        Version = $Version
        MutationCount = 0
        ReadBackMismatch = [bool]$ReadBackMismatch
        TimeoutAfterApply = [bool]$TimeoutAfterApply
        FailBeforeApply = [bool]$FailBeforeApply
        Operations = @{}
        Audits = [Collections.Generic.List[object]]::new()
        ProductionWrite = 'DISABLED'
    }
    [pscustomobject]@{
        PSTypeName = 'Rap.ControlledWriteCapabilityToken'
        CapabilityId = $id
        Mode = 'FIXTURE_ONLY'
        TargetSystem = $TargetSystem
        TargetObject = $TargetObject
        ProductionWrite = 'DISABLED'
    }
}

function Resolve-RapControlledWriteCapability {
    param([Parameter(Mandatory)]$Adapter)
    if ($Adapter.PSObject.TypeNames -cnotcontains 'Rap.ControlledWriteCapabilityToken') { throw 'UNTRUSTED_CONTROLLED_WRITE_ADAPTER' }
    $id = [string]$Adapter.CapabilityId
    if ($id -notmatch '^[a-f0-9]{64}$' -or -not $script:ControlledWriteCapabilities.ContainsKey($id)) { throw 'UNTRUSTED_CONTROLLED_WRITE_ADAPTER' }
    $capability = $script:ControlledWriteCapabilities[$id]
    if ($capability.Kind -cne 'FIXTURE_CONTROLLED_WRITE' -or $capability.ProductionWrite -cne 'DISABLED') { throw 'UNSAFE_CONTROLLED_WRITE_CAPABILITY' }
    $capability
}

function Get-RapControlledWriteFixtureState {
    [CmdletBinding()]param([Parameter(Mandatory)]$Adapter)
    $capability = Resolve-RapControlledWriteCapability $Adapter
    [pscustomobject]@{
        TargetSystem = $capability.TargetSystem
        TargetObject = $capability.TargetObject
        Fields = Copy-RapControlledWriteValue $capability.Fields
        Version = $capability.Version
        MutationCount = $capability.MutationCount
        AuditCount = $capability.Audits.Count
        ProductionWrite = 'DISABLED'
    }
}

function New-RapControlledWriteAudit {
    param($Plan, $Approval, [string]$Result, $BeforeValue, $AfterValue, [bool]$ChangesApplied, [bool]$ReadBackVerified)
    [pscustomobject][ordered]@{
        OperationId = $Plan.OperationId
        LibraryId = $Plan.LibraryId
        ProjectId = $Plan.ProjectId
        TargetSystem = $Plan.TargetSystem
        TargetObject = $Plan.TargetObject
        TargetField = $Plan.TargetField
        PlanHash = $Plan.PlanHash
        ApprovalId = $(if ($null -eq $Approval) { $null } else { $Approval.ApprovalId })
        ApprovalProvenance = $(if ($null -eq $Approval) { $null } else { $Approval.ApprovalProvenance })
        ApprovedBy = $(if ($null -eq $Approval) { $null } else { $Approval.ApprovedBy })
        BeforeValue = Copy-RapControlledWriteValue $BeforeValue
        AfterValue = Copy-RapControlledWriteValue $AfterValue
        BeforeHash = Get-RapControlledWriteHash $BeforeValue
        AfterHash = Get-RapControlledWriteHash $AfterValue
        Timestamp = [DateTimeOffset]::UtcNow.ToString('o')
        Result = $Result
        ChangesApplied = $ChangesApplied
        ReadBackVerified = $ReadBackVerified
        VerificationMethod = $Plan.VerificationMethod
        RollbackInfo = $Plan.RollbackInfo
        ProductionWrite = 'DISABLED'
    }
}

function Invoke-RapControlledWritePilot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Plan,
        [AllowNull()]$Approval,
        [Parameter(Mandatory)]$Adapter,
        [ValidateSet('LOCAL', 'TEST', 'PRODUCTION')][string]$Environment = 'TEST',
        [ValidateSet('LOCAL', 'TEST', 'PRODUCTION')][string]$ExpectedEnvironment = 'TEST'
    )
    if ($Environment -cne $ExpectedEnvironment) { throw 'CONTROLLED_WRITE_ENVIRONMENT_MISMATCH' }
    if ($Environment -ceq 'PRODUCTION') { throw 'PRODUCTION_WRITE_PILOT_TEST_DEFERRED' }
    [void](Assert-RapControlledWritePlanIntegrity $Plan)
    $capability = Resolve-RapControlledWriteCapability $Adapter
    if ($capability.TargetSystem -cne $Plan.TargetSystem -or $capability.TargetObject -cne $Plan.TargetObject) { throw 'CONTROLLED_WRITE_TARGET_MISMATCH' }

    if ($capability.Operations.ContainsKey($Plan.OperationId)) {
        $existing = $capability.Operations[$Plan.OperationId]
        if ($existing.PlanHash -cne $Plan.PlanHash) { throw 'OPERATION_REPLAY_CONFLICT' }
        if ($existing.Status -ceq 'VERIFIED') {
            return [pscustomobject]@{OperationId=$Plan.OperationId;Status='ALREADY_COMPLETED';ChangesApplied=$false;MutationCount=0;Verification='PASS';StateHistory=@('PLANNED','AWAITING_APPROVAL','APPROVED','APPLYING','APPLIED','VERIFIED','ALREADY_COMPLETED');Audit=$existing.Audit;ProductionWrite='DISABLED'}
        }
        throw "OPERATION_NOT_REPLAYABLE:$($existing.Status)"
    }

    if ($null -eq $Approval) { throw 'HUMAN_APPROVAL_REQUIRED' }
    $approvalRecord = Resolve-RapControlledWriteApproval $Approval
    if ($approvalRecord.State -cne 'APPROVED' -or $approvalRecord.ApproverType -cne 'HUMAN' -or $approvalRecord.OperationId -cne $Plan.OperationId -or $approvalRecord.PlanHash -cne $Plan.PlanHash -or $approvalRecord.PayloadHash -cne $Plan.PayloadHash) { throw 'APPROVAL_BINDING_MISMATCH' }

    $currentValue = if ($capability.Fields.ContainsKey($Plan.TargetField)) { Copy-RapControlledWriteValue $capability.Fields[$Plan.TargetField] } else { $null }
    if ((Get-RapControlledWriteHash $currentValue) -cne $Plan.BeforeHash -or [string]$capability.Version -cne $Plan.ExpectedVersion) { throw 'STALE_CONTROLLED_WRITE_PLAN' }
    if ($capability.FailBeforeApply) { throw 'CONTROLLED_WRITE_APPLY_FAILED' }

    $stateHistory = [Collections.Generic.List[string]]::new()
    foreach ($state in @('PLANNED','AWAITING_APPROVAL','APPROVED','APPLYING')) { $stateHistory.Add($state) }
    $capability.Fields[$Plan.TargetField] = Copy-RapControlledWriteValue $Plan.ProposedValue
    $capability.Version = [int]$capability.Version + 1
    $capability.MutationCount = [int]$capability.MutationCount + 1
    $stateHistory.Add('APPLIED')

    if ($capability.TimeoutAfterApply) {
        $audit = New-RapControlledWriteAudit $Plan $approvalRecord 'PARTIAL_FAILURE' $currentValue $Plan.ProposedValue $true $false
        $capability.Audits.Add($audit)
        $capability.Operations[$Plan.OperationId] = [pscustomobject]@{PlanHash=$Plan.PlanHash;Status='PARTIAL_FAILURE';Audit=$audit}
        return [pscustomobject]@{OperationId=$Plan.OperationId;Status='PARTIAL_FAILURE';ChangesApplied=$true;MutationCount=1;Verification='UNKNOWN';StateHistory=@($stateHistory);Audit=$audit;HumanReview=$true;ProductionWrite='DISABLED'}
    }

    $readBack = Copy-RapControlledWriteValue $capability.Fields[$Plan.TargetField]
    if ($capability.ReadBackMismatch) { $readBack = [pscustomobject]@{SimulatedMismatch=$true;ObservedHash=(Get-RapControlledWriteHash $readBack)} }
    $verified = (Get-RapControlledWriteHash $readBack) -ceq $Plan.PayloadHash
    if (-not $verified) {
        $stateHistory.Add('VERIFY_FAILED')
        $audit = New-RapControlledWriteAudit $Plan $approvalRecord 'VERIFY_FAILED' $currentValue $readBack $true $false
        $capability.Audits.Add($audit)
        $capability.Operations[$Plan.OperationId] = [pscustomobject]@{PlanHash=$Plan.PlanHash;Status='VERIFY_FAILED';Audit=$audit}
        return [pscustomobject]@{OperationId=$Plan.OperationId;Status='VERIFY_FAILED';ChangesApplied=$true;MutationCount=1;Verification='FAIL';StateHistory=@($stateHistory);Audit=$audit;HumanReview=$true;ProductionWrite='DISABLED'}
    }

    $stateHistory.Add('VERIFIED')
    $audit = New-RapControlledWriteAudit $Plan $approvalRecord 'VERIFIED' $currentValue $readBack $true $true
    $capability.Audits.Add($audit)
    $capability.Operations[$Plan.OperationId] = [pscustomobject]@{PlanHash=$Plan.PlanHash;Status='VERIFIED';Audit=$audit}
    [pscustomobject]@{OperationId=$Plan.OperationId;Status='VERIFIED';ChangesApplied=$true;MutationCount=1;Verification='PASS';StateHistory=@($stateHistory);Audit=$audit;ProductionWrite='DISABLED'}
}

Export-ModuleMember -Function New-RapControlledWritePlan,New-RapControlledWriteApprovalRequest,Approve-RapControlledWritePlan,New-RapControlledWriteFixtureAdapter,Get-RapControlledWriteFixtureState,Invoke-RapControlledWritePilot
