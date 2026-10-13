# Aşama 3a Raporu

Dal: `asama3a` (`main`'den açıldı, `main`'e yazılmadı). `Derle.bat` (Win64 Release) hatasız derlendi.
**Şu an yalnızca Adım 1 bitti.** Adım 2 (Metadata çıkar) ve 3b sahibinin onayını bekliyor, başlanmadı.

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
