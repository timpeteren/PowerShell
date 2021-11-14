# Run Script as admin to update CRL and copy base64-encoded contents of .crl to clipboard for transfer

if (-not ([Security.Principal.WindowsIdentity]::GetCurrent().Groups -contains 'S-1-5-32-544') ) {
    Write-Host "`nRun PowerShell as admin.`n" -ForegroundColor Red; return;
}
else {
    Set-Location C:\CERTSRV\CERTDATA
    certutil -CRL
    certutil -f -encodehex "Root CA.crl" .\RootCACrl.pem 9
    Get-Content .\RootCACrl.pem | Set-Clipboard
    Remove-Item .\RootCACrl.pem -Force
}
