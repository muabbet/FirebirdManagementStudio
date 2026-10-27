@echo off
rem KullaniciTestDerle.bat - Test\KullaniciTest.dpr dosyasini Win64 derler; .exe bin\Win64\Release icine konur
rem (orada "istemci" ve "Diller" klasorleri var, program ikisini de oradan yukler).
rem Gomulu (varsayilan, FBTEST_SUNUCU bos) calistirmak icin ortam degiskeni gerekmez; kendi gecici veritabanini acar.
rem Sunucuda calistirmak icin once ayarlayin (sifre hicbir dosyaya yazilmaz):
rem   FBTEST_SUNUCU    ornek 127.0.0.1
rem   FBTEST_PORT      ornek 3052
rem   FBTEST_YOL       sunucudaki VAR OLAN veritabani yolu
rem   FBTEST_KULLANICI SYSDBA
rem   FBTEST_SIFRE     ...
rem   FBTEST_CIKTI     tam dosya yolu, ornek %TEMP%\kullanicitest.txt
rem   FBTEST_YAZMA     1 = yazma bolumu (test kullanicilari FBY_TEST3D* ekle/sifre/sil...). Yalniz yerel sunucuda
rem                    port 3052, 3053 veya 3054 iken calisir; 3050/3051 dahil baska portta kod reddeder. Okuma her yerde.
rem PowerShell'de ortam degiskeni:  $env:FBTEST_PORT = "3052"     (cmd'deki "set" PowerShell'de calismaz)
call "C:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat"
cd /d "%~dp0"
if not exist "%TEMP%\kullanicitest_dcu" mkdir "%TEMP%\kullanicitest_dcu"
dcc64.exe -Q -B KullaniciTest.dpr -U..\Kaynak -I..\Kaynak "-NSSystem;Xml;Data;Datasnap;Web;Soap;Winapi;System.Win;Data.Win;Vcl;Vcl.Imaging;Vcl.Touch;Vcl.Samples;Vcl.Shell" -E..\bin\Win64\Release -N0%TEMP%\kullanicitest_dcu
exit /b %errorlevel%
