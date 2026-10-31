# Tek .exe paketi raporu (dal `paket`)

**Sorun (sahibi, 2026-10-31):** Müşteriye yalnız `.exe` ve `Ikonlar` klasörü gitti: dil dosyaları yoktu (arayüzde `BTN_YENI_BAGLANTI`, `APP_BASLIK` gibi anahtarlar göründü) ve "istemci yok" (`ERR_ISTEMCI_YOK`) hatası çıktı. İstenen: **tek bir .exe ile her şey** çalışsın.

## Çözüm

Dil dosyaları, ikonlar, `anahtar_kelimeler.txt`, tema (`Windows10.vsf`) ve Firebird istemcisi (`fbclient.dll`, `gbak.exe`, eklentiler, Visual C++ çalışma dosyaları) derlemede **bir ZIP** olarak `.exe`'nin içine gömülür (3 MB; `.exe` ≈ 14,6 MB). Program ilk açılışta ZIP'i `%LOCALAPPDATA%\FirebirdYonetici\paket` klasörüne açar, sonraki açılışlarda (`.exe` aynıysa) tekrar açmaz. Yönetici yetkisi gerekmez; kullanıcıya ait hiçbir dosya silinmez.

| Dosya | Görev |
|---|---|
| `Kaynak\uPaket.pas` (yeni) | `PaketKlasoru`: dosyaların bulunduğu klasör. `.exe`'nin yanında `Diller\tr.json` varsa orası (geliştirme / test, eskisi gibi); yoksa gömülü paketin açıldığı klasör |
| `Kaynak\Paket.rc` (yeni) | ZIP'i `.exe`'ye gömer (`PAKET RCDATA`) |
| `PaketHazirla.bat` (yeni) | `SonDerleme.bat` ile dosyaları `obj\paket`'e toplar, `Kaynak\Paket.zip` yapar |
| `Derle.bat`, `FirebirdYonetici.dproj` | Önce `PaketHazirla.bat` (dproj'ta PreBuildEvent), `Paket.rc` derleme listesinde |
| `uDil`, `uIkon`, `uBaglanti`, `uYedek`, `uDDL`, `fSorguSekme`, `fProsedurSekme`, `FirebirdYonetici.dpr` | `ExtractFilePath(ParamStr(0))` yerine `PaketKlasoru` |

## ICU neden pakette yok?

`icudt63l.dat` (27 MB) ve `icu*.dll`, uzak sunucuya bağlanan istemci için gerekmiyor. Ölçüm: ICU'suz istemciyle `TabloYapiTest` **2.5.9 sunucuda 100/0, 4.0.7 sunucuda 102/0** geçti (kolon, index, kısıt, tablo oluşturma/silme, Türkçe karakterler dahil). Gömülü (embedded) motor kullanılacaksa `PAKET_ICU=1` ile pakete eklenir.

## Denenen

- `.exe` tek başına boş bir klasöre kopyalandı ve açıldı: pencere açıldı, 39 dosya `%LOCALAPPDATA%\FirebirdYonetici\paket` altına çıktı (Diller, Ikonlar, istemci, Stiller, anahtar_kelimeler.txt, lisanslar).
- Ayrı klasördeki ICU'suz minimum istemci ile iki sunucuya bağlanıp tam test koşuldu.
- **Denemedim:** Pencerede dillerin ve ikonların görünmesini gözle; başka bir Windows bilgisayarda açılışı (özellikle antivirüsün açılan `fbclient.dll` / `gbak.exe`'ye tepkisi); eski açık bir kopya `fbclient.dll`'i kilitliyken yeni sürümün paketi açması.

## Bilinen sınırlar

- IDE'de derlerseniz paket bir SONRAKİ derlemede güncel olur (Delphi önce kaynakları derler, sonra PreBuildEvent çalışır). Dil/ikon/istemci dosyaları değiştiyse `Derle.bat` ya da önce `PaketHazirla.bat` çalıştırın.
- Yeni dil eklemek: `.exe`'nin yanına `Diller` klasörü koymak yeterli DEĞİL (gömülü paket seçilir); `Diller\tr.json` dahil tüm klasörü yanına koyarsanız program yalnız o klasörü kullanır (geliştirme kipi). İleride "ek dil klasörü" ayrıca düşünülebilir.
- Paket yeni `.exe`'de yeniden açılır (imza: ZIP boyu + `.exe` zamanı); eski dosyalar silinmez, üstüne yazılır.
- Firebird istemcisi 5.0 (64 bit). 32 bit bir sürüm gerekirse ayrı derleme gerekir.
- `LISANSLAR.md`: pakete Firebird istemcisinin lisans dosyaları (`IDPLicense.txt`, `IPLicense.txt`) ve SynEdit lisansı da konur; yayın öncesi kontrol edilmeli.

## Müşteriye verme

Yalnızca `bin\Win64\Release\FirebirdYonetici.exe` dosyasını verin. İlk açılışta birkaç saniye sürebilir (dosyalar açılır).
