# Aşama 3d-1 Raporu: Kullanıcılar (liste, ekle, sil, şifre, ad/soyad, yönetici, aktif/pasif)

Dal: `asama3d-1` (main `ddf6c48` üstünden). Yerel çalışma, itme/PR yok, `CLAUDE.md` kutularına dokunulmadı.
**Sunucu kipi (3.0 :3052, 4.0 :3053, 2.5 test kopyası :3054) denenmedi**: şifre bende yok. Yazma kodu henüz hiçbir gerçek sunucuda çalışmadı. Gerçek arayüz de elle denenmedi (bkz. bölüm 5).

## 1. Ne değişti

| Dosya | Değişiklik |
|---|---|
| `Kaynak\uMetadata.pas` | Salt okuma: `TKullaniciBilgisi`, `TKullaniciYetenekleri`, `KullaniciYetenekleri(Bag)`, `KullaniciListesiOku(Bag)` (3.0+ `SEC$USERS`; 2.5 `TFDIBSecurity.DisplayUsers`). Sürüm kararı yalnızca burada. |
| `Kaynak\uKullanici.pas` (yeni) | Yazma: `KullaniciEkle/Sil`, `SifreDegistir`, `AdSoyadDegistir`, `YoneticiAyarla`, `AktifAyarla`, kural kontrolleri, kayıtlı bağlantı şifresi güncelleme, ızgara bellek tablosu. |
| `Kaynak\fKullanicilar.pas/.dfm` (yeni) | Sekme (frame): bilgi satırı, "Yeni kullanıcı" düğmesi, ızgara, sağ tık menüsü (6 madde). |
| `Kaynak\fKullaniciDuzenle.pas/.dfm` (yeni) | Küçük pencere (ekle / şifre / ad-soyad). Tamam düğmesi doğrudan `uKullanici` yordamını çağırır. |
| `Kaynak\fAna.pas`, `uIkon.pas` | Şeritte Yönetim sekmesine tek "Kullanıcılar" düğmesi; sekme açma (bağlantı başına tek sekme); bağlantı kapanınca sekme kapanır; dil değişince yazılar yenilenir. |
| `Kaynak\uBaglanti.pas` | `FbSurucu` (2.5 listesi için aynı sürücü), `HataMetniniCevir`'e 3 yeni cümle. |
| `Diller\tr/en/de.json` | 60'ar yeni anahtar (üçü de 297 anahtar, yinelenen yok). |
| `FirebirdYonetici.dpr/.dproj` | Yeni unit'ler eklendi. |
| `Test\KullaniciTest.dpr`, `KullaniciTestDerle.bat` (yeni) | Test (bölüm 3). |

## 2. Kararlar ve davranış

