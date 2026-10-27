# Aşama 3e-2 Raporu: Trigger listesi, düzenleme ve kaydetme

Dal: `asama3e-2` (main `3f039a6` üstünden). Yerel çalışma, itme/PR yok, `CLAUDE.md` kutularına dokunulmadı, dosya silinmedi, yeni üçüncü parti bileşen yok.
**Sunucu kipi (3.0 :3052, 4.0 :3053, 2.5 :3054) bende denenmedi** (şifre bende yok). Testler "gömülü" kipte koştu; bu makinede bu kip gerçek gömülü değil, yerel bir Firebird'e düşüyor ve bu koşuda **5.0.4** olarak göründü. 2.5 / 3.0 / 4.0 davranışı bende hiç denenmedi. Gerçek arayüzü **elle denemedim**; yalnızca programın açılıp 6 sn çökmeden durduğunu gördüm.

## 1. Ne değişti

| Dosya | Değişiklik |
|---|---|
| `Kaynak\uMetadata.pas` | `TetikleyicileriListele` (ağaç için, gövde okunmaz), `TetikleyiciBilgisiOku` (tek trigger). `TetikleyicileriOku` aynı iç yordamı kullanıyor, davranışı aynı. DDL trigger'ında `Olaylar = 'DDL'` (yalnız ağaçta tür olarak görünür). |
| `Kaynak\uDDL.pas` | `ntTetikleyici` türü, `TetikleyiciScripti` ve `TetikleyiciDuzenleScripti` (`CREATE OR ALTER TRIGGER`). `ScriptUret(ntTetikleyici)` `CREATE TRIGGER` üretir. DDL trigger'ında script üretilmez (mevcut davranış), `EMetadataHatasi` fırlar. |
| `Kaynak\uProsedur.pas` | Genel `NesneDuzenleMetni / NesneAdiniDogrula / NesneKaydet` (tür parametreli). `Prosedur*` adları ince sarmal olarak kaldı. Yeni: `TetikleyiciTablosunuDogrula`. Yedek dosyası `trigger_ADI_...sql`. |
| `Kaynak\fProsedurSekme.pas` | `Tur` alanı eklendi (sekme prosedür ya da trigger). Metinler tura göre `Anahtar(...)` ile seçilir. `ProsedurAdi` alanı `NesneAdi` oldu. |
| `Kaynak\fAna.pas/.dfm` | Yeni 4. dal "Trigger'lar" (Tablolar, View'lar, Prosedürler, **Trigger'lar**, Generator'lar). `DAL_GENERATOR` 3'ten 4'e kaydı. Sağ tık "Düzenle" maddesi (`miNesneDuzenle`) prosedür ve trigger için ortak. Pasif trigger soluk (`tvNesnelerCustomDrawItem`). DDL trigger'ında Script üret/Düzenle gizli. |
| `Kaynak\uIkon.pas` | `IKON_TETIKLEYICI` = mevcut "çalıştır" (player-play) ikonu: **geçici, `Ikonlar\svg` içinde uygun yok**; sahibine bildirim. |
| `Kaynak\uBaglanti.pas` | `HataMetniniCevir`: `read-only column` → `ERR_SALT_OKUNUR_KOLON`. |
| `Diller\tr/en/de.json` | 13 yeni anahtar (`AGAC_TETIKLEYICILER`, `TRG_*`, `ERR_TRG_*`, `ERR_SALT_OKUNUR_KOLON`...). |
| `Test\TriggerDuzenleTest.dpr`, `TriggerDuzenleTestDerle.bat` | Yeni test (bölüm 3). |

## 2. Kararlar

- **Kod tekrarı:** trigger'ı aynı `uProsedur` ve `fProsedurSekme` birimlerine ekledim, `uNesneDuzenle` diye yeni birim açmadım. Neden: iki nesne türünün adımları birebir aynı (ad koruması, onay, yedek, tek işlemde çalıştırma), fark yalnız başlık sözcüğü ve metinler; tür parametresi en az kod ve en az yeni dosya demek. Prosedür davranışı değişmedi: `ProsedurDuzenleTest` 86/0 aynen geçti.
- **Ağaç:** adın yanında tablo `TR_MUSTERI_BI (MUSTERI)`; veritabanı trigger'ında `(ON CONNECT)`, DDL trigger'ında `(DDL)`. Pasif trigger gri yazılı (seçiliyken normal renk).
- **Menü (trigger):** Script üret, Düzenle, Yenile (3 madde). Aktif/pasif yapma yok (bkz. öneriler).
- **Düzenle metni:** `CREATE OR ALTER TRIGGER ad FOR tablo ACTIVE|INACTIVE BEFORE|AFTER olay POSITION n AS ...`, `SET TERM ^` sarmalı. Sekme başlığı "Trigger: ADI (bağlantı)".
- **Kaydet:** 3e-1 ile aynı: ad koruması, onay (varsayılan Hayır), `_arsiv\<bağlantı>\trigger_ADI_yyyymmdd_hhnnss.sql` yedeği (yazılamazsa durur), tek açık işlemde commit/rollback, `SqlMesajiYaz`. Ctrl+S ve Kaydet tek yol, F5 yalnız ipucu.
- **Onay metni (tr):** "`ADI` trigger'ı veritabanında değiştirilecek. Bu trigger tablonun ilgili işlemlerinde otomatik çalışır; yanlış bir trigger veriyi bozabilir. Eski hali bir dosyaya yedeklenir. Devam edilsin mi?"
- **Önemli bulgu (gerçek davranış, 5.0.4):** `CREATE OR ALTER TRIGGER ... FOR <başka tablo>` Firebird'de **hata vermeden trigger'ı başka tabloya taşıyor**. Bunu sessizce kabul etmek tehlikeli olduğundan kaydetme başlamadan reddediyorum (`TetikleyiciTablosunuDogrula`, onaydan da önce): "Trigger'ın bağlı olduğu tablo değiştirilemez; kaydetme yapılmadı..." (`ERR_TRG_TABLO_DEGISTI`, tr/en/de). Taşımak için yeni trigger + eskisini silme önerilir.
- **DDL trigger'ı (3.0+):** ağaçta listelenir (`(DDL)`), ama bu sürümde script üretilmediği için Script üret ve Düzenle menüsü **gizli**. Veritabanı trigger'ı (`ON CONNECT` vb.) listelenir ve düzenlenir (`FOR` yok). `BEFORE/AFTER TRANSACTION` gibi 4.0+ türleri için `ScriptUret` ne üretiyorsa o; 5.0.4 dışında denenmedi.

## 3. Test: `Test\TriggerDuzenleTest.dpr`

`Test\TriggerDuzenleTestDerle.bat` ile derlenir. Bölümler: **A** saf kurallar ve dil anahtarları; **B1** liste (tablo adıyla), düzenle metni (tablo/olay/pozisyon/aktif), kaydet, yeni davranış (INSERT ile), yedek (içerik eski), yedekle geri kayıt, pasif trigger `INACTIVE` korunuyor; **B2** sözdizimi, olmayan kolon, tablo değiştirme, DELETE'te `NEW`, AFTER'da `NEW` ataması, ad değişikliği, başlıksız metin (hepsinde eski trigger bozulmuyor); **B4** yedek yazılamıyor → durur; **B5** `ON CONNECT` ve (3.0+) DDL trigger'ı; **B7** yetkisiz kullanıcı; **B8** üç dilde cümleler; **B9** arayüz duman testi (sekme, Kaydet bağlı, F5 ipucu). Yazma yalnız gömülü kendi veritabanında veya yerel 3052/3053/3054 + `FBTEST_YAZMA=1`; başka portta kod reddeder.

**Gömülü sonuç (5.0.4): `Kontrol: 60  Hata: 0`.** Diğer testler (yeniden derlenip koşuldu, çıkış kodu 0): ProsedurDuzenleTest 86/0, KullaniciTest 44/0, DDLTest, SorguTest, AktarTest, SeritTest. `YedekTest` koşturulmadı (`uYedek`e dokunmadım; 3e-1'de de bu ortamda sürüme göre kararsızdı).

**Gerçek hatalar (5.0.4'te üretildi, çevirisi bağlandı):**
- Sözdizimi: `Token unknown - line 5` → `ERR_SQL_SOZDIZIMI`; editör satırı doğru (7).
- Olmayan kolon (`Column unknown NEW.X`, -206) → `ERR_SQL_NESNE_YOK` (zaten vardı).
- DELETE trigger'ında `NEW`: gerçek hata yine `Column unknown NEW.LOG` (-206), aynı cümle; "NEW/OLD'a özel" ayrı cümle yazmadım (aynı kod, ayırt edilirse metne bakmak gerekir).
- AFTER trigger'da `NEW.KOLON = ...`: `attempted update of read-only column` → **yeni** `ERR_SALT_OKUNUR_KOLON`.
- Yetki: `no permission for ALTER access to TABLE ...` → `ERR_YETKI_YOK`.
- Tablo değiştirme: hata değil, sessiz taşıma → yukarıdaki doğrulama.
- **Üretilemedi / farklı çıkabilir:** olmayan tabloya `FOR` (OR ALTER ile mevcut trigger'da tablo değiştirme olarak yakalandığından "Table unknown" görülmedi), olay/zaman uyumsuzluğunun 2.5/3.0/4.0'daki metinleri, 3.0+ satır numarası (3e-1 bulgusu: 3.0+ ALTER hatasında satır yok; kod bunu zaten doğru işliyor).

## 4. Sunucu testi için sahibine (PowerShell)

Sırayla 3052 (3.0), 3053 (4.0), 3054 (2.5); `FBTEST_YOL` sunucuda VAR OLAN bir test veritabanı:

```powershell
$env:FBTEST_SUNUCU = "127.0.0.1"; $env:FBTEST_PORT = "3052"
$env:FBTEST_YOL = "<sunucudaki test veritabani yolu>"
$env:FBTEST_KULLANICI = "SYSDBA"; $env:FBTEST_SIFRE = "<sifre>"
$env:FBTEST_YAZMA = "1"; $env:FBTEST_CIKTI = "$env:TEMP\triggertest_3052.txt"
.\bin\Win64\Release\TriggerDuzenleTest.exe; $LASTEXITCODE
Get-Content $env:FBTEST_CIKTI | Select-String "HATA|tablo degistirme|AFTER|yetkisiz|Kontrol:"
```

3053 ve 3054 için yalnız `FBTEST_PORT`, `FBTEST_YOL` ve çıktı adı değişir. Çıktıdaki `HATA` ve "AFTER tetikleyicide NEW atama / DELETE tetikleyicisinde NEW / yetkisiz" satırlarını iletirseniz çevirileri gerçek metne bağlarım. Test kendi `FBY_TEST_*` tablo ve trigger'larını siler.

## 5. Bilinen sınırlar

- Tanım değişmiş mi karşılaştırması yok (3e-1 ile aynı): sekme açıkken başkası trigger'ı değiştirirse Kaydet üzerine yazar; eski hali yedeklendiği için kaybolmaz.
- Trigger ikonu geçici ("çalıştır"); ayrı ikon çizilmedi.
- Sekme kapatılırken "kaydedilmemiş değişiklik" sorulmuyor (sorgu sekmeleri gibi).
- Trigger'ın tablosu değiştirilemez (bilinçli). DDL trigger'ı düzenlenemez.
- Ağaç listesi `TetikleyicileriListele` ile tüm trigger'ları tek sorguda okur (gövde okunmaz); çok büyük veritabanında ölçmedim.

## 6. Öneriler (bu görevde yapılmadı)

- **Aktif/pasif yapma:** ağaçta sağ tık "Pasif yap / Aktif yap" (`ALTER TRIGGER ad INACTIVE|ACTIVE`, onay + SQL karşılığı); pasif trigger zaten soluk görünüyor, doğal devamı.
- **Etkin yetki:** 3d-2'de yetki görüntülemede kullanıcının bir nesne üzerindeki *etkin* yetkisini (rol ve PUBLIC dahil) göstermek, "Kaydet yetki yok" hatasını önceden tahmin etmeye yarar.
- Tablo sekmesinde o tablonun trigger'larının listesi (ağaçtaki dala gitmeden).
- Ortak "Ctrl+Boşluk" öneri hazırlığı (`fSorguSekme`/`fProsedurSekme` kopyası) ortak yordama alınabilir.

## 7. Sahibine arayüz deneme listesi

1. Bağlan: ağaçta Tablolar, View'lar, Prosedürler, **Trigger'lar (N)**, Generator'lar sırası; trigger adlarının yanında `(TABLO)` var mı? Pasif olan soluk mu?
2. Trigger'a sağ tık: Script üret / Düzenle / Yenile. Script başlığı `CREATE TRIGGER`.
3. Düzenle: sekme "Trigger: ADI (bağlantı)"; metin `CREATE OR ALTER TRIGGER ad FOR tablo ...`; aynı trigger'a tekrar Düzenle mevcut sekmeye geçiyor mu?
4. Gövdeyi değiştir, Ctrl+S: onay metni (varsayılan Hayır) → Evet → "kaydedildi (commit)", yedek yolu, `SQL:` satırı. `%APPDATA%\FirebirdYonetici\_arsiv\<bağlantı>\trigger_...sql` eski mi? Tabloya satır ekleyince yeni davranış var mı?
5. Bozuk yaz (`new.X = = 1`): cümle + Ayrıntı + geri alındı + SQL, imleç hatalı satıra (2.5'te) gidiyor mu?
6. `FOR` satırında başka bir tablo adı yaz, Kaydet: onaydan önce "tablo değiştirilemez" uyarısı çıkıyor mu?
7. Adı değiştir, Kaydet: uyarı. Bu sekmede F5: yalnız ipucu.
8. Dili Almanca/İngilizce yap: dal adı, sekme başlığı, onay, mesajlar değişiyor, düğme yazısı kesilmiyor mu?
9. (3.0+) DDL trigger'ı olan veritabanında: listede `(DDL)`, sağ tıkta yalnız Yenile mi?
10. Prosedüre sağ tık → Düzenle hâlâ aynen çalışıyor mu?
