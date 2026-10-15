@echo off
rem DDLTestDerle.bat - Test\DDLTest.dpr dosyasini Win64 derler; .exe bin\Win64\Release icine konur
rem (orada "istemci" klasoru ve anahtar_kelimeler.txt var, program ikisini de oradan yukler).
rem Gomulu (varsayilan) calistirmak icin ortam degiskeni gerekmez. Sunucuda denemek icin once ayarlayin
rem (sifre hicbir dosyaya yazilmaz; FBTEST_KLASOR SUNUCUDAKI bir klasor olmali, test orada gecici
rem veritabanlari acar):
rem   set FBTEST_SUNUCU=localhost
rem   set FBTEST_PORT=3050
rem   set FBTEST_KLASOR=C:\Temp
rem   set FBTEST_KULLANICI=SYSDBA
rem   set FBTEST_SIFRE=...
rem   set FBTEST_CIKTI=%TEMP%\ddltest.txt
rem   set FBTEST_SCRIPTLER=%TEMP%\ddlscriptler     (istege bagli: uretilen script'ler buraya yazilir)
call "C:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat"
cd /d "%~dp0"
if not exist "%TEMP%\ddltest_dcu" mkdir "%TEMP%\ddltest_dcu"
dcc64.exe -Q -B DDLTest.dpr -U..\Kaynak -I..\Kaynak "-NSSystem;Xml;Data;Datasnap;Web;Soap;Winapi;System.Win;Data.Win;Vcl;Vcl.Imaging;Vcl.Touch;Vcl.Samples;Vcl.Shell" -E..\bin\Win64\Release -N0%TEMP%\ddltest_dcu
exit /b %errorlevel%
