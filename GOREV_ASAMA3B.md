# Görev: Aşama 3b, veri dışa aktarma (yalnızca CSV)

Bu görev, **Delphi/RAD Studio 12 ve gerçek Firebird sunucuları olan makinede** çalışan ajan içindir. Aşama 3a sahibi tarafından onaylandı. Bu, Aşama 3'ün (Yönetim Özellikleri) **ikinci alt aşamasıdır**; genel plan `GOREV_ASAMA3.md`'de (3c, 3d orada), ama **şimdilik yalnızca 3b'yi yap**.

**Önce `CLAUDE.md` dosyasının tamamını oku** (özellikle Bölüm 3, 4, 6, 7, 10). Sonra `ASAMA3A_RAPOR.md`'yi (özellikle `fMetadataCikar` penceresi ve ilerleme/iptal yöntemi), `Kaynak\uSorgu.pas`, `Kaynak\fSorguSekme.pas`, `Kaynak\fTabloSekme.pas`, `Kaynak\fMetadataCikar.pas`, `Kaynak\uOnay.pas` dosyalarına göz at.

## Çalışma düzeni

- **Önce kontrol:** `main`'de 3a'nın birleşmiş olduğunu doğrula (`Kaynak\fMetadataCikar.pas` ve `ASAMA3A_RAPOR.md` `main`'de olmalı). Yoksa **dur** ve sahibine söyle; kendin birleştirme.
- Dal: `main`'in son halinden `asama3b` adlı yeni dal aç (`git fetch`, `git checkout main`, `git pull`, sonra dalı aç). `main`'e yazma.
- Tüm yanıt ve rapor Türkçe. Her yeni yazı için üç dil dosyası (tr, en, de) güncellenir. Dosya silme yok (`_arsiv`). Yeni bileşen yok. Kod sade kalsın (CLAUDE.md Bölüm 3): düğmenin `OnClick`'i işi yapan unit fonksiyonunu (veya kısa yordamı) doğrudan çağırır, formlarda sabit yazı yok, sınıf bildiriminde alanlar prosedürlerden önce, boş olay yöneticisi yok.
- Belirsiz bir şey olursa tahmin etme, sahibine sor.
- Sahibinin Firebird 2.5.9 ve 5.0.4 sunucu bağlantıları gerçek veridir: **orada nesne oluşturma/silme/veri yazma deneme.** Yalnızca geçici veritabanında dene. Sunucu şifresi sahibindedir; 3050/3051 sunucu testlerini sahibi kendi penceresinde çalıştırır. Ajan şifre tahmin etmez, gömülü 5.0.4 ve geçici veritabanıyla ölçer, sunucu testleri için komutları rapora yazar.
- Tehlikeli işlemler (var olan dosyanın üzerine yazma) net onay penceresi ister (`uOnay.OnayIste`), onaysız yazma yok.
- **3a'dan küçük devreden iş:** 3a düzeltmesinden sonra raporda `DDLTest` 147 yerine 146 kontrol yazıyordu ve fark açıklanmamıştı. `DDLTest`'i çalıştırıp sayıyı kontrol et, farkın nedenini 3b raporuna bir cümleyle yaz (kod değişikliği gerekmiyorsa dokunma).

## Amaç ve davranış

Sonuç ızgarasındaki veri, **tüm satırlarıyla** CSV dosyasına aktarılır. Yalnızca ekrandaki 500 satır değil. Excel'de çift tıklayıp açılmalı, Türkçe karakterler bozulmamalı. `.xlsx` yazılmaz.

### Hangi sonuçlar

1. **Sorgu sekmesi:** son çalıştırılan `SELECT`'in sonucu (çoklu komutta `BetikCalistir`'in döndürdüğü son SELECT sonucu). Düğme yalnızca sekmede satır döndüren bir sonuç varken etkin.
2. **Tablo sekmesi (tabloya çift tık):** tablonun **tüm** satırları (`SELECT * FROM "TABLO"`), sekmede yalnızca ilk 100 satır görünse bile.

### Nasıl okunur (önemli, tasarım kararı)

