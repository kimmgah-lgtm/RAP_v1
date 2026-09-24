Set-StrictMode -Version Latest;$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
$matrix=Get-Content -Raw (Join-Path $root 'docs/SPR-011.5-SCENARIO-MATRIX.md')
$core=Get-Content -Raw (Join-Path $PSScriptRoot 'ReconciliationTests.ps1')
$negative=Get-Content -Raw (Join-Path $PSScriptRoot 'ReconciliationNegativeTests.ps1')
$script:N=0;function A([bool]$ok,[string]$m){$script:N++;if(!$ok){throw "Traceability assertion $script:N failed: $m"}}
$requirements=@('Snapshot / Difference Detector','Ownership-aware Decision','Recovery Plan','DRY_RUN','Local / Fixture Apply','Read-back Verification','Audit / Lineage','Stale-plan Protection','Idempotency','Restart Recovery')
A (@($requirements|Where-Object{$matrix-notmatch[regex]::Escape($_)}).Count-eq0) 'all ten requirements mapped'
A (@(1..16|Where-Object{$core-notmatch("RC{0:d2}"-f$_)}).Count-eq0) 'RC01-RC16 mapped to executable assertions'
A (@(1..16|Where-Object{$negative-notmatch("N{0:d2}"-f$_)}).Count-eq0) 'N01-N16 mapped to executable assertions'
A (($matrix|Select-String '\| PASS \|' -AllMatches).Matches.Count-eq10) 'every requirement records PASS'
A ($matrix-match'Library_ID \+ Project_ID') 'scope isolation mapped'
A ($matrix-match'protected ownership') 'ownership protection mapped'
A ($matrix-match'production-write disablement') 'production safety mapped'
A ($matrix-match'mandatory verification') 'read-back requirement mapped'
if($script:N-ne8){throw "Expected 8 traceability assertions, got $script:N"};Write-Host "SPR-011.5 traceability: 10/10 requirements mapped; assertions: $script:N"
