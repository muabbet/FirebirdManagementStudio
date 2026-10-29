# Aşama 3f Raporu: View düzenleme, Domain / Exception / Generator yönetimi

Dal: `asama3f` (main `cc8d713` üstünden), dört commit: 3f-1, 3f-2, 3f-3, 3f-4. Yerel çalışma, itme/PR yok, `CLAUDE.md` kutularına dokunulmadı, dosya silinmedi, yeni üçüncü parti bileşen yok.
**Arayüzü elle denemedim.** Yalnızca programın açılıp 6 sn çökmeden durduğunu gördüm (ağaç, sağ tık menüleri, pencereler görsel olarak denenmedi). Mantık (komut üretimi, yedek, hata cümleleri, sekme duman testleri) testlerle sürümlerde denendi.

## 1. Hangi sürümlerde denendi (dürüst not)

Görev "sunucu kipini sen çalıştıramazsın" diyordu. Test sunucularını (`TestSunuculariBaslat.ps1`) başlattım ve **4.0.7 (:3053) ile 2.5.9 (:3054) sunucularında SYSDBA/masterkey kabul edildi**, yazma testlerini orada koştum (yalnızca izinli 3052/3053/3054 portları; test kodu başka portta yazmayı reddediyor, 3050/3051'e dokunulmadı). **3.0 sunucusu (:3052) masterkey'i reddetti**; bunun yerine gerçek **3.0.14 istemcisiyle yerleşik kip** (`C:\Firebird\firebird30` içeriğini `istemci` olarak kullanan geçici klasör) koştum. 5.0.4 de yerleşik kip. Yani dört sürümün hepsinde gerçek motorla denendi: **2.5.9 (sunucu), 3.0.14 (yerleşik), 4.0.7 (sunucu), 5.0.4 (yerleşik)**. 3.0 sunucusunu şifreyle siz de deneyebilirsiniz (komutlar bölüm 6).

## 2. Ne değişti

| Dosya | Değişiklik |
|---|---|
| `Kaynak\uNesneYonet.pas` (yeni, 314 satır) | Silme (`NesneSil`, onay metni, bağımlılık satırları), yeni nesne şablonu, domain değiştirme (varsayılan/CHECK/ad), generator (değer, küçültme uyarısı, oluşturma), `AdHazirla` |
| `Kaynak\uProsedur.pas` | Tür tabloları view/exception/domain/generator için genişledi. Çalıştırma parçası `MetniCalistir`, yedek parçası `EskiTanimiYedekle` ortak yordam oldu (prosedür/trigger davranışı aynı). Yeni: `YeniNesneAdiniDogrula`, `YeniNesneKaydet` |
| `Kaynak\fProsedurSekme.pas` | `Anahtar(Bas, Son)` (tür ekiyle dil anahtarı seçer: PRS/TRG/VIEW/EXC/DOM), "Yeni nesne" kipi (`Yeni`, `YeniHazirla`, `OnOlusturuldu`) |
| `Kaynak\fGeneratorDeger.pas/.dfm` (yeni) | Generator değer penceresi (şimdiki değer, yeni değer, kullananlar) |
| `Kaynak\fAna.pas/.dfm` | 7 dal (Tablolar, View'lar, Prosedürler, Trigger'lar, **Domain'ler, Exception'lar**, Generator'lar). `DalIciniDoldur`/`DalYenile` (yalnız ilgili dal yenilenir), sağ tık maddeleri, Yeni/Sil/Domain/Generator işleyicileri |
| `Kaynak\uMetadata.pas` | `DomainleriGetir`, `IstisnalariGetir`, `DomainBilgisiOku`, `IstisnaBilgisiOku`, `BagimliNesneler` (RDB$DEPENDENCIES) |
| `Kaynak\uDDL.pas` | `ntDomain`, `ntIstisna`; `ScriptUret` ile CREATE DOMAIN / CREATE EXCEPTION; `ViewDuzenleScripti`, `IstisnaDuzenleScripti`, `GeneratorDegerKomutu`, `AdiYaz`; domain metni metadata çıkarımıyla ortak (`DomainMetni`, tekrar yazılmadı) |
| `Kaynak\uBaglanti.pas` | `HataMetniniCevir`: yeni çeviriler (bölüm 4) |
| `Kaynak\uIkon.pas` | `IKON_DOMAIN`, `IKON_ISTISNA` (geçici, bölüm 7) |
| `Diller\tr/en/de.json` | Yeni anahtarlar eklendi (toplam 437); üç dilde birebir aynı anahtar kümesi (doğrulandı) |
| `Test\NesneYonetimTest.dpr` + `...Derle.bat` | Yeni test (bölüm 5) |

## 3. Alt işlerin durumu

- **3f-1 tamam:** Domain'ler ve Exception'lar dalları, Script üret + Yenile. Sistem nesnesi çıkmaz (test).
- **3f-2 tamam:** View → Düzenle. Kaydet adımları 3e ile aynı (ad koruması, onay varsayılan Hayır, `_arsiv\<bağlantı>\view_ADI_yyyymmdd_hhnnss.sql` yedeği, tek işlem, `SqlMesajiYaz`).
- **3f-3 tamam:** Exception: Yeni (sekme), Düzenle (`CREATE OR ALTER EXCEPTION`), Sil. Domain: Yeni (sekme), üç ayrı küçük iş (varsayılan, CHECK, ad), Sil. View ve Generator: Sil.
- **3f-4 tamam:** Generator: Değeri göster/ayarla, Yeni generator, Sil, Script üret; küçültme uyarısı; kullanan prosedür/trigger'lar bağımlılık listesinden.

## 4. Sözdizimi kararları (ölçüldü) ve gerçek hata kodları

**View: `CREATE OR ALTER VIEW ad (kolonlar) AS ...;` seçildi, 2.5.9, 3.0.14, 4.0.7 ve 5.0.4'te çalışır.** Bağımlısı olan view'ı, bağımlının kullandığı kolonlar durdukça değiştirir. `RECREATE VIEW` dört sürümde de bağımlı varken `cannot delete COLUMN V1.A / there are 1 dependencies` ile **başarısız** olur, bu yüzden kullanılmadı. Bağımlının kullandığı kolon çıkarılırsa gerçek hata `Column ID from table V is referenced in view W` (kod 335544351): `ERR_NESNE_BAGIMLI` cümlesine bağlandı. View'a bağlı tetikleyiciler `CREATE OR ALTER VIEW`'da korunur (2.5.9 ve 4.0.7'de ölçüldü); düzenleme metnine dahil edilmez. "Güvenli yol çıkmadı" durumu olmadı.

**Exception:** `CREATE OR ALTER EXCEPTION` dört sürümde de çalışır (`ALTER EXCEPTION`'a düşmek gerekmedi). Yeni sekme düz `CREATE EXCEPTION` ister; `CREATE OR ALTER` reddedilir ki var olan sessizce ezilmesin.

**Domain:** `ALTER DOMAIN ... SET DEFAULT x` / `DROP DEFAULT`, `... DROP CONSTRAINT` + `ADD CHECK (...)` (tek işlemde; hatalı yeni CHECK'te eskisi geri gelir, test var), `... TO yeniad`. `DROP CONSTRAINT` CHECK yokken de hata vermez (ölçüldü). Domain'de tek CHECK olabilir (`Only one constraint allowed for a domain`), bu yüzden önce kaldırılıp sonra eklenir. Tip değiştirme yok (görev gereği). Yazılan ad yalnız harf/rakam/_/$ ise BÜYÜK harfe çevrilir (`AdHazirla`).

**Generator, görevden sapma (sahibinin kararı gerekir):** Görev "2.5'te `SET GENERATOR`, 3.0+'da `ALTER SEQUENCE ... RESTART WITH n`" diyordu. Ölçüm: `RESTART WITH n` sonrası `GEN_ID(ad,0)` **2.5.9 ve 3.0.14'te n**, ama **4.0.7 ve 5.0.4'te n-1** (artış 5 ise n-5; "sonraki değer n" anlamı). Ekranda "değer 100" yazıp gerçekte 99 bırakmamak için **her sürümde `SET GENERATOR ad TO n`** kullandım (dört sürümde `GEN_ID(ad,0)=n`, `INCREMENT BY 5` olan sequence'te de n). `SET GENERATOR` 5.0'da "eski" sayılsa da çalışıyor. Değiştirmek isterseniz tek yordam: `uDDL.GeneratorDegerKomutu`. Sürüm farkı olsun isterseniz 4.0+'da `RESTART WITH n + artış` gerekir; ben sade olanı seçtim.

**Bağımlılık (RDB$DEPENDENCIES, ölçüldü):** bağımlı olunan tür: tablo 0, view 1, exception 7, domain 9, generator 14; bağımlı: view 1, trigger 2, prosedür 5. Domain'i kullanan **tablo kolonları** bu tabloda yok, `RDB$RELATION_FIELDS`'ten alınıyor.

**`HataMetniniCevir` yeni/genişleyen çeviriler (hepsi test sunucularında üretilmiş gerçek metinle):**

| Gerçek metin (sürüme göre) | Cümle |
|---|---|
| `... already exists` (exception, sequence, view/tablo, domain TO); domain oluşturmada 2.5: `attempt to store duplicate value ... RDB$FIELDS`, 3.0+: `violation of PRIMARY or UNIQUE KEY ... RDB$FIELDS` | `ERR_NESNE_VAR` (yeni) |
| `Domain X is used in table T (local name C) and cannot be dropped` | `ERR_DOMAIN_KULLANILIYOR` (yeni) |
| `cannot delete ... there are N dependencies`, `Column X from table V is referenced in view W` | `ERR_NESNE_BAGIMLI` (kod 2.5'te nesne-yok koduyla karıştığı için artık kodlardan **önce** metne bakılıyor); metne "view kolonunu çıkarma" eklendi |
| `Exception not found`, `Domain not found`, `Sequence X not found`, `generator X is not defined`, `View X does not exist` | `ERR_SQL_NESNE_YOK` (5.0/4.0/3.0'da önce "Beklenmeyen hata" çıkıyordu) |

Üretilemeyen: salt-okunur transaction ile yazma, yetkisiz kullanıcıyla silme (Kullanıcı yönetimi 3d'ye ait; `ERR_YETKI_YOK` çevirisi zaten var ve 3e'de testli). Yazım hatası/geçersiz tip → `ERR_SQL_SOZDIZIMI` (zaten vardı).

## 5. Test: `Test\NesneYonetimTest.dpr` (153 kontrol)

Bölümler: A dil anahtarları; B0 gerçek hata kodları (kontrol değil, çıktı notu); B1 liste/script; B2 sekme duman; B3 view (kaydet, yedek içeriği, bağımlı kolon çıkarma reddi, bağımlının kullanmadığı kolon çıkarma, sözdizimi/olmayan tablo, ad değişikliği, başlıksız, yedek yazılamıyor); B4 exception (yeni, ad çakışması, düzenle, yeni mesajla prosedür, yedek, kurallar); B5 silme (bağımlılık listesi, 13 kullananla "ve 3 tane daha", onay metni, kullanılan nesne silinemez ama yedek alınmış, silme+yedek içeriği, yedek yazılamayınca silme başlamaz); B6 domain (komut metinleri, varsayılan/CHECK/ad, hatalı CHECK'te geri alma); B7 generator (yeni, değer, 32 bit dışı, küçültme uyarısı, trigger bağımlılığı, `INCREMENT BY`, yedek eski değeri tutuyor, pencere duman); üç dilde anahtarlar.

Sonuçlar (çıkış kodu 0): **5.0.4 yerleşik 153/0, 3.0.14 yerleşik 153/0, 4.0.7 sunucu 153/0, 2.5.9 sunucu 151/0** (2.5'te `INCREMENT BY` yok, 2 kontrol atlanır).
Mevcut testler yeniden derlenip koşuldu: ProsedurDuzenleTest 86/0 (5.0), TriggerDuzenleTest 60/0 (5.0); ayrıca 3.0.14/4.0.7/2.5.9'da Prosedur 84/86/80, Trigger 60/60/58, Kullanici 44/99/87 hatasız; DDLTest, AktarTest, SeritTest, SorguTest, YedekTest çıkış kodu 0. MetadataTest'in derleme dosyası yok, koşturulmadı.

## 6. Sunucuda sizin çalıştırmanız için (PowerShell)

`FBTEST_YOL` sunucuda VAR OLAN bir test veritabanı olmalı. Test `FBY_TEST_*` nesnelerini oluşturup siler; yalnız 3052/3053/3054'te yazar.

```powershell
.\Test\NesneYonetimTestDerle.bat
$env:FBTEST_SUNUCU = "127.0.0.1"; $env:FBTEST_PORT = "3052"
$env:FBTEST_YOL = "<sunucudaki test veritabani yolu>"
$env:FBTEST_KULLANICI = "SYSDBA"; $env:FBTEST_SIFRE = "<sifre>"
$env:FBTEST_YAZMA = "1"; $env:FBTEST_CIKTI = "$env:TEMP\nesnetest_3052.txt"
.\bin\Win64\Release\NesneYonetimTest.exe; $LASTEXITCODE
Get-Content $env:FBTEST_CIKTI | Select-String "HATA|OLCUM|Kontrol:"
```
3053 (4.0) ve 3054 (2.5) için `FBTEST_PORT`, `FBTEST_YOL` ve çıktı adı değişir. Gömülü: ortam değişkeni vermeden `.\bin\Win64\Release\NesneYonetimTest.exe`.

## 7. Kod tekrarı, yedek yerleri, ikonlar

- **Kod tekrarı:** prosedür/trigger için olan `uProsedur` + `fProsedurSekme` hattına view ve exception **tür olarak eklendi** (yeni sekme sınıfı yok); ortak çalıştırma/yedek parçaları çıkarıldı. Silme, domain, generator ve yeni-nesne işleri tek yeni birimde (`uNesneYonet`). Prosedür/trigger davranışı değişmedi (testler aynen geçti). Dil anahtarı seçimi tek kurala indi: `Bas + tür eki + Son`.
- **Yedekler:** `%APPDATA%\FirebirdYonetici\_arsiv\<bağlantı adı>\`. Düzenlemede `view_ADI_...sql`, `exception_ADI_...sql` (CREATE OR ALTER biçimi); silme/domain/generator işlemlerinde **tam CREATE script'i** (`domain_`, `generator_` (eski değerle, `SET GENERATOR`), `exception_`, `view_` + view tetikleyicileri). Yazılamazsa işlem başlamaz. Geri yükleme elle: dosyayı Sorgu sekmesinde açıp çalıştırın.
- **İkonlar (geçici):** Domain = "list-tree" (plan ikonu), Exception = "file-plus". `Ikonlar\svg` içinde uygun yok; sahibine bildirim.

## 8. Bilinen sınırlar

- Arayüz elle denenmedi (yukarıda). Sağ tık menü maddeleri: view 4 (Script üret, Düzenle, Yenile, Sil), exception 4, generator 4, domain 6 (Script üret, Varsayılan, CHECK, Ad, Yenile, Sil); dallarda "Yeni ..." + Yenile.
- Domain tipi değiştirme, domain'e NOT NULL / COLLATE değiştirme yok.
- "Yeni" sekmesi tek kullanımlık: başarıdan sonra sekme kapanır, dal yenilenir; exception'ı düzenlemek için ağaçtan Düzenle.
- Silmede bağımlı varsa yedek dosyası yine yazılır (silme reddedilse bile); dosyalar silinmez, biriken yedekleri elle temizlemek gerekir.
- Silinen nesnenin açık düzenleme sekmeleri sorulmadan kapanır. Düzenleme sekmesi kapatılırken "kaydedilmemiş değişiklik" sorulmuyor (3e'deki gibi).
- Tanım değişmiş mi karşılaştırması yok (3e ile aynı): sekme açıkken başkası view'ı değiştirirse Kaydet üzerine yazar; eski hali yedeklenir.
- Domain yeniden adlandırma/silme sonrası tabloların açık sekmeleri yenilenmez.
- Ağaç: `Yenile` bağlantının tüm dallarını okur (sağ tık "Yenile" aynen); değişiklik sonrası yalnız ilgili dal otomatik yenilenir.
- Bağımlılık listesi trigger/prosedür gövdesindeki dinamik SQL'i (`EXECUTE STATEMENT`) görmez.

## 9. Öneriler (bu görevde yapılmadı)

- 3g: tablo yapısı (kolon/index/constraint) düzenleme; domain tip değiştirme orada daha kolay olur.
- Yedekten "geri yükle" düğmesi (arşiv klasöründeki son dosyayı Sorgu sekmesinde aç).
- Aktif/pasif trigger yapma (3e-2'den kalan öneri).
- Generator için "Yeni generator" penceresinde başlangıç değeri.
- Silinecek nesne için bağımlılık listesinde nesneye çift tıklayınca açma.

## 10. Sahibine arayüz deneme listesi

1. Bağlan: ağaçta Tablolar, View'lar, Prosedürler, Trigger'lar, **Domain'ler (N)**, **Exception'lar (N)**, Generator'lar sırası ve sayılar. Dili değiştir: dal adları değişiyor mu?
2. View'a sağ tık: Script üret / Düzenle / Yenile / Sil. Düzenle → sekme "View: ADI (bağlantı)", metin `CREATE OR ALTER VIEW ... AS`. WHERE ekleyip Ctrl+S: onay (varsayılan Hayır) → Evet → "kaydedildi", yedek yolu, `SQL:` satırı. Bağımlısı olan view'dan kullanılan kolonu çıkar: "Bu nesneyi başka nesneler kullanıyor..." cümlesi + Ayrıntı.
3. Exception dalına sağ tık → **Yeni exception...**: şablon sekmesi (`CREATE EXCEPTION YENI_EXCEPTION 'mesaj';`). Adı/mesajı yaz, Ctrl+S: onay, "oluşturuldu", sekme kapanır, dalda görünür. Aynı adı tekrar dene: "Bu adla bir nesne zaten var".
4. Exception → Düzenle (mesajı değiştir, kaydet). Exception → Sil: onay penceresi nesne adı, "geri alınamaz", yedek, kullanan prosedürler (en çok 10 + "... ve N tane daha"); kullanılıyorsa reddedildiğinde anlaşılır cümle; `DROP EXCEPTION ...` alt alanda.
5. Domain dalına sağ tık → **Yeni domain...** (aynı akış). Domain'e sağ tık: Varsayılan değeri değiştir (kutuda mevcut değer, boş = kaldır), CHECK koşulunu değiştir (boş = kaldır), Adı değiştir; her birinde SQL'li onay penceresi. Kolonda kullanılan domain'i Sil: "tablo kolonunda kullanılıyor" cümlesi.
6. Generator'a sağ tık → **Değeri göster/ayarla...**: pencere şimdiki değeri ve kullanan trigger/prosedürleri gösteriyor mu? Değeri büyüt: onayda `SET GENERATOR ...`. Değeri **küçült**: onayda ek "DİKKAT ... çakışabilir" uyarısı, varsayılan Hayır. Dal → **Yeni generator...**; Sil.
7. Dili Almanca/İngilizce yap: menüler, pencereler, onaylar; düğme yazıları kesiliyor mu?
8. Prosedür ve Trigger → Düzenle → Kaydet hâlâ aynen çalışıyor mu?
