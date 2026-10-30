# Görev: Aşama 3g, Tablo yapısı: kolon, index, kısıt, yeni tablo, tablo sil

**Önce `CLAUDE.md` dosyasını baştan sona oku** (Bölüm 3, 4, 6, 8 "SQL karşılığı", 9, 10, 12), sonra `GOREV_ASAMA3F.md`, `ASAMA3F_RAPOR.md` ve 3f'nin kodunu (`uNesneYonet.pas`, `fGeneratorDeger.pas`, `uProsedur.pas`, `fProsedurSekme.pas`, `fAna.pas` Yeni/Sil akışı, `uDDL.pas`, `uMetadata.pas`: `KolonlariOku`, `KisitlariOku`, `IndeksleriOku`, `BagimliNesneler`) ve `fTabloSekme.pas` oku. Tüm yanıt ve rapor Türkçe.

## Karar (sahibi, 2026-10-30)

3f'deki "küçük pencere + SQL karşılığı + net onay + yedek" kalıbı **tablo yapısı** için de kurulur. Tablo veri düzenleme (satır ekleme/güncelleme) **bu görevde YOK**. Her iş küçük bir pencere ya da şablonlu sekme olsun, tek büyük "tablo tasarımcısı" yapılmayacak (CLAUDE.md Bölüm 3: sade kod).

## Çalışma düzeni

