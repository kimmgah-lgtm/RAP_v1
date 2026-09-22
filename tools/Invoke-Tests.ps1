#Requires -Version 7.0
<# .SYNOPSIS Runs repository acceptance tests. #>
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
& (Join-Path $repositoryRoot 'src/Local/ResearchAutomation.Local/tests/Bootstrap.Tests.ps1')

