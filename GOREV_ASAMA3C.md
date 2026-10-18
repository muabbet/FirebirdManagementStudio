# Görev: Aşama 3c, yedek ve geri yükleme (`gbak`)

Bu görev, **Delphi/RAD Studio 12 ve gerçek Firebird sunucuları olan makinede** çalışan ajan içindir. Bu, Aşama 3'ün (Yönetim Özellikleri) **üçüncü alt aşamasıdır**; genel plan `GOREV_ASAMA3.md`'de (3d orada), ama **şimdilik yalnızca 3c'yi yap**.

**Önce `CLAUDE.md` dosyasının tamamını oku** (özellikle Bölüm 3, 4, 6, 9, 10). Sonra `ASAMA3B_RAPOR.md`, `ASAMA3A_RAPOR.md`, `Kaynak\uBaglanti.pas` (özellikle `TBaglantiTanimi`, `IstemciDosyasi`, DPAPI şifre kısmı), `Kaynak\uOnay.pas`, `Kaynak\fCsvAktar.pas` (ilerleme/iptal örneği), `Kaynak\fAna.pas` (sağ tık menüsü, şifre sorma), `SonDerleme.bat` dosyalarına göz at.

## Çalışma düzeni

- **Çalışma yerel yürür: GitHub'a itme yok, PR yok.**
- **Önce kontrol:** `git status` ve `git log` ile `main`'in son halini gör. `main`'de 3b'nin birleşmiş olduğunu doğrula (`Kaynak\uAktar.pas`, `Kaynak\fCsvAktar.pas` ve `ASAMA3B_RAPOR.md` `main`'de olmalı). Yoksa **dur** ve sahibine söyle; kendin birleştirme.
- Dal: `main`'in son halinden `asama3c` adlı yeni dal aç. `main`'e yazma. Eski yerel `asama3b` (yarım WIP) ve `asama3b-csv` dallarını kullanma.
- Tüm yanıt ve rapor Türkçe. Her yeni yazı için üç dil dosyası (tr, en, de) güncellenir, anahtar kümeleri eşit kalır. Dosya silme yok (`_arsiv`). Yeni bileşen yok. Kod sade kalsın (CLAUDE.md Bölüm 3): düğmenin `OnClick`'i işi yapan unit fonksiyonunu doğrudan çağırır, formlarda sabit yazı yok, sınıf bildiriminde alanlar prosedürlerden önce, boş olay yöneticisi yok.
- Belirsiz bir şey olursa tahmin etme, sahibine sor.
- Sahibinin Firebird 2.5.9 ve 5.0.4 sunucu bağlantıları gerçek veridir: **orada yedek-geri yükleme deneme, hiçbir veritabanına yazma.** Yalnızca gömülü 5.0.4 ve geçici veritabanıyla dene. Sunucu şifresi sahibindedir; 3050/3051 sunucu testlerini sahibi kendi penceresinde çalıştırır. Ajan şifre tahmin etmez, sunucu testleri için komutları rapora yazar.
- Tehlikeli işlemler (var olan `.fbk` dosyasının üzerine yazma) net onay penceresi ister (`uOnay.OnayIste`). Sessiz ya da otomatik yok.

## Amaç

Bir veritabanını `.fbk` dosyasına **yedeklemek** ve bir `.fbk` dosyasını **yeni bir veritabanı dosyasına geri yüklemek**. `gbak.exe` programı çağrılır, kendimiz yedekleme motoru yazmıyoruz. Windows'a ve `gbak`'a bağlı her şey yeni **`uYedek.pas`**'in arkasında.

## Kararlar (sahibi adına, değiştirme; belirsiz bir şey çıkarsa sor)

