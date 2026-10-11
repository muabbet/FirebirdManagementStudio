# Lisanslar

Bu projede kullanılan harici bileşenler ve dosyalar:

| Parça | Ne için | Lisans | Kaynak |
|---|---|---|---|
| **Tabler Icons** 3.49.0 | Araç çubuğu ve nesne ağacı ikonları (`Ikonlar\*.png`, kaynak SVG'ler `Ikonlar\svg\`) | MIT, Telif: 2020-2026 Paweł Kuna. Lisans metni: `Ikonlar\svg\LICENSE_tabler.txt` | https://github.com/tabler/tabler-icons |
| **Firebird istemcisi** (`fbclient.dll` 5.0.4, 64 bit ve yan dosyaları) | Veritabanı bağlantısı | Initial Developer's Public License (IDPL), bkz. derlemede `istemci\IDPLicense.txt` | https://firebirdsql.org |
| **SynEdit** (TurboPack) | SQL editörü (`uEditor.pas`), SQL renklendirme | Mozilla Public License 1.1 (MPL 1.1) ile çift lisans. Yerel kopyadaki kaynak dosya başlıkları: MPL 1.1 **veya** GNU GPL sürüm 2 ya da üstü. GitHub'daki güncel `LICENSE` dosyası: MPL 1.1 **veya** GNU LGPL sürüm 2.1 ya da üstü. Telif: dosya başlıklarına göre Martin Waldenburg (mwEdit, 1998), Maël Hörz (Unicode çevirisi) ve `Contributors.txt` içindeki katkıda bulunanlar. Sürüm: readme'ye göre "10.4 Sydney" (VER340). Kaynak depoya konmaz | https://github.com/TurboPack/SynEdit (derleyen kişi kaynağı kütüphane yoluna ekler) |
| **FireDAC** | Veritabanı erişimi | RAD Studio ile birlikte gelir (Embarcadero) | RAD Studio 12 |
| **VCL Style "Windows10"** (`Windows10.vsf`) | Açık tema | RAD Studio ile birlikte gelir (Embarcadero). Depoda yer almaz, derleme sırasında RAD Studio kurulumundan kopyalanır | RAD Studio 12 |
| **ICU 63.1** (`icudt63.dll`, `icuin63.dll`, `icuuc63.dll`, `icudt63l.dat`) | Firebird istemcisinin karakter seti ve metin işlemleri | Unicode lisansı ("COPYRIGHT AND PERMISSION NOTICE (ICU 58 and later)", Telif: Unicode, Inc. ve katkıda bulunanlar). Telif ve izin notunun kopyalarla birlikte verilmesi şartı vardır. Metin: https://github.com/unicode-org/icu/blob/release-63-1/icu4c/LICENSE | Firebird 5.0 paketi |
| **zlib 1.3.2** (`zlib1.dll`) | Firebird istemcisinin sıkıştırması | zlib License, Telif: 1995-2026 Jean-loup Gailly ve Mark Adler. Metin: https://zlib.net/zlib_license.html | Firebird 5.0 paketi |
| **Microsoft Visual C++ çalışma zamanı** (`vcruntime140*.dll`, `msvcp140*.dll`) | Firebird istemcisinin ihtiyacı | Microsoft lisansı, Firebird paketiyle gelir | Firebird 5.0 paketi |

## Notlar

- Firebird istemci dosyaları ve `.vsf` stil dosyası depoya konmaz (`.gitignore`). `SonDerleme.bat` bunları derleme klasörüne kopyalar.
- ICU ve zlib lisans adları ve telif sahipleri, DLL dosya özellikleri ve yukarıdaki resmi sayfalardan doğrulanmıştır. Bu iki bileşenin lisans **metinleri** Firebird paketinde ayrı dosya olarak gelmediği için hazır pakete henüz konmamıştır. Pakete eklenmesi sahibinin kararına bırakılmıştır.
- `Windows10.vsf` (Embarcadero stili) hazır pakete konulacaksa yeniden dağıtım izninin RAD Studio lisansıyla uyumlu olduğu doğrulanmalıdır. Henüz doğrulanmadı.
- Projenin kendi lisansı (MIT veya Apache) henüz seçilmedi. Karar verilince bu dosyaya ve `LICENSE` dosyasına yazılacak.
- SynEdit: yerel kopyada ayrı bir lisans dosyası yoktur (yalnızca `readme.md`); lisans bilgisi kaynak dosyaların başlıklarındadır ve GitHub'daki `LICENSE` ile **birebir aynı değildir** (başlıklarda ikinci seçenek GPL 2+, GitHub'da LGPL 2.1+). İkisinde de ortak seçenek MPL 1.1'dir; bu proje MPL 1.1 kapsamında kullanır. SynEdit depoya konmaz, kaynak koduyla dağıtılmaz; derleyen kişi GitHub'dan TurboPack/SynEdit'i alıp kütüphane yoluna ekler (RAD Studio 12 GetIt sürümü kurulu olmayabilir). Dosyalar MPL 1.1 altında değiştirilmeden kullanıldığı için kaynak kodu için ek yükümlülük doğmaz. SynEdit derlenmiş `.exe` içine statik girer; MPL 1.1 ikili dağıtımda "kaynağın nereden alınacağını" bildirmeyi ister. Hazır pakete MPL notu (SynEdit adı, MPL 1.1 ve kaynak adresi) konması gerekir veya tavsiye edilir. Karar sahibinde.
