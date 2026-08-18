###############################################################################
# Description: Adds printer remotely and restarts services
# 08/19/21 glb created 
# 09/04/21 glb added spooler status check
# 01/19/22 glb added phprint.txt check
# 02/18/22 glb added try/catch for restart
# 02/23/22 glb added check for completion of start/stop
# 03/02/22 glb changed rename to delete for Robert
# 04/28/22 glb cleaned up messages for RobTir
# 05/19/22 glb sped up restart
# 06/09/22 glb added lpdsvc and phprint tracking files
# 06/15/22 glb added - option to suppress restart with multiple printers
# 05/17/23 glb retired Casey said it was blocked
# UNC = Example \\yahoo\HP222
# https://docs.microsoft.com/en-us/windows/win32/fileio/naming-a-file
# https://unc.us/
# Machine Policy issue(apply and reboot) = Stop-Service : Cannot stop service 'Print Spooler (spooler)' because it has dependent services. It can only be stopped if the Force flag is set.
# add trailing + for extra long restart spooler
# add trailing - for another unc
#https://devblogs.microsoft.com/scripting/use-windows-powershell-to-display-service-dependencies/
###############################################################################

#Increase to 60 if printer not added without any errors
$global:SpoolerSleep = 5
$global:LpdsvcFlag = $false
$StopSuccess = $false
$NoRestart = $false
$global:AddSuccess = $false
$PhprintList = ".\wphprint.txt"
$LpdsvcList = ".\wlpdsvc.txt"

function Search-Server {

    param (
        $Server,
        $Printer
    )

    (Get-Printer -ComputerName $Server | where name -like "$($Printer)*" | select @{LABEL='Printer UNC';Expression={'\\{0}\{1}' -f $_.ComputerName,$_.Name }},PortName | Format-Table -AutoSize | Out-String).Trim()
}

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
				#"Currently Installed: {0}->{1}" -f $SubKey2,$key2.GetValue($SubKey2)
				Write-Host "Currently Installed: $($SubKey2)->$($key2.GetValue($SubKey2))" -ForegroundColor Green
				}
			 }
	}
	#return $HasPrinter
}

