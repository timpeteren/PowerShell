[CmdletBinding()]
Param(
  [Parameter(Mandatory=$False,Position=1)]
   [string]$BackupFolder="c:\CABackups",
   #Specifies the destiniation backup folder

   [Parameter(Mandatory=$False,Position=2)]
   [bool]$ThalesHSM,
   #Determines if Thales HSM Files should be backedup

   [Parameter(Mandatory=$False,Position=3)]
   [bool]$Diagnostic,
   #Enables diagnostic logging

   [Parameter(Mandatory=$False,Position=4)]
   [bool]$EventLogging=$true,
   #Enables Event Log Entries

   [Parameter(Mandatory=$False,Position=5)]
   [bool]$Register
   #Used during install to register the eventlog source
  )


#************************************************************************************
# Scripted by: Mark B. Cooper
#              PKI Solutions Inc.
#              www.pkisolutions.com
#
# Version:     1.3
# Date:        March 16, 2020
#************************************************************************************

function WriteDebugLog ([string]$msg)
{
    $(Get-Date -format 'MM-dd-yy hh:mm:ss') +": " + $msg | Out-File -FilePath $logfile -Append
    if ($Diagnostic)
    {
        Write-Host $msg
    }
}

function WriteEventLog ([string]$msg, [int]$EventID,[bool]$Error)
{
    if ($EventLogging)
    {
        if ($Error)
        {
            Write-EventLog -LogName Application -Source "CABackup" -EventId $EventID -EntryType Error -Message $msg -Category 0
        }
        else
        {
            Write-EventLog -LogName Application -Source "CABackup" -EventId $EventID -EntryType Information -Message $msg -Category 0
        }
    }
}

cls
Set-PSDebug -Trace 0

#Revision and Log detail tracking purposes only
$ScriptVersion="1.0"

#Log and temp files
$logfile = "$BackupFolder\Backup-Log-$(Get-Date -format 'yyyy-MM-dd').log"

if ($Register)
{
    New-EventLog -LogName "Application" -Source "CABackup"
    Exit
}

if (Test-Path $BackupFolder)
{}
else
{
    New-Item $BackupFolder -ItemType Directory | Out-Null
}

WriteDebugLog "Script Starting -Version $ScriptVersion"

Write-Host "Starting Certification Authority Backup..."
WriteEventLog "Starting Certification Authority Backup" 1



WriteDebugLog "Removing Backup Folder Contents"

Remove-Item $BackupFolder\* -Recurse

if(!$?)
{
    WriteDebugLog "Error removing old backup folder contents. Error: " + $error[0]
    Write-Host "Unable to empty the target backup folder. Script is ending"
    WriteEventLog "Unable to empty the target backup folder. Script is ending" 3 $true
    Exit
}

WriteDebugLog "Backup Folder Prepared"

WriteDebugLog "Backing Up CA Database"

Backup-CARoleService -path $BackupFolder -DatabaseOnly
if(!$?)
{
    WriteDebugLog "Error Performing CA Database Backup. Error: " + $error[0]
    Write-Host "Unable to perform CA Database Backup. Script is ending"
    WriteEventLog "Unable to perform CA Database Backup. Script is ending" 4 $true
    Exit
}
WriteDebugLog "CA Database backup completed"

WriteDebugLog "Copying CA Certificates"

Copy-Item C:\CERTSRV\CERTDATA\*.crt $BackupFolder
if(!$?)
{
    WriteDebugLog "Error Copying CA Certificate Files. Error: " + $error[0]
    #Not considered a critical error, so backup will continue
}
else
{
    WriteDebugLog "CA certificates backup completed."
}

WriteDebugLog "Copying CAPolicy.inf"
if (Test-Path $env:windir\capolicy.inf) {
    Copy-Item $env:windir\capolicy.inf $BackupFolder
    if(!$?)
    {
        WriteDebugLog "Error Copying CAPolicy File. Error: " + $error[0]
        #Not considered a critical error, so backup will continue
    }
    else
    {
        WriteDebugLog "CAPolicy.inf backup completed."
    }
}


WriteDebugLog "Exporting CA Registry Configuration"

&'reg.exe' "export" "HKLM\system\currentcontrolset\services\certsvc\configuration" $BackupFolder\caregistry.reg

if ($ThalesHSM)
{
    WriteDebugLog "Backing up Thales HSM Files"
    Copy-Item $env:nfast_kmdata $BackupFolder\HSM -Recurse
    if(!$?)
    {
        WriteDebugLog "Error Copying Thales HSM Files. Error: " + $error[0]
        #Not considered a critical error, so backup will continue
    }
}

WriteDebugLog "Checking CA Type to determine if an Issuing CA"
$activeConfig = get-itemproperty -path "HKLM:\System\CurrentControlSet\Services\CertSvc\configuration" -Name active
$activeConfig = $activeConfig.Active
$CAType = get-itemproperty -path HKLM:\System\CurrentControlSet\Services\CertSvc\configuration\$activeConfig -Name CAType
if ($CAType.CAType -eq "1")
{
    WriteDebugLog "CA is an Issuing CA - Dumping list of templates"
    certutil -catemplates > $BackupFolder\CATemplates.txt
}

WriteDebugLog "Backup Completed."
Write-Host "Certification Authority Backup COMPLETED"
WriteEventLog "Certification Authority Backup COMPLETED" 2

