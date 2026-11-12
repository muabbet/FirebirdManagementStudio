@echo off
rem BaglantiDosyasiTestDerle.bat - Test\BaglantiDosyasiTest.dpr dosyasini Win64 derler; .exe bin\Win64\Release icine konur
rem (orada Diller klasoru var). Calistirma: BaglantiDosyasiTest.exe <gecici_klasor> <cikti.txt>
rem Gecici klasor gercek kayitli baglantilara dokunmaz (VeriKlasoruAyarla).
call "C:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat"
cd /d "%~dp0"
if not exist "%TEMP%\baglantidosyasitest_dcu" mkdir "%TEMP%\baglantidosyasitest_dcu"
dcc64.exe -Q -B BaglantiDosyasiTest.dpr -U..\Kaynak -I..\Kaynak "-NSSystem;Xml;Data;Datasnap;Web;Soap;Winapi;System.Win;Data.Win;Vcl;Vcl.Imaging;Vcl.Touch;Vcl.Samples;Vcl.Shell" -E..\bin\Win64\Release -N0%TEMP%\baglantidosyasitest_dcu
exit /b %errorlevel%
