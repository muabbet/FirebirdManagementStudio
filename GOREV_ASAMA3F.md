# Görev: Aşama 3f, View / Generator / Domain / Exception: listele, oluştur, düzenle, sil

Bu görev, **Delphi/RAD Studio 12 olan makinede** çalışan ajan içindir. **Önce `CLAUDE.md` dosyasını baştan sona oku** (Bölüm 3, 4, 6, 8 "SQL karşılığı" kuralı, 9, 10, 12), sonra **`GOREV_ASAMA3E1.md`, `GOREV_ASAMA3E2.md`, `ASAMA3E2_RAPOR.md` ve 3e'nin kodunu** (`uProsedur.pas`, `fProsedurSekme.pas`, `fAna.pas` içindeki Düzenle/Kaydet akışı, `uDDL.pas`, `uMetadata.pas`) oku. Tüm yanıt ve rapor Türkçe.

## Karar (sahibi, 2026-10-29)

IBExpert'te olup bizde olmayan özelliklerin ilk grubu: 3e'deki "düzenle, Kaydet = veritabanına uygula" akışını **View, Generator** için de kur, ağaca **Domain'ler** ve **Exception'lar** dallarını ekle (listele, script üret, oluştur, düzenle, sil). Tablo yapısı düzenleme (kolon, index, constraint) **bu görevde YOK** (ayrı görev, 3g).

## Çalışma düzeni

