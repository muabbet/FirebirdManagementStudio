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

- **Sol panel:** Kayıtlı bağlantılar (klasörlere konabilir, aynı anda birden fazlası açık olabilir). Bağlı bir bağlantının altında beş dal: Tablolar, View'lar, Prosedürler, Trigger'lar, Generator'lar.
- **Sağ üst:** Sekmeli çalışma alanı. Her açılan şey (sorgu, tablo verisi, tablo yapısı) kendi sekmesinde açılır.
- **Sağ alt:** Sonuç alanı. Sorgu sonucu veya hata mesajı burada görünür.
- **Üstte (karar 2026-10-18):** Kendi çizdiğimiz, üçüncü parti bileşensiz **sekmeli şerit (ribbon)**: üstte sekmeler (Bağlantı, Sorgu, Yönetim), tıklanan sekmenin düğmeleri görünür; büyük ikon üstte, yazı altta. Açılır menü ve iç içe menü yok, bir iş için tek düğme. Yeni özellik düğmesi uygun sekmeye konur. Kod: `uSerit.pas`, ayrıntı: `GOREV_ASAMA3R.md`.
- **Sağ tık menüsü:** Bir nesnede en fazla 5-6 seçenek ("İlk 100 satırı göster", "Yapıyı göster", "Script üret" gibi).
- **İlk sürümde ayar penceresi yok.** Makul varsayılanlar kullanılır, ayarlar sonra eklenir (dil seçimi hariç).
- **Görsel:** Açık ve temiz VCL Style teması, nesne ağacında tutarlı küçük ikon seti (tablo, view, prosedür vb. için ayrı), cömert boşluklar ve okunaklı yazı boyutu.

- **SQL karşılığı (karar 2026-10-27):** Programın veritabanında yaptığı her yönetim işleminin (kullanıcı, trigger/prosedür kaydetme vb.) çalıştırdığı SQL, işlem bitince alt mesaj alanında gösterilir (hata olunca da denenen SQL). Şifreler her zaman `***`. Amaç öğrenme: kullanıcı işin SQL'ini görür. Ortak yordam `fAna.pas` içindeki `SqlMesajiYaz`.

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
- [x] Kullanıcı ve yetki yönetimi: 3d-1 kullanıcılar, 3d-2 yetki görüntüleme ve 3d-3 yetki verme/geri alma tamam (`ASAMA3D2_RAPOR.md`, onaylandı 2026-10-31). Rol yönetimi ve kolon düzeyi yetki bilerek yok (basitlik)
- [x] Trigger ve saklı prosedür düzenleme ve kaydetme (sahibinin isteği 2026-10-27): 3e-1 prosedür ve 3e-2 trigger tamam, sahibi denedi ve onayladı
- [x] 3f: View düzenleme; Domain, Exception ve Generator yönetimi (ağaç dalları, oluştur, düzenle, sil; ayrıntı: `GOREV_ASAMA3F.md`), sahibi denedi ve onayladı (2026-10-29). Görsel düzeltme (SSMS örneği `Referans/ssms.png`, StokluBulut ikonu) tamam ve onaylandı (2026-10-30, `GORSEL_RAPOR.md`). 3g tablo yapısı (kolon, index, kısıt, yeni tablo, tablo sil, bağımlılıklar; `GOREV_ASAMA3G.md`, `ASAMA3G_RAPOR.md`) tamam ve onaylandı (2026-10-30). Sıradaki: Aşama 4 (çoklu veritabanı)

