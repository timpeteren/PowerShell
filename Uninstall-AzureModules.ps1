param(
  [Parameter(Mandatory=$true)]
  [string]$Module,

  [switch]$Force
)

Workflow Uninstall-AzureModules
{
  param(
    [Parameter(Mandatory=$true)]
    [string]$Module,

    [switch]$Force
  )
  
    $Modules = (Get-Module -ListAvailable $Module).Name | Get-Unique
    Foreach -parallel ($Module in $Modules)
    {
        Write-Output ("Uninstalling: $Module")
        Uninstall-Module $Module -Force
    }
}
try {
  Uninstall-AzureModules -Module $Module
} catch {
  Write-Host ("`t" + $_.Exception.Message)
}