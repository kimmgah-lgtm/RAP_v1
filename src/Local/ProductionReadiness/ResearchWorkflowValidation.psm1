Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

function Get-RapResearchTraceValue {
    param($Object,[string]$Name,$Default=$null)
    if($null-eq$Object){return $Default}
    $property=$Object.PSObject.Properties[$Name]
    if($null-eq$property){return $Default}
    $property.Value
}

function Get-RapResearchTraceHash {
    param([Parameter(Mandatory)]$Value)
    $json=$Value|ConvertTo-Json -Depth 40 -Compress
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($json))).ToLowerInvariant()
}

function Test-RapResearchObjectTrace {
    <#
    .SYNOPSIS Classifies a normalized Zotero -> Library_ID -> Drive -> Notion trace.
    .DESCRIPTION This is a pure, read-only decision function. Callers provide evidence
    already read through the existing connectors. The function cannot perform I/O or
    apply reconciliation and always returns ProductionWrite=DISABLED.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidatePattern('^LIB:L\d{6}$')][string]$LibraryId,
        [Parameter(Mandatory)][bool]$AccessAvailable,
        [Parameter(Mandatory)][AllowNull()]$ZoteroRecord,
        [Parameter(Mandatory)][AllowNull()]$DriveFile,
        [Parameter(Mandatory)][AllowNull()]$NotionReview,
        [AllowEmptyCollection()][object[]]$ProjectMappings=@(),
        [ValidateRange(0,1000)][int]$BibliographicCandidateCount=1,
        [ValidateRange(0,1000)][int]$PdfCandidateCount=1,
        [bool]$SchemaCompatible=$true,
        [bool]$LinkageComplete=$true,
        [bool]$PdfMetadataMatches=$true,
        [bool]$PdfHashMatches=$true
    )
    $reasons=[Collections.Generic.List[string]]::new()
    $status='MATCHED'
    if(!$AccessAvailable){$status='TEST_DEFERRED';$reasons.Add('EXTERNAL_ACCESS_UNAVAILABLE')}
    elseif(!$SchemaCompatible){$status='SCHEMA_MISMATCH';$reasons.Add('NOTION_REVIEW_SCHEMA_INCOMPATIBLE')}
    elseif($null-eq$ZoteroRecord-or$null-eq$DriveFile-or$null-eq$NotionReview){$status='MISSING';$reasons.Add('REQUIRED_RESEARCH_OBJECT_MISSING')}
    elseif($BibliographicCandidateCount-ne1-or$PdfCandidateCount-ne1){$status='AMBIGUOUS';$reasons.Add('IDENTITY_NOT_UNIQUE')}
    elseif(!$PdfMetadataMatches-or!$PdfHashMatches){$status='PDF_MISMATCH';$reasons.Add($(if(!$PdfMetadataMatches){'PDF_BIBLIOGRAPHIC_IDENTITY_MISMATCH'}else{'PDF_HASH_MISMATCH'}))}
    elseif(!$LinkageComplete){$status='BROKEN_LINK';$reasons.Add('STRUCTURED_LINKAGE_INCOMPLETE')}

    $projectIds=@($ProjectMappings|ForEach-Object{[string](Get-RapResearchTraceValue $_ 'ProjectId')}|Where-Object{$_}|Sort-Object -Unique)
    if($projectIds.Count-eq0){$reasons.Add('PROJECT_MAPPING_MISSING')}
    [pscustomobject]@{
        LibraryId=$LibraryId;Status=$status;Reasons=@($reasons);ZoteroItemKey=[string](Get-RapResearchTraceValue $ZoteroRecord 'ItemKey')
        DriveFileId=[string](Get-RapResearchTraceValue $DriveFile 'FileId');NotionPageId=[string](Get-RapResearchTraceValue $NotionReview 'PageId')
        ProjectIds=$projectIds;ProjectMappingComplete=$projectIds.Count-gt0;PdfMetadataMatches=$PdfMetadataMatches;PdfHashMatches=$PdfHashMatches
        ChangesApplied=$false;ApplyPermitted=$false;ProductionWrite='DISABLED'
    }
}

function New-RapReadOnlyReconciliationCase {
    <#
    .SYNOPSIS Creates an inspectable reconciliation case without an APPLY path.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$')][string]$CaseId,
        [Parameter(Mandatory)]$Trace,
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$RecommendedHumanActions
    )
    if($Trace.ProductionWrite-cne'DISABLED'-or$Trace.ChangesApplied-or$Trace.ApplyPermitted){throw 'UNSAFE_RESEARCH_TRACE'}
    $body=[ordered]@{
        CaseId=$CaseId;LibraryId=[string]$Trace.LibraryId;Status=[string]$Trace.Status;Reasons=@($Trace.Reasons)
        RecommendedHumanActions=@($RecommendedHumanActions);Action='PLAN';ApplyPermitted=$false;ChangesApplied=$false
        ProductionWrite='DISABLED'
    }
    $body.CaseHash=Get-RapResearchTraceHash $body
    [pscustomobject]$body
}

Export-ModuleMember -Function Test-RapResearchObjectTrace,New-RapReadOnlyReconciliationCase
