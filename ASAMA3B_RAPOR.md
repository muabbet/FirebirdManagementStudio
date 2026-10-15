# Aşama 3b raporu: CSV dışa aktarma

Dal: `asama3b-csv` (main `8875ccc`'den açıldı; GitHub'a itilmedi, PR yok). `CLAUDE.md` kutuları **işaretlenmedi**, onayınız bekleniyor.

## Ne yapıldı

- **`uAktar.pas` (yeni):** `CsvAktar(Bag, Sql, Yazici, Secenekler, Uyarilar, Ilerleme, SatirSayisi)`. Sonucu üreten SELECT'i aynı bağlantıda **yeni, salt okunur, anlık görüntü (snapshot) işlemiyle** yeniden çalıştırır; `fmOnDemand` + `Unidirectional`, önbellek yok, satır satır yazar. Ayraç ve ondalık ayracı parametredir; Windows'tan okuyan `WindowsCsvSecenekleri` aynı unit'te. Ayrıca `VarsayilanCsvAdi`, `AktarmaHatasiniCevir`.
- **`uSorgu.pas`:** `TabloTumSatirlarSorgusu(Tablo)` (`SELECT * FROM "TABLO"`) eklendi; `TirnakliAd` gizli kaldı, açılmadı.
- **`fCsvAktar.pas/.dfm` (yeni):** ince pencere (hedef dosya, Seç..., Başlat, İptal/Kapat). Dosya varsa `OnayIste` ile üzerine yazma onayı. İlerleme "12.500 satır yazıldı", `ProcessMessages` ile pencere donmaz. İptalde dosya silinmez, "dosyada yalnızca N satır var" yazılır. Hata olursa pencere açık kalır (Excel'de açık dosyayı kapatıp tekrar Başlat denenebilir). `fMetadataCikar`'a dokunulmadı; onun `Ilerle` yöntemini ortaklaştırmak yerine 6 satırlık kendi `Ilerle`'si var (sadelik için).
- **Düğme:** sonuç alanı başlığında (`pnlSonucBaslik` / `pnlVeriBaslik`), araç çubuğuna eklenmedi. Sorgu sekmesinde yalnızca satır döndüren sonuç varken etkin; tablo sekmesinde hep etkin ve **tüm** satırları aktarır. Genişlik yazıya göre uzar (`uOnay.DugmeyiYaziyaUydur`, yeni küçük yardımcı).
- **Özet:** ana pencerenin sonuç alanına (`memSonuc`, sekmelere `AnaSonuc` ile verilir): dosya, satır, süre, uyarılar (BLOB atlandı, Excel sınırı).
- **`uBaglanti.pas`:** `isc_read_only_trans` (335544361) için "salt okunur, veri değişmedi" cümlesi eklendi.
- **Dil:** `tr/en/de` üçüne 16 anahtar eklendi (`AKTAR_*`, `ERR_AKTAR_*`, `ERR_SALT_OKUNUR`). Anahtar kümeleri eşit: üçünde **197**, fark yok.
- `.dpr` ve `.dproj`'a `uAktar`, `fCsvAktar` eklendi. Yeni bileşen yok.

## Biçim kararları (ölçülerek doğrulandı)

UTF-8 BOM, CRLF, başlık satırı kolon/takma adları, `"` kaçışı, NULL boş alan; tarih `yyyy-mm-dd`, `hh:nn:ss`, `yyyy-mm-dd hh:nn:ss`; boolean `TRUE/FALSE`; sayılarda binlik ayracı ve bilimsel gösterim yok. `NUMERIC(18,2)` hane kaybı olmasın diye `dtBCD` → `dtFmtBCD` eşlenir (`1234567890123456,78` tam çıktı). Metin BLOB yazılır, ikili BLOB boş kalır ve uyarı verilir.

## Test (gömülü Firebird 5.0.4, geçici veritabanı)

**Yeni `AktarTest`: 70 kontrol, hata 0** (1,1 milyon satırlık isteğe bağlı koşuyla birlikte 75). Kapsam:
- Alan kuralları, iki ayraç seçeneğiyle (`;`+`,` ve `,`+`.`) ayrı ayrı: ayraç/`"`/satır sonu/boş metin/NULL/Türkçe/5000 karakterlik metin/metin BLOB/ikili BLOB/SMALLINT…BIGINT uçları/NUMERIC/DECIMAL/FLOAT/DOUBLE/küçük kesirler/DATE/TIME/TIMESTAMP/BOOLEAN. Bağımsız CSV okuyucusuyla geri okundu; ilk 3 bayt `EF BB BF`, her LF'den önce CR var.
- **100.000 satır, 10 kolon:** satır sayısı tam 100.000 + başlık, her satırın değeri tek tek denetlendi. Süre **1,4 sn** (~73.000 satır/sn), dosya 11,6 MB, çalışma kümesi başta 51,0 MB → tepe 51,4 MB (**artış 0,4 MB**).
- **1.100.000 satır** (Excel sınırını da denemek için 1 milyon yerine 1,1 milyon): tam 1.100.000 satır, hepsi doğru, süre **17,2 sn**, 133,9 MB dosya, bellek **54,1 → 54,2 MB (artış ≈ 0)**, Excel uyarısı çıktı. Bellek satır sayısına bağlı büyümüyor.
- **Ekran sınırı:** ekranda 500 satır yüklüyken JOIN + ORDER BY DESC sonucu dosyada 100.000 satır, sıra doğru, ekrandaki sonuç etkilenmedi.
- **İptal:** 5000. satırda `False`, dosya silinmedi, 5001 satır, hepsi tam, son satır yarım değil, CRLF ile bitiyor.
- **Salt okunur:** `SELECT * FROM P_YAZ` (INSERT yapan prosedür) hata verdi ve `ERR_SALT_OKUNUR` cümlesine çevrildi; tablo boş kaldı. Kontrol: aynı komut normal işlemde 1 satır yazıyor, yani engel gerçekten salt okunur işlemden.
- **Hatalar (anlaşılır cümle):** olmayan tablo, sözdizimi, olmayan klasör, başka programda açık dosya, **bağlantı kopması** (`MON$ATTACHMENTS` ile aktarma sürerken koparıldı → "Sunucu ile bağlantı koptu").
- Windows ayarı bu makinede `;` ve `,` okundu. Üç dilde `AKTAR_*` anahtarları dolu.

**Mevcut testler (yeniden derlenip çalıştırıldı):** `DDLTest` **146 OK, hata 0** (iki koşu); `SorguTest` **80/80**; `BaglantiDosyasiTest` **52/52**; `MetadataTest` çıkış kodu 0. `Derle.bat` hatasız.

**DDLTest 147/146 farkı:** kod değişmedi. `8d8ad3b` (147 yazan rapordaki durum) ayrı çalışma ağacında derleyip çalıştırdım: orada da **146 OK**. Yani 147, büyük olasılıkla 146 `OK` satırına sondaki "Hata sayisi: 0" satırının eklenmesiyle sayılmıştı (benim `HATA` aramam da büyük/küçük harf duyarsız olunca aynı satırı yakalıyor). Gerçek kontrol sayısı hep 146.

## Bilinen sınırlar

- NULL ile boş metin ayırt edilemez (ikisi de boş alan).
- Baştaki sıfır (`00123`) Excel'de kaybolur; hile yapılmadı.
- Yeniden çalıştırma: arada veri değiştiyse dosya ekrandan farklı olabilir (anlık görüntü işlemi dosyanın kendi içinde tutarlı olmasını sağlar).
- `CHAR` dolgu boşlukları FireDAC'ta kırpılıyor (`AB` yazılır, `AB    ` değil). Sondaki sıfırlar korunmaz: `5.10` → `5,1`, `0.00` → `0`; değerler sayısal olarak aynıdır.
- 1.048.575 veri satırı üstünde Excel uyarısı çıkar, dosya yine yazılır.
- Mevcut dosya onayla üzerine yazılırken önce kısaltılır; ardından SQL/bağlantı hatası olursa eski içerik gitmiştir (onayı siz verdiniz). Silme yok.
- Disk dolu durumu **denenmedi** (yalnız aynı hata sınıfı olan "olmayan klasör" ve "açık dosya" denendi).

## Arayüzde denenmedi

Programı hazırlanan geçici veritabanıyla (ayrı `APPDATA`) başlattım: pencere hatasız açıldı, yanıt veriyor, kapatıldı (dfm ve olay bağları yükleniyor). Ancak bilgisayar kontrol aracı `FirebirdYonetici.exe`'yi tanımadığı için **tıklayarak deneyemedim**. Şunlar **denenmedi**:
- düğmenin etkin/pasif durumları (sorgu sekmesi sonuçsuz / SELECT / DML sonrası),
- `fCsvAktar` penceresinin görünümü ve akışı, Seç... penceresi, üzerine yazma onayı,
- 100.000 satırda pencerenin donmaması ve İptal düğmesinin arayüzden çalışması (iptal mantığı testte denendi),
- Almanca yazıların sığması, dil değişince düğme genişliği,
- tablo sekmesinden aktarma ve özetin ana pencerenin sonuç alanına yazılması,
- Excel'de çift tıklayıp açma.

## Sizden beklenenler

1. Sunucu testleri (şifre bende yok). Derleme: `Test\AktarTestDerle.bat`. Sonra, 2.5.9 için (5.0.4 için port 3051):
```
set FBTEST_SUNUCU=localhost
set FBTEST_PORT=3050
set FBTEST_KLASOR=C:\Temp
set FBTEST_KULLANICI=SYSDBA
set FBTEST_SIFRE=...
set FBTEST_CIKTI=%TEMP%\aktartest_259.txt
bin\Win64\Release\AktarTest.exe
```
`FBTEST_KLASOR` sunucudaki bir klasör olmalı (orada geçici veritabanı açılır, gerçek veriye dokunmaz); CSV'ler bu bilgisayarda `%TEMP%\aktartest`'e yazılır. İsteğe bağlı: `AKTAR_SATIR`, `AKTAR_MILYON=1100000`. 2.5.9'da BOOLEAN kolonu ve 3.0+ özellikleri otomatik atlanır; `DATEADD`/`LPAD`/`MON$ATTACHMENTS` 2.5'te var, ama 2.5'te hiç koşulmadığı için orada çıkabilecek farklar bilinmiyor.
2. Arayüzde yukarıdaki "denenmedi" listesini elle deneyin, 100.000 satırlık bir tabloyu Excel'de açıp Türkçe karakter, sayı ve tarihlere bakın.
3. Onayınızdan sonra `CLAUDE.md` Aşama 3 "Veri dışa aktarma" kutusunu işaretleyeceğim; 3c'ye geçmedim.
