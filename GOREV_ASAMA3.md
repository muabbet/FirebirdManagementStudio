# Görev: Aşama 3, Yönetim Özellikleri

Bu görev, **Delphi/RAD Studio 12 ve gerçek Firebird sunucuları olan makinede** çalışan ajan içindir. Aşama 1, 1b ve 2 sahibi tarafından onaylandı ve `main`'e birleştirildi.

**Önce `CLAUDE.md` dosyasının tamamını oku** (özellikle Bölüm 3, 6, 9, 10). Sonra `ASAMA2C_RAPOR.md` ve `ASAMA2B_RAPOR.md` dosyalarını oku.

## Çalışma düzeni

- Dal: her alt aşama için `main`'in son halinden `asama3a`, `asama3b` vb. adlı yeni dal aç. `main`'e yazma.
- **Bu görev dört alt aşamadır (3a, 3b, 3c, 3d). Her alt aşama ayrı dalda, ayrı raporla biter (`ASAMA3A_RAPOR.md` vb.). Sahibi onaylamadan sonrakine geçme.** Birleşik büyük bir dal açma.
- Tüm yanıt ve rapor Türkçe. Her yeni yazı için üç dil dosyası (tr, en, de) güncellenir. Dosya silme yok (`_arsiv`). Yeni bileşen yok (listede olmayan hiçbir şey eklenmez). Kod sade kalsın (CLAUDE.md Bölüm 3): düğmenin `OnClick`'i işi yapan unit fonksiyonunu doğrudan çağırır, formlarda sabit yazı yok, sınıf bildiriminde alanlar prosedürlerden önce.
- Belirsiz bir şey olursa tahmin etme, sahibine sor.
- Sahibinin Firebird 2.5.9 ve 5.0.4 sunucu bağlantıları gerçek veridir: **orada `insert`/`update`/`delete`/`drop`/kullanıcı silme deneme.** Yalnızca geçici veritabanında dene. Sunucu şifresi sahibindedir; sunucu testlerini (3050/3051) sahibi kendi penceresinde çalıştırır. Ajan şifre tahmin etmez, gömülü 5.0.4 ve geçici veritabanıyla ölçer, sunucu testleri için komutları rapora yazar.
- Tehlikeli işlemler (silme, geri yükleme ile üzerine yazma, kullanıcı silme, yetki geri alma) **her zaman** ne olacağını açıkça yazan onay penceresi ister (`uOnay.pas` kullan). Sessiz ya da otomatik yok.
- Yeni unit gerekiyorsa aşağıda adı verildi. Mimari kuralı: sürüme, Windows'a veya dış programa (`gbak`) bağlı her şey kendi unit'inin arkasında.

> Aşama 2'den devreden küçük işler `GOREV_ASAMA3A.md` içinde.

---

# Aşama 3a: `uDDL.pas` (Script üretimi ve metadata çıkarma)

Ayrıntılı görev belgesi: **`GOREV_ASAMA3A.md`** (ajan o dosyayla çalışır; burada tekrar yazılmadı). Özet: Adım 1 tek nesne için "Script üret" (tablo, view, prosedür, generator), Adım 2 bütün veritabanının metadata çıkarımı (IBExpert "Extract Metadata" gibi: dosya veya pano, seçenekler, hepsi birden).


---

# Aşama 3b: Veri dışa aktarma

**Karar (sahibi verdi): yalnızca CSV.** Ek bileşen yasak olduğu için `.xlsx` yazılmaz. CSV UTF-8 BOM'lu olur, ayraç kullanıcı ortamına göre `;` veya `,` seçilir, Excel'de çift tıkla açılır. `.xlsx` istenirse ayrıca karar verilir.

## Kapsam

