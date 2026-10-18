# Firebird Yöneticisi: Ajan Görev Belgesi

Bu belge, Delphi ile yazılacak SSMS (SQL Server Management Studio) benzeri bir Firebird yönetim aracının tasarım kurallarını ve aşamalı görev listesini içerir. Ajan, işe başlamadan önce **tüm belgeyi** okumalıdır.

---

## 1. Amaç

Firebird için sade, kolay kullanımlı, SSMS'e görsel olarak benzeyen bir yönetim aracı yapmak. Araç ileride **ücretsiz ve açık kaynak** olarak herkese açılacak. Para kazanma amacı yok. Ana hedef kolaylıktır.

**Ana ilke:** Kullanıcının kafası karışmasın. Bir iş için tek yol, kısa menüler, anlaşılır Türkçe/İngilizce/Almanca mesajlar.

---

## 2. Teknik Zemin

- Dil/IDE: Delphi, RAD Studio 12 Athens, VCL
- Veritabanı erişimi: **FireDAC** (Firebird sürücüsü). IBX kullanılmayacak.
- Desteklenen Firebird sürümleri: 2.5, 3.0, 4.0, 5.0 (kodun başında "test edildi" notu tutulacak)
- Görünüm: Delphi **VCL Styles** ile açık ve temiz bir tema
- Ayarlar ve dil dosyaları: `System.JSON`
- Şifre saklama: Windows **DPAPI** (şifreler düz metin olarak diske yazılmayacak)

---

## 3. Kod Yazım Kuralları (ÇOK ÖNEMLİ)

Bu kurallar projenin sahibi tarafından özellikle istenmiştir. İhlal edilmemelidir.

1. **Kod olabildiğince basit ve sade olsun.** "Ne kadar basit o kadar güzel." Sahibi kodu kendisi de okuyacak.
2. **Bir düğmenin ne yaptığı tek adımda görülebilsin.** Ata sınıf zincirinde, karmaşık kalıtımda veya olay (event) zincirlerinde aranmasın. Düğmenin `OnClick` olayı doğrudan işi yapan unit'teki fonksiyonu çağırsın.
3. **Formdaki bir bileşenin olayı açıldığında hata vermesin.** Boş veya eksik bağlanmış olay yöneticisi bırakılmasın.
4. **Form ince, mantık unit'lerde olsun.** Formlar sadece arayüzü bilir, işi unit'ler yapar.
5. **Delphi sınıf bildiriminde sıralama kuralı:** Aynı görünürlük bölümünde (`private`, `public` vb.) önce **alan (değişken) bildirimleri**, sonra **procedure/function bildirimleri** yazılsın. Ters sıra projenin sahibinde derleme hatası veriyor.
6. **Hiçbir şey otomatik silinmesin.** Dosya silme yerine taşıma veya arşivleme tercih edilir. Kullanıcıya yönelik tehlikeli işlemler (silme, toplu güncelleme) her zaman net bir onay penceresi ister.
7. Karmaşık, "akıllı" çözümler yerine sıradan ve okunur çözümler tercih edilsin.

---

## 4. Mimari: Unit Bölünmesi

Her iş kendi unit'inde olacak. Birbirinden bağımsız olmalı.

