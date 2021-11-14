<#
.SYNOPSIS
Create a new PinPoint DNS zone.

.DESCRIPTION
Create a new PinPoint DNS zone and configure secondary/slave servers to host this zone.

.PARAMETER PinPointZone
The FQDN of the new pinpoint zone (FQDN of host you are resolving for).

.PARAMETER PinPointZoneHost
The IP Address of the host you are directing users to.

.PARAMETER PrimaryDnsServer
The Primary DNS Server responsible for hosting the zone. If none is specified, localhost is used.

.PARAMETER SecondaryDnsServers
List of secondary DNS servers to configure.  Servers can be specified as either hostnames or IP addresses.

.EXAMPLE
.\New-PinPointDnsZone.ps1 -PinPointZone my.domain.com -PinPointZoneHost 1.2.3.4 -SecondaryDnsServers @('192.168.0.2','192.168.0.3')

Attempts to create new pinpoint zone my.domain.com with address of 1.2.3.4 on server LOCALHOST and configure 192.168.0.2 and 192.168.0.3 as secondary servers.

.LINK
https://blogs.technet.microsoft.com/undocumentedfeatures/2016/07/07/creating-a-pinpoint-dns-zone/

.LINK
https://gallery.technet.microsoft.com/Create-a-new-PinPoint-DNS-ce98cfc2
#>
[CmdletBinding()]
Param(
	[Parameter(Mandatory=$True,HelpMessage='Name of PinPoint Zone to create')]
		[string]$PinPointZone,
	[Parameter(Mandatory=$True,HelpMessage='IP Address for pinpoint zone host')]
		[ipaddress]$PinPointZoneHost,
	[Parameter(Mandatory=$False,HelpMessage='Primary DNS Server')]
		[string]$PrimaryDnsServer = $env:COMPUTERNAME,
	[Parameter(Mandatory=$False,HelpMessage='Secondary DNS Servers')]
		[array]$SecondaryDnsServers
	)

# Is PrimaryDnsServer a DC?
$DsSetting = (Get-DnsServer -ComputerName $PrimaryDnsServer).ServerSetting.DsAvailable
$ZoneFile = $PinPointZone + ".dns"

# Resolve PrimaryDnsServer to IP Address
$PrimaryDnsServerHost = (Resolve-DnsName $PrimaryDnsServer)
If ($PrimaryDnsServerHost.Type -eq "PTR")
	{
	$PrimaryDnsServerIP = $PrimaryDnsServer
	}
ElseIf ($PrimaryDnsServerHost.Type -eq "A")
	{
	$PrimaryDnsServerIP = $PrimaryDnsServerHost.IpAddress
	}
Write-Host -NoNewline "Primary Dns Server resolves to ";Write-Host -ForegroundColor Green "$($PrimaryDnsServerIP)."

If ($DsSetting -eq $true)
	{
	Write-Host -NoNewline "Creating PinPoint zone ";Write-Host -NoNewLine -ForegroundColor Green "$($PinPointZone) "; Write-Host -NoNewline "on server "; Write-Host -ForegroundColor Green "$($PrimaryDnsServer)."
	Add-DnsServerPrimaryZone -ComputerName $PrimaryDnsServer -Name $PinPointZone -DynamicUpdate None -ReplicationScope Legacy -ZoneFile $ZoneFile
	If (Get-DnsServerZone -ComputerName $PrimaryDnsServer -ZoneName $PinPointZone -ErrorAction SilentlyContinue)
		{
		Write-Host "     Zone created successfully."
		Add-DnsServerResourceRecordA -Name '@' -ComputerName $PrimaryDnsServer -ZoneName $PinPointZone -IPv4Address $PinPointZoneHost
		}
	Else
		{
		Write-Host -ForegroundColor Red "Zone $($PinPointZone) not created successfully."
		Break
		}
	}
Else
	{
	Write-Host -NoNewline "Creating PinPoint zone ";Write-Host -NoNewLine -ForegroundColor Green "$($PinPointZone) "; Write-Host -NoNewline "on server "; Write-Host -ForegroundColor Green "$($PrimaryDnsServer)."
	Add-DnsServerPrimaryZone -ComputerName $PrimaryDnsServer -Name $PinPointZone -DynamicUpdate None -ZoneFile $ZoneFile
	If (Get-DnsServerZone -ComputerName $PrimaryDnsServer -ZoneName $PinPointZone -ErrorAction SilentlyContinue)
		{
		Write-Host "     Zone created successfully."
		Add-DnsServerResourceRecordA -Name '@' -ComputerName $PrimaryDnsServer -ZoneName $PinPointZone -IPv4Address $PinPointZoneHost
		}
	Else
		{
		Write-Host -ForegroundColor Red "Zone $($PinPointZone) not created successfully."
		Break
		}
	}

If ($SecondaryDnsServers)
	{
	[System.Collections.ArrayList]$IPArray = @()
	Write-Host "Resolving Dns Server Names to IP Addresses."
	Foreach ($DnsServer in $SecondaryDnsServers)
		{
		$obj = Resolve-DnsName $DnsServer -ErrorAction SilentlyContinue
		If ($obj.Type -eq "PTR")
			{
			Write-Host -NoNewline "Adding ";Write-Host -NoNewLine -ForegroundColor Green "$($obj) "; Write-Host "to Secondary Dns Server List."
			$IPArray += $obj
			}
		ElseIf ($obj.Type -eq "A")
			{
			Write-Host -NoNewline "Adding ";Write-Host -NoNewLine -ForegroundColor Green "$($obj.IPAddress) "; Write-Host "to Secondary Dns Server List."
			$IPArray += $obj.IPAddress
			}
		Else
			{
			Write-Host -ForegroundColor Yellow "Object $($DnsServer) not found.  Removing from input list."
            $IPArray = $IPArray -notmatch $DnsServer
            $SecondaryDnsServers = $SecondaryDnsSErvers -notmatch $DnsServer
			}
		}
	
	[array]$IPArray = $IPArray | Sort -Unique
	
	# Adding Dns Servers as Secondaries to Zone
	If ($IPArray.Count -ge 1)
		{
        $IPArrayCount = $IPArray.Count
		Write-Host "Preparing to add $IPArrayCount Dns Servers as secondaries to $($PinPointZone)."
		Set-DnsServerPrimaryZone -ZoneName $PinPointZone -ComputerName $PrimaryDnsServer -SecondaryServers $IPArray -SecureSecondaries TransferToSecureServers
		}
	
	Foreach ($DnsServer in $SecondaryDnsServers)
		{
		Write-Host -NoNewline "Attempting to add secondary zone to server ";Write-Host -NoNewline -ForegroundColor Green "$($DnsServer)."
        Try
            {
            Add-DnsServerSecondaryZone -ZoneName $PinPointZone -ComputerName $DnsServer -MasterServers $PrimaryDnsServerIP -ZoneFile $ZoneFile
            If (Get-DnsServerZone -ComputerName $DnsServer -Name $PinPointZone -ea SilentlyContinue )
                {
                Write-Host -ForegroundColor Green "     Zone successfully created on server $($DnsServer)."
                }
            Else
                {
                Write-Host -ForegroundColor Yellow "     Zone was not successfully detected on $($DnsServer)."
                }
            }
        Catch
            {
            Write-Host -ForegroundColor Red "     Unable to create zone on server $($DnsServer).  Error: $($Error.CategoryInfo.Category)"
            }
        Finally
            {
            }
        $Error.Clear()
		}
	}
Else
	{
	Write-Host "PinPoint Zone creation complete."
	}	