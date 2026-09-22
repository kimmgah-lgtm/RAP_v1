#Requires -Version 7.0
<# .SYNOPSIS Executes dependency-free acceptance tests for SPR-001. #>
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$powerShell = (Get-Process -Id $PID).Path
& $powerShell -NoProfile -File (Join-Path $root 'Install.ps1')
if ($LASTEXITCODE -ne 0) { throw "Installer acceptance test failed with exit code $LASTEXITCODE." }
& $powerShell -NoProfile -File (Join-Path $root 'Run-Agent.ps1') -SelfTest
if ($LASTEXITCODE -ne 0) { throw "Agent self-test acceptance test failed with exit code $LASTEXITCODE." }
$configuration = Get-Content -LiteralPath (Join-Path $root 'config/config.json') -Raw | ConvertFrom-Json
if ($configuration.version -ne '1.0.0-alpha.5') { throw 'Semantic version acceptance test failed.' }
if ($configuration.build -ne '20260922.001') { throw 'Build number acceptance test failed.' }
$expectedCapabilities = [ordered]@{
    CloudController = $true; LocalAgent = $true; SQLite = $true; Logger = $true; Queue = $true
    Zotero = $true; WriteLayer = $true; Drive = $true; Bootstrap = $true; Notion = $true; AIReview = $false
}
foreach ($entry in $expectedCapabilities.GetEnumerator()) {
    if ($configuration.capabilities.PSObject.Properties[$entry.Key].Value -ne $entry.Value) {
        throw "Capability acceptance test failed: $($entry.Key)."
    }
}
$connectorTestRoot=[IO.Path]::GetFullPath((Join-Path $root '../Connectors/Zotero/tests'))
& $powerShell -NoProfile -File (Join-Path $connectorTestRoot 'ConnectorTests.ps1')
if ($LASTEXITCODE -ne 0) { throw "Zotero connector tests failed with exit code $LASTEXITCODE." }
& $powerShell -NoProfile -File (Join-Path $connectorTestRoot 'SampleLibraryTests.ps1')
if ($LASTEXITCODE -ne 0) { throw "Zotero sample library tests failed with exit code $LASTEXITCODE." }
$writeTestRoot=[IO.Path]::GetFullPath((Join-Path $root '../Write/ResearchAutomation.Write/tests'))
foreach($testName in @('TransactionTests.ps1','RollbackTests.ps1','VerificationTests.ps1','AcceptanceTests.ps1')){
    & $powerShell -NoProfile -File (Join-Path $writeTestRoot $testName)
    if($LASTEXITCODE -ne 0){throw "Write Layer test failed: $testName ($LASTEXITCODE)"}
}
$driveTestRoot=[IO.Path]::GetFullPath((Join-Path $root '../Connectors/GoogleDrive/tests'))
foreach($testName in @('DriveConnectorTests.ps1','IntegrityTests.ps1','AcceptanceTests.ps1')){
    & $powerShell -NoProfile -File (Join-Path $driveTestRoot $testName)
    if($LASTEXITCODE -ne 0){throw "Google Drive test failed: $testName ($LASTEXITCODE)"}
}
$bootstrapTestRoot=[IO.Path]::GetFullPath((Join-Path $root '../Bootstrap/tests'))
foreach($testName in @('BootstrapTests.ps1','AcceptanceTests.ps1')){
    & $powerShell -NoProfile -File (Join-Path $bootstrapTestRoot $testName)
    if($LASTEXITCODE -ne 0){throw "Bootstrap Engine test failed: $testName ($LASTEXITCODE)"}
}
Write-Host 'RAP repository acceptance tests: PASS'
