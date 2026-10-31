@echo off
rem PaketHazirla.bat - Derlemeden ONCE calisir (dproj PreBuildEvent): programin tum dosyalarini Kaynak\Paket.zip yapar.
rem Paket.rc bu ZIP'i .exe'nin icine gomer (bkz. uPaket.pas). Tek .exe'yi baska bilgisayara kopyalamak yeter.
rem
rem Ne konur: SonDerleme.bat'in .exe'nin yanina koydugu her sey (Diller, Ikonlar, anahtar_kelimeler.txt, Stiller,
rem istemci: fbclient.dll, gbak.exe, eklentiler). Once gecici klasore (obj\paket) kopyalanir, sonra ziplenir.
rem Kullanici dosyalarina dokunmaz; yalniz kendi urettigi obj\paket ve Kaynak\Paket.zip'i yeniler.
rem
rem ICU (icu*.dll, icudt*.dat, ~30 MB) pakete konmaz: uzak sunucuya baglanan istemci icin gerekmez (olculdu, bkz.
rem ASAMA_PAKET_RAPOR.md). Gomulu (embedded) motor kullanilacaksa PAKET_ICU=1 yapin.
set KOK=%~dp0
set SAHNE=%KOK%obj\paket
set ZIP=%KOK%Kaynak\Paket.zip

if exist "%SAHNE%" rmdir /s /q "%SAHNE%"
call "%KOK%SonDerleme.bat" "%SAHNE%"
if errorlevel 1 goto :sonderleme_hata
if not "%PAKET_ICU%"=="1" del /q "%SAHNE%\istemci\icu*" 2>nul

if exist "%ZIP%" del /q "%ZIP%"
powershell -NoProfile -ExecutionPolicy Bypass -Command "Add-Type -AssemblyName System.IO.Compression.FileSystem; [System.IO.Compression.ZipFile]::CreateFromDirectory('%SAHNE%', '%ZIP%', [System.IO.Compression.CompressionLevel]::Optimal, $false)"
if not exist "%ZIP%" goto :zip_hata

rem Paket.rc'nin zamani guncellenir: Delphi .res'i yalniz .rc yenilendiyse yeniden uretir.
pushd "%KOK%Kaynak"
copy /b Paket.rc+,, >nul
popd
exit /b 0

:sonderleme_hata
echo PaketHazirla.bat : error PK001: SonDerleme.bat hata verdi, paket hazirlanamadi.
exit /b 1

:zip_hata
echo PaketHazirla.bat : error PK002: %ZIP% olusturulamadi.
exit /b 1
