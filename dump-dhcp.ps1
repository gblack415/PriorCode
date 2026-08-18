###############################################################################
# Description: Given IP or DNS, find dhcp leases and reservations
# 04/01/22 glb created
# 01/27/23 glb got it to work
# 02/15/23 glb added AD
# 04/22/24 glb added dhcp name search
# 09/10/24 glb cleaned up post dhcp splits
# 11/04/24 glb added outfile
# TO DO AUTOMATICALLY CHECK FOR A -RSM ON PHYSICAL SERVERS
###############################################################################
$global:ScopeId=""
$global:SubnetMask=""
$global:ScopeName=""
$global:DhcpServer=""
$global:DnsServer=""
$global:IPAddress=""
$global:SkipList="|dhcp.yahoo.com|"
$global:FileName=""
#$global:OverrideIPAddress=""
function Search-Scope {
    param (
        $Server,
        $IpAddress,
		$ComputerName
    )
	
	#$IpAddress -ne "" -and $IpAddress -ne $null
	if(![string]::IsNullOrEmpty($IpAddress) -ne "")
	{
		try
		{
			"Trying {0} on {1}" -f $IpAddress,$Server
			#DMZ ranges are disabled
			#$Scope = Get-DhcpServerv4Scope -ComputerName $Server | where state -eq "active" | where-object {$_.ScopeId -eq ($IpAddress.address -band ([ipaddress]$_.SubnetMask).address)} | Select-Object -Property ScopeId, SubnetMask, Name		
			$Scope = Get-DhcpServerv4Scope -ComputerName $Server | where-object {$_.ScopeId -eq ($IpAddress.address -band ([ipaddress]$_.SubnetMask).address)} | Select-Object -Property ScopeId, SubnetMask, Name		
			if (![string]::IsNullOrEmpty($Scope) -ne "")
			{
				$global:ScopeId=$Scope.ScopeId.IpAddressToString
				$global:SubnetMask=$Scope.SubnetMask.IpAddressToString
				$global:ScopeName=$Scope.Name
				$global:DhcpServer=$Server.ToUpper() -replace '\..*',''
			}
		}
		catch
		{
			"No Matches"
			$_
		}
	}
	else
	{
		try
		{
			$SearchName=-join($ComputerName,"*")
			"Trying {0} on {1}" -f $ComputerName,$Server
			#(Get-DhcpServerv4Lease -ComputerName $global:DhcpServer -ScopeId $global:ScopeId | where hostname -match $ComputerName | FT ipaddress,hostname,clientid,addressstate | Out-String).Trim() 
			#$Scope = Get-DhcpServerv4Scope -ComputerName $Server | where hostname -match $ComputerName | Select-Object -Property ScopeId,IPAddress, Name		
			#$Scope = Get-DhcpServerv4Scope -ComputerName phsscdc1  | Get-DhcpServerv4Reservation -ComputerName phsscdc1 | where Name -like "PHEECTXSSCPV3A*"
			$Scope = Get-DhcpServerv4Scope -ComputerName $Server | Get-DhcpServerv4Reservation -ComputerName $Server | where Name -like $SearchName
			if (![string]::IsNullOrEmpty($Scope) -ne "")
			{
				$global:ScopeId=$Scope.ScopeId.IpAddressToString
				$global:SubnetMask=""
				$global:IPAddress=$Scope.IPAddress
				$global:ScopeName=$Scope.Name
				$global:DhcpServer=$Server.ToUpper() -replace '\..*',''
			}
		}
		catch
		{
			"No Matches"
			$_
		}
		
	}
	"-------------------------------------------------------------------------------"
}

