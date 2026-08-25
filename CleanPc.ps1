###############################################################################
# Description: Slowly Deletes temp files remotely from the computer it is launched from. See CleanPc-Fast.bat that runs this on remote device.
# 08/21/21 glb created
# 09/09/21 glb added clear dns cache
# 04/29/22 glb noticed I added logging for John
# 06/18/22 glb moved gpupdate to batch file as it seems to work better remotely
# https://stackoverflow.com/questions/1752677/how-to-recursively-delete-an-entire-directory-with-powershell-2-0
# 
###############################################################################

#$env:wnum="w300060"
#Too many folder/file errors
$ErrorActionPreference = 'SilentlyContinue'   


function Clean-Folder {

    param (
        $Path
    )

    "Working on:$($Path)"


    if (Test-Path $Path)
    {


        Write-Host "Found Folder, Deleting files(ignore errors)" -ForegroundColor Green
        # First remove any files in the folder tree
        #Get-ChildItem -LiteralPath $Path -Recurse -Force | Where-Object { -not ($_.psiscontainer) } | Remove-Item –Force
        #Get-ChildItem -LiteralPath $Path -Recurse -Force | Where-Object { -not ($_.psiscontainer) } | Remove-Item –Force -PassThru | Select-Object FullName | Add-Content -Path $LogFile 
		ForEach ($Subfolder in Get-ChildItem -LiteralPath $Path -Recurse -Force | Where-Object { -not ($_.psiscontainer) } ) {
            try 
            {
                "Deleting File:$($Subfolder.FullName)" >> $LogFile
                 Remove-Item -LiteralPath $Subfolder.FullName -Recurse -Force 

            }
            catch
            {
                Write-Host "Can't Delete Folder $($Subfolder.FullName)" -ForegroundColor Red
            }

		}
        Write-Host "Found Folder, Deleting subfolders(ignore errors)" -ForegroundColor Green
        # Then remove any sub-folders (deepest ones first).    The -Recurse switch may be needed despite the deepest items being deleted first.
        ForEach ($Subfolder in Get-ChildItem -LiteralPath $Path -Recurse -Force | Select-Object FullName, @{Name="Depth";Expression={($_.FullName -split "\\").Count}} | Sort-Object -Property @{Expression="Depth";Descending=$true}) { 
            try 
            {
                "Deleting Folder:$($Subfolder.FullName)" >> $LogFile
                 Remove-Item -LiteralPath $Subfolder.FullName -Recurse -Force 

            }
            catch
            {
                Write-Host "Can't Delete Folder $($Subfolder.FullName)" -ForegroundColor Red
            }
        }
        "-------------------------------------------------------------------------------"

    }
    else
    {
        Write-Host ""Path not found"" -ForegroundColor Red 
        
    }

}
"PowerShell Version: $((Get-Host).Version)"
ipconfig /flushdns
$host.ui.RawUI.WindowTitle = "Cleaning PC"
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
$host.ui.RawUI.WindowTitle = “Remotely Cleaning $($ComputerName)”
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
"Starting"
[System.Net.DNS]::GetHostByName('')
$LogFile = get-date -uformat "\\$($ComputerName)\C$\windows\system32\CleanPC-%Y%m%d_%H%M%S.log"
Clean-Folder -Path "\\$($ComputerName)\C$\temp\"
Clean-Folder -Path "\\$($ComputerName)\C$\windows\temp\"

Get-ChildItem "\\$($ComputerName)\C$\Users\" | 
Foreach-Object {
    #Big Files
    Clean-Folder -Path "$($_.FullName.Replace('C:',''))\AppData\Local\CrashDumps"
    #Usual
    Clean-Folder -Path "$($_.FullName.Replace('C:',''))\AppData\Local\Temp"
    #usual
    Clean-Folder -Path "$($_.FullName.Replace('C:',''))\AppData\Local\Microsoft\Windows\Temporary Internet Files"
    #Centricity Enterprise
    Clean-Folder -Path "$($_.FullName.Replace('C:',''))\AppData\Local\assembly\dl2"
    #Centricity Enterprise
    Clean-Folder -Path "$($_.FullName.Replace('C:',''))\AppData\Local\assembly\dl3"
    #usual
    Clean-Folder -Path "$($_.FullName.Replace('C:',''))\AppData\Local\assembly\tmp"
    #mytime issues
    Clean-Folder -Path "$($_.FullName.Replace('C:',''))\AppData\Local\Sun\Java\Deployment\cache\6.0"
    #Citrix Icons
    Clean-Folder -Path "$($_.FullName.Replace('C:',''))\AppData\Local\Citrix\Receiver"
    #Citrix Temp
    Clean-Folder -Path "$($_.FullName.Replace('C:',''))\AppData\Local\Citrix\SelfService\Temp"	
}

