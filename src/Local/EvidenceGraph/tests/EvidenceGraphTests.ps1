#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'ResearchAutomation.EvidenceGraph.psd1') -Force
. (Join-Path $PSScriptRoot 'TestHarness.ps1')
$script:Assertions=0
function Assert-RapGraphTest {param([bool]$Condition,[string]$Message)$script:Assertions++;if(-not $Condition){throw $Message}}
function Assert-RapGraphThrows {param([scriptblock]$Action,[string]$Pattern,[string]$Message)$script:Assertions++;$caught=$null;try{& $Action}catch{$caught=$_.Exception.Message};if($null -eq $caught -or $caught -notmatch $Pattern){throw "$Message Actual=$caught"}}

$fixture=New-RapEvidenceGraphFixture;$h=New-RapEvidenceGraphTestHarness;$operation=New-RapEvidenceGraphOperation -Nodes $fixture.Nodes -Edges $fixture.Edges
$result=Invoke-RapEvidenceGraphMutation -Operation $operation -Dependencies $h.Dependencies -Mode Fixture

# TEST 01-05 identity and boundaries
$paper=$h.State.Nodes['PAPER:LIB:L000001']
Assert-RapGraphTest ($paper.LibraryId -eq 'LIB:L000001' -and $paper.NodeType -eq 'PAPER') 'TEST 01 paper identity failed.'
Assert-RapGraphTest ($h.State.Nodes.ContainsKey('PROJECT_PAPER:LIB:L000001|PR001') -and $h.State.Nodes.ContainsKey('PROJECT_PAPER:LIB:L000001|PR002')) 'TEST 02 multi-project participation failed.'
Assert-RapGraphTest ($h.State.Nodes['PROJECT_PAPER:LIB:L000001|PR001'].ScopeKey -ne $h.State.Nodes['PROJECT_PAPER:LIB:L000001|PR002'].ScopeKey) 'TEST 03 project contexts collapsed.'
Assert-RapGraphTest ($null -eq $paper.PSObject.Properties['OutcomeSelection'] -and @($h.State.Edges.Values|Where-Object {$_.SourceNodeId -eq $paper.NodeId -and $_.RelationType -eq 'HAS_META_CODING'}).Count -eq 0) 'TEST 04 project judgment became global.'
Assert-RapGraphTest ($h.State.Nodes['COMMON_REVIEW:LIB:L000001'].NodeType -eq 'COMMON_REVIEW' -and $h.State.Nodes['META_CODING:LIB:L000001|PR001'].NodeType -eq 'META_CODING') 'TEST 05 review/meta distinction failed.'

# TEST 06-13 relationships
Assert-RapGraphTest (@($h.State.Edges.Values|Where-Object {$_.SourceNodeId -eq $paper.NodeId -and $_.RelationType -eq 'HAS_EVIDENCE'}).Count -eq 4) 'TEST 06 paper-evidence links failed.'
Assert-RapGraphTest (@($h.State.Edges.Values|Where-Object {$_.SourceNodeId -eq 'PROJECT_PAPER:LIB:L000001|PR001' -and $_.RelationType -eq 'REFERENCES' -and $_.TargetNodeId -eq $paper.NodeId}).Count -eq 1) 'TEST 07 project-paper reference failed.'
Assert-RapGraphTest (@($h.State.Edges.Values|Where-Object {$_.SourceNodeId -eq 'PROJECT_PAPER:LIB:L000001|PR001' -and $_.RelationType -eq 'HAS_META_CODING' -and $_.TargetNodeId -eq 'META_CODING:LIB:L000001|PR001'}).Count -eq 1) 'TEST 08 meta context link failed.'
Assert-RapGraphTest (@($h.State.Edges.Values|Where-Object {$_.SourceNodeId -eq 'META_CODING:LIB:L000001|PR001' -and $_.RelationType -eq 'HAS_OUTCOME'}).Count -eq 2) 'TEST 09 multiple outcomes failed.'
Assert-RapGraphTest (@($h.State.Edges.Values|Where-Object {$_.SourceNodeId -eq 'META_CODING:LIB:L000001|PR001' -and $_.RelationType -eq 'HAS_EFFECT_SIZE'}).Count -eq 2) 'TEST 10 multiple effects failed.'
$effectTrace=Get-RapEffectEvidenceGraph 'EFFECT_SIZE:ES-1|PR001' $h.Dependencies
Assert-RapGraphTest (@($effectTrace.Evidence|Where-Object NodeId -eq $fixture.EvidenceA).Count -eq 1) 'TEST 11 effect evidence link failed.'
Assert-RapGraphTest (@($h.State.Edges.Values|Where-Object {$_.SourceNodeId -eq 'STATISTICAL_INPUT:N|PR001' -and $_.RelationType -eq 'SUPPORTED_BY'}).Count -eq 1) 'TEST 12 statistical evidence link failed.'
Assert-RapGraphTest (@(Get-RapDerivedValueInputs 'DERIVED_VALUE:HEDGES_G|PR001' $h.Dependencies).Count -eq 3) 'TEST 13 derived lineage failed.'

