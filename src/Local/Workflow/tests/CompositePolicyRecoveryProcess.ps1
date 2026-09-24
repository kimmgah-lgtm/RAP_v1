#Requires -Version 7.0
[CmdletBinding()]param([Parameter(Mandatory)][ValidateSet('Write','Read')][string]$Phase,[Parameter(Mandatory)][string]$DatabasePath)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'ResearchAutomation.Workflow.psd1') -Force
. (Join-Path $PSScriptRoot 'TestHarness.ps1')

$stale=New-RapWorkflowFixture;$stale.VersionState.SourceVersion=2
$broken=Copy-RapWorkflowFixture $stale;$broken.LibraryLinkage.Valid=$false;$broken.LibraryLinkage.LinkedLibraryId='LIB:RECOVERY-AMBIGUOUS'
if($Phase-eq'Write'){
    $dependencies=New-RapWorkflowSqliteDependencies $DatabasePath
    $null=Invoke-RapWorkflowExceptionOperation $stale 'TURN-C-XPROC-A' $dependencies
    $null=Invoke-RapWorkflowExceptionOperation $broken 'TURN-C-XPROC-B' $dependencies
    Write-Host 'TURN-C recovery process A: PASS'
    exit 0
}

$snapshot=Get-RapWorkflowExceptionSnapshot $DatabasePath
$policy=Get-RapCompositeResolutionPolicy @(Find-RapWorkflowExceptions $broken) $broken
if($snapshot.AuditCount-ne2){throw 'RECOVERY_AUDIT_HISTORY_LOST'}
if($snapshot.LastAudit.PolicyVersion-ne'SPR-011-TURN-C-1'){throw 'RECOVERY_POLICY_VERSION_LOST'}
if($snapshot.LastAudit.PolicyDecision-ne'BLOCKED'){throw 'RECOVERY_POLICY_DECISION_CHANGED'}
if($snapshot.LastAudit.PolicyHash-ne$policy.PolicyHash){throw 'RECOVERY_POLICY_NONDETERMINISTIC'}
Write-Host 'TURN-C recovery process B: PASS'
