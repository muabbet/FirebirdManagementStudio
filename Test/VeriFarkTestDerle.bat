@echo off
rem VeriFarkTestDerle.bat - Test\VeriFarkTest.dpr dosyasini Win64 derler; .exe bin\Win64\Release icine konur
rem (orada "istemci" klasoru ve Diller klasoru var, program ikisini de oradan yukler).
call "C:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat"
cd /d "%~dp0"
if not exist "%TEMP%\VeriFarkTest_dcu" mkdir "%TEMP%\VeriFarkTest_dcu"
dcc64.exe -Q -B VeriFarkTest.dpr -U..\Kaynak -I..\Kaynak "-NSSystem;Xml;Data;Datasnap;Web;Soap;Winapi;System.Win;Data.Win;Vcl;Vcl.Imaging;Vcl.Touch;Vcl.Samples;Vcl.Shell" -E..\bin\Win64\Release -N0%TEMP%\VeriFarkTest_dcu
exit /b %errorlevel%
