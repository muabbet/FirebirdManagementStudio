@echo off
rem TetikleyiciDurumTestDerle.bat - Test\TetikleyiciDurumTest.dpr dosyasini Win64 derler; .exe bin\Win64\Release icine konur
rem (orada "istemci" klasoru var, program fbclient.dll'i oradan yukler).
rem Calistirmadan once ortam degiskenlerini ayarlayin (sifre hicbir dosyaya yazilmaz):
rem   set FBTEST_SUNUCU=localhost
rem   set FBTEST_PORT=3050
rem   set FBTEST_KLASOR=C:\...\test klasoru   (SUNUCUDAKI klasor; gecici veritabani buraya kurulur)
rem   set FBTEST_KULLANICI=SYSDBA
rem   set FBTEST_SIFRE=...
rem   set FBTEST_CIKTI=%TEMP%\tetikdurumtest.txt
call "C:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat"
cd /d "%~dp0"
if not exist "%TEMP%\tetikdurumtest_dcu" mkdir "%TEMP%\tetikdurumtest_dcu"
dcc64.exe -Q -B TetikleyiciDurumTest.dpr -U..\Kaynak -I..\Kaynak "-NSSystem;Xml;Data;Datasnap;Web;Soap;Winapi;System.Win;Data.Win;Vcl;Vcl.Imaging;Vcl.Touch;Vcl.Samples;Vcl.Shell" -E..\bin\Win64\Release -N0%TEMP%\tetikdurumtest_dcu
exit /b %errorlevel%
