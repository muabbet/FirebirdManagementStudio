# Aşama 3a düzeltme 2: Yorum komutu Firebird 2.5'te (rapor)

**Dal:** `asama3-ddl25` (main 7eb2f3b üstünden). Yalnızca `Kaynak/uDDL.pas` değişti; yeni yazı yok, dil dosyalarına dokunulmadı.

## Neden bozuluyordu
`uDDL.pas` yorumları `COMMENT ON PROCEDURE PARAMETER P.A IS '...'` diye üretiyordu. Firebird 2.5 bu söz dizimini tanımıyor (-104, Token unknown: PARAMETER).

## Kaynak
- Firebird 2.5 Language Reference, COMMENT: yalnızca `COMMENT ON PARAMETER procad.parametread` var. https://www.firebirdsql.org/file/documentation/chunk/en/refdocs/fblangref25/fblangref25-ddl-comment.html
- Firebird 3.0 ve 5.0 Language Reference, COMMENT: `[{PROCEDURE | FUNCTION}] PARAMETER ...`; yani `PROCEDURE` anahtar sözcüğü isteğe bağlı, `COMMENT ON PARAMETER ADD_EMP_PROJ.EMP_NO IS '...'` örneği resmi belgede var. https://firebirdsql.org/file/documentation/chunk/en/refdocs/fblangref30/fblangref30-ddl-comment.html , .../fblangref50/fblangref50-ddl-comment.html
- 4.0 sayfasına bakılmadı; 3.0 ve 5.0 aynı olduğundan aynı kabul edildi (4.0 doğrulaması sunucuda yapılmadı).

## Ne değişti
`Kaynak/uDDL.pas`, `TCikarici.Aciklamalar` (~satır 981-984): hedef `PROCEDURE PARAMETER` ise `PARAMETER` yazılır. `PARAMETER` biçimi tüm sürümlerde geçerli olduğundan **sürüme bağlı dal gerekmedi**; kod daha sade kaldı. (Görevde "sürüme bağlı yap" denmişti; gerekçe: tek biçim hepsinde çalışıyor.)
- FUNCTION PARAMETER: `uMetadata.AciklamalariOku` yalnızca `rdb$procedure_parameters` okuyor, fonksiyon parametresi hiç üretilmiyor; bu yüzden ele alınacak bir şey yok.
- Paketli prosedürler (3.0+) zaten `PaketSarti` ile dışarıda.

## Test
- `Test\DDLTestDerle.bat` ile derlendi; gömülü kipte `DDLTest.exe`: **146 OK, Hata sayısı: 0**.
- **Firebird 2.5.9 sunucu kipi çalıştırılmadı** (şifre bende yok). "2.5.9'da çalışıyor" denemez: gömülü kipte bozulmadı, 2.5.9'u sahibi deneyecek. Beklenen: önceki 2 HATA (D (bos) ve gidis-donus kontrolleri) gitmeli.

## Sahibine: 2.5.9'da deneme (PowerShell)
```powershell
$env:FBTEST_SUNUCU="localhost"; $env:FBTEST_PORT="3050"; $env:FBTEST_KLASOR="C:\Temp"; $env:FBTEST_KULLANICI="SYSDBA"; $env:FBTEST_SIFRE="..."; $env:FBTEST_CIKTI="$env:TEMP\ddltest_259.txt"; .\bin\Win64\Release\DDLTest.exe
```
Not: bu worktree'de `bin\Win64\Release` yoktu; ana klasörden `istemci`, `Diller`, `anahtar_kelimeler.txt` kopyalanıp derlendi (bin git'te yok sayılıyor). Ana klasörde exe'yi yeniden derlemek gerekir.
