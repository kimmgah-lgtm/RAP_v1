Set-StrictMode -Version Latest
function Get-RapDriveSHA256 {
 <#
 .SYNOPSIS Computes a lowercase SHA-256 digest without changing content.
 .PARAMETER Bytes File content bytes.
 .OUTPUTS Lowercase hexadecimal SHA-256 string.
 #>
 [CmdletBinding()]param([Parameter(Mandatory)][byte[]]$Bytes)
 [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($Bytes)).ToLowerInvariant()
}
function Test-RapDriveSHA256 {
 <#
 .SYNOPSIS Compares content with an expected SHA-256 digest.
 .PARAMETER Bytes File content bytes.
 .PARAMETER ExpectedSHA256 Expected 64-character digest.
 .OUTPUTS Boolean comparison result.
 #>
 [CmdletBinding()]param([Parameter(Mandatory)][byte[]]$Bytes,[Parameter(Mandatory)][ValidatePattern('^[0-9a-fA-F]{64}$')][string]$ExpectedSHA256)
 (Get-RapDriveSHA256 $Bytes) -eq $ExpectedSHA256.ToLowerInvariant()
}
Export-ModuleMember -Function Get-RapDriveSHA256,Test-RapDriveSHA256
