Set-StrictMode -Version Latest

class RapZoteroItem {
    [string]$ItemKey
    [string]$LibraryType
    [long]$Version
    [string]$Title
    [object[]]$Creators = @()
    [string]$DOI
    [string]$ISBN
    [string]$Date
    [string]$Publication
    [object[]]$Collections = @()
    [string[]]$Tags = @()
    [string]$Extra
    [object[]]$Notes = @()
    [object[]]$Attachments = @()
    [object]$AnnotationSummary
}