Ekrandaki sonuç sayfa sayfa çekiliyor (`SATIR_PARCASI`) ve FireDAC onları bellekte tutar; büyük sonuçta bu yol kullanılmaz. Bunun yerine:

- Dışa aktarma, **sonucu üreten SELECT komutunu yeniden çalıştırır**: aynı bağlantıda (`Bag.Baglanti`) **yeni, ayrı bir salt okunur transaction** (`TFDTransaction`, `Options.ReadOnly`) ve yeni bir `TFDQuery` ile. Salt okunur olduğu için `SELECT ... FROM prosedür` gibi yan etkili bir komut yanlışlıkla veri yazamaz (Firebird hata verir; bu hata anlaşılır cümleyle gösterilir).
- Sorgu, bellekte biriktirmeyecek biçimde açılır (`FetchOptions.Mode := fmOnDemand`, `Unidirectional := True`, `RowsetSize` makul, ör. 500; önbelleğe alma yok), **satır satır dosyaya yazılır.** 100.000 satırda da 1.000.000 satırda da bellek kullanımı yaklaşık sabit kalmalı (testle göster).
- Sonucu üreten SQL metni: sorgu sekmesinde `TSorguSonucu.Sorgu.SQL` içinde zaten var (yeni alan icat etmeden önce bak); tablo sekmesi için `uSorgu`'ya tablo adından tam okuma SQL'i üreten küçük bir fonksiyon ekle (`TirnakliAd` şu an `uSorgu` içinde gizli; açman gerekiyorsa açıkla). Yeniden çalıştırma ekrandaki sonuçla aynı SQL'dir; arada veri değiştiyse dosya ekrandan farklı olabilir (rapora bir cümle yaz, kullanıcıya ayrıca uyarı gösterme).
- Eski sürümlerde (2.5) `FIRST`/`ROWS` gibi sürüme bağlı bir şey kullanma; tam sonucu sorguyla aynen çalıştırmak yeterli. Sürüme bağlı bir fark çıkarsa `uMetadata`/`uSorgu` arkasında kalsın, formda olmasın.

### Dosya biçimi

