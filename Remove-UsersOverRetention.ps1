<#
.SYNOPSIS
    Connects to an Azure AD B2C tenant and fetches an access_token for querying Microsoft Graph.
    Uses the token to find users based on a filter and uses the select parameter to fetch the necessary user attributes.
    Checks users createdDateTime against $UserRetention and deletes user if retention setting is met or exceeeded.
    REMEMBER that app principal (or user) must have adequate privileges to be able to delete users from tenant.
.PARAMETER UserRetention
    User retention setting (in days).
.PARAMETER TenantId
    Tenant identifier.
.PARAMETER ClientId
    App registration identifier.
.PARAMETER ClientSecret
    App registration secret.
.EXAMPLE
    .\Remove-UsersOverRetention.ps1
    If run without params variables must be fetched from session environment variables ($ENV:).
.EXAMPLE
    .\Remove-UsersOverRetention.ps1 -UserRetention 30 -TenantId xxx -ClientId xxx -ClientSecret xyz
    Direct execution means params must be supplied at runtime, primarily meant for testing (id and secret in clear text).
.DESCRIPTION
    19.07.2022:
    Original script runs in an Azure DevOps pipeline where variables are found in the environment ($ENV:).
    Script was modified to support direct execution, assuming the necessary parameters and credentials are supplied.
    Script implements SupportsShouldProcess which means -WhatIf (and -Confirm) can be used for testing intended action.
#>

[CmdletBinding(SupportsShouldProcess=$true)]
Param(
	[Parameter(
        HelpMessage='B2C user retention setting',
        Mandatory=$False)]
		[string]$UserRetention = $ENV:B2C_USER_RETENTION,
    [Parameter(
        HelpMessage='Name of B2C tenant identifier',
        Mandatory=$False)]
		[string]$TenantId = $ENV:B2C_TENANT_ID,
	[Parameter(
        HelpMessage='App registration identifier',
        Mandatory=$False)]
		[string]$ClientId= $ENV:DEPLOYMENT_APP_REGISTRATION_CLIENTID,
	[Parameter(
        HelpMessage='App registration secret',
        Mandatory=$False)]
		[string]$ClientSecret = $ENV:DEPLOYMENT_APP_REGISTRATION_CLIENTSECRET
	)


# Connect to Azure AD B2C tenant
Write-Host "Connecting to Azure AD B2C tenant..."
$uri = "https://login.microsoftonline.com/{0}/oauth2/token" -f $TenantId
$body = "resource=https://graph.microsoft.com/&client_id=$($ClientId)&grant_type=client_credentials&client_secret={0}" -f [System.Net.WebUtility]::UrlEncode($ClientSecret)
$token = Invoke-RestMethod $uri -Body $body -ContentType "application/x-www-form-urlencoded" -ErrorAction Stop

$restParams = @{
    Headers = @{
        Authorization = "Bearer $($token.access_token)"
    }    
}

# Get all users
$users = New-Object System.Collections.ArrayList
# Filter users with display name starting with 'b2c_' and select parameters id, displayName, createdDateTime
$uri = "https://graph.microsoft.com/v1.0/users?`$top=999&`$filter=(startswith(displayName,'b2c_'))&`$select=id,displayName,createdDateTime"
do {
    $result = Invoke-RestMethod $uri @restParams
    if ($result.value) {
        $result.value | ForEach-Object {
            $users.Add($_) | Out-Null
        }        
    }

    # If there are more than 999 users, follow odata link to next page
    $uri = $result.'@odata.nextLink'
} while ($uri) # Continue for as long as there are nextLinks

# Process users
if ($users) {
    # User retentions in days
    Write-Host "User retention setting in number of days: $($UserRetention)"
    $users | ForEach-Object {
        Write-Host "Processing user: $($_.displayName)"

        # Set created date fetched from resultant Graph query object
        $newDate = $($_.createdDateTime)
        # Calculate, in days, how long ago the user was created
        $daysAgo = ((Get-Date) - $newDate).Days

        # If $daysAgo is greater or equal to user retention it means that the user will be deleted
        if ($daysAgo -ge $UserRetention) {

            # Script implements SupportsShouldProcess and can therefore be run with -WhatIf parameter
            if ($PSCmdlet.ShouldProcess($($_.displayName),'Delete user')) {
                try {
                    Write-Host "Delete user $($_.displayName) is $($daysAgo) days old."
                    # Put result in $res to avoid output and later potentially add check for .StatusCode
                    $res = Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/users/$($_.id)" -Method Delete @restParams
                    Write-Host "User successfully deleted!"
                }
                catch { Write-Host "Delete user query failed`nError $($Exception.Message))" -BackgroundColor Red}
            }
            else {
                Write-Host "User $($_.displayName) is $($daysAgo) days old."
                Write-Host "Invoke-RestMethod -Uri `"https://graph.microsoft.com/v1.0/users/$($_.id)`" -Method Delete @restParams"
            }
        }
        else {
            Write-Host "User was created $daysAgo days ago, leaving it alone."
        }
    }
}
else {
    Write-Host "No users to process"
}