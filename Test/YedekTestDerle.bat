@echo off
rem YedekTestDerle.bat - Test\YedekTest.dpr dosyasini Win64 derler; .exe bin\Win64\Release icine konur
rem (orada "istemci" klasoru ve Diller klasoru var, program ikisini de oradan yukler).
rem Gomulu (varsayilan) calistirmak icin ortam degiskeni gerekmez. Sunucuda denemek icin once ayarlayin
rem (sifre hicbir dosyaya yazilmaz; FBTEST_KLASOR SUNUCUDAKI bir klasor olmali, test orada gecici
rem veritabani acar; .fbk dosyalari yine bu bilgisayarda %TEMP%\yedektest klasorune yazilir):
rem   set FBTEST_SUNUCU=localhost
rem   set FBTEST_PORT=3050
rem   set FBTEST_KLASOR=C:\Temp
rem   set FBTEST_KULLANICI=SYSDBA
rem   set FBTEST_SIFRE=...
rem   set FBTEST_CIKTI=%TEMP%\yedektest.txt
rem   set YEDEK_SATIR=300000        (istege bagli: iptal testindeki buyuk tablonun satir sayisi)
call "C:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat"
cd /d "%~dp0"
if not exist "%TEMP%\yedektest_dcu" mkdir "%TEMP%\yedektest_dcu"
dcc64.exe -Q -B YedekTest.dpr -U..\Kaynak -I..\Kaynak "-NSSystem;Xml;Data;Datasnap;Web;Soap;Winapi;System.Win;Data.Win;Vcl;Vcl.Imaging;Vcl.Touch;Vcl.Samples;Vcl.Shell" -E..\bin\Win64\Release -N0%TEMP%\yedektest_dcu
exit /b %errorlevel%
