@echo off
rem SorguSekmeKaydetTestDerle.bat - Test\SorguSekmeKaydetTest.dpr dosyasini Win64 derler (veritabani gerekmez).
rem Calistirma: ..\bin\Win64\Release\SorguSekmeKaydetTest.exe   (istege bagli: set FBTEST_CIKTI=%TEMP%\sqlkaydet.txt)
call "C:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat"
cd /d "%~dp0"
if not exist "%TEMP%\sqlkaydettest_dcu" mkdir "%TEMP%\sqlkaydettest_dcu"
set SYNEDIT=C:\Baris\Componnt\Ortak\SynEdit\Source
dcc64.exe -Q -B SorguSekmeKaydetTest.dpr "-U..\Kaynak;%SYNEDIT%;%SYNEDIT%\Highlighters" "-I..\Kaynak;%SYNEDIT%" "-NSSystem;Xml;Data;Datasnap;Web;Soap;Winapi;System.Win;Data.Win;Vcl;Vcl.Imaging;Vcl.Touch;Vcl.Samples;Vcl.Shell" -E..\bin\Win64\Release -N0%TEMP%\sqlkaydettest_dcu
exit /b %errorlevel%
