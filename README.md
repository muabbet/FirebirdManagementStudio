# Firebird Yöneticisi

Firebird için sade, kolay kullanımlı, SSMS'e benzeyen yönetim aracı. Delphi (RAD Studio 12), VCL, FireDAC. Win64.

> **Kişisel proje, destek sınırlı.** Boş zamanda yavaş yavaş geliştirilir.

Test edilen Firebird sürümleri: 2.5, 3.0, 4.0, 5.0 (Aşama 1'de 2.5.9 ve 5.0.4 hedeflendi).

## Durum

Aşama 1 (iskelet ve ağaç): bağlantı penceresi, kayıtlı bağlantılar (şifreler DPAPI ile şifreli), sürüm algılama, Tablolar / View'lar / Prosedürler / Generator'lar ağacı, tabloya çift tıklayınca kolonlar ve ilk 100 satır, üç dil (tr, en, de). Ayrıntılar `CLAUDE.md` içinde.

## Derleme

RAD Studio 12 gerekir.

- IDE: `Kaynak\FirebirdYonetici.dproj` dosyasını açın, **Win64 / Release** derleyin.
- Komut satırı: `Derle.bat` (rsvars.bat + msbuild).

Çıktı `bin\Win64\Release\` klasörüne gider. Derleme sonrası `SonDerleme.bat` şunları oraya kopyalar: `Diller`, `Ikonlar`, `Stiller\Windows10.vsf`, `anahtar_kelimeler.txt` ve `istemci\` (Firebird 5.0 64 bit `fbclient.dll` ve yan dosyaları). Firebird istemcisinin kaynağı `SonDerleme.bat` başındaki `FBKAYNAK` satırındadır, kendi bilgisayarınıza göre değiştirin.

Tek bir `fbclient.dll` (5.0) yüklenir; 2.5 ve 5.0 sunuculara onunla bağlanılır.

## Güvenlik

- Şifreler diske düz yazılmaz. İstenirse Windows DPAPI ile şifrelenir ve sadece aynı Windows kullanıcısı çözebilir.
- Bağlantı dosyası `%APPDATA%\FirebirdYonetici\baglantilar.json`. `.gitignore` bunu, `*.fdb` ve derleme çıktılarını dışarıda tutar.

## Deneme

`Test\MetadataTest.dpr`: arayüz açmadan bağlantı, metadata ve ilk satırları dener. Şifre ortam değişkeninden (`FBTEST_SIFRE`) okunur, hiçbir dosyaya yazılmaz.

Lisanslar: `LISANSLAR.md`.