| Unit | Görevi |
|---|---|
| `uBaglanti.pas` | Bağlantı tanımları, bağlanma/kopma, kayıtlı bağlantı listesi (JSON), şifrelerin DPAPI ile saklanması |
| `uMetadata.pas` | Tablo, kolon, index, constraint, view, prosedür, trigger, generator listelerini okuma. **Sürüme bağlı her şey burada.** |
| `uSorgu.pas` | SQL çalıştırma, parça parça (ör. 500'er satır) sonuç çekme, hata yakalama |
| `uSonucGrid.pas` | Sonuç ızgarasının davranışları (bkz. Bölüm 7) |
| `uEditor.pas` | SQL editörünün (SynEdit) arkasındaki sarmalayıcı. Formlar SynEdit'i doğrudan bilmez. |
| `uDil.pas` | Çok dilli yazı sistemi (bkz. Bölüm 6) |
| `uDDL.pas` | Nesnelerden `CREATE` script'i üretme (Aşama 3) |
| `fAna.pas` | Ana form (ağaç, sekmeler, araç çubuğu, sonuç alanı) |

**Kural:** Sürüme bağlı, harici bileşene bağlı veya Windows'a bağlı her şey ilgili unit'in arkasına gizlenir. Böylece ileride değiştirmek tek yerde olur.

---

## 5. Üçüncü Parti Bileşen Politikası

**Genel kural:** Üçüncü parti bileşen sadece zor ve sıkıcı kısımlarda kullanılır. Programın asıl işi (bağlantı, metadata, DDL, dil, ekran düzeni) kendi kodumuzla yazılır.

**Zorunlu şartlar.** Her harici bileşen için:
1. Ücretsiz ve **kaynak kodu açık** olmalı (proje herkese açılacak, başkaları derleyebilmeli).
2. Hâlâ bakımı yapılıyor olmalı (son yıllarda güncellenmiş).
3. Bunu kendimiz makul sürede yazamıyor olmalıyız. Yazabiliyorsak kendimiz yazarız.

**Ücretli bileşenler yasak:** TMS, DevExpress (cxGrid dahil) vb. kullanılmayacak. Gerekçe: başkaları lisanssız derleyemez.

**İzin verilen liste (bu liste dışında hiçbir şey eklenmeyecek):**
- **SynEdit**: SQL editörü (sözdizimi renklendirme). Önce RAD Studio 12 GetIt üzerinden kurulabiliyor mu kontrol et, değilse GitHub'dan kaynak kodlu sürümü kullan ve sahibine bildir.
- **Virtual TreeView**: *sadece* standart `TTreeView` yavaş kalırsa. Önce `TTreeView` ile başla.
- Sonuç ızgarası: **standart TDBGrid** (bkz. Bölüm 7).

**Ajan kendi kafasına göre yeni bileşen eklemeyecek.** Gerekli görürse önce sahibine sorar ve gerekçesini üç soruya göre yazar.

---

## 6. Çok Dillilik

Başlangıç dilleri: **Türkçe (tr), İngilizce (en), Almanca (de)**. Dil sistemi **baştan** kurulacak, sonradan eklenmeyecek.

1. Dil dosyaları düz JSON: `tr.json`, `en.json`, `de.json`. İçerik: `"BAGLAN": "Bağlan"` gibi anahtar-değer çiftleri. Dosyalar uygulamanın yanındaki `Diller` klasöründe durur. Yeni dil eklemek için kod derlemek gerekmez, sadece yeni bir JSON dosyası konur.
2. Tek bir fonksiyon: `T('ANAHTAR')`. **Formlarda hiçbir sabit yazı olmayacak**, her görünen yazı bu fonksiyondan gelecek.
3. Yedekleme sırası: seçili dilde yoksa İngilizce, İngilizcede de yoksa anahtarın kendisi gösterilir. Program asla boş yazıyla açılmaz.
4. Dil, program yeniden başlamadan anında değişebilmeli.
5. Düğme ve menü genişlikleri sabit olmayacak, yazıya göre uzayacak (Almanca'da yazılar kesilmesin).
6. **Yeni bir özellik eklenince üç dil dosyasına da anahtar eklenmeden iş bitmiş sayılmaz.**
7. Firebird'in ham hata mesajları İngilizce gelir. Sık görülen hatalar (yanlış şifre, veritabanı bulunamadı, kilitli kayıt, bağlantı kopması vb.) için kendi anlaşılır cümlelerimiz yazılır ve çevrilir. Ham mesaj "Ayrıntı" bölümünde saklı durur.

---

## 7. Sonuç Izgarası (`uSonucGrid.pas`)

Standart **TDBGrid** kullanılacak, aşağıdaki altı özellik kendi kodumuzla eklenecek:

1. Başlığa tıklayınca sıralama
2. Satırlarda bir açık, bir koyu renk (zebra)
3. NULL değerler gri ve eğik yazıyla gösterilsin (SSMS gibi)
4. Kolon genişliği içeriğe göre otomatik ayarlansın
5. Seçili hücreler `Ctrl+C` ile kopyalanabilsin (Excel'e yapıştırılabilir biçimde)
6. Uzun metin ve BLOB alanları kısaltılarak gösterilsin, çift tıklayınca tamamı açılsın

**Büyük sonuçlar:** Sorgu çok satır döndürürse sonuçlar parça parça çekilir (ör. 500'er satır). Kullanıcı aşağı indikçe devamı gelir. Bu mantık `uSorgu.pas` içinde olacak, grid'de değil.

**Yedek plan:** Bu yetmezse JvDBGrid (JVCL, MPL lisansı) düşünülür, ama **sahibine sorulmadan geçilmeyecek**.

---

## 8. Ekran Düzeni (SSMS'ten esinlenmiş, sadeleştirilmiş)

- **Sol panel:** Kayıtlı bağlantılar (klasörlere konabilir, aynı anda birden fazlası açık olabilir). Bağlı bir bağlantının altında dört dal: Tablolar, View'lar, Prosedürler, Generator'lar.
- **Sağ üst:** Sekmeli çalışma alanı. Her açılan şey (sorgu, tablo verisi, tablo yapısı) kendi sekmesinde açılır.
- **Sağ alt:** Sonuç alanı. Sorgu sonucu veya hata mesajı burada görünür.
- **Üstte:** En fazla 5-6 düğmeli **tek** araç çubuğu (Bağlan, Yeni Sorgu, Çalıştır, Yenile gibi). İkinci çubuk ve iç içe menü yok.
- **Sağ tık menüsü:** Bir nesnede en fazla 5-6 seçenek ("İlk 100 satırı göster", "Yapıyı göster", "Script üret" gibi).
- **İlk sürümde ayar penceresi yok.** Makul varsayılanlar kullanılır, ayarlar sonra eklenir (dil seçimi hariç).
- **Görsel:** Açık ve temiz VCL Style teması, nesne ağacında tutarlı küçük ikon seti (tablo, view, prosedür vb. için ayrı), cömert boşluklar ve okunaklı yazı boyutu.

**Her özellik için soru:** "Kullanıcı bunu tek tıkla yapabiliyor mu?"

---

## 9. Firebird Sürüm Bağımsızlığı

Yeni Firebird sürümleri çıkınca güncellemek kolay olmalı.

1. Bağlanınca sunucu sürümü bir kez öğrenilir: `rdb$get_context('SYSTEM', 'ENGINE_VERSION')`. Sonuç saklanır.
2. Sürüme bağlı **hiçbir şey formda olmayacak.** Hepsi `uMetadata.pas` içinde ve anahtar kelime dosyasında olacak.
3. SQL anahtar kelime ve veri tipi listeleri kodun içine gömülmeyecek, ayrı bir metin dosyasında (`anahtar_kelimeler.txt`) duracak.
4. Kodun başında "Test edilen Firebird sürümleri: 2.5, 3.0, 4.0, 5.0" notu tutulacak.
5. Sürüm uyumunda metadata için önce FireDAC `TFDMetaInfoQuery`, gerekirse `RDB$` sistem tablolarına doğrudan sorgu kullanılır.
6. `fbclient.dll` 32/64 bit uyumuna dikkat edilecek, hangi sürümle çalıştığı belgelenecek.
7. Yeni Firebird sürümü çıktığında: resmi release notes ve Language Reference okunur, değişen sistem tabloları/sözdizimi çıkarılır, sadece ilgili unit güncellenir ve **o sürümde gerçek bir test veritabanıyla denenir.**

---

## 10. Güvenlik ve Dağıtım

- Bağlantı şifreleri JSON'a düz yazılmaz, DPAPI ile şifrelenir.
- Tehlikeli işlemler (DROP, DELETE, UPDATE'in WHERE'siz hali, toplu işlemler) onay penceresi ister. Pencere ne olacağını açıkça yazar.
- Transaction davranışı açık olmalı. `CommitRetaining` gibi davranışlar gizli kalmasın. Kullanıcıya açık/kapalı transaction durumu görünsün.
- Proje GitHub'da yayınlanacak (MIT veya Apache lisansı). Kullanılan her harici bileşenin lisansı `LISANSLAR.md` dosyasında listelenecek.
- Derlenmiş `.exe` ve gerekli dosyalarla hazır paket sunulacak.
- README'de "kişisel proje, destek sınırlı" notu yer alacak.

---

## 11. Aşamalı Görev Listesi

Bu bir "boş zamanda yavaş yavaş" projesidir, acele yoktur. **Her aşama bitince sahibinden onay alınmadan sonrakine geçilmez.** Her aşamanın sonunda kısa bir rapor yazılır.

### Aşama 1: İskelet ve Ağaç
- [x] Proje yapısı ve unit'lerin boş iskeletleri
- [x] `uDil.pas` ve `tr.json`, `en.json`, `de.json` (başlangıç anahtarlarıyla)
- [x] Ana form: sol ağaç, sağ sekmeler, alt sonuç alanı, üst araç çubuğu
- [x] Bağlantı penceresi (sunucu, veritabanı yolu, kullanıcı, şifre), kayıtlı bağlantılar JSON'da, şifreler DPAPI ile
- [x] Bağlanınca sürüm algılama
- [x] Ağaçta Tablolar, View'lar, Prosedürler, Generator'lar dallarının doldurulması
- [x] Tabloya çift tıklayınca kolonları ve ilk satırları gösterme
- [x] VCL Style teması ve ikon seti

**Bitiş ölçütü:** Gerçek bir Firebird veritabanına bağlanıp ağacı görebiliyor, bir tabloyu açabiliyorum. Dil değiştirince yazılar anında değişiyor.

### Aşama 1b: Çoklu bağlantı ağacı
- [x] Kayıtlı bağlantılar ağaçta görünür ve aynı anda birden fazla bağlantı açık kalabilir
- [x] Klasörler, sürükle-bırak ve "Kayıttan Kaldır"
- [x] Şifresi kayıtlı olmayan bağlantıda şifre sorma penceresi

**Bitiş ölçütü:** İki veritabanına aynı anda bağlanıp ikisinden de tablo açabiliyorum, klasörler program kapanıp açılınca korunuyor.

### Aşama 2: SQL Editörü
- [x] `uEditor.pas` (SynEdit sarmalayıcı), SQL renklendirme, çoklu sekme
- [x] Sorgu çalıştırma (`F5`), sonuç ızgarası, hata gösterimi (anlaşılır cümle + Ayrıntı)
- [x] `uSonucGrid.pas` altı eklenti
- [x] Parça parça sonuç çekme
- [x] Sorgu planını gösterme
- [x] `Ctrl+Boşluk` otomatik tamamlama (anahtar kelime, veri tipi, nesne adları)
- [x] Çoklu komut çalıştırma: seçili kısım (içinde birden fazla komut varsa sırayla)

### Aşama 3: Yönetim Özellikleri
- [x] `uDDL.pas`: tablo, view, prosedür, trigger için `CREATE` script üretimi (referans: `isql -x` çıktısı)
- [x] Tüm veritabanının metadata çıkarımı (IBExpert "Extract Metadata" gibi: dosyaya veya panoya, hepsi birden, seçenekler: CREATE DATABASE, CONNECT, şifre)
- [x] Veri dışa aktarma (yalnızca CSV; Excel'de açılır, `.xlsx` yazılmaz)
- [x] Yedek/geri yükleme (`gbak` çağırma)
- [ ] Kullanıcı ve yetki yönetimi

### Aşama 4: Çoklu Veritabanı (sahibinin özel ihtiyacı)
- [ ] Bir sorguyu seçilen birçok veritabanında çalıştırma, sonuçları birleştirme
- [ ] Şema farkı bulma (iki veritabanını karşılaştırma)
- [ ] Toplu güncelleme (onay ve önizleme ile)

### Aşama 5: PostgreSQL (küçük kapsam, sahibinin ihtiyacı: pgAdmin'e hızlı alternatif)
Aşama 3 ve 4 bitmeden başlanmaz. Yalnızca bağlan, gez, SQL çalıştır. Script üretme ve yönetim özellikleri bu aşamada yok.

**Bulgu (sahibi ölçtü, 2026-10-13):** Windows Server'da pgAdmin 4 (PostgreSQL 18 ile gelen sürüm) 2 dk 44 sn'de açılıyordu. Neden Windows Defender'ın gerçek zamanlı taramasıydı: pgAdmin'in kurulum klasörü ve `%APPDATA%\pgadmin` klasörü Defender dışlamasına eklenince açılış 30 sn'ye (ikinci açılış 25 sn) düştü. Log önce yalnızca tek uyarı satırı içeriyordu, ilk log satırı açılıştan 77 sn sonra yazılmıştı (Python sunucusu geç ayağa kalkıyordu). Bu aşamanın çıkış nedeni pgAdmin yavaşlığı olduğundan, kendi aracımız da bu ortamda ölçülmeli: açılış süresi Defender dışlamasıyla ve dışlamasız karşılaştırılır, yavaşsa README'ye "program klasörünü Defender dışlamasına ekleyin" notu konur.
- [ ] Hazırlık: sürüme/motora bağlı kodu `uMetadata.pas` içinde motor seçimi arkasına almak (Firebird davranışı değişmeden, mevcut testler geçmeli)
- [ ] FireDAC PostgreSQL sürücüsü ile bağlantı (`libpq.dll` 32/64 bit uyumu ve sürümü belgelenir), şifre DPAPI ile
- [ ] Ağaçta Tablolar, View'lar, Prosedür/Fonksiyonlar, Sequence'lar dalları (`pg_catalog` / `information_schema`)
- [ ] Tabloya çift tıklayınca kolonlar ve ilk satırlar
- [ ] SQL editörü ve sonuç ızgarası PostgreSQL'de çalışır (F5, çoklu komut, hata cümleleri tr/en/de)
- [ ] Sorgu planı (`EXPLAIN`)
- [ ] PostgreSQL anahtar kelime/tip listesi ayrı metin dosyasında

**Bitiş ölçütü:** pgAdmin'in yavaş açıldığı bir sunucuya bağlanıp tabloları görebiliyor, SQL ve script çalıştırabiliyorum.

---

## 12. Ajan İçin Çalışma Kuralları

1. Önce bu belgeyi tamamen oku, sonra Aşama 1'e başla.
2. Belirsiz bir şey varsa tahmin etme, sahibine sor.
3. Listede olmayan bileşen ekleme.
4. Her yeni özellikte üç dil dosyasını da güncelle.
5. Kod sade kalsın: akıllı hileler, karmaşık kalıtım ve zincirleme olaylardan kaçın.
6. Delphi sınıf bildiriminde alanlar prosedürlerden önce gelsin.
7. Dosya silme yok. Gerekirse `_arsiv` klasörüne taşı.
8. Her aşama sonunda: ne yapıldı, ne test edildi, neler eksik kaldı. Kısa ve Türkçe rapor yaz.
9. Tüm cevaplar, açıklamalar ve raporlar **Türkçe** yazılacak.
