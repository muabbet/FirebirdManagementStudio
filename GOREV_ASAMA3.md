# Görev: Aşama 3, Yönetim Özellikleri

Bu görev, **Delphi/RAD Studio 12 ve gerçek Firebird sunucuları olan makinede** çalışan ajan içindir. Aşama 2 sahibi tarafından onaylandı ve `main`'e birleştirilmek üzere.

**Önce `CLAUDE.md` dosyasının tamamını oku** (özellikle Bölüm 3, 6, 9, 10). Sonra `ASAMA2C_RAPOR.md` ve `ASAMA2B_RAPOR.md` dosyalarını oku.

## Çalışma düzeni

- Dal: `main`'e birleştirilmiş son halden (Aşama 2 dahil) `asama3a` adlı dal aç. Aşama 2 henüz `main`'de değilse `asama2c` üzerinden aç ve raporda belirt. `main`'e yazma.
- **Bu görev dört alt aşamadır (3a, 3b, 3c, 3d). Her alt aşama ayrı dalda, ayrı raporla biter (`ASAMA3A_RAPOR.md` vb.). Sahibi onaylamadan sonrakine geçme.** Birleşik büyük bir dal açma.
- Tüm yanıt ve rapor Türkçe. Her yeni yazı için üç dil dosyası (tr, en, de) güncellenir. Dosya silme yok (`_arsiv`). Yeni bileşen yok (listede olmayan hiçbir şey eklenmez). Kod sade kalsın (CLAUDE.md Bölüm 3): düğmenin `OnClick`'i işi yapan unit fonksiyonunu doğrudan çağırır, formlarda sabit yazı yok, sınıf bildiriminde alanlar prosedürlerden önce.
- Belirsiz bir şey olursa tahmin etme, sahibine sor.
- Sahibinin Firebird 2.5.9 ve 5.0.4 sunucu bağlantıları gerçek veridir: **orada `insert`/`update`/`delete`/`drop`/kullanıcı silme deneme.** Yalnızca geçici veritabanında dene. Sunucu şifresi sahibindedir; sunucu testlerini (3050/3051) sahibi kendi penceresinde çalıştırır. Ajan şifre tahmin etmez, gömülü 5.0.4 ve geçici veritabanıyla ölçer, sunucu testleri için komutları rapora yazar.
- Tehlikeli işlemler (silme, geri yükleme ile üzerine yazma, kullanıcı silme, yetki geri alma) **her zaman** ne olacağını açıkça yazan onay penceresi ister (`uOnay.pas` kullan). Sessiz ya da otomatik yok.
- Yeni unit gerekiyorsa aşağıda adı verildi. Mimari kuralı: sürüme, Windows'a veya dış programa (`gbak`) bağlı her şey kendi unit'inin arkasında.

## Aşama 2'den devreden işler

