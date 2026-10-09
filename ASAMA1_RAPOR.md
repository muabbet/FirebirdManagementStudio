# Aşama 1 Raporu: İskelet ve Ağaç

Tarih: 2026-10-09. Hedef: Win64, RAD Studio 12 (Delphi 12), VCL + FireDAC.

## 1. Ne yapıldı

- Ana form: sol nesne ağacı, sağ üstte sekmeli çalışma alanı, sağ altta sonuç alanı, üstte tek araç çubuğu (Bağlan, Bağlantıyı Kes, Yenile) ve dil seçici, altta durum çubuğu.
- Bağlantı penceresi: sunucu, port, veritabanı yolu, kullanıcı, şifre, karakter seti. Kayıtlı bağlantılar listesi. Başarılı bağlantı otomatik kaydedilir. "Listeden Kaldır" onay ister ve veritabanına dokunmaz.
- Kayıtlı bağlantılar JSON'da (`%APPDATA%\FirebirdYonetici\baglantilar.json`). Şifre isteğe bağlı olarak Windows DPAPI ile şifrelenip saklanır, düz metin yazılmaz. Varsayılan: şifre saklanmaz.
- Varsayılanlar: Dialect 3, karakter seti WIN1254, `Pooled=False`, sunucu `localhost`, port 3050, kullanıcı SYSDBA.
- Bağlanınca sürüm algılama: `RDB$GET_CONTEXT('SYSTEM','ENGINE_VERSION')`. Sürüm durum çubuğunda görünür.
- Ağaç: Tablolar, View'lar, Prosedürler, Generator'lar dalları ve sayıları (sistem nesneleri hariç).
- Tabloya çift tıklayınca (veya sağ tık "Aç") yeni sekmede kolonlar (ad, veri tipi, boş olabilir) ve ilk 100 satır. Veri salt okunurdur.
- Çok dillilik (tr, en, de): `T('ANAHTAR')`, dil program yeniden başlamadan anında değişir. Son seçilen dil `%APPDATA%\FirebirdYonetici\ayar.json` içinde hatırlanır.
- Anlaşılır hata cümleleri (yanlış şifre, sunucuya ulaşılamadı, dosya bulunamadı, kilit, bağlantı koptu, istemci dosyası yok). Ham mesaj "Ayrıntı" altında durur.
- Transaction durumu durum çubuğunda görünür ("İşlem: kapalı"). Aşama 1 salt okunur, her sorgu kendi işlemini açıp kapatır.
- VCL stili "Windows10" (açık tema), ikon seti Tabler Icons.

## 2. Unit'ler (`Kaynak\`)

| Unit | Görevi |
|---|---|
| `uDil.pas` | JSON dil dosyaları, `T()` / `TF()`, yedekleme sırası (seçili dil, İngilizce, anahtarın kendisi), son dilin hatırlanması |
| `uBaglanti.pas` | Bağlantı tanımı, kayıtlı bağlantılar (JSON), DPAPI, FireDAC bağlantısı, sürüm algılama, hata cümleleri. Yeni bağlantı kurulamazsa eskisi bozulmaz. |
| `uMetadata.pas` | Tablo, view, prosedür, generator listeleri (`TFDMetaInfoQuery`), tablonun kolon bilgisi |
| `uSorgu.pas` | Tablonun ilk satırlarını salt okunur sorgu olarak getirir |
| `uIkon.pas` | PNG ikonları `TImageCollection` / `TVirtualImageList` içine yükler *(belgede yoktu, eklendi)* |
| `uOnay.pas` | Evet/Hayır onay penceresi, düğme yazıları seçili dilden *(belgede yoktu, eklendi)* |
| `uSonucGrid.pas`, `uEditor.pas`, `uDDL.pas` | Boş iskelet (Aşama 2 ve 3) |
| `fAna.pas` / `.dfm` | Ana form |
| `fBaglanti.pas` / `.dfm` | Bağlantı penceresi |
| `fTabloSekme.pas` / `.dfm` | Tablo sekmesinin içeriği (kolonlar + ilk satırlar) |
| `Manifest.xml` / `Manifest.rc` | Windows ortak denetimler v6 ve DPI bildirimi. Bu olmadan ikonların arkası siyah çıkıyordu. |

Form olayları (`OnClick` vb.) ilgili işi doğrudan yapar, boş olay yöneticisi yoktur. Sınıf bildirimlerinde alanlar prosedürlerden önce gelir.

## 3. Bileşenler ve lisanslar

Üçüncü parti **kod bileşeni eklenmedi**. Kullanılanlar:

| Parça | Lisans |
|---|---|
| FireDAC, VCL, VCL Style "Windows10" | RAD Studio ile gelir (Embarcadero). `.vsf` depoya konmaz, derlemede RAD Studio kurulumundan kopyalanır. |
| Firebird istemcisi 5.0.4 (`fbclient.dll` 64 bit + yan dosyalar) | IDPL. Depoya konmaz, derlemede `C:\Firebird\Firebird50_64`'ten `istemci\` altına kopyalanır. |
| **Tabler Icons 3.49.0** (12 ikon SVG kaynağı + PNG) | **MIT**, Telif: 2020-2026 Paweł Kuna. Lisans metni indirilen paketten alındı: `Ikonlar\svg\LICENSE_tabler.txt`. Fugue'ya geçmek gerekmedi. |

SynEdit ve Virtual TreeView eklenmedi (Aşama 2 / gerekirse). Ayrıntı: `LISANSLAR.md`.