- **SYSDBA:** yalnızca şifre. Silme, pasif, yönetici, ad/soyad: arayüzde menü kapalı **ve** `uKullanici` istisna fırlatır (büyük/küçük harf duyarsız).
- **Kendini silme/pasif yapma:** menüde kapalı, kodda da reddedilir.
- **Gömülü bağlantı (Sunucu boş):** düğme kapalı, araç ipucunda "Gömülü bağlantıda kullanıcı yönetimi yok…"; tüm işlevler de reddeder.
- **Kullanıcı adı:** `A-Z a-z 0-9 _ $`, en çok 31, büyük harfe çevrilir.
- **Şifre kaçırma tek yerde (`SqlMetni`).** FireDAC komutunda `ParamCreate/MacroCreate/ParamExpand/MacroExpand/EscapeExpand` kapalı. **Test kanıtladı:** `MacroExpand` kapatılmadan `&e!f` şifreden siliniyordu; kapatınca `Ab'c:d&e!f g{h}?i` aynen gidiyor (SELECT ile kanıtlandı; CREATE USER ile bağlanma denemesi sunucuda yapılacak).
- **Şifre gizleme:** komut önizlemesi `***`; sunucu hata metninde şifre geçerse `***` ile değiştirilir (hata sınıfı/kodu korunur).
- **Şifre uyarısı:** 3.0+ için 20 bayt, 2.5 için 8 karakter aşılırsa uyarı (engellemez); alt sınır yok.
- **Kendi şifresi:** 3.0+ `ALTER CURRENT USER SET PASSWORD`, 2.5 `ALTER USER kendi_adı PASSWORD`. Başarıdan sonra bağlantının bellekteki şifresi güncellenir; kayıtlı bağlantıda şifre saklanıyorsa "Kayıtlı bağlantı şifresi de güncellensin mi?" sorulur (Evet: DPAPI kaydı güncellenir; açık bağlantı etkilenmez).
- **Yönetici olarak ekleme:** önce `CREATE USER`, sonra ölçümde doğrulanan `ALTER USER … GRANT ADMIN ROLE`. İkincisi düşerse kullanıcı eklenmiş sayılır, pencere kapanır, uyarı gösterilir.
- **Onaylar:** silme (Hayır varsayılan), yönetici yapma (hem listeden hem ekleme kutusundan), pasif yapma; metinler görev belgesindeki gibi.
- **Hata cümleleri (`HataMetniniCevir`):** `335544352` → "Bu işlem için yetkiniz yok"; `336723990` → "Kullanıcı bulunamadı (ya da yalnızca yönetici başkalarını görebilir)"; metinde `PLG$SRP` → "Kullanıcı yönetmek için SYSDBA ya da yönetici olmalısınız". Üç dilde.
- **"Kullanıcı zaten var" hatası:** sunucuda üretemediğim için çeviriye **gerçek kodu bağlamadım** (tahmin yok). Onun yerine `KullaniciEkle`, listede ad varsa kendi cümlesini verir ("'X' adında bir kullanıcı zaten var"). Test, sunucunun gerçek hatasını `BILGI (sunucunun gercek "zaten var" hatasi…)` satırında yazar; sahibi bu satırı bana iletirse koda bağlarım. Aynı şekilde "olmayan kullanıcıyı silme" ham hatası da yazılır.
- **Ikon:** `Ikonlar\svg` içinde kullanıcı ikonu yok. Geçici olarak liste ikonu (`IKON_KULLANICI = IKON_GENERATOR`) kullanıldı. **Sahibine bildirim:** uygun bir ikon seçilirse `uIkon.pas`'a eklenecek.
- Ağaç sağ tık menüsüne ekleme yapılmadı. Menü: Şifre değiştir, Ad/soyad düzenle, Yönetici yap/kaldır (3.0+), Aktif/Pasif yap (3.0+), Yenile, Sil.
- Küçük "hile": `fKullanicilar` içinde sağ tıkta satırı seçmek için `TDBGrid`'in korunmuş `Row` özelliğine `TSatirErisimi` ile erişildi (tek satır, yorumlu).

## 3. Test: `Test\KullaniciTest.dpr`

Derleme: `Test\KullaniciTestDerle.bat`. Üç bölüm: **A** saf kurallar (ad doğrulama, kaçırma/gizleme, uyarı, hata cümleleri, kayıtlı şifre, özel karakter), **B** gömülü kip reddi, **C** sunucu (okuma her sunucuda; yazma yalnızca yerel 3052/3053/3054 + `FBTEST_YAZMA=1`, başka portta, 3050/3051 dahil, kod reddeder). Yazma bölümü: ekle→listede→ilk şifreyle bağlan, aynı ad (zaten var), bozuk girdiler, şifre değiştir (eski bağlanamaz/yeni bağlanır), özel karakterli ve Türkçe harfli şifre, özel karakterli ad/soyad, kendi şifresini değiştirme, yönetici olmayanla ekleme/silme/başkasının şifresi (doğru anlaşılır cümle), liste yalnızca kendini gösterir, ad/soyad, yönetici yap/kaldır + yönetici bağlantısıyla ekleme/silme, ekleme sırasında yönetici kutusu, pasif/aktif, silme, SYSDBA reddi (4 işlem), SYSDBA şifresini aynı değerle yeniden verme, temizlik.

