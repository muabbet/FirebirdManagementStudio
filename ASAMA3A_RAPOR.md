# Aşama 3a Raporu

Dal: `asama3a` (`main`'den açıldı, `main`'e yazılmadı). `Derle.bat` (Win64 Release) hatasız derlendi.
**Adım 1 onaylandı, Adım 2 bitti (aşağıda); 3b sahibinin onayını bekliyor, başlanmadı.**

---

# Adım 1: Tek nesne için "Script üret"

## Ne yapıldı

- **Ağaç sağ tık menüsü:** Tablo, View, Prosedür ve Generator nesnelerinde yeni tek seçenek **"Script üret"** (`miScriptUret`, `fAna.pas`/`fAna.dfm`). `OnClick` → `miScriptUretClick` → `ScriptAc` → doğrudan `uDDL.ScriptUret`. Tablo düğümünde menü: Aç, Script üret, Yenile (üç madde; bağlantı düğümü menüsüne dokunulmadı).
- **Sonuç yeni sorgu sekmesinde** açılır, çalıştırılmaz. `YeniSorgu` isteğe bağlı `Metin` parametresi aldı (`fAna.pas`), `TSorguSekme.MetinYaz` → `TSqlEditor.MetinYaz` (`uEditor.pas`). Boş parametreyle eski davranış aynen.
- **`uMetadata.pas` (sürüme bağlı okuma):** `TabloBilgisiOku`, `ViewBilgisiOku`, `ProsedurBilgisiOku`, `GeneratorBilgisiOku`. `RDB$` tablolarını yalnızca bu unit bilir; `uDDL`'ye sade kayıtlar verir (`TKolonBilgisi`, `TKisitBilgisi`, `TIndeksBilgisi`, `TTetikleyiciBilgisi`, `TParametreBilgisi` ...). Sürüme bağlı farklar (identity, paket, artış, kısmi indeks) `SurumNo(Bag)` ile bu unit içinde.
- **`uDDL.pas` (sadece metin üretir):** `ScriptUret(Bag, Tur, Ad)`. `uDDL` `RDB$` bilmez.
  - Tablo: kolonlar (tip, domain adı, `NOT NULL`, `DEFAULT`, `COMPUTED BY`, karakter seti, `COLLATE`, `IDENTITY` 3.0+), `PRIMARY KEY`/`UNIQUE`/`CHECK` tablo içinde, `FOREIGN KEY` (`ON UPDATE/ON DELETE`) ayrı `ALTER TABLE ... ADD`, indeksler (benzersiz, azalan, ifade, pasif, 5.0 kısmi) ayrı `CREATE INDEX`, en sonda tablonun tetikleyicileri tek `SET TERM ^ ;` bloğunda.
  - View: `CREATE VIEW ad (kolonlar) AS ...;` (view'a bağlı tetikleyici varsa sona eklenir).
  - Prosedür: parametreler (girdi/çıktı, domain, 3.0+ `NOT NULL`/varsayılan), gövde `SET TERM` içinde.
  - Generator: `CREATE SEQUENCE ad;` + `SET GENERATOR ad TO n;` (+ 3.0+ artış `INCREMENT BY`).
  - Adlar yalnız gerektiğinde `"..."` içine alınır (küçük harf, boşluk, özel karakter, anahtar kelime). Anahtar kelimeler `anahtar_kelimeler.txt`'den okunur, kodda gömülü değil. Dosya ayrıştırması `uEditor`'daydı; tekrar yazmamak için `uMetadata.AnahtarKelimeleriOku` oldu, `uEditor` onu çağırıyor (davranış aynı).
  - Sistemin verdiği kısıt adları (`INTEG_n`) ve indeks adları yazılmaz.
- **Hata/eksik nesne:** `EMetadataHatasi` (nesne yok, gövde kaydı yok, bilinmeyen tip) anlaşılır cümleyle sonuç alanına yazılır; başka hata "Script üretilemedi" + ham mesaj "Ayrıntı"da. Yeni dil anahtarları (tr/en/de, her biri 6): `MENU_SCRIPT_URET`, `MSG_SCRIPT_URETILDI`, `ERR_DDL_NESNE_YOK`, `ERR_DDL_KAYNAK_YOK`, `ERR_DDL_TIP_BILINMIYOR`, `ERR_DDL_ALINAMADI`. Kontrol: üç dosyada 140 anahtar, eksik 0, boş 0.
- Yeni dosyalar: `Test\DDLTest.dpr`, `Test\DDLTestDerle.bat`. Harici bileşen eklenmedi.

## Ne test edildi (Firebird 5.0.4, gömülü, geçici veritabanları)

`DDLTest` (**83 kontrol, hata 0**). Yöntem: A veritabanında yapı kurulur (domain, generator'lar, 4 prosedür, 5 tablo, 1 view) → her nesne için script üretilir → **boş B veritabanında uygulamanın kendi çalıştırıcısıyla** (`KomutlaraBol` + `BetikCalistir`) çalıştırılır → B'den aynı nesne için tekrar script üretilir → **iki çıktı birebir aynı mı** (13 nesne: 3 generator, 4 prosedür, 5 tablo, 1 view; **13/13 aynı**). B'ye yalnızca domainler elle konur (Adım 1'de domain script'i yok).

Kapsanan durumlar: bileşik PK; FK + `ON DELETE CASCADE` + `ON UPDATE CASCADE`; domain kolon ve domain parametre; computed kolon; `DEFAULT` (sayı, negatif sayı, metin, `CURRENT_DATE`, `'NOW'`, `CURRENT_USER`); adlı ve adsız `CHECK`; `COLLATE UNICODE_CI`; karakter seti (UTF8, OCTETS); BLOB (alt tip 0/1, segment boyu); tüm sayı/tarih tipleri; tetikleyiciler: `BEFORE INSERT`, `BEFORE INSERT OR UPDATE`, pasif `AFTER INSERT OR UPDATE OR DELETE`; gövdesinde `;` ve `'a;b'` olan prosedür; girdi+çıktı parametreli prosedür; parametresiz prosedür; satır sonu `--` yorumu olan gövde; view; kolon listeli view; indeksler (normal, benzersiz azalan, ifade, pasif); identity (`ALWAYS` ve `BY DEFAULT`, `START WITH`/`INCREMENT BY`), `BOOLEAN`, `INT128`, `DECFLOAT`, `TIME/TIMESTAMP WITH TIME ZONE` (5.0.4'te); küçük harfli/boşluklu/anahtar kelime ("ORDER") adların tırnaklanması; generator değeri (41) korunuyor. Hata durumu: olmayan tablo/prosedür/generator ve tablo adının view diye istenmesi anlaşılır cümle veriyor.

Ek doğrulama: üretilen script'ler (BOM'suz) **`isql -i` (5.0.4)** ile yeni bir veritabanında da hatasız çalıştı.

Mevcut testler: `SorguTest` **80/80, hata 0**; `BaglantiDosyasiTest` **52/52, hata 0**; `MetadataTest` çıkış kodu 0. Program açılışı denendi: pencere hatasız açıldı ve kapandı (dfm/olay bağları yükleniyor).

## `isql -x` ile fark listesi (5.0.4, aynı A veritabanı)

Hepsi gerekçeli; hiçbiri anlam farkı değil, aşağıdaki iki madde dışında:

1. Biçim: isql tabloyu yalnız kolonlarla yazıp kısıt/indeks/tetikleyiciyi dosyanın başka yerlerine dağıtır; bu araç tek nesne içindir, PK/UNIQUE/CHECK tablo içinde, FK/indeks/tetikleyici hemen altında (kullanıcı tek bakışta okur).
2. isql prosedürü iki aşamada yazar (boş iskelet + `ALTER`, çünkü prosedürler birbirini çağırır). Tek nesne için `CREATE PROCEDURE` gövdesiyle tek seferde yazıyoruz; birbirini çağıran prosedürlerde çalıştırma sırası kullanıcıda (Adım 2'de tüm DB için isql sırası uygulanacak).
3. Computed kolon: isql `TOPLAM BIGINT COMPUTED BY (NULL)` + sonra `ALTER`; biz `TOPLAM COMPUTED BY (MIKTAR * 2)` (geçerli ve daha sade).
4. Identity: isql `GENERATED ... (START WITH 1) NOT NULL`; biz `START WITH`'i yalnız 1'den farklıysa, `NOT NULL`'u hiç yazıyoruz (identity zaten boş olamaz). İkisi eşdeğer.
5. `INCREMENT 5` (isql) – `INCREMENT BY 5` (bizim, standart sözdizimi).
6. BLOB: isql `SUB_TYPE TEXT SEGMENT SIZE 80`; biz `SUB_TYPE 1` ve segment boyunu yalnız 80'den farklıysa yazıyoruz.
7. FK: isql `ON UPDATE` önce, biz `ON DELETE` önce yazıyoruz.
8. Tetikleyici başlığı: isql tek satır (`ACTIVE BEFORE INSERT POSITION 0`), biz iki satır; gövde aynı.
9. **Generator değeri:** isql `-x` generator'ın **güncel değerini yazmıyor** (`CREATE GENERATOR ... START WITH 1`); biz `SET GENERATOR ad TO n;` yazıyoruz (tek nesne script'inde değeri kaybetmemek için). Sahibinin kararı: istenmezse tek satırla kaldırılır.
10. **Pasif indeks:** isql `-x` bu veritabanında `ALTER INDEX ... INACTIVE` satırını yazmadı; biz yazıyoruz.
11. Domain `CHECK` ve domain tanımı: isql yazar, Adım 1'de domain script'i yok (Adım 2).

## Kararlar (sahibine bilgi)

- **Karakter seti** yalnız veritabanının varsayılanından farklıysa yazılır (isql gibi). Başka varsayılan karakter setli veritabanında çalıştırılırsa kolonlar o veritabanının varsayılanını alır. Adım 2'de `CREATE DATABASE ... DEFAULT CHARACTER SET` bunu çözer. İsterseniz her zaman açık yazarız.
- Generator için `CREATE SEQUENCE` + `SET GENERATOR` seçildi (üç sürümde de aynı anlamı veriyor). 5.0'da `ALTER SEQUENCE ... RESTART WITH n` ölçtüm: güncel değeri `n-1` yapıyor (ilk `NEXT VALUE` n döner), sürümler arasında anlamı değiştiği için kullanılmadı.
- View'a bağlı kullanıcı tetikleyicileri (güncellenebilir view) de sona ekleniyor; görevde yoktu ama eklenmeyince script eksik kalırdı.

## Bilinen sınırlar (Adım 1'de yapılmadı)

- Başlangıç değeri (`RDB$INITIAL_VALUE`) ve identity'nin güncel değeri script'e yazılmaz (yalnız `START WITH`, `INCREMENT`).
- `COMMENT ON`, `GRANT`, tablo/kolon açıklamaları, domain/exception script'i, `TYPE OF` parametre, dizi (ARRAY) kolon, azalan kısıt indeksi (`USING DESC INDEX`), paket içindeki prosedürler: yok (Adım 2'de bir kısmı gelecek; paket/ARRAY şimdilik kapsam dışı).
- Bilinmeyen tip kodu gelirse script üretilmez, cümle gösterilir (sessizce yanlış yazmaz).
- **Firebird 2.5.9, 3.0, 4.0 sunucuda denenmedi.** 2.5/3.0/4.0'a özgü sorgu dalları yalnız şemaya bakılarak yazıldı: identity/paket/artış 3.0+, kısmi indeks 5.0, `INT128/DECFLOAT/TZ` tipleri 5.0.4'te denendi. 2.5'te özellikle bakılacak: CHECK tetikleyicileri `RDB$SYSTEM_FLAG` ile ayrılıyor mu, tetikleyici metni `AS` ile mi başlıyor (iki durumu da ele alıyor).

## Sahibinin elle deneme listesi

1. Ağaçta gerçek bir tabloya sağ tık > **Script üret**: yeni sekmede script açılıyor mu, sütunlar/kısıtlar/indeksler/tetikleyiciler doğru mu? Sağ tık menüsünde yalnız "Aç, Script üret, Yenile" mi var?
2. Aynısını View, Prosedür ve Generator için yapın.
3. Üretilen script'i **boş** bir veritabanında F5 ile çalıştırın (bağımlı nesneler: önce domain, generator, FK'nin gösterdiği tablolar).
4. Dil değiştirip (tr/en/de) menü yazısını ve silinmiş bir nesnede ağacı yenilemeden "Script üret" hata cümlesini görün.
5. Türkçe karakterli adlı bir tablo/prosedür ("Küçük Tablo") için script üretin (`CHARSET` WIN1254 bağlantıda).
6. Çok büyük gövdeli bir prosedürde sekme açılış süresine bakın.

