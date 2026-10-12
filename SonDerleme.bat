@echo off
rem SonDerleme.bat - Derleme bitince calisir (dproj PostBuildEvent).
rem Diller, Ikonlar, anahtar kelime dosyasi, tema ve Firebird istemcisini .exe'nin yanina koyar.
rem Disaridan hicbir sey silmez, sadece kopyalar.
rem
rem Diller veya Ikonlar kopyalanamazsa HATA verir ve 1 ile cikar (program bunlarsiz calismaz).
rem Firebird istemcisi veya tema dosyasi eksikse sadece UYARI basar, derleme kirilmaz.
rem "SonDerleme.bat : error/warning" bicimi MSBuild ve IDE tarafindan hata/uyari olarak gosterilir.
rem (Parantezli bloklar yerine goto kullanilir: yollarda "(x86)" gibi parantez olabilir.)
rem
rem Firebird istemcisi (Firebird 5.0, 64 bit) asagidaki klasorden alinir.
rem Baska bilgisayarda farkliysa FBKAYNAK ortam degiskenini ayarlayin ya da asagidaki satiri degistirin.
if not defined FBKAYNAK set FBKAYNAK=C:\Firebird\Firebird50_64

set KOK=%~dp0
set CIKTI=%~1
if "%CIKTI%"=="" goto :cikti_yok

xcopy /Y /I /E /Q "%KOK%Diller" "%CIKTI%\Diller\" >nul
if errorlevel 1 goto :diller_hata
xcopy /Y /I /Q "%KOK%Ikonlar\*.png" "%CIKTI%\Ikonlar\" >nul
if errorlevel 1 goto :ikonlar_hata
if exist "%KOK%anahtar_kelimeler.txt" copy /Y "%KOK%anahtar_kelimeler.txt" "%CIKTI%\" >nul
if exist "%KOK%SYNEDIT_LISANS.txt" copy /Y "%KOK%SYNEDIT_LISANS.txt" "%CIKTI%\" >nul
if exist "%KOK%LISANSLAR.md" copy /Y "%KOK%LISANSLAR.md" "%CIKTI%\" >nul

rem Acik tema (Windows10 VCL stili) RAD Studio kurulumundan alinir.
if not defined BDSCOMMONDIR goto :vsf_degisken_yok
if not exist "%BDSCOMMONDIR%\Styles\Windows10.vsf" goto :vsf_yok
if not exist "%CIKTI%\Stiller" mkdir "%CIKTI%\Stiller"
copy /Y "%BDSCOMMONDIR%\Styles\Windows10.vsf" "%CIKTI%\Stiller\" >nul
if errorlevel 1 echo SonDerleme.bat : warning SD006: Windows10.vsf kopyalanamadi. Program standart gorunumle acilir.
goto :istemci

:vsf_degisken_yok
echo SonDerleme.bat : warning SD004: BDSCOMMONDIR tanimli degil, Windows10.vsf kopyalanmadi. Program standart gorunumle acilir.
goto :istemci

:vsf_yok
echo SonDerleme.bat : warning SD005: %BDSCOMMONDIR%\Styles\Windows10.vsf bulunamadi, kopyalanmadi. Program standart gorunumle acilir.
goto :istemci

:istemci
if not exist "%FBKAYNAK%\fbclient.dll" goto :istemci_yok
if not exist "%CIKTI%\istemci" mkdir "%CIKTI%\istemci"
if not exist "%CIKTI%\istemci\plugins" mkdir "%CIKTI%\istemci\plugins"
for %%F in (fbclient.dll ib_util.dll firebird.msg zlib1.dll msvcp140.dll msvcp140_1.dll vcruntime140.dll vcruntime140_1.dll icudt63.dll icuin63.dll icuuc63.dll icudt63l.dat IDPLicense.txt IPLicense.txt) do if exist "%FBKAYNAK%\%%F" copy /Y "%FBKAYNAK%\%%F" "%CIKTI%\istemci\" >nul || echo SonDerleme.bat : warning SD008: %%F kopyalanamadi.
for %%F in (srp.dll legacy_auth.dll chacha.dll) do if exist "%FBKAYNAK%\plugins\%%F" copy /Y "%FBKAYNAK%\plugins\%%F" "%CIKTI%\istemci\plugins\" >nul || echo SonDerleme.bat : warning SD008: plugins\%%F kopyalanamadi.
xcopy /Y /I /E /Q "%FBKAYNAK%\intl" "%CIKTI%\istemci\intl\" >nul
if errorlevel 1 echo SonDerleme.bat : warning SD008: intl klasoru kopyalanamadi.
exit /b 0

:istemci_yok
echo SonDerleme.bat : warning SD007: %FBKAYNAK%\fbclient.dll bulunamadi, istemci klasoru doldurulmadi. Program veritabanina baglanamaz. FBKAYNAK degiskenini ayarlayin.
exit /b 0

:cikti_yok
echo SonDerleme.bat : error SD001: Cikti klasoru verilmedi. Kullanim: SonDerleme.bat cikti_klasoru
exit /b 1

:diller_hata
echo SonDerleme.bat : error SD002: Diller klasoru kopyalanamadi, kaynak: %KOK%Diller . Program dil dosyalari olmadan calismaz.
exit /b 1

:ikonlar_hata
echo SonDerleme.bat : error SD003: Ikonlar klasoru kopyalanamadi, kaynak: %KOK%Ikonlar . Program ikonlar olmadan acilmaz.
exit /b 1
