############################################################################################################
#
# Invoke-GPUpdateGroup.ps1
#
# Run Invoke-Command on computers in a specified AD security group and run gpupdate /force /target:computer
#
#

[CmdletBinding()]
Param
(
    # Name of security group to look for objects
    [Parameter(Mandatory=$true,
            ValueFromPipelineByPropertyName=$true,
            Position=0)]
    [string]
    $Group, # = "acl.gpo.azuremigrated",
     
    # Dry run parameter, set to $true by default
    [bool]
    $DryRun = $true
)

try {
    $members = Get-ADGroupMember -Identity $Group -ErrorAction Stop
    if (-not $DryRun) {
        $members | ForEach-Object {
            Write-Host "`nRunning gpupdate on $($_.name):"
            Invoke-Command -ComputerName $($_.name) -ScriptBlock {gpupdate /force /target:computer}
        } -ErrorAction Stop
    }
    else {
        $members | ForEach-Object {
            Write-Host "`nRunning gpupdate on $($_.name):"
            Write-Host "Dry run active!" -ForegroundColor Yellow
            Write-Host "Invoke-Command -ComputerName $($_.name) -ScriptBlock {gpupdate /force /target:computer}"
        }
    }
}
catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
    Write-Host "`nCouldn't find AD security group ``$Group``. Make sure you have entered the correct name!" -ForegroundColor Red
}
catch [System.Exception] {
    Write-Host "`nWas not able to successfully run ``gpupdate /force on computer: $($_.name)``" -ForegroundColor Yellow
}

# Cleaning up variables used while executing
$Group, $DryRun, $members = $null