## Sahibinden beklenenler (ajan şifre bilmiyor)

Firebird 2.5.9 (3050) ve 5.0.4 sunucu (3051) üzerinde `DDLTest`; **sunucuda gerçek veritabanına dokunmaz**, yalnız verilen klasörde iki geçici veritabanı açar (`FBTEST_KLASOR` sunucudaki bir klasör olmalı, yazma yetkisi gerekir):

```
set FBTEST_SUNUCU=localhost
set FBTEST_PORT=3050
set FBTEST_KLASOR=C:\Temp
set FBTEST_KULLANICI=SYSDBA
set FBTEST_SIFRE=...
set FBTEST_CIKTI=%TEMP%\ddltest_259.txt
set FBTEST_SCRIPTLER=%TEMP%\ddlscriptler_259
bin\Win64\Release\DDLTest.exe
```

(5.0.4 sunucu için port 3051, çıktı dosyası başka ad.) Önce `Test\DDLTestDerle.bat` ile derlenir. Çıktının sonunda `Hata sayisi: 0` olmalı. 2.5.9'da 3.0+ nesneleri (identity, `BOOLEAN`, artışlı generator) test içinde sürüme göre atlanır. Test sunucuda oluşan iki geçici `.fdb` dosyasını silmez (sunucuda sahibi elle siler/taşır).

