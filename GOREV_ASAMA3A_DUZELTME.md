# Görev: Aşama 3a düzeltmeleri (küçük)

Bu görev, **Delphi/RAD Studio 12 olan makinedeki** ajan içindir. `asama3a` dalı (8d8ad3b) sahibi tarafından incelendi, büyük sorun yok. Aşağıdaki iki küçük iş yapılacak. **Aynı dalda (`asama3a`) devam et**, yeni dal açma, `main`'e yazma. Önce `CLAUDE.md`'yi oku (özellikle Bölüm 3, 6, 8). Tüm yanıt ve rapor Türkçe. Dosya silme yok. Yeni bileşen yok. 3b'ye **geçme**.

## 1. Araç çubuğuna "Klonla" düğmesi (sahibi kararı)

**Neden:** Önceki görev belgesinde "araç çubuğundaki Klonla düğmesi kalır" yazıyordu ama böyle bir düğme hiç yokmuş (belge hatası). Sağ tık menüsünden Klonla çıkarılınca bağlantıyı klonlamanın arayüzde yolu kalmadı. Sahibi: **araç çubuğuna "Klonla" düğmesi eklensin.**

**Yapılacak (`fAna.dfm` / `fAna.pas`):**
- `tbAna` araç çubuğuna `btnKlonla: TToolButton` ekle. Yerleşim: `btnYeniBaglanti`'dan hemen sonra (Yeni Bağlantı, Klonla, Bağlan, ...). Simge: `IKON_KLONLA` (`uIkon.pas`'te zaten var, `ImageIndex` 9, "copy" ikonu). Diğer düğmelerle aynı biçim (`ShowCaptions` açık).
- `OnClick` → `btnKlonlaClick` → doğrudan `YeniBaglanti(OgeAl(SeciliBaglantiDugmesi).BaglantiAd)` çağıran **kısa** yordam (eski `miKlonlaClick`'in yaptığı iş; `SeciliBaglantiDugmesi = nil` ise hiçbir şey yapmaz). Boş olay yöneticisi bırakma, sınıf bildiriminde alanlar prosedürlerden önce.
- **Etkin/pasif:** ağaçta bir **bağlantı** düğümü seçiliyken etkin, başka düğümde (klasör, tablo vb.) veya hiç seçim yokken pasif. Mevcut düğme etkinlik güncellemesinin yapıldığı yere (`btnYenile.Enabled := Bag <> nil` satırlarının bulunduğu yordam) ekle; yeni mantık/yeni yordam icat etme. Bağlantının açık olması şart değil (klon, kayıtlı tanımı kopyalar).
- Başlık `T('BTN_KLONLA')`: **yeni anahtar** (tr: "Klonla", en: "Clone", de: "Klonen"), üç dil dosyasına eklenir; `YazilariYaz`/dil değişimi yordamında `btnKlonla.Caption := T('BTN_KLONLA')`. Mevcut `MENU_KLONLA` anahtarı artık kullanılmıyorsa dil dosyalarında **bırak** (silme yok, zararsız); ama `miKlonla` ile ilgili kalıntı kod/olay kalmadığını doğrula.
- Düğme genişliği yazıya göre uzasın (Almanca "Klonen" kesilmesin); araç çubuğunda diğer düğmelerle aynı yöntem.
- **Not:** CLAUDE.md Bölüm 8 araç çubuğunu en fazla 5-6 düğme olarak sınırlıyor; bununla yedi düğme olacak. Sahibi bunu bilerek kabul etti. Raporda tek satır olarak belirt (düğme sayısı, soruna yol açıp açmadığı: örn. dar pencerede araç çubuğu taşıyor mu).

**Doğrulama:** derle (`Derle.bat`), programı aç. Klonla düğmesi bağlantı düğümü seçiliyken etkin, başka düğümde pasif mi; tıklayınca bağlantı penceresi mevcut tanımın bilgileriyle (kopya olarak) açılıyor mu (daha önce menüden olduğu gibi); üç dilde başlık doğru mu. **Elle denemediğin kısmı "denemedim" diye yaz.**

## 2. `ASAMA3A_RAPOR.md` tutarlılığı

Rapor, sonradan yapılan düzeltmelerle çelişen eski bilgiler taşıyor. Yalnızca **metni düzelt**, kod değişikliği yok:
1. **Adım 2 > "Ne yapıldı"** içinde, `uDDL.MetadataCikar` sıra listesinin 1. maddesinde bozuk karakterler var (`veritabanÄ±nÄ±n`, `Ã¶rn.`, `seÃ§ilmiÅŸse`, `varsayÄ±lan`...). Doğru Türkçe karakterlerle yeniden yaz (dosyayı UTF-8 olarak kaydet, başka yerde de bozuk karakter olup olmadığına bak: `Ã`, `Ä`, `Å` ara).
2. Aynı bölümde "**Dosya kodlaması: UTF-8, BOM'suz** ... Başlıkta `SET NAMES UTF8;`" ve "Okuma UTF-8 bağlantıyla yapılır" cümleleri arasında, **dosya kodlamasının artık veritabanının varsayılan karakter setine göre** (örn. WIN1254, NONE ise bağlantının, bilinmiyorsa UTF8) belirlendiğini ve başlıkta `SET NAMES <o karakter seti>` yazıldığını açıkça belirt (okuma hâlâ UTF8 bağlantıyla; dosyaya yazarken veritabanının karakter setine çevrilir, bu setin dışında kalan bir karakter varsa `?` olarak yazılabilir: **bilinen sınır** olarak "Bilinen sınırlar ve önemli notlar" bölümüne ekle). BOM yok kuralı doğru kalır (ölçüm: `isql -i` BOM'lu dosyayı reddediyor).
3. Dosyaya yazarken mevcut dosya, onay verildikten sonra **çıkarma başlamadan boşaltılır**; çıkarma ortasında hata/iptal olursa dosyada eski içerik kalmaz (yarım içerik veya boş). Bunu da "Bilinen sınırlar" bölümüne bir cümleyle ekle (sahibi bunu şimdilik kabul ediyor, kod değişmeyecek).
4. "Yapılmayanlar" bölümüne ve en başa: **Klonla düğmesi eklendi** (yukarıdaki iş), "Klonla menüden çıkarıldı" cümlesindeki "araç çubuğundaki düğme kalır" yanlışının belge hatası olduğu ve sahibinin kararıyla düğmenin yeni eklendiği not düşülsün. "**Sahibine soru**" paragrafı çözüldü diye işaretlensin (silme, "Çözüldü: araç çubuğuna eklendi" notu).

## Rapor ve bitiş

- Mevcut testler geçmeli (değişiklik yalnızca arayüzde, ama emin olmak için `DDLTest`, `SorguTest`, `BaglantiDosyasiTest`, `MetadataTest` çalıştır, sayıları yaz). Dil dosyalarında üç dilin anahtar sayıları eşit mi kontrol et.
- `ASAMA3A_RAPOR.md`'nin sonuna "Düzeltme (tarih)" bölümü ekle: ne yapıldı, ne test edildi, neyi denemedin. Kısa.
- `CLAUDE.md` Aşama 3 kutularını **işaretleme**, 3b'ye **geçme**; sahibinin elle denemesi ve onayı bekleniyor.
