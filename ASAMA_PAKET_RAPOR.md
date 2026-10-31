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

---

# Kolon veri tipi: listeden seçim, zorunlu boyut (aynı dal)

**İstek (sahibi):** "Kolon eklerken veri tipi combobox ile gelsin, Firebird sürümüne göre; zorunlu alanları (uzunluk vb.) sorsun, `varchar(50)` yazmak amatörce."

- **Liste:** `veri_tipleri.txt` (yeni; `anahtar_kelimeler.txt` ile aynı `#FB3/#FB4` bölüm düzeni, sürüme bağlı kısım kodda değil dosyada). 2.5: 14 tip; 3.0: + BOOLEAN; 4.0/5.0: + INT128, DECFLOAT(16/34), TIME/TIMESTAMP WITH TIME ZONE. Veritabanının domain'leri listenin sonuna "(domain)" ekiyle eklenir.
- **Boyut:** VARCHAR / CHAR seçilince "Uzunluk" kutusu (önceden 50 / 10 yazılı, değiştirilebilir, 1–32765); NUMERIC / DECIMAL seçilince "Toplam basamak" ve "Virgülden sonraki basamak" (önceden 18 ve 2; en çok 18, Firebird 4.0+'da 38). Geçersiz sayı anlaşılır cümleyle reddedilir. Diğer tiplerde boyut kutusu çıkmaz.
- **Değiştir penceresi:** kolonun mevcut tipi listede seçili gelir, sayılar açılır. Değişmediyse eski tip metni aynen korunur (CHARACTER SET gibi ekler kaybolmaz). Listede olmayan tip (örn. `BLOB SUB_TYPE 1`) "(mevcut, değişmez) ..." maddesi olarak görünür.
- **Kod:** `uMetadata` (`VeriTipleriniOku`, `SayiHassasiyetiAzami`), `uKolon` (`KolonTipleri`, `TipAyristir`, `TipMetniOlustur`, `TipSayilariniDogrula`), `fKolonIslem` (yalnız alanlar). Üç dilde yeni anahtarlar (540).
- **Test (`TabloYapiTest` bölüm F, 128 kontrol):** 5.0.4 gömülü 128/0, 3.0.14 gömülü 127/0, 4.0.7 sunucu 127/0, 2.5.9 sunucu 126/0 (liste sürüme göre, ayrıştırma, metin üretme, doğrulama, listeden üretilen tiplerle kolon ekleme, domain tipli kolon, pencere .dfm duman testi). **Pencerenin görünümü ve combo'nun gözle kullanımı denenmedi.**
- Karakter seti (CHAR/VARCHAR için `CHARACTER SET`) sorulmaz, veritabanı varsayılanı kullanılır; istenirse eklenir.
