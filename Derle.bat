@echo off
rem Derle.bat - RAD Studio 12 ile Win64 Release derlemesi (komut satirindan).
rem IDE kullaniyorsaniz bu dosyaya gerek yok; Kaynak\FirebirdYonetici.dproj'u acip derleyin.
call "C:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat"
cd /d "%~dp0Kaynak"
msbuild FirebirdYonetici.dproj /t:Rebuild /p:Config=Release /p:Platform=Win64 /v:minimal /nologo
exit /b %errorlevel%
