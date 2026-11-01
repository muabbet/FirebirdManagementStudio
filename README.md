# Firebird Management Studio

Firebird için sade, ücretsiz ve açık kaynak yönetim aracı. SSMS'e (SQL Server Management Studio) benzer bir görünüm, ama "kafa karışmasın" ilkesiyle: bir iş için tek yol, kısa menüler, anlaşılır Türkçe / İngilizce / Almanca mesajlar.

*English: a simple, free and open-source management tool for Firebird (2.5 - 5.0), inspired by SSMS. One exe, no installation, Windows 64-bit. The interface is available in Turkish, English and German.*

> **Kişisel proje, destek sınırlı.** Boş zamanda yavaş yavaş geliştirilir. Fikir ve önerileriniz çok değerlidir (GitHub Issues).

## İndirme ve çalıştırma

[Son sürümü indirin](https://github.com/muabbet/FirebirdYonetici/releases/latest), zip dosyasını açın, `FirebirdYonetici.exe` dosyasını çalıştırın. Kurulum yok; Firebird istemcisi, diller ve ikonlar exe'nin içindedir.

- **Windows 10/11, 64 bit gerekir.** 32 bit Windows'ta çalışmaz. Windows 7 denenmedi.
- Bağlanmak için ağda ya da yerelde çalışan bir Firebird sunucusu gerekir (2.5, 3.0, 4.0 veya 5.0).
- Bağlantı penceresindeki **Sunucular** düğmesi ağdaki Firebird sunucularını bulur.

## Neler yapar?

- **Gezme:** Kayıtlı bağlantılar (klasörlere konabilir, aynı anda birden fazlası açık kalabilir). Tablolar, View'lar, Prosedürler, Trigger'lar, Domain'ler, Exception'lar, Generator'lar. Tablolar dalına çift tıklayınca tüm tablolar listesi (ad, alan sayısı, açıklama, başlığa tıklayınca sıralama, alt bölümde alanlar).
- **SQL editörü:** Renklendirme, `F5` ile çalıştırma, çoklu komut, `Ctrl+Boşluk` otomatik tamamlama, sorgu planı. Sonuçlar parça parça yüklenir; ızgarada sıralama, zebra, NULL gösterimi, otomatik genişlik, `Ctrl+C` (Excel'e yapıştırılır), uzun metin ve BLOB kısaltma.
- **Tablo yapısı:** Kolon ekle, adını ve tipini değiştir, sil; index ve kısıt (PK, UNIQUE, FK, CHECK) ekle ve sil; yeni tablo, tablo sil; bağımlılıklar. Her yönetim işleminin SQL'i alt alanda görünür.
- **Nesne yönetimi:** Prosedür, trigger ve view düzenleme; domain, exception ve generator oluşturma, düzenleme, silme. Script üretme (`CREATE`) ve tüm veritabanının metadata çıkarımı.
- **Kullanıcılar ve yetkiler:** Kullanıcı yönetimi; tablo, view ve prosedür yetkilerini görüntüleme, verme ve geri alma.
- **Yedek ve dışa aktarma:** `gbak` ile yedekleme ve geri yükleme; tablo verisini CSV olarak dışa aktarma.
- **Çoklu veritabanı:** Aynı `SELECT`'i birçok veritabanında çalıştırıp sonuçları tek tabloda birleştirme; iki veritabanının şema farkı; birçok veritabanında `UPDATE` (önce önizleme, sonra net bir onay penceresi).
- **Güvenlik ilkeleri:** Tehlikeli işlemler (silme, `WHERE`'siz güncelleme, toplu işlem) net bir onay penceresi ister. Hiçbir şey sessizce silinmez.

## Bilinen sınırlar

- **Kiril alfabesi:** WIN1251 karakter setli veritabanında gerçek Kiril metin bozuk görünebilir (FireDAC, WIN1251'i Windows'un kod sayfasıyla çözüyor). Denerseniz sonucu Issues'a yazmanız çok yardımcı olur. Türkçe karakterler (WIN1254 ve gerçek veritabanlarında denenen biçimler) sorunsuz.
- **Toplu güncelleme önizlemesi** satır verisini geri alır ama tetikleyicilerin dış etkilerini (generator değeri, dış dosya, UDF) geri alamaz.
- Hedeflenen Firebird sürümleri 2.5, 3.0, 4.0 ve 5.0'dır. Gerçek veritabanında 2.5.9 ve 5.0.4 ile, mantık testleriyle 3.0.14 ve 4.0.7 ile de denendi. Ayrıntı: `ASAMA*_RAPOR.md` dosyaları.
- Arayüzün bazı pencereleri yalnızca sahibi tarafından elle denendi; her aşamanın raporunda neyin denenmediği yazılıdır.

## Derleme

RAD Studio 12 (Athens) gerekir. SQL editörü için **SynEdit (TurboPack)** kütüphane yolunda olmalıdır (kaynak: https://github.com/TurboPack/SynEdit, depoda yer almaz). Firebird 5.0 64 bit istemci dosyaları `SonDerleme.bat` başındaki `FBKAYNAK` yolundan alınır; kendi bilgisayarınıza göre değiştirin.

- IDE: `Kaynak\FirebirdYonetici.dproj` dosyasını açın, **Win64 / Release** derleyin.
- Komut satırı: `Derle.bat` (rsvars.bat + msbuild). Önce `PaketHazirla.bat` çalışır: diller, ikonlar, tema ve Firebird istemcisi `Kaynak\Paket.zip` olur ve exe'nin içine gömülür. Çıktı `bin\Win64\Release\FirebirdYonetici.exe`.
- Dağıtım paketi: `Dagit.bat` (derlenmiş exe ile lisans dosyalarını zipler, `dagitim\` klasörüne koyar).

Tek bir `fbclient.dll` (5.0, 64 bit) yüklenir; 2.5, 3.0, 4.0 ve 5.0 sunuculara onunla bağlanılır.

## Güvenlik

- Bağlantı şifreleri diske düz yazılmaz. İstenirse Windows DPAPI ile şifrelenir ve yalnızca aynı Windows kullanıcısı çözebilir.
- Bağlantı dosyası `%APPDATA%\FirebirdYonetici\baglantilar.json`. `.gitignore` bunu, `*.fdb` dosyalarını ve derleme çıktılarını dışarıda tutar.

## Deneme

`Test` klasöründe komut satırı deneme programları vardır (`SorguTest`, `DDLTest`, `CokluSorguTest`, `SemaFarkTest`, `TopluGuncelleTest`, `GorunumTest` vb.). Her biri kendi `...Derle.bat` dosyasıyla derlenir, kendi geçici veritabanını açar, gerçek verilere dokunmaz ve hata sayısını çıkış kodu olarak verir. Kullanıcı için gerekmez.

## Katkı ve geri bildirim

Hata, fikir ve öneri için GitHub Issues kullanın. Proje kişisel olduğundan yanıt süresi garanti edilmez. Kod yazım ilkeleri (basit, sade, formlar ince) `CLAUDE.md` dosyasındadır.

## Lisans

Projenin kendi kodu **MIT** lisansıdır (`LICENSE`). Kullanılan harici bileşenlerin lisansları `LISANSLAR.md` dosyasında listelenir (SynEdit: MPL 1.1, Firebird istemcisi: IDPL, Tabler Icons: MIT).
