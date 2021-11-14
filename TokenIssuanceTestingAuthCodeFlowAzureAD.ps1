#############################################################
# Get OIDC Code from an Azure AD application registration
# This sample only works on Azure AD apps (not AAD B2C)
#############################################################

Add-Type -AssemblyName System.Web

# Your Client ID and Client Secret obtained when registering your WebApp
$tenantName = '.onmicrosoft.com'
$clientId = ''
$clientSecret = ''  #  // NOTE: Only required for web apps
# $apiClientId = ''
#$resource =  'https://{0}/{1}/write https://{0}/{1}/read' -f $tenantName, $apiClientId
$redirectUri = "https://jwt.ms"
$scope = 'openid' #+ $resource


# UrlEncode the app ID redirect URI and scope parameter because it contains the resource URL
$redirectUriEncoded =  [System.Web.HttpUtility]::UrlEncode($redirectUri)
$scopeEncoded = [System.Web.HttpUtility]::UrlEncode($scope)

Function Get-AuthCode {
    Add-Type -AssemblyName System.Windows.Forms

    $form = New-Object -TypeName System.Windows.Forms.Form -Property @{Width=512;Height=1024}
    $web  = New-Object -TypeName System.Windows.Forms.WebBrowser -Property @{Width=512;Height=1024;Url=($url -f ($scope -join "%20")) }

    $DocComp  = {
        $Global:uri = $web.Url.AbsoluteUri        
        if ($Global:uri -match "error=[^&]*|code=[^&]*") {$form.Close() }
    }
    $web.ScriptErrorsSuppressed = $true
    $web.Add_DocumentCompleted($DocComp)
    $form.Controls.Add($web)
    $form.Add_Shown({$form.Activate()})
    $form.ShowDialog() | Out-Null

    $queryOutput = [System.Web.HttpUtility]::ParseQueryString($web.Url.Query)
    $output = @{}
    foreach($key in $queryOutput.Keys){
        $output["$key"] = $queryOutput[$key]
    }

    $output
}

$BaseUri = "https://login.microsoftonline.com/{0}/oauth2/v2.0/authorize" -f $tenantName
$url = "$($BaseUri)?" + `
        "client_id=$($clientId)" + `
        "&response_mode=query" + `
        "&response_type=code" + `
        "&redirect_uri=$($redirectUriEncoded)" + `
        # The redirect_uri of your app, where authentication responses can be sent and received by your app. It must exactly match one of the redirect_uris you registered in the portal, 
        # except it must be url encoded. For native & mobile apps, you should use the default value of https://login.microsoftonline.com/common/oauth2/nativeclient
        "&scope=$($scopeEncoded)" + `
        "&state=myState" + `
        "&nonce=1234randomkr0234kfa12"

$result = Get-AuthCode
Write-Output $result

####################################################
# Now that you've acquired an authorization_code and have been granted permission by the user, you can redeem the code for an access_token to the desired resource.
# https://docs.microsoft.com/en-us/azure/active-directory/develop/active-directory-v2-protocols-oauth-code
###################################################

###############################################
# Exchange code for id_token
###############################################

$GrantType = "authorization_code"
$Uri = "https://login.microsoftonline.com/$($tenantName)/oauth2/v2.0/token"
$scopeFormatted = "openid" # -f $resource

$Body = @{
    "grant_type" = $GrantType
    "client_id" = $clientid
    "scope" = $scopeFormatted
    "code" = $result.code
    "redirect_uri" = $redirectUri
    "client_secret" = $clientSecret
}

$token = Invoke-RestMethod -Uri $Uri -Method Post -Body $Body
Write-Output $token