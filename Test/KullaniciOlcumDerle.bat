@echo off
rem KullaniciOlcumDerle.bat - Test\KullaniciOlcum.dpr dosyasini Win64 derler; .exe bin\Win64\Release icine konur
rem (orada "istemci" klasoru var, program fbclient.dll'i oradan yukler).
rem Program VARSAYILAN olarak yalnizca OKUR. Ortam degiskenleri (sifre hicbir dosyaya yazilmaz):
rem   FBTEST_SUNUCU    bos = gomulu; ornek 127.0.0.1
rem   FBTEST_PORT      ornek 3052
rem   FBTEST_YOL       sunucudaki VAR OLAN veritabani yolu (gomulu kipte bos birakilirsa gecici veritabani acilir)
rem   FBTEST_KULLANICI SYSDBA
rem   FBTEST_SIFRE     ...
rem   FBTEST_CIKTI     tam dosya yolu, ornek %TEMP%\kullaniciolcum.txt
rem   FBTEST_YAZMA     1 = yazma bolumu (FBY_TEST olustur/sifre/GRANT/REVOKE/sil); yalniz yerel sunucuda port 3052
rem                    veya 3053 iken ya da gomulu kipte kendi gecici veritabaninda calisir; 3050/3051 reddedilir
rem PowerShell'de ortam degiskeni:  $env:FBTEST_PORT = "3052"     (cmd'deki "set" PowerShell'de calismaz)
call "C:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat"
cd /d "%~dp0"
if not exist "%TEMP%\kulolcum_dcu" mkdir "%TEMP%\kulolcum_dcu"
dcc64.exe -Q -B KullaniciOlcum.dpr -U..\Kaynak -I..\Kaynak "-NSSystem;Xml;Data;Datasnap;Web;Soap;Winapi;System.Win;Data.Win;Vcl;Vcl.Imaging;Vcl.Touch;Vcl.Samples;Vcl.Shell" -E..\bin\Win64\Release -N0%TEMP%\kulolcum_dcu
exit /b %errorlevel%
