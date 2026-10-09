@echo off
rem SonDerleme.bat - Derleme bitince calisir (dproj PostBuildEvent).
rem Diller, Ikonlar, anahtar kelime dosyasi ve Firebird istemcisini .exe'nin yanina koyar.
rem Disaridan hicbir sey silmez, sadece kopyalar.
rem
rem Firebird istemcisi (Firebird 5.0, 64 bit) asagidaki klasorden alinir.
rem Baska bilgisayarda farkliysa sadece bu satiri degistirin.
set FBKAYNAK=C:\Firebird\Firebird50_64

set KOK=%~dp0
set CIKTI=%~1
if "%CIKTI%"=="" (
  echo Kullanim: SonDerleme.bat ^<cikti klasoru^>
  exit /b 1
)

xcopy /Y /I /E /Q "%KOK%Diller" "%CIKTI%\Diller\" >nul
xcopy /Y /I /Q "%KOK%Ikonlar\*.png" "%CIKTI%\Ikonlar\" >nul
rem Acik tema (Windows10 VCL stili) RAD Studio kurulumundan alinir.
if exist "%BDSCOMMONDIR%\Styles\Windows10.vsf" (
  if not exist "%CIKTI%\Stiller" mkdir "%CIKTI%\Stiller"
  copy /Y "%BDSCOMMONDIR%\Styles\Windows10.vsf" "%CIKTI%\Stiller\" >nul
)
if exist "%KOK%anahtar_kelimeler.txt" copy /Y "%KOK%anahtar_kelimeler.txt" "%CIKTI%\" >nul

if not exist "%FBKAYNAK%\fbclient.dll" (
  echo UYARI: %FBKAYNAK%\fbclient.dll bulunamadi. istemci klasoru doldurulmadi.
  exit /b 0
)
if not exist "%CIKTI%\istemci" mkdir "%CIKTI%\istemci"
if not exist "%CIKTI%\istemci\plugins" mkdir "%CIKTI%\istemci\plugins"
for %%F in (fbclient.dll ib_util.dll firebird.msg zlib1.dll msvcp140.dll msvcp140_1.dll vcruntime140.dll vcruntime140_1.dll icudt63.dll icuin63.dll icuuc63.dll icudt63l.dat IDPLicense.txt IPLicense.txt) do (
  if exist "%FBKAYNAK%\%%F" copy /Y "%FBKAYNAK%\%%F" "%CIKTI%\istemci\" >nul
)
for %%F in (srp.dll legacy_auth.dll chacha.dll) do (
  if exist "%FBKAYNAK%\plugins\%%F" copy /Y "%FBKAYNAK%\plugins\%%F" "%CIKTI%\istemci\plugins\" >nul
)
xcopy /Y /I /E /Q "%FBKAYNAK%\intl" "%CIKTI%\istemci\intl\" >nul
exit /b 0
