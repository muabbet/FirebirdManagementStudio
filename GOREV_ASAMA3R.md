# Görev: Gruplu şerit (ribbon), üçüncü parti bileşensiz

Bu görev, **Delphi/RAD Studio 12 olan makinede** çalışan ajan içindir. **Önce `CLAUDE.md` dosyasını baştan sona oku** (Bölüm 3, 5, 6, 8, 12 özellikle). Tüm yanıt ve rapor Türkçe.

## Karar (sahibi, 2026-10-18)

Üstteki tek `TToolBar` (`tbAna`, 7 düğme) yerine, Office benzeri **gruplu bir şerit** yapılacak: büyük ikon üstte, yazı altta, her grubun altında küçük grup adı. Sahibinin örnek ekran görüntüsü: tek sekme ("Ana Menü"), gruplar arasında ince dikey çizgi, grup adı altta ortada. **Bileşen eklenmeyecek** (Bölüm 5): Delphi'nin `Vcl.Ribbon`'u da, üçüncü parti de kullanılmayacak. Yalnızca standart VCL: `TPanel`, `TLabel`, `TSpeedButton` (veya `TButton`), `TImageList`/`TBitmap`, `TBevel`/`TShape`.

## Çalışma düzeni

- Yerel çalışma: GitHub'a itme yok, PR yok. `main` (güncel) üstünden yeni dal: `asama3r-ribbon`. `main`'e birleştirme, `CLAUDE.md` kutularına dokunma (Bölüm 8 metni zaten güncellendi).
- Dosya silme yok (gerekirse `_arsiv`). Yeni üçüncü parti bileşen yok. Belirsizlikte tahmin etme, sahibine sor.
- Sınıf bildiriminde alanlar prosedürlerden önce. Düğmenin `OnClick`'i işi yapan yordamı doğrudan çağırsın; boş olay yöneticisi bırakma. Bütün yazılar `T('ANAHTAR')`, üç dil dosyası (tr, en, de) güncellenir.

## Yapılacaklar

1. **Yeni unit `Kaynak\uSerit.pas`** (adı `uRibbon.pas` da olabilir, sahibine sor, varsayılan `uSerit`): şeridi **kod ile** kurar. Bir `TPanel` içine gruplar dizilir; grup = `TPanel` + içindeki düğmeler + altta grup adı `TLabel`. Düğme listesi tek yerde okunabilsin (ör. bir dizi: grup anahtarı, düğme anahtarı, ikon, tıklama yordamı). Form (`fAna`) yalnızca `SeritKur(...)` çağırır ve düğme olaylarını bağlar; şerit mantığı unit'te.
2. **Gruplar ve düğmeler** (mevcut düğmelerin yeri değişir, **davranışları aynen kalır**, yeni özellik yok):
   - **Bağlantı:** Yeni Bağlantı, Klonla, Bağlantıyı Kes, Yenile (mevcut `btnYeniBaglanti`, `btnKlonla`, `btnBaglan`, `btnYenile` ile aynı yordamlar).
   - **Sorgu:** Yeni Sorgu, Çalıştır (F5), Plan (Ctrl+L).
   - **Yönetim:** Metadata çıkar, Yedekle / Geri yükle (şu an yalnızca sağ tık menüsünde; şeritte de tek tıkla olsun, aynı yordamı çağırsın, sağ tık menüsü kalsın, Bölüm 8: en fazla 5-6 seçenek).
   - Her düğme, ağaçta/sekmede uygun olmadığında **pasif** olur (mevcut `Enabled` mantığını koru, ayrı bir yere kopyalama; mevcut durum güncelleme yordamı şeridi de güncellesin).
3. **Görünüm:** Büyük ikon (32 px civarı, `Ikonlar` klasöründeki mevcut ikonların büyüğü yoksa `Ikonlar\svg` kaynağından üret; yeni ikon seti çizme, mevcutları kullan; eksik ikon varsa sahibine söyle, geçici olarak aynı ikonu kullan), yazı ikonun altında, **düğme genişliği yazıya göre uzar** (Almanca kesilmesin, Bölüm 6.5), pasif düğme soluk. Üzerine gelince ve basılınca görsel geri bildirim. Grup adı küçük ve gri, altta ortada; gruplar arası ince dikey çizgi. VCL Style (açık tema) ile uyumlu: renkleri `StyleServices`'ten al, sabit renk yazma.
4. **Dil değişince** şerit yazıları anında değişir (program yeniden başlamaz). Grup adları dahil.
5. **Eski araç çubuğu** (`tbAna`, `ilAna` vb.): artık kullanılmayan bileşenleri formdan **kaldır** (dosya silme değil, bileşen kaldırma), ama `.dfm` bozulmasın; `Derle.bat` hatasız, uyarısız derlesin. Klavye kısayolları (F5, Ctrl+L) çalışmaya devam etsin.
6. **Daraltma / küçük pencere:** ilk sürümde yok (sahibi bilir). Pencere dar olursa şerit yatay kaydırma gerektirmesin diye yalnızca Almanca'da bile makul genişlikte kalındığını kontrol et; sığmıyorsa raporda yaz.
7. **Test:** `Derle.bat` ile derle, programı aç. Sunucuda veri değiştiren bir şey yapma. Denemen gerekenler: her düğme eskisi gibi çalışıyor mu, pasif/aktif durumlar doğru mu, dil değişimi, Almanca genişlikleri, 100% ve 125% ekran ölçeği (mümkünse). **Denemediğini "denemedim" diye açıkça yaz.** Mevcut testler (`MetadataTest`, `SorguTest`, `DDLTest`, `AktarTest`, `YedekTest` gömülü kipte) hâlâ geçmeli.
8. **Rapor:** `ASAMA3R_RIBBON_RAPOR.md` (Türkçe, kısa): ne değişti (dosya, satır), düğme eşleme tablosu (eski → yeni grup), denenenler/denenmeyenler, eksik ikonlar, sahibine arayüz deneme listesi.

## Bitiş ölçütü

Program açılınca üstte üç gruplu şerit görünür, her düğme eski işini yapar, Türkçe/İngilizce/Almanca'da yazılar kesilmez, dil anında değişir, hiçbir üçüncü parti bileşen eklenmemiştir. **Sahibi onaylamadan sonraki işe (3d) geçilmez.**
