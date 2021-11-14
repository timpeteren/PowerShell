# VMware Tools uninstaller and cleanup
#
# Finds VMware Tools in the Uninstall section of either 64-bit or 32-bit HKLM registry hive node
#
# Tries to uninstall VMware Tools using MSIExec which is the preferred way to uninstall the software
# Then checks to see if VMware Tools has been removed from Uninstall
# If software unistall failed a manual cleanup routine will trigger
#
# The cleanup removes VMware Tools specific registry settings based on the OS version of the server
#
# Supports server OS versions 2008 R2, 2021, 2016 / 2019

# List software to uninstall using MSIExec with arguments {"Displayname"="arguments"}
$SoftwareMSI = @{
    "VMware Tools" = "/qn /norestart"
}

# Find UninstallString with msi
Write-Host "`nUninstalling with msi!`n"

foreach ($software in $SoftwareMSI.GetEnumerator()) {
    $uninstall = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" | ForEach-Object { Get-ItemProperty $_.PSPath } | Where-Object { $_.DisplayName -like "*$($software.name)*" } | Select-Object DisplayName, UninstallString, PSPath
    if (-not $uninstall) {
        $uninstall = Get-ChildItem "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall" | ForEach-Object { Get-ItemProperty $_.PSPath } | Where-Object { $_.DisplayName -like "*$($software.name)*" } | Select-Object DisplayName, UninstallString, PSPath
    }
    $MSIGUID = [regex]::match($uninstall.UninstallString, '{([^/)]+)}').groups[1].value
    if ($MSIGUID) {
        Write-Host "[$env:COMPUTERNAME] Uninstalling: $($software.name)" -ForegroundColor Yellow
        # Start the Uninstall using msiexec.exe
        $Arguments = "/x $MSIGUID " + "$($software.value)"
        Start-Process -FilePath "msiexec.exe" -ArgumentList $Arguments -Wait
    }
    Else {
        Write-Host "[$env:COMPUTERNAME] Not Found   : $($software.name)" -ForegroundColor Yellow
        Write-Host "                   - Skipping" -ForegroundColor Cyan
    }
}

