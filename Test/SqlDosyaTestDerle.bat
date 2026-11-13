@echo off
rem SqlDosyaTestDerle.bat - Test\SqlDosyaTest.dpr dosyasini Win64 derler (veritabani gerekmez).
rem Calistirma: ..\bin\Win64\Release\SqlDosyaTest.exe   (istege bagli: set FBTEST_CIKTI=%TEMP%\sqldosyatest.txt)
call "C:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat"
cd /d "%~dp0"
if not exist "%TEMP%\sqldosyatest_dcu" mkdir "%TEMP%\sqldosyatest_dcu"
dcc64.exe -Q -B SqlDosyaTest.dpr -U..\Kaynak -I..\Kaynak "-NSSystem;Xml;Data;Datasnap;Web;Soap;Winapi;System.Win;Data.Win;Vcl;Vcl.Imaging;Vcl.Touch;Vcl.Samples;Vcl.Shell" -E..\bin\Win64\Release -N0%TEMP%\sqldosyatest_dcu
exit /b %errorlevel%
