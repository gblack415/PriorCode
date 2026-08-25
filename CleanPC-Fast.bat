@ECHO OFF
REM ******************************************************************************** 
REM Description: Copies the clean-up ps1 to the remote device and runs it there.
REM 10/4/13 GLB - Created
REM 06/18/22 GLB - Added remote gpupdate
REM JUMPBOX AND SLAM REQUIRED
REM ******************************************************************************** 
ipconfig /flushdns
ECHO JUMPBOX AND SLAM REQUIRED
IF "%USERNAME%"=="%USERNAME:!=%" echo ERROR Needs Runas Slam
set cleanScript=CleanPc.ps1
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
echo Cleaning on %WNUM%
TITLE Remote Clean-up on %WNUM%
set Counter=0
:pingIt
ping -n 2 %WNUM%
echo Attempt %Counter%
set /A Counter=%Counter%+1
if %Counter% gtr 5 goto :ERROR
if %errorlevel% NEQ 0 goto :pingIt

echo Copy del tmp script over
copy /Y .\%cleanScript% \\%wnum%\c$\windows\system32\

IF EXIST \\%wnum%\c$\windows\system32\%cleanScript% (
	echo "copied clean script successfully"
	powershell -Command "Invoke-Command -ComputerName %WNUM% -Scriptblock {powershell -File c:\windows\system32\%cleanScript% localhost}"
) else (
	echo "copy failed"
)

REM gpupdate works better remotely for problem devices
powershell -Command "Invoke-Command -ComputerName %WNUM% -Scriptblock {gpupdate /force}"
powershell -Command "Invoke-Command -ComputerName %WNUM% -Scriptblock {gpupdate /force}"
powershell -Command "Invoke-Command -ComputerName %WNUM% -Scriptblock {gpupdate /force}"
TIMEOUT /T 5
EXIT /B 0
:ERROR
ECHO Error device is not pingable
timeout /T 5
EXIT /B 1
