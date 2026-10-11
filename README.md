# Firebird Yöneticisi

Firebird için sade, kolay kullanımlı, SSMS'e benzeyen yönetim aracı. Delphi (RAD Studio 12), VCL, FireDAC. Win64.

> **Kişisel proje, destek sınırlı.** Boş zamanda yavaş yavaş geliştirilir.

Hedeflenen Firebird sürümleri: 2.5, 3.0, 4.0, 5.0. Denenen: 2.5.9 ve 5.0.4 (3.0 ve 4.0 henüz denenmedi).

## Durum

Aşama 1 (iskelet ve ağaç): bağlantı penceresi, kayıtlı bağlantılar (şifreler DPAPI ile şifreli), sürüm algılama, Tablolar / View'lar / Prosedürler / Generator'lar ağacı, tabloya çift tıklayınca kolonlar ve ilk 100 satır, üç dil (tr, en, de). Ayrıntılar `CLAUDE.md` içinde.

Aşama 1b (çoklu bağlantı ağacı): kayıtlı bağlantılar ağaçta görünür, aynı anda birden fazla bağlantı açık kalabilir, bağlantılar klasörlere konabilir (sürükle-bırak) ve "Kayıttan Kaldır" ile listeden çıkarılır (veritabanına dokunulmaz). Şifresi kayıtlı olmayan bağlantıda şifre sorulur (şifre kaydedilmez). `baglantilar.json` içinde her bağlantının `Klasor` alanı ve boş klasörler için `Klasorler` listesi tutulur; eski biçimdeki dosya okunmaya devam eder.

Aşama 2 (SQL editörü): sorgu sekmeleri (SynEdit, SQL renklendirme), `F5` ile çalıştırma, sonuç 500'er satır parça parça yüklenir, sonuç ızgarasında sıralama / zebra / NULL gösterimi / otomatik genişlik / Ctrl+C / uzun metin ve BLOB kısaltma. Her sorgu sekmesi kendi işleminde ve otomatik onay (autocommit) modunda çalışır. DROP ve WHERE'siz DELETE/UPDATE onay ister. `Ctrl+L` ile sorgu planı (komut çalıştırılmaz). `Ctrl+Boşluk` ile otomatik tamamlama (anahtar kelimeler `anahtar_kelimeler.txt` dosyasından, nesne adları, `ad.` yazınca kolon adları; `ad` takma ad da olabilir). Editörde birden fazla komut varsa (veya seçili kısımda) hepsi sırayla çalışır, `SET TERM` desteklenir, ilk hatada durulur; her komut ayrı otomatik onaylandığı için önceki komutlar geri alınmaz.

## Derleme

RAD Studio 12 gerekir. SQL editörü için **SynEdit** (TurboPack, `TSynCompletionProposal` dahil) kütüphane yolunda olmalıdır; GetIt veya https://github.com/TurboPack/SynEdit kaynağı (kaynak depoda yoktur).

- IDE: `Kaynak\FirebirdYonetici.dproj` dosyasını açın, **Win64 / Release** derleyin.
- Komut satırı: `Derle.bat` (rsvars.bat + msbuild).

Çıktı `bin\Win64\Release\` klasörüne gider. Derleme sonrası `SonDerleme.bat` şunları oraya kopyalar: `Diller`, `Ikonlar`, `Stiller\Windows10.vsf`, `anahtar_kelimeler.txt` ve `istemci\` (Firebird 5.0 64 bit `fbclient.dll` ve yan dosyaları). Firebird istemcisinin kaynağı `SonDerleme.bat` başındaki `FBKAYNAK` satırındadır, kendi bilgisayarınıza göre değiştirin.

Tek bir `fbclient.dll` (5.0) yüklenir; 2.5 ve 5.0 sunuculara onunla bağlanılır.

## Güvenlik

- Şifreler diske düz yazılmaz. İstenirse Windows DPAPI ile şifrelenir ve sadece aynı Windows kullanıcısı çözebilir.
- Bağlantı dosyası `%APPDATA%\FirebirdYonetici\baglantilar.json`. `.gitignore` bunu, `*.fdb` ve derleme çıktılarını dışarıda tutar.

## Deneme

`Test\MetadataTest.dpr`: arayüz açmadan bağlantı, metadata ve ilk satırları dener. Şifre ortam değişkeninden (`FBTEST_SIFRE`) okunur, hiçbir dosyaya yazılmaz. `FBTEST_YOL2` verilirse ikinci bir veritabanına da bağlanıp iki bağlantının aynı anda açık kalabildiğini dener.

`Test\BaglantiDosyasiTest.dpr`: kayıtlı bağlantı dosyasının güvenliğini (bozuk dosyanın silinmeden yanına taşınması, atomik yazma, DPAPI şifre gidiş-dönüş, eski biçim okuma, klasör gidiş-dönüşü) geçici bir klasörde dener, gerçek verilere dokunmaz. Bu iki deneme programı için `.dproj` yoktur; `dcc64` ile derlenir (örnek: `dcc64 Test\BaglantiDosyasiTest.dpr -UKaynak`).

Lisanslar: `LISANSLAR.md`.
