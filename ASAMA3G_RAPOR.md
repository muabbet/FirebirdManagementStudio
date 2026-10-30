# Aşama 3g Raporu: Tablo yapısı (kolon, index, kısıt, yeni tablo, tablo sil)

Dal: `asama3g` (main `81a5b13` üstünden), dört alt iş: 3g-1 (`1292f79`), 3g-2 (`ae199b3`), 3g-3 (`b6c1476`), 3g-4 (bu rapor ile). Yerel çalışma, itme/PR yok, `CLAUDE.md` kutularına dokunulmadı, dosya silinmedi, yeni üçüncü parti bileşen yok.
**Arayüzü elle denemedim.** Her adım hatasız derlendi ve mantık (komut üretimi, yedek, hata cümleleri, sekme duman testi) testlerle dört sürümde denendi; pencerelerin görünümü, sağ tık menüsü ve düğme yerleşimi gözle denenmedi.

## 1. Hangi sürümlerde denendi

`TabloYapiTest` (3g'nin tek test programı, 102 kontrol): **5.0.4 gömülü 102/0, 3.0.14 gömülü 102/0, 4.0.7 sunucu (:3053) 102/0, 2.5.9 sunucu (:3054) 100/0** (2.5'te NOT NULL kontrolleri farklı). Sunucu testleri `GECICI.FDB` ile SYSDBA/masterkey kullandı; test yalnız 3052/3053/3054 portunda yazar, 3050/3051'e kod izin vermez. 3.0 sunucusu (:3052) masterkey'i reddettiği için 3.0 yerleşik (3.0.14 istemcisi) çalıştırıldı.
Mevcut testler yeniden derlenip koşuldu: NesneYonetim 153/0, ProsedurDuzenle 86/0, TriggerDuzenle 60/0, DDL 0 hata, Kullanici 44/0, Aktar 70/0, Serit çıkış kodu 0 (hepsi 5.0.4 gömülü).

## 2. Alt işler

| | Ne | Not |
|---|---|---|
| 3g-1 | Tablo sekmesinde Kolonlar / İndeksler / Kısıtlar / Bağımlılıklar alt sekmeleri; sağ tık "Bağımlılıklar" | Okuma. `uMetadata`: `TabloBagimliliklariniOku`, bellek tabloları |
| 3g-2 | Kolon ekle, adı değiştir, tip/NOT NULL/varsayılan değiştir, sil | `uKolon`, `fKolonIslem` |
| 3g-3 | Index oluştur / sil / aktif-pasif; kısıt ekle (PK, UNIQUE, FK, CHECK) / sil | `uIndeksKisit`, `fYapiIslem` |
| 3g-4 | Yeni tablo (şablonlu sekme), tablo sil (ad yazdırma, satır sayısı, bağımlılıklar, yapı yedeği) | `uNesneYonet`, `fProsedurSekme`, `fAna` |

## 3. Dosyalar

Yeni: `uKolon.pas`, `fKolonIslem.pas/.dfm`, `uIndeksKisit.pas`, `fYapiIslem.pas/.dfm`, `Test\TabloYapiTest.dpr` + `...Derle.bat`, `GOREV_ASAMA3G.md`.
Değişen: `uMetadata.pas` (bağımlılık/yapı okuyucuları, `KolonNullDegistirilebilir`, `TabloSatirSayisi`), `uProsedur.pas` (`TabloYapisiniYedekle`, tablo için `TurSozcugu/TurOnEki/DosyaOnEki`), `uNesneYonet.pas` (tablo silme/şablon), `uBaglanti.pas` (yeni hata çevirileri), `fTabloSekme.pas/.dfm`, `fProsedurSekme.pas`, `fAna.pas/.dfm`, `FirebirdYonetici.dpr/.dproj`, `Diller\tr/en/de.json` (üçünde 531 anahtar, aynı küme).

## 4. Ortak akış (kolon, index, kısıt, tablo sil)

Pencere ya da seçili satır → komut üretimi → net onay (varsayılan Hayır; komut, veri riski/satır sayısı, bağımlılıklar en çok 10, yedek bilgisi) → tablonun tam CREATE script'i `_arsiv\<bağlantı>\tablo_ADI_yyyymmdd_hhnnss.sql` olarak yedeklenir (yazılamazsa işlem başlamaz) → tek açık işlemde çalıştır (commit / hatada rollback) → SQL `SqlMesajiYaz` ile alt alanda → başarıda tablo sekmesi yeniden okunur. **Verinin kendisi yedeklenmez**, onay penceresinde ve yedek dosyasının başında yazılıdır.

