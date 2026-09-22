Set-StrictMode -Version Latest
class RapIntegrityReport {
 [string]$Timestamp;[int]$TotalPDFs;[int]$Verified;[int]$Missing;[int]$BrokenLinks;[int]$DuplicatePDFs;[int]$HashFailures;[int]$OrphanPDFs;[object[]]$Warnings=@();[object[]]$Details=@();[string]$Status
}
