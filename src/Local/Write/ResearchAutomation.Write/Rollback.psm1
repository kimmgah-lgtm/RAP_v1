Set-StrictMode -Version Latest
function Invoke-RapRollback {
    <# .SYNOPSIS Executes the command rollback against its pre-write snapshot. #>
    [CmdletBinding()]param($Command,$Context,$Snapshot,$WriteResult)
    & $Command.Rollback $Command $Context $Snapshot $WriteResult
}
Export-ModuleMember -Function Invoke-RapRollback

