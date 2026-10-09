# Lisanslar

Bu projede kullanılan harici bileşenler ve dosyalar:

| Parça | Ne için | Lisans | Kaynak |
|---|---|---|---|
| **Tabler Icons** 3.49.0 | Araç çubuğu ve nesne ağacı ikonları (`Ikonlar\*.png`, kaynak SVG'ler `Ikonlar\svg\`) | MIT, Telif: 2020-2026 Paweł Kuna. Lisans metni: `Ikonlar\svg\LICENSE_tabler.txt` | https://github.com/tabler/tabler-icons |
| **Firebird istemcisi** (`fbclient.dll` 5.0.4, 64 bit ve yan dosyaları) | Veritabanı bağlantısı | Initial Developer's Public License (IDPL), bkz. derlemede `istemci\IDPLicense.txt` | https://firebirdsql.org |
| **FireDAC** | Veritabanı erişimi | RAD Studio ile birlikte gelir (Embarcadero) | RAD Studio 12 |
| **VCL Style "Windows10"** (`Windows10.vsf`) | Açık tema | RAD Studio ile birlikte gelir (Embarcadero). Depoda yer almaz, derleme sırasında RAD Studio kurulumundan kopyalanır | RAD Studio 12 |
| **Microsoft Visual C++ çalışma zamanı** (`vcruntime140*.dll`, `msvcp140*.dll`) | Firebird istemcisinin ihtiyacı | Microsoft lisansı, Firebird paketiyle gelir | Firebird 5.0 paketi |

## Notlar

- Firebird istemci dosyaları ve `.vsf` stil dosyası depoya konmaz (`.gitignore`). `SonDerleme.bat` bunları derleme klasörüne kopyalar.
- Projenin kendi lisansı (MIT veya Apache) henüz seçilmedi. Karar verilince bu dosyaya ve `LICENSE` dosyasına yazılacak.
- Aşama 2'de SynEdit (MPL/MIT benzeri açık kaynak) eklenirse buraya yazılacak.