- Yerel çalışma: GitHub'a itme yok, PR yok. `main` üstünden yeni dal `asama3g`. `main`'e birleştirme yok, `CLAUDE.md` kutularına dokunma.
- Dosya silme yok (gerekirse `_arsiv`). Yeni üçüncü parti bileşen yok. Belirsizlikte tahmin etme, sahibine sor.
- Veri değiştiren testler yalnızca atılabilir sunucularda: gömülü kip, 3.0 :3052, 4.0 :3053, 2.5 test kopyası :3054. Gerçek veri sunucularında (:3050, :3051) yazma testi **yasak**; test programı bu portlarda yazmayı kod seviyesinde reddetsin (`NesneYonetimTest`'teki koruma kalıbı). Sunucu kipini çalıştıramıyorsan "denemedim" de.
- Çalışan program `bin\...\FirebirdYonetici.exe`'yi kilitlerse programı **kapatma**, geçici klasöre derle (`/p:DCC_ExeOutput=...`).
- Sınıf bildiriminde alanlar prosedürlerden önce. Her görünen yazı `T('ANAHTAR')`, üç dil dosyası. Her alt iş kendi commit'i (3g-1 ... 3g-4), mevcut testler geçsin.

## Yapılacaklar

### 3g-1: Tablo sekmesinde yapı (yalnızca okuma) ve bağımlılıklar
1. `fTabloSekme`: kolonların yanına/altına **Index'ler** ve **Kısıtlar** (PK, UNIQUE, FK, CHECK) bölümleri; mevcut `IndeksleriOku` / `KisitlariOku` kullanılır (yeniden yazma). Sade yerleşim: sekme içinde küçük alt sekmeler ya da bölünmüş paneller, SSMS'in "Kolonlar / Index'ler / Kısıtlar" düzenine benzer.
2. Tablo sağ tık (en çok 6 madde): **İlk 100 satır**, **Yapıyı göster**, **Script üret**, **Bağımlılıklar** (yeni: bu tabloyu kullanan view/prosedür/trigger ve FK ile bağlı tablolar, `BagimliNesneler` + `RDB$REF_CONSTRAINTS`), **Yenile**; düzenleme maddeleri sonraki alt işlerde eklenir.
3. Sürüm farkı varsa yalnızca `uMetadata`'da.

### 3g-2: Kolon işleri
Tablo yapı sekmesinde kolona sağ tık / üstte düğmeler (en çok 6): **Kolon ekle**, **Adı değiştir**, **Tipi/NOT NULL/varsayılanı değiştir**, **Kolon sil**.
1. Her biri küçük pencere, alttaki **SQL önizlemesi** görünür, Kaydet = çalıştır, net onay (varsayılan Hayır), tek işlemde, başarıda `SqlMesajiYaz`, hatada anlaşılır cümle + Ayrıntı.
2. Sözdizimleri (**tahmin etme, dört sürümde dene**): `ALTER TABLE t ADD c tip`, `ALTER TABLE t ALTER COLUMN c TO yeni`, `ALTER TABLE t ALTER COLUMN c TYPE tip`, `ALTER COLUMN c SET NOT NULL / DROP NOT NULL` (2.5'te `SET NOT NULL` yoktur: sürüm farkı `uDDL/uMetadata` içinde, yoksa o sürümde düğme kapalı ve neden yazılı), `SET DEFAULT x / DROP DEFAULT`, `DROP c`.
3. **Veri kaybı riski** olan işler (kolon sil, tipi daralt, NOT NULL ekle): onay penceresinde ek uyarı ("N satırdaki veri kaybolabilir"; satır sayısı `COUNT(*)` ile gösterilir, büyük tabloda uyarı bekleme süresiyle birlikte). İşlemden önce tablonun CREATE script'i `_arsiv\<bağlantı>\tablo_ADI_yyyymmdd_hhnnss.sql` olarak yedeklenir (zorunlu; yazılamazsa işlem başlamaz). **Kolon verisi yedeklenmez**, bu onay penceresinde ve yedek dosyasının başında açıkça yazılır.
4. Kolonu kullanan index/kısıt/view/trigger/prosedür bağımlılıkları onayda listelenir (en çok 10 madde); Firebird reddederse hata anlaşılır cümleye çevrilir (gerçek hata kodu/metniyle).

### 3g-3: Index ve kısıt işleri
1. **Index:** oluştur (kolon seçimi, UNIQUE, ASC/DESC), sil, aktif/pasif yap (`ALTER INDEX ... ACTIVE|INACTIVE`).
2. **Kısıt:** ekle ve sil: PRIMARY KEY, UNIQUE, FOREIGN KEY (referans tablo ve kolon seçimi, ON DELETE/UPDATE seçenekleri), CHECK. Mevcut veri kuralı bozuyorsa Firebird'in hatası anlaşılır cümleye çevrilir.
3. Aynı pencere kalıbı: SQL önizleme, onay, `SqlMesajiYaz`. Sil: bağımlılık (örn. PK'ya bağlı FK'ler) listelenir, tablo yedeği (3g-2 kuralı).
4. İsimsiz kısıt/index adı: `RDB$` otomatik adları (`INTEG_12`, `RDB$PRIMARY5`) olduğu gibi gösterilir ve silme onayında yazılır.

### 3g-4: Yeni tablo ve tablo sil
1. **Yeni tablo:** Tablolar dalına sağ tık → şablonlu düzenleme sekmesi (`CREATE TABLE YENI_TABLO (ID INTEGER NOT NULL PRIMARY KEY, AD VARCHAR(50));`), Kaydet = çalıştır (3f-3'teki "Yeni exception/domain" akışı).
2. **Tablo sil:** sağ tıkta **Sil**. Onay penceresi: tablo adı, "geri alınamaz", **satır sayısı**, bağımlılıklar (en çok 10), yedek bilgisi; varsayılan Hayır. Silmeden önce tablo CREATE script'i `_arsiv`'e yedeklenir. **Verinin kendisi yedeklenmez** ve pencerede bu açıkça yazılır. Bağımlılık varsa Firebird reddeder, hata anlaşılır cümleye çevrilir. Onaya ek olarak **tablo adını yazdırma** kutusu (yanlışlıkla silinmesin).
3. Sağ tık menü sınırı: bir tabloda en çok 6 madde; fazlası yapı sekmesine gider.

## Ortak kurallar

- Ham Firebird hataları `HataMetniniCevir`'de üç dilde anlaşılır cümleye çevrilir; **gerçek hatayı test sunucusunda üret**, tahminle çeviri yazma. Üretemediğini raporda "üretilemedi" yaz.
- Her yönetim işleminin SQL'i `SqlMesajiYaz` ile alt alanda görünür (hatada da denenen SQL).
- Düğme/menü genişlikleri yazıya göre uzar; Almanca'da kesilmesin.
- Yeni tablo ya da kolon adları `AdHazirla` kuralıyla (3f) işlenir.

## Test

`Test\TabloYapiTest.dpr` + `...Derle.bat` (3f test kalıbı: ortam değişkenleri, çıktı dosyaya, yazma koruması 3052/3053/3054). İçerik: yapı okuma (kolon/index/kısıt) → bağımlılık listesi → kolon ekle/adını değiştir/tip değiştir/NOT NULL/varsayılan/sil (her sürümde; desteklenmeyen sürümde düğme kapalı kontrolü) → veri kaybı uyarısı satır sayısı → index oluştur/pasif/aktif/sil → kısıt ekle/sil (PK, UNIQUE, FK, CHECK; veri bozuk iken hata cümlesi) → yeni tablo → tablo sil (bağımlılıkla reddedilme, yedek dosyası içeriği, yedek yazılamayınca durma) → hata cümleleri üç dilde → arayüz duman testi. Mevcut tüm testler (Prosedür, Trigger, Nesne Yönetim, Kullanıcı, DDL, Aktar, Şerit, Sorgu, Yedek) hâlâ geçsin. Gömülü kipte derle/çalıştır; **denemediğini "denemedim" diye yaz.**

## Rapor

`ASAMA3G_RAPOR.md` (Türkçe, kısa): ne değişti (dosya/satır), her alt işin durumu, hangi sürümde hangi sözdizimi (özellikle NOT NULL, tip değiştirme) ve neden, yedek yerleri, sunucu testi için PowerShell komutları, denenenler/denenmeyenler, bilinen sınırlar, öneriler, sahibine arayüz deneme listesi.

## Bitiş ölçütü

Tablo sekmesinde kolon, index ve kısıtlar görünür; kolon/index/kısıt eklenip değiştirilip silinebilir; yeni tablo oluşturulup silinebilir; veri kaybı riskli işler satır sayısı ve net onayla gelir, tablo CREATE yedeği alınır; hatalar üç dilde anlaşılır; SQL karşılıkları alt alanda görünür; mevcut testler ve yeni test dört sürümde geçer. **Sahibi onaylamadan sonraki işe (3d-2/3d-3 yetkiler) geçilmez.**
