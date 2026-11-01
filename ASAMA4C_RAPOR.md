# Aşama 4c Raporu: Önizlemeli Toplu Güncelleme

Tarih: 2026-11-01. Dal: `asama4c`.

## Ne yapıldı
- Şeritte Sorgu sekmesine **Toplu Güncelle** düğmesi. Tek sekme açılır (Çoklu Sorgu gibi: solda kutucuklu veritabanı listesi, sağda editör).
- Akış: tek bir `UPDATE` yaz, veritabanlarını işaretle, **Önizle** (F5), sonra **Uygula**.
- **Önizle:** Komut her veritabanında kendi işlemi (transaction) içinde çalıştırılır, etkilenen satır sayısı alınır ve işlem **geri alınır**; veri değişmez. Özet satırı "hiçbir veri değişmedi, uygularsanız toplam N satır değişecek" der.
- **Uygula:** Önce acık bir **onay penceresi**: komutun kendisi, her veritabanında kaç satır değişeceği, toplam ve "geri alınamaz" uyarısı. Komutta `WHERE` yoksa ayrıca büyük uyarı ("tablonun TÜM satırları değişecek").
- Uygula ancak şu koşullarda çalışır: önizleme yapılmış, komut ve veritabanı seçimi önizlemeyle aynı, önizlemede hata yok. Aksi halde anlaşılır bir cümleyle "önce önizleyin" der. Uygulandıktan sonra yeniden önizleme gerekir (aynı komut yanlışlıkla ikinci kez çalışmasın).
- Her veritabanı kendi işleminde uygulanır ve onaylanır; birinde hata olursa o geri alınır, diğerleri etkilenmez. Hata kırmızı, atlanan (şifresi kayıtlı olmayan kapalı bağlantı) gri görünür.
- Yalnızca `UPDATE` kabul edilir (SELECT için Çoklu Sorgu; INSERT/DELETE/DDL yok, basitlik ve güvenlik için).
- Çalışan komut ve hatalar (SQL karşılığı) alt mesaj alanına yazılır.
- Açık bağlantı varsa onu kendi ayrı işlemiyle kullanır (açık sekmelerin işlemine karışmaz); yoksa kayıtlı şifreyle geçici bağlanır ve kapatır.
- Kod: `uTopluGuncelle.pas` (mantık), `fTopluGuncelle.pas/.dfm` (ince form), `fAna.pas` (düğme ve sekme), `uCokluSorgu.pas` (`IlkSozcuk` ortak oldu). Üç dilde 15 yeni anahtar (her dilde 682).

## Ne test edildi
`Test\TopluGuncelleTest.dpr` (yerleşik motor, Firebird 5.0.4): 36 kontrol, 0 hata.
Kapsam: komut denetimi (UPDATE kabul; SELECT/DELETE/DROP/iki komut/boş red), WHERE tanıma (yorumda ve yazı içinde geçen sayılmaz), önizlemede sayılar doğru ve veri değişmiyor, tablosu olmayan veritabanında anlaşılır hata ve diğerleri etkilenmiyor, şifresiz bağlantı atlanıyor, uygulamada veri değişiyor ve sayılar önizlemeyle aynı, hatalı veritabanı varken diğeri uygulanıyor, WHERE'siz tüm satırlar sayılıyor ama önizleme veriyi değiştirmiyor, ilerleme bildirimi, dil anahtarları (tr/en/de), sekmenin dfm'i hatasız oluşuyor.

## Eksik / görülmedi
- Arayüz (Önizle/Uygula düğmeleri, onay penceresi) gözle denenmedi; yalnızca sekmenin hatasız oluştuğu test edildi.
- Firebird 2.5, 3.0 ve 4.0 ile denenmedi.
- Önizleme tetikleyicilerin **dış etkilerini** (generator değeri, dış dosya, UDF) geri alamaz; veri satırları geri alınır. Onay metnine bu not eklenmedi (istenirse eklenir).
- Uygula sırasında bir veritabanı hata verirse diğerleri uygulanır (hepsi-ya-hiç değil). Sebep: veritabanları ayrı dosyalardır, ortak işlem yoktur. Önizleme hatasızsa bu durum nadirdir.
