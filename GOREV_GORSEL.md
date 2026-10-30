# Görev: Görsel düzeltme (SSMS gibi muntazam ızgara, editör ve durum çubuğu)

**Önce `CLAUDE.md` dosyasını baştan sona oku** (Bölüm 3, 6, 7, 8, 12), sonra `Referans\ssms.png` dosyasına bak (SSMS'in sonuç ızgarası, editörü, durum çubuğu), sonra `Kaynak\uSonucGrid.pas`, `Kaynak\uEditor.pas`, `Kaynak\fSorguSekme.pas/.dfm`, `Kaynak\fTabloSekme.pas/.dfm`, `Kaynak\fAna.pas/.dfm` (alt durum çubuğu) oku. Tüm yanıt ve rapor Türkçe.

## Karar (sahibi, 2026-10-29/30)

SSMS'in ızgara ve yazı düzeni çok muntazam; bizim program aynı düzene yaklaşsın. **Yalnızca görünüm:** işlev, SQL, veritabanı davranışı, menüler değişmez. Yeni üçüncü parti bileşen yok, standart `TDBGrid` ve `TSynEdit` kalır (CLAUDE.md Bölüm 5 ve 7).

## Çalışma düzeni

- Yerel çalışma: GitHub'a itme yok, PR yok. `main` üstünden yeni dal `gorsel`. `main`'e birleştirme yok, `CLAUDE.md` kutularına dokunma, sahibi onaylayınca mimar birleştirir.
- Dosya silme yok (gerekirse `_arsiv`). Belirsizlikte tahmin etme, sahibine sor.
- Sınıf bildiriminde alanlar prosedürlerden önce. Her görünen yazı `T('ANAHTAR')`, yeni yazı varsa üç dil dosyası.
- Her alt iş kendi commit'i (g-1 ... g-4). Commit mesajı sonuna `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.
- Sahibinin çalışan programı `bin\Win64\Release\FirebirdYonetici.exe`'yi kilitleyebilir: derleme "erişim reddedildi" derse programı **kapatma**, geçici çıktı klasörüne derle (`/p:DCC_ExeOutput=...`) ve raporda belirt.

## Yapılacaklar

### g-1: Sonuç ızgarası (`uSonucGrid.pas`, hem sorgu sonucu hem tablo "İlk satırlar")
Hedef `Referans\ssms.png`:
1. **Hücre çizgileri:** ince, açık gri (SSMS gibi), `dgRowLines` ve `dgColLines` açık. Şu an çizgi yok.
2. **Satır yüksekliği** yaklaşık 20-22 px, yazı Segoe UI 9 (sonuç ızgarasında). Şu an satırlar çok yüksek, ekrana az satır sığıyor. DPI büyütmede (125-150%) kesilmesin: yüksekliği yazı ölçüsünden hesapla, sabit piksel verme.
3. **Başlık:** açık gri zemin, yazı normal ağırlık (kalın değil), altında ince çizgi. Sıralama oku (1. özellik) çalışmaya devam etsin.
4. **Satır numarası sütunu:** solda başlıkla aynı gri tonda, 1'den başlar, sıralamadan bağımsız olarak ekranda görünen sıra. Mevcut `dgIndicator` oku ile çakışmasın (ok kalır ya da numaraya taşınır, sade olanı seç, raporda yaz).
5. **Seçili hücre** yumuşak mavi zemin; tüm satır koyu mavi olmasın. Çoklu seçim (Ctrl+C) boyaması aynı tonda.
6. **Hizalama:** SSMS her şeyi sola hizalıyor. Sayıları sola hizala, ama **tek yerde değiştirilebilir** yap (ör. tek sabit/yordam), çünkü bu zevk meselesi: raporda sahibine soru olarak yaz.
7. **Zebra** kalsın ama çizgilerle birlikte çok hafif (CLAUDE.md Bölüm 7 madde 2). **NULL gri ve eğik** kalsın (CLAUDE.md madde 3; SSMS'in yeni sürümü sarı zemin kullanıyor, sahibi karar verirse değişir, bu görevde değişmez; raporda "sarı zemin istenirse tek satır" diye yaz).
8. Mevcut altı özellik (sıralama, zebra, NULL, otomatik genişlik, Ctrl+C, BLOB kısaltma/çift tık) **aynen** çalışsın.

### g-2: Editör (`uEditor.pas`) ve editör altı durum satırı
1. Editörün altında ince durum satırı: `Sat: N, Krkt: M` (imleç), `CRLF`/`LF`, `UTF-8` (dosya kodlaması yoksa bu iki bilgiyi gösterme, uydurma), yakınlaştırma yüzdesi yok (bu görevde yakınlaştırma eklenmez). Yazılar `T()`.
2. Satır numarası kenarlığı (gutter) renkleri SSMS gibi: açık gri zemin, gri numara. Aktif satır hafif vurgulu.
3. Yazı tipi Consolas 11 kalsın ya da SSMS'e yakın bir boy; **karar:** değiştirme, yalnızca satır aralığı ve renkler. (Editör zaten okunaklı.)
4. Hatalı satır işareti (3e/3f'te eklendi, kırmızı zemin) bozulmasın.

### g-3: Alt durum çubuğu (`fAna.pas`)
Şu an ana formun altındaki durum çubuğunda yazı kesilmiş görünüyor ("Select a connection in the tree"). SSMS'teki gibi: sol tarafta mesaj, sağda sırayla **sunucu sürümü, bağlantı adı, veritabanı, işlem durumu (açık/kapalı), son sorgu süresi, satır sayısı**. Bu bilgiler zaten programda var (sürüm, işlem durumu); yeni sorgu yapma, yalnızca göster. Yazı kesilmesin, panel genişlikleri yazıya göre (Almanca da).

### g-4: Küçük düzen
1. Ağaçta satır aralığı ve +/- işaretleri SSMS'e yakın ve okunaklı olsun (cömert boşluk, CLAUDE.md Bölüm 8 "Görsel").
2. Sonuç alanında "Sonuçlar" / "İletiler" sekmeleri **yok**, bunlar yeni özellik; bu görevde ekleme. Yalnızca mevcut alt mesaj alanının yazı tipi/boşluğu ızgarayla uyumlu olsun.
3. Sorgu sekmesi ve tablo sekmesinin ızgara kenar boşlukları aynı olsun.

## Test

- Mevcut tüm testler (Prosedür, Trigger, Nesne Yönetim, Kullanıcı, DDL, Aktar, Şerit, Sorgu, Yedek) hâlâ geçsin; gömülü kipte koş.
- Izgara için: sorgu sonucu (sayı, metin, tarih, NULL, BLOB, 5000 satır), tablo "İlk satırlar", Ctrl+C yapıştırma, sıralama, boş sonuç. **DPI 100%, 125%, 150%** ve dil Türkçe/İngilizce/Almanca için ekran görüntüsü al (`Referans\Yeni\` klasörüne, SSMS örneğiyle yan yana karşılaştırılabilsin). Arayüzü elle denemediğini "denemedim" diye yaz.

## Rapor

`GORSEL_RAPOR.md` (Türkçe, kısa): ne değişti (dosya/satır), her alt işin durumu, SSMS'ten bilerek ayrılan yerler ve nedeni, sahibine sorular (sayı hizası sola mı sağa mı, NULL gri eğik mi sarı zemin mi), denenenler/denenmeyenler, bilinen sınırlar, sahibine arayüz deneme listesi.

## Bitiş ölçütü

Sorgu sonucu ve tablo satırları `Referans\ssms.png` ile yan yana konunca aynı düzende görünür: ince çizgiler, dar satırlar, gri başlık, satır numarası, yumuşak mavi seçim; durum çubuğu kesilmeden sürüm, bağlantı, işlem durumu, süre ve satır sayısını gösterir; mevcut işlevler ve testler bozulmamıştır. **Sahibi onaylamadan sonraki işe geçilmez.**
