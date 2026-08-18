@ECHO OFF
REM ********************************************************************************
REM Descrption: REBOOT AT 2AM
REM GLB CREATED
REM REQUIRES SLAM
REM ********************************************************************************
time /T
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
IF %ERRORLEVEL% neq 0 GOTO ERROR
TITLE Delay Reboot on %WNUM%

set hour=%time:~0,2%
IF "%hour:~0,1%" == " " set hour=0%hour:~1,1%
echo %hour%

set min=%time:~3,2%
IF "%min:~0,1%" == " " set hour=0%min:~1,1%
echo %min%

IF %hour% leq 2 set /A hours = 2 - %hour%
IF %hour% geq 2 IF %hour% leq 24 set /A hours = 26 - %hour%
set /A DURATIONhour = %hours% * 3600 + %min% * 60 
IF "%WNUM%"=="" GOTO ERROR
echo shutting down %WNUM%
echo SHUTDOWN DELAY:%DURATIONhour%
shutdown /r /m \\%WNUM% /t %DURATIONhour% /c "Misc Windows Issue"
IF EXIST "recordAction.exe" recordAction.exe %WNUM% REBOOT

timeout /T 5
EXIT /B 0
:ERROR
ECHO Error device is not pingable
timeout /T 5