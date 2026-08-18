###############################################################################
# Description: Lists the network drives of the logged in person
# C:\Users\garbla\NTUSER.DAT
# 
# https://social.technet.microsoft.com/Forums/ie/en-US/46881e57-62a4-446e-af2d-cd2423e7837f/report-on-remote-users-mapped-drives
# 08/19/21 glb copied from internet
###############################################################################
function Get-MappedDrives($ComputerName){
  $output = @()
  if(Test-Connection -ComputerName $ComputerName -Count 1 -Quiet){
    $Hive = [long]$HIVE_HKU = 2147483651
    $sessions = Get-WmiObject -ComputerName $ComputerName -Class win32_process | ?{$_.name -eq "explorer.exe"}
    if($sessions){
      foreach($explorer in $sessions){
		"-------------------------------------------------------------------------------"
        $sid = ($explorer.GetOwnerSid()).sid
        $owner  = $explorer.GetOwner()
        $RegProv = get-WmiObject -List -Namespace "root\default" -ComputerName $ComputerName | Where-Object {$_.Name -eq "StdRegProv"}
        $DriveList = $RegProv.EnumKey($Hive, "$($sid)\Network")
        if($DriveList.sNames.count -gt 0)
		{
          foreach($drive in $DriveList.sNames)
		  {
          $output += "$($drive)`t$(($RegProv.GetStringValue($Hive, "$($sid)\Network\$($drive)", "RemotePath")).sValue)`t$($owner.Domain)`t$($owner.user)`t$($ComputerName)"
          }
        }
		else
		{
			write-debug "No mapped drives on $($ComputerName)"
		}
      }
    }else{write-debug "explorer.exe not running on $($ComputerName)"}
  }else{write-debug "Can't connect to $($ComputerName)"}
  return $output
}

function Get-AllMappedDrives($ComputerName){
  $output = @()
  if(Test-Connection -ComputerName $ComputerName -Count 1 -Quiet){
    $Hive = [long]$HIVE_HKU = 2147483651
    $RegProv = get-WmiObject -List -Namespace "root\default" -ComputerName $ComputerName | Where-Object {$_.Name -eq "StdRegProv"}
    $UserList = $RegProv.EnumKey($Hive, "")
    foreach($User in $UserList.sNames)
	{
		if ($User.Length -gt 9 -and $User.contains("Classes") -eq $false) 
		{
			"$($User)>-------------------------------------------"
			$DriveList = $RegProv.EnumKey($Hive, "$($User)\Network")
			if($DriveList.sNames.count -gt 0)
			{
			  foreach($drive in $DriveList.sNames)
			  {
			  $output += "$($drive)`t$(($RegProv.GetStringValue($Hive, "$($User)\Network\$($drive)", "RemotePath")).sValue)`t$($owner.Domain)`t$($owner.user)`t$($ComputerName)"
			  }
			}
			else
			{
				write-debug "No mapped drives on $($ComputerName)"
			}
		}
    }

  }else{write-debug "Can't connect to $($ComputerName)"}
  return $output
}
ipconfig /flushdns
"PowerShell Version:$((Get-Host).Version)"

if ($args.count -eq 1)
{
    $env:wnum = $args[0]
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
Get-Date
"Workstation: {0}" -f $ComputerName
$host.ui.RawUI.WindowTitle = "Getting Network Drives on $($ComputerName)"
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

Get-MappedDrives  $ComputerName
#Get-AllMappedDrives  $ComputerName

Start-Sleep -s 5

"Done"
