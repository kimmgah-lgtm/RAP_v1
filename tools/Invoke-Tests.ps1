#Requires -Version 7.0
<# .SYNOPSIS Runs repository acceptance tests. #>
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
& (Join-Path $repositoryRoot 'src/Local/ResearchAutomation.Local/tests/Bootstrap.Tests.ps1')
& (Join-Path $repositoryRoot 'src/Local/Reconciliation/tests/ReconciliationTests.ps1')
& (Join-Path $repositoryRoot 'src/Local/Reconciliation/tests/ReconciliationNegativeTests.ps1')
& (Join-Path $repositoryRoot 'src/Local/Reconciliation/tests/ReconciliationAdversarialTests.ps1')
& (Join-Path $repositoryRoot 'src/Local/Reconciliation/tests/ReconciliationTraceabilityTests.ps1')
& (Join-Path $repositoryRoot 'src/Local/ProductionReadiness/tests/ProductionReadinessTests.ps1')
& (Join-Path $repositoryRoot 'src/Local/ProductionReadiness/tests/ProductionReadinessAdversarialTests.ps1')
& (Join-Path $repositoryRoot 'src/Local/ProductionReadiness/tests/CredentialLeakageTests.ps1')
& (Join-Path $repositoryRoot 'src/Local/ProductionReadiness/tests/ReadCapabilityBoundaryTests.ps1')
& (Join-Path $repositoryRoot 'src/Local/ProductionReadiness/tests/ResearchWorkflowValidationTests.ps1')
& (Join-Path $repositoryRoot 'src/Local/ProductionReadiness/tests/ControlledWritePilotTests.ps1')
& (Join-Path $repositoryRoot 'src/Local/ProductionReadiness/tests/ControlledWritePilotAdversarialTests.ps1')
& (Join-Path $repositoryRoot 'src/Local/ProductionReadiness/tests/ControlledWriteRemediationTests.ps1')
& (Join-Path $repositoryRoot 'src/Local/ProductionReadiness/tests/ControlledWriteGateProbeTests.ps1')