# TEST 14-19 traceability queries
Assert-RapGraphTest (@(Get-RapEvidenceByLibraryId 'LIB:L000001' $h.Dependencies).Count -eq 4) 'TEST 14 Library-to-evidence query failed.'
Assert-RapGraphTest (@(Get-RapProjectMetaCodingGraph 'LIB:L000001' PR001 $h.Dependencies).NodeId -contains 'META_CODING:LIB:L000001|PR001') 'TEST 15 project Meta Coding query failed.'
Assert-RapGraphTest (@($effectTrace.StatisticalInputs).Count -eq 3 -and @($effectTrace.Evidence).Count -ge 1) 'TEST 16 effect trace query failed.'
Assert-RapGraphTest (@(Get-RapDerivedValueInputs 'DERIVED_VALUE:HEDGES_G|PR001' $h.Dependencies|Select-Object -ExpandProperty NodeId) -contains 'STATISTICAL_INPUT:MEAN|PR001') 'TEST 17 derived source query failed.'
Assert-RapGraphTest (@(Get-RapEvidenceDependents $fixture.EvidenceA $h.Dependencies).Count -ge 5) 'TEST 18 reverse evidence query failed.'
Assert-RapGraphTest (@(Get-RapProjectPaperGraph PR001 $h.Dependencies).NodeId -contains 'PROJECT_PAPER:LIB:L000001|PR001') 'TEST 19 project relationship query failed.'

# TEST 20-24 provenance/status
$evA=$h.State.Nodes[$fixture.EvidenceA];$uncertain=$h.State.Nodes[$fixture.Uncertain];$missing=$h.State.Nodes[$fixture.Missing]
Assert-RapGraphTest ($evA.Attributes.SourceReference -eq 'fixture:table-a' -and $evA.Attributes.EvidenceLocation -eq 'p. 12' -and $evA.Attributes.PromptVersion -eq 'fixture-v1') 'TEST 20 provenance lost.'
Assert-RapGraphTest ($uncertain.Attributes.EvidenceStatus -eq 'UNCERTAIN') 'TEST 21 uncertainty promoted.'
Assert-RapGraphTest ($missing.Attributes.EvidenceStatus -eq 'NOT_REPORTED' -and $null -eq $missing.Attributes.Value) 'TEST 22 missing evidence fabricated.'
$conflicts=@(Get-RapEvidenceByLibraryId 'LIB:L000001' $h.Dependencies|Where-Object {$_.Attributes.EvidenceStatus -eq 'CONFLICTING_EVIDENCE'})
Assert-RapGraphTest ($conflicts.Count -eq 2 -and @($conflicts.Attributes.Value|Sort-Object -Unique).Count -eq 2) 'TEST 23 conflict sources collapsed.'
Assert-RapGraphTest ($h.State.Nodes['AI_EXTRACTION:AE-1'].Attributes.OriginState -eq 'AI_ASSISTED' -and @($h.State.Edges.Values|Where-Object RelationType -eq 'CONFIRMS').Count -eq 1) 'TEST 24 AI origin lost after confirmation.'

# TEST 25-28 ownership/firewalls
Assert-RapGraphThrows {New-RapEvidenceGraphNode 'EVIDENCE:BLOCK1' EVIDENCE -LibraryId 'LIB:L000001' -Attributes ([pscustomobject]@{EvidenceStatus='SUPPORTED';SourceReference='x';CriticalAppraisal='forbidden'})} 'HUMAN_OWNED_GRAPH_WRITE_BLOCKED' 'TEST 25 HUMAN_OWNED overwrite allowed.'
Assert-RapGraphThrows {New-RapEvidenceGraphNode 'EVIDENCE:BLOCK2' EVIDENCE -LibraryId 'LIB:L000001' -Attributes ([pscustomobject]@{EvidenceStatus='SUPPORTED';SourceReference='x';ReviewerMemo=''})} 'HUMAN_OWNED_GRAPH_WRITE_BLOCKED' 'TEST 26 blank HUMAN_OWNED write allowed.'
Assert-RapGraphTest ($h.State.Nodes['AI_EXTRACTION:AE-1'].Attributes.OriginState -eq 'AI_ASSISTED' -and $null -eq $h.State.Nodes['AI_EXTRACTION:AE-1'].Attributes.PSObject.Properties['ResearcherConfirmed']) 'TEST 27 AI silently confirmed.'
$badCommon=New-RapEvidenceGraphEdge 'META_CODING:LIB:L000001|PR001' HAS_COMMON_REVIEW 'COMMON_REVIEW:LIB:L000001' -ProjectId PR001;$badCommonOp=New-RapEvidenceGraphOperation -Nodes $fixture.Nodes -Edges @($badCommon)
Assert-RapGraphThrows {Invoke-RapEvidenceGraphMutation $badCommonOp (New-RapEvidenceGraphTestHarness).Dependencies -Mode Fixture} 'GRAPH_RELATION_TYPE_MISMATCH|COMMON_REVIEW_GRAPH_FIREWALL' 'TEST 28 project judgment entered Common Review.'