### Aşama 4: Çoklu Veritabanı (sahibinin özel ihtiyacı)
- [x] Bir sorguyu seçilen birçok veritabanında çalıştırma, sonuçları birleştirme (4a, `ASAMA4A_RAPOR.md`, sahibi denedi ve onayladı 2026-11-01)
- [x] Şema farkı bulma (iki veritabanını karşılaştırma) (4b, `ASAMA4B_RAPOR.md`, onaylandı 2026-11-01)
- [x] Toplu güncelleme (onay ve önizleme ile) (4c, `ASAMA4C_RAPOR.md`, sahibi denedi ve onayladı, main'e birleştirildi 2026-11-01)

### Aşama 4d: Gridden Kayıt Düzeltme (fikir 2026-10-31, Aşama 4'ten sonra)
Tablo verisi gridinde (şu an salt okunur) bir hücreyi çift tıklayıp düzeltme, ayrı ve açık bir "Düzenle" kipiyle. Basitlik ve güvenlik için:
- [ ] Yalnızca birincil anahtarı olan tablolarda; "Düzenle" düğmesine basınca açılır, varsayılan salt okunur kalır
- [ ] Kaydetmeden önce onay penceresi: hangi tablo, hangi kayıt, eski ve yeni değer, çalışacak `UPDATE` (SQL karşılığı alt alanda, bkz. `SqlMesajiYaz`)
- [ ] Transaction açık/kapalı durumu görünür, "Kaydet" ve "Geri al" düğmeleri
- [ ] Karakter seti: WIN1251 veritabanında Türkçe harf yazma önce kopyada test edilir (bilinen sınır, `ASAMA4A_RAPOR.md`)
- [ ] 3 dil anahtarı, test

### Hakkında ve Fikir/Öneri (karar 2026-11-01)
- [x] Hakkında penceresi: yönetici rozetine tıklayınca açılır (ad, sürüm, platform, yetki, lisans, "Sürümü kopyala"); yönetici değilse rozet "Yönetici olarak aç" olur ve sorup yeniden başlatır. Kod: `uYonetici.pas`, `fHakkinda.pas`
- [ ] **İleride:** "Fikir ve öneri" düğmesi (sahibi için fikirler çok önemli). GitHub yayınlanınca Issues sayfasını açar; o zamana kadar yapılmaz

### Görünüm düzenlemeleri (sahibinin isteği 2026-11-01, 4c denemesinden sonra)
- [x] Fare bir bağlantının üstüne gelince veritabanı yolu ipucu; durum çubuğunda seçili bağlantının yolu
- [x] Sekme sağ tık menüsü: Yenile (veriyi yeniden yükler), Sekmeyi kapat, Tüm sekmeleri kapat (onaylı); sağ tıklanan sekme seçilir
- [x] "Tablolar" dalına çift tıklayınca tablo listesi sekmesi (IBExpert gibi): ad, alan sayısı, açıklama; başlığa tıklayınca sıralar; listede tabloya tıklayınca altta alanları; çift tıklayınca tablo kendi sekmesinde açılır. Kod: `fTabloListe.pas`
- [x] Şeritte **Görünüm** sekmesi: Ayrıntıyı göster/kapat (alan bölümü), Tüm pencereleri kapat
- [x] Alan listesinde **Sıra** kolonu (veritabanındaki eklenme sırası); başlığa tıklayınca sıralanır, Sıra başlığı ilk sıraya döndürür
- [x] Görev çubuğunda eski ikon: Windows ikon önbelleği; çözüm: programa yeni uygulama kimliği (`uUygulama.pas`, `UygulamaKimliginiAyarla`). Sahibi doğruladı: düzeldi (2026-11-01)

### Yayın hazırlığı (2026-11-01)
- [x] Lisans: MIT (`LICENSE`, Telif: Barış Başpınar); `LISANSLAR.md` güncellendi
- [x] `README.md` yeniden yazıldı (indirme, özellikler, bilinen sınırlar, derleme, lisans)
- [x] `Dagit.bat`: exe + lisans dosyaları tek zip (`dagitim\FirebirdManagementStudio-SURUM-win64.zip`); zipten çıkan exe yalnız başına açılıp çalıştı (denendi)
- [x] Tanıtım sayfasında GitHub ve indirme bağlantıları (`github.com/muabbet/FirebirdYonetici`), lisans satırı
- [ ] GitHub'a gönderme, GitHub Pages ayarı (docs klasörü), Releases'e zip yükleme ve ekran görüntüsü (`docs/ekran.png`, sahte verili veritabanıyla): sahibinin kararı ve işi

### Aşama 5: PostgreSQL — İPTAL EDİLDİ (karar 2026-10-31)

Sahibi PostgreSQL desteğini **yapmama** kararı verdi: araç yalnızca Firebird'e özel kalacak. Gerekçe: pgAdmin iyi bir alternatif, iki veritabanını aynı araçta karıştırmak kafa karışıklığı yaratır; pgAdmin'in yavaş açılma sorunu Windows Defender dışlaması ile çözüldü (üretimde hızlı açılıyor). **Ana ilke:** basit ama Firebird için her şeyi yapabilen bir program. Motor seçimi, PostgreSQL sürücüsü, `libpq.dll` gibi hiçbir şey eklenmeyecek; `uMetadata.pas` Firebird'e özel kalır.

Eski plan (yapılmayacak, kayıt için): bağlan, gez, SQL çalıştır; `pg_catalog` / `information_schema`; `EXPLAIN`; PostgreSQL anahtar kelime listesi.

### Aşama 6: Tanıtım ve İndirme Sayfası (fikir 2026-10-31, Aşama 4 bitince)
Tek sayfalık, sade, hızlı yüklenen statik HTML sayfası; GitHub Pages ile ücretsiz yayınlanır, exe GitHub Releases'ten indirilir. Yayın (GitHub'a gönderme) sahibinin kararıdır.
- [x] Tek HTML dosyası (`docs/index.html`, taslak hazır 2026-11-01; İndir ve GitHub bağlantıları ile `docs/ekran.png` yayında doldurulacak): başlık, büyük "İndir" düğmesi (Windows 64 bit, sürüm, boyut), ekran görüntüsü
- [ ] "Windows 64 bit gerekir" uyarısı indirme düğmesinin hemen yanında (program yalnızca 64 bit; 32 bit Windows'ta açılmaz)
- [ ] 5-6 kısa madde: tek exe, Firebird 2.5/3.0/4.0/5.0, tr/en/de, sunucu bulma, ücretsiz ve açık kaynak
- [ ] Sayfada dil seçimi (tr/en/de), mobilde düzgün görünüm, animasyon yok
- [ ] Bilinen sınır notu: Kiril alfabesi (WIN1251'de gerçek Kiril metin) sorunlu olabilir, FireDAC bozuk çözüyor; test eden olursa GitHub'dan yazsın (ayrıntı: `ASAMA4A_RAPOR.md`)
- [ ] GitHub bağlantısı, lisans, "kişisel proje, destek sınırlı" notu

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
