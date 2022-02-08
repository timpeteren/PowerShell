<#
    ###############################################################################################################################
    #
    # 06.02.2021 Tim Peter Edstrøm, TietoEVRY Public Cloud
    #
    # Set-ComputersFromCertificates.ps1
    #
    # Script will fetch all issued (and omit revoked) and still valid certificates issued from a certificate template
    # It will create computer objects in an organizational by comparing the identities of issued certificate with objects in the OU
    #
    # NOTE!
    # The script should be run in a normal user context as it does not require elevated privileges
    #
    # Pre-req:
    # * Account running script must be a *domain user* and have permissions to add computer objects in the designated OU
    #       Use "delegate" on the Organizational Unit (OU), choose custom and then computer object and read / write
    # * The service account used running script MUST have "Issue and Manage" permissions on the Certificate Authority (CA) to query CA for issued certificates <- IMPORTANT
    # * The OU canonical name is required to address the OU for the device objects, but WITHOUT the "domain.local/" prefix
    #       The canonical name of an object or OU can be found on the Active Directory object tab "Object" :-)
    #
    # v0.1: Initial release
    #
    # v0.2: Added service principal names when creating computer object
    #       Added $basePath and $dNameOU to list of variables to be cleared before executing
    #
    # v0.3: Added $objName by splitting $cert.CommonName to remove domain extension, because object can only be a name (not FQDN)
    #
    # v0.4: Add domain extension check for object to be created, add directory wide search to rule out that object exists elsewhere
    #
    # v0.5: Add culture settings to avoid datetime format to be an issue while creating PowerShell custom objects from certificates
    #
    # v0.6: Add back support for checking against objects existing in designated OU before deciding to create object or not
    #
    # v0.7: Add check against directory in case object exists elsewhere, add additional output during and post execution
    #
    # v0.8: Use a split overload that only splits the the strings containing ':' once (ShortDate format can use either '.' or ':'
    #
    # v0.85: Output status if no new certificates have been found, minor improvements
    #
    # 07.02.22 Tim Peter Edstrøm
    # v0.9: Add check for prerequisite PowerShell module
    #       Modify script to require it to be run as administrator once (if the PowerShell module is not installed)
    #
    #
    #
    # TODO:
    # * Write status, when performing additions (and later, removals) to Event Log
    # * Add cleanup support by removing objects from the OU if a certificate has been revoked or expired
    # * Support local user to exceute task and read the credentials for the domain user from encrypted file on disk
    #
    #
    ###############################################################################################################################
#>

# Add param to distringuish if script needs to install pre-requisite feature and then exit administrative context once it's done
$preReqCheck = (Get-WindowsFeature -name RSAT-AD-Powershell).InstallState

if ($preReqCheck -eq "Available") {
    try {
    
        # Verify that the script is running with elevated privileges
        if (-not ( [Security.Principal.WindowsIdentity]::GetCurrent().Groups -contains 'S-1-5-32-544') ) {
            Write-Host "On first execution, run script with administrative privileges to install prerequisites." -ForegroundColor Red
        }
        else {
            $result = Install-WindowsFeature -Name RSAT-AD-Powershell -Confirm:$false -Verbose
            Write-Host "Successfully installed prerequisite. Now run script again in non-elevated context." -ForegroundColor Green
        }
    } catch {
        Write-Error "Failure when installing prerequisites, exiting..."
    }
    exit
}

# Clears values before executing script in case it has been run multiple times (these search strings would otherwise append for each run)
$domainDName = $null
$basePath    = $null
$dNameOU     = $null
$certsCN     = $null
$templ       = $null
$templDName  = $null
$templOID    = $null
$Data        = $null
$i=$j=$k=$l=$m  = 0

<##### Variables below must be filled in manually #####>

