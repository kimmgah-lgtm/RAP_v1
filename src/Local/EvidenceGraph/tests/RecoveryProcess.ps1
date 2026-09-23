#Requires -Version 7.0
[CmdletBinding()]param([Parameter(Mandatory)][ValidateSet('Prepare','Resume')][string]$Phase,[Parameter(Mandatory)][string]$DatabasePath)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'ResearchAutomation.EvidenceGraph.psd1') -Force
. (Join-Path $PSScriptRoot 'TestHarness.ps1')
$fixture=New-RapEvidenceGraphFixture
$operation=New-RapEvidenceGraphOperation -Nodes $fixture.Nodes -Edges $fixture.Edges -OperationId GRAPH-INDEPENDENT-RECOVERY
$dependencies=New-RapEvidenceGraphSqliteDependencies -DatabasePath $DatabasePath
if($Phase -eq 'Prepare'){
    $dependencies.UpsertEdge={param($edge)throw 'SIMULATED_PROCESS_A_TERMINATION'}
    try{Invoke-RapEvidenceGraphMutation -Operation $operation -Dependencies $dependencies -Mode Fixture|Out-Null;throw 'Process A did not stop.'}catch{if($_.Exception.Message -ne 'SIMULATED_PROCESS_A_TERMINATION'){throw}}
    Write-Output 'GRAPH_PROCESS_A_PREPARED'
    exit 0
}
$result=Invoke-RapEvidenceGraphMutation -Operation $operation -Dependencies $dependencies -Mode Fixture
$snapshot=Get-RapEvidenceGraphFixtureSnapshot -DatabasePath $DatabasePath
if($result.Status -ne 'COMPLETED' -or @($snapshot.Nodes).Count -ne 25 -or @($snapshot.Edges).Count -ne 29){throw 'Graph Process B recovery validation failed.'}
Write-Output 'GRAPH_PROCESS_B_RECOVERED'
