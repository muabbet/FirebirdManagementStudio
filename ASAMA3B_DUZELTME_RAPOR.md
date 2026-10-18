# Aşama 3b düzeltme raporu: sunucu kipinde geçici veritabanı

Dal: `asama3b-duzeltme` (`asama3b-csv` a08cf54'ten açıldı, ayrı git worktree'de: `..\FirebirdYonetici_duzeltme`; sizin klasörünüze, `bin` çıktısına ve `main`/`asama3c`'ye dokunulmadı). GitHub'a itilmedi, PR yok. `CLAUDE.md` kutuları işaretlenmedi.

## Ne değişti

- `Test\AktarTest.dpr` (satır 70-76) ve `Test\DDLTest.dpr` (satır 67-73), `GeciciVeritabaniOlustur`: `Tanim.Sunucu` doluysa `Server`, `Port` (`IntToStr(Tanim.Port)`) ve `Protocol = 'TCPIP'` parametreleri verilir. Boşsa hiçbir şey eklenmez, gömülü kip eskisi gibi. Başka değişiklik yok (her dosyada +7 satır).
- **Kod okuması:** `uBaglanti.FbBaglan` (satır 569-574) aynı üç parametreyi, aynı koşulla (`Sunucu <> ''`) veriyor; artık oluşturma ve bağlanma aynı yere gider.
- **Diğer testler (yalnızca okundu, dokunulmadı):** `SorguTest` zaten `Sunucu <> ''` iken veritabanı oluşturmayı atlıyor (var olan `FBTEST_YOL`'a bağlanır), sorun yok. `MetadataTest` ve `Adim0Olcum` veritabanı oluşturmuyor, sorun yok.

## Gömülü kipte doğrulama

`AktarTest` **70 kontrol, hata 0**; `DDLTest` **146 OK, hata 0**. Yani gömülü kipte bozulmadı.

## Sunucu kipi: sahibi deneyecek

Sunucu kipini ben çalıştıramadım (şifre bende yok); düzeltmenin sunucuda işe yaradığını **henüz göstermedim**, yalnızca parametrelerin `FbBaglan` ile eşleştiğini kod okumasıyla kontrol ettim. Komutlar (2.5.9/3050; 5.0.4 için port 3051 ve çıktı adı):
```
Test\AktarTestDerle.bat
Test\DDLTestDerle.bat
set FBTEST_SUNUCU=localhost
set FBTEST_PORT=3050
set FBTEST_KLASOR=C:\Temp
set FBTEST_KULLANICI=SYSDBA
set FBTEST_SIFRE=...
set FBTEST_CIKTI=%TEMP%\aktartest_259.txt
bin\Win64\Release\AktarTest.exe
set FBTEST_CIKTI=%TEMP%\ddltest_259.txt
bin\Win64\Release\DDLTest.exe
```
`FBTEST_KLASOR` sunucudaki bir klasör olmalı. 2.5.9'da bu testlerin bazı satırları 2.5'e özgü fark gösterebilir (önceki raporlarda belirtildiği gibi, orada hiç koşulmadı).
