<# 

.SYNOPSIS
Unmaps network drives

.DESCRIPTION
Unmapdrives removes all currently mapped network drives. It's smart enough to remove drives mapped with "net use", "New-SmbMapping" and "New-PSDrive". This cmdlet accepts no parameters and assumes -Force for all unmappings.

.EXAMPLE
UnMapDrives Unmaps all currently mapped network drives

.NOTES
Author: Charlie Russel Copyright: 2015 by Charlie Russel

: Permission to use is granted but attribution is appreciated Initial: 06/27/2015 (cpr) ModHist: :

#> 

[CmdletBinding()] 
# Build a dynamic list of currently mapped drives
$DriveList = Get-WMIObject Win32_LogicalDisk ` | Where-Object { $_.DriveType -eq 4 }

# Don't bother running this if we don't have any mapped drives 
if ($DriveList) {
    $SmbDriveList = $DriveList.DeviceID
} 
else {
    Write-Host "No mapped drives found"
    Return
}

Write-host "Unmapping drive: " -NoNewLine
Write-Host $SmbDriveList
Write-Host " "

Foreach ($drive in $SmbDriveList) {
    # Remove unwanted colon from PSDrive name
    $psDrive = $drive -replace ":" 
    Remove-SmbMapping -LocalPath $Drive -Force -UpdateProfile
    If ( (Get-PSDrive -Name $psDrive) ) {
        Remove-PSDrive -Name $psDrive -Force
    } 
}
Write-Host " " 

# Report back all FileSystem drives to confirm that only local drives are present.
Get-PSDrive -PSProvider FileSystem