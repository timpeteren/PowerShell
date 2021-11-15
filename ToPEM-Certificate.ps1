# Convert pfx to pem
# Convert DER to BASE64 / PEM

$certFile = "" # could be .pfx or DER
try {
    $der = Get-Content $certFile -encoding Byte
    [System.Convert]::ToBase64String($der) | Set-Clipboard
    $der = $null
}
catch [System.Exception] {
    Write-Host "Failed with error:`n $($_.Exception[-1])"
}

# Import Base64 endcoded certificate string to PowerShell cert object
<# 
    $certBase64 = Read-Host "Paste BASE64 encoded string and press ENTER" | Out-Null
    $certBase64 = 'BASE64ENCODEDSTRINGGOESHERE'
    $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]( [System.Convert]::FromBase64String($certBase64) )
    $cert | Format-List *
#>

# Export public key of certificate from pfx file to WITHOUT storing private key on filesystem
$certPath = "" # Relative or full file system certificate path
$cert = New-Object -TypeName System.Security.Cryptography.X509Certificates.X509Certificate2
$FullPathToCert = Resolve-Path -Path $certPath
# Read password for managing certificate
$Password = Read-Host 'Password' -AsSecureString
$X509KeyStorageFlag = 32
$cert.Import($FullPathToCert, $Password, $X509KeyStorageFlag)
# Put Base64 endcoded certificate public key on clipboard
[System.Convert]::ToBase64String($Cert.RawData) | Set-Clipboard