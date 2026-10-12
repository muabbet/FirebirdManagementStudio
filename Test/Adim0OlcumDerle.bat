@echo off
rem Adim0OlcumDerle.bat - Test\Adim0Olcum.dpr dosyasini Win64 derler; .exe bin\Win64\Release icine konur
rem (orada "istemci" klasoru var, program fbclient.dll'i oradan yukler).
rem Calistirmadan once ortam degiskenlerini ayarlayin (sifre hicbir dosyaya yazilmaz):
rem   set FBTEST_SUNUCU=localhost
rem   set FBTEST_PORT=3050
rem   set FBTEST_YOL=C:\...\gecici_test.fdb      (SUNUCUDAKI yol; gecici/test veritabani olmali)
rem   set FBTEST_KULLANICI=SYSDBA
rem   set FBTEST_SIFRE=...
rem   set FBTEST_CIKTI=%TEMP%\olcum.txt
call "C:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat"
cd /d "%~dp0"
if not exist "%TEMP%\olcum_dcu" mkdir "%TEMP%\olcum_dcu"
dcc64.exe -Q -B Adim0Olcum.dpr -U..\Kaynak -I..\Kaynak "-NSSystem;Xml;Data;Datasnap;Web;Soap;Winapi;System.Win;Data.Win;Vcl;Vcl.Imaging;Vcl.Touch;Vcl.Samples;Vcl.Shell" -E..\bin\Win64\Release -N0%TEMP%\olcum_dcu
exit /b %errorlevel%