**Yapılan denemeler (bu makinede):**
- `KullaniciTest` yerel kip: **36 kontrol, 0 hata** (bölüm A + B).
- `SeritTest`, `SorguTest`: 0 hata. `DDLTest`, `AktarTest`: 0 hata (`FBTEST_SIFRE=masterkey` ile).
- `YedekTest`: **5 hata, ama değişikliğimden bağımsız**: `ddf6c48` (benim değişikliklerim yok) taşınarak aynı şekilde denendi, aynı 5 hata çıktı.
- **Ortam uyarısı:** bu çalışma ağacının `istemci` klasöründe `engine13.dll` yok; "gömülü" bağlantı fiilen yerel 2.5.9 hizmetine gidiyor (testler `Surum 2.5.9` yazdı, bu yüzden "gömülü kip" gerçek gömülü 5.0.4 değil, boş şifre reddediliyor). Gerçek gömülü motorla denemek için `istemci`ye `engine13.dll` konmalı.

## 4. Sahibinin çalıştıracağı sunucu testi

Derleme (bir kez): `cd Test; .\KullaniciTestDerle.bat`. Sonra 3.0 için (4.0 için `3053`, 2.5 test kopyası için `3054`; `FBTEST_YOL` o sunucudaki var olan bir veritabanı):

```powershell
Remove-Item Env:FBTEST_* -ErrorAction SilentlyContinue
$env:FBTEST_SUNUCU = "127.0.0.1"
$env:FBTEST_PORT = "3052"
$env:FBTEST_YOL = "C:\Firebird\Firebird30\gecici.fdb"
$env:FBTEST_KULLANICI = "SYSDBA"
$env:FBTEST_SIFRE = "SIFRENIZ"
$env:FBTEST_YAZMA = "1"
$env:FBTEST_CIKTI = "$env:TEMP\kullanicitest_30.txt"
& "C:\Baris\Kodlar\FirebirdYonetici\.claude\worktrees\vibrant-snyder-9e4ef8\bin\Win64\Release\KullaniciTest.exe"
```

Çıktı dosyasını (`kullanicitest_30.txt`, `_40`, `_25`) bana ilet. `FBTEST_YAZMA` vermeden 3050/3051'e karşı yalnızca okuma testi çalışır (`FBTEST_YAZMA=1` olsa bile bu portlarda yazma kapalı kalır).

## 5. Denenmeyenler (açıkça)

- Yazma işlemlerinin hiçbiri sunucuda denenmedi (CREATE/ALTER/DROP USER); 2.5'te `ALTER USER kendi_adı` yolu ve 2.5 Services listesi bu çalışmada çalıştırılmadı (ölçüm raporunda 2.5.9 listesi çalışmıştı).
- **Gerçek arayüz elle denenmedi:** uygulama açıldı ve çöktürmeden başladı (ana form, şerit, yeni düğme) ama bilgisayar kontrolü için uygulama erişimi verilemedi. Sahibine arayüz deneme listesi:
  1. Şeritte Yönetim > "Kullanıcılar": bağlantı yokken/gömülüde kapalı mı, gömülüde fare üstünde gerekçe çıkıyor mu?
  2. Sunucu bağlantısında tıkla: sekme "Kullanıcılar (ad)", üstte bilgi satırı, liste; ikinci tıklamada aynı sekme öne gelir mi?
  3. 2.5'te Yönetici/Aktif sütunları yok, 3.0+'da var mı? Sağ tık menüsünde 2.5'te yönetici/aktif maddeleri gizli mi?
  4. SYSDBA satırında yalnızca "Şifre değiştir" ve "Yenile" açık mı? Kendi satırında Sil/Pasif kapalı mı?
  5. Yeni kullanıcı: boş şifre, farklı şifre, geçersiz ad hata cümleleri; Almanca/İngilizce yazıların kesilmeden sığması; pencere yüksekliği.
  6. Dil değişince sekme başlığı, sütunlar, menü ve "Evet/Hayır" değerleri yeni dile geçiyor mu?
  7. Kendi şifreni değiştirince "Kayıtlı bağlantı şifresi de güncellensin mi?" soruluyor mu?
  8. Ayrıntı düğmesi hata penceresinde ham mesajı açıyor mu?

## 6. Moderatör sunucu testinden sonra düzeltmeler (3.0.14 ve 4.0.7: 71 kontrol, 3 hata)