## Aşama 2'den devreden

- **Öneri listesi (`m.` → ikinci satır seçili):** yapılmadı. Hata ayıklayıcı olmadan nedenini kanıtlayamadım. `SynCompletionProposal.pas`'ı okudum: `Execute` içinde `Position := 0` ve `CurrentString := s` çağrılıyor, ikinci satıra geçişin `.` ile gelen karakterin `CurrentString`'e eklenmesinden mi, `OnExecute`'taki `CurrentInput`'tan mı olduğu çalışan arayüzde `OneriHazirla` sonrası `Position` bakılarak ayrılmalı. Tahmin üzerine kod değiştirmedim.
- SorguTest sunucu çalıştırmaları (2.5.9/5.0.4): sahibinde.

## Yapılmayanlar

`CLAUDE.md` Aşama 3 kutuları işaretlenmedi. Adım 2 ("Metadata çıkar", "Klonla" menüden çıkarma) ve 3b'ye geçilmedi, onayınızı bekliyorum.

---

# Adım 2: Tüm veritabanının metadata'sını çıkar ("Metadata çıkar")

Adım 1 sahibi tarafından onaylandı (2026-10-13). Bu bölüm Adım 2'yi anlatır; 3b'ye geçilmedi.

## Ne yapıldı

- **Menü:** Bağlantı düğümü sağ tık menüsünden **Klonla çıkarıldı** (`miKlonla`, `miKlonlaClick`, görünürlük ve başlık satırları silindi; `YeniBaglanti(KlonAd)` işlevi dosyada duruyor). Yerine **"Metadata çıkar"** geldi, yalnızca bağlı bağlantıda görünür. Menü (bağlıyken): Bağlan, Bağlantıyı Kes, Düzenle, Kayıttan Kaldır, Yenile, Metadata çıkar = **altı**. Araç çubuğuna düğme eklenmedi.
  - **Sahibine soru:** Görevde "araç çubuğundaki Klonla düğmesi kalır" yazıyor, ama araç çubuğunda böyle bir düğme **yok** (Yeni Bağlantı, Bağlan, Yenile, Yeni Sorgu, Çalıştır, Plan). Bu yüzden şu an bağlantı klonlamanın arayüzde yolu kalmadı. İsterseniz araç çubuğuna "Klonla" düğmesi eklerim, ya da böyle kalsın.
