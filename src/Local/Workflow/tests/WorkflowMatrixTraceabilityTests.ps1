#Requires -Version 7.0
# SPR-011 Turn E (RISK-SPR011-005): mechanically enforces docs/SPR-011-SCENARIO-MATRIX.md.
# Static rows (legacy L*, Turn-C R*/CA*) must name an assertion literal that exists in the named test file.
# Runtime rows (Turn-E E*/EA*) must equal, in both directions, the assertion IDs executed and passed now.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$repositoryRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
$matrixPath=Join-Path $repositoryRoot 'docs/SPR-011-SCENARIO-MATRIX.md'
$script:N=0
function A([bool]$Condition,[string]$Message){$script:N++;if(!$Condition){throw "Traceability assertion $script:N failed: $Message"}}

A (Test-Path -LiteralPath $matrixPath) 'matrix document exists'
$rows=[Collections.Generic.List[object]]::new()
foreach($line in Get-Content -LiteralPath $matrixPath -Encoding utf8){
    if($line-notmatch'^\| (L\d{2}|R\d{2}|CA-[A-I]2?|E\d-[A-Z0-9-]+|EA-\d{2}) \|'){continue}
    $cells=@([regex]::Split($line.Trim().Trim('|'),'(?<!\\)\|')|ForEach-Object{$_.Trim().Replace('\|','|')})
    $rows.Add([pscustomobject]@{Id=$cells[0];Test=$cells[4];Assertion=$cells[5];Actual=$cells[7];Cells=$cells.Count})
}
A ($rows.Count-ge150) "matrix has mandatory rows ($($rows.Count))"
A (@($rows|Where-Object Cells -ne 9).Count-eq0) 'every row has the full 9-column schema'
A (@($rows.Id|Group-Object|Where-Object Count -gt 1).Count-eq0) 'Requirement_IDs are unique'
A (@($rows|Where-Object Actual -ne 'PASS').Count-eq0) 'every row records Actual=PASS'

# Static rows: literal assertion tokens must exist in the named test file.
$static=@($rows|Where-Object{$_.Id-match'^(L|R|CA)'})
$missing=[Collections.Generic.List[string]]::new()
foreach($row in $static){
    $file=Join-Path $PSScriptRoot $row.Test
    if(-not(Test-Path -LiteralPath $file)){$missing.Add("$($row.Id): file $($row.Test)");continue}
    $content=Get-Content -LiteralPath $file -Raw -Encoding utf8
    $tokens=@([regex]::Matches($row.Assertion,'`([^`]+)`')|ForEach-Object{$_.Groups[1].Value})
    if(-not$tokens.Count){$missing.Add("$($row.Id): no assertion token");continue}
    foreach($token in $tokens){if(-not$content.Contains($token)){$missing.Add("$($row.Id): '$token' not in $($row.Test)")}}
}
A ($missing.Count-eq0) "static assertion literals resolved: $($missing-join '; ')"
A (@($static|Where-Object{$_.Id-match'^L'}).Count-eq40) 'all 40 legacy requirements are mapped'
A (@($static|Where-Object{$_.Id-match'^R'}).Count-eq20) 'R01-R20 are mapped'

# Runtime rows: execute the Turn-E suites in separate processes and compare ID sets both ways.
$powerShell=(Get-Process -Id $PID).Path
$resultPath=Join-Path ([IO.Path]::GetTempPath()) "rap-trace-$PID-$([guid]::NewGuid().ToString('N')).json"
try{
    $null=&$powerShell -NoProfile -File (Join-Path $PSScriptRoot 'WorkflowTurnERemediationTests.ps1') -ResultPath $resultPath
    A ($LASTEXITCODE-eq0) 'Turn-E remediation suite passed during traceability run'
    $executed=@(Get-Content -LiteralPath $resultPath -Raw -Encoding utf8|ConvertFrom-Json)
}finally{Remove-Item -LiteralPath $resultPath -Force -ErrorAction SilentlyContinue}
$passedE=@($executed|Where-Object Result -eq 'PASS'|ForEach-Object Id|Sort-Object)
$matrixE=@($rows|Where-Object{$_.Id-match'^E\d-'}|ForEach-Object Id|Sort-Object)
A ($passedE.Count-eq$executed.Count) 'every executed Turn-E assertion passed'
A (($passedE-join',')-eq($matrixE-join',')) "Turn-E matrix rows equal executed assertions (unmapped: $(@($passedE|Where-Object{$_-notin$matrixE})-join','); not executed: $(@($matrixE|Where-Object{$_-notin$passedE})-join','))"
$advOut=@(&$powerShell -NoProfile -File (Join-Path $PSScriptRoot 'WorkflowTurnEAdversarialTests.ps1'))
A ($LASTEXITCODE-eq0) 'Turn-E adversarial suite passed during traceability run'
$passedEA=@($advOut|ForEach-Object{[string]$_}|Where-Object{$_-match'^EA-\d{2} PASS '}|ForEach-Object{$_.Split(' ')[0]}|Sort-Object)
$matrixEA=@($rows|Where-Object{$_.Id-match'^EA-'}|ForEach-Object Id|Sort-Object)
A (($passedEA-join',')-eq($matrixEA-join',')) 'Turn-E adversarial matrix rows equal executed assertions'

Write-Host "SPR-011 matrix traceability tests: PASS; mapped rows: $($rows.Count); assertions: $script:N"
