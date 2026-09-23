#Requires -Version 7.0
[CmdletBinding()]param(
    [Parameter(Mandatory)][ValidateSet('Prepare','Resume')][string]$Phase,
    [Parameter(Mandatory)][string]$DatabasePath
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'ResearchAutomation.MetaCoding.psd1') -Force
. (Join-Path $PSScriptRoot 'TestHarness.ps1')

Register-RapMetaCodingProjectFixture -DatabasePath $DatabasePath -ProjectId PR001 -LibraryId 'LIB:L000001' | Out-Null
$request=New-RapMetaCodingRequest -LibraryId 'LIB:L000001' -ProjectId PR001 -SourceEvidence ([pscustomobject]@{Fixture='independent-process'}) -OperationId 'META-INDEPENDENT-RECOVERY'

if($Phase -eq 'Prepare'){
    $output=New-RapMetaCodingFixtureOutput
    $dependencies=New-RapMetaCodingSqliteDependencies -DatabasePath $DatabasePath -ExtractAssistedCoding ({$output}.GetNewClosure())
    $dependencies.UpsertProjectCoding={param($record)throw 'SIMULATED_PROCESS_A_TERMINATION'}
    try{Invoke-RapMetaCoding -Request $request -Dependencies $dependencies -Mode Fixture|Out-Null;throw 'Process A did not stop at the fixture interruption.'}catch{if($_.Exception.Message -ne 'SIMULATED_PROCESS_A_TERMINATION'){throw}}
    Write-Output 'PROCESS_A_PATCH_PREPARED'
    exit 0
}

$dependencies=New-RapMetaCodingSqliteDependencies -DatabasePath $DatabasePath -ExtractAssistedCoding {throw 'PROCESS_B_MUST_NOT_REEXTRACT'}
$result=Invoke-RapMetaCoding -Request $request -Dependencies $dependencies -Mode Fixture
$record=Get-RapMetaCodingFixtureRecord -DatabasePath $DatabasePath -LibraryId 'LIB:L000001' -ProjectId PR001
if($result.Status -ne 'COMPLETED' -or @($record.AiAssisted.EffectSizes).Count -ne 2){throw 'Process B recovery validation failed.'}
Write-Output 'PROCESS_B_RECOVERED_WITHOUT_REEXTRACTION'