- **Pencere:** `fMetadataCikar.pas/.dfm` (yeni, ince form). Hedef: *Dosyaya kaydet* (varsayılan, "Seç..." ile) veya *Panoya kopyala*; üç kutu (CREATE DATABASE, CONNECT, şifre) **varsayılan kapalı**; şifre kutusu ilk ikisi kapalıyken pasif; işaretlenince kırmızı kalın uyarı ("şifre script içinde düz metin olarak görünecek"). Şifre kayıtlı bağlantıdan (DPAPI) gelir. Sıra tek ve varsayılandır (nesne türü kutusu yok).
  - Dosya zaten varsa **üzerine yazma onayı** (dosya adı ve son değişiklik tarihi yazılı, `OnayIste`). Dosyaya **akış** olarak yazılır (`TStreamWriter`), bellekte tek metin tutulmaz. Panoya alınıyorsa 8 milyon karakterden büyük metin **kesilmez**, "pano için fazla büyük, dosyaya kaydedin" cümlesi çıkar, pencere açık kalır.
  - İlerleme: "Tablolar: 12 / 117" gibi yazılır, pencere `ProcessMessages` ile donmaz, **İptal** düğmesi çalışır. İptalde yarım dosya silinmez, sonuç alanına "dosyada yalnızca yarım içerik var (dosya silinmedi)" yazılır.
  - Bitişte sonuç alanına özet ve **uyarılar** (atlanan nesneler) yazılır.
