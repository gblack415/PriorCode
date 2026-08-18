###############################################################################
# Description: Last Boot Stats with W# capture for problems
# 05/17/23 glb created
# 11/14/23 glb added remove unpingable
###############################################################################
"PowerShell Version:$((Get-Host).Version)"
ipconfig /flushdns
$host.ui.RawUI.WindowTitle = "Interrogating PC"
if ($args.count -eq 1)
{
    "Got W# from parameter"
    $env:wnum = $args[0]
}

if (Test-Path "c:\users\$env:UserName\desktop\wnum.txt")
{
    "Got W# from File"
    $env:wnum = Get-Content "c:\users\$env:UserName\desktop\wnum.txt" -Raw
}

if ($env:wnum)
{
    $ComputerName = $env:wnum
}
else
{
    $ComputerName= Read-Host -Prompt "Workstation"
    $ComputerName = $ComputerName.Trim()
}
#$host.ui.RawUI.WindowTitle = “Remotely Cleaning $($ComputerName)”
If (Test-Connection $ComputerName -Count 1 -ErrorAction 0 -Quiet) 
{ 
    Write-Host "$ComputerName is Pingable" -ForegroundColor Green 
}
Else 
{ 
    Write-Host "$ComputerName is DOWN, bye" -ForegroundColor Red 
	$badFile=".\wbad.txt"
	(Get-Content -Path $badFile ) -replace $ComputerName, '' | sort -unique | where {$_ -notmatch '(^\s*)$'} | Set-Content -Path $badFile
    Start-Sleep -s 5
    Exit 1
}
"Starting"
#[System.Net.DNS]::GetHostByName('')
""
(Get-WmiObject -computername $env:wnum win32_operatingsystem | select csname,caption, @{LABEL='LastBootUpTime';EXPRESSION={$_.ConverttoDateTime($_.lastbootuptime)}}, @{LABEL='Up Days';EXPRESSION={NEW-TIMESPAN -Start $_.ConverttoDateTime($_.lastbootuptime) -End (GET-DATE)}}| Out-String).Trim()
""
$bnum = Get-WmiObject -computername $env:wnum win32_operatingsystem | select BuildNumber  | foreach {$_.BuildNumber}
$oldFile=".\wOldOs.txt"
if ( $bnum -ge 19045) 
{
	Write-Host "Build: $bnum" -ForegroundColor Green
}
else
{
	Write-Host "Build: $bnum" -ForegroundColor Red 
	if (Test-Path $oldFile)
	{
		$al = Get-Content $oldFile
		$cw = $al | %{$_ -match $ComputerName}
	}
	If ($cw -contains $true) 
	{
		"Contains {0}" -f $ComputerName
		(Get-Content -Path $oldFile ) -replace $ComputerName, '' | sort -unique | where {$_ -notmatch '(^\s*)$'} | Set-Content -Path $oldFile
	}
	else
	{
		"Adding to {0}" -f $oldFile
		Add-Content $oldFile $ComputerName
	}
}

$udays = (get-date) - (get-ciminstance -computername $env:wnum -classname Win32_OperatingSystem).LastBootUpTime | foreach {$_.Days}
"Uptime: {0} day(s)" -f $udays
$kdays= Get-WmiObject -computername $env:wnum Win32_quickfixengineering | Sort-Object InstalledOn -Descending | select -first 1 @{LABEL='KbDays';EXPRESSION={NEW-TIMESPAN -Start $_.InstalledOn -End (GET-DATE)}} | foreach {$_.KbDays}
$lastBootFile=".\wLastBoot.txt"
"KB Age: {0} day(s)" -f $kdays.Days
#If ( $udays -ge 30 -or $kdays.Days -ge 75)
If ( $udays -ge 30)
{
	$IPAddress = Resolve-DnsName -Name $ComputerName | select ipaddress | Out-String 
	if ($IPAddress -like '*10.100*') 
	{
		Write-Host "VPN Device, ignore." -ForegroundColor Red 
	}
	else
	{
		#If (Get-Content $lastBootFile | %{$_ -match $ComputerName}) 
		if (Test-Path $lastBootFile)
		{
			$al = Get-Content $lastBootFile
			$cw = $al | %{$_ -match $ComputerName}
		}
		If ($cw -contains $true) 
		{
			"Contains {0}" -f $ComputerName
		}
		else
		{
			"Adding to {0}" -f $lastBootFile
			Add-Content $lastBootFile $ComputerName
		}
	}
}
else
{
	(Get-Content -Path $lastBootFile ) -replace $ComputerName, '' | sort -unique | where {$_ -notmatch '(^\s*)$'} | Set-Content -Path $lastBootFile
}


""
"--------------------------------------------------------------------------------"
"Time Zone"
"--------------------------------------------------------------------------------"
""
(Get-WmiObject -computername $env:wnum win32_timezone | select caption | Out-String).Trim()
""
"--------------------------------------------------------------------------------"
"Free Space"
"--------------------------------------------------------------------------------"
""
(Get-WmiObject -computername $env:wnum Win32_logicaldisk | select DeviceId, ProviderName,@{Name='Size(GB)';Expression={[decimal]('{0:N0}' -f($_.size/1gb))}},@{Name='Free (GB)';Expression={[decimal]('{0:N0}' -f($_.freespace/1gb))}}, @{Name='Free (%%)';Expression={'{0,6:P0}' -f(($_.freespace/1gb) / ($_.size/1gb))}} | Format-Table -auto| Out-String).Trim()  
""
#"--------------------------------------------------------------------------------"
#"Event Log"
#"--------------------------------------------------------------------------------"
#""
#(Get-EventLog -Logname System -Newest 10 -ComputerName $env:wnum | Out-String).Trim()
#""
"--------------------------------------------------------------------------------"
"KB's"
"--------------------------------------------------------------------------------"
""
Get-WmiObject -computername $env:wnum Win32_quickfixengineering | Sort-Object InstalledOn -Descending | Format-Table -auto
""