#Verify the uninstall by checking if registry entry is removed
if (Get-ItemProperty $uninstall.PSPath -ErrorAction SilentlyContinue ) {
    Write-Host "`nInitiating manual removal by registry cleanup based on OS level`n" -ForegroundColor DarkCyan

    Write-Host "Getting operating system version...`n" -ForegroundColor DarkCyan

    # Stopping running VMware services
    [array]$services = "VGAuthService", "VMTools", "vmvss"
    # $services = Get-Service -DisplayName *VMware*

    # Stop all VMware services
    Get-Service -Name $services -ErrorAction SilentlyContinue | ForEach-Object { Stop-Service $_ -Force -Confirm:$false }

    foreach ($svc in $services) {
        # The try will remove the VMware service from registry if it exists, and the catch will throw a debug log if it does not exist
        Try {
            # Tries to locate the service in the registry and then remove it
            Get-ChildItem -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$svc" -ErrorAction Stop
            Remove-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$svc" -Recurse -Force -Confirm:$false -Verbose
        }
        Catch [System.Management.Automation.ItemNotFoundException] {
            # If the registry hive key does not exist, catch the error and output an error
            Write-Host "Service $svc does not exist in registry."
        }
    }

    # Windows 2016 and Windows 2019 Virtual Machine 
    if ( (Get-WmiObject -Class win32_operatingsystem | Select-Object Caption | Where-Object { $_ -match "Windows Server 2019" }) -or (Get-WmiObject -Class win32_operatingsystem | Select-Object Caption | Where-Object { $_ -match "Windows Server 2016" }) ) {
        [array]$regKeys = @(
            "HKEY_CLASSES_ROOT\Installer\Features\FABCF247D5EE2B84E959AD50317B5907"
            "HKEY_CLASSES_ROOT\Installer\Products\FABCF247D5EE2B84E959AD50317B5907"
            "HKEY_LOCAL_MACHINE\SOFTWARE\Classes\Installer\Features\FABCF247D5EE2B84E959AD50317B5907"
            "HKEY_LOCAL_MACHINE\SOFTWARE\Classes\Installer\Products\FABCF247D5EE2B84E959AD50317B5907"
            "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Products\FABCF247D5EE2B84E959AD50317B5907"
            "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{$MSIGUID}"
            "HKEY_LOCAL_MACHINE\SOFTWARE\VMware, Inc."
        )
    }

    # Windows 2012 Virtual Machine 
    if ($null -eq $regKeys -and (Get-WmiObject -Class win32_operatingsystem | Select-Object Caption | Where-Object { $_ -match "Windows Server 2012" }) ) {
        [array]$regKeys = @(
            "HKEY_CLASSES_ROOT\Installer\Features\B634907914A56494B87EA24A33AC1F80"
            "HKEY_CLASSES_ROOT\Installer\Products\B634907914A56494B87EA24A33AC1F80"
            "HKEY_CLASSES_ROOT\CLSID\{D86ADE52-C4D9-4B98-AA0D-9B0C7F1EBBC8}"
            "HKEY_LOCAL_MACHINE\SOFTWARE\Classes\Installer\Features\B634907914A56494B87EA24A33AC1F80"
            "HKEY_LOCAL_MACHINE\SOFTWARE\Classes\Installer\Products\B634907914A56494B87EA24A33AC1F80"
            "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Products\B634907914A56494B87EA24A33AC1F80"
            "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{9709436B-5A41-4946-8BE7-2AA433CAF108}"
            "HKEY_LOCAL_MACHINE\SOFTWARE\VMware, Inc."
        )
    }

    # Windows 2008 R2 Virtual Machine 
    if ($null -eq $regKeys -and (Get-WmiObject -Class win32_operatingsystem | Select-Object Caption | Where-Object { $_ -match "Windows Server 2008 R2" }) ) {
        [array]$regKeys = @(
            "HKEY_CLASSES_ROOT\Installer\Features\C2A6F2EFE6910124C940B2B12CF170FE"
            "HKEY_CLASSES_ROOT\Installer\Products\C2A6F2EFE6910124C940B2B12CF170FE"
            "HKEY_CLASSES_ROOT\CLSID\{D86ADE52-C4D9-4B98-AA0D-9B0C7F1EBBC8}"
            "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Products\C2A6F2EFE6910124C940B2B12CF170FE"
            "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{FE2F6A2C-196E-4210-9C04-2B1BC21F07EF}"
            "HKEY_LOCAL_MACHINE\SOFTWARE\VMware, Inc."
        )
    }

    foreach ($key in $regKeys) {

        # The try will remove the registry hive key if it exists, and the catch will throw a debug log if it does not exist
        Try {
            # Tries to locate the registry hive key and then removes it
            Get-ChildItem -Path "Registry::$key" -ErrorAction Stop | Out-Null
            Remove-Item -Path "Registry::$key" -Recurse -Force -Confirm:$false -Verbose
        }
        Catch [System.Management.Automation.ItemNotFoundException] {
            # If the registry hive key does not exist, catch the error and output an error
            Write-Host "Registry entry $key does not exist."
        }
    }

    if (Test-Path "C:\Program Files\VMware") {
        #! (Get-ItemProperty -Path 'HKLM:\SOFTWARE\VMware, Inc.\VMware Tools').InstallPath
        Remove-Item -Path "C:\Program Files\VMware" -Recurse -Force -Confirm:$false -ErrorAction Stop -Verbose
        Write-Host "Folder 'C:\Program Files\VMware' has been successfully removed!" -ForegroundColor DarkCyan
    }
    Write-Host "`nThe computer needs a reboot for VMware Tools to be fully removed!`n"  -ForegroundColor DarkCyan
}

if (Get-ItemProperty $uninstall.PSPath -ErrorAction SilentlyContinue ) {
    Write-Host "                   - Removal Failed" -ForegroundColor Red
}
Else {
    Write-Host "                   - Removal Successful" -ForegroundColor Green
}

Write-Host "`nUninstalling $($software.Name) using msi concluded.`n"