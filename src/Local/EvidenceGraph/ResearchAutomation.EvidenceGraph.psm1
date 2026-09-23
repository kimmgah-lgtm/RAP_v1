Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'EvidenceGraphEngine.psm1') -Force -ErrorAction Stop
Import-Module (Join-Path $PSScriptRoot 'EvidenceGraphPersistence.psm1') -Force -ErrorAction Stop
Export-ModuleMember -Function New-RapEvidenceNodeId,New-RapEvidenceGraphNode,New-RapEvidenceGraphEdge,New-RapEvidenceGraphOperation,Invoke-RapEvidenceGraphMutation,Get-RapEvidenceByLibraryId,Get-RapProjectMetaCodingGraph,Get-RapEffectEvidenceGraph,Get-RapDerivedValueInputs,Get-RapEvidenceDependents,Get-RapProjectPaperGraph,Initialize-RapEvidenceGraphStore,New-RapEvidenceGraphSqliteDependencies,Get-RapEvidenceGraphFixtureSnapshot
