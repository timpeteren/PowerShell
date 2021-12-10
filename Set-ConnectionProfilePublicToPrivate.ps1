<#
.SYNOPSIS
    PowerShell script that modifies interface network connection profile
.DESCRIPTION
    Automatic VPN connectivity is in effect when the active interface is set to 'Public'
    For AzureAD-joined devices all network interfaces may be set to 'Public'
    This causes an issue for the TrustedNetworkDetection  parameter which is ignored
    Script will look for an interface with a configured network name
    If the network name is found, check if it is 'Public' and set to 'Private'
.EXAMPLE
    If script doesn't run locally, first run command below (only required once)
    PS C:\> Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
    (If deployed via Intune the above action is not required)

    PS C:\> Set-ConnectionProfilePublicToPrivate.ps1
    Executes the script (remember to set variable prior to execution / deployment)
    If run locally, the script must be run with elevated privileges
.INPUTS
    Input must be defined in the script
    If $networkName variable is not set script exceution will abort
    In the current iteration, input parameter is not supported
.OUTPUTS
    Outputs status to console
    If executed via Intune, script output to registry at the following location:
    HKLM SW MS IntuneManagementExtension Policies <GUIDx> <GUIDy> ResultDetails Value.ExecutionMsg
.NOTES
    Date 10.12.21
    by Tim Peter Edstrøm

    Feel free to re-use and modify to suit your requirements.
#>

# Required
$networkName = ""

# Look for $networkName and if it is empty, abort script
if ( [System.String]::IsNullOrWhiteSpace($networkName) ) {
    Write-Host "Required variable was not set, script is aborting..." -ForegroundColor Yellow
    break;
}

# Register a scheduled task to run for device primary user and execute the script on logon
#region Add scheduled task running on user logon
$psPath = "C:\WINDOWS\System32\WindowsPowerShell\v1.0\PowerShell.exe"
$psCommand= "-ExecutionPolicy Bypass -WindowStyle Hidden -command $([char]34)Get-NetConnectionProfile | Where-Object {`$_.Name -like '*$networkName*'-and `$_.NetworkCategory -eq 'Public'} | Set-NetConnectionProfile -NetworkCategory Private$([char]34)"
$schtaskName = "SetConnectionProfile"
$schtaskDescription = "Add trusted network to Private network category profile list"

# When task will trigger and in what context
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $($env:USERNAME)
# Execute task in users context
$principal = New-ScheduledTaskPrincipal -UserId $($env:USERNAME) -Id "Author" -RunLevel Highest
# Produce the scheduled task action
$action = New-ScheduledTaskAction -Execute $psPath -Argument $psCommand
# Configure additional settings for execution
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
# Register scheduled task
$null = Register-ScheduledTask -TaskName $schtaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description $schtaskDescription -Force
#endregion Add scheduled task running on user logon

#region Run set-networkconnectionprofile once
# Get interface with network connection name like *$networkName*
$interfaceProfile = (Get-NetConnectionProfile | Where-Object {$_.Name -like "*$networkName*"})

# If interface network category is set to 'Public' set it to 'Private'
if ( $interfaceProfile.NetworkCategory -eq "Public" ) {
    Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private
    Write-Host "Interface '$($interfaceProfile.InterfaceAlias)' with name '$($interfaceProfile.Name)' changed network profile from '$($interfaceProfile.NetworkCategory)' to 'Private' (and added scheduled task)" -ForegroundColor Green
}
# If the network interface isn't 'Public' do nothing
else {
    Write-Host "Didn't detect '$($networkName)'. Added scheduled task that will run on user's subsequent logons." -ForegroundColor DarkGreen
}
#endregion Run set-networkconnectionprofile once

$networkName, $interfaceProfile, $psPath, $psCommand, $schtaskName, $schtaskDescription, $principal, $action, $settings = $null