1. **"Kullanıcı zaten var" çevirisi:** hata `336723987` ("add record error") yetkisizlik hatasıyla aynı kodu taşıyor. Eşleme artık **metne** göre: `no permission` + `PLG$SRP_VIEW` → "yönetici olmalısınız"; `violation of PRIMARY or UNIQUE KEY` + `PLG$SRP` → "'X' adında bir kullanıcı zaten var" (ad, hata metnindeki `"PLG$USER_NAME" = '...'` değerinden alınır; bulunamazsa genel cümle `ERR_KULLANICI_VAR_GENEL`). Üç dilde. 2.5 için eşleme **eklenmedi** (metni ölçülmedi); test 2.5'te yalnızca ham mesajı ve çevirisini BILGI satırına yazar. Testte iki yeni kontrol (3.0 metni → doğru cümle; ad yoksa genel cümle) ve sunucuda "zaten var" çevirisinin "yönetici olmalısınız" OLMADIĞI kontrolü var.
2. **Türkçe harfli şifre:** kararım **ASCII dışı şifreyi reddetmek** (`ERR_SIFRE_ASCII`, üç dilde; `uKullanici.SifreyiDogrula`, hem ekleme hem şifre değiştirmede). Neden: önerilen UTF8 yönetim bağlantısı denemesini yapamadım (sunucu şifresi bende yok), moderatörün ölçümü ise sorunu doğruladı, en sade çözüm reddetmek. Test güncellendi: Türkçe şifre reddedilir, eski şifre bozulmaz, zincir ASCII şifreyle (`SIFRE_OZEL`) devam eder. Kalan iki hatanın (kendi bağlantısı, yönetici bağlantısı) Türkçe şifrenin zincirleme sonucu olduğunu varsayıyorum; sunucuda yeniden koşulunca doğrulanacak. İleride UTF8 denemesi istenirse sade yol: kullanıcı yönetimi komutları için ayrı UTF8 bağlantısı.
3. **`TSatirErisimi`:** `uSonucGrid.pas` ve başka yerde sağ tıkta satır seçme yolu yok, bu yüzden mevcut tek satırlık erişim kaldı (korunmuş `Row` özelliği, `TDBGrid.MouseCoord` ile satırı bulmanın standart yolu).

Yerel `KullaniciTest`: 38 kontrol, 0 hata. Uygulama derleniyor. Sunucu testlerini moderatör yeniden çalıştıracak.

## 7. Üçüncü tur: 3.0'da yönetici bağlantısı ve bilinen sınırlar

- **Test düzeltmesi:** 3.0.14'te SYSDBA olmayan, yönetici yapılmış kullanıcı kullanıcı yönetebilmek için `ROLE RDB$ADMIN` ile bağlanmak zorunda (moderatör teşhisi). Testte yönetici bağlantısı `RoleName=RDB$ADMIN` ile açılıyor (`BaglanRolle`; uygulamanın bağlantı tanımına rol alanı EKLENMEDİ). Sunucu sonucu moderatörün yeniden koşusuyla doğrulanacak (yerelde denenemedi).
- **Karar: ASCII dışı şifre reddedilir** (Türkçe harf vb.). Neden: 3.0 ve 4.0 ölçümünde Türkçe harfli şifre ayarlanıyor ama o şifreyle bağlanılamıyor (karakter seti uyumsuzluğu); UTF8 yönetim bağlantısı denenmedi (sunucu şifresi yok). En sade çözüm reddetmek: `ERR_SIFRE_ASCII`, üç dilde.
- **Bilinen sınırlar:** (1) Uygulama bağlantısı rol belirtmediği için, SYSDBA olmayan bir yönetici 3.0'da kullanıcı eklerse sunucu `PLG$SRP_VIEW` yetki hatası verir ve metinden SYSDBA-olmayan-yönetici ile gerçek yetkisizlik ayrılamadığından cümle "SYSDBA ya da yönetici olmalısınız" olarak kalır; çözüm SYSDBA ile bağlanmaktır (ileride bağlantıya rol alanı eklenebilir). (2) 2.5'te "zaten var" ham mesajı ölçülmedi, çevirisi yok (listeden önce kontrol edilir). (3) Yerel "gömülü" bağlantı bu makinede gerçek gömülü değil (bkz. bölüm 3).