## 5. Sürüm farkları (ölçüldü)

- `ALTER COLUMN ... SET/DROP NOT NULL`: yalnız 3.0+. 2.5'te kutu kapalı, nedeni yazılı; sistem tablosuna elle yazılmaz (`KolonNullDegistirilebilir`, `uMetadata`).
- `ALTER COLUMN ... TYPE`, `SET/DROP DEFAULT`, `TO` (ad), `ADD`, `DROP`: dört sürümde çalıştı.
- `CREATE [UNIQUE] [DESCENDING] INDEX`, `ALTER INDEX ... ACTIVE|INACTIVE`, `DROP INDEX`, `ALTER TABLE ... ADD [CONSTRAINT] PRIMARY KEY|UNIQUE|FOREIGN KEY|CHECK`, `DROP CONSTRAINT`: dört sürümde aynı.
- **Firebird CHECK kısıtını eklerken mevcut kayıtları denetlemez** (dört sürümde ölçüldü): mevcut veri uymasa da eklenir. Onay penceresine not olarak yazıldı.
- Mesaj farkı: 2.5'te ek ayrıntı satırları farklı ("STORE RDB$RELATION_CONSTRAINTS failed" gibi); çevirilen cümleler dört sürümde aynı.

## 6. Hata cümleleri (hepsi gerçek hatadan)

Test sunucularında üretilip `HataMetniniCevir` ve ilgili birimlere bağlandı:
- UNIQUE index/kısıt tekrarlı veride: "attempt to store duplicate value ... in unique index" ya da "violation of PRIMARY or UNIQUE KEY" → `ERR_YAPI_TEKRAR` (mevcut veriyle ilgili özel cümle).
- FK eklerken yetim kayıt: "violation of FOREIGN KEY ... Foreign key reference target does not exist" → `ERR_YAPI_YETIM`.
- İkinci birincil anahtar: "Attempt to define a second PRIMARY KEY" → `ERR_PK_VAR`.
- FK'nin kullandığı PK/UNIQUE silinirken "Cannot delete PRIMARY KEY being used in FOREIGN KEY definition" → `ERR_KISIT_FK_BAGLI`; tablo silerken aynı hata `ERR_TABLO_FK_BAGLI` (tabloya özel cümle).
- Olmayan kolon "Unknown columns in index" → `ERR_SQL_NESNE_YOK` (önceden genel hata çıkıyordu).
- Aynı ad "already exists" (index, kısıt, tablo) → `ERR_NESNE_VAR`. View bağlıyken kolon/tablo silme "dependencies / is referenced in" → `ERR_NESNE_BAGIMLI`.
- Üretilemeyen: yetkisiz kullanıcıyla işlem (kullanıcı/yetki 3d'ye ait; `ERR_YETKI_YOK` çevirisi zaten var), başka bağlantıda kilitli tablo.

## 7. Kod kararları

- Her iş kendi unit'inde (`uKolon`, `uIndeksKisit`); formlar yalnız alan toplar ve komut önizlemesini gösterir, komutu unit üretir.
- Yeni tablo `TProsedurSekme`'nin "Yeni" kipiyle yapıldı (3f-3 exception/domain ile aynı akış, yeni sekme sınıfı yok). Bunun için `TNesneTuru`'nun ilk değeri `ntTablo`'ya Delphi'nin varsayılan 0 vermesi sorun çıkardı: sekmenin `Tur` alanı atanmazsa "prosedür" sayılıyordu. `TProsedurSekme.Create` artık `Tur := ntProsedur` atar (test: "varsayılan tur ntProsedur").
- Tablo silmede onay + tablonun adını aynen yazdırma (`MetinSor`); engeller (view/trigger/prosedür, FK ile bağlı tablolar) onayda listelenir.
- `TKisitBilgisi.GercekAd` eklendi (INTEG_ adları dahil gerçek ad; DDL çıktısı değişmedi, `Ad` aynen).

## 8. Bilinen sınırlar

- Kolon listeleri pencerede metin olarak yazılır (seçme kutusu yok); ad `AdHazirla` ile BÜYÜK harfe çevrilir, tırnaklı/küçük harfli adlar yazılırsa olduğu gibi tırnaklanır.
- Kolon verisi ve tablo verisi yedeklenmez (bilinçli, uyarı yazılı); geri yükleme elle: yedek dosyasını Sorgu sekmesinde çalıştırın.
- Tip değiştirme veri dönüşümü hatasını Firebird'in cümlesine bırakır; hesaplanan (COMPUTED BY) kolon bu pencerelerden değiştirilemez.
- Kısıt/index işlemleri sonrası aynı tablonun başka açık sekmeleri yenilenmez; yalnız işlemin yapıldığı sekme yenilenir.
- Index'ler sekmesi kısıtlara ait indexleri göstermez (Kısıtlar'da görünürler).
- 3.0 sunucusu (:3052) şifre nedeniyle denenmedi; 3.0 gömülü (3.0.14) denendi. Büyük tabloda `COUNT(*)` onay penceresini geciktirebilir.
- Silinen tablonun açık tablo sekmeleri sorulmadan kapanır.