# Fill in $domain and $domainDName values manually should you so prefer
$domain = (Get-ADDomain).DNSRoot
# Canonical name format (and OU order) and NOT distinguished name order, example: "Resources/dot1xDevices", WITHOUT domain
$path = "example/servers/dot1x"
# Certificate authority servername (ONLY) WITHOUT domain, which is added from the $domain variable
$serverName = "exampleCAserver"
# Certificate Authority (CA) name, can be found by runnning "certutil -ping" on CA server, or by opening CA management console
$certificateAuthorityName = "example Issuing CA"
# Certificate template DISPLAY name (including spaces if template contains any)
$templDName = "example computer certificate template"

<##### End of variables that must be filled in manually #####>

# Build certificate authority FQDN
$certificateAuthorityFQDN = "$serverName.$domain\$certificateAuthorityName"

# Sets $domainDName based on $domain name
while ($i -lt $domain.Split(".").Length) {$domainDName += "DC=" + $($domain.Split("."))[$i] ; $i++ ; if ($i -lt $domain.Split(".").Length) {$domainDName += ","}}

# Get template name
$templ = ActiveDirectory\Get-ADObject -SearchBase "CN=OID,CN=Public Key Services,CN=Services,CN=Configuration,$domainDName" -Filter * -Properties * | Where-Object {$_.DisplayName -like $templDName}

# Override for v1 templates for example 'User' 'Computer' 'Web Server' built-in templates which are addressed by name and not OID
if (-not ([System.String]::IsNullOrWhiteSpace($templ)))
{
    $templOID = $templ.'msPKI-Cert-Template-OID'
}
else
{
    $templOID = $templDName
}

# Finds all certificates that have not yet expired, are in the issued certificates list and is issued from the certificate template entered above
$Data = certutil -config $certificateAuthorityFQDN -view -restrict "Disposition=20,Certificatetemplate=$templOID,Certificate Expiration Date>now" -out "Issued Common Name, Certificate Hash, Certificate Effective Date, Certificate Expiration Date, SerialNumber" | findstr "Name: Hash: Date:"

# Builds an array of certificate objects that includes common name and hash (thumbprint)
[System.Collections.ArrayList]$Result = @()

