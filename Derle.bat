@echo off
rem Derle.bat - RAD Studio 12 ile Win64 Release derlemesi (komut satirindan).
rem IDE kullaniyorsaniz bu dosyaya gerek yok; Kaynak\FirebirdYonetici.dproj'u acip derleyin.
rem Once PaketHazirla.bat: dil, ikon, tema ve Firebird istemcisi Kaynak\Paket.zip olur ve .exe'nin icine gomulur
rem (tek .exe yeter, bkz. Kaynak\uPaket.pas). IDE'de derlerseniz paket bir SONRAKI derlemede guncel olur; dosyalar
rem degistiyse once bu dosyayi ya da PaketHazirla.bat'i calistirin.
rem rsvars.bat BDSCOMMONDIR'i tanimlar (tema dosyasi oradan alinir); PaketHazirla'dan once cagrilmali.
call "C:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat"
call "%~dp0PaketHazirla.bat"
if errorlevel 1 exit /b 1
cd /d "%~dp0Kaynak"
msbuild FirebirdYonetici.dproj /t:Rebuild /p:Config=Release /p:Platform=Win64 /v:minimal /nologo
exit /b %errorlevel%
