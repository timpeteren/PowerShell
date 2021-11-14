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


<# 
    $certBase64 = Read-Host "Paste BASE64 encoded string and press ENTER" | Out-Null
    $certBase64 = 'BASE64ENCODEDSTRINGGOESHERE'
    $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]( [System.Convert]::FromBase64String($certBase64) )
    $cert | Format-List *
#>