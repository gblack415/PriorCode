###############################################################################
# Description: Prompts for device and deletes printer remotely then restarts services.
# 08/19/21 glb created
# 01/19/22 glb added phprint.txt check
# 11/14/24 glb cleaned up parameters
# NEEDS JUMPBOX
###############################################################################
ipconfig /flushdns

$global:SpoolerSleep = 5
$global:LpdsvcFlag = $false

function Enum-Registry {
	param (
	$ComputerName
	)
	$Hive = [Microsoft.Win32.RegistryHive]::LocalMachine

	$reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey($Hive, $ComputerName)

	$KeyPath = 'Software\Microsoft\Windows NT\CurrentVersion\Print\Connections'
	$key = $reg.OpenSubKey($KeyPath)

	$SubKeyArray1 = $key.GetSubKeyNames()
	ForEach ($SubKey1 in $SubKeyArray1)
	{
			$key2 = $reg.OpenSubKey("$KeyPath\$SubKey1")

			$SubKeyArray2 = $key2.GetValueNames()   
			ForEach ($SubKey2 in $SubKeyArray2)
			{
			   if ($SubKey2 -eq "Printer")
			   {
				"Currently Installed: {0}->{1}" -f $SubKey2,$key2.GetValue($SubKey2)
				}
			 }
	}
}

