@echo off
rem Dagit.bat - Derlenmis exe ile lisans dosyalarini tek zipe koyar: dagitim\FirebirdManagementStudio-SURUM-win64.zip
rem Once Derle.bat calistirilmis olmali (bin\Win64\Release\FirebirdYonetici.exe). Surum numarasi Kaynak\uUygulama.pas
rem icindeki UYGULAMA_SURUMU'nden okunur. Ayni adli eski zip silinmez, dagitim\_eski klasorune tasinir.
rem GitHub'a YUKLEME yapmaz; yukleme (Releases) sahibinin kararidir.
setlocal
cd /d "%~dp0"
if not exist "bin\Win64\Release\FirebirdYonetici.exe" (
  echo HATA: bin\Win64\Release\FirebirdYonetici.exe yok. Once Derle.bat calistirin.
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$v = [regex]::Match((Get-Content 'Kaynak\uUygulama.pas' -Raw), 'SURUMU = .([0-9.]+).').Groups[1].Value; if (-not $v) { Write-Host 'HATA: surum numarasi okunamadi'; exit 1 };" ^
  "$ad = 'FirebirdManagementStudio-' + $v + '-win64.zip'; New-Item -ItemType Directory -Force dagitim | Out-Null;" ^
  "if (Test-Path ('dagitim\' + $ad)) { New-Item -ItemType Directory -Force dagitim\_eski | Out-Null; Move-Item ('dagitim\' + $ad) ('dagitim\_eski\' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + $ad) };" ^
  "$dosyalar = 'bin\Win64\Release\FirebirdYonetici.exe','LICENSE','LISANSLAR.md','SYNEDIT_LISANS.txt';" ^
  "Compress-Archive -Path $dosyalar -DestinationPath ('dagitim\' + $ad);" ^
  "Write-Host ('Hazir: dagitim\' + $ad)"
exit /b %errorlevel%