"###############################################################################"
"Current DNS Cache"
"###############################################################################"
Get-DnsClientCache

"###############################################################################"
"Clearning DNS Cache"
"###############################################################################"
Clear-DnsClientCache -Verbose

"###############################################################################"
"Attempt policy update"
"###############################################################################"
#try 
#{
	#Invoke only runs on jumpbox 
#	"MACHINE POLICY EVALUATION - $($ComputerName)"
#	Invoke-WmiMethod -Class sms_client -Namespace 'root\ccm' -ComputerName $ComputerName -Name TriggerSchedule -ArgumentList "{00000000-0000-0000-0000-000000000021}"
#	"DISCOVERY DATA - $($ComputerName)"
#	Invoke-WmiMethod -Class sms_client -Namespace 'root\ccm' -ComputerName $ComputerName -Name TriggerSchedule -ArgumentList "{00000000-0000-0000-0000-000000000003}"
#	"App Devployment - $($ComputerName)"
#	Invoke-WmiMethod -Class sms_client -Namespace 'root\ccm' -ComputerName $ComputerName -Name TriggerSchedule -ArgumentList "{00000000-0000-0000-0000-000000000121}"
#	"Hardware Inventory - $($ComputerName)"
#	Invoke-WmiMethod -Class sms_client -Namespace 'root\ccm' -ComputerName $ComputerName -Name TriggerSchedule -ArgumentList "{00000000-0000-0000-0000-000000000001}"
#	"Update Deployment - $($ComputerName)"
#	Invoke-WmiMethod -Class sms_client -Namespace 'root\ccm' -ComputerName $ComputerName -Name TriggerSchedule -ArgumentList "{00000000-0000-0000-0000-000000000108}"
#	"Update Scan - $($ComputerName)"
#	Invoke-WmiMethod -Class sms_client -Namespace 'root\ccm' -ComputerName $ComputerName -Name TriggerSchedule -ArgumentList "{00000000-0000-0000-0000-000000000113}"
#	"Software Inventory - $($ComputerName)"
#	Invoke-WmiMethod -Class sms_client -Namespace 'root\ccm' -ComputerName $ComputerName -Name TriggerSchedule -ArgumentList "{00000000-0000-0000-0000-000000000002}"
#	"Sleep for 120 seconds before running gpupdate /force"
#	Start-Sleep -s 120
#	"Running gpupdate thrice just in case"
#	"MACHINE POLICY EVALUATION - $($ComputerName)"
#	Invoke-WmiMethod -Class sms_client -Namespace 'root\ccm' -Name TriggerSchedule -ArgumentList "{00000000-0000-0000-0000-000000000021}"
	"DISCOVERY DATA - $($ComputerName)"
	Invoke-WmiMethod -Class sms_client -Namespace 'root\ccm' -Name TriggerSchedule -ArgumentList "{00000000-0000-0000-0000-000000000003}"
	"App Devployment - $($ComputerName)"
	Invoke-WmiMethod -Class sms_client -Namespace 'root\ccm' -Name TriggerSchedule -ArgumentList "{00000000-0000-0000-0000-000000000121}"
	"Hardware Inventory - $($ComputerName)"
	Invoke-WmiMethod -Class sms_client -Namespace 'root\ccm' -Name TriggerSchedule -ArgumentList "{00000000-0000-0000-0000-000000000001}"
	"Update Deployment - $($ComputerName)"
	Invoke-WmiMethod -Class sms_client -Namespace 'root\ccm' -Name TriggerSchedule -ArgumentList "{00000000-0000-0000-0000-000000000108}"
	"Update Scan - $($ComputerName)"
	Invoke-WmiMethod -Class sms_client -Namespace 'root\ccm' -Name TriggerSchedule -ArgumentList "{00000000-0000-0000-0000-000000000113}"
	"Software Inventory - $($ComputerName)"
	Invoke-WmiMethod -Class sms_client -Namespace 'root\ccm' -Name TriggerSchedule -ArgumentList "{00000000-0000-0000-0000-000000000002}"
#	"Sleep for 120 seconds before running gpupdate /force"
#	Start-Sleep -s 120
#	gpupdate /force 
#	gpupdate /force 
#	gpupdate /force 
# }
#catch
#{
#	"ERROR FORCING INVOKE-GPUPDATE"
#}
#finally
#{
#
#}
#Rundll32.exe user32.dll,LockWorkStation
"Ended"
[System.Net.DNS]::GetHostByName('')