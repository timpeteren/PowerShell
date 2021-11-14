<# 
    ############################################################################
    # Set-CertificateStatus.ps1
    #
    # 11.03.21
    # Tim Peter Edstrøm
    #
    # Apply 'archive' flag to (superseded and or duplicate) certificates
    #
    # Accepts -CertificateOID parameter to search for specific certificates
    #
    # Must be run as administrator to archive certificates in LocalMachine store
    #
    # TODO:
    # Add logging for when script has made any changes
    #   - either event viewer
    #   - file based
    #   - add transcript
    #
    # Experimental!
    # Use parameter -IncludeArchived:$true to also process archived certificates
    # (Not very useful for the current iteration of the script)
    #
    # v0.1: Initial release
    #
    # v0.2: Add -DryRun parameter and set it default to $true
    #
    # v0.3: Fix console output and add foregroundcolor parameter
    #
    # v0.4: Add certificate Subject match USERNAME when certstore is CurrentUser
    #
    #############################################################################
#>

[CmdletBinding()]
param (
    # Default certificate store is LocalMachine
    [Parameter(Mandatory = $false)]
    [string] $CertStore = "LocalMachine",

    # Change to $true to work with certificates that have Status 'Archived'
    [Parameter(Mandatory = $false)]
    [bool] $IncludeArchived = $false,

    # Look for certificate containing a particular OID
    [Parameter(Mandatory = $false)]
    [string] $CertificateOID,

    # DryRun, testrun the script before allowing it to make changes
    [Parameter(Mandatory = $false)]
    [bool] $DryRun = $false
)

# Executing...
$store = New-Object System.Security.Cryptography.X509Certificates.X509Store "My",$CertStore
if ($includeArchived) {
    $store.Open("ReadWrite,IncludeArchived")
} 
else { 
    $store.Open("ReadWrite")
}
		
[System.Security.Cryptography.X509Certificates.X509Certificate2Collection] $certificates = $store.certificates

if ($certificateOID) {
    # When filtering certificates on OID, don't require COMPUTERNAME to match Subject of certificate, sort the list decending, newest first
    $certsSorted = $certificates | Where-Object {($_.EnhancedKeyUsageList).ObjectId -contains $certificateOID} | Sort-Object -Descending
}
else {
    # Match certificate Subject with HOSTNAME or COMPUTER and sort the list descending, most recently issued certificate first in the list
    if ( $CertStore -eq "LocalMachine" ) { $accountName = $env:COMPUTERNAME } else { $accountName = $env:USERNAME }
    $certsSorted = $certificates | Where-Object {$_.Subject -match $accountName } | Sort-Object {$_.NotAfter} -Descending
}

# Apply Status 'Archived' = $true to certificates
# Could add ' |  Where-Object {$_.notAfter -gt (Get-Date) }' to foreach to only process valid (not expired) certificates
foreach ($cert in $certsSorted) {
    # Do not process the first certificate as this is the most recent, and at least one certificate must remain active
    if 	(-not ($cert.Thumbprint -eq $certsSorted[0].Thumbprint) ) {
	    if ($DryRun -eq $true) {
            Write-Host "Would run `$cert.Set_Archived($true) for certificate $($cert | Select-Object subject, thumbprint, notafter)" -ForegroundColor Yellow
        }
        else {
            Write-Host "Setting Status = 'Archived' to certificate $($cert | Select-Object subject, thumbprint, notafter)" -ForegroundColor Yellow
            $cert.Set_Archived($true)
            $archivedNumber++
        }
    }
}
if ($archivedNumber -gt 0) {
    Write-Host "`nNumber of certificates that were archived: $archivedNumber`n" -ForegroundColor Green
    Write-Host "Certificate: " -ForegroundColor Yellow
    $certsSorted[0] | Format-List *
    Write-Host "The following certificate remains active (scroll up to view the complete list of certificate parameters):`n`t$($certsSorted[0] | Select-Object subject, thumbprint, notafter, archived)" -ForegroundColor Green
}

$store.Close()
$accountName, $certificates, $certsSorted, $archivedNumber = $null