for ($j = 0; $j -lt $($Data.Count); $j++) {
    # Create custom object and applicable properties
    if ($j % 4 -eq 0)
    {
        $T1 = ($Data[$j+2].Split(":", 2)[-1])
        $T2 = ($Data[$j+3].Split(":", 2)[-1])

        $IssueDate = [DateTime]::Parse((Get-Date $T1),[CultureInfo]::InvariantCulture)
        $Expirationdate = [DateTime]::Parse((Get-Date $T2),[CultureInfo]::InvariantCulture) 

        $CertObject = New-Object -TypeName PSObject
        # Split on comma, remove double quotes, trim any leading (and trailing) space(s)
        Add-Member -InputObject $CertObject -MemberType NoteProperty -Name "CommonName" -Value (($Data[$j].Split(":")[-1]).Replace("`"","")).Trim()
        Add-Member -InputObject $CertObject -MemberType NoteProperty -Name "Hash" -Value (($Data[$j+1].Split(":")[-1]).Replace("`"","")).Replace(" ","")
        Add-Member -InputObject $CertObject -MemberType NoteProperty -Name "IssueDate" -Value $IssueDate 
        Add-Member -InputObject $CertObject -MemberType NoteProperty -Name "ExpirationDate" -Value $Expirationdate 

        # Check and discard empty values
        if ($CertObject.CommonName -notmatch "EMPTY" -and $CertObject.Hash -notmatch "EMPTY")
        {
            # Add new custom object to collection
			$Result.Add($CertObject) | Out-Null # Redirect output to null to avoid console log of index
        }
    }
    $T1             = $null
    $T2             = $null
    $IssueDate      = $null
    $Expirationdate = $null
}

$k = $path.Split("/").Length
while ($k -gt 0) {
    $dNameOU += "OU=" + $path.Split("/")[($k-1)] + ","
    $k--
    if (($path.Split("/")[($path.Split("/").Length)-1]) -eq ($path.Split("/")[($k-1)]) )
    {
        # does nothing if the last OU from $path is the one being processed
    } 
    else
    {
        $basePath  += "OU=" + $path.Split("/")[$k-1] + ","
    }
}

while (($domain.Split(".").Length) -ne $l) {
    $dNameOU += "DC=" + $domain.Split(".")[$l]
    $basePath+= "DC=" + $domain.Split(".")[$l]
    $l++
    if ($domain.Split(".").Length -ne $l)
    { 
        $dNameOU += ","
        $basePath += ","
    }
}

# The try / catch will create the organizational unit to place the objects in if it does not already exist
Try
{
    Get-ADOrganizationalUnit $dNameOU -ErrorAction Stop | Out-Null
    Write-Debug "Organizational unit with distinguished name $dNameOU found"
}
Catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException]
{ 
    New-ADOrganizationalUnit -Path $basePath -Name (($path.Split("/")[($path.Split("/").Length)-1])) -Description "OU for dot1x shadow objects" -Confirm:$false
}
    
# Instantiate list and fill with computer objects from the designated organizational unit
$objsInOU = [System.Collections.ArrayList]::new()
$objsInOU = (Get-ADObject -SearchBase $dNameOU -Filter {ObjectClass -eq "computer" }).Name

# Instantiate list of certificate Common Names
$certsCN = [System.Collections.ArrayList]::new()

foreach ($cert in $Result) {
    try {
        # Split certificate Common Name to remove domain extension to use in upcoming if-else statement
        $objName = ($cert.CommonName).Split('.')[0]
        
        # Check if $objName (CN without domain extension) exists in designated organizational unit
        if ( $objsInOU -notcontains $objName ) {
            
            # If the issued certificate Common Name does not match with objects in the OU, check for the object's existence elsewhere in the directory
            # Use try/catch to avoid error output when the cmdlet fails to find an object
            try { $objFound = Get-ADComputer -Identity $objName } catch { Write-Host "Object with name $objName will be created." -ForegroundColor Yellow }

            if ( [System.String]::IsNullOrEmpty($objFound) ) {
                # Builds a service principal names list to be added to the object, required for 802.1x authentication through RADIUS
                # Checks if the certificate Common Name contains a domain extension, otherwise only add the HOST/$objName entry
                if ("HOST/$($cert.CommonName)" -eq "HOST/$objName") { $setSPNs = "HOST/$objName" } else { [array] $setSPNs = "HOST/$($cert.CommonName)", "HOST/$objName" }
        
                # Creates new computer objects with the required SPNs for successful authentication
                New-ADComputer -Server (Get-ADDomain).PDCEmulator -Name $objName -DNSHostName $($cert.CommonName) -Path $dNameOU -ServicePrincipalNames $setSPNs

                # Add certificate Common Name to $objsInOU list which consists of objects found in OU in addition to new objects added during runtime of script
                $objsInOU += $objName

                # Add certificate Common Name to list of CNs
                $certsCN += $cert.CommonName
            }
            else {
                Write-Host "Object with name ``$($objFound.Name)`` already exists $($objFound.DistinguishedName)" -ForegroundColor Red
            }
        }

        # Null variable used in foreach loop to avoid "lingering" values
        $objName  = $null
        $objFound = $null
        $setSPNs  = $null

    }
    catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] { Write-Host "New AD object will be created: $objeName in $dNameOU."}

}

Write-Host "`nList of objects in organizational unit:" -ForegroundColor Yellow
$objsInOU | ForEach-Object { $m++; Write-Host "$m. $_" -ForegroundColor Green }

if (-not [System.String]::IsNullOrEmpty($certsCN) ) {
    $certsCN | ForEach-Object { Write-Host "Certificate with common name: $_ was added as an AD object." -ForegroundColor Green }
}
else {Write-Host "`nNo new computer certificates has been detected." -ForegroundColor Green}