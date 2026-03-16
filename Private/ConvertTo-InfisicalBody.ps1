# ConvertTo-InfisicalBody.ps1
# Builds request body hashtables consistently for Infisical API calls.
# Ensures workspaceId, environment, and secretPath are always included.
# Handles SecureString → plaintext conversion in a single controlled place.
# Called by: New-InfisicalSecret, Set-InfisicalSecret, Remove-InfisicalSecret
# Dependencies: InfisicalSession class

function ConvertTo-InfisicalBody {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [InfisicalSession] $Session,

        [Parameter()]
        [string] $Environment,

        [Parameter()]
        [string] $SecretPath = '/',

        [Parameter()]
        [string] $ProjectId,

        [Parameter()]
        [System.Security.SecureString] $SecretValue,

        [Parameter()]
        [string] $Comment,

        [Parameter()]
        [switch] $SkipMultilineEncoding,

        [Parameter()]
        [string[]] $TagIds,

        [Parameter()]
        [hashtable] $SecretMetadata,

        [Parameter()]
        [int] $ReminderRepeatDays,

        [Parameter()]
        [string] $ReminderNote,

        [Parameter()]
        [string[]] $ReminderRecipients,

        [Parameter()]
        [string] $NewSecretName,

        [Parameter()]
        [ValidateSet('shared', 'personal')]
        [string] $Type,

        [Parameter()]
        [hashtable] $AdditionalProperties
    )

    $resolvedEnvironment = if ([string]::IsNullOrEmpty($Environment)) {
        $Session.DefaultEnvironment
    }
    else {
        $Environment
    }

    $resolvedProjectId = if ([string]::IsNullOrEmpty($ProjectId)) {
        $Session.ProjectId
    }
    else {
        $ProjectId
    }

    $body = @{
        workspaceId = $resolvedProjectId
        environment = $resolvedEnvironment
        secretPath  = $SecretPath
    }

    # Convert SecureString to plaintext in this single controlled location
    if ($null -ne $SecretValue) {
        $body['secretValue'] = [System.Net.NetworkCredential]::new('', $SecretValue).Password
    }

    if (-not [string]::IsNullOrEmpty($Comment)) {
        $body['secretComment'] = $Comment
    }

    if ($SkipMultilineEncoding.IsPresent) {
        $body['skipMultilineEncoding'] = $true
    }

    if ($null -ne $TagIds -and $TagIds.Count -gt 0) {
        $body['tagIds'] = $TagIds
    }

    if ($null -ne $SecretMetadata -and $SecretMetadata.Count -gt 0) {
        $metadataArray = [System.Collections.Generic.List[hashtable]]::new()
        foreach ($key in $SecretMetadata.Keys) {
            $metadataArray.Add(@{ key = $key; value = [string]$SecretMetadata[$key] })
        }
        $body['secretMetadata'] = @($metadataArray)
    }

    if ($PSBoundParameters.ContainsKey('ReminderRepeatDays') -and $ReminderRepeatDays -gt 0) {
        $body['secretReminderRepeatDays'] = $ReminderRepeatDays
    }

    if (-not [string]::IsNullOrEmpty($ReminderNote)) {
        $body['secretReminderNote'] = $ReminderNote
    }

    if ($null -ne $ReminderRecipients -and $ReminderRecipients.Count -gt 0) {
        $body['secretReminderRecipients'] = $ReminderRecipients
    }

    if (-not [string]::IsNullOrEmpty($NewSecretName)) {
        $body['newSecretName'] = $NewSecretName
    }

    if (-not [string]::IsNullOrEmpty($Type)) {
        $body['type'] = $Type
    }

    # Merge any additional properties
    if ($null -ne $AdditionalProperties) {
        foreach ($key in $AdditionalProperties.Keys) {
            $body[$key] = $AdditionalProperties[$key]
        }
    }

    return $body
}
