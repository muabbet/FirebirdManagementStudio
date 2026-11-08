@echo off
rem SorguGecmisiTestDerle.bat - Test\SorguGecmisiTest.dpr dosyasini Win64 derler (veritabani gerekmez).
rem Calistirma: ..\bin\Win64\Release\SorguGecmisiTest.exe   (istege bagli: set FBTEST_CIKTI=%TEMP%\gecmistest.txt)
call "C:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat"
cd /d "%~dp0"
if not exist "%TEMP%\gecmistest_dcu" mkdir "%TEMP%\gecmistest_dcu"
dcc64.exe -Q -B SorguGecmisiTest.dpr -U..\Kaynak -I..\Kaynak "-NSSystem;Xml;Data;Datasnap;Web;Soap;Winapi;System.Win;Data.Win;Vcl;Vcl.Imaging;Vcl.Touch;Vcl.Samples;Vcl.Shell" -E..\bin\Win64\Release -N0%TEMP%\gecmistest_dcu
exit /b %errorlevel%