İkon PNG'leri Tabler SVG'lerinden Edge (headless) ile 32x32 olarak üretildi. 12 ikonun 9'u kullanılıyor, `file-plus`, `player-play`, `plug-connected` Aşama 2 için hazır duruyor.

## 4. Test edilen

- RAD Studio 12, Win64 Release, `msbuild` ile temiz derleme (`Derle.bat`), hatasız, derleme sonrası betik çalışıyor.
- **Geçici Firebird 5.0.4 veritabanı** (gömülü kip, gerçek veriye dokunmadan): ağaç, kolonlar, `NUMERIC(12,2)`, `NULL` bilgisi, `BLOB SUB_TYPE`, Türkçe karakterli tablo adı ("Küçük Tablo") ve Türkçe veri ("Şişli Güneş Çiçek İnşaat", "Ömer Yılmaz"). Test programı: `Test\MetadataTest.dpr`.
- **Hata yolları** (sahte kullanıcıyla ve kapalı portla): yanlış kullanıcı/şifre (3050 ve 3051), kapalı port, olmayan yol. Anlaşılır cümle ve ham mesaj doğru eşleşti. Bu denemeler iki sunucunun günlüğüne başarısız giriş olarak düşmüş olabilir.
- **Arayüz** (fare ile): bağlantı penceresi, bağlanma, ağaç, tablo sekmeleri, sekme geçişi, Türkçe → Almanca anlık dil değişimi, Almanca hata penceresi, ikonların saydamlığı.
- Her iki sunucuya da bağlanıldığı **proje sahibi tarafından** gerçek veritabanı kopyalarında doğrulandı: 2.5.9 (`DATABASE.FDB`, port 3050) ve 5.0.4 (`sys_database.fdb`, port 3051). Ağaç doldu (5.0'da 39 tablo), tablolar açıldı.
- Dil dosyaları: kodda kullanılan 56 anahtarın hepsi tr, en, de dosyalarında var.
- Şifre taraması: eklenecek dosyalarda şifre, `masterkey` veya gerçek veritabanı yolu yok. Test şifresi sadece ortam değişkeninden okunur.

## 5. Test edilemeyen

- Gerçek veritabanlarına **ben** bağlanamadım: SYSDBA şifresini bilmiyorum ve girmem gerekmiyordu. Gerçek kopyalardaki sonuçlar proje sahibinin kendi denemesine dayanıyor.
- Firebird 3.0 ve 4.0 hiç denenmedi (makinede kurulu değil). Kodda sürüme özel bir şey yok, ama denenmedi.
- Büyük veritabanlarında (binlerce tablo) ağaç hızı ölçülmedi. Hız sorunu olursa Virtual TreeView için önce size sorulacak.
- Çok yüksek DPI / çoklu monitör denenmedi.
- Windows kullanıcısı değişince DPAPI ile saklanan şifrenin çözülememesi denenmedi. Kod bu durumda hata vermeden boş şifre döndürür, ama test edilmedi.

## 6. Bilinen sorunlar ve eksikler

- Veri tipi sütunu dar: Firebird 5.0'da identity kolon "INTEGER GENERATED BY DEFAULT..." diye uzun yazıyor ve kesiliyor.
- Veri ızgarasında kolon genişliği sabit, uzun metin/BLOB kısaltma, sıralama, zebra renk, NULL gösterimi yok. Bunlar Aşama 2 (`uSonucGrid.pas`).
- Sağ tık menüsünde sadece "Aç" ve "Yenile" var. "Yapıyı göster", "Script üret" sonraki aşamalarda.
- Sunucu alanı boş bırakılırsa istemci gömülü motoru kullanır. Sunucu aynı dosyayı açmışsa "dosya kullanılıyor" hatası çıkar (IBExpert'teki çakışmanın nedeni de buydu). Bağlantı penceresinde bir uyarı **henüz yok**, onay bekleniyor.
- Sonuç alanında eski mesajlar dil değişince çevrilmez (günlük gibi tutuluyor).
- Aynı anda tek bağlantı vardır. Yeni bağlantı eskisinin yerine geçer (çoklu veritabanı Aşama 4).
- `BYN_MALADI` tablosunun ilk satırları boş göründü, büyük olasılıkla kopyada tablo boş (doğrulanmadı).
- Stil dosyası (`Windows10.vsf`) derleme sırasında RAD Studio kurulumundan kopyalanır, yoksa program standart görünümle açılır.
- RAD Studio IDE'sinde derleme `.dproj` üzerinden `SonDerleme.bat`'ı çağırır. Önceki sürümde yol `Kaynak..\` olarak birleşip hata veriyordu, `$(MSBuildProjectDirectory)\..\` ile düzeltildi. IDE'de bu düzeltmeyi **ben denemedim**, sadece `msbuild` ile denendi.
- `Firebird istemcisi` kaynak yolu (`C:\Firebird\Firebird50_64`) `SonDerleme.bat` içinde sabit, başka bilgisayarda değiştirilmeli.

## 7. Belgeden sapmalar

- `uIkon.pas`, `uOnay.pas`, `Manifest.*` ve `Test\MetadataTest.dpr` eklendi (hepsi kendi kodumuz, harici bileşen yok).
- Kodlar `Kaynak\` klasöründe, dil dosyaları `Diller\`, ikonlar `Ikonlar\`.
- `.dproj` içinde `Win64` hedeflendi, `Win32` işaretli değil.
- VCL Style `.dproj` ile gömülmedi (bu derlemede işlemedi), çalışma zamanında `Stiller\Windows10.vsf` yüklenir.
