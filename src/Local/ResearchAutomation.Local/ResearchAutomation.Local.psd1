@{
    RootModule        = 'ResearchAutomation.Local.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'f8305df2-c931-4761-a30a-0ef625dd482a'
    Author            = 'Research Automation Platform contributors'
    CompanyName       = 'Research Automation Platform'
    Copyright         = '(c) 2026 Research Automation Platform contributors. MIT License.'
    Description       = 'Local bootstrap runtime for the Research Automation Platform.'
    PowerShellVersion = '7.0'
    FunctionsToExport = @(
        'Get-RapConfiguration', 'Initialize-RapConfiguration',
        'Initialize-RapLogger', 'Write-RapLog',
        'Initialize-RapQueue', 'Test-RapQueue', 'Invoke-RapQueueScalar',
        'Invoke-RapSelfTest', 'Show-RapHealthDashboard',
        'Get-RapZoteroItems', 'Get-RapZoteroCollections',
        'Get-RapZoteroLibraryStatistics', 'Test-RapZoteroConnection'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{ PSData = @{ Prerelease = 'alpha.5'; Tags = @('RAP', 'Local', 'SQLite', 'Zotero', 'Transactions', 'GoogleDrive', 'Bootstrap'); LicenseUri = 'https://opensource.org/license/mit' } }
}