## 9. Öneriler (bu görevde yapılmadı)

- Kolon seçme kutuları (tablodan kolon listesi) ve kısıt/index düzenleme (şimdilik sil + yeniden oluştur).
- Tablo yeniden adlandırma ve tablo yorumu; tablo/kolon `COMMENT ON`.
- Yedekten "geri yükle" düğmesi (arşiv klasöründeki son dosyayı Sorgu sekmesinde aç).
- Sonraki iş: 3d-2 / 3d-3 yetkiler.

## 10. Sahibine arayüz deneme listesi

1. Bir tablo aç: alt sekmeler **Kolonlar / İndeksler / Kısıtlar / Bağımlılıklar** görünüyor, dil değişince başlıklar değişiyor mu? Sağ tık "Bağımlılıklar" o sekmeyi öne getiriyor mu?
2. **Kolon ekle** (örn. `ZZ INTEGER`, varsayılan `5`), pencerede SQL önizlemesi canlı değişiyor mu? Tamam → onay → kolon listede.
3. Kolon seç → **Adı değiştir**, **Tip / NOT NULL / varsayılan**, **Kolon sil** (bağımlı view'u olan bir kolonda reddedilme cümlesini de gör). 2.5'te NOT NULL kutusu kapalı mı?
4. **İndeksler:** Index oluştur (UNIQUE, DESC), Aktif/pasif yap (durum sütunu değişiyor mu), Index sil.
5. **Kısıtlar:** Kısıt ekle: tür seçince alanlar değişiyor mu (PK/UNIQUE, FK, CHECK)? FK'de bağlanacak tablo listesi geliyor mu? CHECK onayında "mevcut kayıtlar denetlenmez" notu var mı? Kısıt sil (PK'ya bağlı FK varken onayda listeleniyor mu).
6. Tablolar dalına sağ tık → **Yeni tablo...**: şablonlu sekme, adı ve kolonları değiştir, Ctrl+S → onay → dal yenilenir, sekme kapanır. Aynı adı tekrar dene: "Bu adla bir nesne zaten var".
7. Tabloya sağ tık → **Sil**: onayda satır sayısı, "veriler yedeklenmez", engeller listede; Evet dedikten sonra **tablo adını yazdırma** kutusu çıkıyor mu, yanlış yazınca "silinmedi" diyor mu? Başarıda açık tablo sekmesi kapanıyor, `_arsiv` yedeği var mı, alt alanda `DROP TABLE` görünüyor mu?
8. Dili Almanca yap: tüm yeni düğme ve pencereler kesilmeden görünüyor mu?
9. Prosedür ve Trigger düzenleme, exception/domain "Yeni" hâlâ aynen çalışıyor mu? (`TProsedurSekme` kurucusu değişti.)

## 11. Sunucu testi için PowerShell

```powershell
.\Test\TabloYapiTestDerle.bat
$env:FBTEST_SUNUCU = "127.0.0.1"; $env:FBTEST_PORT = "3052"
$env:FBTEST_YOL = "<sunucudaki test veritabani yolu>"
$env:FBTEST_KULLANICI = "SYSDBA"; $env:FBTEST_SIFRE = "<sifre>"
$env:FBTEST_YAZMA = "1"; $env:FBTEST_CIKTI = "$env:TEMP\yapitest_3052.txt"
.\bin\Win64\Release\TabloYapiTest.exe; $LASTEXITCODE
Get-Content $env:FBTEST_CIKTI | Select-String "HATA|Kontrol:"
```
Test `FBY_TEST_*` tablolarını oluşturur ve siler; yalnız 3052/3053/3054'te yazar. Gömülü kip için ortam değişkeni vermeden `.\bin\Win64\Release\TabloYapiTest.exe`. Not: test exe'si `bin\Win64\Release\Diller` klasörünü okur; dil dosyalarını değiştirdiyseniz oraya kopyalayın.
