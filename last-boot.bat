@ECHO OFF
REM ********************************************************************************
REM Description: Queries remote device for info
REM 02/23/19 glb created
REM 01/21/22 glb added check for phprint.txt
REM 08/02/22 glb added error check with suggestion
REM 02/13/23 glb added more error checking for dupe ip
REM TODO ADD WMIC PATCHES INSTALLED, JOBS STORED LOCALLY IN SPOOLER AND BETTER EVENTS
REM ********************************************************************************
:START
SET "WNUM="
SET  WNUM=%1
IF "%WNUM%" NEQ "" GOTO GOTP1
IF EXIST c:\users\%username%\desktop\wnum.txt SET /p WNUM=<c:\users\%username%\desktop\wnum.txt
:GOTP1
IF "%WNUM%" NEQ "" GOTO SKIP
SET /P WNUM=Please enter a W#: 
IF "%WNUM%"=="" GOTO ERROR
GOTO SKIP
:SKIP
ping %WNUM% -n 1
if %ERRORLEVEL% NEQ 0 GOTO ERROR
TITLE LastBoot on %WNUM%
echo ###############################################################################
SET HASACTIVE=0
SET HASWNUM=0
SET ESESSION=0
ECHO Querying: %WNUM%
query user /server:%WNUM% | findstr /i /R "Active" > nul
IF %ERRORLEVEL% EQU 0 SET HASACTIVE=1
query user /server:%WNUM% | findstr /i /R %WNUM% > nul
IF %ERRORLEVEL% EQU 0 SET HASWNUM=1
query user /server:%WNUM%
SET HASERROR=0
REM ERROR IS TWO LINES AND MESSES WITH FINDSTR
IF %HASWNUM% EQU 0 IF %HASACTIVE% EQU 0 query user /server:%WNUM% 2>&1 | findstr /i /R "enumerating"  | findstr /i /R "enumerating"
IF %ERRORLEVEL% EQU 0 SET ESESSION=1
IF %ESESSION% NEQ 0 GOTO FOUNDERROR
ECHO ###############################################################################
SET UDAYS=
REM $env:days = (get-date) - (gcim Win32_OperatingSystem).LastBootUpTime | foreach {$_.Days}
REM $dork2 = (get-date) - (get-ciminstance Win32_OperatingSystem).LastBootUpTime | foreach {$_.Days}
REM powershell -Command "($env:udays = (get-date) - (get-ciminstance -computername $env:wnum Win32_OperatingSystem).LastBootUpTime | foreach {$_.Days})"
REM powershell -Command "($env:udays = (get-date) - (get-ciminstance -computername $env:wnum Win32_OperatingSystem).LastBootUpTime | foreach {$_.Days})"
REM powershell -Command "($env:udays = (get-date) - (get-ciminstance -computername $env:wnum Win32_OperatingSystem).LastBootUpTime | foreach {$_.Days -replace '`r','' -replace '`n',''})"
REM powershell -Command "($udays = (get-date) - (get-ciminstance -computername $env:wnum Win32_OperatingSystem).LastBootUpTime | foreach {$_.Days}); 
REM $env:udays= [int32]$udayz"powershell -Command "($env:udays = (get-date) - (get-ciminstance -computername $env:wnum -classname Win32_OperatingSystem).LastBootUpTime | foreach {$_.Days})"
REM powershell -Command "($udays = (get-date) - (get-ciminstance -computername $env:wnum Win32_OperatingSystem).LastBootUpTime | foreach {$_.Days}); $env:udays= [int32]$udayz"powershell -Command "($env:udays = (get-date) - (get-ciminstance -computername $env:wnum Win32_OperatingSystem).LastBootUpTime | select $_.Days)"
REM set /a uday = %UDAYS% * 1
REM IF %UDAYS% GEQ 14 echo REBOOT
powershell -Command "try {(Get-WmiObject -computername $env:wnum win32_operatingsystem | select csname,caption, @{LABEL='LastBootUpTime';EXPRESSION={$_.ConverttoDateTime($_.lastbootuptime)}}, @{LABEL='Up Days';EXPRESSION={NEW-TIMESPAN -Start $_.ConverttoDateTime($_.lastbootuptime) -End (GET-DATE)}}| Out-String).Trim()} catch{exit 1} "
IF %ERRORLEVEL% NEQ 0 GOTO FOUNDERROR
ECHO ###############################################################################
powershell -Command "(Get-WmiObject -computername $env:wnum win32_timezone | select caption | Out-String).Trim()"
REM if %ERRORLEVEL% NEQ 0 SET HASERROR=1
IF %ERRORLEVEL% NEQ 0 GOTO FOUNDERROR
ECHO ###############################################################################
powershell -Command "(Get-WmiObject -computername $env:wnum Win32_logicaldisk | select DeviceId, ProviderName,@{Name='Size(GB)';Expression={[decimal]('{0:N0}' -f($_.size/1gb))}},@{Name='Free (GB)';Expression={[decimal]('{0:N0}' -f($_.freespace/1gb))}}, @{Name='Free (%%)';Expression={'{0,6:P0}' -f(($_.freespace/1gb) / ($_.size/1gb))}} | Format-Table -auto| Out-String).Trim()  "
IF %ERRORLEVEL% NEQ 0 GOTO FOUNDERROR
REM if %ERRORLEVEL% NEQ 0 SET HASERROR=1
ECHO ###############################################################################
REM sc \\%WNUM% query spooler
REM powershell -Command "(Get-service spooler -ComputerName $env:wnum | select displayname,@{LABEL='Spooler Status';Expression={'{0}' -f $_.status }}| Out-String).Trim()"
REM IF EXIST \\%WNUM%\c$\windows\phprint.txt (
REM     echo 'phprint.txt exists'
REM )
powershell -Command "Get-WmiObject -computername $env:wnum Win32_quickfixengineering | Sort-Object InstalledOn -Descending | Format-Table -auto"
REM if %ERRORLEVEL% NEQ 0 SET HASERROR=1
IF %ERRORLEVEL% NEQ 0 GOTO FOUNDERROR
ECHO ###############################################################################
powershell -Command "(Get-EventLog -Logname System -Newest 10 -ComputerName $env:wnum | Out-String).Trim()"
REM if %ERRORLEVEL% NEQ 0 SET HASERROR=1
IF %ERRORLEVEL% NEQ 0 GOTO FOUNDERROR
ECHO ###############################################################################
:FOUNDERROR
ECHO Current Time:%DATE% %TIME%
REM NEED TO DETECT ERROR AND SUGGEST THE FOLLOWING
REM IF %HASACTIVE% NEQ 0 echo Has Active User
REM IF %HASWNUM% NEQ 0 echo Has WNum User
IF %HASWNUM% EQU 0 IF %HASACTIVE% EQU 0 echo [32m###########-NO ACTIVE USERS-############[0m
IF %HASWNUM% EQU 0 IF %HASACTIVE% NEQ 0 echo [7;31m###########-ACTIVE USERS!!!-############[0m
IF %HASWNUM% NEQ 0 IF %HASACTIVE% NEQ 0 echo [94mActive W#, remote to confirm[0m
IF %ERRORLEVEL% NEQ 0 echo Suggestion: smc-cmr.bat %WNUM%
IF %ERRORLEVEL% EQU 0 echo Suggestion: remote-conf-man.bat %WNUM%
IF %ESESSION% NEQ 0 echo Suggestion: powershell -file dump-dhcp.ps1 %WNUM%
ECHO.
REM powershell -Command "(resolve-dnsname $env:wnum | Out-String).Trim()"
REM powershell -Command "[Net.DNS]::GetHostEntry([Net.DNS]::GetHostEntry($env:wnum).AddressList.IPAddressToString)"
REM Name                                           Type   TTL   Section    IPAddress
REM ----                                           ----   ---   -------    ---------
REM W005264.peacehealth.org                        A      1200  Answer     172.26.204.210
REM Name                           Type   TTL   Section    NameHost
REM ----                           ----   ---   -------    --------
REM 210.204.26.172.in-addr.arpa    PTR    1200  Answer     w019446.peacehealth.org

REM IF %HASERROR% NEQ 0 sc \\%WNUM% query gpsvc
REM IF %HASERROR% EQU 0 timeout /t 100
EXIT /B 0
:ERROR
ECHO Error device is not pingable
timeout /T 5
