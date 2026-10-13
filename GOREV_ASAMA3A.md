# Görev: Aşama 3a, `uDDL.pas` (Script üretimi) ve metadata çıkarma

Bu görev, **Delphi/RAD Studio 12 ve gerçek Firebird sunucuları olan makinede** çalışan ajan içindir. Aşama 1, 1b ve 2 sahibi tarafından onaylandı ve `main`'e birleştirildi. Bu, Aşama 3'ün (Yönetim Özellikleri) **ilk alt aşamasıdır**; genel plan `GOREV_ASAMA3.md`'de (3b, 3c, 3d orada), ama **şimdilik yalnızca 3a'yı yap**.

**Önce `CLAUDE.md` dosyasının tamamını oku** (özellikle Bölüm 3, 4, 6, 9, 10). Sonra `ASAMA2C_RAPOR.md` dosyasını ve `Kaynak\uMetadata.pas`, `Kaynak\uDDL.pas` (şu an boş iskelet), `Kaynak\uSorgu.pas` (`KomutlaraBol`, `TirnakliAd`), `Kaynak\fAna.pas` (`pmNesne`, `YeniSorgu`) dosyalarına göz at.

## Çalışma düzeni

- Dal: `main`'den `asama3a` adlı yeni dal aç, `main`'e yazma. Önce `git fetch`, `git checkout main`, `git pull`, sonra dalı aç. Bu görev dosyası `main`'de.
- Tüm yanıt ve rapor Türkçe. Her yeni yazı için üç dil dosyası (tr, en, de) güncellenir. Dosya silme yok (`_arsiv`). Yeni bileşen yok. Kod sade kalsın (CLAUDE.md Bölüm 3): düğme/menü `OnClick`'i işi yapan unit fonksiyonunu doğrudan çağırır, formlarda sabit yazı yok, sınıf bildiriminde alanlar prosedürlerden önce, boş olay yöneticisi yok.
- Belirsiz bir şey olursa tahmin etme, sahibine sor.
- Sahibinin Firebird 2.5.9 ve 5.0.4 sunucu bağlantıları gerçek veridir: **orada nesne oluşturma/silme deneme.** Yalnızca geçici veritabanında dene. Sunucu şifresi sahibindedir; 3050/3051 sunucu testlerini sahibi kendi penceresinde çalıştırır. Ajan şifre tahmin etmez, gömülü 5.0.4 ve geçici veritabanıyla ölçer, sunucu testleri için komutları rapora yazar.
- Tehlikeli işlemler (dosyanın üzerine yazma vb.) net onay penceresi ister (`uOnay.OnayIste`).
- **İki adım sırayla yapılır.** Adım 1 bitip raporlandıktan sonra Adım 2'ye geç; **Adım 1 raporunu sahibine göstermek için araya bir ara rapor yaz** (`ASAMA3A_RAPOR.md`'nin Adım 1 bölümü) ve devam etmeden önce sahibine "Adım 1 tamam" de. Sahibi onaylamadan 3b'ye **geçme**.

## Aşama 2'den devreden işler

