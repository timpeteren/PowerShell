# Hyper-V
Get-VM | Start-VM -Passthru
.\vmconnect.exe localhost (Get-VM).Name # (/ $vm.name)

# "Sleep" VM
Get-VM | Save-VM -Verbose
Get-VM | Where-Object {$_.State -eq "Saved"} | Start-VM -Verbose

# "Pause" VM
Get-VM | Suspend-VM -Verbose
Get-VM | Where-Object {$_.State -eq "Paused"} | Resume-VM -Verbose

# Create checkpoint (snapshot)
Checkpoint-VM -ComputerName localhost -Name (get-vm).name -SnapshotName AZVPNClient

# VM host, find "Default Switch" IP address
(Get-NetIPAddress -InterfaceAlias "vethernet (default switch)" -AddressFamily IPv4).IPAddress
172.18.112.1

# VM guest, remove existing ip address and default gateway
Get-NetAdapter | Foreach-Object {Remove-NetIPAddress -InterfaceAlias $_.ifAlias -DefaultGateway (Get-NetRoute -InterfaceAlias $_.ifAlias -AddressFamily IPv4 | Where-Object {$_.NextHop -ne "0.0.0.0" -and $_.DestinationPrefix -eq "0.0.0.0/0"}).NextHop -Confirm:$false}
$vmHostIpBlocks = "172.25.32."
$vmHostIpGw = "1"
$vmGuestIp = "123"
Get-NetAdapter | Foreach-Object {New-NetIPAddress -InterfaceAlias $_.ifAlias -AddressFamily IPv4 -IPAddress ($vmHostIpBlocks + $vmGuestIp) -PrefixLength 24 -DefaultGateway ($vmHostIpBlocks + $vmHostIpGw) -Confirm:$false}


# Additional commands

#Set-NetIPInterface -InterfaceAlias Ethernet -Dhcp Enabled
 
# Get-NetIPConfiguration | Where-Object {((Get-NetAdapter).ifAlias -eq $_.InterfaceAlias)} | foreach ipv4defaultgateway

# Set-NetIPAddress -InterfaceIndex 11 -IPAddress 192.168.80.2 -AddressFamily IPv4 -PrefixLength 24
# Remove-NetIPAddress -InterfaceIndex 11 -DefaultGateway 192.168.80.1 -Confirm:$false
# Get-NetAdapter | Foreach-Object {New-NetIPAddress -InterfaceAlias $_.ifAlias -AddressFamily IPv4 -IPAddress $($vmHostIpBlocks$vmGuestIp) -PrefixLength 24 -DefaultGateway $($vmHostIpBlocks + "1") -Confirm:$false}

# Discover default (null) routes
# Get-NetRoute |
# 	where {$_.DestinationPrefix -eq '0.0.0.0/0'} |
# 	select { $_.NextHop }

# $gwInterfaces.InterfaceIndex / .InterfaceAlias
	
# $gwInterfaces = Get-NetRoute | Where {$_.DestinationPrefix -eq '0.0.0.0/0'}
# $gwInterfaces | Foreach-Object {Remove-NetIPAddress -InterfaceIndex $_.InterfaceIndex -DefaultGateway $_.NextHop -Confirm:$false}