- Yerel çalışma: GitHub'a itme yok, PR yok. `main` (güncel) üstünden yeni dal `asama3f`. `main`'e birleştirme yok, `CLAUDE.md` kutularına dokunma.
- Dosya silme yok (gerekirse `_arsiv`). Yeni üçüncü parti bileşen yok. Belirsizlikte tahmin etme, sahibine sor.
- Veri değiştiren testler yalnızca atılabilir sunucularda: gömülü kip, 3.0 :3052, 4.0 :3053, 2.5 test kopyası :3054 (`Test\TestSunuculariBaslat.ps1` ile açılır). Gerçek veri sunucularında (:3050, :3051) yazma testi **yasak**; test programı bu portlarda yazmayı kod seviyesinde reddetsin (`TriggerDuzenleTest`'teki koruma kalıbı). Sunucu kipini sen çalıştıramazsın (şifre sende yok): "gömülü kipte denendi, sunucuyu mimar/sahibi çalıştıracak" de, "çalışıyor" deme.
- Sınıf bildiriminde alanlar prosedürlerden önce. Her görünen yazı `T('ANAHTAR')`, üç dil dosyası.

## Yapılacaklar

Sırayla, her alt iş kendi commit'i olsun (3f-1 ... 3f-4). Her alt iş sonunda mevcut testler geçsin.

### 3f-1: Domain'ler ve Exception'lar dalları (yalnızca okuma)
1. `uMetadata`: domain listesi (`RDB$FIELDS`, sistem üretimi `RDB$%` adlar hariç) ve exception listesi (`RDB$EXCEPTIONS`, sistem hariç). Sürüm farkı varsa yalnızca burada.
2. Ağaç: bağlı bağlantı altında dallar şu sırayla: Tablolar, View'lar, Prosedürler, Trigger'lar, **Domain'ler**, **Exception'lar**, Generator'lar. Ağaç doldurma ve dil değişimi (`YazilariYenile`) çalışsın. Ikon: `Ikonlar\svg` içinde uygun yoksa mevcut ikonu geçici kullan, raporda bildir.
3. Sağ tık (en çok 5-6 madde): **Script üret**, **Yenile**. (Düzenle ve sil sonraki alt işlerde eklenir.) `uDDL`'de domain ve exception script'i yoksa ekle (metadata çıkarımında zaten varsa onu kullan, tekrar yazma).

### 3f-2: View düzenleme
1. View'a sağ tık: **Düzenle**. Tanım yeni düzenleme sekmesinde açılır ("View: ADI (bağlantı adı)"); Kaydet adımları 3e ile **aynı**: ad koruması, net onay penceresi (varsayılan Hayır; "View değiştirilecek, bu view'ı kullanan prosedür/trigger/view'lar etkilenebilir"), eski tanım yedeği `_arsiv\<bağlantı>\view_ADI_yyyymmdd_hhnnss.sql` (yazılamazsa durur), tek açık işlemde çalıştır, başarıda commit ve `SqlMesajiYaz`, hatada anlaşılır cümle + Ayrıntı.
2. **Sözdizimi sürüme bağlıdır, tahmin etme, test sunucularında dene:** `CREATE OR ALTER VIEW` hangi sürümde var? Yoksa seçenekler: `RECREATE VIEW` (bağımlılık varsa başarısız olabilir). Gerçek davranışı 2.5/3.0/4.0'da üret ve en güvenli çalışan yolu seç. Bağımlılık yüzünden değiştirilemeyen view için anlaşılır cümle ("Bu view'ı başka nesneler kullanıyor, önce onları bırakmak gerekir" gibi, gerçek hata koduyla bağla). Hiçbir sürümde güvenli yol çıkmazsa kendin karar verme: raporda yaz, sahibine sor.
3. Kod tekrarı yazma: 3e'de genelleştirilen `NesneDuzenleMetni/NesneAdiniDogrula/NesneKaydet` yapısına view'ı ekle; prosedür ve trigger davranışı hiç değişmesin (`ProsedurDuzenleTest`, `TriggerDuzenleTest` aynen geçmeli).

### 3f-3: Exception ve Domain oluştur / düzenle / sil
1. **Yeni** (dal üstüne sağ tık veya şeritte yok, sağ tık yeterli): boş şablonlu düzenleme sekmesi (`CREATE EXCEPTION YENI_EXCEPTION 'mesaj';`, `CREATE DOMAIN YENI_DOMAIN AS VARCHAR(50);`). Kaydet = çalıştır, aynı onay/SQL karşılığı akışı. Ad çakışması hatası anlaşılır cümle.
2. **Düzenle:** Exception: `CREATE OR ALTER EXCEPTION` (2.5+; sürümde yoksa `ALTER EXCEPTION`, test et). Domain: `ALTER DOMAIN` ile yapılabilenler (varsayılan değer, CHECK, ad değiştirme, tip değiştirme kısıtlı). **Domain için "CREATE OR ALTER" yoktur;** düzenleme sekmesinde üretilecek komut `ALTER DOMAIN ...` olacağı için bunu **basit tut:** yalnızca şu işleri destekle ve her biri ayrı küçük pencere/komut olsun: varsayılan değeri değiştir/kaldır, CHECK'i değiştir/kaldır, adı değiştir. Tip değiştirme bu görevde yok (rapora not).
3. **Sil (DROP):** Exception, Domain, View, Generator için sağ tıkta **Sil**. Net onay penceresi (varsayılan Hayır; nesne adı, türü, "geri alınamaz" ve yedek bilgisi). Önce `RDB$DEPENDENCIES` ile **kimler kullanıyor** bakılır ve onay penceresinde listelenir (en çok 10 madde, fazlası "ve N tane daha"); bağımlılık varsa Firebird zaten reddeder, hatayı anlaşılır cümleye çevir (gerçek hata kodu/metniyle). Silmeden önce tanım `_arsiv`'e script olarak yedeklenir (yazılamazsa silme başlamaz). `SqlMesajiYaz` ile `DROP ...` görünür. **Tablo ve prosedür/trigger silme bu görevde YOK.**
4. Sağ tık menü sınırı: bir nesnede en çok 6 madde (Script üret, Düzenle, Yenile, Sil, + türe özgü bir tane).

### 3f-4: Generator (sequence) yönetimi
1. Generator'a sağ tık: **Değeri göster/ayarla** (küçük pencere: şimdiki değer `GEN_ID(ad, 0)`, yeni değer kutusu; Kaydet = 2.5 için `SET GENERATOR ad TO n`, 3.0+ için `ALTER SEQUENCE ad RESTART WITH n`, sürüm farkı `uMetadata`/`uDDL` içinde), **Yeni generator** (ad), **Sil** (3f-3 akışı), **Script üret**.
2. Değer küçültme (geri alma) tehlikelidir: yeni değer şimdikinden **küçükse** ek uyarı ("Bu değer daha önce kullanılmış kayıt numaralarıyla çakışabilir"). Onay varsayılan Hayır.
3. Tetikleyici bulma (hangi trigger bu generator'ı kullanıyor) bağımlılık listesinden gelir.

## Ortak kurallar (tüm alt işler)

- Ham Firebird hataları `HataMetniniCevir`'de (üç dilde) anlaşılır cümleye çevrilir; **gerçek hatayı test sunucusunda üret**, tahminle çeviri yazma. Üretemediğini raporda "üretilemedi" diye yaz.
- Her yönetim işleminin SQL'i `SqlMesajiYaz` ile alt alanda görünür (hatada da denenen SQL).
- Düğme/menü genişlikleri yazıya göre uzar; Almanca'da kesilmesin.
- Şeride düğme eklemek gerekmez; her şey ağaç sağ tık menüsünden.

## Test

`Test\NesneYonetimTest.dpr` + `...Derle.bat` (3e test kalıbı: ortam değişkenleri, çıktı dosyaya, yazma koruması 3052/3053/3054). İçerik: domain ve exception listeleme (sistem nesnesi çıkmaz) → script üretimi → exception/domain oluştur-düzenle-sil → view düzenle (bağımlısız ve bağımlılı) ve yedek dosyası → generator değer oku/ayarla/küçült uyarısı → silmede bağımlılık listesi → hata cümleleri üç dilde → arayüz duman testi. Mevcut tüm testler (Prosedur, Trigger, Kullanici, DDL, Aktar, Yedek, Serit, Sorgu, Metadata) hâlâ geçsin. Gömülü kipte derle/çalıştır, arayüzü elle dene; **denemediğini "denemedim" diye yaz.**

## Rapor

`ASAMA3F_RAPOR.md` (Türkçe, kısa): ne değişti (dosya/satır), her alt işin durumu, hangi sürümde hangi sözdizimi seçildi ve neden (view için özellikle), kod tekrarı kararı, yedek yerleri, sunucu testi için sahibine PowerShell komutları, denenenler/denenmeyenler, bilinen sınırlar, öneriler, sahibine arayüz deneme listesi. Commit mesajlarının sonuna `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>` ekle.

## Bitiş ölçütü

Ağaçta Domain'ler ve Exception'lar dalları var; view düzenlenip kaydedilir; exception, domain, generator oluşturulur/düzenlenir/silinir; her silme bağımlılıkları gösterip net onay ister ve yedek alır; hatalar üç dilde anlaşılır; SQL karşılıkları alt alanda görünür; prosedür ve trigger düzenleme aynen çalışır; testler gömülü ve 3 sunucuda hatasız. **Sahibi onaylamadan sonraki işe (3g tablo yapısı düzenleme) geçilmez.**
