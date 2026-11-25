@echo off
rem EditorYorumTestDerle.bat - Test\EditorYorumTest.dpr dosyasini Win64 derler; .exe bin\Win64\Release icine konur.
rem Veritabani gerekmez. Calistirinca sonucu ekrana yazar (FBTEST_CIKTI verilirse o dosyaya).
call "C:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat"
cd /d "%~dp0"
if not exist "%TEMP%\editortest_dcu" mkdir "%TEMP%\editortest_dcu"
rem SynEdit kaynak klasoru (uEditor kullanir). Baska yerdeyse asagidaki yolu degistirin.
set SYNEDIT=C:\Baris\Componnt\Ortak\SynEdit\Source
dcc64.exe -Q -B EditorYorumTest.dpr "-U..\Kaynak;%SYNEDIT%;%SYNEDIT%\Highlighters" "-I..\Kaynak;%SYNEDIT%" "-NSSystem;Xml;Data;Datasnap;Web;Soap;Winapi;System.Win;Data.Win;Vcl;Vcl.Imaging;Vcl.Touch;Vcl.Samples;Vcl.Shell" -E..\bin\Win64\Release -N0%TEMP%\editortest_dcu
exit /b %errorlevel%
