# Firebird Management Studio

Firebird için sade, ücretsiz ve açık kaynak yönetim aracı. SSMS'e (SQL Server Management Studio) benzer bir görünüm, ama "kafa karışmasın" ilkesiyle: bir iş için tek yol, kısa menüler, anlaşılır Türkçe / İngilizce / Almanca mesajlar.

*English: a simple, free and open-source management tool for Firebird (2.5 - 5.0), inspired by SSMS. One exe, no installation, Windows 64-bit. The interface is available in Turkish, English and German.*

> **Kişisel proje, destek sınırlı.** Boş zamanda yavaş yavaş geliştirilir. Fikir ve önerileriniz çok değerlidir (GitHub Issues).

## İndirme ve çalıştırma

[Son sürümü indirin](https://github.com/muabbet/FirebirdManagementStudio/releases/latest), zip dosyasını açın, `FirebirdManagementStudio.exe` dosyasını çalıştırın. Kurulum yok; Firebird istemcisi, diller ve ikonlar exe'nin içindedir.

- **Windows 10/11, 64 bit gerekir.** 32 bit Windows'ta çalışmaz. Windows 7 denenmedi.
- Bağlanmak için ağda ya da yerelde çalışan bir Firebird sunucusu gerekir (2.5, 3.0, 4.0 veya 5.0).
- Bağlantı penceresindeki **Sunucular** düğmesi ağdaki Firebird sunucularını bulur.

## Neler yapar?

- **Gezme:** Kayıtlı bağlantılar (klasörlere konabilir, aynı anda birden fazlası açık kalabilir). Tablolar, View'lar, Prosedürler, Trigger'lar, Domain'ler, Exception'lar, Generator'lar. Tablolar dalına çift tıklayınca tüm tablolar listesi (ad, alan sayısı, açıklama, başlığa tıklayınca sıralama, alt bölümde alanlar).
- **SQL editörü:** Renklendirme, `F5` ile çalıştırma, çoklu komut, `Ctrl+Boşluk` otomatik tamamlama, sorgu planı. **SQL geçmişi ve sık kullanılan sorgular:** çalıştırdığınız sorgular birikir (**Geçmiş** düğmesi), adlandırıp sık kullanılanlara ekleyebilirsiniz; seçtiğiniz sorgu editörün sonuna eklenir, kendiliğinden çalışmaz. Şifre içeren komutlar kaydedilmez, "Geçmişi temizle" kayıtları silmez, tarihli bir yan dosyaya taşır. Sonuçlar parça parça yüklenir; ızgarada sıralama, zebra, NULL gösterimi, otomatik genişlik, `Ctrl+C` (Excel'e yapıştırılır), uzun metin ve BLOB kısaltma.
- **Tablo yapısı:** Kolon ekle, adını ve tipini değiştir, sil; index ve kısıt (PK, UNIQUE, FK, CHECK) ekle ve sil; yeni tablo (SQL ile ya da **gridde kolonları tasarlayarak**, canlı SQL önizlemesiyle), tablo sil; bağımlılıklar. Her yönetim işleminin SQL'i alt alanda görünür.
- **Tablo verisi:** Tablo sekmesi önce ilk 100 satırı gösterir, aşağı indikçe 100'er satır daha yüklenir. Kolon başlığına tıklayınca satırlar **sunucuda** sıralanır (tablonun tamamı sıralanır, yalnız ekrandaki satırlar değil). **Düzenle** kipiyle hücre düzeltme, yeni kayıt ekleme ve kayıt silme (değişiklikler önce bellekte bekler; **Kaydet**'te net onayla tek işlemde çalışır, hata olursa hiçbiri uygulanmaz); **CSV'den içe aktarma** (ayraç ve kodlama tahmini, önizleme, kolon eşleme, tek işlem); tüm kayıtları silme (tablo adını yazdırarak); tabloyu **başka bir veritabanına kopyalama** (yapı ve veri).
- **Tablo filtresi:** Kolon başlıklarının altındaki **filtre satırı**: kutuya yazıp Enter'a basın (`ali` içerir, `ali*` ile başlar, `>10`, `<>5`, `10..20` arası, `2026-11-09` tarih, `-` boş, `!-` boş değil); yazarken kolonun mevcut değerlerinden en çok 10 tanesi **öneri listesi** olarak çıkar, seçince filtre uygulanır. Hücreye sağ tıkla da filtrelenir, istenirse üstteki kutuya `WHERE` koşulu yazılır. Filtre sunucuda çalışır; çalışan SQL alt alanda görünür; **Dışa aktar** filtreyi ve sıralamayı uygular.
- **İlişkili kayıtlar ve kolon özeti:** Tablo gridinde yabancı anahtar hücresine sağ tıklayıp **Bağlı kayda git** ile ana kaydı filtreli yeni sekmede açın; **Bu kaydı kullananlar** ile hangi tabloda kaç kaydın bu kaydı kullandığını görüp birini açın (birleşik anahtarlar dahil). Kolon başlığına sağ tıklayıp **Kolon özeti** ile filtreye uyan satırlarda sayı, dolu/boş, en küçük/en büyük, sayı kolonunda toplam ve ortalamayı görün; hesap sunucuda yapılır, yalnız ekrandaki satırlara bakılmaz.
- **Kolon işlemleri:** Kolonlar sekmesinde seçili kolon için **Birincil anahtar yap** (kolon boş olabiliyorsa Firebird 3.0 ve üstünde önce NOT NULL, sonra PRIMARY KEY; komutlar onay penceresinde yazılı) ve **Otomatik artan yap** (generator ve BEFORE INSERT trigger'ı, her Firebird sürümünde; numara kolondaki en büyük değerden devam eder). Firebird 2.5'te kolonun NOT NULL durumu sonradan değiştirilemediği için boş olabilen kolona birincil anahtar eklenemez; program nedenini ve çözümü yazar.
- **Script üretme:** Tabloya sağ tık > **Script üret** > CREATE, SELECT, INSERT, UPDATE, DELETE. Komutlar yeni sorgu sekmesinde açılır, çalıştırılmaz; UPDATE ve DELETE'in `WHERE`'i birincil anahtardan kurulur ve doldurulmadan hiçbir kayda dokunmaz.
- **Sorgu sonucu filtresi:** Tek bir `SELECT`'in sonucunda da kolon başlıklarının altında filtre satırı çıkar (sunucuda süzer; `Dışa aktar` süzülmüş sonucu aktarır).
- **Bağlantı ağacı:** Klasör içinde klasör (sürükle-bırak, "Alt klasör ekle") ve şeritte **Tüm bağlantıları kes**.
- **Arama:** Şeritte **Yönetim > Ara**: tablo, view, prosedür, trigger ve exception adlarında ve kolon adlarında arar; istenirse view, prosedür ve trigger kaynak metinlerinin içinde de arar (eşleşen satır görünür). Sonuca çift tıklayınca nesne açılır.
- **Veritabanı:** Yeni veritabanı oluşturma (karakter seti seçilir, var olan dosya ezilmez); sorguda `CREATE`/`ALTER`/`DROP` sonrası ağacın kendiliğinden yenilenmesi; **aktif bağlantılar** (kim bağlı, ne çalışıyor, en eski işlem; onaylı bağlantı koparma).
- **Nesne yönetimi:** Prosedür, trigger ve view düzenleme; domain, exception ve generator oluşturma, düzenleme, silme. Script üretme (`CREATE`) ve tüm veritabanının metadata çıkarımı.
- **Kullanıcılar ve yetkiler:** Kullanıcı yönetimi; tablo, view ve prosedür yetkilerini görüntüleme, verme ve geri alma.
- **Bakım:** Veritabanı bakımı: önce ayrıntılı rapor (tablo ve index durumu, temizlenecek kayıtlar, yeniden kurulacak index'ler, bozuk kayıt taraması, işlem sayaçları), onaydan sonra sweep, index yeniden kurma ve istatistik yenileme; bakım sonrası "önce → sonra" farkı. **Yeniden yarat** (yedekle ve yeni dosyaya geri yükle) ile dosya küçülür. İlerleme çubuğu, geçen süre ve iptal vardır. SYSDBA ya da yetkili kullanıcı gerekir.
- **Index önerisi:** Sorgu sekmesinde **Index öner**: sorgunun planında index'siz taranan büyük tablolar için hangi kolonlara index konabileceğini söyler (önce sabit değerli koşullar, sonra JOIN kolonları), onayınızla oluşturur ve planı önce / sonra gösterir.
- **Yedek ve kopyalama:** `gbak` ile yedekleme ve geri yükleme (2.5, 3.0, 4.0 ve 5.0 sunucularında; ilerleme çubuğu ve dosya boyutuyla); bağlantıya sağ tık > **Veritabanını kopyala** (yedekle ve yeni dosyaya geri yükle; var olan dosya ezilmez) ve **Klonla** (bağlantıyı çoğalt); tablo verisini CSV olarak dışa aktarma.
- **Çoklu veritabanı:** Aynı `SELECT`'i birçok veritabanında çalıştırıp sonuçları tek tabloda birleştirme; iki veritabanının şema farkı; birçok veritabanında `UPDATE` (önce önizleme, sonra net bir onay penceresi).
- **Güvenlik ilkeleri:** Tehlikeli işlemler (silme, `WHERE`'siz güncelleme, toplu işlem) net bir onay penceresi ister. Hiçbir şey sessizce silinmez.

## Bilinen sınırlar

- **Kiril alfabesi:** WIN1251 karakter setli veritabanında gerçek Kiril metin bozuk görünebilir (FireDAC, WIN1251'i Windows'un kod sayfasıyla çözüyor). Denerseniz sonucu Issues'a yazmanız çok yardımcı olur. Türkçe karakterler (WIN1254 ve gerçek veritabanlarında denenen biçimler) sorunsuz.
- **Toplu güncelleme önizlemesi** satır verisini geri alır ama tetikleyicilerin dış etkilerini (generator değeri, dış dosya, UDF) geri alamaz.
- **Tablo kopyalama** yabancı anahtarları, tetikleyicileri, yetkileri ve generator değerlerini kopyalamaz (pencerede yazar). Tablo tasarımında yabancı anahtar ve index yoktur, tablo oluştuktan sonra tablo sekmesinden eklenir.
- **Düzenleme kipi** yalnızca birincil anahtarı olan tablolarda açılır. Boş metin hücresi boş yazı (`''`) olarak kalır, NULL yapmanın ayrı yolu yoktur; CSV içe aktarmada boş hücre NULL olur.
- Hedeflenen Firebird sürümleri 2.5, 3.0, 4.0 ve 5.0'dır. Gerçek veritabanında 2.5.9 ve 5.0.4 ile denendi; önceki sürümlerdeki özellikler mantık testleriyle 3.0.14 ve 4.0.7 ile de denendi. **0.9 sürümündeki birincil anahtar / otomatik artan yapma, script üretme ve sorgu sonucu filtresi 3.0.14 ve 4.0.7'de geçici veritabanıyla testle denendi; filtre satırı 2.5.9'da elle de denendi. 0.8 sürümündeki ilişkili kayıtlar, kolon özeti ve arama özellikleri 3.0.14 ve 4.0.7'de geçici veritabanıyla testle denendi. 0.6 sürümündeki bakım, veritabanı kopyalama ve yedek 2.5.9, 3.0.14, 4.0.7 ve 5.0.4'te denendi. 0.5 sürümündeki özellikler (veri düzenleme, içe aktarma, tablo kopyalama, tasarım, aktif bağlantılar) yalnızca 2.5.9 ve 5.0.4'te denendi; 3.0 ve 4.0'da henüz denenmedi.**
- Arayüzün bazı pencereleri yalnızca sahibi tarafından elle denendi; her aşamanın raporunda neyin denenmediği yazılıdır.

## Yeni dil ekleme

Program Türkçe, İngilizce ve Almanca gelir; bu üç dil her sürümde eksiksiz tutulur. Başka bir dili herkes ekleyebilir, kod derlemek gerekmez:

1. `%LOCALAPPDATA%\FirebirdYonetici\paket\Diller` klasörünü açın (program bir kez çalışmış olmalı).
2. `en.json` dosyasını kopyalayıp adını dil koduna çevirin (örneğin `ru.json`, `pt-BR.json`).
3. Dosyadaki `DIL_ADI` değerini dilin kendi adıyla yazın (örneğin `Русский`), diğer değerleri çevirin.
4. Programı yeniden açın; dil seçim listesinde görünür.

Çevirmediğiniz anahtarlar İngilizce görünür, program bozulmaz. Yeni sürümlerde eklenen anahtarlar topluluk dillerinde İngilizce kalabilir. Çevirinizi GitHub Issues üzerinden gönderirseniz sürüme ekleyebiliriz.

## Derleme

RAD Studio 12 (Athens) gerekir. SQL editörü için **SynEdit (TurboPack)** kütüphane yolunda olmalıdır (kaynak: https://github.com/TurboPack/SynEdit, depoda yer almaz). Firebird 5.0 64 bit istemci dosyaları `SonDerleme.bat` başındaki `FBKAYNAK` yolundan alınır; kendi bilgisayarınıza göre değiştirin.

- IDE: `Kaynak\FirebirdManagementStudio.dproj` dosyasını açın, **Win64 / Release** derleyin.
- Komut satırı: `Derle.bat` (rsvars.bat + msbuild). Önce `PaketHazirla.bat` çalışır: diller, ikonlar, tema ve Firebird istemcisi `Kaynak\Paket.zip` olur ve exe'nin içine gömülür. Çıktı `bin\Win64\Release\FirebirdManagementStudio.exe`.
- Dağıtım paketi: `Dagit.bat` (derlenmiş exe ile lisans dosyalarını zipler, `dagitim\` klasörüne koyar).

Tek bir `fbclient.dll` (5.0, 64 bit) yüklenir; 2.5, 3.0, 4.0 ve 5.0 sunuculara onunla bağlanılır.

## Güvenlik

- Bağlantı şifreleri diske düz yazılmaz. İstenirse Windows DPAPI ile şifrelenir ve yalnızca aynı Windows kullanıcısı çözebilir.
- Bağlantı dosyası `%APPDATA%\FirebirdYonetici\baglantilar.json`. `.gitignore` bunu, `*.fdb` dosyalarını ve derleme çıktılarını dışarıda tutar.

## Deneme

`Test` klasöründe komut satırı deneme programları vardır (`SorguTest`, `DDLTest`, `CokluSorguTest`, `SemaFarkTest`, `TopluGuncelleTest`, `GorunumTest` vb.). Her biri kendi `...Derle.bat` dosyasıyla derlenir, kendi geçici veritabanını açar, gerçek verilere dokunmaz ve hata sayısını çıkış kodu olarak verir. Kullanıcı için gerekmez.

## Katkı ve geri bildirim

Hata, fikir ve öneri için GitHub Issues kullanın: [Fikir ve öneri yaz](https://github.com/muabbet/FirebirdManagementStudio/issues/new/choose) (hazır şablonlar var). Programda **Hakkında** penceresindeki **Fikir ve öneri** düğmesi de aynı sayfayı açar. Proje kişisel olduğundan yanıt süresi garanti edilmez. Kod yazım ilkeleri (basit, sade, formlar ince) `CLAUDE.md` dosyasındadır.

## Lisans

Projenin kendi kodu **MIT** lisansıdır (`LICENSE`). Kullanılan harici bileşenlerin lisansları `LISANSLAR.md` dosyasında listelenir (SynEdit: MPL 1.1, Firebird istemcisi: IDPL, Tabler Icons: MIT).
