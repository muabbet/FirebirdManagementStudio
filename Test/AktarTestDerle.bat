@echo off
rem AktarTestDerle.bat - Test\AktarTest.dpr dosyasini Win64 derler; .exe bin\Win64\Release icine konur
rem (orada "istemci" klasoru ve Diller klasoru var, program ikisini de oradan yukler).
rem Gomulu (varsayilan) calistirmak icin ortam degiskeni gerekmez. Sunucuda denemek icin once ayarlayin
rem (sifre hicbir dosyaya yazilmaz; FBTEST_KLASOR SUNUCUDAKI bir klasor olmali, test orada gecici
rem veritabani acar; CSV dosyalari yine bu bilgisayarda %TEMP%\aktartest klasorune yazilir):
rem   set FBTEST_SUNUCU=localhost
rem   set FBTEST_PORT=3050
rem   set FBTEST_KLASOR=C:\Temp
rem   set FBTEST_KULLANICI=SYSDBA
rem   set FBTEST_SIFRE=...
rem   set FBTEST_CIKTI=%TEMP%\aktartest.txt
rem   set AKTAR_SATIR=100000        (istege bagli: buyuk tablonun satir sayisi)
rem   set AKTAR_MILYON=1100000      (istege bagli: ikinci, cok buyuk tablo; 1048575 ustu Excel uyarisini da dener)
rem   set AKTAR_DB_KALSIN=1         (istege bagli: gecici veritabani arsive tasinmaz, arayuzde elle denemek icin)
call "C:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat"
cd /d "%~dp0"
if not exist "%TEMP%\aktartest_dcu" mkdir "%TEMP%\aktartest_dcu"
dcc64.exe -Q -B AktarTest.dpr -U..\Kaynak -I..\Kaynak "-NSSystem;Xml;Data;Datasnap;Web;Soap;Winapi;System.Win;Data.Win;Vcl;Vcl.Imaging;Vcl.Touch;Vcl.Samples;Vcl.Shell" -E..\bin\Win64\Release -N0%TEMP%\aktartest_dcu
exit /b %errorlevel%
