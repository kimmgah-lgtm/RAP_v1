Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'Verification.psm1') -Force

function New-RapWriteCommand {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Command,[Parameter(Mandatory)][ValidatePattern('^[A-Z0-9]{8}$')][string]$ItemKey,[Parameter(Mandatory)][hashtable]$Payload,[string]$OperationID=([guid]::NewGuid().ToString()),[string]$Operator=[Environment]::UserName)
    [pscustomobject]@{
        OperationID=$OperationID;Command=$Command;ItemKey=$ItemKey;Payload=$Payload;Operator=$Operator
        Validate={param($self,$context,$current) Test-RapWriteCommand -Command $self -Context $context -Current $current}
        Execute={param($self,$context,$snapshot) & $context.Apply $self $snapshot}
        Verify={param($self,$context,$actual,$writeResult) Test-RapWriteVerification -Command $self -Actual $actual -WriteResult $writeResult}
        Rollback={param($self,$context,$snapshot,$writeResult) & $context.Restore $self $snapshot $writeResult}
    }
}

function Test-RapWriteCommand {
    [CmdletBinding()]
    param($Command,$Context,$Current)
    if($null -eq $Current){return [pscustomobject]@{Valid=$false;Status='VALIDATION_FAILED';Reason='Item not found'}}
    switch($Command.Command){
        'WriteLibraryId'{
            $id=[string]$Command.Payload.LibraryId;if($id -notmatch '^LIB:L\d{6}$'){return [pscustomobject]@{Valid=$false;Status='VALIDATION_FAILED';Reason='Library_ID must match LIB:L000001'}}
            $match=[regex]::Match([string]$Current.data.extra,'(?m)^Library_ID:\s*(LIB:L\d{6})\s*$');if($match.Success){return [pscustomobject]@{Valid=$true;Status='ALREADY_EXISTS';Reason=$match.Groups[1].Value}}
        }
        'WriteExtra'{if($null -eq $Command.Payload.Extra){return [pscustomobject]@{Valid=$false;Status='VALIDATION_FAILED';Reason='Extra is required'}};if([string]$Current.data.extra -eq [string]$Command.Payload.Extra){return [pscustomobject]@{Valid=$true;Status='ALREADY_EXISTS';Reason='Extra already matches'}}}
        'WriteTag'{if([string]$Command.Payload.Tag -notmatch '^rap:[a-z0-9][a-z0-9._-]{0,63}$'){return [pscustomobject]@{Valid=$false;Status='VALIDATION_FAILED';Reason='Only rap: system tags are allowed'}};if(@($Current.data.tags|ForEach-Object{$_.tag}) -contains $Command.Payload.Tag){return [pscustomobject]@{Valid=$true;Status='ALREADY_EXISTS';Reason='Tag already exists'}}}
        'AddCollection'{if([string]$Command.Payload.CollectionKey -notmatch '^[A-Z0-9]{8}$'){return [pscustomobject]@{Valid=$false;Status='VALIDATION_FAILED';Reason='Invalid collection key'}};if(@($Current.data.collections) -contains $Command.Payload.CollectionKey){return [pscustomobject]@{Valid=$true;Status='ALREADY_EXISTS';Reason='Collection already assigned'}}}
        'UpdateMetadata'{if($Command.Payload.Fields.Count -eq 0){return [pscustomobject]@{Valid=$false;Status='VALIDATION_FAILED';Reason='Metadata fields are required'}};foreach($key in $Command.Payload.Fields.Keys){if($key -notin @('title','DOI','ISBN','date','publicationTitle')){return [pscustomobject]@{Valid=$false;Status='VALIDATION_FAILED';Reason="Metadata field is not allowed: $key"}}}}
        'CreateLinkedAttachment'{if(-not [IO.Path]::IsPathRooted([string]$Command.Payload.Path)){return [pscustomobject]@{Valid=$false;Status='VALIDATION_FAILED';Reason='Linked attachment path must be absolute'}}}
        default{return [pscustomobject]@{Valid=$false;Status='VALIDATION_FAILED';Reason='Unknown command'}}
    }
    [pscustomobject]@{Valid=$true;Status='READY';Reason='Validated'}
}

Export-ModuleMember -Function New-RapWriteCommand,Test-RapWriteCommand
