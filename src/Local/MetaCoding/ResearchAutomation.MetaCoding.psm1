Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'MetaCodingEngine.psm1') -Force -ErrorAction Stop
Import-Module (Join-Path $PSScriptRoot 'MetaCodingPersistence.psm1') -Force -ErrorAction Stop
Export-ModuleMember -Function New-RapMetaCodingRequest,Invoke-RapMetaCoding,Confirm-RapMetaCoding,Initialize-RapMetaCodingStore,Register-RapMetaCodingProjectFixture,New-RapMetaCodingSqliteDependencies,Get-RapMetaCodingFixtureRecord
