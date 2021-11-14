<#
.SYNOPSIS

Grants the NETWORK SERVICE read access to a certificate's private key.

.DESCRIPTION
In order for HTTPS to work in ASP.Net Core, an SSL certificate must be installed and readable by NETWORK SERVICE
account.
The SSL certificate is obtained from KeyVault and installed into the VM Scale Set by our ARM template. However,
the certificate is protected by a private key. The default permissions (ACLs) on the imported certificate are
insufficient for an ASP.Net Core application running in Service Fabric. This script grants the
"NT AUTHORITY\NETWORK SERVICE" account read-only access to the private key of a given certificate which is
sufficient for ASP.Net Core (Kestrel) to use it for HTTPS communication.
#>

param(
    [Parameter(Mandatory=$true)][string] $Thumbprint
)

Write-Host "Updating certificate access."

$store = New-Object System.Security.Cryptography.X509Certificates.X509Store(
    [System.Security.Cryptography.X509Certificates.StoreName]::My,
    [System.Security.Cryptography.X509Certificates.StoreLocation]::LocalMachine
    )

try
{
    $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly)

    try
    {
        $cert = $store.Certificates | where {$_.Thumbprint -eq $Thumbprint}

        if ($cert -eq $null)
        {
            Write-Error "Cannot find the certificate with thumbprint $Thumbprint"
            exit
        }

        $rsa = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($cert)
        $key = $rsa.Key

        # 0x44 = DACL_SECURITY_INFORMATION | NCRYPT_SILENT_FLAG
        $daclPropertyOptions = [System.Security.Cryptography.CngPropertyOptions]0x44
        $daclProperty = $key.GetProperty("Security Descr", $daclPropertyOptions)

        $securityDescriptor = New-Object System.Security.AccessControl.RawSecurityDescriptor($daclProperty.GetValue(), 0);

        # Find existing NETWORK SERVICE Access control (ACE)
        $existingNetworkServiceAce = $securityDescriptor.DiscretionaryAcl | where {$_.SecurityIdentifier.IsWellKnown([System.Security.Principal.WellKnownSidType]::NetworkServiceSid)}

        $desiredAccessMask = [System.Security.AccessControl.CryptoKeyRights]::GenericRead -bor
                     [System.Security.AccessControl.CryptoKeyRights]::Synchronize -bor
                     [System.Security.AccessControl.CryptoKeyRights]::ReadPermissions -bor
                     [System.Security.AccessControl.CryptoKeyRights]::ReadAttributes -bor
                     [System.Security.AccessControl.CryptoKeyRights]::ReadExtendedAttributes -bor
                     [System.Security.AccessControl.CryptoKeyRights]::ReadData

        if ($existingNetworkServiceAce -ne $null)
        {
            # Verify access mask
            if ($existingNetworkServiceAce.AceQualifier -ne [System.Security.AccessControl.AceQualifier]::AccessAllowed)
            {
                Write-Host "NETWORK SERVICE already has an entry, but it is not 'Access Allowed'."
                # This would be dangerous to try and fix
                exit
            }

            $updatedAccessMask = $existingNetworkServiceAce.AccessMask -bor $desiredAccessMask
            if ($updatedAccessMask -eq $existingNetworkServiceAce.AccessMask)
            {
                Write-Host "NETWORK SERVICE already has read access"
                exit
            }
            else
            {
              Write-Host "Adding Read access to NETWORK SERVICE"
              $existingNetworkServiceAce.AccessMask = $updatedAccessMask
            }
        }
        else
        {
          Write-Host "Adding NETWORK SERVICE to the access control list with Allow Read access"
          # Create a new ACE
          $networkServiceIdentifier = New-Object System.Security.Principal.SecurityIdentifier([System.Security.Principal.WellKnownSidType]::NetworkServiceSid, $null)
          $ace = New-Object System.Security.AccessControl.CommonAce(
                [System.Security.AccessControl.AceFlags]::None,
                [System.Security.AccessControl.AceQualifier]::AccessAllowed,
                $desiredAccessMask,
                $networkServiceIdentifier,
                $false,
                $null)

          # Add it to the DACL
          $securityDescriptor.DiscretionaryAcl.InsertAce($securityDescriptor.DiscretionaryAcl.Count, $ace)
        }

        # Write the updated DACL back to the CNG key's security descriptor
        $updatedValue = New-Object byte[] $securityDescriptor.BinaryLength
        $securityDescriptor.GetBinaryForm($updatedValue, 0)
        $updatedCngProperty = New-Object System.Security.Cryptography.CngProperty("Security Descr", $updatedValue, $daclPropertyOptions)
        $key.SetProperty($updatedCngProperty)

        Write-Host "Security descriptor updated"
    }
    finally
    {
        $store.Close()
    }
}
catch [System.Security.Cryptography.CryptographicException]
{
    Write-Error "Could not open the Local Machine certificate store. Are you running as administrator?"
} 