- **`uDDL.MetadataCikar`** (yeni, `TCikarici` sınıfı; iş burada). Adım 1'deki üreticileri çağırır (kolon, kısıt, indeks, tetikleyici metinleri ortak). Sıra (boş veritabanında hatasız çalışsın diye):
  1. `SET NAMES UTF8;`, (seçilmişse) `CREATE DATABASE` (sayfa boyutu ve varsayılan karakter seti veritabanından) / `CONNECT`
  2. Roller, exception'lar, generator'lar (değerleriyle `SET GENERATOR`), domain'ler
  3. Tablolar **yalnız kolonlarıyla** (geçici tablo `ON COMMIT ...`, dış tablo `EXTERNAL FILE` dahil)
  4. Prosedürler **parametreli iskelet** olarak: çıkış parametreli olanda gövde `SUSPEND;`, diğerinde `EXIT;` (isql -x de böyle; boş gövdeli olunca bu prosedürü çağıran view kurulamıyor, ilk denemede "invalid request BLR" hatası aldım ve düzelttim)
  5. View'lar **bağımlılık sırasıyla** (bağımlılık `uMetadata.ViewAdlariSirali` içinde `RDB$DEPENDENCIES`'ten okunur; çözülemeyen/döngü olursa sona yazılır ve uyarı verilir)
  6. `PRIMARY KEY`/`UNIQUE`, sonra `FOREIGN KEY`, sonra `CHECK` (hepsi `ALTER TABLE ADD`)
  7. İndeksler
  8. Tetikleyiciler (tablo, view ve **veritabanı** tetikleyicileri: `ON CONNECT` vb.)
  9. Prosedür gövdeleri (`ALTER PROCEDURE`)
  10. Yetkiler (`GRANT`; aynı kişiye aynı nesnedeki yetkiler tek satırda; sütun bazlı `UPDATE (a, b)`, `WITH GRANT OPTION`, rol üyeliği `WITH ADMIN OPTION`, `EXECUTE`, 3.0+ `USAGE`)
  11. Açıklamalar (`COMMENT ON`: veritabanı, tablo, view, kolon, prosedür, parametre, tetikleyici, domain, generator/sequence, exception, rol, indeks)
  - `SET TERM` sarmalayıcıları dengeli (prosedür başlıkları, tetikleyiciler, gövdeler ayrı bloklar).
  - **Okuma UTF-8 bağlantıyla** yapılır: bağlantı UTF8 değilse program metadata için ayrı, kısa ömürlü bir UTF8 bağlantı açar (açılamazsa verilen bağlantı kullanılır). Türkçe nesne adları ve açıklamalar bozulmuyor (testte doğrulandı).
  - **Dosya kodlaması: UTF-8, BOM'suz.** Ölçtüm: BOM'lu dosyayı `isql -i` ilk komutta "Token unknown" diye reddediyor. Başlıkta `SET NAMES UTF8;` (dosya kodlamasına bağlı sabit `SCRIPT_KARAKTER_SETI`; nesnelerin karakter seti ve `DEFAULT CHARACTER SET` veritabanından okunur, kodda sabit değil).