function Restart-Local-Spooler {

	$host.ui.RawUI.WindowTitle = "Restarting Spooler on $($ComputerName)"
	try
	{
		#Get-Service "spooler" -ComputerName $ComputerName | Where-Object { $_.status -eq ‘running’} 
		Get-Service "spooler" -ComputerName $ComputerName |
		ForEach-Object {
		write-host -ForegroundColor 9 “Service name $($_.name)”
		  if($_.DependentServices)
			{ write-host -ForegroundColor 3 “`tServices that depend on $($_.name)”
			  foreach($s in $_.DependentServices)
			   { “`t`t” + $s.name
			   if ( $s.name -eq "LPDSVC")
			   {
				   $global:LpdsvcFlag=$true
				   Add-Content $LpdsvcList "$ComputerName"
			   }
				} #end if DependentServices
		} 
		}
		if ($global:LpdsvcFlag)
		{

			if(Test-Path -Path .\remote-conf-man.bat -PathType Leaf)
			{		
				"###############################################################################"
				"ERROR LPDSVC DEPENDENCY, RUNNING MACHINE POLICY UPDATE"
				"###############################################################################"
				#.\remote-conf-man.bat $ComputerName
				"MACHINE POLICY EVALUATION - $($ComputerName)"
				Invoke-WmiMethod -Class sms_client -Namespace 'root\ccm' -ComputerName $ComputerName -Name TriggerSchedule -ArgumentList "{00000000-0000-0000-0000-000000000021}"
				#"DISCOVERY DATA - $($ComputerName)"
				#Invoke-WmiMethod -Class sms_client -Namespace 'root\ccm' -ComputerName $ComputerName -Name TriggerSchedule -ArgumentList "{00000000-0000-0000-0000-000000000003}"
				"App Devployment - $($ComputerName)"
				Invoke-WmiMethod -Class sms_client -Namespace 'root\ccm' -ComputerName $ComputerName -Name TriggerSchedule -ArgumentList "{00000000-0000-0000-0000-000000000121}"
				#"Hardware Inventory - $($ComputerName)"
				#Invoke-WmiMethod -Class sms_client -Namespace 'root\ccm' -ComputerName $ComputerName -Name TriggerSchedule -ArgumentList "{00000000-0000-0000-0000-000000000001}"
				"Update Deployment - $($ComputerName)"
				Invoke-WmiMethod -Class sms_client -Namespace 'root\ccm' -ComputerName $ComputerName -Name TriggerSchedule -ArgumentList "{00000000-0000-0000-0000-000000000108}"
				"Update Scan - $($ComputerName)"
				Invoke-WmiMethod -Class sms_client -Namespace 'root\ccm' -ComputerName $ComputerName -Name TriggerSchedule -ArgumentList "{00000000-0000-0000-0000-000000000113}"
				#"Software Inventory - $($ComputerName)"
				#Invoke-WmiMethod -Class sms_client -Namespace 'root\ccm' -ComputerName $ComputerName -Name TriggerSchedule -ArgumentList "{00000000-0000-0000-0000-000000000002}"
	
				"###############################################################################"
				"ERROR LPDSVC DEPENDENCY, RAN MACHINE POLICY UPDATE"
				"###############################################################################"
			}

		}
		
		#Get-service "spooler" -ComputerName $ComputerName | select displayname,@{LABEL='Current Status   ';Expression={'{0}' -f $_.status }} | Format-Table -AutoSize
		Get-CimInstance -ClassName Win32_Service -ComputerName $ComputerName -Filter 'Name = "spooler"' | select displayname,@{LABEL='Current Status   ';Expression={'{0}' -f $_.statE }} | Format-Table -AutoSize
		#Get-Service "spooler" -ComputerName $ComputerName | Stop-Service -PassThru | select displayname,@{LABEL='Current Status   ';Expression={'Attempting Stop'}} | Format-Table -AutoSize
		Get-Service "spooler" -ComputerName $ComputerName | Stop-Service -Force -PassThru | select displayname,@{LABEL='Current Status   ';Expression={'Attempting Stop'}} | Format-Table -AutoSize
		#if ($global:LpdsvcFlag)
		#{		
		#"Run stop on workstation due to remote slowness"
		#WMIC /node:$ComputerName process call create "cmd.exe /c sc stop spooler"
		#}


		#Get-CimInstance -ClassName Win32_Service -ComputerName w507609 -Filter 'Name = "spooler" AND State = "Running" AND StartMode = "Auto"' | Where-Object { $_.state -eq 'Running' -or $_.StartMode -eq 'Auto' }
		#https://stackoverflow.com/questions/28186904/powershell-wait-for-service-to-be-stopped-or-started
		#Wait for Stop
		$maxRepeat = 20
		do {
			#$count = (Get-Service "spooler" -ComputerName $ComputerName | ? {$_.status -eq "Stopped"}).count
			$count = (Get-CimInstance -ClassName Win32_Service -ComputerName $ComputerName -Filter 'Name = "spooler"' | ? {$_.state -eq "Stopped"}).count
			$maxRepeat--
			Write-Host "+"  –NoNewline
			sleep -Milliseconds 600
		} until ($count -eq 0 -or $maxRepeat -eq 0)
		
		
		#Get-service "spooler" -ComputerName $ComputerName | select displayname,@{LABEL='Current Status   ';Expression={'{0}' -f $_.status }} | Format-Table -AutoSize
		Get-CimInstance -ClassName Win32_Service -ComputerName $ComputerName -Filter 'Name = "spooler"' | select displayname,@{LABEL='Current Status   ';Expression={'{0}' -f $_.statE }} | Format-Table -AutoSize
		Get-Service "spooler" -ComputerName $ComputerName | Start-Service -PassThru | select displayname,@{LABEL='Current Status   ';Expression={'Attempting Start'}} | Format-Table -AutoSize
		#Get-Service "spooler" -ComputerName $ComputerName | select -expand DependentServices | get-Service | Start-Service -PassThru | select displayname,@{LABEL='Current Status   ';Expression={'Attempting Start'}} | Format-Table -AutoSize
		#if ($global:LpdsvcFlag)
		#{		
		#"Run start on workstation due to remote slowness"
		#WMIC /node:$ComputerName process call create "cmd.exe /c sc start spooler"
		#}
		#Invoke-Command -session $s -scriptblock {c:\windows\system32\sc.exe  start spooler}
		#Remove-PSSession $s
		#Wait for Start
		$maxRepeat = 20
		do {
			#$count = (Get-Service "spooler" -ComputerName $ComputerName | ? {$_.status -eq "Running"}).count
			$count = (Get-CimInstance -ClassName Win32_Service -ComputerName $ComputerName -Filter 'Name = "spooler"' | ? {$_.state -eq "Running"}).count
			$maxRepeat--
			Write-Host "+"  –NoNewline
			sleep -Milliseconds 600
		} until ($count -eq 0 -or $maxRepeat -eq 0)

		#if(!$?)
		#if( $LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) 
		#{
		#"###############################################################################"
		#"ERROR STARTING SPOOLER DURING (RESTART)"
		#"###############################################################################"
		#}
		#Get-service "spooler" -ComputerName $ComputerName | select displayname,@{LABEL='Current Status   ';Expression={'{0}' -f $_.status }} | Format-Table -AutoSize
		Get-CimInstance -ClassName Win32_Service -ComputerName $ComputerName -Filter 'Name = "spooler"' | select displayname,@{LABEL='Current Status   ';Expression={'{0}' -f $_.statE }} | Format-Table -AutoSize
	}
	catch
	{
		"###############################################################################"
		"ERROR STARTING SPOOLER"
		"###############################################################################"
	}
	
}


"PowerShell Version:$((Get-Host).Version)"
ipconfig /flushdns
$host.ui.RawUI.WindowTitle = "Delete Printer"
$args.count
if ($args.count -ge 1)
{
    $ComputerName = $args[0]
}
else
{
    $ComputerName= Read-Host -Prompt "Workstation"
}

"Workstation:{0}" -f $ComputerName

If (Test-Connection $ComputerName -Count 1 -ErrorAction 0 -Quiet) 
{ 
    Write-Host "$ComputerName is Pingable" -ForegroundColor Green 
}
Else 
{ 
    Write-Host "$ComputerName is DOWN, bye" -ForegroundColor Red 
    Start-Sleep -s 5
    Exit 1
}

$PhprintFile="\\"+$ComputerName+"\c$\Windows\phprint.txt"
$PhprintFileNew = get-date -uformat "phprint.txt-%Y%m%d_%H%M%S"
if(Test-Path -Path $PhprintFile -PathType Leaf)
{
        #Write-Host "Phprint.txt Exists, renaming it"
		#Rename-Item -Path $PhprintFile -NewName $PhprintFileNew		
		Write-Host "Phprint.txt Exists, deleting it"
		#Rename-Item -Path $PhprintFile -NewName $PhprintFileNew		
		Remove-Item -Path $PhprintFile
		
		
}

$host.ui.RawUI.WindowTitle = "Delete Printer on $($ComputerName)"
if ($args.count -ge 2)
{
    $PrinterUnc = $args[1]
}
else
{
    $PrinterUnc= Read-Host -Prompt "Del Printer(no server)"
}

if ($PrinterUnc)
{
    "Need to Delete Printer: {0}" -f $PrinterUnc
}
$Hive = [Microsoft.Win32.RegistryHive]::LocalMachine

$reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey($Hive, $ComputerName)

$KeyPath = 'Software\Microsoft\Windows NT\CurrentVersion\Print\Connections'
$key = $reg.OpenSubKey($KeyPath)

$SubKeyArray1 = $key.GetSubKeyNames()
$HasPrinter = $false   
$Unc=""         
ForEach ($SubKey1 in $SubKeyArray1)
{

        $key2 = $reg.OpenSubKey("$KeyPath\$SubKey1")

        $SubKeyArray2 = $key2.GetValueNames()

        "----------------------------------------------"     
        ForEach ($SubKey2 in $SubKeyArray2)
        {
           if ($SubKey2 -eq "Printer")
           {
            "Currently Installed: {0}->{1}" -f $SubKey2,$key2.GetValue($SubKey2)
            #if ($PrinterUnc -eq $key2.GetValue($SubKey2))
            if($key2.GetValue($SubKey2).ToUpper().Contains($PrinterUnc.ToUpper())) 
            {
                "Printer Exists"
                $HasPrinter = $true
                $Unc = $key2.GetValue($SubKey2)
                 break 
            }
            else
            {
                "Printer Not Found"
            }
           }
            if ($HasPrinter -eq $true)
            {
                break
            }

        }
       "----------------------------------------------"
}

if ($HasPrinter -eq $true)
{
    Get-service spooler -ComputerName $ComputerName  | select status |  Tee-Object -Variable ServiceStatus
    if($ServiceStatus.Status -ne "Running") 
    { 
        "###############################################################################"
        "PRINT SPOOLER NOT RUNNING, NEED TO START TO DEL PRINTER"
        "###############################################################################"
        Get-Service "spooler" -ComputerName $ComputerName | Start-Service -PassThru | select displayname,@{LABEL='Current Status   ';Expression={'Attempting Start'}} | Format-Table -AutoSize
		$maxRepeat = 20
		do {
			$count = (Get-Service "spooler" -ComputerName $ComputerName | ? {$_.status -eq "Running"}).count
			$maxRepeat--
			sleep -Milliseconds 600
		} until ($count -eq 0 -or $maxRepeat -eq 0)
    }
    "Deleting Printer UNC:{0}" -f $Unc
    #Invoke-WMIMethod -Class Win32_Process -Name Create -Computername $ComputerName -ArgumentList "cmd /c RUNDLL32 PRINTUI.DLL,PrintUIEntry /gd /q /c\\$ComputerName /n$PrinterUnc"
    #Invoke-WMIMethod -Class Win32_Process -Name Create -Computername $ComputerName -ArgumentList "cmd /c RUNDLL32 PRINTUI.DLL,PrintUIEntry /gd /q /c\\$ComputerName /n$Unc"
    #Invoke-WMIMethod -Class Win32_Process -Name Create -Computername $ComputerName -ArgumentList "cmd /c RUNDLL32 PRINTUI.DLL,PrintUIEntry /dn /q /c\\$ComputerName /n$Unc"
    RUNDLL32 PRINTUI.DLL,PrintUIEntry /gd /q /c\\$ComputerName /n$Unc
	#$s = New-PSSession -computername $ComputerName
	#Invoke-Command -session $s -scriptblock {c:\windows\system32\RUNDLL32 PRINTUI.DLL,PrintUIEntry /gd /q /n$Unc}
	#Remove-PSSession $s
	Restart-Local-Spooler

	<# Start-Sleep -s 5
    Get-service spooler -ComputerName $ComputerName  | select displayname,@{LABEL='Current Status   ';Expression={'{0}' -f $_.status }} | Format-Table -AutoSize
    Get-Service "spooler" -ComputerName $ComputerName | Stop-Service -PassThru | select displayname,@{LABEL='Current Status   ';Expression={'Attempting Stop'}} | Format-Table -AutoSize
	$maxRepeat = 20
	do {
		$count = (Get-Service "spooler" -ComputerName $ComputerName | ? {$_.status -eq "Stopped"}).count
		$maxRepeat--
		sleep -Milliseconds 600
	} until ($count -eq 0 -or $maxRepeat -eq 0)
    Get-service spooler -ComputerName $ComputerName  | select displayname,@{LABEL='Current Status   ';Expression={'{0}' -f $_.status }} | Format-Table -AutoSize
    Get-Service "spooler" -ComputerName $ComputerName | Start-Service -PassThru | select displayname,@{LABEL='Current Status   ';Expression={'Attempting Start'}} | Format-Table -AutoSize
	$maxRepeat = 20
	do {
		$count = (Get-Service "spooler" -ComputerName $ComputerName | ? {$_.status -eq "Running"}).count
		$maxRepeat--
		sleep -Milliseconds 600
	} until ($count -eq 0 -or $maxRepeat -eq 0)
    Get-service spooler -ComputerName $ComputerName  | select displayname,@{LABEL='Current Status   ';Expression={'{0}' -f $_.status }} | Format-Table -AutoSize #>
}

"Post Restart Printer List: {0}" -f $ComputerName
Enum-Registry -ComputerName $ComputerName
Start-Sleep -s 5
$host.ui.RawUI.WindowTitle = ""
"Done"