# TEST 29-34 integrity/idempotency
$missingSource=New-RapEvidenceGraphEdge 'EFFECT_SIZE:MISSING|PR001' SUPPORTED_BY $fixture.EvidenceA -ProjectId PR001;$sourceOp=New-RapEvidenceGraphOperation -Nodes @($evA) -Edges @($missingSource)
Assert-RapGraphThrows {Invoke-RapEvidenceGraphMutation $sourceOp (New-RapEvidenceGraphTestHarness).Dependencies -Mode Fixture} 'GRAPH_SOURCE_NODE_MISSING' 'TEST 29 missing source accepted.'
$effectNode=$fixture.Nodes|Where-Object NodeId -eq 'EFFECT_SIZE:ES-1|PR001';$missingTarget=New-RapEvidenceGraphEdge $effectNode.NodeId SUPPORTED_BY 'EVIDENCE:MISSING' -ProjectId PR001;$targetOp=New-RapEvidenceGraphOperation -Nodes @($effectNode) -Edges @($missingTarget)
Assert-RapGraphThrows {Invoke-RapEvidenceGraphMutation $targetOp (New-RapEvidenceGraphTestHarness).Dependencies -Mode Fixture} 'GRAPH_TARGET_NODE_MISSING' 'TEST 30 missing target accepted.'
$pp1=$fixture.Nodes|Where-Object NodeId -eq 'PROJECT_PAPER:LIB:L000001|PR001';$meta2=$fixture.Nodes|Where-Object NodeId -eq 'META_CODING:LIB:L000001|PR002';$cross=New-RapEvidenceGraphEdge $pp1.NodeId HAS_META_CODING $meta2.NodeId -ProjectId PR001;$crossOp=New-RapEvidenceGraphOperation -Nodes @($pp1,$meta2) -Edges @($cross)
Assert-RapGraphThrows {Invoke-RapEvidenceGraphMutation $crossOp (New-RapEvidenceGraphTestHarness).Dependencies -Mode Fixture} 'CROSS_PROJECT_GRAPH_EDGE_BLOCKED' 'TEST 31 cross-project contamination accepted.'
$dupHarness=New-RapEvidenceGraphTestHarness;$dupOp=New-RapEvidenceGraphOperation -Nodes $fixture.Nodes -Edges @($fixture.Edges+$fixture.Edges[0]);[void](Invoke-RapEvidenceGraphMutation $dupOp $dupHarness.Dependencies -Mode Fixture)
Assert-RapGraphTest ($dupHarness.State.Edges.Count -eq 29) 'TEST 32 duplicate edge created.'
$nodeCalls=$h.State.NodeUpserts;$edgeCalls=$h.State.EdgeUpserts;$replay=Invoke-RapEvidenceGraphMutation $operation $h.Dependencies -Mode Fixture
Assert-RapGraphTest ($replay.Status -eq 'ALREADY_COMPLETED' -and $h.State.NodeUpserts -eq $nodeCalls -and $h.State.EdgeUpserts -eq $edgeCalls) 'TEST 33 equivalent replay mutated graph.'
$conflictHarness=New-RapEvidenceGraphTestHarness;$op1=New-RapEvidenceGraphOperation $fixture.Nodes $fixture.Edges -OperationId GRAPH-CONFLICT;[void](Invoke-RapEvidenceGraphMutation $op1 $conflictHarness.Dependencies -Mode Fixture);$op2=New-RapEvidenceGraphOperation $fixture.Nodes @($fixture.Edges|Select-Object -First 1) -OperationId GRAPH-CONFLICT
Assert-RapGraphThrows {Invoke-RapEvidenceGraphMutation $op2 $conflictHarness.Dependencies -Mode Fixture} 'PAYLOAD_CONFLICT' 'TEST 34 changed payload accepted.'

