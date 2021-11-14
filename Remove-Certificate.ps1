# Modify DnsName to the common name of the certificate(s) to be removed
# If DnsName is left empty the script will filter on fqdn (works on AD integrated, not Azure AD joined devices)
# Issuer added to avoid removal of certificates issued by other authorities

$DnsName = ""
if (!($DnsName)) {$DnsName = (Get-ComputerInfo -Property CsDNSHostName).CsDNSHostName}
$CertStore = "LocalMachine" # CurrentUser
$Issuer = "Issuing CA"

$certs = Get-ChildItem -Path Cert:\$CertStore\my\ -DnsName $DnsName | Where-Object {$_.Issuer -match $Issuer}
foreach ($item in $certs) {Remove-Item $item.PSPath -Force -Verbose}