function Full-Report{
	    param (
        $ComputerName
		)
		
	$global:ScopeId=""
	$global:SubnetMask=""
	$global:ScopeName=""
	$global:DhcpServer=""
	$global:DnsServer=""
	$global:IPAddress=""
	"Workstation: {0}" -f $ComputerName
	$host.ui.RawUI.WindowTitle = "Checking DHCP Records for $($ComputerName)"
	$IpRegex = "^([1-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])(\.([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])){3}$"
	if ( $ComputerName -match $IpRegex)
	{
		"Got an IP, Trying to Get DNS Name"
		$IpAddress = $ComputerName	
		try
		{
			$ComputerName = [system.net.dns]::gethostentry($IpAddress).HostName.ToUpper() -replace '\..*',''
		}
		catch
		{
			"No DNS Name"
		}

	}
	else
	{
		"Got a name, get a DNS IP"
		$IpAddress = ""
		try
		{
			$IpAddress = [System.Net.Dns]::GetHostAddresses($ComputerName).IPAddressToString
		}
		catch
		{
			"No DNS IP"
		}
	}
	#if ($IpAddress -ne "0.0.0.0")
	#{
		"Workstation Address: {0}" -f $IpAddress
		if ( $IpAddress -ne "")
		{
			$SearchIp =  ([ipaddress]$IpAddress)
		}

		"Yahoo"
		Search-Scope -Server yahoodhcp -IpAddress $SearchIp -ComputerName $ComputerName

		if($global:ScopeId  -eq "")
		{
			
			Write-Host "Searching All Servers" -ForegroundColor Red
			$DCList = Get-DhcpServerInDC  | Select-Object DnsName
			foreach ($dc in $DCList)
			{
				if( $SkipList -notlike "*|$($dc.DnsName)|*" )
				{
					"Server: {0}" -f $dc.DnsName
					Search-Scope -Server $dc.DnsName -IpAddress $SearchIp -ComputerName $ComputerName
					if($global:ScopeId -ne "")
					{
						break
					}
				}
				else
				{
					"Skipping Server: {0}" -f $dc.DnsName
				}
			}

		}
	#}
	#$global:FileName=".\$($ComputerName)-{(Get-Date -format yyyyMMdd)}.txt"
	$global:FileName=".\{0}-{1}.txt" -f $ComputerName,(Get-Date -format yyyyMMdd)
	#if ($args.count -eq 1 -and Test-Path -Path $args[0] -PathType leaf)
	#{
	#	"Filename: {0}" -f $args[0] | Out-File -FilePath $global:FileName -Append 
	#}
	Get-Date -format yyyy-MM-ddTHH:mm:ss | Out-File -FilePath $global:FileName -Append
	"==============================================================================="
	"===============================================================================" | Out-File -FilePath $global:FileName -Append
	dsquery computer -name $ComputerName
	dsquery computer -name $ComputerName | Out-File -FilePath $global:FileName -Append
	"==============================================================================="
	"===============================================================================" | Out-File -FilePath $global:FileName -Append
	"Workstation: {0}" -f $ComputerName.toupper()
	"Workstation: {0}" -f $ComputerName.toupper() | Out-File -FilePath $global:FileName -Append 
	"Workstation DNS Address: {0}" -f $IpAddress
	"Workstation DNS Address: {0}" -f $IpAddress | Out-File -FilePath $global:FileName -Append
	"Workstation DHCP Address: {0}" -f $global:IPAddress
	"Workstation DHCP Address: {0}" -f $global:IPAddress | Out-File -FilePath $global:FileName -Append
	"DHCP Server: {0}" -f $global:DhcpServer
	"DHCP Server: {0}" -f $global:DhcpServer | Out-File -FilePath $global:FileName -Append
	"Scope Name: {0}" -f $global:ScopeName
	"Scope Name: {0}" -f $global:ScopeName | Out-File -FilePath $global:FileName -Append
	"Scope Id: {0}" -f $global:ScopeId
	"Scope Id: {0}" -f $global:ScopeId | Out-File -FilePath $global:FileName -Append
	"Subnet Mask: {0}" -f $global:SubnetMask
	"Subnet Mask: {0}" -f $global:SubnetMask | Out-File -FilePath $global:FileName -Append
	"-------------------------------------------------------------------------------"
	"-------------------------------------------------------------------------------" | Out-File -FilePath $global:FileName -Append

	if($global:ScopeId -ne "")
	{
		"Looking for {0} in DHCP" -f $ComputerName
		(Get-DhcpServerv4Lease -ComputerName $global:DhcpServer -ScopeId $global:ScopeId -AllLeases | where hostname -match $ComputerName | FT ipaddress,hostname,clientid,addressstate | Out-String).Trim() 
		(Get-DhcpServerv4Lease -ComputerName $global:DhcpServer -ScopeId $global:ScopeId -AllLeases | where hostname -match $ComputerName | FT ipaddress,hostname,clientid,addressstate | Out-String).Trim()  | Out-File -FilePath $global:FileName -Append
		""
		"" | Out-File -FilePath $global:FileName -Append
		if ($IpAddress -ne "")
		{
		"Looking for DNS Address {0} in DHCP" -f $IpAddress
		#(Get-DhcpServerv4Lease -ComputerName $global:DhcpServer -ScopeId $global:ScopeId | where ipaddress -match $IpAddress | FT ipaddress,hostname,clientid,addressstate | Out-String).Trim() 
		(Get-DhcpServerv4Lease -ComputerName $global:DhcpServer -ScopeId $global:ScopeId -AllLeases | where ipaddress -eq $IpAddress | FT ipaddress,hostname,clientid,addressstate | Out-String).Trim() 
		(Get-DhcpServerv4Lease -ComputerName $global:DhcpServer -ScopeId $global:ScopeId -AllLeases | where ipaddress -eq $IpAddress | FT ipaddress,hostname,clientid,addressstate | Out-String).Trim() | Out-File -FilePath $global:FileName -Append
		} elseif ( $global:IPAddress -ne "")
		{
			(Get-DhcpServerv4Lease -ComputerName $global:DhcpServer -ScopeId $global:ScopeId -AllLeases | where ipaddress -eq $global:IPAddress | FT ipaddress,hostname,clientid,addressstate | Out-String).Trim() 
			(Get-DhcpServerv4Lease -ComputerName $global:DhcpServer -ScopeId $global:ScopeId -AllLeases | where ipaddress -eq $global:IPAddress | FT ipaddress,hostname,clientid,addressstate | Out-String).Trim()  | Out-File -FilePath $global:FileName -Append
		}
	}
	$global:ScopeId = ""
}

