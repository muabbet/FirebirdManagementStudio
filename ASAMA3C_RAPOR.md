# Aşama 3c raporu: yedekle / geri yükle (`gbak`)

**3c, `asama3b-csv` (a08cf54) üstüne kuruldu.** 3b henüz onaylanıp `main`'e birleşmediği için dal `main`'den değil oradan açıldı (sizin talimatınız). 3b'de sonradan düzeltme çıkarsa 3c'nin ona göre yeniden birleştirilmesi gerekir. Dal: `asama3c`. GitHub'a itilmedi, PR yok, **commit de yapılmadı** (değişiklikler çalışma ağacında). `CLAUDE.md` kutuları **işaretlenmedi**, 3d'ye geçilmedi.

## Ne yapıldı

- **`uYedek.pas` (yeni):** `YedekAl`, `GeriYukle`, `GbakHatasiniCevir`, `AltIslemCalistir`, `GbakSurumu`, `GbakYolu/GbakVarMi/GbakYoluAyarla`, `VarsayilanYedekAdi`, `BoyutMetni`. gbak `CreateProcess` ile, **kabuksuz**, gizli pencerede çalışır; stdout+stderr tek boruya alınır, `PeekNamedPipe` ile okunur (iş parçacığı yok). Şifre yalnızca alt işlemin ortam bloğuna `ISC_PASSWORD` olarak konur; kendi ortamımıza yazılmaz, bizim ortamda eski bir `ISC_PASSWORD` varsa alt işleme sızmaz.
- **Yedek:** `gbak -b -v`, önce `<hedef>.yarim`'e yazılır, başarıyla bitince hedefin yerine geçer (`MoveFileEx`). Hata/iptalde `.yarim` silinmez, eski yedek bozulmaz. Önceki bir `.yarim` varsa silinmez, `.yarim-yyyymmdd-hhnnss` adıyla yanına taşınır.
- **Geri yükleme:** yalnızca `gbak -c -v` (yeni dosya). `-r` hiçbir yerde yok. Hedef, açık bir bağlantının yoluyla aynıysa gbak çalıştırılmaz. Yerel (gömülü, sunucu boş) kullanımda hedef dosya varsa da gbak **çalıştırılmaz** (nedeni aşağıda, "Bulgular").
- **`fYedek.pas/.dfm` (yeni):** tek pencere, iki mod (Yedek al / Geri yükle), canlı gbak çıktısı kutusu, Başlat / İptal-Kapat, "Ayrıntı" bloğu (şifresiz komut, gbak sürümü, çıkış kodu) çıktı kutusunun altında. Seç... pencereleri (`TOpenDialog` / `TSaveDialog`), `gbak.exe` yoksa `TOpenDialog` ile seçtirme (oturum boyunca, **diske yazılmaz**). Üzerine yazma onayı `OnayIste` ile (ad, boyut, tarih yazılı). Ana pencerenin sonuç alanına özet, uyarılar, yarım dosya yolu yazılır.
- **`fAna`:** bağlantı düğümünün sağ tık menüsüne **tek madde** "Yedekle / Geri yükle..." (bağlantı açık olmak zorunda değil). Kayıtlı şifre yoksa mevcut şifre sorma penceresi açılır, şifre kaydedilmez. **Bağlantı düğümü menüsü artık yedi madde** (Bağlan, Bağlantıyı Kes, Yenile, Metadata çıkar, Yedekle / Geri yükle, Düzenle, Kayıttan Kaldır); sınırı bilerek aşıyoruz. Araç çubuğuna ve başka yere eklenmedi.
- **`uBaglanti.pas`:** iki küçük ekleme: `FbYoluAcikBaglantidaMi` ve `YerelSunucuMu` (ikisi de yalnızca okur).
- **`SonDerleme.bat`:** `gbak.exe`'yi `FBKAYNAK`'tan `istemci\`ye kopyalar; yoksa yalnızca `warning SD009` basar. `LISANSLAR.md` satırı güncellendi. `.dpr` ve `.dproj`'a `uYedek`, `fYedek` eklendi. Yeni bileşen yok.
- **Dil:** `tr/en/de` üçüne **40 anahtar** eklendi (`MENU_YEDEK`, `YEDEK_*`, `ERR_YEDEK_*`, `ONAY_YEDEK_UZERINE_YAZ`). Anahtar kümeleri eşit: üçünde **237** (3b'de 197'ydi), fark yok.

## Test (gömülü Firebird 5.0.4, geçici veritabanı, gbak 5.0.4.1812)

**`YedekTest`: 94 kontrol, hata 0** (`Test\YedekTestDerle.bat`). Kapsam:
- **Tam tur:** MUSTERI/SIPARIS tabloları (Türkçe karakter, UTF8 kolon, 70.000 baytlık ikili BLOB, 7.492 karakterlik metin BLOB, `NUMERIC(15,2)`, TIMESTAMP, PK/FK/CHECK, indeks), generator (4242 → tetikleyici 4243 verdi, geri yüklenende 4243), tetikleyici, prosedür, view. `.fbk` oluştu (111.616 bayt), **yeni dosyaya** geri yüklendi, `FbBaglan` ile bağlanıldı: nesne adları, üç sorgunun tüm satırlarının MD5 özeti, satır sayıları (201 / 500), BLOB bayt bayt, generator değeri, prosedür sonucu ve `MetadataCikar` çıktısı (1.615 karakter) **birebir aynı**. Yollar Türkçe karakterli ve boşluklu (`Türkçe Klasör ğşıİ\kaynak çğıöşüİ ...`).
- **Hedef var:** geri yükleme başarısız, cümle doğru, dosya boyutu aynı (2.367.488), **MD5 aynı** (gbak hiç çalıştırılmadığı için). Açık bağlantının yoluna geri yükleme reddedildi, gbak çalışmadı.
- **`.yarim` yöntemi:** (a) başarıda hedefin yerine geçti, `.yarim` kalmadı; (b) önceki `.yarim` silinmeden yanına taşındı; (c) olmayan kaynakta eski yedek dokunulmadan kaldı (MD5 aynı); (d) **iptal:** 1.000.000 satırlık (95 MB) veritabanında tam yedek 2,8–7,9 sn sürdü (makine yüküne göre), iptal 0,9–2,6 sn'de istendi, `YedekAl` iptal isteğinden ~50 ms sonra `False` döndü, alt işlem durdu (yarım dosya 800 ms sonra büyümüyor, 17–19 MB), `.yarim` **silinmedi**, eski yedek MD5 aynı; (e) hedef başka programda açıkken yedek alınıp yer değiştirilemedi: "yerine konamadı" cümlesi, tam yedek `.yarim` olarak duruyor.
- **Şifre:** komut satırı metni (`Ayrıntı`) ve gbak çıktısı şifreyi içermez, `-password` yok; alt işlemin ortamında `ISC_PASSWORD` var; verilmezse yok; kendi ortamımızda hep boş (önce/sonra); ortamımıza dışarıdan konmuş eski değer alt işleme sızmaz ve bizim tarafımızdan değiştirilmez.
- **Hatalar (tr/en/de cümle):** olmayan kaynak veritabanı, olmayan klasöre yedek, bozuk `.fbk` (rastgele metin), olmayan `.fbk`, başka programda açık `.fbk`, olmayan klasöre geri yükleme, gbak.exe yok (anlaşılır istisna). Her biri ham metin yerine çevrilmiş cümle verdi, Ayrıntı komut ve çıkış kodunu taşıyor.
- **Eşleme birim testi:** 20 ham gbak metni → cümle, üç dilde ayrı ayrı (3 kontrol). **6 örnek bu makinede ölçüldü** (`already exists`, `cannot open backup file`, `expected backup description record`, `CreateFile (open)`, `CreateFile (create)`, `USE_GBAK_UTILITY`), kalanı Firebird belgelerinden/bellekten örneklerdir (gerçek sunucuda sizin denemenize kalır).
- Dil anahtarları: 40 yeni anahtar üç dilde dolu.

**`YedekFormTest`: 27 kontrol, hata 0** (`Test\YedekFormTest.dpr`; formu kodla sürer, gerçek `OnClick`/`ShowModal`/gbak): pencere açılışı, iki mod geçişi ve etiket değişimi, tüm olay yöneticilerinin bağlı olması, canlı çıktı (46 satır), özet yazısı, üzerine yazma onay penceresi, bos alan uyarısı, aynı hedefe ikinci geri yükleme (cümle + dosya değişmedi), **Almanca yazıların sığması** (düğmeler ve etiketler), **İptal düğmesi** (`btnKapat.Click`, yarım dosya yolu yazısı), ana pencerenin sonuç satırları.

**Mevcut testler (yeniden derlenip çalıştırıldı):** `DDLTest` **146 OK**, `SorguTest` **80/80** (geçici veritabanı verilerek), `BaglantiDosyasiTest` **52/52**, `MetadataTest` çıkış kodu 0 (geri yüklenen veritabanını da okudu), `AktarTest` **70/70**. `Derle.bat` hatasız, bizim birimlerde uyarı/ipucu yok.

## Bulgular

- **gbak sürümü:** `gbak:gbak version WI-V5.0.4.1812 Firebird 5.0` (`gbak -z`, Ayrıntı'da gösterilir). Sürüm uyumu (5.0 gbak ile 2.5.9 sunucu) **bu makinede denenemedi**, aşağıdaki sunucu testlerinde.
- **Çıktı kodlaması: Windows ANSI kod sayfası** (bu makinede ACP=1254, OEM=857). OEM değil. Türkçe yol (`Türkçe Klasör ğşıİ`) ve işletim sisteminin yerelleşmiş hata metni (`Sistem belirtilen dosyayı bulamıyor`, `ı`, `ğ`) ACP ile çözülünce doğru çıktı. Bu yüzden çıktı `GetACP` kodlamasıyla okunur. Komut satırı UTF-16 geçer ama gbak argümanları ANSI aldığı için ACP dışındaki karakterler (örneğin Türkçe Windows'ta Çince karakter) yollarda desteklenmez.
- **Hata metinleri yerelleşiyor:** işletim sistemi kısmı Türkçe, gbak öneki İngilizce gelir. Bu yüzden eşleme yalnızca gbak'ın İngilizce kısmına bakar (`cannot open backup file`, `expected backup description record`, `I/O error during "CreateFile (open)/(create)"`, `already exists`...).
- **Var olan hedefe `gbak -c` bile dosyayı değiştirir:** gbak, "var mı?" diye veritabanına bağlanır ve başlık sayfasının **2 baytını** değiştirir (ölçüldü: sayfa 0, bayt 4 ve 52); hata yine de verir, veri sayfalarına dokunmaz. Salt bağlanıp kesmek (bizim `FbBaglan`) de 8 bayt değiştirir. Bu yüzden yerel hedef varsa gbak'ı hiç çalıştırmıyoruz ("bayt bayt aynı" koşulu için); **ağ üzerinden sunucuda bu önlem alınamaz**, orada gbak'ın kendi hatası ve cümlesi devrededir.
- **Gömülü kipte kaynak veritabanı başka süreç tarafından açılamaz:** program kendi bağlantısını açık tutuyorsa gbak "dosya başka bir işlem tarafından kullanılıyor" der (`I/O error ... (open)`). Bu hata şu cümleye çevrilir: "Kaynak veritabanı bulunamadı veya açılamadı... yerel (gömülü) kullanımda başka bağlantıda açıksa da çıkar". Sunucu kullanımında (asıl senaryo) sorun yok. Programda gömülü bağlantıyı yedekten önce otomatik kesmedik (gizli davranış olmasın diye).
- **Yetki:** var olmayan kullanıcıyla gömülü gbak "System privilege USE_GBAK_UTILITY is missing" verdi; bunun için ayrı cümle eklendi (`ERR_YEDEK_YETKI`). Gömülü ortamda gerçek "yanlış şifre" üretilemedi.

## Bilinen sınırlar / denenmedi

- **Denenmedi (sunucu gerekli):** yanlış şifre cümlesi (`ERR_SIFRE`), sunucuya ulaşılamadı, bağlantı kopması, **sürüm uyumsuzluğu (`ERR_YEDEK_SURUM`)**, disk dolu (`ERR_YEDEK_DISK`) cümleleri yalnızca ham metin örnekleriyle birim düzeyinde sınandı.
- **Pencereyi fareyle/klavyeyle kendim denemedim.** Bilgisayar kontrol aracı bu programı tanımıyor (3b'deki gibi). Kodla sürdüğüm denemeler yukarıda. **Denenmedi:** ağaçta sağ tık menüsünün görünürlüğü ve yedi madde sırası, gerçek fare tıklaması, Seç... pencereleri (`TOpenDialog`/`TSaveDialog`), `gbak.exe` yoksa çıkan seçme penceresi, şifresi kayıtlı olmayan bağlantıda şifre sorma, düğme ve etiket görünümü ekranda (Almanca için yalnızca ölçülen genişlik).
- Yarım dosya yeri: uzak sunucuda geri yükleme iptalinde dosya sunucuda olabilir; yol bildirilir ama var olup olmadığı bilinmez.
- `.yarim-tarih` adlı eski yarım dosyalar birikebilir (silmiyoruz).
- gbak seçeneği yok (sayfa boyutu, `-g`, ODS...), sahibinin kararı gereği.
- `engine13.dll` gömülü testler için `istemci\plugins`'te elle duruyor; `SonDerleme.bat` onu kopyalamaz (bu aşamanın işi değil, not olarak).

## Sizden beklenenler

1. Arayüzde elle deneyin: ağaçta bağlantı düğümüne sağ tık (yedi madde), Yedek al / Geri yükle geçişi, Seç... pencereleri, canlı çıktı, İptal, Almanca, kayıtlı olmayan bağlantıda şifre sorma, `istemci\gbak.exe`'yi geçici adlandırıp seçme penceresi.
2. Sunucu testleri (şifre bende yok). Önce derleyin:
```
Test\YedekTestDerle.bat
```
Sonra 2.5.9 için (5.0.4 için port 3051 ve `FBTEST_CIKTI=%TEMP%\yedektest_504.txt`):
```
set FBTEST_SUNUCU=localhost
set FBTEST_PORT=3050
set FBTEST_KLASOR=C:\Temp
set FBTEST_KULLANICI=SYSDBA
set FBTEST_SIFRE=...
set FBTEST_CIKTI=%TEMP%\yedektest_259.txt
set YEDEK_SATIR=300000
bin\Win64\Release\YedekTest.exe
```
`FBTEST_KLASOR` **sunucudaki** bir klasör olmalı (geçici veritabanları orada açılır, gerçek veriye dokunulmaz); `.fbk` dosyaları bu bilgisayarda `%TEMP%\yedektest` altına yazılır. Sunucu modunda "hedef var" testinin bayt karşılaştırması ve ham-gbak ölçümü atlanır (sunucudaki dosyaya ulaşılamaz), diğerleri aynen koşar. İstenen sunucu denemeleri bu testin içinde: (a) 2.5.9'dan yedek (5.0 gbak ile), (b) o yedeği 2.5.9'da **yeni** dosyaya geri yükleme, (c) 5.0.4 için aynısı, (d) yanlış kullanıcı/şifre (`ERR_SIFRE` bekleniyor), (e) sürüm uyumsuzluğu: 5.0.4'ten alınan yedeği 2.5.9'a geri yüklemeyi elle deneyip çıkan ham metni bana iletin (`ERR_YEDEK_SURUM` eşlemesi belgelerden, ölçülmedi). Hangi sürüm çiftinin çalıştığını raporunuza yazın. 2.5.9 sunucuda testin bazı satırları 2.5'e özgü farklar gösterebilir (örneğin generator/tetikleyici sözdizimi 2.5'te de geçerli ama orada hiç koşulmadı).
3. Şu kararlar sizde: (i) `gbak.exe` seçimini saklayalım mı (şimdi yalnızca oturum boyunca)? (ii) Gömülü kullanımda yedekten önce programın kendi bağlantısını otomatik kesmesini ister misiniz (şimdi kesmiyor, cümle uyarıyor)? (iii) 3b'nin `main`'e birleşiminden sonra 3c'nin yeniden birleştirilmesi/commit'i.
4. Onayınızdan sonra `CLAUDE.md` Aşama 3 "Yedek/geri yükleme" kutusunu işaretleyeceğim; 3d'ye geçmedim.