- **`uMetadata.pas`'e eklenenler** (sürüme bağlı okuma): `RolAdlari`, `IstisnalariOku`, `GeneratorAdlari`, `DomainleriOku`, `TabloAdlari`, `ProsedurAdlari`, `ViewAdlariSirali`, `YetkileriOku`, `AciklamalariOku`, `TabloOzellikleriniOku`, `DesteklenmeyenNesneSayisi`, tüm veritabanı tetikleyicileri (`TetikleyicileriOku(Bag, '')`), sayfa boyutu ve varsayılan karakter seti. `uDDL` hâlâ `RDB$` bilmiyor.
- **Dil anahtarları:** 40 yeni anahtar (menü, pencere, aşama adları, ilerleme, uyarılar, onay, hata). Üç dosyada **180 anahtar, eksik 0, boş 0**; kodda kullanılan tüm `T('...')` anahtarları dil dosyasında var.
- Proje dosyaları: `FirebirdYonetici.dpr` ve `.dproj`'a `fMetadataCikar` eklendi.

## Ne test edildi (Firebird 5.0.4 gömülü, geçici veritabanları)

`DDLTest` artık **144 kontrol, hata 0** (Adım 1'de 83'tü). Adım 2 senaryosu (karmaşık C veritabanı): roller; exception (Türkçe karakter ve tırnak); generator değerleri; domain (CHECK, DEFAULT, UTF8); bileşik PK/FK zinciri; UNIQUE; CHECK; Türkçe adlı tablo ve kolonlar ("Küçük Tablo", "Şehir Adı", "İlçe"); ifade indeksi; birbirini çağıran prosedürler; **alfabetik sırası bağımlılığın tersi olan view zinciri (V_Z → V_Y → V_X)**; prosedür çağıran view; view ve veritabanı tetikleyicisi; geçici tablolar; identity; yetkiler (kullanıcı, PUBLIC, rol, prosedür, sütun bazlı, GRANT/ADMIN OPTION, USAGE); tüm nesne türlerinde `COMMENT ON` (çok satırlı ve tırnaklı).
1. Çıkarma tamamlandı, ilerleme bildirimi geldi, uyarı yok.
2. Sıra (rol < exception < generator < domain < tablo < prosedür başlığı < view < PK < FK < CHECK < indeks < tetikleyici < gövde < yetki < açıklama), view bağımlılık sırası, SET TERM dengesi, sistem adlı (`INTEG_`) kısıtın ve sahip yetkilerinin yazılmaması.
3. **Boş D veritabanında** çıkan script uygulamanın kendi çalıştırıcısıyla (F5 mantığı, `KomutlaraBol` + `BetikCalistir`) çalıştı: **60 komut, hata 0**.
4. D'den tekrar metadata çıkarıldı ve ilk çıktıyla **satır satır karşılaştırıldı: aynı** (194 satır).
5. **Şifre:** kutu kapalıyken çıktıda `PASSWORD` sözcüğü ve şifre metni (`GizliSifre123`) **hiç geçmiyor** (metin araması). CREATE DATABASE+CONNECT açık, şifre kapalıyken de geçmiyor. Şifre açıkken iki yerde (`CREATE DATABASE`, `CONNECT`) geçiyor. CREATE DATABASE/CONNECT kapalıyken şifre kutusu işaretli gelse bile hiçbir şey yazılmıyor.
6. **İptal:** 8. ilerleme çağrısında iptal edilince `False` döner, yazılan kısım yarım kalır ve sona ulaşmaz.
7. Dosyaya akış: BOM yok, içerik metinle aynı (Türkçe karakterler UTF-8 gidiş-dönüş).

