# Görev: Aşama 3e-1, Saklı prosedür düzenleme ve kaydetme

Bu görev, **Delphi/RAD Studio 12 olan makinede** çalışan ajan içindir. **Önce `CLAUDE.md` dosyasını baştan sona oku** (Bölüm 3, 4, 6, 8 özellikle "SQL karşılığı" kuralı, 9, 10, 12). Tüm yanıt ve rapor Türkçe. **Bu görev 3d-1'in `main`'e birleşmesinden sonra başlar** (ortak `SqlMesajiYaz` yordamı `fAna.pas`'ta hazır olmalı; yoksa dur ve mimara söyle).

## Sahibinin kararları (2026-10-27)

- Sahibi trigger ve saklı prosedürleri programdan **düzenleyip kaydetmek** istiyor. İşe **önce prosedür** (3e-1), sonra trigger (3e-2) ile başlanır; trigger'lar ağaçta **ayrı bir "Trigger'lar" dalı** olarak görünecek (3e-2'de).
- **"Kaydet" = veritabanına uygula** (`CREATE OR ALTER`, yani derle). Dosyaya kaydetme ayrı bir düğme olarak eklenmez.
- Her kaydetmenin SQL'i alt mesaj alanında görünür (`SqlMesajiYaz`, öğrenme amaçlı).

## Çalışma düzeni

- Yerel çalışma: GitHub'a itme yok, PR yok. `main` (3d-1 birleştikten sonraki) üstünden yeni dal `asama3e-1`. `main`'e birleştirme yok, `CLAUDE.md` kutularına dokunma.
- Dosya silme yok (gerekirse `_arsiv`). Yeni üçüncü parti bileşen yok. Belirsizlikte tahmin etme, sahibine sor.
- Veri değiştiren testler yalnızca atılabilir sunucularda: gömülü kip, 3.0 :3052, 4.0 :3053, 2.5 test kopyası :3054. Gerçek veri sunucularına (:3050, :3051) bağlanan yazma testi **yasak**, test programı bu portlarda yazmayı kod seviyesinde reddetsin (`KullaniciTest`'teki koruma kalıbı). Sunucu kipini sen çalıştıramazsın (şifre sende yok): "gömülü kipte denendi, sunucuyu sahibi deneyecek" de, "çalışıyor" deme.

## Yapılacaklar

1. **Menü:** Ağaçta bir prosedüre sağ tık menüsüne **"Düzenle"** maddesi (menü en çok 6 madde, Bölüm 8; şu an kaç madde var kontrol et, yer yoksa hangisini birleştireceğini mimara sor). Tıklayınca prosedürün tanımı yeni bir **düzenleme sekmesinde** açılır: mevcut `ScriptUret` ile alınan tanım, ama başlığı `CREATE PROCEDURE` yerine **`CREATE OR ALTER PROCEDURE`** olarak (Firebird 2.5+ destekler). Çok komutlu gövde için `SET TERM` ile sarılır (3a/2b'deki `KomutlaraBol` mantığı zaten `SET TERM`'i tanıyor, onu yeniden yazma).
2. **Düzenleme sekmesi** mevcut SQL sekmesinin editörünü kullanır (`uEditor`, SynEdit sarmalayıcısı), yeni bileşen yok. Sekme başlığı: "Prosedür: ADI (bağlantı adı)". Bu sekmede **tek yol: "Kaydet" düğmesi (sekme içinde) ve Ctrl+S**. F5 bu sekmede de çalışmaya devam etmesin ya da aynı işi mi yapsın, sen en sade olanı seç ve nedenini raporda yaz; ama iki farklı yoldan farklı davranış olmasın.
3. **Kaydet adımları** (hepsi `uMetadata`/`uSorgu` tarafında bir yordam, formda iş yok; Bölüm 4):
   - Net onay penceresi: "`ADI` prosedürü veritabanında değiştirilecek. Bu prosedürü kullanan tetikleyiciler ve prosedürler yeni haliyle çalışır. Eski hali bir dosyaya yedeklenir." Evet/Hayır, varsayılan Hayır (Bölüm 10).
   - **Eski tanımı kaydetmeden önce `_arsiv\<bağlantı adı>\prosedur_ADI_yyyymmdd_hhnnss.sql` dosyasına yaz** (Bölüm 3.6: hiçbir şey kaybolmasın). Yazılamazsa kaydetmeyi durdur ve nedenini söyle.
   - Metni çalıştır (`BetikCalistir` ya da mevcut tek komut çalıştırıcı, transaction davranışı açık: başarıda commit, hata olursa rollback ve kullanıcıya durum görünür; `CommitRetaining` gizli bırakılmaz).
   - Başarı: "ADI prosedürü kaydedildi." ve altında **`SqlMesajiYaz`** ile SQL (uzun gövdenin ilk satırı + "(N satır)"; tam metin zaten sekmede). Hata: Firebird'in anlaşılır cümlesi + "Ayrıntı"da ham mesaj; hatada denenen SQL de aynı şekilde gösterilir. Firebird satır numarası veriyorsa (`line X, column Y`), editörde o satıra git.
4. **Hata cümleleri (Bölüm 6.7) `HataMetniniCevir`'e, üç dilde:** "nesne kullanımda" (başka bir bağlantı prosedürü çalıştırıyor), "bağımlı nesne" (prosedürü başka nesne kullanıyor, parametre/dönüş değiştirilemiyor), "yetki yok", "sözdizimi hatası" zaten var mı bak. Gerçek hata kodlarını **test sunucusunda üret**, tahmin etme.
5. **Sürüm farkı** yalnızca `uMetadata`/`uDDL` içinde (Bölüm 9): `CREATE OR ALTER PROCEDURE` 2.5-5.0'da var, ama 3.0+ paketli prosedürler (`PaketSarti`) **kapsam dışı** (Düzenle menüsü pasif ya da gizli). Prosedür parametreleri, `SQL SECURITY` (5.0) vb. için `ScriptUret` ne üretiyorsa onu aynen düzenlemeye aç, yeni sözdizimi icat etme.
6. **Tanım değişmiş mi uyarısı (yalnızca sade hâli):** Düzenleme sekmesi açıkken başkası prosedürü değiştirdiyse, Kaydet anında karşılaştırma yapma (bu dilimde yok); raporda "bilinen sınır" olarak yaz.
7. **Dil dosyaları:** `tr.json`, `en.json`, `de.json` (menü, sekme başlığı, Kaydet, onay, mesajlar, hatalar). Düğme genişlikleri yazıya göre uzar.
8. **Test:** `Test\ProsedurDuzenleTest.dpr` + `...Derle.bat` (mevcut test kalıbı, ortam değişkenleri, çıktı dosyaya). İçerik: prosedür oluştur → düzenleme metni `CREATE OR ALTER` ile geliyor → gövdeyi değiştir (ör. dönüş değeri farklı) → Kaydet → prosedürü çağır, sonuç yeni → eski tanım dosyası `_arsiv`'de ve içeriği eski → sözdizimi hatalı metin: hata cümlesi + satır no, eski prosedür bozulmadı → `SET TERM` içeren gövde → Türkçe harfli yorum/metin aynen kalıyor → başka bağlantı prosedürü kullanırken kaydetme hatası (anlaşılır cümle) → yetkisiz kullanıcı (3 sürüm) → paketli prosedür (3.0+) menüde kapalı → eski tanım yazılamazsa kaydetme durur. 2.5, 3.0, 4.0, 5.0 gömülü/sunucu.
9. **Gömülü kipte derle/çalıştır**, mevcut testler (DDL, Aktar, Yedek, Serit, Kullanici, Sorgu) hâlâ geçsin; gerçek arayüzü açıp elle dene, **denemediğini "denemedim" diye yaz**.
10. **Rapor:** `ASAMA3E1_RAPOR.md` (Türkçe, kısa): ne değişti (dosya/satır), düğme/menü yeri, onay metni, eski tanım yedeği nerede, sunucu testi için sahibine PowerShell komutları ($env:FBTEST_...; 3052/3053/3054), denenenler/denenmeyenler, bilinen sınırlar, sahibine arayüz deneme listesi. Commit mesajlarının sonuna `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>` ekle.

## Bitiş ölçütü

Bir prosedüre sağ tık → Düzenle → metin düzenlenir → Kaydet (onay) → prosedür veritabanında yeni halde, eski hali `_arsiv`'de, SQL alt mesaj alanında görünür, hatalar üç dilde anlaşılır; testler gömülü ve 3 sunucuda hatasız. **Sahibi onaylamadan 3e-2'ye (trigger) geçilmez.**
