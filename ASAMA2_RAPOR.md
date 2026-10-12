# Aşama 2 Raporu: SQL Editörü

Dal: `claude/sleepy-pascal-nd1dcw` (`main` 326cc90 üzerine). Bu raporu yazan ortam Linux; **Delphi/FireDAC/SynEdit yok, hiçbir şey derlenmedi ve çalıştırılmadı.** Kod elle yazıldı ve statik olarak kontrol edildi. İlk iş `Derle.bat` ile derleyip hata varsa bana iletmek olmalı.

## 1. Ne yapıldı

- **`uEditor.pas`**: `TSqlEditor` sarmalayıcısı. SynEdit ve SQL renklendirici (`TSynSQLSyn`, Firebird/InterBase 6 ayarı) kodda oluşturulur; `.dfm`'ler SynEdit paketine bağlı değildir. Formlar SynEdit'i bilmez. Secili yazı varsa onu, yoksa tüm editörü çalıştırır.
- **`uSorgu.pas`**: `SorguCalistir`: tek bir komutu çalıştırır (`OpenOrExecute`). SELECT ise `fmOnDemand` ile `SATIR_PARCASI` = 500'er satır çekilir; aşağı indikçe devamı gelir. SELECT değilse etkilenen satır sayısı döner. `:ad` ve `!ad` parametre/makro sayılmaz. Komutun sonundaki `;` atılır. `TehlikeliSorguUyarisi`: `DROP` (ALTER ... DROP dahil) ve `WHERE`'siz `DELETE`/`UPDATE` için onay anahtarı verir; yorum ve tırnak içindeki yazılar sayılmaz.
- **İşlem davranışı (açık):** Her sorgu sekmesinin kendi `TFDTransaction`'ı var, **otomatik onay (autocommit)**. Sonuç mesajı bunu yazar. Böylece bir sekmede yarım okunmuş sonuç, başka sekmenin komutundan etkilenmez. Elle Commit/Rollback yok (araç çubuğunda yer ve bu aşamada istek yok).
- **`uSonucGrid.pas`**: `TSonucGrid`, standart `TDBGrid` üzerine altı özellik: (1) başlık tıklayınca sıralama, ▲/▼; (2) zebra; (3) NULL gri ve eğik "NULL"; (4) kolon genişliği ilk 50 satıra göre (60-400 px); (5) Ctrl+C: Ctrl+tıkla seçilen satırlar, seçim yoksa aktif hücre, sekmeyle ayrılmış (NULL boş, sekme/satır sonu/tırnak varsa tırnaklı); (6) 100 karakterden uzun yazı kısaltılır, BLOB `(BLOB, N bayt)` görünür, çift tıklayınca `fMetinGoster` penceresinde tamamı (ikili BLOB'da ilk 1024 bayt onaltılık). Aynı ızgara tablo sekmesinin veri ızgarasında da kullanılıyor.
- **`fSorguSekme`** (frame): üstte editör, altta sonuç ızgarası ve mesaj kutusu. Hata: anlaşılır cümle + "Ayrıntı" (ham Firebird mesajı). Satır sayısı yazısı kaydırdıkça güncellenir.
- **`fMetinGoster`**: salt okunur tam metin penceresi.
- **`fAna`**: araç çubuğuna **Yeni Sorgu** ve **Çalıştır (F5)**; `F5` tuşu (`KeyPreview`). Seçili bağlantı açıksa yeni sorgu sekmesi açılır (`Sorgu 1 [Bağlantı]`). Bağlantı kesilince / kayıttan kaldırılınca o bağlantının sorgu sekmeleri de kapanır. Çalıştır düğmesi yalnızca sorgu sekmesi aktifken açık.
- **Araç çubuğu (sizin seçiminiz):** 5 düğme: Yeni Bağlantı, Bağlan/Kes, Yenile, Yeni Sorgu, Çalıştır. Yeni Klasör / Klonla / Kayıttan Kaldır çubuktan çıkarıldı; sağ tık menülerinde duruyor (Yeni Klasör: ağacın boş alanına sağ tık).
- **Hata cümleleri (`uBaglanti.HataMetniniCevir`):** benzersiz anahtar ihlali, yabancı anahtar ihlali, nesne yok, SQL yazım hatası için yeni cümleler.
- **Dil:** tr/en/de üçünde de 21 yeni anahtar (112 anahtar, listeler aynı). Kodda kullanılan her `T('...')` üç dosyada var.
- `LISANSLAR.md` (SynEdit), `README.md` güncellendi. İkonlar `code.png` ve `player-play.png` zaten `Ikonlar` klasöründeydi, `uIkon`'a eklendi.

## 2. Ne denendi

- Yalnızca statik kontrol: dil anahtarı eşleşmesi, `.dfm` olay yöneticilerinin `.pas`'ta varlığı, sınıf bildirim sırası, `.pas` dosyalarında Türkçe karakter olmaması.
- **Derleme, çalıştırma, SynEdit, FireDAC davranışı denenmedi.**

## 3. Neler eksik kaldı / riskler

- **Sorgu planı yapılmadı.** FireDAC `TFDQuery`'de plan özelliği yok; plan, düşük seviyeli `TIBStatement.sql_get_plan` üzerinden alınabilir ama bu sınıfa `TFDQuery`'den erişim yolunu doğrulayamadım. Tahmin etmedim. Seçenekler: (a) FireDAC iç arayüzünü deneyerek bulmak (Delphi'li makinede), (b) `fbclient.dll`'deki `isc_dsql_sql_info` ile doğrudan istemci API'si. Hangisini istediğinizi söyleyin.
- **`anahtar_kelimeler.txt` kullanılmıyor.** Renklendirme SynEdit'in kendi Firebird ayarını kullanıyor. `TSynSQLSyn`'a dışarıdan anahtar kelime listesi verme yolunu doğrulayamadım. Kural 9.3 gereği bizim kodumuzda gömülü liste yok, ama dosya şimdilik boşta. Otomatik tamamlama (Ctrl+Boşluk) için kullanılabilir; karar sizin.
- **Tek komut:** Aynı anda yalnızca bir komut çalışır (`;` ile ayrılmış birden fazlası SQL yazım hatası verir). Çok komutlu betik (`SET TERM`, `COMMIT`) için `TFDScript` gerekir; Aşama 3 ile birlikte düşünülebilir.
- **Sıralama sınırı:** Başlıkla sıralama, o ana kadar yüklenen satırlar üzerinde yapılır; sonradan gelen satırlar sıralı yere girer. Tüm sonuç üzerinde gerçek sıralama için komuta `ORDER BY` yazılmalı. FireDAC'in `fmOnDemand`'da `IndexFieldNames` davranışı denenmedi.
- **Satır sayısı yazısı:** Sonuç tam yüklendi mi bilinmiyor; 500'ün katıysa "varsa devamı yüklenir" ibaresi eklenir.
- **Sonuç alanı yeri:** CLAUDE.md "sağ alt sonuç alanı" diyor. Sorgu sonucu ve hata, her sorgu sekmesinin kendi alt kısmında (tablo sekmesindeki gibi); ana formun altındaki kutu bağlantı mesajları için kaldı. Sekme değişince doğru sonuç görünsün diye böyle yaptım; farklı istiyorsanız söyleyin.
- **Ctrl+C:** DBGrid hücre aralığı seçemez; çoklu seçim satır bazlıdır (Ctrl+tıkla).
- **Bağlantı koparsa** açık sorgu sekmesi ilk işlemde hata verir (Aşama 1'deki sınırlama).
- Ağaç, `CREATE/DROP` sonrası kendiliğinden yenilenmez; "Yenile" gerekir.
- SynEdit'in GetIt sürümünde `SQLDialect`, `sqlInterbase6`, `Gutter.ShowLineNumbers`, `SelAvail`, `SelText` adları beklendiği gibi olmalı; farklıysa derleme hatası verir, `uEditor.pas` tek yer.
- Firebird 3.0 ve 4.0 hâlâ denenmedi.

## 4. Elle deneme listesi (Windows)

Önce SynEdit'in GetIt'ten kurulu olduğundan ve Win64 kütüphane yolunda olduğundan emin olun, sonra `Derle.bat`.

1. Açık bir bağlantı seç, **Yeni Sorgu**: `Sorgu 1 [Bağlantı]` sekmesi, SQL renkli yazılmalı. Bağlantı kapalıyken düğme soluk olmalı.
2. `select * from rdb$relations` + **F5**: satırlar gelir, üstte "N satır yüklendi". 500'den fazlaysa aşağı inince artar. Çalıştır düğmesi aynı işi yapar.
3. Metni seçip F5: yalnızca seçili kısım çalışır.
4. Izgara: başlığa tıkla (▲, tekrar ▼), zebra, NULL gri-eğik, geniş yazılar kısaltılmış, kolon genişlikleri uygun.
5. Hücre seç + Ctrl+C, Excel'e yapıştır. Ctrl+tıkla birkaç satır seç + Ctrl+C.
6. Uzun metin/BLOB hücresine çift tıkla: tam metin penceresi.
7. Hata: `selec 1` ve olmayan tablo: anlaşılır cümle + "Ayrıntı" altında ham mesaj.
8. `update tablo set x=1` (WHERE yok) ve `drop table ...`: net onay penceresi; Hayır → "Komut çalıştırılmadı". (Gerçek veride denemeyin, test veritabanında deneyin.)
9. `insert` çalıştır: "N satır etkilendi ... otomatik onaylandı". Başka sekmeden/bağlantıdan görünmeli.
10. İki sorgu sekmesi: birinde uzun sonuç açıkken diğerinde `insert`: ilk sekmenin sonucu bozulmamalı.
11. Bağlantıyı kes: o bağlantının sorgu ve tablo sekmeleri kapanmalı.
12. Dil değiştir: araç çubuğu, sekme başlığı ("Abfrage 1"), sonuç etiketi anında değişmeli.
13. Tablo sekmesinin veri ızgarasında da sıralama/zebra/NULL çalışmalı.
