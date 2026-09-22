Set-StrictMode -Version Latest
function Backup-RapItem {
    <# .SYNOPSIS Creates an immutable deep-copy snapshot before a write. #>
    [CmdletBinding()]param([Parameter(Mandatory)]$Item)
    $copy=$Item|ConvertTo-Json -Depth 30 -Compress|ConvertFrom-Json -Depth 30
    [pscustomobject]@{Timestamp=[DateTimeOffset]::UtcNow.ToString('o');Version=$copy.version;Extra=$copy.data.extra;Tags=@($copy.data.tags);Collections=@($copy.data.collections);Attachments=@($copy.children|Where-Object{$_.data.itemType -eq 'attachment'});Item=$copy}
}
Export-ModuleMember -Function Backup-RapItem

