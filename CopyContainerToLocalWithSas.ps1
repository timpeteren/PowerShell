<#

Assumptions:
* Know the directory the PowerShell script (attached file) is located under e.g C:\users\<username>\desktop\scripts\storage
* Know the destination, e.g you want blobs to be stored in a directory named "blobs" under C:\VPP
* Have AzCopy installed to the default location (C:\Program Files (x86)\Microsoft SDKs\Azure\AzCopy) (configurable via -AZCopyPath parameter)
* Have a container SAS link

Variables: 
-StorageResourceGroup => The resource group name with the source blobs, laerdalweb-uat in the above example
-StorageAccountName => The storage account, e.g laerdalwebgrvor4hoezuw6
-ContainerName => Episerver blobs are currently stored under a folder called mysitemedia
-SasUri => The querystring part of a generated SAS link. Generating from Storage Explorer will give a such link
-Destination => A local folder that you have access to

#>

param(
    [Parameter(Mandatory=$true)]
    [string] $StorageResourceGroup,

    [Parameter(Mandatory=$true)]
    [string] $StorageAccountName,

    [Parameter(Mandatory=$true)]
    [string] $ContainerName,

    [Parameter(Mandatory=$true)]
    [string] $SasUri,

    [Parameter(Mandatory=$true)]
    [string] $DestinationPath,

    [string] $AZCopyPath = 'C:\Program Files (x86)\Microsoft SDKs\Azure\AzCopy\AzCopy.exe'
)
try {

    $StartTime = Get-Date

    $Arg1 = '/Source:"https://' + $StorageAccountName + '.blob.core.windows.net/' + $ContainerName + '"'
    Write-Output $Arg1

    $Arg2 = '/Dest:"' + $DestinationPath + '"'
    Write-Output $Arg2
    
    $Arg3 = '/SourceSAS:"' + $SasUri + '"'
    Write-Output $Arg3
    
    $Arg4 = '/S'
    $Arg5 = '/Y'
    $Arg5 = '/XO'
    $Arg7 = '/XN'
    
    & $AZCopyPath $Arg1 $Arg2 $Arg3 $Arg4 $Arg5 $Arg6 $Arg7
}
catch {
    throw
}
finally {
    $elapsedTime = New-Timespan $StartTime $(Get-Date)
    Write-Output ("Completed in {0:hh} hours, {0:mm} minutes, {0:ss} seconds" -f $elapsedTime)
}