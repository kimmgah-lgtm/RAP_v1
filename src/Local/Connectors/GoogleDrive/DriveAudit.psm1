Set-StrictMode -Version Latest
function Write-RapDriveAudit {<#
.SYNOPSIS
Appends one Drive verification audit record as JSONL.
#>[CmdletBinding()]param([Parameter(Mandatory)][string]$Path,[Parameter(Mandatory)]$Record)[void][IO.Directory]::CreateDirectory((Split-Path -Parent $Path));Add-Content -LiteralPath $Path -Value ($Record|ConvertTo-Json -Depth 20 -Compress) -Encoding utf8NoBOM}
Export-ModuleMember -Function Write-RapDriveAudit
