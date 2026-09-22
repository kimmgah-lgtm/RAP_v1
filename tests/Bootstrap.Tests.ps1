#Requires -Version 7.0
<# .SYNOPSIS Runs the RAP local bootstrap acceptance suite from the repository test entry point. #>
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
& (Join-Path $repositoryRoot 'src/Local/ResearchAutomation.Local/tests/Bootstrap.Tests.ps1')

