Set-StrictMode -Version Latest

class RapZoteroAttachment {
    [string]$ItemKey
    [string]$Title
    [string]$ContentType
    [string]$Path
    [bool]$IsLinked
    [bool]$FileExists
    [object[]]$Annotations = @()
}