1. **İstemci tarafı gbak:** `gbak` bu bilgisayarda çalışır, sunucuya ağ üzerinden bağlanır (`-service` kullanılmaz). Yedek dosyası (`.fbk`) **bu bilgisayarda** oluşur. Bağlantı biçimi: `Sunucu` doluysa `sunucu/port:yol` (hem 2.5 hem 3.0+ bunu anlar), boşsa yalnızca `yol` (gömülü, testler için).
2. **Geri yükleme yalnızca yeni dosyaya:** `gbak -c` (create) kullanılır. **`-r` (replace) hiç kullanılmaz, yok.** Hedef veritabanı dosyası zaten varsa gbak hata verir; bu hata anlaşılır cümleyle gösterilir ("Bu adda bir veritabanı zaten var, yeni bir ad girin"). Var olan veritabanının üzerine yazma ilk sürümde **yok**. Hedef yol, açık bir bağlantının yoluyla aynıysa gbak'ı çalıştırmadan önce uyar ve yeni ad iste.
3. **Yedek dosyası üzerine yazma:** hedef `.fbk` zaten varsa `OnayIste` ile onay istenir (dosya adı, boyut, son değişiklik tarihi yazılı). Onaylanırsa yedek önce `<hedef>.yarim` adlı geçici dosyaya yazılır, **başarıyla bitince** hedefin yerine geçer (rename). Hata veya iptalde `.yarim` dosyası **silinmez**, kullanıcıya "yarım dosya şurada, geçerli bir yedek değil" denir (kural 6). Önceki geçerli yedek böylece yarım yedekle bozulmaz.
4. **Şifre komut satırına yazılmaz.** Şifre yalnızca `ISC_PASSWORD` ortam değişkeniyle, **yalnızca o alt işlem için** iletilir (`CreateProcess` ortam bloğu; kendi sürecimizin ortamına `SetEnvironmentVariable` yazma). Kullanıcı adı `-user` ile komut satırında olabilir. Komut satırı "Ayrıntı"da gösteriliyorsa şifresizdir. Şifre kaynağı: kayıtlı bağlantıdan (DPAPI, Aşama 1b davranışı); kayıtlı değilse `fAna.pas`'taki gibi şifre sorulur (şifre kaydedilmez).
5. **Bağlantı açık olmak zorunda değil:** kayıtlı bir bağlantı tanımı yeterli (sunucu, port, yol, kullanıcı, şifre). Yedek sırasında açık bağlantı sorun değil.
6. **`gbak.exe` yeri:** `fbclient.dll`'in yanındaki `istemci\` klasörü (`uBaglanti.IstemciDosyasi` ile aynı klasör, 64 bit Firebird 5.0). `SonDerleme.bat` istemciyi hangi klasörden kopyalıyorsa `gbak.exe`'yi de oradan `istemci\`ye kopyalasın (yoksa yalnızca UYARI basar, derleme kırılmaz; mevcut uyarı biçimini örnek al). Bulunamazsa kısa pencereyle (`TOpenDialog`) `gbak.exe` seçtirilir. **Seçim saklanmaz** (ayar penceresi yok); saklama gerekirse raporda sahibine sor.
7. **Arayüz tek yol:** Ağaçta **bağlantı düğümünün** sağ tık menüsüne **tek madde**: "Yedekle / Geri yükle...". Aşağıda tarif edilen **tek pencere** açılır. Bağlantı düğümünde menü zaten altı madde (Bağlan, Kes, Düzenle, Kaldır, Metadata çıkar, Yenile), bu yedinci olacak; sınırı bilerek aşıyoruz, raporda say ve yaz. Araç çubuğuna ve başka yere ekleme yok.

## Pencere (`fYedek.pas/.dfm`, form ince, iş `uYedek.pas`'te)

- Üstte iki seçenekli işlem seçimi: **Yedek al** / **Geri yükle** (`TRadioGroup` veya iki `TRadioButton`; seçim değişince etiketler ve alanlar değişir, ikinci pencere yok).
- **Yedek al:**
  - Kaynak: bağlantının veritabanı (salt okunur gösterilir, değiştirilemez): `sunucu:yol`.
  - Hedef: `.fbk` dosyası, varsayılan ad `<veritabanı dosya adı>_yyyymmdd_hhnnss.fbk` (Belgelerim klasöründe), "Seç..." ile `TSaveDialog`.
- **Geri yükle:**
  - Kaynak: `.fbk` dosyası, "Seç..." ile `TOpenDialog`.
  - Hedef: **yeni** veritabanı yolu (sunucudaki yol; elle yazılır. Sunucu `localhost`/boşsa "Seç..." ile `TSaveDialog` de kullanılabilir, uzak sunucuda yok). Önerilen varsayılan boş bırakılır, kullanıcı yazar.
- Düğmeler: **Başlat**, **İptal/Kapat** (çalışırken İptal). Ek seçenek **yok** (sayfa boyutu, parçalama, ODS, çöp toplama seçtirilmez; Bölüm 8: ayar yığma yok).
- Gbak çıktısı pencere içindeki salt okunur bir alanda **canlı** gösterilir; hata olursa çıktının tamamı "Ayrıntı"da (ve kopyalanabilir) kalır. Bitişte ana pencerenin sonuç alanına özet: işlem, dosya, boyut, süre, varsa uyarılar.
- Yazı genişlikleri yazıya göre uzar (`DugmeyiYaziyaUydur`). Pencere donmaz, İptal çalışır (3b'deki `ProcessMessages` yöntemini kullan, iş parçacığı ekleme).

## `uYedek.pas`

- `YedekAl(Tanim; Hedef; Yazici/geri çağrı; ...)` ve `GeriYukle(Tanim; Kaynak; HedefYol; ...)` gibi iki sade fonksiyon. Çıktı satır satır bir geri çağrıyla gelir (3b'deki `Ilerleme` örneği gibi, iptalde `False` döner). Kayıtlı tanım + gerekirse sorulan şifre parametre olarak girer.
- `gbak` alt işlemi: `CreateProcess`, kabuk (`cmd.exe`) **kullanılmaz** (yol/şifre kaçışı sorunu çıkmasın), standart çıktı ve hata çıktısı **boruya** (pipe) alınır. Boru okuması bloklanmasın: `PeekNamedPipe` ile bak, veri yoksa kısa bekle ve ilerleme geri çağrısını çağır (böylece İptal ve pencere çalışır). Pencere gizli çalışır (konsol penceresi açılmaz).
- Argümanlar: yedek için `-b -v`; geri yükleme için `-c -v`. Yol ve dosya adları tırnaklanır (boşluk, Türkçe karakter). Çıktının kodlaması (OEM/ANSI) Türkçe karakterli bir yolla **ölçülsün**, bozuk görünüyorsa doğru kodlama seçilsin ve raporda yazılsın.
- **İptal:** alt işlem `TerminateProcess` ile durdurulur, hedef dosya (yedekte `.yarim`, geri yüklemede yarım oluşmuş veritabanı) **silinmez**; kullanıcıya "Yarım dosya şurada duruyor, kullanılamaz; gerekirse elle silin" denir (kural 6).
- **Çıkış kodu ve hata cümleleri:** çıkış kodu 0 değilse hata. Gbak çıktısındaki sık hatalar tr/en/de anlaşılır cümleye çevrilir, ham çıktı "Ayrıntı"da kalır (CLAUDE.md Bölüm 6, madde 7). En az: sunucuya bağlanılamadı, kullanıcı/şifre hatalı, kaynak veritabanı bulunamadı, **hedef veritabanı zaten var**, yedek dosyası açılamadı/yazılamadı (klasör yok, disk dolu, dosya başka programda açık), yedek dosyası geçerli değil/bozuk, sürüm (ODS) uyumsuzluğu ("bu yedek bu sunucu sürümünde geri yüklenemez" gibi sade cümle). Tanınmayan hata için genel cümle + Ayrıntı. Eşleme gbak çıktısındaki metne bakar (`uBaglanti.MetindenCevir` gibi), `uYedek` içinde.
- Çıkış kodu 0 ama çıktıda `WARNING`/`warning` varsa uyarı olarak özete eklenir.
- `gbak -z` ile bulunan gbak sürümü "Ayrıntı"da gösterilir (sunucu 2.5 iken 5.0 gbak çalıştığını kullanıcı/sahibi görebilsin).

## Doğrulama (zorunlu)

Yeni test: `Test\YedekTest.dpr` + `Test\YedekTestDerle.bat` (`AktarTest`/`DDLTest` gibi; gömülü 5.0.4, geçici veritabanı kendi oluşturur; dosya silme yok, artıkları `_arsiv`e taşı). `gbak.exe`'yi test için de `istemci\` yanından kullan; gömülü ortamda `gbak` çalışmıyorsa nedenini ve çözümü rapora yaz, tahmin etme.

1. **Tam tur:** tablolar (Türkçe karakterli veri, metin ve ikili BLOB, NUMERIC, TIMESTAMP, kısıtlamalar), generator (değeri yedekte korunuyor mu), prosedür/trigger, view içeren geçici veritabanı yedeklenir, `.fbk` oluşur (boyut > 0), **yeni dosyaya** geri yüklenir, geri yüklenen veritabanına bağlanılır (`uBaglanti.FbBaglan` ile) ve tablolar, satır sayıları, bir BLOB değeri, generator değeri, metadata (`uMetadata` ile ad listeleri) **aynı** çıkar.
2. **Hedef var:** geri yükleme var olan bir veritabanı dosyasına yapılırsa gbak hata verir, dosyanın **boyutu ve içeriği değişmez** (bayt karşılaştır), anlaşılır cümle çıkar.
3. **Yedek hedefi var:** onay mantığı: var olan `.fbk` için `.yarim` yöntemi doğru çalışıyor (başarıda yer değiştirir, başarısızlıkta eski yedek **dokunulmadan** kalır, `.yarim` silinmez). Onay penceresini çağıran kısım testte atlanır, mantık fonksiyonu test edilir.
4. **Şifre güvenliği:** oluşturulan komut satırı metni şifreyi **içermez**; alt işlem ortamında `ISC_PASSWORD` vardır; kendi sürecimizin `ISC_PASSWORD` ortam değişkeni sonrasında **boş**tur.
5. **Hatalar** (tr/en/de anlaşılır cümle + Ayrıntı): olmayan kaynak veritabanı, olmayan klasöre yedek, geçersiz/bozuk `.fbk` (örneğin rastgele metin dosyası), olmayan kullanıcı/şifre (gömülü ortamda denenebiliyorsa; denenemiyorsa "denenmedi" yaz, çıktı örneği sunucu testlerine bırak), sürüm uyumsuzluğu (denenebiliyorsa). Her çeviri için ham metin → cümle eşlemesini birim düzeyinde test et (gbak çıktısı örnek metinleriyle).
6. **İptal:** orta büyüklükte veritabanında (birkaç yüz MB gerekmez, yeterince satırlı geçici veritabanı; alt işlem birkaç saniye sürsün) iptal edilince alt işlem durur, `False` döner, hedef dosya silinmez.
7. **Pencere/Olay yönetimi:** yeni dfm'lerde tüm olay yöneticileri dolu, boş olay yok; üç dil dosyasında yeni anahtarlar eşit.
8. **Mevcut testler geçmeli:** `DDLTest` (146), `SorguTest` (80), `BaglantiDosyasiTest` (52), `MetadataTest`, `AktarTest` (70). `Derle.bat` hatasız.
9. Programı derle, arayüzü kendin dene; **denemediğini "denemedim" diye açıkça yaz.** Özellikle: sağ tık menüsünün görünürlüğü, iki mod arasında geçiş, Seç... pencereleri, canlı çıktı, İptal, Almanca yazıların sığması, şifre sorma penceresi (kayıtlı olmayan bağlantı).

**Bitiş ölçütü:** Geçici veritabanı yedeklenip yeni dosyaya geri yükleniyor, geri yüklenen veritabanına bağlanıp aynı tablolar açılıyor; var olan veritabanının üzerine yazma mümkün değil; şifre komut satırında görünmüyor; iptal çalışıyor. 2.5.9 ve 5.0.4 sunucu denemesini sahibi yapar.

## Rapor ve bitiş

- `ASAMA3C_RAPOR.md` (Türkçe, kısa): ne yapıldı, ne test edildi (sayılarla: kontrol sayısı, süre, dosya boyutları), neler eksik kaldı, bilinen sınırlar, menü madde sayısı (yedi), `gbak -z` sürümü ve sürüm uyumu gözlemi, çıktı kodlaması bulgusu, sahibinin elle deneme listesi, sahibinden bekleyenler.
- **Sahibinin sunucu testleri için komutlar** raporun sonunda: önce `Test\YedekTestDerle.bat`, sonra ortam değişkenleriyle (`FBTEST_SUNUCU`, `FBTEST_PORT`, `FBTEST_KLASOR`, `FBTEST_KULLANICI`, `FBTEST_SIFRE`, `FBTEST_CIKTI`; `AktarTest`'teki gibi) çalıştırma. Sunucu denemelerinde özellikle: (a) 2.5.9 sunucudan yedek (5.0 gbak ile), (b) o yedeği 2.5.9 sunucuda **yeni** dosyaya geri yükleme, (c) 5.0.4 için aynısı, (d) yanlış şifre, (e) sürüm uyumsuzluğu cümlesi. Hangi sürüm çiftinin çalışıp çalışmadığı sahibinin raporuna girecek.
- `CLAUDE.md` Aşama 3 kutularını **işaretleme** (sahibi onaydan sonra işaretletir). 3d'ye **geçme**; sahibinin onayı beklenir.
