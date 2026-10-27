# Aşama 3e-1 Raporu: Saklı prosedür düzenleme ve kaydetme

Dal: `asama3e-1` (main `d50737f` üstünden). Yerel çalışma, itme/PR yok, `CLAUDE.md` kutularına dokunulmadı, dosya silinmedi, yeni üçüncü parti bileşen yok.
**Sunucu kipi (3.0 :3052, 4.0 :3053, 2.5 :3054) bende denenmedi:** şifre bende yok. Testlerim "gömülü" kipte koştu; bunun gerçekte ne olduğu bölüm 4'te. Gerçek arayüzü **elle denemedim** (bölüm 5).

## 1. Ne değişti

| Dosya | Değişiklik |
|---|---|
| `Kaynak\uProsedur.pas` (yeni) | Tüm mantık: `ProsedurDuzenleMetni`, `ProsedurAdiniDogrula`, `ProsedurKaydet` (yedek + tek açık işlemde çalıştırma + sonuç kaydı), `ProsedurYedekKlasoru`, `SqlOzeti`, `HataSatiriBul`. Formda iş yok. |
| `Kaynak\fProsedurSekme.pas/.dfm` (yeni) | Düzenleme sekmesi (frame): üstte bilgi satırı + **Kaydet** düğmesi, altta `uEditor` editörü. `OnClick` doğrudan `Kaydet`i çağırır. |
| `Kaynak\uDDL.pas` | `ProsedurDuzenleScripti(Bag, Ad)`: `ScriptUret` ile aynı metin, başlık `CREATE OR ALTER PROCEDURE`. `ProsedurScripti` içine `Fiil` parametresi eklendi, `ScriptUret` çıktısı değişmedi (testle doğrulandı). |
| `Kaynak\uEditor.pas` | `TumMetin` (seçim olsa bile tüm metin) ve `SatiraGit(Satir)` eklendi. |
| `Kaynak\uBaglanti.pas` | `MetindenCevir`'e: "Column/Table/Procedure unknown" → mevcut `ERR_SQL_NESNE_YOK`; "dependencies" → yeni `ERR_NESNE_BAGIMLI`. |
| `Kaynak\fAna.pas/.dfm` | Ağaç sağ tık: prosedürde **Düzenle** (`miProsedurDuzenle`); sekme açma (aynı bağlantı + aynı prosedür açıksa o sekmeye geçer); bağlantı kapanınca sekme kapanır; dil değişince başlık/yazılar yenilenir; **Ctrl+S** = Kaydet; F5 bu sekmede yalnız ipucu yazar. |
| `Diller\tr/en/de.json` | 21 yeni anahtar (üçünde de aynı). `ERR_SQL_SOZDIZIMI` metnindeki eskimiş "Aynı anda yalnızca tek komut çalıştırılır" cümlesi (çoklu komut 2b'den beri var) "hatanın yeri Ayrıntı'da yazar" ile değiştirildi. |
| `FirebirdYonetici.dpr/.dproj` | Yeni unit'ler eklendi. |
| `Test\ProsedurDuzenleTest.dpr`, `ProsedurDuzenleTestDerle.bat` (yeni) | Test (bölüm 3). |

## 2. Davranış ve kararlar

- **Menü:** prosedür satırında sağ tık menüsü şimdi 3 madde: Script üret, **Düzenle**, Yenile (en çok 6 kuralı içinde; birleştirme gerekmedi).
- **Sekme başlığı:** "Prosedür: ADI (bağlantı adı)". Tanım `CREATE OR ALTER PROCEDURE`, `SET TERM ^ ;` sarmalı; `KomutlaraBol` SET TERM'i zaten tanıdığı için yeniden yazılmadı (tek komut çıkıyor).
- **Tek yol: Kaydet düğmesi / Ctrl+S**, ikisi de aynı `Kaydet`. **F5 hiçbir şey çalıştırmaz**, mesaj alanına "Bu sekmede F5 bir şey çalıştırmaz; Kaydet veya Ctrl+S" yazar. Neden: F5 = "çalıştır" alışkanlığıyla yanlışlıkla veritabanını değiştirmek, "kaydetmek" ile "çalıştırmak"ın karışması en sade çözümle önlenir; ikisini aynı yapmak onay penceresi olmadan kaydetme riski doğururdu.
- **Onay metni (tr):** "`ADI` prosedürü veritabanında değiştirilecek. Bu prosedürü kullanan tetikleyiciler ve prosedürler yeni haliyle çalışır. Eski hali bir dosyaya yedeklenir. Devam edilsin mi?" Evet/Hayır, varsayılan Hayır (`OnayIste`). Metinde birden fazla komut varsa "N komut var, hepsi tek işlemde çalışır, biri hata verirse hiçbiri uygulanmaz" eklenir; DROP/WHERE'siz DELETE-UPDATE varsa madde madde uyarılır.
- **Eski tanım yedeği:** `<veri klasörü>\_arsiv\<bağlantı adı>\prosedur_ADI_yyyymmdd_hhnnss.sql` (veri klasörü = `%APPDATA%\FirebirdYonetici`, bağlantı JSON'unun durduğu yer). İçerik: yorum başlığı, `SET NAMES <karakter seti>;` ve `CREATE OR ALTER PROCEDURE …` (SET TERM sarmalı), yani aynen geri kaydedilebilir (testle doğrulandı). Dosya veritabanının karakter seti kodlamasıyla yazılır (metadata çıkarımıyla aynı). Aynı saniyede ikinci kayıt `_2` son ekiyle yazılır, hiçbir yedek ezilmez. Yedek yazılamazsa (klasör açılamaz, tanım okunamaz, disk) **kaydetme durur, veritabanına dokunulmaz**, "Ayrıntı"da neden yazar.
- **Kaydet işlemi:** kendi `TFDTransaction`'ı (AutoCommit kapalı): hepsi başarılıysa **commit**, biri hata verirse **rollback**; çoklu komutta yarım kalmaz. Mesajlar durumu açıkça söyler: "kaydedildi (işlem onaylandı: commit)" / "değişiklik uygulanmadı; işlem geri alındı (rollback), eski hali duruyor" / "veritabanına dokunulmadı".
- **Başarı:** "ADI prosedürü kaydedildi" + "Eski hali yedeklendi: <yol>" + `SqlMesajiYaz` ile SQL (çok satırlı komut: ilk satır + "… (N satır)"; tam metin sekmede).
- **Hata:** anlaşılır cümle + "Ayrıntı: <ham mesaj>" + "geri alındı" + denenen SQL (`SqlMesajiYaz`). Firebird `line N, column M` verirse N, komutun metindeki ofsetiyle editör satırına çevrilir, **imleç o satıra gider** ve mesaj "Hata editörde N. satırda" der (embedded 2.5.9'da sözdizimi ve "Column unknown" hataları için satır doğru çıktı).
- **Ad koruması (isteğin dışında, güvenlik):** metindeki ilk komut `CREATE OR ALTER PROCEDURE <bu sekmedeki ad>` ile başlamıyorsa (ad değişmiş, başlık silinmiş, başka komut) kaydetme **hiç başlamaz**, uyarı penceresi çıkar. Aksi halde farklı adla kaydetmek sessizce yeni prosedür yaratırdı ve onay metni yanlış olurdu. Tırnaklı ad ("FBY Test Q") ve küçük harfli yazım doğru çözülür.
- **Paketli prosedür (3.0+):** ağaç zaten `rdb$package_name is null` ile paketli prosedürleri listelemiyor ve `ProsedurBilgisiOku` onları bulamıyor (`EMetadataHatasi`). Yani menüde "pasif" değil, **hiç görünmezler**; ek kod gerekmedi. (Test bölümü 3.0+ için hazır, 2.5'te atlanır.)
- **Yeni hata cümleleri (tr/en/de):**
  - sözdizimi: `ERR_SQL_SOZDIZIMI` zaten vardı (metin düzeltildi); gerçek hata 2.5.9'da üretildi ("Token unknown - line 6, column 7").
  - **olmayan değişken/kolon** (`Column unknown`, -206): daha önce genel "Beklenmeyen hata" çıkıyordu; gerçek hatayla görüldü, `ERR_SQL_NESNE_YOK`a bağlandı.
  - **bağımlı nesne:** 2.5.9'da `DROP PROCEDURE` gerçek hatası "cannot delete / PROCEDURE X / there are 1 dependencies" üretildi; `ERR_NESNE_BAGIMLI` bu metne bağlı.
  - **yetki yok:** `ERR_YETKI_YOK` (kod `335544352`) önceden vardı. **Bu görevde ALTER PROCEDURE yetki hatasını üretemedim** (bölüm 4); koda dokunmadım.
  - **nesne kullanımda:** `ERR_NESNE_KULLANIMDA` (metinde `" is in use"`) önceden vardı; yalnızca sentetik metinle doğrulandı, **gerçek hata üretilemedi** (bölüm 4).

## 3. Test: `Test\ProsedurDuzenleTest.dpr`

`Test\ProsedurDuzenleTestDerle.bat` ile derlenir (SynEdit yolu bat içinde `SYNEDIT=` ile ayarlı, arayüz duman testi `uEditor` ister). Bölümler:
**A** saf kurallar (ad doğrulama, SQL özeti, hata satırı, yedek klasörü, dil anahtarları tr/en/de); **B1** düzenle metni → gövde değiştir → kaydet → yeni sonuç, yedek içeriği eski, yedekle geri kaydet; **B2** sözdizimi/olmayan değişken hatası (cümle + Ayrıntı + editör satırı, eski prosedür bozulmaz), çoklu komutta ikincisi hata → ilki geri alınır, ad değişikliği ve başlıksız metin reddi; **B3** çok `;`'li SET TERM gövdesi, Türkçe harfli yorum ve metin aynen, tırnaklı ad; **B4** yedek yazılamıyor → kaydetme durur; **B5** paketli prosedür (yalnız 3.0+); **B6** başka bağlantı prosedürü kullanırken / bağımlı nesne; **B7** yetkisiz kullanıcı; **B8** üç dilde cümleler; **B9** arayüz duman testi (sekme ve editör oluşuyor, DFM hatası yok, `OnClick` bağlı, F5 ipucu, bağlantı yokken Kaydet mesaj yazıyor).
Yazma bölümleri kendi geçici veritabanında koşar; **sunucuda yalnızca yerel 3052/3053/3054 + `FBTEST_YAZMA=1`**, başka portta (3050/3051 dahil) kod reddeder, okuma-yalnızca bölüm A koşar.

**Sonuç (gömülü, sürüm 2.5.9):** `Kontrol: 75  Hata: 0`.
Mevcut testler (hepsi yeniden derlendi): `KullaniciTest` 43/0, `SorguTest` 0 hata, `DDLTest` 0 hata (`FBTEST_SIFRE=masterkey` ile), `AktarTest` 70/0, `SeritTest` 0 hata. `YedekTest`: bu ortamda yalnız 5.0.4'e düşen çalıştırmada geçiyor, 2.5.9'a düşünce gbak 5.0 sürümü 2.5 dosyasını yedekleyemiyor ("tam tur" 5 hata) — kodum `uYedek`e dokunmadı, ana depodaki eski derlemeyle (5.0.4'e düşen) aynı test 94/0 geçti; aşağıdaki "gömülü" notuna bakın.

## 4. Denenenler / denenmeyenler (açık)

- **"Gömülü kip" bu makinede gerçek gömülü değil:** `istemci\plugins` altında `engine13.dll` yok; `Sunucu` boşken istemci yerel çalışan bir Firebird sunucusuna XNET ile bağlanıyor ve **hangisine düşeceği yola/zamana göre değişiyor** (bu dizinde 2.5.9 test sunucusuna, ana depodaki derlemede 5.0.4'e düştü). Benim koşularım 2.5.9'a düştü (:3054 test sunucusu, izinli). Bazı koşularda aynı geçici dosya adı yüzünden "Dosya var" hatasıyla hiç başlamadı (test hata sayısı 1, hiçbir şey yazmadı). Bu yüzden **3.0 / 4.0 / 5.0 davranışı bende hiç denenmedi**.
- **Üretemediğim gerçek hatalar** (2.5.9'da ALTER'a izin veriyor, hata çıkmıyor): (a) başka bağlantı prosedürü çalıştırırken ALTER (imleç açık tutuldu, hata yok; 5.0.4'te `DROP` ile görülen "is in use" metnine güveniyoruz, yalnızca sentetik test), (b) bağımlı prosedür varken **parametre değiştirme** ALTER'ı (2.5.9 kabul ediyor; 3.0+ reddedebilir, gerçek metin bilinmiyor), (c) yetkisiz kullanıcıyla ALTER (gömülü/XNET'te tanımsız kullanıcı bağlanamıyor).
  Test bunları sunucuda **kendisi deniyor ve ham kodu yazıyor**: çıktıdaki `ham kod (...)` ve `bagimli parametre degisimi:` / `kullanimda:` / `yetkisiz:` satırlarını bana iletirseniz cümleleri gerçek koda bağlarım. Sunucuda reddedilirse test, cümlenin genel hata (`ERR_GENEL`) olmadığını ve eski prosedürün bozulmadığını kontrol eder.
- **Sahibi için sunucu testi** (PowerShell; şifre ortam değişkeninde, hiçbir dosyaya yazılmaz). Sırayla 3052 (3.0), 3053 (4.0), 3054 (2.5), `FBTEST_YOL` o sunucuda VAR OLAN bir test veritabanı:
```powershell
$env:FBTEST_SUNUCU = "127.0.0.1"; $env:FBTEST_PORT = "3052"
$env:FBTEST_YOL = "<sunucudaki test veritabani yolu>"
$env:FBTEST_KULLANICI = "SYSDBA"; $env:FBTEST_SIFRE = "<sifre>"
$env:FBTEST_YAZMA = "1"; $env:FBTEST_CIKTI = "$env:TEMP\prosedurtest_3052.txt"
.\bin\Win64\Release\ProsedurDuzenleTest.exe; $LASTEXITCODE
Get-Content $env:FBTEST_CIKTI | Select-String "HATA|ham kod|kullanimda|bagimli|yetkisiz|Kontrol:"
```
  3053 ve 3054 için yalnız `FBTEST_PORT` ve `FBTEST_YOL`/çıktı adı değişir. Derlemek için: `Test\ProsedurDuzenleTestDerle.bat`. Yedek dosyaları testte `%TEMP%\prosedurtest_veri` altına yazılır (gerçek veri klasörüne dokunmaz). Test kendi `FBY_TEST_*` prosedürlerini siler; yetkisiz kullanıcı `FBY_YETKISIZ` oluşturulup silinir (sunucu kipinde).
- **Arayüz elle denenmedi:** program 6 sn açık kaldı (çökmedi), B9 duman testi sekmeyi ve editörü oluşturdu; menü, sekme, onay penceresi, Ctrl+S, imleç satıra gitme **elle denenmedi**.

## 5. Bilinen sınırlar

- **Tanım değişmiş mi karşılaştırması yok** (görev bunu dışarıda bıraktı): sekme açıkken başkası prosedürü değiştirirse Kaydet sessizce üzerine yazar. Eski hali (başkasının değişikliği dahil) o anda yedeklendiği için kaybolmaz.
- Sekme kapatılırken "kaydedilmemiş değişiklik var" sorulmuyor (sorgu sekmeleri de sormuyor). Bağlantı kesilince sekme düzenlenmiş metinle birlikte kapanır.
- Düzenleme metni `ScriptUret`in ürettiğini aynen açar; 5.0'daki `SQL SECURITY` vb. `ScriptUret` üretmiyorsa düzenlemede de yok (yeni sözdizimi icat edilmedi).
- Aynı fonksiyonun öneri (Ctrl+Boşluk) hazırlığı `fSorguSekme`den kopyalandı (~35 satır); ileride ortak yordama alınabilir.
- Yedek klasörü bağlantı adına bağlı: bağlantı yeniden adlandırılırsa yeni yedekler yeni klasöre gider (eskiler dokunulmadan kalır).

## 6. Sahibine arayüz deneme listesi

1. Bir veritabanına bağlan, ağaçta bir prosedüre sağ tık: **Script üret / Düzenle / Yenile** görünüyor mu?
2. Düzenle: yeni sekme "Prosedür: ADI (bağlantı)"; metin `CREATE OR ALTER PROCEDURE`, `SET TERM ^` sarmalı; alt mesajda "açıldı, kaydedilene kadar değişmez".
3. Aynı prosedüre tekrar Düzenle: yeni sekme açılmıyor, mevcut sekmeye geçiyor mu?
4. Gövdeyi değiştir → **Ctrl+S** (ve ayrıca Kaydet düğmesi): onay penceresi (varsayılan Hayır) → Evet → alt alanda "kaydedildi (commit)", "Eski hali yedeklendi: …" ve `SQL: CREATE OR ALTER PROCEDURE … (N satır)`. `%APPDATA%\FirebirdYonetici\_arsiv\<bağlantı>\` altında dosya var mı, içeriği eski mi?
5. Sorgu sekmesinden prosedürü çalıştır: yeni sonuç geliyor mu?
6. Bilerek bozuk yaz (örn. `X = = 2;`): anlaşılır cümle + Ayrıntı + "geri alındı" + denenen SQL, **imleç hatalı satıra gidiyor** mu?
7. Adı değiştirip Kaydet: kaydetmeden uyarı penceresi çıkıyor mu?
8. Bu sekmede F5: yalnızca ipucu mesajı, hiçbir şey çalışmıyor mu?
9. Dili Almanca/İngilizce yap: sekme başlığı, düğme, mesajlar değişiyor, Almanca yazı düğmede kesilmiyor mu?
10. İkinci bir bağlantıdan (ya da başka istemciden) aynı prosedürü çalışır halde tutarken Kaydet: "nesne kullanımda" cümlesi geliyor mu? (Üretemediğim durum, bölüm 4.)

## 7. Düzeltme turu (moderatörün 3 sunucudaki koşusundan sonra)

Moderatör testi 3.0.14, 4.0.7 ve 2.5.9 atılabilir sunucularında koştu; üç bulgu, üçü de düzeltildi (ilk koşuda üretemediğim gerçek hatalar böylece görüldü):

1. **3.0+ ALTER hatası satır numarası vermiyor** (Firebird davranışı: `unsuccessful metadata update | CREATE OR ALTER PROCEDURE … failed | … Column unknown | X`, `line N` yok; 2.5'te `At line 1, column 62` var). Kod zaten doğru davranıyor (satır 0 ise imleç oynamaz, "Hata editörde N. satırda" mesajı yazılmaz; yalnız cümle + Ayrıntı). Test sürüme göre düzeltildi: 2.5'te satır beklenir, 3.0+'da `satır = 0` ya da doğru satır kabul, **yanlış satır hata**. Hatalı sözcüğü editörde arayıp satıra gitme yapılmadı (sade kalındı).
2. **3.0/4.0'da "nesne kullanımda" gerçek hata:** `lock conflict on no wait transaction | unsuccessful metadata update | object PROCEDURE "…" is in use`, **kod 335544345** (`isc_lock_conflict`). Çeviri doğru (`ERR_NESNE_KULLANIMDA`, metindeki `" is in use"` kontrolü kodun önüne geçiyor). Testte sızan istisna, B6'daki yardımcı `create or alter` çağrılarının `Dene` ile sarılmasıyla kapandı; 3.0+'da `ProsedurKaydet`in reddedilmesi (nesne kullanımda cümlesi, eski prosedür bozulmadı) artık bir kontrol. B6'nın geri kalanı, B7, B8, B9 3.0/4.0'da da koşar.
3. **2.5'te yetkisiz ALTER:** `unsuccessful metadata update | MODIFY RDB$PROCEDURES failed | no permission for protect access to PROCEDURE X`, kod `335544352` gelmiyor. `HataMetniniCevir`: metinde `no permission for` (erişim türü fark etmez) → `ERR_YETKI_YOK`. Testte bu 2.5 metniyle sentetik kontrol var; B7 3.0+'da gerçek mesajı yazdırır ve çevirinin `ERR_YETKI_YOK` olduğunu doğrular.

Gömülü (2.5.9) yeniden koşu: `Kontrol: 77  Hata: 0`. 3 sunucuda tekrar koşu moderatörde.
