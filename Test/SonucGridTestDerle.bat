@echo off
rem SonucGridTestDerle.bat - Test\SonucGridTest.dpr dosyasini Win64 derler; .exe bin\Win64\Release icine konur.
rem Veritabani gerekmez (bellekte tablo). Calistirinca sonucu ekrana yazar (FBTEST_CIKTI verilirse o dosyaya).
call "C:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat"
cd /d "%~dp0"
if not exist "%TEMP%\sonucgridtest_dcu" mkdir "%TEMP%\sonucgridtest_dcu"
rem SynEdit kaynak klasoru (derleme yolu icin). Baska yerdeyse asagidaki yolu degistirin.
set SYNEDIT=C:\Baris\Componnt\Ortak\SynEdit\Source
dcc64.exe -Q -B SonucGridTest.dpr "-U..\Kaynak;%SYNEDIT%;%SYNEDIT%\Highlighters" "-I..\Kaynak;%SYNEDIT%" "-NSSystem;Xml;Data;Datasnap;Web;Soap;Winapi;System.Win;Data.Win;Vcl;Vcl.Imaging;Vcl.Touch;Vcl.Samples;Vcl.Shell" -E..\bin\Win64\Release -N0%TEMP%\sonucgridtest_dcu
exit /b %errorlevel%