- **Kodlama:** UTF-8 **BOM'lu** (Excel çift tıklayınca Türkçe karakterleri doğru okusun diye). Satır sonu `CRLF`.
- **Ayraç:** kullanıcının Windows liste ayracı (`GetLocaleInfo` ... `LOCALE_SLIST`; Türkçe Windows'ta `;`). Ayraç boşsa veya ondalık ayracıyla aynıysa `;` kullan. Bu Windows'a bağlı kısım **yeni `uAktar.pas`'in arkasında** kalsın (CLAUDE.md Bölüm 4).
- **Ondalık ayracı:** kullanıcının Windows ondalık ayracı (Türkçe Windows'ta `,`); binlik ayracı **yok**, bilimsel gösterim (`1E+05` gibi) **yok**. `NUMERIC(p,s)` değerleri hane kaybetmeden yazılmalı (ör. `NUMERIC(18,2)` `1234567890123456,78` olarak çıkmalı, kayan noktaya çevrilip bozulmamalı). Büyük `BIGINT`/`INT128` değerleri de tam çıkmalı.
- **Başlık satırı:** her zaman ilk satır, kolon adları (sorgudaki takma adlar dahil).
- **Alanlar:** ayraç, `"` veya satır sonu (`CR`/`LF`) içeren değer `"..."` içine alınır, içindeki `"` ikiye katlanır. `NULL` boş alan olur (boş metinle ayırt edilemez, bilinen sınır, rapora yaz).
- **Tarih/saat:** ISO biçimi: `DATE` → `yyyy-mm-dd`, `TIME` → `hh:nn:ss`, `TIMESTAMP` → `yyyy-mm-dd hh:nn:ss`. Saat dilimli tipler (5.0) için de aynı sade biçim, dilim bilgisi gerekiyorsa sahibine sor.
- **Boolean:** `TRUE`/`FALSE`.
- **BLOB:** ikili (binary) BLOB değerleri **yazılmaz**, hücre boş kalır, başlık kalır. **Metin BLOB'ları** (`SUB_TYPE TEXT`, açıklama/not alanları sık kullanılır) metin olarak yazılır (alan kuralları geçerli, satır sonu varsa tırnaklanır). Dışa aktarmada en az bir ikili BLOB kolonu atlandıysa sonuç mesajına "BLOB alanları atlandı" notu (hangi kolonlar) eklenir.
- **Excel sınırı:** 1.048.575 veri satırından fazla yazıldıysa sonuç mesajına "Excel bu kadar satırı açamaz" uyarısı eklenir (dosya yine de yazılır).
- Baştaki sıfırların (`00123`) Excel'de kaybolması gibi Excel'in kendi davranışları için **hile yapma** (`="00123"` vb. yok); rapora "bilinen sınır" olarak yaz.

### Arayüz

- **Tek düğme: "Dışa aktar"**, sonuç alanının başlık satırında (sorgu sekmesinde `lblSonuc` yanında, tablo sekmesinde `lblVeri` yanında). **Araç çubuğuna ekleme** (zaten yedi düğme var; araç çubuğu doldu). Menü ve ikinci yol yok.
- Düğme tıklanınca küçük bir pencere (`fCsvAktar.pas/.dfm`, form ince, iş `uAktar.pas`'te): hedef dosya (varsayılan ad `<tablo adı veya "sorgu">_yyyymmdd_hhnnss.csv`, "Seç..." ile `TSaveDialog`), **Başlat**, **İptal/Kapat**. Başka seçenek **yok** (ayraç, kodlama, başlık satırı seçtirilmez; Bölüm 8: ayar yığma yok).
- İlerleme: "12.500 satır yazıldı" gibi (satır sayısı, biçimlenmiş), pencere donmaz (`fMetadataCikar`'daki `ProcessMessages` yöntemini kullan; aynısını tekrar yazma, ortak bir yere almak daha sadeyse al, ama `fMetadataCikar` davranışı değişmesin), **İptal** düğmesi çalışır. İptalde **yarım dosya silinmez**, kullanıcıya "dosyada yalnızca N satır var (dosya silinmedi)" denir.
- Hedef dosya zaten varsa **üzerine yazma onayı** (`uOnay.OnayIste`, dosya adı ve son değişiklik tarihi yazılı, `fMetadataCikar`'daki gibi). Onaysız yazma yok.
- Bitiş: ana pencerenin sonuç alanına özet (dosya adı, satır sayısı, süre) ve varsa uyarılar (BLOB atlandı, Excel sınırı).
- Hatalar (disk dolu, dosya başka programda açık, SQL hatası, bağlantı kopmuş) anlaşılır tr/en/de cümle + "Ayrıntı"da ham mesaj (Bölüm 6, madde 7).
- Her yeni yazı için üç dil dosyası; `Dışa aktar` yazısı, pencere yazıları, durum/özet/uyarı/hata cümleleri. Düğme ve pencere genişlikleri yazıya göre uzar (Almanca kesilmesin).

### Mimari

- **`uAktar.pas`** (yeni): `CsvAktar(Bag, Sql, Yazici, Secenekler, Uyarilar, Ilerleme)` gibi sade bir fonksiyon (3a'daki `MetadataCikar` imzasını örnek al: `TTextWriter`, `Uyarilar: TStrings`, ilerleme geri çağrısı, iptalde `False` döner). Ayraç ve ondalık ayracı **parametre** olsun (test iki seçeneği de denesin); Windows'tan okuyan küçük fonksiyon aynı unit'te. CSV alan kaçışı ve biçimleme de burada.
- Form (`fCsvAktar`) yalnızca arayüzü bilir; `fSorguSekme`/`fTabloSekme` yalnızca pencereyi açar. Dosyaya `TStreamWriter` ile akış (bellekte tek metin yok), kodlama `TUTF8Encoding.Create(True)`.
- `.dpr`, `.dproj`'a yeni unit ve form eklenir. Harici bileşen eklenmez.

## Doğrulama (zorunlu)

Yeni test: `Test\AktarTest.dpr` + `Test\AktarTestDerle.bat` (`DDLTest`/`DDLTestDerle.bat` gibi; gömülü 5.0.4, geçici veritabanı kendi oluşturur; dosya silme yok, artıkları `_arsiv`e taşı). Sunucu 2.5.9/5.0.4 için komutları rapora yaz, sahibi çalıştırır.

1. **Alan kuralları** (küçük tablo, her kombinasyon): ayraç içeren, `"` içeren, satır sonu içeren, boş metin, `NULL`, Türkçe karakter (ç ğ ı ö ş ü İ), uzun metin, metin BLOB (satır sonlu), ikili BLOB, tüm sayı tipleri (`SMALLINT`, `INTEGER`, `BIGINT`, `NUMERIC(18,2)` büyük değerle, `DECIMAL`, `FLOAT`, `DOUBLE PRECISION`, negatif, küçük kesirler), `DATE`, `TIME`, `TIMESTAMP`, `BOOLEAN` (5.0). Çıktıyı **testin kendi bağımsız CSV okuyucusuyla** geri oku (satır/alan sayısı ve değerler aynı mı), ayrıca dosyanın ilk üç baytı `EF BB BF`, satır sonu `CRLF`.
2. **Ayraç/ondalık:** hem `;`+`,` hem `,`+`.` seçeneğiyle çıktı doğru mu.
3. **100.000 satır** (en az 8-10 kolonlu, karışık tipli) tablo: tümü dışa aktarılır, **satır sayısı tam 100.000 + başlık**, süre ve **bellek** (çalışma kümesi, başlangıç ve bitişte) rapora yazılır. Mümkünse **1.000.000 satır** ile de dene (bellek kabaca aynı kalıyor mu, süre kaç). Sunucuda değil, gömülü geçici veritabanında.
4. **Büyük sonuçta ekran sınırı:** sorgu sekmesi mantığıyla (ekranda 500 satır çekilmiş) ama dosyada tümü, sonuç başka bir sorguya (JOIN/`ORDER BY` ile) bağlı olsa da doğru satır sayısı.
5. **İptal:** ortasında iptal edilince `False` döner, dosya silinmez, yazılan kısım tutarlı CSV (son satır yarım değil, ya da yarım olabileceği raporda yazılı).
6. **Salt okunur:** yan etkili bir prosedürü `SELECT * FROM prosedür` ile çalıştıran bir dışa aktarmanın veri yazamadığını göster (Firebird hatası anlaşılır cümleyle çıkıyor mu).
7. **Hata:** kapalı bağlantı, yazılamayan yol (geçersiz klasör), SQL hatası; anlaşılır cümle.
8. Mevcut testler geçmeli: `DDLTest`, `SorguTest` (80), `BaglantiDosyasiTest` (52), `MetadataTest`.
9. Programı derle (`Derle.bat`), arayüzü kendin dene; **denemediğini "denemedim" diye açıkça yaz** (önceki raporlardaki gibi). Özellikle: düğme etkin/pasif durumları, pencere akışı, Almanca yazıların sığması, 100.000 satırda pencerenin donmaması.

**Bitiş ölçütü:** 100.000 satırlık bir tablonun (ve bir sorgu sonucunun) sonucu CSV'ye aktarılıp Excel'de çift tıkla açılıyor, Türkçe karakterler bozulmuyor, sayı ve tarihler Excel'de doğru görünüyor; iptal çalışıyor; bellek sabit kalıyor.

## Rapor ve bitiş

- `ASAMA3B_RAPOR.md` (Türkçe, kısa): ne yapıldı, ne test edildi (sayılarla: kontrol sayısı, satır sayısı, süre, bellek), neler eksik kaldı, bilinen sınırlar (NULL ile boş metin ayrımı yok, baştaki sıfır, Excel satır sınırı, ekrandan farklı olabilen yeniden çalıştırma), sahibinin elle deneme listesi, sahibinden bekleyenler (2.5.9/5.0.4 sunucu testleri, Excel'de açıp bakma).
- `CLAUDE.md` Aşama 3 kutularını **işaretleme** (sahibi onaydan sonra işaretletir). 3c'ye **geçme**; sahibinin onayı beklenir.
