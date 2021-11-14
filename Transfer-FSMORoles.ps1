# Transfer all five FSMO roles
#
# 23.02.21
# Tim Peter Edstrøm, TietoEVRY
#
# ID	FSMO Role
# 0	    PDC Emulator
# 1	    RID Master
# 2	    Infrastructure Master
# 3     Schema Master
# 4     Domain Naming Master
# 
# FSMO roles are the roles needed to keep an Active Directory environment healthy and running smoothly. There are 5 Flexible Master Operation Roles in total. Here’s what they are and what they do:
#
# PDC Emulator Role
# This role is the most used of all FSMO roles and has the widest range of functions
# The PDC Emulator is the authoritative DC in the domain and the domain source for time synchronization for all other domain controllers
# The PDC Emulator changes passwords, responds to authentication requests and manages Group Policy Objects
#
# RID Master Role (Relative ID)
# The RID Master is the single DC responsible for processing RID Pool requests from all domain controllers within a given domain
# Responds to requests by retrieving RIDs from the domain’s unallocated RID pool and assigns them to the pool of the requesting DC
#
# Infrastructure Master Role
# The Infrastructure Master role is to ensure that cross-domain object references are correctly handled
#
# Schema Master Role
# The Schema Master Role’s purpose is to replicate schema changes to all other domain controllers in the forest
# Typical implementations that involve schema changes are Exchange Server, SCCM, Skype for Business etc.
#
# Domain Naming Master Role
# This role processes all changes to the namespace
# Adding subdomains is an example of Domain Naming Master Role in use
#
# Possible improvements:
#  - Select individual roles to transfer
#

Param(
    # Name of domain controller to receive FSMO roles
    [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
    [string] $DomainController,
    
    # Whether or not to "DryRun"
    [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
    [bool] $DryRun = $true
)

try {
    Write-Host "`nTrying to import ActiveDirectory PowerShell module...`n"
    Import-Module ActiveDirectory -ErrorAction Stop | Out-Null

    if ($DryRun) {
        Write-Host "Dry run triggered (make sure to include -DryRun:`$false to execute`n" -ForegroundColor Yellow
        Move-ADDirectoryServerOperationMasterRole -Identity $DomainController –OperationMasterRole 0, 1, 2, 3, 4 -ErrorAction Stop -WhatIf | Out-Null
    }
    else {
        Write-Host "`nMoving FSMO roles to $DomainController`n" -ForegroundColor Yellow
        Move-ADDirectoryServerOperationMasterRole -Identity $DomainController –OperationMasterRole 0, 1, 2, 3, 4 -Confirm:$false -Force -ErrorAction Stop
        Write-Host "Sleeping for 5 seconds to allow AD to register that the FSMO roles have been relocated"
        Start-Sleep 5
    }

    Write-Host "`nCurrent FSMO roles holder`n" -ForegroundColor Yellow
    Get-ADDomainController -Filter * | Select-Object Name, Domain, Forest, OperationMasterRoles | Where-Object { $_.OperationMasterRoles } | Format-Table -AutoSize
}

catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
    Write-Host "Domain Controller name ($DomainController) can not be found, please try again..." -ForegroundColor Red
}

catch [System.Exception] {
    Write-Host "The ActiveDirectory PowerShell module cannot be loaded, but is required for transferring FSMO roles"
}