#Requires -Version 7.0
[CmdletBinding()]
param([Parameter(Mandatory)][ValidateSet('Write','Read')][string]$Mode,[Parameter(Mandatory)][string]$DatabasePath)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'ResearchAutomation.Synthesis.psd1') -Force
if($Mode -eq 'Write'){
    . (Join-Path $PSScriptRoot 'TestHarness.ps1')
    $records=New-RapBasicSynthesisFixture
    $spec=New-RapAnalysisSpecification -AnalysisId AN-RECOVERY -ProjectId PR001 -Model RANDOM -Estimator DL
    $dataset=New-RapTestAnalysisDataset $spec $records
    $sqlite=New-RapSynthesisSqliteDependencies $DatabasePath
    $primary=Invoke-RapSynthesis $spec $dataset RECOVERY-PRIMARY $sqlite
    $sensitivity=Invoke-RapSensitivityAnalysis $spec $dataset $sqlite RECOVERY-SENSITIVITY
    [pscustomobject]@{PrimaryRunId=$primary.Run.RunId;ChildRunIds=@($sensitivity.Runs.RunId);ParentAnalysisId=$sensitivity.ParentAnalysisId}|ConvertTo-Json -Depth 10 -Compress
}else{
    $snapshot=Get-RapSynthesisFixtureSnapshot $DatabasePath
    [pscustomobject]@{Primary=@($snapshot.Runs|Where-Object {$null -eq $_.PSObject.Properties['RunType'] -or $_.RunType -ne 'SENSITIVITY'});Children=@($snapshot.Runs|Where-Object {$null -ne $_.PSObject.Properties['RunType'] -and $_.RunType -eq 'SENSITIVITY'})}|ConvertTo-Json -Depth 60 -Compress
}
