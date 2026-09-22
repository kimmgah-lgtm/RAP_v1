Set-StrictMode -Version Latest
function Test-RapWriteVerification {
    [CmdletBinding()]
    param($Command,$Actual,$WriteResult)
    if($null -eq $Actual){return $false}
    switch($Command.Command){
        'WriteLibraryId'{return [string]$Actual.data.extra -match "(?m)^Library_ID:\s*$([regex]::Escape($Command.Payload.LibraryId))\s*$"}
        'WriteExtra'{return [string]$Actual.data.extra -eq [string]$Command.Payload.Extra}
        'WriteTag'{return @($Actual.data.tags|ForEach-Object{$_.tag}) -contains $Command.Payload.Tag}
        'AddCollection'{return @($Actual.data.collections) -contains $Command.Payload.CollectionKey}
        'UpdateMetadata'{foreach($key in $Command.Payload.Fields.Keys){if([string]$Actual.data.$key -ne [string]$Command.Payload.Fields[$key]){return $false}};return $true}
        'CreateLinkedAttachment'{return $null -ne $WriteResult.CreatedKey -and @($Actual.children.key) -contains $WriteResult.CreatedKey}
    }
    return $false
}
Export-ModuleMember -Function Test-RapWriteVerification
