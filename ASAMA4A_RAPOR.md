# Aşama 4a Raporu: Çoklu Sorgu (birden çok veritabanında SELECT)

Tarih: 2026-10-31. Dal: `asama4`.

## Ne yapıldı
- Şeritte Sorgu sekmesine **Çoklu Sorgu** düğmesi. Tek sekme açılır.
- Solda kayıtlı bağlantılar onay kutularıyla listelenir (Hepsini seç / Hiçbirini seçme). Şifresi kayıtlı olmayan ve açık olmayan bağlantı pasif görünür.
- Ortada tek bir SELECT (veya WITH) yazılır, F5 ile seçilen tüm veritabanlarında çalışır.
- Sonuçlar tek tabloda birleşir, ilk kolon `VERITABANI`. Veritabanı başına durum listesi: Tamam / Hata (kırmızı) / Atlandı (gri), satır sayısı, süre.
- Bir veritabanında hata olması diğerlerini durdurmaz. Hata cümlesi anlaşılır, ayrıntı alt alanda.
- Güvenlik: yalnızca tek SELECT/WITH kabul edilir (UPDATE, DELETE, DROP, birden çok komut reddedilir).
- Sonuç sınırı: toplam 5000 satır, aşılırsa uyarı yazılır.
- Kod: `uCokluSorgu.pas` (mantık), `fCokluSorgu.pas/.dfm` (ince form), `uBaglanti.pas` (`BaglantiKur`, `FbGeciciBaglan`: ağaçta görünmeyen geçici bağlantı), 3 dil dosyasında 20 yeni anahtar (her dilde 620 anahtar).

## Ne test edildi
`Test\CokluSorguTest.dpr`: yerleşik motorda 31/0, sunucuda (3053 Firebird 4, 3054 Firebird 5) 33/0.
Kapsam: sorgu denetimi, üç veritabanı, eksik tablo hatası, kayıtlı şifre olmayan bağlantı, açık bağlantıyı yeniden kullanma, 5000 satır sınırı, dil anahtarları, WIN1254 veritabanında Türkçe harfler.

## Bulgu (önemli, ayrı iş): WIN1251 bağlantıda Kiril harfler bozuk geliyor
Ölçüm: WIN1251 veritabanına doğru baytlarla (CF F0 E8 E2 E5 F2) yazılan "Привет", FireDAC `CharacterSet=WIN1251` bağlantısıyla okununca WIN1254 gibi çözülüyor (Ï ğ è…). Aynı veri `CharacterSet=UTF8` bağlantısıyla doğru geliyor. Yani veri sunucuda sağlam, sorun FireDAC'ın WIN1251 çözümlemesinde. Çoklu sorguya özgü değil, uygulamanın her yerini etkiler (Windows'un varsayılan kod sayfası 1254 olduğu için WIN1254 veritabanlarında fark edilmez).
Sahibi gerçek veritabanında (FABRIKA 2026, WIN1251 tanımlı, Firebird 2.5.9) denedi: Türkçe harfler bizde ve IBExpert'te aynı, doğru görünüyor. Karar (2026-10-31): düzeltme yapılmaz, bilinen sınır olarak kalır; tanıtım sayfasına "Kiril test edilmedi, test eden yazsın" notu konur (CLAUDE.md Aşama 6).
(Yapılmamış olası çözüm:) veritabanı karakter seti NONE değilse UTF8 ile bağlanmak (sunucu çevirir). Etkisi geniş olduğu için sahibine sorulmadan yapılmadı. Testte bu kontrol çıkarıldı, yerine not düşüldü.

## Eksik / görülmedi
- Arayüz (çoklu sorgu sekmesi) gözle denenmedi, yalnızca dfm'nin hatasız oluştuğu test edildi.
- Firebird 2.5 ve 3.0 sunucusunda çalıştırılmadı (3052 yerleşik motorda denendi).
- 4b (şema karşılaştırma) ve 4c (önizlemeli toplu güncelleme) başlamadı.
- `bin\Win64\Release\FirebirdYonetici.exe` yeniden derlendi (Derle.bat).
