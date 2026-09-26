@{
    RootModule='ResearchAutomation.ResearchIntake.psm1'
    ModuleVersion='1.0.0'
    GUID='e8314a47-1ea7-4a23-8c68-43005248340b'
    Author='Research Automation Platform contributors'
    PowerShellVersion='7.0'
    FunctionsToExport=@('New-RapResearchIntakeStore','New-RapResearchQuestion','New-RapSearchRequest','Invoke-RapMockResearchSearch','Add-RapResearchInboxCandidates','Promote-RapResearchInboxCandidate','Resolve-RapCanonicalPaperIdentity','Get-RapPreZoteroDedupDecision','Invoke-RapResearchIntakeDecision','Get-RapResearchIntakeAudit')
    CmdletsToExport=@()
    VariablesToExport=@()
    AliasesToExport=@()
    PrivateData=@{PSData=@{Prerelease='alpha.1';Tags=@('RAP','ResearchIntake','LocalOnly','ZeroDuplicate')}}
}
