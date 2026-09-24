Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'ResearchAutomation.Output.psd1') -Force
. (Join-Path $PSScriptRoot 'TestHarness.ps1')
$script:N = 0
function A($condition, $message) { $script:N++; if (-not $condition) { throw $message } }
function T($action, $pattern) { $script:N++; $message = $null; try { & $action } catch { $message = $_.Exception.Message }; if ($message -notmatch $pattern) { throw "Expected $pattern; actual=$message" } }

$records = New-RapOutputFixture
$spec = New-RapOutputSpecification -OutputSpecId OUT-ADV -ProjectId PR001 -OutputType EFFECT_SIZE_TABLE -OutputName x -SourceScope CONFIRMED -IncludedFields x -FormattingProfile x
$wrongProject = $records[3].PSObject.Copy(); $wrongProject.ProjectId = 'PR002'
T { New-RapOutputDataset $spec @($wrongProject) } 'PROJECT_SCOPE'
$brokenLineage = $records[3].PSObject.Copy(); $brokenLineage.Lineage = $null
T { New-RapOutputDataset $spec @($brokenLineage) } 'LINEAGE_REQUIRED'
$dataset = New-RapOutputDataset $spec $records
$artifact = New-RapResearchArtifact $spec $dataset
$changed = New-RapOutputFixture; $changed[3].Data.Effect = .7
$changedDataset = New-RapOutputDataset $spec $changed
A ((Test-RapOutputStale $artifact $changedDataset.SourceDatasetHash $spec.ConfigHash PR001) -eq 'STALE') 'stale artifact not detected'
$withoutScreening = @($records | Where-Object { $_.RecordType -ne 'SCREENING' })
A ((New-RapFixtureArtifact SCREENING_FLOW_DATA $withoutScreening OUT-ADVFLOW).Artifact.Status -eq 'MISSING_REQUIRED_DATA') 'missing flow fabricated'
$statement = New-RapFactualResultStatement $records[5]
A ($null -eq $statement.Interpretation) 'interpretation generated'
$manifest = New-RapReproducibilityManifest $spec $dataset @($artifact)
T { New-RapExportPackage $spec $dataset @($artifact) $manifest @([pscustomobject]@{ Name = 'API_KEY.txt' }) } 'PRIVATE'
$sameWrongProject = $records[3].PSObject.Copy(); $sameWrongProject.ProjectId = 'PR002'
T { New-RapOutputDataset $spec @($sameWrongProject) } 'PROJECT_SCOPE'
$ai = $records[2].PSObject.Copy(); $ai.VerificationState = 'AI_ASSISTED'
T { New-RapOutputDataset $spec @($ai) } 'NOT_VERIFIED'
$package = New-RapExportPackage $spec $dataset @($artifact) $manifest
$tampered = $artifact.PSObject.Copy(); $tampered.ContentHash = 'tampered'
A ((Test-RapOutputPackage $package @($tampered) $manifest).Status -eq 'FAILED') 'partial package finalized'
A (-not (Test-RapOutputPackage $package @($tampered) $manifest).Valid) 'tamper accepted'

if ($script:N -ne 10) { throw "Expected 10 assertions, got $script:N" }
Write-Host "SPR-010 adversarial tests: 10/10 PASS; assertions: $script:N"
