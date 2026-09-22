Set-StrictMode -Version Latest
function New-RapBootstrapReport {<#
.SYNOPSIS
Creates the immutable summary of one bootstrap execution.
#>[CmdletBinding()]param([string]$OperationId,[string]$Status,[object[]]$Items,[object[]]$Warnings,[string]$Mode)[pscustomobject]@{Timestamp=[DateTimeOffset]::UtcNow.ToString('o');OperationId=$OperationId;Status=$Status;Mode=$Mode;Total=@($Items).Count;Succeeded=@($Items|Where-Object Status -eq SUCCESS).Count;Failed=@($Items|Where-Object Status -eq FAILED).Count;Warnings=@($Warnings);Items=@($Items)}}
Export-ModuleMember -Function New-RapBootstrapReport