**`isql` ile (5.0.4 `isql -i`, boş yeni veritabanı):** C veritabanının script'i (CREATE DATABASE satırıyla) ve **gerçek bir veritabanının kopyası** (`SYS_DATABASE - Kopya.FDB`, 6,8 MB, 1017 satırlık script) **0 hatalı komutla** çalıştı. Gerçek dosyalara dokunmadım: kopyayı bu oturumun geçici klasörüne kopyalayıp onu okudum (kaynak dosya değişmedi). Çıkarma 294 ms sürdü.
**Gerçek kopyada gidiş-dönüş:** isql ile kurulan veritabanından tekrar çıkarma, ilkiyle **1021 satırın 1018'i aynı**; 3 fark exception mesajlarında (aşağıda "Bilinen sınırlar"). Gerçek kopyada 1 uyarı çıktı ("script'i üretilemeyen N nesne").

Mevcut testler: `SorguTest` 80/80, `BaglantiDosyasiTest` 52/52, `MetadataTest` çıkış kodu 0. Program açılışı denendi (hatasız açıldı/kapandı).

## `isql -x` ile fark listesi (aynı C veritabanı)

Adım 1'dekilere (biçim, `SET GENERATOR`, computed kolon, identity biçimi, `INCREMENT BY`) ek olarak:
1. isql rolleri ve exception'ları sonda yazar; biz başta (generator/tablo/yetkilerden önce gelmeleri gerekir, başta olması daha güvenli).
2. isql domain `CHECK`'ini sonradan `ALTER DOMAIN ... ADD CONSTRAINT CHECK` ile yazar; biz `CREATE DOMAIN` içinde.
3. isql `CHECK` kısıtlarını ve tetikleyicileri prosedür gövdelerinden sonra yazar; biz spesifikasyondaki sıra: kısıtlar < indeksler < tetikleyiciler < gövdeler.
4. `GRANT ROL TO USER x` (biz) – `GRANT ROL TO x` (isql); ikisi de geçerli.
5. `COMMENT ON PROCEDURE PARAMETER` her ikisinde aynı (ilk denemede `COMMENT ON PARAMETER` yazmıştım, isql biçimine çevirdim; 2.5'te geçerli olan budur).
6. isql dosyayı sistem karakter setinde yazar (Türkçe karakterler bozuk), biz UTF-8 + `SET NAMES UTF8`.
7. isql generator değerini yazmıyor, biz yazıyoruz.

## Bilinen sınırlar ve önemli notlar

- **Exception mesajı karakter seti:** Firebird exception mesajını bağlantı karakter setiyle **dönüştürmeden** saklar. Gerçek kopyada mesaj WIN1254 baytlarıyla duruyor; script `SET NAMES UTF8` ile `isql`'de çalıştırılınca yeni veritabanında UTF-8 baytlarıyla duruyor, program okuyunca bozuk görünebilir (kopyada 3 exception). Programın kendi çalıştırıcısıyla (WIN1254 bağlantı) bayt aynı kalıyor. Öneri: script'i uygulamada çalıştırmak, ya da `SET NAMES` satırını kendi bağlantı karakter setinize çevirmek. Kodla çözmek istenirse karar sizin.
- Script'i üretilmeyen nesneler (uyarıyla sayısı bildirilir): fonksiyonlar (UDF ve PSQL `CREATE FUNCTION`), paketler, kullanıcı collation'ları, blob filtreleri, DDL tetikleyicileri. Ayrıca `CREATE USER` (3d), `GRANTED BY`, `ARRAY` kolonlar, `TYPE OF` parametreler bu sürümde yok.
- Programın kendi çalıştırıcısı `CREATE DATABASE` satırını çalıştıramaz; CREATE DATABASE'li script'i `isql` ile çalıştırın. `CONNECT` ve `SET NAMES` satırlarını çalıştırıcı atlıyor.
- Başlangıç değeri (initial value) ve identity'nin güncel değeri yazılmaz (Adım 1'deki gibi).
- **Firebird 2.5.9, 3.0, 4.0 sunucuda denenmedi.** 2.5'te özellikle bakılacaklar: `COMMENT ON VIEW`/`INDEX` sözdizimi, `RDB$ROLES`/`RDB$EXCEPTIONS` tablolarında `RDB$SYSTEM_FLAG` sütunu, `RDB$USER_PRIVILEGES` nesne türü kodları. (`RDB$USER = RDB$GRANTOR` ve `RDB$GRANTOR is not null` kuralı 5.0'da doğrulandı.)
- **Arayüzü elle denemedim.** Pencere derlendi, program hatasız açılıp kapandı, ama menü > pencere > çıkarma akışını ve Almanca yazıların kesilip kesilmediğini ekranda görmedim. Aşağıdaki liste bu yüzden önemli.
- Çok büyük veritabanında (binlerce nesne) süre ve bellek ölçülmedi (en büyük deneme 1017 satır / 294 ms). Çıkarma ana iş parçacığında çalışır; pencere donmasın diye `ProcessMessages` kullanılır.

