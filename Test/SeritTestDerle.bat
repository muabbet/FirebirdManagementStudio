@echo off
rem SeritTestDerle.bat - Test\SeritTest.dpr dosyasini Win64 derler; .exe bin\Win64\Release icine konur.
rem Calistirinca %TEMP% (ya da SERITTEST_KLASOR) icine seritTest.txt ve uc dilde PNG yazar.
call "C:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat"
cd /d "%~dp0"
if not exist "%TEMP%\seritTest_dcu" mkdir "%TEMP%\seritTest_dcu"
dcc64.exe -Q -B SeritTest.dpr -U..\Kaynak -I..\Kaynak "-NSSystem;Xml;Data;Datasnap;Web;Soap;Winapi;System.Win;Data.Win;Vcl;Vcl.Imaging;Vcl.Touch;Vcl.Samples;Vcl.Shell" -E..\bin\Win64\Release -N0%TEMP%\seritTest_dcu
exit /b %errorlevel%