1. **Öneri listesi (düşük öncelik):** `m.` yazınca `Ctrl+Boşluk` listesinde seçili satır ilk değil ikinci satır geliyor (`ASAMA2C_RAPOR.md` Adım 4.1: `SynCompletionProposal.pas` içinde `Position` yalnızca `CurrentString` değişince 0'a çekiliyor, `.` ile tetiklenen listede `CurrentString` şüpheli, denenmedi). Çalışan arayüzde hata ayıklayıcıyla `Position` değerine bak. Birkaç satırlık bir çözüm bulursan düzelt, bulamazsan raporla ve bırak. Ana işi geciktirmesin.
2. **Sahibinden bekleyenler** (ajan yapmaz): `SorguTest`'in Firebird 2.5.9 ve 5.0.4 sunucu çalıştırmaları. (SynEdit lisans notu işi `SYNEDIT_LISANS.txt` ile ele alındı.)

---

# Adım 1: Tek nesne için "Script üret"

**Amaç:** Ağaçta bir nesneye sağ tıklayıp "Script üret" seçince o nesnenin `CREATE` script'i yeni bir SQL sekmesinde açılsın. Kullanıcı okuyup düzenleyebilir, F5 ile çalıştırabilir. Referans çıktı: `isql -x`.

## Kapsam

Ağaçtaki dört dal: **Tablo, View, Prosedür, Generator.** Ağaçta Trigger dalı yok; trigger'lar tablonun script'inin **sonuna** eklenir (aşağıya bak). Domain ve exception tek tek script üretimi bu adımda **yok** (yalnızca Adım 2'deki tüm veritabanı çıkarımında olacak).

Tabloda: kolon tipi (domain kullanıyorsa domain adı), `NOT NULL`, `DEFAULT`, `COMPUTED BY`, karakter seti/`COLLATE`, `IDENTITY` (yalnızca 3.0+), `PRIMARY KEY`, `UNIQUE`, `FOREIGN KEY` (`ON UPDATE/ON DELETE`), `CHECK`. İndeksler ayrı `CREATE INDEX` olarak, tablonun altına. Tablonun **trigger'ları** da aynı script'te, en sonda, ayrı `CREATE TRIGGER` olarak gelir (kullanıcı için tek yol; ayrıca "trigger script'i üret" menüsü yok).

Prosedür/trigger gövdesinde `;` olduğu için çıktıya `SET TERM ^ ;` ... `^ SET TERM ; ^` sarmalayıcısı konur (Aşama 2b `KomutlaraBol` bunu zaten anlıyor, çalıştırmada sorun çıkmamalı).

## Mimari (CLAUDE.md Bölüm 4 ve 9)

- **Sürüme bağlı okuma `uMetadata.pas`'te**, **metin üretme `uDDL.pas`'te** olsun. `uDDL` doğrudan `RDB$` tablosu bilmesin; `uMetadata` ona sade kayıtlar (örn. kolon listesi, kısıt listesi, gövde metni) versin. İki unit arasındaki arayüz sade tutulsun.
- Firebird 2.5'te olmayan şeyler (IDENTITY, `CREATE OR ALTER` bazı biçimleri, 4.0+ yeni tipler) için sürümü `uMetadata`'dan sor. Sürümü formdan okuma.
- Anahtar kelime/tip listesi kodda gömülmez (`anahtar_kelimeler.txt`).
- Tırnaklama: yalnızca gerektiğinde `"` ile tırnakla (küçük harf, boşluk, özel karakter, anahtar kelime olan adlarda); gereksiz yere tırnaklama.

## Arayüz

- Ağaç sağ tık menüsü (`pmNesne`, `fAna.pas`; görünürlük `pmNesnePopup` içinde): Tablo/View/Prosedür/Generator düğümlerinde "Script üret" **tek** seçenek olarak eklenir (CLAUDE.md Bölüm 8: en fazla 5-6 seçenek). Alt menü yok. `OnClick` doğrudan `uDDL` fonksiyonunu çağıran kısa bir yordamı çalıştırsın (`miAcClick` gibi sade).
- Sonuç, **yeni bir sorgu sekmesinde** metin olarak açılır. Şu an `YeniSorgu` (`fAna.pas`) boş sekme açıyor; metinle açabilmesi için en küçük değişikliği yap (örn. isteğe bağlı bir `Metin` parametresi ve `TSorguSekme` içinde editöre yazma, `uEditor` üzerinden). Çalıştırma otomatik **yapılmaz**.
- Hata/eksik nesne durumunda anlaşılır Türkçe/İngilizce/Almanca cümle (ham mesaj "Ayrıntı"da).

## Doğrulama (zorunlu)

Gerçek test veritabanında, her tür nesne için:
1. Script üret.
2. Boş yeni veritabanında çalıştır.
3. Aynı nesneyi tekrar script üret ve **iki çıktının aynı olduğunu** göster (gidiş-dönüş testi).
4. Mümkünse aynı nesne için `isql -x` çıktısı ile karşılaştır, **fark varsa listele** (aynı olması şart değil, fark gerekçesi yazılsın).

Test aracını `Test\DDLTest.dpr` olarak ekle (`Test\DDLTestDerle.bat` ile, `SorguTestDerle.bat` gibi) (gömülü 5.0.4 ve geçici veritabanı; `SorguTest`teki `GeciciVeritabaniOlustur` gibi kendisi oluşturur; dosya silme yok, artıkları `_arsiv`e taşı). Sunucu 2.5.9 testi için komutu rapora yaz, sahibi çalıştırır. En az şu durumlar: bileşik PK, FK + `ON DELETE CASCADE`, domain kolon, computed kolon, default değerler, `CHECK`, `COLLATE`, trigger (before/after, insert/update birlikte), gövdesinde `;` olan prosedür, giriş/çıkış parametreli prosedür, view.

**Bitiş ölçütü:** Sağ tık > Script üret ile bir tablo (indeks ve trigger'larıyla), view, prosedür ve generator'ın script'i yeni sekmede açılıyor; boş veritabanında çalışıp aynı nesneyi geri veriyor.


---

# Adım 2: Tüm veritabanının metadata'sını çıkar ("Metadata çıkar")

IBExpert'teki *Tools > Extract Metadata* karşılığı. Tek nesne değil, **bütün veritabanının** yapısı tek script olarak çıkar. Veri (satırlar) dahil değildir, yalnızca yapı.

**Önce Adım 1 bitsin.** Bu adım Adım 1'deki tek nesne üreticilerini birleştirir; aynı kodu tekrar yazma, `uDDL.pas`'teki fonksiyonları çağır. Adım 1 raporu sahibine gittikten sonra Adım 2'ye başla.

### İstenen davranış

- **Tek yol:** Ağaçta bağlı bir veritabanına sağ tık > **"Metadata çıkar"**. Araç çubuğuna düğme ekleme.
- **Menü sınırı sorunu (sahibine sor):** Bağlantı düğümünün menüsünde şu an altı seçenek var (Bağlan, Kes, Düzenle, Kaldır, Klonla, Yenile); yenisi yedinci olur (CLAUDE.md Bölüm 8: en fazla 5-6). Klonla ve Kayıttan Kaldır zaten araç çubuğunda var. Öneri: menüden **Klonla**yı çıkarmak (araç çubuğundaki düğme kalır). Kararı sahibi versin; sormadan menüden bir şey kaldırma.
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

## Rapor ve bitiş

- Mevcut testler geçmeli: `SorguTest` (80 kontrol), `BaglantiDosyasiTest`, `MetadataTest`. Yeni test: `Test\DDLTest.dpr`.
- Programı derle (`Derle.bat`), arayüzü kendin dene; **denemediğini "denemedim" diye açıkça yaz** (önceki raporlardaki gibi).
- Üç dil dosyasında yeni anahtarlar eksiksiz mi kontrol et (boş değer, eksik anahtar yok).
- `ASAMA3A_RAPOR.md` (Türkçe, kısa): ne yapıldı, ne test edildi (sayılarla), neler eksik kaldı, `isql -x` farkları, sahibinin elle deneme listesi, sahibinden bekleyenler (2.5.9/5.0.4 sunucu testleri).
- `CLAUDE.md` Aşama 3 kutularını **işaretleme** (sahibi onaydan sonra işaretletir). 3b'ye geçme.
