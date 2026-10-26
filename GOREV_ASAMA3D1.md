# Görev: Aşama 3d-1, Kullanıcılar (liste, ekle, sil, şifre değiştir)

Bu görev, **Delphi/RAD Studio 12 olan makinede** çalışan ajan içindir. **Önce `CLAUDE.md` dosyasını baştan sona oku** (Bölüm 3, 4, 5, 6, 8, 9, 10, 12 özellikle), sonra `ASAMA3D_OLCUM_RAPORU.md` ve `Olcum\kullaniciolcum_*.txt` dosyalarını oku (2.5.9, 3.0.14, 4.0.7, 5.0.4 gerçek sunucu ölçümleri). Tüm yanıt ve rapor Türkçe.

## Çalışma düzeni

- Yerel çalışma: GitHub'a itme yok, PR yok. `main` (güncel) üstünden yeni dal `asama3d-1`. `main`'e birleştirme yok, `CLAUDE.md` kutularına dokunma (3d'nin kutusu 3d-3'e kadar açık kalır).
- Dosya silme yok (gerekirse `_arsiv`). Yeni üçüncü parti bileşen yok (`TFDIBSecurity` FireDAC'ın parçasıdır, serbest). Belirsizlikte tahmin etme, sahibine sor.
- **Gerçek veri içeren sunucularda (2.5.9 :3050, 5.0.4 :3051) yazma testi YASAK.** Yazan testler yalnızca atılabilir sunucularda (3.0 :3052, 4.0 :3053, 2.5 test kopyası :3054) çalışsın; test programı bu port listesinin dışında yazmayı kod seviyesinde reddetsin (`Test\KullaniciOlcum.dpr`'deki korumanın aynısı, 3054 eklenmiş). Şifre dosyaya yazılmaz, ortam değişkeniyle verilir. Sunucu kipini sen çalıştıramazsın (şifre sende yok): "gömülü kipte denendi, sunucuyu sahibi deneyecek" diye yaz, "çalışıyor" deme.

## Sahibinin kararları (2026-10-26)

- **SYSDBA** listede görünür, yalnızca **şifresi değiştirilebilir**. Silinemez, pasif yapılamaz, yönetici bayrağı değiştirilemez. Bu, arayüzde menü maddelerinin kapalı olmasıyla **ve** `uKullanici.pas` fonksiyonlarının kendisinin reddetmesiyle sağlanır (arayüz atlatılsa bile SYSDBA silinmesin).
- Diğer kullanıcılar eklenir, silinir, şifre/ad/soyad değiştirilir, yönetici yapılır/kaldırılır (3.0+), aktif/pasif yapılır (3.0+).
- Bu dilimde yok: etiket (TAGS), eklenti seçimi (`USING PLUGIN`), Windows eşlemesi, yetki işlemleri (GRANT/REVOKE: 3d-2 ve 3d-3).
- "Şifremi değiştir" için **ayrı düğme yok**: listede kullanıcıya sağ tık, "Şifre değiştir" (tek yol). Yönetici olmayan kullanıcı listede yalnızca kendi satırını görür, aynı menü işini görür.
- Değiştirilen şifre, **bağlantının kendi kullanıcısına** aitse ve kayıtlı bağlantıda şifre saklanıyorsa: başarılı değişiklikten sonra "Kayıtlı bağlantı şifresi de güncellensin mi?" sorulur (Evet: DPAPI'li kayıt güncellenir). Açık bağlantı etkilenmez.
- Şifre kuralı: boş olamaz, iki kez girilir, aynı olmalı. **Alt uzunluk sınırı yok** (sahibi 6 haneli şifre kullanıyor). 20 bayttan uzunsa uyarı ("Firebird bu şifrenin yalnızca ilk 20 baytını kullanır", Srp için; sürüme göre kısa not).

## Yapılacaklar

1. **`uMetadata.pas` (salt okuma, sürüme bağlı):** `KullaniciListesiOku(Bag)` → kayıt listesi (ad, ad, orta ad, soyad, yönetici mi, aktif mi, "yönetici/aktif bilgisi var mı"). 3.0+: `SEC$USERS`; 2.5: `TFDIBSecurity.DisplayUsers` (yönetici/aktif bilgisi yok, 2.5'te sütun gösterilmez). Ayrıca küçük bir **yetenek** fonksiyonu (`KullaniciYetenekleri(Bag)`): liste SQL ile mi, aktif/pasif var mı, yönetici bayrağı okunuyor mu, kendi şifre komutu hangisi. Form yalnızca bu yeteneklere bakar, sürüm numarası bilmez (Bölüm 9).
2. **Yeni `Kaynak\uKullanici.pas` (yazma):** `KullaniciEkle`, `KullaniciSil`, `SifreDegistir`, `AdSoyadDegistir`, `YoneticiAyarla`, `AktifAyarla`. 3.0+ ve 2.5'te SQL: `CREATE USER`, `ALTER USER ... PASSWORD`, `DROP USER`, `ALTER USER ... GRANT/REVOKE ADMIN ROLE`, `ACTIVE/INACTIVE` (3.0+). Kendi şifresini değiştirme (bağlı kullanıcı = değiştirilen kullanıcı): 3.0+ `ALTER CURRENT USER SET PASSWORD`, 2.5 `ALTER USER kendi_adı PASSWORD` (ölçümde ikisi de çalıştı; 2.5'te gerçek sunucuda yazma yok, test kopyasında denenecek). Kurallar:
   - **Metin kaçırma tek yerde:** şifre ve adlardaki `'` iki katına çıkar. FireDAC komutunda `:ad`, `&makro`, `!makro` yanlış yorumlanmasın (komutun `ResourceOptions.ParamCreate/MacroCreate` kapalı) ve bunu testle kanıtla: şifrede `'`, `:`, `&`, `!`, boşluk, Türkçe harf varken ekle + bağlan.
   - **Kullanıcı adı doğrulaması:** yalnızca `A-Z a-z 0-9 _ $`, en çok 31 karakter (2.5 sınırı), büyük harfe çevrilir, boş olamaz. Tırnaklı/özel adlar bu sürümde yok. SYSDBA'yı silme/pasif/yönetici değiştirme çağrıları istisna fırlatır.
   - **Önizleme/log:** şifre hiçbir zaman log'a, "Ayrıntı" bölümüne veya ekrana düz yazılmaz (`***`).
   - 2.5 listeleme için Services API, ama yazma için Services **kullanma** (ölçümde yazma kısmı sorunlu çıktı: `TFDIBSecurity` ile AddUser "kullanıcı/şifre tanımsız" verdi); 3.0+ ve 2.5 yazma SQL'dir.
3. **Yeni `Kaynak\fKullanicilar.pas/.dfm` (sekme):** diğer sekmeler gibi (fTabloSekme kalıbı). Üstte bilgi satırı: "Bu liste veritabanının değil, sunucunun kullanıcılarıdır." Altta ızgara: Kullanıcı adı, Ad, Soyad, Yönetici (varsa), Aktif (varsa). Üstte bir düğme "Yeni kullanıcı". **Sağ tık en çok 6 madde:** Şifre değiştir, Ad/soyad düzenle, Yönetici yap/kaldır (3.0+), Aktif/Pasif yap (3.0+), Yenile, Sil. SYSDBA satırında yalnızca "Şifre değiştir" ve "Yenile" etkin. Her bağlantı için tek "Kullanıcılar" sekmesi (ikinci tıklamada mevcut sekme öne gelir). Sekme başlığı "Kullanıcılar (bağlantı adı)".
4. **Yeni `Kaynak\fKullaniciDuzenle.pas/.dfm`:** küçük pencere, yalnızca alanları toplar (ekleme: ad, şifre, şifre tekrar, ad, soyad, yönetici kutusu (3.0+); şifre değiştirme: yeni şifre iki kez; ad/soyad düzenleme). Form ince, iş `uKullanici`'de, düğmenin `OnClick`'i doğrudan yordamı çağırır. Boş olay yöneticisi yok.
5. **Şerit (`uSerit.pas`, `fAna.pas`):** "Yönetim" sekmesine **tek düğme "Kullanıcılar"**. Etkin: seçili bağlantı **açık ve sunucu kipinde** (gömülü bağlantıda kapalı; tıklanamaz, gerekçe araç ipucunda/durum satırında "Gömülü bağlantıda kullanıcı yönetimi yok"). Yeni ikon çizme: `Ikonlar\svg` içinde kullanıcı ikonu varsa PNG'ye çevir, yoksa mevcut bir ikonu geçici kullan ve raporda sahibine bildir. Ağaç sağ tık menüsüne **ekleme yok** (menü zaten kalabalık, tek yol ilkesi).
6. **Onaylar (Bölüm 10), net ve ne olacağını yazan pencereler:**
   - Sil: "`ADI` kullanıcısı sunucudan silinecek. Bu kullanıcı hiçbir veritabanına bağlanamaz. Verilmiş yetkiler (GRANT) sahipsiz kalır. Geri alınamaz." Evet/Hayır, varsayılan düğme Hayır.
   - Yönetici yap: "Bu kullanıcı sunucunun tüm kullanıcılarını yönetebilir."
   - Pasif yap: "Bu kullanıcı bağlanamaz hale gelir (silinmez)."
   - Kendi kendini silme/pasif yapma: engelle (açık cümleyle).
7. **Hata cümleleri (Bölüm 6.7) `uBaglanti.HataMetniniCevir` içinde, üç dil:** `no permission for ... access` (335544352) "Bu işlem için yetkiniz yok"; `record not found for user` (336723990) "Kullanıcı bulunamadı (ya da yalnızca yönetici başkalarını görebilir)"; `add record error` + `PLG$SRP_VIEW` (336723987) "Kullanıcı yönetmek için SYSDBA ya da yönetici olmalısınız"; "kullanıcı zaten var" hatasını **test sunucusunda üretip** gerçek kodunu ve mesajını bul, onu da çevir (tahmin etme). Ham mesaj "Ayrıntı"da kalır.
8. **Dil dosyaları:** `tr.json`, `en.json`, `de.json` üçü birden (düğme, sekme başlığı, sütunlar, menü, pencereler, onaylar, hatalar). Düğme/pencere genişlikleri yazıya göre uzar, Almanca kesilmesin.
9. **Test:** `Test\KullaniciTest.dpr` + `KullaniciTestDerle.bat` (mevcut test kalıbı: `FBTEST_SUNUCU/PORT/YOL/KULLANICI/SIFRE/CIKTI`, çıktı dosyaya, hata sayısı sonda). İçeriği: ekle→listede görünür→ilk şifreyle bağlanır; şifre değiştir→eski şifre bağlanamaz, yeni bağlanır; kendi şifresini değiştir; ad/soyad; yönetici yap/kaldır (3.0+); pasif/aktif (3.0+, pasif bağlanamaz); sil→listeden gider; **SYSDBA silme/pasif/yönetici reddi**; özel karakterli şifre; yönetici olmayan kullanıcıyla ekleme/silme denemesi → doğru anlaşılır hata; `HataMetniniCevir` yeni cümleleri; gömülü kipte "kullanıcı yönetimi yok" davranışı. Yazan bölüm yalnızca 3052, 3053, 3054 portlarında çalışır, başka portta (3050, 3051 dahil) kod seviyesinde reddedilir, ama **okuma** (liste) her sunucuda çalışır.
10. **Gömülü kipte** derle/çalıştır (DDL/Aktar/Yedek/Serit testleri hâlâ geçmeli), gerçek arayüzü açıp elle dene; **denemediğini "denemedim" diye yaz**.
11. **Rapor:** `ASAMA3D1_RAPOR.md` (Türkçe, kısa): ne değişti (dosya/satır), birim bölünmesi, ekran, sunucu testi için sahibine PowerShell komutları (2.5 test kopyası :3054, 3.0 :3052, 4.0 :3053; `$env:FBTEST_...` biçimi), denenenler/denenmeyenler, sahibine arayüz deneme listesi. Commit mesajlarının sonuna `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>` ekle.

## Bitiş ölçütü

Sunucu bağlantısında "Kullanıcılar" düğmesiyle sunucunun kullanıcıları listelenir; yeni kullanıcı eklenir, şifresi değiştirilir, silinir; SYSDBA yalnızca şifre değiştirilebilir; gömülü bağlantıda düğme kapalı; hata mesajları üç dilde anlaşılır; testler 3.0, 4.0 ve 2.5 test kopyasında hatasız. **Sahibi onaylamadan 3d-2'ye geçilmez.**
