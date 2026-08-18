###############################################################################
# Description: Lists printers of the logged in person
# https://social.technet.microsoft.com/Forums/ie/en-US/46881e57-62a4-446e-af2d-cd2423e7837f/report-on-remote-users-mapped-drives
# 08/19/21 glb - copied from internet
# 09/28/22 glb - added default and locally installed printers
# 05/16/23 glb - added list of all mapped printers
# 10/14/24 glb - removed shared file
###############################################################################
$global:Users = 0
function Get-MappedDrives($ComputerName){
 # $output = @()
 $SessionOwner=""
  if(Test-Connection -ComputerName $ComputerName -Count 1 -Quiet){
    #$Hive = [long]$HIVE_HKU = 2147483651
	$Hive = 2147483651
    $sessions = Get-WmiObject -ComputerName $ComputerName -Class win32_process | ?{$_.name -eq "explorer.exe"}
    if($sessions){
      foreach($explorer in $sessions){
		  $global:Users +=1
		"-------------------------------------------------------------------------------"
        $sid = ($explorer.GetOwnerSid()).sid
        $owner  = $explorer.GetOwner()
        $RegProv = get-WmiObject -List -Namespace "root\default" -ComputerName $ComputerName | Where-Object {$_.Name -eq "StdRegProv"}
        $DriveList = $RegProv.EnumKey($Hive, "$($sid)\Printers\Connections")
        if(($DriveList.sNames.count -gt 0) -and ($SessionOwner.IndexOf("|" + $explorer.GetOwner().User +"|") -eq -1)){			
		"Found {0} Printers in Session {1}" -f $DriveList.sNames.count,$explorer.GetOwner().User
          foreach($drive in $DriveList.sNames){
			  "Printer: {0}" -f $drive.replace(",,","\\").replace(",","\")
			  #Need to get name
			  #Get-PrintJob -computername $ComputerName  -PrinterName "$($drive)"
			  #"Printer:{0}" -f $drive
          #$output += "$($drive)`t$(($RegProv.GetStringValue($Hive, "$($sid)\Network\$($drive)", "RemotePath")).sValue)`t$($owner.Domain)`t$($owner.user)`t$($ComputerName)"
          }
		  $DP = $RegProv.GetStringValue($Hive, "$($sid)\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows","Device")
		  "-->Default Printer {0}" -f $DP.sValue.replace(",,","\\").replace(",","\")
        }else{write-debug "No mapped printers on $($ComputerName)"}

		$SessionOwner += "|" + $explorer.GetOwner().User +"|"
      }
    }else{write-debug "explorer.exe not running on $($ComputerName)"}
  }else{write-debug "Can't connect to $($ComputerName)"}
  #return $output
}
function Get-NonNetworkPrinters($ComputerName){
	$Hive = 2147483650
	$RegProv = get-WmiObject -List -Namespace "root\default" -ComputerName $ComputerName | Where-Object {$_.Name -eq "StdRegProv"}
    $DriveList = $RegProv.EnumKey($Hive, "SYSTEM\CurrentControlSet\Control\Print\Printers")
    if($DriveList.sNames.count -gt 0){
		"==============================================================================="
		"Found {0} System Printers" -f $DriveList.sNames.count
		    foreach($drive in $DriveList.sNames){
				#"System Printer: {0}" -f $drive
				if ($drive.ToUpper() -Match "PHUNIFLOW"){
					Write-Host "System Printer: $($drive)" -ForegroundColor Red
				} else {
					Write-Host "System Printer: $($drive)" -ForegroundColor Green
					if ($drive.ToUpper() -NotMatch "ONENOTE" -And $drive.ToUpper() -NotMatch "SNAGIT")
					{
						#"Checking Jobs"
						#OneNote has permission issues
						#Get-PrintJob -computername $ComputerName  -PrinterName "$($drive)"
						Write-Host "remove-printjob -computername $($ComputerName) -printername '$($drive)' -id ##"
						#"remove-printjob -computername w502248 -printername "RightFax Fax Printer" -id ##"
					}
				}
			}
		"==============================================================================="
	}
}

function Get-AllMapped($ComputerName) {

	$Hive = [Microsoft.Win32.RegistryHive]::LocalMachine

	$reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey($Hive, $ComputerName)

	$KeyPath = 'Software\Microsoft\Windows NT\CurrentVersion\Print\Connections'
	$key = $reg.OpenSubKey($KeyPath)

	$SubKeyArray1 = $key.GetSubKeyNames()
	"==============================================================================="
	ForEach ($SubKey1 in $SubKeyArray1)
	{
			$key2 = $reg.OpenSubKey("$KeyPath\$SubKey1")

			$SubKeyArray2 = $key2.GetValueNames()   
			ForEach ($SubKey2 in $SubKeyArray2)
			{
			   if ($SubKey2 -eq "Printer")
			   {
					#"System Connections: {0}->{1}" -f $SubKey2,$key2.GetValue($SubKey2)
					if ($key2.GetValue($SubKey2).ToUpper() -Match "PHUNIFLOW" -or $key2.GetValue($SubKey2).ToUpper() -Match "PHUNIFLON"){
						Write-Host "System Connections: $($SubKey2)->$($key2.GetValue($SubKey2).ToUpper())" -ForegroundColor Red
					} else {
						Write-Host "System Connections: $($SubKey2)->$($key2.GetValue($SubKey2).ToUpper())" -ForegroundColor Green
					}
				}
			 }
	}
	#return $HasPrinter
}

function Check-LPDSVC($ComputerName){
	#Get-CimInstance -ClassName Win32_Service -ComputerName $ComputerName -Filter 'Name = "LPDSVC"'
	$service = Get-Service -ComputerName $ComputerName -Name lpdsvc -ErrorAction SilentlyContinue
	if($service -eq $null)
	{
		Write-Host "$ComputerName HAS LPDSVC" -ForegroundColor Red 
		# Service does not exist
	} else {
		Write-Host "$ComputerName has no LPDSVC" -ForegroundColor Green 
		# Service does exist
	}
}

ipconfig /flushdns
"PowerShell Version:$((Get-Host).Version)"

if ($args.count -eq 1)
{
    $ComputerName = $args[0]
}
else
{
    $ComputerName= Read-Host -Prompt "Workstation"
    $ComputerName = $ComputerName.Trim()
}
"==============================================================================="
"Workstation: {0}" -f $ComputerName
$host.ui.RawUI.WindowTitle = "Getting Printers on $($ComputerName)"
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

Get-MappedDrives $ComputerName
Get-AllMapped $ComputerName
Get-NonNetworkPrinters $ComputerName
#Check-LPDSVC $CompuerName
Get-CimInstance -ClassName Win32_Service -ComputerName $ComputerName -Filter 'Name = "LPDSVC"'
Start-Sleep -s 5

"Done"