## Sahibinin elle deneme listesi (Adım 2)

1. Bağlı bir veritabanında bağlantıya sağ tık: menüde yalnız Bağlan, Bağlantıyı Kes, Düzenle, Kayıttan Kaldır, Yenile, **Metadata çıkar** olmalı (Klonla yok).
2. **Metadata çıkar**: pencere açılıyor mu? Üç kutu kapalı mı, şifre kutusu pasif mi? CREATE DATABASE'i işaretleyince şifre kutusu açılıyor mu, şifreyi işaretleyince kırmızı uyarı çıkıyor mu?
3. Dosyaya kaydet (yeni dosya): sonuç alanında özet var mı? Aynı dosyaya tekrar: üzerine yazma onayı dosya adı ve tarihle çıkıyor mu, "Hayır" dosyaya dokunmuyor mu?
4. Büyük bir veritabanında ilerleme yazısı akıyor mu, pencere donmuyor mu? **İptal** ile durdurun: sonuç alanında "yarım içerik" cümlesi var mı, dosya duruyor mu?
5. Panoya kopyala, Not Defteri'ne yapıştırın.
6. Çıkan dosyayı boş bir veritabanında F5 ile (CREATE DATABASE kutusu kapalı) çalıştırın; hatasızsa aynı veritabanından tekrar çıkarıp iki dosyayı karşılaştırın (Notepad++ Compare).
7. Aynısını `isql -i dosya.sql` ile deneyin (CREATE DATABASE + şifre kutusu açık; dosyada şifreyi görün; işiniz bitince dosyayı güvenli yere taşıyın).
8. Almanca ve İngilizceye geçip pencere yazılarının kesilmediğini görün.
9. Türkçe karakterli nesne adı, açıklama ve exception mesajı olan bir veritabanında deneyin (exception için yukarıdaki nota bakın).

## Sunucu testi için komutlar (sahibi çalıştırır)

Adım 1'deki komutlar aynen geçerli (`DDLTest.exe` artık Adım 2'yi de içeriyor; 2.5.9'da 3.0+ özellikler otomatik atlanır). İsteğe bağlı gerçek veritabanı **kopyası** için `set FBTEST_KOPYA=C:\...\kopya.fdb` (yalnız gömülü kip, 5.0.4 istemcisiyle açılabilen kopya; sadece okur, `FBTEST_SCRIPTLER` klasörüne `kopya.sql` yazar).

## Yapılmayanlar

`CLAUDE.md` Aşama 3 kutuları işaretlenmedi. 3b'ye geçilmedi.