# TEST 35-40 persistence/reload
$tempRoot=Join-Path ([IO.Path]::GetTempPath()) ("rap-graph-$PID-$([guid]::NewGuid().ToString('N'))");[void][IO.Directory]::CreateDirectory($tempRoot)
try{
    $database=Join-Path $tempRoot 'graph.db';$sqlite=New-RapEvidenceGraphSqliteDependencies $database;$persistOp=New-RapEvidenceGraphOperation $fixture.Nodes $fixture.Edges -OperationId GRAPH-PERSIST;[void](Invoke-RapEvidenceGraphMutation $persistOp $sqlite -Mode Fixture)
    $reloaded=New-RapEvidenceGraphSqliteDependencies $database;$snapshot=Get-RapEvidenceGraphFixtureSnapshot $database
    Assert-RapGraphTest (@($snapshot.Nodes).Count -eq 25) 'TEST 35 nodes did not persist.'
    Assert-RapGraphTest (@($snapshot.Edges).Count -eq 29) 'TEST 36 edges did not persist.'
    Assert-RapGraphTest (@($snapshot.Nodes|Where-Object ScopeKey -eq 'LIB:L000001|PR001').Count -gt 0 -and @($snapshot.Nodes|Where-Object ScopeKey -eq 'LIB:L000001|PR002').Count -gt 0) 'TEST 37 project context did not persist.'
    $persistedEvidence=$snapshot.Nodes|Where-Object NodeId -eq $fixture.EvidenceA
    Assert-RapGraphTest ($persistedEvidence.Attributes.SourceReference -eq 'fixture:table-a' -and $persistedEvidence.Attributes.EvidenceStatus -eq 'CONFLICTING_EVIDENCE') 'TEST 38 provenance did not persist.'
    $persistedAi=$snapshot.Nodes|Where-Object NodeId -eq 'AI_EXTRACTION:AE-1';$persistedConfirm=$snapshot.Nodes|Where-Object NodeId -eq 'RESEARCHER_CONFIRMED:RC-1|PR001'
    Assert-RapGraphTest ($persistedAi.Attributes.OriginState -eq 'AI_ASSISTED' -and $persistedConfirm.Attributes.ConfirmationState -eq 'RESEARCHER_CONFIRMED') 'TEST 39 confirmation distinction did not persist.'
    [void](Invoke-RapEvidenceGraphMutation $persistOp $reloaded -Mode Fixture);$afterReplay=Get-RapEvidenceGraphFixtureSnapshot $database
    Assert-RapGraphTest (@($afterReplay.Edges).Count -eq 29) 'TEST 40 reload replay duplicated edge.'
    $recoveryDb=Join-Path $tempRoot 'recovery.db';$pwsh=(Get-Process -Id $PID).Path;$recoveryScript=Join-Path $PSScriptRoot 'RecoveryProcess.ps1';$processA=& $pwsh -NoProfile -File $recoveryScript -Phase Prepare -DatabasePath $recoveryDb;if($LASTEXITCODE -ne 0){throw 'Graph Process A failed.'};$processB=& $pwsh -NoProfile -File $recoveryScript -Phase Resume -DatabasePath $recoveryDb;if($LASTEXITCODE -ne 0){throw 'Graph Process B failed.'}
    $recoveryPassed=($processA -contains 'GRAPH_PROCESS_A_PREPARED') -and ($processB -contains 'GRAPH_PROCESS_B_RECOVERED')
}finally{if(Test-Path -LiteralPath $tempRoot){Remove-Item -LiteralPath $tempRoot -Recurse -Force}}

# TEST 41-47 safety and independent recovery
$repo=[IO.Path]::GetFullPath((Join-Path $root '../../..'));$config=Get-Content -Raw (Join-Path $repo 'src/Local/ResearchAutomation.Local/config/config.json')|ConvertFrom-Json
Assert-RapGraphTest ($config.capabilities.ProductionAIProvider -eq $false) 'TEST 41 Production AI enabled.'
Assert-RapGraphTest ($config.capabilities.ProductionNotionWrite -eq $false) 'TEST 42 Production Notion enabled.'
Assert-RapGraphTest ($config.capabilities.ProductionZoteroWrite -eq $false) 'TEST 43 Production Zotero enabled.'
Assert-RapGraphTest ($config.capabilities.ProductionDriveMigration -eq $false) 'TEST 44 Production Drive migration enabled.'
Assert-RapGraphTest ($h.State.ExternalTests -eq 'TEST_DEFERRED' -and $h.State.ExternalCalls -eq 0) 'TEST 45 external tests were not deferred.'
Assert-RapGraphTest ($h.State.ProductionWrites -eq 0 -and $h.State.CommonReviewWrites -eq 0 -and $result.ProductionWrite -eq 'DISABLED') 'TEST 46 production data changed.'
Assert-RapGraphTest $recoveryPassed 'TEST 47 independent Process B recovery failed.'

Write-Host "SPR-008 Evidence Graph focused tests: 47/47 PASS; assertions: $script:Assertions"