- Sonuç ızgarasındaki (sorgu sonucu veya tablo verisi) **tüm** satırlar dışa aktarılır, yalnızca ekrandaki 500 satır değil. Parça parça çekme mantığı `uSorgu.pas`'te, dışa aktarma da yeni küçük `uAktar.pas` içinde olsun; formda iş yok. Büyük sonuçta bellekte biriktirme, satır satır dosyaya yaz.
- İlerleme ve iptal: uzun sürerse kullanıcı görür (satır sayısı), durdurabilir. Donma yok (Aşama 2'deki gibi, ana iş parçacığı kilitlenmesin; nasıl yapıldığına bak, aynı yöntemi kullan).
- Alan kuralları: ayraç/tırnak/satır sonu içeren değer tırnaklanır, `NULL` boş alan olur, tarih biçimi ISO (`yyyy-mm-dd hh:nn:ss`), BLOB yazılmaz (boş bırakılıp rapora/mesaja "BLOB alanları atlandı" notu).
- Dosya yeni bir ad olmalı ya da var olan dosyanın üzerine yazılacaksa **onay penceresi** çıkar (kural 6).
- Arayüz: sonuç alanının üstündeki mevcut düğmelerin yanına "Dışa aktar" (tek düğme). Araç çubuğuna ekleme (5-6 düğme sınırı), karar vermeden önce mevcut düğmeleri say.

**Bitiş ölçütü:** 100.000 satırlık bir tablonun sonucu CSV'ye aktarılıp Excel'de açılıyor, Türkçe karakterler bozulmuyor.

---

# Aşama 3c: Yedek/geri yükleme (`gbak`)

Yeni unit: `uYedek.pas`. `gbak.exe`'yi **kendi çağırır** (Windows'a bağlı kısım bu unit'in arkasında).

## Kapsam

- **Yedek al:** kaynak veritabanı (açık bağlantıdan), hedef `.fbk` dosyası. Seçenekler en az: yok. Varsayılanlar makul (tam yedek). Ayar yığma yok.
- **Geri yükle:** `.fbk` > yeni veritabanı dosyası. **Var olan bir veritabanının üzerine yazma** varsayılan kapalıdır; açılırsa ayrı ve çok net bir onay penceresi ister (dosya adı, boyut, tarih yazılı). Daha güvenli seçenek önerilir: hedef dosya zaten varsa yeni ad iste.
- `gbak.exe` yolu: `fbclient.dll` ile aynı klasör/sürüm mantığıyla bulunur. Bulunamazsa kullanıcıdan seçtir (kısa pencere), seçimi saklama konusunda sahibine sor. Sürüm uyumuna dikkat: sunucu 2.5 iken gbak 5.0 çalıştırma gibi durumlarda `ODS` uyumsuzluğu olabilir, bunu sade bir cümleyle bildir (tr/en/de).
- **Şifre komut satırına yazılmaz.** `ISC_PASSWORD` ortam değişkeni ile iletilir (yalnızca o alt işlem için). Şifre DPAPI kayıtlı bağlantıdan alınır (Aşama 1b davranışı); kayıtlı değilse şifre sorulur.
- gbak çıktısı canlı olarak mesaj alanında gösterilir; ham çıktı "Ayrıntı"da saklanır. Çıkış kodu sıfır değilse anlaşılır hata cümlesi.
- Uzun sürer, arayüz donmaz; iptal edilebilir (iptalde yarım kalan hedef dosya silinmez, kullanıcıya haber verilir).
- Bağlantı: yedek sırasında açık bağlantı sorun değil; geri yüklemede hedef dosya bir açık bağlantıda kullanılıyorsa uyarılır.

**Bitiş ölçütü:** Geçici veritabanı yedeklenip yeni dosyaya geri yükleniyor, geri yüklenen veritabanına bağlanıp aynı tablolar açılıyor. 2.5.9 ve 5.0.4 sunucu denemesini sahibi yapar.

---

# Aşama 3d: Kullanıcı ve yetki yönetimi

Yeni unit: `uKullanici.pas`. Sürüme bağlı her şey burada.

**Önce ölç, sonra sahibine sor:** Firebird 2.5 ile 3.0+ arasında kullanıcı yönetimi çok farklıdır (2.5: Service API / `security2.fdb` ve `gsec`; 3.0+: SQL `CREATE USER`/`ALTER USER`/`DROP USER`, `SEC$USERS`). Hangi yolla ne yapılabildiğini kısa bir **ölçüm raporu** olarak yaz (FireDAC'ın hangi yöntemi destekledi, hangi sürümde ne oldu), sonra sahibinden onay al ve yazmaya geç. Ölçümde kullanıcı oluşturma/silme sunucuda yapılacaksa geçici kullanıcı adıyla (örn. `GECICI_TEST_01`) çalış, gerçek kullanıcılara dokunma.

## Kapsam (ölçüme göre daralabilir)

- Kullanıcı listesi (ad, ad-soyad, yönetici mi). **Şifre hiçbir yerde gösterilmez/saklanmaz** (CLAUDE.md Bölüm 10).
- Kullanıcı ekle, şifre değiştir, sil (silme için net onay).
- Yetki yönetimi: bir nesne üzerinde `GRANT`/`REVOKE` (tablo/view/prosedür) ve rol atama. Bu kısımda önce **mevcut yetkileri göster** (kimde ne var), sonra değiştirme. Yetki değişiklikleri script olarak önizlenir, kullanıcı onaylayınca uygulanır (Aşama 4'teki "önizleme ile toplu güncelleme" ruhuyla).
- Yetkisiz kullanıcı (örn. SYSDBA değil) için işlemler anlaşılır cümleyle reddedilir; menü o durumda gizlenmez ama net hata verir.
- Arayüz: tek yeni pencere ("Kullanıcılar ve yetkiler"), ağaçta sunucu/bağlantı sağ tık menüsünden açılır. Tek yol, kısa menü (Bölüm 1 ana ilke).

**Bitiş ölçütü:** Gömülü/geçici ortamda kullanıcı eklenip listeleniyor, bir tabloya `GRANT SELECT` verilip geri alınıyor. 2.5.9 ve 5.0.4 sunucu denemelerini sahibi yapar.

---

## Her alt aşama için ortak testler ve rapor

- Mevcut testler geçmeli: `SorguTest` (80 kontrol), `BaglantiDosyasiTest`, `MetadataTest`. Yeni özellik için ilgili yeni test eklenir.
- Programı derle (`Derle.bat`), kendin arayüzde dene ve denediklerini yaz; **denemediğini "denemedim" diye açıkça belirt** (önceki raporlardaki gibi).
- Üç dil dosyasında yeni anahtarlar eksiksiz mi, kontrol et (boş değer, eksik anahtar yok).
- `ASAMA3X_RAPOR.md`: ne yapıldı, ne test edildi (sayılarla), neler eksik kaldı, sahibinin elle deneme listesi, sahibinden bekleyenler (sunucu testleri).
- `CLAUDE.md` Aşama 3 kutularını **işaretleme** (sahibi onaydan sonra işaretletir). Bir sonraki alt aşamaya ya da Aşama 4'e **geçme**.