function Check-Registry {
	param (
	$ComputerName,
	$PrinterUnc
	)
	#Note any print statements get added to return values
	$HasPrinter = $false
	$Hive = [Microsoft.Win32.RegistryHive]::LocalMachine

	$reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey($Hive, $ComputerName)

	$KeyPath = 'Software\Microsoft\Windows NT\CurrentVersion\Print\Connections'
	$key = $reg.OpenSubKey($KeyPath)

	$SubKeyArray1 = $key.GetSubKeyNames()
	ForEach ($SubKey1 in $SubKeyArray1)
	{

			$key2 = $reg.OpenSubKey("$KeyPath\$SubKey1")

			$SubKeyArray2 = $key2.GetValueNames()

			#"----------------------------------------------"     
			ForEach ($SubKey2 in $SubKeyArray2)
			{
			   if ($SubKey2 -eq "Printer")
			   {
				#"Currently Installed: {0}->{1}" -f $SubKey2,$key2.GetValue($SubKey2)
				if ($PrinterUnc -eq $key2.GetValue($SubKey2))
				{
				#	"Printer Exists"
					$HasPrinter = $true
				}
				#else
				#{
				#	"New Printer Not Found"
				#}
			   }
			}
		   #"----------------------------------------------"
	}
	return $HasPrinter
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
				"App Deployment - $($ComputerName)"
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

ipconfig /flushdns
"PowerShell Version: $((Get-Host).Version)"

if ($args.count -eq 1)
{
    $env:wnum = $args[0]
}
elseif ($args.count -eq 2)
{
	$env:wnum = $args[0]
	$env:punc = $args[1]
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
"==============================================================================="
"Workstation: {0}" -f $ComputerName

$host.ui.RawUI.WindowTitle = "Adding Printer on $($ComputerName)"
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
        Write-Host "Phprint.txt exists, deleting it"
		#Rename-Item -Path $PhprintFile -NewName $PhprintFileNew		
		Remove-Item -Path $PhprintFile
		Add-Content $PhprintList "$ComputerName"
}
$ScriptLocation = Split-Path $MyInvocation.MyCommand.Path

Enum-Registry -ComputerName $ComputerName

# Attempt to get UNC
#if ($env:punc)
if ($env:punc -and -not $env:punc.IndexOf("\\") -eq -1)
{
    $PrinterUnc = $env:punc
}
else
{
    # 0 to just restart spooler
	"==============================================================================="
    $PrinterUnc= Read-Host -Prompt "New Printer P# or UNC(\\?\P#?) or 0 to restart spooler"
    $PrinterUnc = $PrinterUnc.Trim()
	if ($PrinterUnc.Contains("+")) 
	{
		$global:SpoolerSleep = 60
		$PrinterUnc=$PrinterUnc.Replace("+","")
	}
	if ($PrinterUnc.Contains("-")) 
	{
		$NoRestart = $true
		$PrinterUnc=$PrinterUnc.Replace("-","")
	}
	"Printer: {0}" -f $PrinterUnc

    if  ($PrinterUnc -eq "0")
    {
        Restart-Local-Spooler
		"==============================================================================="
		"Post Restart Printer List without Adding Printer: {0}" -f $ComputerName
		Enum-Registry -ComputerName $ComputerName
		"==============================================================================="
		if ($global:LpdsvcFlag)
		{
			"Has LPDSVC"
		}
		#$ser = @()
		#Invoke-Command -ScriptBlock {"$ser = $ScriptLocation\get-printers.ps1 $ComputerName return $ser"}
		#Write-Output $ser
		"Done"
        exit 0
    } 
	elseif ($PrinterUnc -eq "")
	{
		"Done"
        exit 0
	}
    elseif ($PrinterUnc.IndexOf("\\") -eq -1) 
    { 
        "Searching for UNC in AD"
		#$result = Get-ADObject -LdapFilter "(&(objectClass=printQueue)(printerName=$PrinterUnc))" -SearchBase "OU=Servers,DC=peacehealth,DC=org" -Properties uNCName | select @{LABEL='Printer UNC';Expression={'{0}' -f $_.uNCName.Replace(".yahoo.com","") }} | Format-Table -AutoSize
        $result = Get-ADObject -LdapFilter "(&(objectClass=printQueue)(printerName=$PrinterUnc))" -SearchBase "OU=Servers,DC=peacehealth,DC=org" -Properties uNCName | select @{LABEL='Printer UNC';Expression={'{0}' -f $_.uNCName }} | Format-Table -AutoSize
        $result
        if($result.Count -gt 0)
        {
            $PrinterUnc= Read-Host -Prompt "Enter Printer UNC"
			if ($PrinterUnc.Contains("+")) 
			{			
				$global:SpoolerSleep = 60
				$PrinterUnc=$PrinterUnc.Replace("+","")
			}
			if ($PrinterUnc -eq "")
			{
				"Done"
				exit 0
			}
        }
        else
        {
            "Need to search print servers for UNC"
             if($PrinterUnc.ToUpper().Contains("P7"))
             {
                "Idaho"
                Search-Server -Server boise.yahoo.com -Printer $PrinterUnc
             }


			"If the UNC(\\?\P#) isn't above, it may not exist on the print servers."
            $PrinterUnc= Read-Host -Prompt "Enter Full Printer UNC(\\?\P#?)"
			if ($PrinterUnc.Contains("+")) 
			{
				$global:SpoolerSleep = 60
				$PrinterUnc=$PrinterUnc.Replace("+","")
			}
			if ($PrinterUnc -eq "")
			{
				"Done"
				exit 0
			}
        }
    }
    

}



$HasPrinter = Check-Registry -ComputerName $ComputerName -PrinterUnc $PrinterUnc           
#$HasPrinter = Check-Registry($ComputerName ,$PrinterUnc)
#"Has Printer {0}" -f $HasPrinter
#$HasPrinter = $false
if ($HasPrinter -eq $false)
{
	"Full UNC of the printer to add:{0}" -f $PrinterUnc
    Get-service spooler -ComputerName $ComputerName  | select status |  Tee-Object -Variable ServiceStatus
    if($ServiceStatus.Status -ne "Running") 
    { 
        "###############################################################################"
        "PRINT SPOOLER NOT RUNNING, NEED TO START TO ADD PRINTER"
        "###############################################################################"
		try 
		{
			Get-Service "spooler" -ComputerName $ComputerName | Start-Service -PassThru | select displayname,@{LABEL='Current Status   ';Expression={'Attempting Start'}}
			$maxRepeat = 20
			do {
			$count = (Get-Service "spooler" -ComputerName $ComputerName | ? {$_.status -eq "Running"}).count
			$maxRepeat--
			sleep -Milliseconds 600
			} until ($count -eq 0 -or $maxRepeat -eq 0)
			#if(!$?)
			#{
			#		"Error starting Spooler since not started"
			#}
		}
		catch
		{
			"###############################################################################"
			"ERROR STARTING SPOOLER"
			"###############################################################################"
		}
	}
	""
    "Adding Printer"
    #Invoke-Command -ComputerName $ComputerName -Scriptblock {RUNDLL32 PRINTUI.DLL,PrintUIEntry /ga /c\\$ComputerName /n$PrinterUnc}
	#Invoke-WMIMethod -Class Win32_Process -Name Create -Computername $ComputerName -ArgumentList "cmd /c RUNDLL32 PRINTUI.DLL,PrintUIEntry /ga /q /c\\$ComputerName /n$PrinterUnc"
	#Invoke-Command -session $s -scriptblock {c:\windows\system32\RUNDLL32 PRINTUI.DLL,PrintUIEntry /ga /n\\PHLABPRINT1X64\P401806}
	#Remove-PSSession $s
	
	
    try
    {
		Start-Sleep -s 5
        RUNDLL32 PRINTUI.DLL,PrintUIEntry /ga /q /c\\$ComputerName /n$PrinterUnc
		#$s = New-PSSession -computername $ComputerName
		#Invoke-Command -session $s -scriptblock {c:\windows\system32\RUNDLL32 PRINTUI.DLL,PrintUIEntry /ga /n$PrinterUnc}
		#Invoke-Command -session $s -scriptblock {c:\windows\system32\sc.exe  stop spooler}
		#Invoke-Command -session $s -scriptblock {c:\windows\system32\sc.exe  start spooler}
		#Remove-PSSession $s
		#You must wait a few seconds for the workstation to add the printer before restarting spooler
		if( $LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) 
		{
		"###############################################################################"
        "ERROR ADDING PRINTER"
        "###############################################################################"
		#$s = New-PSSession -computername $ComputerName
		#Invoke-Command -session $s -scriptblock {c:\windows\system32\RUNDLL32 PRINTUI.DLL,PrintUIEntry /ga /n\\PHLABPRINT1X64\P401806}
		#Remove-PSSession $s
		#Invoke-Command -session $s -scriptblock {c:\windows\system32\gpupdate /force }
		}
    }
    catch
    {
        "###############################################################################"
        "ERROR ADDING PRINTER"
        "###############################################################################"
		#Try next time
		#$s = New-PSSession -computername $ComputerName
		#Invoke-Command -session $s -scriptblock {c:\windows\system32\RUNDLL32 PRINTUI.DLL,PrintUIEntry /ga /n\\PHLABPRINT1X64\P401806}
		#Invoke-Command -session $s -scriptblock {c:\windows\system32\gpupdate /force }
		#Remove-PSSession $s
    }
}
else
{
	"Printer Exists"
}
if ($NoRestart)
{
	"No restart, done"
	exit 0
}
"Post Add Sleep: {0} seconds" -f $global:SpoolerSleep
Start-Sleep -s $global:SpoolerSleep
Restart-Local-Spooler 
"==============================================================================="
"Post Restart Printer List: {0}" -f $ComputerName
Enum-Registry -ComputerName $ComputerName
if ($HasPrinter)
{
	"No printer added"
}
else
{
	"Added Printer: {0}" -f $PrinterUnc
}

if ($global:LpdsvcFlag)
{
	"###############################################################################"
	"WARNING LPDSVC DEPENDENCY, RUN REMOTE MACHINE POLICY UPDATE IF ERRORS"
	"###############################################################################"
}


#Invoke-Command -ScriptBlock {"$ScriptLocation\get-printers.ps1 $ComputerName"}
Start-Sleep -s 5
"==============================================================================="
"If printer not added without any errors, increase `$global:SpoolerSleep = 5 to `$global:SpoolerSleep = 60 and rerun."
"If you get any errors restarting the spooler, it needs a machine policy update run manually."
"==============================================================================="
"That's all folks."
