<#
.SYNOPSIS
    This script performs the installation or uninstallation of the Sysinternals Suite.
.DESCRIPTION
    The script is provided as a template to perform an install or uninstall of an application(s).
    The script requires either -Install:$true -Uninstall:$true parameter to be proviede.
    Optionally the -InstallPath parameter can also be provided

.PARAMETER DeploymentType
    The type of deployment to perform. Default is: Install.

.EXAMPLE
    PowerShell.exe .\Deploy-SysinternalsSuite.ps1 -Install:$true -InstallPath <full directory path>

.NOTES

.LINK

#>
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $true)]
    [ValidateSet("Install", "Uninstall")]
    [string]$DeploymentType = "Install",
    [Parameter(Mandatory = $false)]
    [string]$InstallPath = "$($env:USERPROFILE)/Documents/SysinternalsSuite"
)

Try {
    If ($DeploymentType -eq "Install") {

        ##*===============================================
        ##* INSTALLATION
        ##*===============================================

        # Close Sysinternals Suite Applications With a 60 Second Countdown Before Automatically Closing
        $appList = "accesschk,accesschk64,AccessEnum,ADExplorer,ADExplorer64,ADInsight,ADInsight64,adrestore,adrestore64,`
                    Autologon,Autologon64,Autoruns,Autoruns64,autorunsc,autorunsc64,Bginfo,Bginfo64,Cacheset,Cacheset64,`
                    Clockres,Clockres64,Contig,Contig64,Coreinfo,Coreinfo64,CPUSTRES,CPUSTRES64,ctrl2cap,Dbgview,dbgview64,`
                    Desktops,Desktops64,disk2vhd,disk2vhd64,diskext,diskext64,Diskmon,Diskmon64,DiskView,DiskView64,du,du64,`
                    efsdump,FindLinks,FindLinks64,handle,handle64,hex2dec,hex2dec64,junction,junction64,ldmdump,Listdlls,Listdlls64,`
                    livekd,livekd64,LoadOrd,LoadOrd64,LoadOrdC,LoadOrdC64,logonsessions,logonsessions64,movefile,movefile64,`
                    notmyfault,notmyfault64,notmyfaultc,notmyfaultc64,ntfsinfo,ntfsinfo64,pendmoves,pendmoves64,pipelist,pipelist64,`
                    portmon,procdump,procdump64,procexp,procexp64,Procmon,Procmon64,psfile,psfile64,PsGetsid,PsGetsid64,PsInfo,PsInfo64,`
                    pskill,pskill64,pslist,pslist64,PsLoggedon,PsLoggedon64,psloglist,psloglist64,pspasswd,pspasswd64,psping,psping64,`
                    PsService,PsService64,psshutdown,psshutdown64,pssuspend,pssuspend64,RAMMap,RDCMan,RegDelNull,RegDelNull64,regjump,`
                    ru,ru64,sdelete,sdelete64,ShareEnum,ShareEnum64,ShellRunas,sigcheck,sigcheck64,streams,streams64,strings,strings64,`
                    sync,sync64,Sysmon,Sysmon64,tcpvcon,tcpvcon64,tcpview,tcpview64,Testlimit,Testlimit64,vmmap,vmmap64,Volumeid,Volumeid64,`
                    whois,whois64,Winobj,Winobj64,ZoomIt,ZoomIt64"
        
        # -CloseAppsCountdown 60

        ## Possible implement
        # Show-InstallationProgress

        ## Install Sysinternals Suite
        $ZipPath = Get-ChildItem -Path "$dirFiles" -Include SysinternalsSuite.zip -File -Recurse -ErrorAction SilentlyContinue
        If ($ZipPath.Exists) {
            Write-Host "Installing the Sysinternals Suite. This may take some time. Please wait..."

            Expand-Archive -Path $ZipPath -DestinationPath $InstallPath -Force
            #-Verbose *>&1 | Out-String | Write-Log
            Start-Sleep -Seconds 5

            ## Suppress Sysinternals Suite EULAs
            Write-Host -Message "Suppressing Sysinternals Suite EULAs."

            [scriptblock]$HKCURegistrySettings = {
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\AccessChk' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\AccessEnum' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\Active Directory Explorer' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\ADInsight' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\ADRestore' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\Autologon' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\AutoRuns' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\BGInfo' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\CacheSet' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\ClockRes' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\Contig' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\Coreinfo' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\CPUSTRES' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\Ctrl2cap' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\DbgView' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\Desktops' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\Disk2Vhd' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\DiskExt' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\Diskmon' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\DiskView' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\Du' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\EFSDump' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\FindLinks' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\Handle' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\Hex2Dec' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\Junction' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\LdmDump' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\ListDLLs' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\LiveKd' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\LoadOrder' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\LogonSessions' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\Movefile' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\NotMyFault' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\NTFSInfo' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\PageDefrag' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\PendMove' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\PipeList' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\Portmon' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\ProcDump' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\Process Explorer' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\Process Monitor' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\PsExec' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\psfile' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\PsGetSid' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\PsInfo' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\PsKill' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\PsList' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\PsLoggedon' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\PsLoglist' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\PsPasswd' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\PsPing' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\PsService' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\PsShutdown' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\PsSuspend' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\RamMap' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\RegDelNull' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\Regjump' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\Regsize' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\RootkitRevealer' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\SDelete' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\Share Enum' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\ShellRunas' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\SigCheck' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\Streams' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\Strings' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\Sync' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\System Monitor' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\TCPView' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\VMMap' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\VolumeID' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\Whois' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\Winobj' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
                Set-RegistryKey -Key 'HKCU\Software\Sysinternals\ZoomIt' -Name 'EulaAccepted' -Value 1 -Type DWord -SID $UserProfile.SID
            }

            ## Create Sysinternals Suite Desktop Shortcut
            If (Test-Path -Path $InstallPath) {
        
                $TargetFile = "$($env:USERPROFILE)/Desktop"
                $ShortcutFile = "$($env:USERPROFILE)/AppData/Roaming/Microsoft/Windows/Start Menu/Programs/Sysinternals.lnk"
                $WScriptShell = New-Object -ComObject WScript.Shell
                $Shortcut = $WScriptShell.CreateShortcut($ShortcutFile)
                $Shortcut.TargetPath = $TargetFile
                $Shortcut.Save()
            }
        }
    }
    else {
        # Indicate the application that is being uninstalled)
        # Show-InstallationProgress -StatusMessage "Uninstalling the $installTitle Applications. Please Wait..."

        ##*===============================================
        ##* UNINSTALLATION
        ##*===============================================

        # Remove Sysinternals Start Menu Shortcut (If Present)
        If (Test-Path -Path "$($env:USERPROFILE)/AppData/Roaming/Microsoft/Windows/Start Menu/Programs") {
            Remove-Item -Path "$($env:USERPROFILE)/AppData/Roaming/Microsoft/Windows/Start Menu/Programs" -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 5
        }

        # Remove Sysinternals Suite (If Present)
        If (Test-Path -Path $InstallPath) {
            Remove-Folder -Path "$env:ProgramFiles\Sysinternals\" -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 5 
        }
    }
}
Catch {
    Write-Error -Message $_.Message
}