ipconfig /flushdns
"PowerShell Version: $((Get-Host).Version)"
"-------------------------------------------------------------------------------"
if ($args.count -eq 0)
{
	#$env:wnum = $args[0]
	$ComputerName= Read-Host -Prompt "Workstation"
    $ComputerName = $ComputerName.Trim().ToUpper()
	
}
elseif ($args.count -eq 1)
{
	if (Test-Path $args[0])
	{
		clear
		"File detected, looping"
		$WorkStations = Get-Content -Path $args[0]
		foreach($ComputerName in $WorkStations)
		{
			


			Full-Report -ComputerName $ComputerName
			"-------------------------------------------------------------------------------"
			
			$ComputerNameRsm = $ComputerName.ToUpper() -replace '\..*',''
			$ComputerNameRsm += '-RSM'
			try
			{
			$RsmIpAddress = [System.Net.Dns]::GetHostAddresses($ComputerNameRsm).IPAddressToString
			Full-Report -ComputerName $ComputerNameRsm
			}
			catch
			{
			"No -RSM"
			}
		}
		exit 0 
	} else {

		#$env:wnum = $args[0]
		$ComputerName = $args[0]
	}
}

Full-Report -ComputerName $ComputerName

"-------------------------------------------------------------------------------"

$ComputerNameRsm = $ComputerName.ToUpper() -replace '\..*',''
$ComputerNameRsm += '-RSM'
try
{
	$RsmIpAddress = [System.Net.Dns]::GetHostAddresses($ComputerNameRsm).IPAddressToString
	Full-Report -ComputerName $ComputerNameRsm
}
catch
{
	"No -RSM"
}

Get-Date