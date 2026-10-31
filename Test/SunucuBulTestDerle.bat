@echo off
rem SunucuBulTestDerle.bat - Test\SunucuBulTest.dpr dosyasini Win64 derler; .exe bin\Win64\Release icine konur.
rem Calistirma: $env:FBTEST_CIKTI = "$env:TEMP\sunucubul.txt"; .\bin\Win64\Release\SunucuBulTest.exe; Get-Content $env:FBTEST_CIKTI
rem (Bu bilgisayarda 3050-3069 portlarinda calisan Firebird sunuculari listelenir.)
call "C:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat"
cd /d "%~dp0"
if not exist "%TEMP%\sunucubul_dcu" mkdir "%TEMP%\sunucubul_dcu"
dcc64.exe -Q -B SunucuBulTest.dpr "-U..\Kaynak" "-NSSystem;Winapi" -E..\bin\Win64\Release -N0%TEMP%\sunucubul_dcu
exit /b %errorlevel%
