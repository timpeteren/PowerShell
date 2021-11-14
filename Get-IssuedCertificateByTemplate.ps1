
Get-WindowsFeature -name RSAT-AD-Powershell -ErrorAction Stop

# Fill in $domain and $domainDName values manually should you so prefer
$domain = (Get-ADDomain).DNSRoot
# Canonical name format (and OU order) and NOT distinguished name order
$path = "Organization/Datamaskiner/dot1x"
# Certificate authority servername (ONLY) WITHOUT domain, which is added from the $domain variable
$serverName = ""
# Certificate authority name, cant be found by runnning "certutil -ping" on CA server, by opening Certification Authority management console
$certificateAuthorityName = ""
$certificateAuthorityFQDN = "$serverName.$domain\$certificateAuthorityName"
# Sets $domainDName based on $domain name
$domainDName = $null
$k = 0 ; while ($k -lt $domain.Split(".").Length) {$domainDName += "DC=" + $($domain.Split("."))[$k] ; $k++ ; if ($k -lt $domain.Split(".").Length) {$domainDName += ","}}
# Certificate template DISPLAY name (including spaces if template contains any)
$templDName = ""
$templ = ActiveDirectory\Get-ADObject -SearchBase "CN=OID,CN=Public Key Services,CN=Services,CN=Configuration,$domainDName" -Filter * -Properties * | Where-Object {$_.DisplayName -like $templDName}

# Override for v1 templates for example 'User' 'Computer' 'Web Server' built-in templates which are addressed by name and not OID
if (-not ([System.String]::IsNullOrWhiteSpace($templ))) {
    $templOID = $templ.'msPKI-Cert-Template-OID'
    }
else {
    $templOID = $templDName
}

# Finds all certificates that have not yet expired, are in the issued certificates list and is issued from the certificate template entered above
$Data = certutil -config $certificateAuthorityFQDN -view -restrict "Disposition=20,Certificatetemplate=$templOID,Certificate Expiration Date>now" -out "Issued Common Name, Certificate Hash, Certificate Effective Date, Certificate Expiration Date, SerialNumber" | findstr "Name: Hash: Date:"

[System.Collections.ArrayList]$Result = @()

for ($i = 0; $i -lt $($Data.Count); $i++) {
    # Create custom object and applicable properties
    # $DateTemplate = 'dd.MM.yyyy HH.mm' 

    if ($i % 4 -eq 0) {
        $T1 = ($Data[$i+2].Split(":")[-1])
        $T2 = ($Data[$i+3].Split(":")[-1])
    
        $IssueDate = [DateTime]::Parse((Get-Date $T1),[CultureInfo]::InvariantCulture)
        $Expirationdate = [DateTime]::Parse((Get-Date $T2),[CultureInfo]::InvariantCulture) 

        $CertObject = New-Object -TypeName PSObject
        # Split on comma, remove double quotes, trim any leading (and trailing) space(s)
        Add-Member -InputObject $CertObject -MemberType NoteProperty -Name "CommonName" -Value (($Data[$i].Split(":")[-1]).Replace("`"","")).Trim()
        Add-Member -InputObject $CertObject -MemberType NoteProperty -Name "Hash" -Value (($Data[$i+1].Split(":")[-1]).Replace("`"","")).Replace(" ","")
        Add-Member -InputObject $CertObject -MemberType NoteProperty -Name "IssueDate" -Value $IssueDate 
        Add-Member -InputObject $CertObject -MemberType NoteProperty -Name "ExpirationDate" -Value $Expirationdate 

        # Check and discard empty values
        if ($CertObject.CommonName -notmatch "EMPTY" -and $CertObject.Hash -notmatch "EMPTY") {
            # Add new custom object to collection
			$Result.Add($CertObject) | Out-Null # Redirect output to null to avoid console log of index
        }
    }
}

$Result
foreach ($cert in $Result) {Write-Output $cert.CommonName}

$Result | Out-GridView

$Result | Export-Csv C:\Temp\$templDName-mal.csv 