Bunlar bu görevin asıl işi değil, 3a başında bak:
1. **Öneri listesi (düşük öncelik):** `m.` yazınca `Ctrl+Boşluk` listesinde seçili satır ilk değil ikinci satır geliyor (`ASAMA2C_RAPOR.md` Adım 4'e bak, çözülmediyse). Birkaç satırlık bir çözüm bulursan düzelt, bulamazsan raporla ve bırak.
2. **Sahibinden bekleyenler** (ajan yapmaz): `SorguTest`'in Firebird 2.5.9 ve 5.0.4 sunucu çalıştırmaları; SynEdit için hazır pakete MPL notu koyma kararı (`LISANSLAR.md` Notlar). Sonuçları gelince `ASAMA2C_RAPOR.md`'ye değil, yeni raporlara not düşülür.

---

# Aşama 3a: `uDDL.pas` (Script üretimi ve metadata çıkarma)

İki adımdır: **Adım 1** tek nesne script üretimi, **Adım 2** bütün veritabanının metadata çıkarımı (IBExpert "Extract Metadata" gibi).

## 3a Adım 1: Tek nesne için "Script üret"

**Amaç:** Ağaçta bir nesneye sağ tıklayıp "Script üret" seçince o nesnenin `CREATE` script'i yeni bir SQL sekmesinde açılsın. Kullanıcı okuyup düzenleyebilir, F5 ile çalıştırabilir. Referans çıktı: `isql -x`.

## Kapsam

Tablo (kolonlar ve kısıtlar), view, prosedür, trigger, generator. Gerekirse ikinci sırada: domain, exception (istenirse sahibine sor, kapsam büyümesin).

Tabloda: kolon tipi (domain kullanıyorsa domain adı), `NOT NULL`, `DEFAULT`, `COMPUTED BY`, karakter seti/`COLLATE`, `IDENTITY` (yalnızca 3.0+), `PRIMARY KEY`, `UNIQUE`, `FOREIGN KEY` (`ON UPDATE/ON DELETE`), `CHECK`. İndeksler ayrı `CREATE INDEX` olarak. Trigger'lar tablo script'inin içinde değil, **ayrı nesne** olarak ayrı üretilir.

Prosedür/trigger gövdesinde `;` olduğu için çıktıya `SET TERM ^ ;` ... `^ SET TERM ; ^` sarmalayıcısı konur (Aşama 2b `KomutlaraBol` bunu zaten anlıyor, çalıştırmada sorun çıkmamalı).

## Mimari (CLAUDE.md Bölüm 4 ve 9)

- **Sürüme bağlı okuma `uMetadata.pas`'te**, **metin üretme `uDDL.pas`'te** olsun. `uDDL` doğrudan `RDB$` tablosu bilmesin; `uMetadata` ona sade kayıtlar (örn. kolon listesi, kısıt listesi, gövde metni) versin. İki unit arasındaki arayüz sade tutulsun.
- Firebird 2.5'te olmayan şeyler (IDENTITY, `CREATE OR ALTER` bazı biçimleri, 4.0+ yeni tipler) için sürümü `uMetadata`'dan sor. Sürümü formdan okuma.
- Anahtar kelime/tip listesi kodda gömülmez (`anahtar_kelimeler.txt`).
- Tırnaklama: yalnızca gerektiğinde `"` ile tırnakla (küçük harf, boşluk, özel karakter, anahtar kelime olan adlarda); gereksiz yere tırnaklama.

## Arayüz

- Ağaç sağ tık menüsü: Tablo/View/Prosedür/Generator düğümlerinde "Script üret" **tek** seçenek olarak eklenir (CLAUDE.md Bölüm 8: en fazla 5-6 seçenek). Kısa alt menü yok.
- Sonuç, **yeni bir sorgu sekmesinde** metin olarak açılır (`uEditor` üzerinden). Çalıştırma otomatik **yapılmaz**.
- Hata/eksik nesne durumunda anlaşılır Türkçe/İngilizce/Almanca cümle (ham mesaj "Ayrıntı"da).

## Doğrulama (zorunlu)

Gerçek test veritabanında, her tür nesne için:
1. Script üret.
2. Boş yeni veritabanında çalıştır.
3. Aynı nesneyi tekrar script üret ve **iki çıktının aynı olduğunu** göster (gidiş-dönüş testi).
4. Mümkünse aynı nesne için `isql -x` çıktısı ile karşılaştır, **fark varsa listele** (aynı olması şart değil, fark gerekçesi yazılsın).

Test aracını `Test\DDLTest.dpr` olarak ekle (gömülü 5.0.4 ve geçici veritabanı; `SorguTest`teki `GeciciVeritabaniOlustur` gibi kendisi oluşturur; dosya silme yok, artıkları `_arsiv`e taşı). Sunucu 2.5.9 testi için komutu rapora yaz, sahibi çalıştırır. En az şu durumlar: bileşik PK, FK + `ON DELETE CASCADE`, domain kolon, computed kolon, default değerler, `CHECK`, `COLLATE`, trigger (before/after, insert/update birlikte), gövdesinde `;` olan prosedür, giriş/çıkış parametreli prosedür, view.

**Bitiş ölçütü:** Sağ tık > Script üret ile bir tablo, view, prosedür, trigger ve generator'ın script'i yeni sekmede açılıyor; boş veritabanında çalışıp aynı nesneyi geri veriyor.

## 3a Adım 2: Tüm veritabanının metadata'sını çıkar ("Metadata çıkar")

IBExpert'teki *Tools > Extract Metadata* karşılığı. Tek nesne değil, **bütün veritabanının** yapısı tek script olarak çıkar. Veri (satırlar) dahil değildir, yalnızca yapı.

**Önce Adım 1 bitsin.** Bu adım Adım 1'deki tek nesne üreticilerini birleştirir; aynı kodu tekrar yazma, `uDDL.pas`'teki fonksiyonları çağır. Adım 1 raporu sahibine gittikten sonra Adım 2'ye başla.

### İstenen davranış

- **Tek yol:** Ağaçta bağlı bir veritabanına sağ tık > **"Metadata çıkar"** (bu menüde tek ek seçenek; 5-6 sınırını aşma). Araç çubuğuna düğme ekleme.
- Küçük bir pencere açılır (`fMetadataCikar`; form ince, iş `uDDL.pas`'te):
  - **Hedef:** iki seçenek: *Dosyaya kaydet* (dosya seçtirilir) veya *Panoya kopyala*. Varsayılan dosya. Yeni sorgu sekmesinde açmak ayrıca istenmedi; yine de çok küçük iş çıkarsa sahibine öner.
  - **Seçenekler** (IBExpert *General Options* ekranı gibi):
    - [ ] `CREATE DATABASE` ifadesini üret
    - [ ] `CONNECT` ifadesini üret
    - [ ] `CONNECT` ve `CREATE DATABASE` ifadelerine **şifreyi de yaz**
  - Üç kutu da **varsayılan kapalıdır**. (IBExpert'te şifre kutusu açık geliyor, burada kapalı: CLAUDE.md Bölüm 10, şifreler düz metin yazılmaz.) Şifre kutusu işaretlenirse "Şifre script içinde düz metin olarak görünecek" diye **net uyarı** göster; şifre kayıtlı bağlantıdan (DPAPI) alınır, kullanıcı ayrıca yazmaz. İlk iki kutu kapalıysa şifre kutusu pasif olsun.
  - **"Hepsini çıkar"** (extract all) tek ve varsayılan davranıştır: aşağıdaki sıradaki tüm nesne türleri birlikte çıkar. Nesne türü bazında kutu listesi **yok** (bu sürümde ayar yığma yok, Bölüm 8). Bu sırayı ihtiyaç doğarsa sonra seçmeli yaparız.
- Dosyaya yazılıyorsa: hedef dosya zaten varsa **üzerine yazma onayı** (`uOnay.pas`, dosya adı ve tarih yazılı), onaysız yazma. Dosya silme yok. Büyük veritabanında bellekte tek metin biriktirme: **dosyaya akış (stream) olarak yaz**. Panoya alınıyorsa çok büyük metinde (örn. 5-10 MB üstü) "pano için fazla büyük, dosyaya kaydedin" cümlesi (tr/en/de) ver, sessizce kesme.
- Dosya kodlaması: UTF-8 (BOM'lu veya değil, ölçüp yaz), başına `SET NAMES UTF8;`. Karakter seti bağlantıdan ve veritabanından alınır, kodda sabit yazılmaz. (Türkçe karakterli nesne adları ve açıklamalar bozulmamalı.)
- İlerleme: uzun sürerse hangi nesne türünde olduğu görünür, iptal edilebilir. Donma yok (Aşama 2'deki yöntem). İptalde yarım dosya silinmez, kullanıcıya haber verilir.

### Çıkış sırası (bağımlılığa göre; referans: `isql -x`)

Script boş bir veritabanında **hatasız** çalışmalı. Bunun için tek tek nesneleri art arda koymak yetmez, sıra şöyle olmalı:
1. (Seçilmişse) `CREATE DATABASE` / `CONNECT`
2. Roller, UDF'ler (varsa), exception'lar, generator'lar/sequence'lar (ilk değerleriyle: `SET GENERATOR ... TO ...`)
3. Domain'ler
4. Tablolar: **yalnızca kolonlar**, kısıtlar (PK/UK/FK/CHECK) olmadan
5. Prosedürler: önce **boş gövdeli** (parametreleriyle) iskelet olarak, çünkü prosedürler birbirini ve view'ları çağırabilir (isql -x böyle yapar)
6. View'lar (view'lar birbirine bağlıysa **bağımlılık sırasına göre**; döngü varsa raporla)
7. Birincil anahtar ve benzersiz kısıtlar, sonra yabancı anahtarlar, `CHECK` kısıtları
8. İndeksler
9. Trigger'lar
10. Prosedür gövdeleri (`ALTER PROCEDURE ...`)
11. Yetkiler (`GRANT`), açıklamalar (`COMMENT ON`)

`SET TERM` sarmalayıcısı Adım 1'deki gibi. Bağımlılık bilgisi `RDB$DEPENDENCIES`'ten **`uMetadata.pas`** içinde okunur (sürüme bağlı kısım orada, CLAUDE.md Bölüm 9). `uDDL` doğrudan `RDB$` bilmez. Firebird 2.5'te olmayan nesne türleri (3.0+ paketler, 4.0+ yeni tipler vb.) için sürümü `uMetadata`'dan sor.

**Kapsam dışı (bu sürümde):** veri, `gbak` yerine geçecek tam yedek, GRANT'in kullanıcı oluşturma kısmı (kullanıcılar 3d'de), `Limit file size` seçeneği (IBExpert'teki dosyayı parçalara bölme; istenmedi).

### Doğrulama (zorunlu)

Gerçek ve **karmaşık** bir test veritabanında (en az: bileşik PK, FK zinciri, birbirini çağıran prosedürler, view içinde view, trigger'lar, domain, generator, exception, `COMMENT`, `GRANT`; mümkünse sahibinin büyük bir veritabanının kopyası):
1. Metadata'yı dosyaya çıkar.
2. Boş yeni veritabanında `isql -i dosya.sql` ve ayrıca uygulamanın kendi çalıştırıcısıyla (F5) çalıştır. **Hata sayısını** yaz; hata varsa nedenini ve hangi satır olduğunu raporla.
3. Oluşan veritabanından tekrar metadata çıkar ve ilk çıktıyla **karşılaştır** (satır satır; fark varsa listele ve gerekçesini yaz).
4. Aynı veritabanı için `isql -x` çıktısı ile karşılaştır; fark varsa listele (aynı olması şart değil, fark **açıklanmalı**).
5. Şifre kutusu kapalıyken çıktıda şifrenin **hiç geçmediğini** kontrol et (metin araması).
6. Gömülü 5.0.4'te ölç; Firebird 2.5.9 sunucu için komutu rapora yaz, sahibi çalıştırır.

`Test\DDLTest.dpr` bu senaryoyu da içersin.

**Bitiş ölçütü:** Sağ tık > Metadata çıkar ile bir veritabanının tüm yapısı dosyaya (veya panoya) çıkıyor; boş veritabanında hatasız çalışıp aynı yapıyı kuruyor; şifre varsayılanda script'e girmiyor.

---

# Aşama 3b: Veri dışa aktarma

**Önce sahibine sor (3b'ye başlamadan):** "Excel" ne demek? Ek bileşen yasak olduğu için gerçek `.xlsx` yazmak makul sürede kendi kodumuzla zor. Öneri: **yalnızca CSV** (UTF-8 BOM'lu, ayraç kullanıcı ortamına göre `;` veya `,`, Excel'de çift tıkla açılır). `.xlsx` istenirse ayrıca karar verilir. Sahibi cevap verene kadar `.xlsx` yazma.

## Kapsam (CSV varsayılırsa)

- Sonuç ızgarasındaki (sorgu sonucu veya tablo verisi) **tüm** satırlar dışa aktarılır, yalnızca ekrandaki 500 satır değil. Parça parça çekme mantığı `uSorgu.pas`'te, dışa aktarma da yeni küçük `uAktar.pas` içinde olsun; formda iş yok. Büyük sonuçta bellekte biriktirme, satır satır dosyaya yaz.
- İlerleme ve iptal: uzun sürerse kullanıcı görür (satır sayısı), durdurabilir. Donma yok (Aşama 2'deki gibi, ana iş parçacığı kilitlenmesin; nasıl yapıldığına bak, aynı yöntemi kullan).
- Alan kuralları: ayraç/tırnak/satır sonu içeren değer tırnaklanır, `NULL` boş alan olur, tarih biçimi ISO (`yyyy-mm-dd hh:nn:ss`), BLOB yazılmaz (boş bırakılıp rapora/mesaja "BLOB alanları atlandı" notu).
- Dosya yeni bir ad olmalı ya da var olan dosyanın üzerine yazılacaksa **onay penceresi** çıkar (kural 6).
- Arayüz: sonuç alanının üstündeki mevcut düğmelerin yanına "Dışa aktar" (tek düğme). Araç çubuğuna ekleme (5-6 düğme sınırı), karar vermeden önce mevcut düğmeleri say.

**Bitiş ölçütü:** 100.000 satırlık bir tablonun sonucu CSV'ye aktarılıp Excel'de açılıyor, Türkçe karakterler bozulmuyor.

---

# Aşama 3c: Yedek/geri yükleme (`gbak`)

Yeni unit: `uYedek.pas`. `gbak.exe`'yi **kendi çağırır** (Windows'a bağlı kısım bu unit'in arkasında).

## Kapsam

- **Yedek al:** kaynak veritabanı (açık bağlantıdan), hedef `.fbk` dosyası. Seçenekler en az: yok. Varsayılanlar makul (tam yedek). Ayar yığma yok.
- **Geri yükle:** `.fbk` > yeni veritabanı dosyası. **Var olan bir veritabanının üzerine yazma** varsayılan kapalıdır; açılırsa ayrı ve çok net bir onay penceresi ister (dosya adı, boyut, tarih yazılı). Daha güvenli seçenek önerilir: hedef dosya zaten varsa yeni ad iste.
- `gbak.exe` yolu: `fbclient.dll` ile aynı klasör/sürüm mantığıyla bulunur. Bulunamazsa kullanıcıdan seçtir (kısa pencere), seçimi saklama konusunda sahibine sor. Sürüm uyumuna dikkat: sunucu 2.5 iken gbak 5.0 çalıştırma gibi durumlarda `ODS` uyumsuzluğu olabilir, bunu sade bir cümleyle bildir (tr/en/de).
- **Şifre komut satırına yazılmaz.** `ISC_PASSWORD` ortam değişkeni ile iletilir (yalnızca o alt işlem için). Şifre DPAPI kayıtlı bağlantıdan alınır (Aşama 1b davranışı); kayıtlı değilse şifre sorulur.
- gbak çıktısı canlı olarak mesaj alanında gösterilir; ham çıktı "Ayrıntı"da saklanır. Çıkış kodu sıfır değilse anlaşılır hata cümlesi.
- Uzun sürer, arayüz donmaz; iptal edilebilir (iptalde yarım kalan hedef dosya silinmez, kullanıcıya haber verilir).
- Bağlantı: yedek sırasında açık bağlantı sorun değil; geri yüklemede hedef dosya bir açık bağlantıda kullanılıyorsa uyarılır.

**Bitiş ölçütü:** Geçici veritabanı yedeklenip yeni dosyaya geri yükleniyor, geri yüklenen veritabanına bağlanıp aynı tablolar açılıyor. 2.5.9 ve 5.0.4 sunucu denemesini sahibi yapar.

---

# Aşama 3d: Kullanıcı ve yetki yönetimi

Yeni unit: `uKullanici.pas`. Sürüme bağlı her şey burada.

**Önce ölç, sonra sahibine sor:** Firebird 2.5 ile 3.0+ arasında kullanıcı yönetimi çok farklıdır (2.5: Service API / `security2.fdb` ve `gsec`; 3.0+: SQL `CREATE USER`/`ALTER USER`/`DROP USER`, `SEC$USERS`). Hangi yolla ne yapılabildiğini kısa bir **ölçüm raporu** olarak yaz (FireDAC'ın hangi yöntemi destekledi, hangi sürümde ne oldu), sonra sahibinden onay al ve yazmaya geç. Ölçümde kullanıcı oluşturma/silme sunucuda yapılacaksa geçici kullanıcı adıyla (örn. `GECICI_TEST_01`) çalış, gerçek kullanıcılara dokunma.

## Kapsam (ölçüme göre daralabilir)

- Kullanıcı listesi (ad, ad-soyad, yönetici mi). **Şifre hiçbir yerde gösterilmez/saklanmaz** (CLAUDE.md Bölüm 10).
- Kullanıcı ekle, şifre değiştir, sil (silme için net onay).
- Yetki yönetimi: bir nesne üzerinde `GRANT`/`REVOKE` (tablo/view/prosedür) ve rol atama. Bu kısımda önce **mevcut yetkileri göster** (kimde ne var), sonra değiştirme. Yetki değişiklikleri script olarak önizlenir, kullanıcı onaylayınca uygulanır (Aşama 4'teki "önizleme ile toplu güncelleme" ruhuyla).
- Yetkisiz kullanıcı (örn. SYSDBA değil) için işlemler anlaşılır cümleyle reddedilir; menü o durumda gizlenmez ama net hata verir.
- Arayüz: tek yeni pencere ("Kullanıcılar ve yetkiler"), ağaçta sunucu/bağlantı sağ tık menüsünden açılır. Tek yol, kısa menü (Bölüm 1 ana ilke).

**Bitiş ölçütü:** Gömülü/geçici ortamda kullanıcı eklenip listeleniyor, bir tabloya `GRANT SELECT` verilip geri alınıyor. 2.5.9 ve 5.0.4 sunucu denemelerini sahibi yapar.

---

## Her alt aşama için ortak testler ve rapor

- Mevcut testler geçmeli: `SorguTest` (80 kontrol), `BaglantiDosyasiTest`, `MetadataTest`. Yeni özellik için ilgili yeni test eklenir.
- Programı derle (`Derle.bat`), kendin arayüzde dene ve denediklerini yaz; **denemediğini "denemedim" diye açıkça belirt** (önceki raporlardaki gibi).
- Üç dil dosyasında yeni anahtarlar eksiksiz mi, kontrol et (boş değer, eksik anahtar yok).
- `ASAMA3X_RAPOR.md`: ne yapıldı, ne test edildi (sayılarla), neler eksik kaldı, sahibinin elle deneme listesi, sahibinden bekleyenler (sunucu testleri).
- `CLAUDE.md` Aşama 3 kutularını **işaretleme** (sahibi onaydan sonra işaretletir). Bir sonraki alt aşamaya ya da Aşama 4'e **geçme**.
