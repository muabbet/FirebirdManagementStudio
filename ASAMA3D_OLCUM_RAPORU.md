# Aşama 3d Ölçüm Raporu: Kullanıcı ve Yetki Yönetimi

Tarih: 2026-10-25. Dal: `asama3d-olcum`. Bu rapor **ölçüm ve öneridir**; özellik kodu (`uKullanici.pas`, form) yazılmadı.
Sunucu kipi (3.0 / 4.0 / 2.5 / gerçek 5.0 sunucusu) **denenmedi**: şifre bende yok. Yalnızca gömülü Firebird 5.0.4 ile denendi (bölüm 4). Sunucu sonuçlarını sahibi çalıştıracak (bölüm 7).

## 1. Önemli bulgular (kısa)

1. **Görev metnindeki bir varsayım yanlış çıktı:** Firebird 2.5'te SQL ile kullanıcı yönetimi **vardır**. `CREATE USER`, `ALTER USER`, `DROP USER` 2.5'te eklendi ([2.5 Language Ref. Update](https://firebirdsql.org/refdocs/langrefupd25-security-sql-user-mgmt.html)). 2.5'te olmayan şey **SQL ile listeleme**: `SEC$USERS` 3.0'da geldi. 2.5'te liste yalnızca Services API (gsec'in kullandığı yol) ile alınır ([gsec belgesi](https://firebirdsql.org/file/documentation/html/en/firebirddocs/gsec/firebird-gsec.html)).
2. **Kullanıcılar veritabanına değil sunucuya aittir.** Kullanıcılar sunucunun güvenlik veritabanındadır (3.0+: varsayılan `security3.fdb`, 4.0+: `security4.fdb`, 5.0: `security5.fdb`; veritabanı başına `databases.conf` ile başka güvenlik veritabanı da verilebilir: [3.0 sürüm notları](https://firebirdsql.org/file/documentation/release_notes/html/en/3_0/rnfb30-security.html)). Yani "Kullanıcılar" ekranı, bağlı olunan veritabanının değil **o sunucunun** kullanıcılarını gösterir. Arayüz bunu açıkça yazmalı.
3. **FireDAC'ın hazır bileşeni var ama eksik:** `TFDIBSecurity` (`FireDAC.Phys.IBBase`, RAD Studio 12 kaynağında doğrulandı). `AddUser/ModifyUser/DeleteUser/DisplayUsers` var. Ama yalnızca eski Services API alanlarını bilir: kullanıcı adı, şifre, ad, orta ad, soyad, userid, groupid, rol. **Yönetici (RDB$ADMIN) bayrağı, aktif/pasif, eklenti (plugin), etiket (TAGS) yok.** Kaynak: `source\data\firedac\FireDAC.Phys.IBWrapper.pas` (`TIBSecurityValue`, `C_Value2IB`). Bu yüzden 3.0+ için asıl yol SQL olmalı.
4. **Gömülü kip kullanıcı yönetimini sınamak için işe yaramaz.** Gömülü 5.0.4'te `istemci` klasöründe `security5.fdb` yok: `SEC$USERS` ve `CREATE USER` "security5.fdb açılamadı" hatası verir. Ayrıca gömülü kipte şifre/kullanıcı doğrulanmıyor: var olmayan `FBY_TEST` kullanıcısı bağlanabildi (doğrulama yöntemi "User name in DPB"). Kullanıcı yönetimi testi **sunucu kipinde** olmak zorunda. GRANT/REVOKE/rol/DDL yetkisi ise gömülüde sınanabildi (bölüm 4).
5. **Parola metinde SQL içinde gider.** `CREATE USER ... PASSWORD '...'` bir SQL metnidir. FireDAC `ExecSQL` metinde `:ad`, `&makro`, `!makro` gibi şeyleri parametre/makro sayabilir, `'` işaretini kaçırmak gerekir. Şifrede `:` `&` `'` `!` varken ne olduğunu bu ölçümde **denemedim**; kodu yazarken ilk test bu olmalı (ParamCreate/MacroCreate kapatılması gerekebilir).

## 2. Sürüm tablosu: işlem x sürüm

"Belge" = bu raporda bağlantısı verilen kaynak. "Ölçüm" = bu oturumda gömülü 5.0.4 ile gördüm. "Sahibi denesin" = sunucuda ölçülecek, henüz bilmiyoruz.

| İşlem | 2.5 | 3.0 | 4.0 | 5.0 |
|---|---|---|---|---|
| Kullanıcı listesi | Yalnızca Services API (`TFDIBSecurity.DisplayUsers`): ad, orta ad, soyad. SQL yok. | `SELECT ... FROM SEC$USERS` (+ `SEC$USER_ATTRIBUTES`) | aynı | aynı |
| Ekle | `CREATE USER u PASSWORD 'p' [FIRSTNAME..] [GRANT ADMIN ROLE]` | + `ACTIVE/INACTIVE`, `TAGS`, `USING PLUGIN` | aynı (seçenekler her sırada) | aynı |
| Sil | `DROP USER u` | `DROP USER u [USING PLUGIN p]` | aynı | aynı |
| Şifre değiştir (yönetici) | `ALTER USER u PASSWORD 'p'` | aynı | aynı | aynı |
| Kendi şifresini değiştir | `ALTER USER kendi_adi PASSWORD 'p'` (belge: yönetici olmayan kullanıcı kendi hesabını değiştirebilir). Sahibi denesin. | `ALTER CURRENT USER SET PASSWORD 'p'` | aynı | aynı |
| Ad/soyad | `ALTER USER .. FIRSTNAME/MIDDLENAME/LASTNAME` (en çok 32 karakter) | aynı | aynı | aynı |
| Yönetici yap/kaldır | `ALTER USER u GRANT/REVOKE ADMIN ROLE`. Listede görmek: Services API'de yok, gsec `display` gösterir (FireDAC göstermez). | `SEC$USERS.SEC$ADMIN` | aynı | aynı |
| Aktif / pasif | Yok | `ACTIVE`/`INACTIVE` (`Legacy_UserManager` yok sayar) | aynı | aynı |
| Eklentiler | Yok | `Srp`, `Legacy_Auth`, `Win_Sspi` (Win_Sspi = Windows doğrulaması); kullanıcı yönetimi eklentisi (`UserManager`) | 4.0'da varsayılan `Srp256` | aynı |
| Kullanıcı adı | büyük harf, en çok 31 | kimlik kuralları, tırnaklı ad büyük/küçük harf duyarlı, en çok 63 | aynı | aynı |
| Kim kullanıcı yönetebilir | SYSDBA; güvenlik veritabanında RDB$ADMIN rolü olan | SYSDBA; RDB$ADMIN (güvenlik veritabanında); Windows Administrator (AUTO ADMIN MAPPING) | + `USER_MANAGEMENT` sistem ayrıcalığı olan rol | aynı |
| Yönetici olmayan ne yapar | kendi bilgisi | yalnızca `ALTER USER` kendi hesabında; `SEC$USERS`'ta yalnızca kendi satırını görür | aynı | aynı |
| Tablo/view/prosedür yetkisi | `GRANT SELECT/INSERT/UPDATE/DELETE/REFERENCES`, `EXECUTE`, sütun yetkisi, `WITH GRANT OPTION` | aynı + `USAGE` (generator, exception, domain vb.) | aynı | aynı |
| Rol | `CREATE ROLE`, `GRANT rol TO kullanıcı` (RDB$USER_PRIVILEGES `M`) | aynı | + rolü role vermek ([4.0 notları](https://firebirdsql.org/file/documentation/release_notes/html/en/4_0/rlsnotes40.html)) | aynı |
| DDL yetkisi (`GRANT CREATE TABLE ..`) | Yok (bilgim; sahibi 2.5'te denesin) | var (RDB$USER_PRIVILEGES `C`/`L`/`O`; 3.0 sunucuda sahibi doğrulasın) | aynı | **Ölçüm: çalıştı** |
| Sistem ayrıcalıkları (`SET SYSTEM PRIVILEGES TO ..`) | Yok | Yok | **Var** (4.0 notları: "extensive system privileges") | Var; liste büyük (örn. `PROFILE_ANY_ATTACHMENT` 5.0 listesinde, [5.0 Güvenlik](https://firebirdsql.org/docs/chunk/en/refdocs/fblangref50/fblangref50-security.html)). **Ölçüm: `USER_MANAGEMENT` rolü oluştu.** |
| Yetkileri okuma | `RDB$USER_PRIVILEGES` | aynı | aynı | aynı, `RDB$GRANT_OPTION` 2 = WITH ADMIN OPTION (rol üyeliği) ([5.0 ek D](https://firebirdsql.org/docs/chunk/en/refdocs/fblangref50/fblangref-appx04-userprivs.html)) |

`RDB$USER_PRIVILEGES` harfleri: `S` select, `I` insert, `D` delete, `U` update, `R` references, `X` execute, `G` usage, `M` rol üyeliği, `C`/`L`/`O` DDL create/alter/drop. Alıcı türü (`RDB$USER_TYPE`) 8 = kullanıcı, 13 = rol, diğerleri nesne (görünüm, prosedür). Nesne türü (`RDB$OBJECT_TYPE`) 0 tablo, 1 görünüm, 5 prosedür, 13 rol, 14 generator, 15 fonksiyon, 18 paket ([ek D](https://firebirdsql.org/docs/chunk/en/refdocs/fblangref50/fblangref-appx04-userprivs.html)). Önemli: bu tablo "kim, kime, neyi verdi" kaydıdır; motorun asıl denetimi `RDB$SECURITY_CLASSES` ile olur. Yönetim ekranı için yeterli, "etkin yetki hesaplayıcı" olarak kullanılmamalı. Not: tabloya veya kullanıcıya verilen `PUBLIC` yetkisi ayrıca görünür; rol yetkisi kullanıcıya yazılmaz, rolde durur.

Kullanıcı ayrıntıları kaynakları: [5.0 Kullanıcı yönetimi SQL](https://firebirdsql.org/docs/chunk/en/refdocs/fblangref50/fblangref50-security-user.html), [3.0 Kullanıcı yönetimi SQL](https://firebirdsql.org/file/documentation/chunk/en/refdocs/fblangref30/fblangref30-security-user.html), [5.0 Güvenlik tabloları](https://firebirdsql.org/docs/chunk/en/refdocs/fblangref50/fblangref50-appx06-sectables.html). Parola uzunluğu: Srp için etkin 20 bayt ([3.0 notları](https://firebirdsql.org/file/documentation/release_notes/html/en/3_0/rnfb30-security.html)); 20 bayttan uzun şifre sessizce kısalıyor gibi davranır, arayüzde uyarı gerekebilir. `Legacy_Auth` 8 karakter.

Okunamayan veya doğrulanamayan şeyler: 5.0 `SEC$USERS` kolon listesi belge sayfasından alınamadı. Kolon adlarını bilgi olarak yazıyorum (`SEC$USER_NAME, SEC$FIRST_NAME, SEC$MIDDLE_NAME, SEC$LAST_NAME, SEC$ACTIVE, SEC$ADMIN, SEC$PLUGIN, SEC$DESCRIPTION`); ölçüm programı `SELECT *` ile gerçek kolon adlarını da yazar, sunucuda doğrulanacak.

## 3. FireDAC'ın kendi yolu ve CLAUDE.md Bölüm 5

- `TFDIBSecurity`, Delphi/FireDAC'ın parçasıdır (Bölüm 2: veritabanı erişimi FireDAC). Bölüm 5 "üçüncü parti bileşen" için konmuş: ücretsiz, kaynak açık, bakımlı, kendimiz yazamıyor olmalıyız. FireDAC üçüncü parti değildir, ücretli bileşen değildir, RAD Studio 12 ile gelir, kaynak koduna zaten sahibiz. Bu yüzden **Bölüm 5 ihlali olmaz** ve izin listesine eklenecek bir şey yoktur. Ek koşul: kullanılırsa `uKullanici.pas` arkasında kalır (Bölüm 4 kuralı), formda görünmez.
- Yedekleme bölümünde (`uYedek.pas`) FireDAC servisleri yerine `gbak.exe` çağrıldığı için örnek yok. Servis API'si için ayrı bir `TFDPhysFBDriverLink` gerekir ve gömülü denemede ikinci sürücü bağlantısı sorunsuz çalıştı (bölüm 4). Konsol programında `FireDAC.ConsoleUI.Wait` eklemek gerekti (ana uygulamada `VCLUI.Wait` var).
- Öneri: **3.0+ yalnızca SQL** (tek yol, tam özellik). **2.5'te ekle/sil/şifre SQL ile; yalnızca listeleme için** `TFDIBSecurity.DisplayUsers`. Gerekçe: Kural 7 (sıradan çözüm) ve tek yol ilkesi; Services'i her yerde kullanmak 3.0+'da aktif/pasif, yönetici bayrağı ve eklentiyi gösteremez.
- `gsec.exe`: `istemci` klasöründe yok, 3.0+'da da önerilmiyor. Kullanmayı önermiyorum (dışarıdan komut satırı ayrıştırmak ve şifreyi komut satırına yazmak gerekir).

## 4. Gömülü Firebird 5.0.4 ile ne denendi (ve ne denenemedi)

Komutlar: okuma (varsayılan) ve `FBTEST_YAZMA=1` (yalnızca programın kendi açtığı geçici veritabanında). Tam çıktılar (not klasörü): `kullaniciolcum_gomulu_okuma.txt`, `kullaniciolcum_gomulu_yazma.txt`.

Çalıştı (gömülü 5.0.4):
- Bağlanma, sürüm `5.0.4`, `CURRENT_USER`/`CURRENT_ROLE`, `MON$DATABASE.MON$OWNER`, `MON$SEC_DATABASE` ("Default"), `MON$AUTH_METHOD` ("User name in DPB").
- `RDB$USER_PRIVILEGES` özeti: 1142 kayıt, harf ve alıcı türü dağılımı, `PUBLIC` yetkileri, rol üyeliği (`SYSDBA` -> `RDB$ADMIN`, grant option 2).
- `GRANT SELECT, INSERT ON t TO u`, `GRANT UPDATE (A) ON ..` (sütun yetkisi `RDB$FIELD_NAME = A`), `REVOKE INSERT`, `REVOKE ALL`, `CREATE ROLE`, `GRANT SELECT ON t TO ROLE r`, `GRANT r TO u` (kayıt: `M`), `REVOKE r FROM u`.
- `GRANT CREATE TABLE TO u` (kayıt: `C`, `SQL$TABLES`, nesne türü 22), `REVOKE CREATE TABLE FROM u`.
- `CREATE ROLE .. SET SYSTEM PRIVILEGES TO USER_MANAGEMENT` (`RDB$ROLES.RDB$SYSTEM_PRIVILEGES` ikili alan, `HEX_ENCODE` ile `0200000000000000`; `RDB$ADMIN` = `FFFFFFFFFFFFFFFF`). Bu kolon doğrudan okunursa metin olarak bozuk görünür.
- Yetkisiz işlem hatası: `no permission for DELETE access to TABLE ...` (kod 335544352). **`HataMetniniCevir` bunu henüz tanımıyor ("Beklenmeyen bir hata oluştu")**; Bölüm 6 madde 7 için yeni cümle gerekecek.
- Servis API'si (`TFDIBSecurity`) gömülü kipte bileşen olarak ayağa kalkıyor ve sunucuya (motora) gidiyor; hata "kullanıcı/şifre tanımsız" (güvenlik veritabanı yok).

Çalışmadı / denenemedi (beklenen):
- `CREATE/ALTER/DROP USER`, `SEC$USERS`, `SEC$USER_ATTRIBUTES`: `security5.fdb` yok (gömülü kipte güvenlik veritabanı yok).
- Şifre değiştirme, kendi şifresini değiştirme, aktif/pasif, yönetici bayrağı, etiket, Services API ile ekle/sil, kısıtlı kullanıcıyla yetki denemeleri (gömülü kip kullanıcıyı doğrulamıyor, bu yüzden sonuç anlamsız): **hepsi sunucuda sahibi tarafından denenecek**.
- 2.5 ve 3.0, 4.0 sunucuları: denenmedi.

Programın korumaları (denendi): `FBTEST_YAZMA=1` ile bile port 3050, 3051 ve diğer tüm portlarda yazma bölümü **"KAPALI"** kalır, yalnızca 3052/3053 + yerel sunucu veya programın kendi gömülü geçici veritabanında açılır. Port 3050/3051 ile yanlış şifre bağlantısı da denendi; yazma kapalı kaldı ve bağlantı reddedildi.

## 5. Önerilen kapsam

İki dilim (veya üç; sahibi karar verir). Her dilimden sonra onay.

**3d-1: Kullanıcılar**
- Liste: ad, ad/soyad, yönetici mi, aktif mi (3.0+), eklenti (3.0+).
- Ekle (ad, şifre, şifre tekrar, ad/soyad, yönetici), şifre değiştir, ad/soyad düzenle, yönetici yap/kaldır, sil.
- "Şifremi değiştir" ayrı düğme: 3.0+ `ALTER CURRENT USER`, 2.5 `ALTER USER kendi_adi`. Yönetici olmayan kullanıcı listeyi göremez (yalnızca kendi satırı); ekran buna göre çalışmalı.
- İlk sürümde yok: etiketler (TAGS), çoklu eklenti seçimi (`USING PLUGIN`), Windows kullanıcı eşleme (`AUTO ADMIN MAPPING`, `SEC$GLOBAL_AUTH_MAPPING`), `SEC$DB_CREATORS`.

**3d-2: Yetkileri görüntüleme**
- Seçili kullanıcı veya rol için: hangi tablo/view/prosedür/generator üzerinde ne yetkisi var, rol üyelikleri, DDL yetkileri, sistem ayrıcalıkları (4.0+).
- Tablo üzerinden ters bakış: "bu tabloda kimin ne yetkisi var" (tablo sağ tık menüsüne tek madde).

**3d-3: Yetki verme/geri alma (sahibinin kararı; ayrı dilim önerilir)**
- Tablo/view için seç/ekle/güncelle/sil/başvuru, prosedür için çalıştır; rol üyeliği ver/al.
- Her işlemde SQL önizlemesi, onay penceresi (Bölüm 10).

### Arayüz taslağı (Bölüm 8)
- **Şerit:** "Yönetim" sekmesine **tek yeni düğme "Kullanıcılar"** (büyük ikon üstte, yazı altta). Seçili bağlantı üzerinde kullanıcı listesi sekmesi açar. Menü yok.
- **Çalışma alanı:** Yeni sekme "Kullanıcılar (sunucu_adı)". Üstte sunucu uyarısı: "Bu liste veritabanının değil, sunucunun kullanıcılarıdır." Altında liste. Pencere yerine sekme, çünkü diğer her şey sekmede.
- **Kullanıcı satırı sağ tık (en çok 6):** Şifre değiştir, Ad/soyad düzenle, Yönetici yap/kaldır, Pasif yap/aktif yap (3.0+), Yetkileri göster (3d-2), Sil.
- **Ağaç:** Tablo sağ tık menüsüne (şu an kaç madde var kontrol edilmeli, sınır 5-6) "Yetkileri göster" ancak 3d-2 ile eklenir; yer yoksa eklenmez.
- **Onaylar (Bölüm 10):** Sil -> "FBY_TEST kullanıcısı sunucudan silinecek. Bu kullanıcı hiçbir veritabanında bağlanamayacak. Yapılan GRANT'ler kalır (sahipsiz). Geri alınamaz." Yönetici bayrağı değişikliği -> "bu kullanıcı bu sunucunun tüm kullanıcılarını yönetebilir." Şifre değiştirme düz onay kutusuyla yetmez, şifre iki kez girilir.
- **Engeller:** kendi hesabını silme, `SYSDBA` silme ve yönetici bayrağını kaldırma (2.5/3.0'da SYSDBA'ya uygulanmaz ama silinemez: ekranda kapalı olsun), kendini pasif yapma.
- **Şifre:** DPAPI ile saklanan bağlantı şifresi (`uBaglanti`) kullanıcı kendi şifresini değiştirince eski kalır; değiştirme başarılı olunca "kayıtlı bağlantı şifresini de güncelleyelim mi?" diye sorulmalı (sahibi karar verecek, bölüm 8).
- **Yazılar:** `uDil` anahtarlarının üç dile eklenmesi (Bölüm 6). Ham hata "Ayrıntı" bölümünde. Yeni anlaşılır cümleler gerekecek: "yetkin yok (kullanıcı yönetmek için SYSDBA veya yönetici olmalısın)", "kullanıcı zaten var", "kullanıcı bulunamadı", "şifre çok uzun/kısa", "güvenlik veritabanı bulunamadı". Gerçek hata mesajları sunucu ölçümünden alınmalı (bölüm 7'deki program ham mesajları ve kodları yazıyor).

## 6. Birim bölünmesi önerisi (Bölüm 4, 9)

| Birim | Görevi |
|---|---|
| `uMetadata.pas` (mevcut) | **Salt okuma, sürüme bağlı**: `KullaniciListesiOku(Bag)` (3.0+ `SEC$USERS`; 2.5 -> `uKullanici`'nin Services listesine yönlendirir veya liste boş + "bu sürümde liste servis ile alınır"), `YetkileriOku(Bag, Alici)`, `RolleriOku(Bag)`. Sürüm kararı (`Bag.Surum` ana sürüm) yalnızca burada. |
| `uKullanici.pas` (yeni) | **Yazma ve 2.5 Services**: `KullaniciEkle`, `KullaniciSil`, `SifreDegistir`, `KendiSifremiDegistir`, `AdSoyadDegistir`, `YoneticiAyarla`, `AktifAyarla`; yalnızca SQL metni üretir ve çalıştırır (sürüme göre `ALTER CURRENT USER` / `ALTER USER`); şifre/ad kaçırma tek yerde; 2.5 liste `TFDIBSecurity`. Önizleme için `…ScriptiUret` fonksiyonları (şifre hiçbir zaman log'a/önizlemeye düz yazılmaz, `***` gösterilir). |
| `uYetki.pas` (3d-3 ile) | `YetkiVer`, `YetkiGeriAl`, `RolUyeligiVer/Al` (SQL üretimi). İstenirse `uKullanici` içinde kalır; ayrı olması "her iş kendi unit'inde" kuralına uyar. |
| `fKullanicilar.pas` (yeni sekme formu) | İnce: liste ızgarası, sağ tık menüsü, düğmelerin `OnClick`'i doğrudan `uKullanici` işlevini çağırır. Kendi SQL'i yok, sürüm bilmez. |
| `fKullaniciDuzenle.pas` | Ekle/düzenle penceresi (ad, şifre x2, ad/soyad, yönetici); yalnızca alanları toplar. |
| `uSerit.pas`, `uDil.pas` + 3 dil dosyası | "Yönetim" sekmesine bir düğme; yeni anahtarlar tr/en/de. |
| `uSorgu.pas` `HataMetniniCevir` (`uBaglanti.pas`) | Yeni sık hatalar için cümleler. |

Sürüm farkı olan her şey (`SEC$USERS` var/yok, `ALTER CURRENT USER`, `ACTIVE/INACTIVE`, sistem ayrıcalıkları) `uMetadata`/`uKullanici` içinde bir **yetenek** fonksiyonuna toplanır (örn. `KullaniciYetenekleri(Bag)`: ListeSQL, AktifPasif, SistemAyricaligi, KendiSifreKomutu). Form yalnızca "bu özellik var mı" sorusunu sorar, sürüm numarasını bilmez. 6.0 çıkınca tek yer değişir.

## 7. Ölçüm programı ve sahibinin çalıştıracağı komutlar

Dosyalar: `Test\KullaniciOlcum.dpr`, `Test\KullaniciOlcumDerle.bat`. Varsayılan yalnızca okur; `FBTEST_YAZMA=1` yazma bölümünü açar (yalnızca yerel 3052/3053 veya kendi gömülü geçici veritabanı). Şifre hiçbir yere yazılmaz. `CREATE/ALTER/DROP USER, GRANT, REVOKE` yalnızca yazma bölümünde ve korumalı çalışır.

Derleme (zaten derlendi; exe, git dışında tutulan `bin\Win64\Release` içinde, bu çalışma ağacında):

```powershell
cd C:\Baris\Kodlar\FirebirdYonetici\.claude\worktrees\unruffled-benz-959342\Test
.\KullaniciOlcumDerle.bat
```

Çalıştırmadan önce `bin\Win64\Release\istemci` klasörü orada olmalı (bu çalışma ağacında kopyaladım). Mevcut tek-satır kalıbı: PowerShell'de `$env:AD = "değer"`, cmd'deki `set` çalışmaz.

**a) Sadece okuma, gerçek veri sunucuları (2.5.9 :3050 ve 5.0.4 :3051). Hiçbir şeyi değiştirmez:**

```powershell
Remove-Item Env:FBTEST_* -ErrorAction SilentlyContinue
$env:FBTEST_SUNUCU = "127.0.0.1"
$env:FBTEST_PORT = "3050"
$env:FBTEST_YOL = "C:\...\VAR_OLAN_VERITABANI.FDB"
$env:FBTEST_KULLANICI = "SYSDBA"
$env:FBTEST_SIFRE = "SIFRENIZ"
$env:FBTEST_CIKTI = "$env:TEMP\kullaniciolcum_25.txt"
& "C:\Baris\Kodlar\FirebirdYonetici\.claude\worktrees\unruffled-benz-959342\bin\Win64\Release\KullaniciOlcum.exe"
```

(3051 için `FBTEST_PORT = "3051"`, çıktı `kullaniciolcum_50.txt`.) `FBTEST_YAZMA` **verilmeyin**.

**b) Okuma + yazma, atılabilir sunucular (3.0.x :3052 ve 4.0.x :3053):**

```powershell
Remove-Item Env:FBTEST_* -ErrorAction SilentlyContinue
$env:FBTEST_SUNUCU = "127.0.0.1"
$env:FBTEST_PORT = "3052"
$env:FBTEST_YOL = "C:\...\TEST.FDB"
$env:FBTEST_KULLANICI = "SYSDBA"
$env:FBTEST_SIFRE = "SIFRENIZ"
$env:FBTEST_YAZMA = "1"
$env:FBTEST_CIKTI = "$env:TEMP\kullaniciolcum_30.txt"
& "C:\Baris\Kodlar\FirebirdYonetici\.claude\worktrees\unruffled-benz-959342\bin\Win64\Release\KullaniciOlcum.exe"
```

(3053 için `FBTEST_PORT = "3053"`, çıktı `kullaniciolcum_40.txt`.) Yazma, `FBY_TEST` / `FBY_SVC` kullanıcılarını, `FBY_OLCUM_T` tablosunu, `FBY_ROL` ve `FBY_SYSROL` rollerini oluşturur ve sonunda siler (yarım kalırsa bir sonraki çalıştırmada temizler).

**c) Gömülü kip (bende yaptığım):** `FBTEST_SUNUCU` boş bırakın. Okuma varsayılan; `FBTEST_YAZMA = "1"` gömülüde yalnızca programın kendi `%TEMP%\kullaniciolcum` geçici veritabanında çalışır (kullanıcı yönetimi hataları beklenen).

Çıktıdaki işaretler: `[CALISTI]` yol çalıştı, `[HATA]` yol çalışmadı (ham mesaj + Firebird kodu + bizim çevirimiz). Çıktıyı bana iletirseniz sürüm tablosunu "ölçüldü" olarak güncellerim.

Ek ölçüm sorularının cevabı bu çıktılarda aranmalı: (1) 3.0/4.0'da `ALTER CURRENT USER` (Y3) çalışıyor mu, (2) 2.5'te `ALTER USER kendi_adi` (Y3) çalışıyor mu, (3) Services API 3.0+ sunucuda da liste verir mi, yönetici bayrağı görünüyor mu (Y1/Y4), (4) `FBY_TEST` yönetici olmadan `CREATE USER`/başkasının şifresini değiştirmeye çalışınca hata mesajları ve kodları, (5) pasif kullanıcı bağlanabiliyor mu, (6) 4.0'da sistem ayrıcalığı rolü, 3.0'da hata mesajı, (7) 2.5'te `GRANT CREATE TABLE` hata mesajı.

## 8. Aşama 4 ve 5'e etkisi (kısa)

- **Aşama 4 (çoklu veritabanı):** Kullanıcılar sunucuya ait olduğundan, "aynı sunucudaki birçok veritabanı" için kullanıcı ekranı tek sefer yeter; farklı sunuculardaki aynı adlı kullanıcıyı karşılaştırma/eşitleme istenirse bu ayrı bir iş (şema farkı kapsamına alınmamalı). Yetki farkı (`RDB$USER_PRIVILEGES` karşılaştırma) şema farkına eklenebilir; 3d-2'nin yetki okuma işlevi buna yeniden kullanılır.
- **Aşama 5 (PostgreSQL):** Kullanıcı/yetki modeli tamamen farklı (`pg_roles`, `GRANT`/`REVOKE`, kullanıcı ve grup aynı kavram: rol). Aşama 5 "yönetim özellikleri yok" dediği için etkisi yok. Tek ilke: `uKullanici` Firebird'e özgü kalır, `uMetadata`'daki motor seçimi arkasına ayrı bir sürücü gelirse buraya dokunulmaz; Aşama 5'in "motor seçimi" hazırlık maddesi için `KullaniciListesiOku` gibi işlevler motor seçiminin arkasında Firebird dalına konmalıdır.

## 9. Sahibine açık kararlar

1. **Kapsam:** 3d-1 (kullanıcılar) ile başlayıp onay mı? Yetki görüntüleme (3d-2) ve verme/geri alma (3d-3) ayrı aşamalar mı olsun, yoksa 3d-3 hiç yapılmasın mı?
2. **2.5 desteği:** 2.5'te liste için `TFDIBSecurity` (Services) kullanılsın mı? Yönetici bayrağı 2.5'te listede görünmez (FireDAC desteklemiyor); "bilinmiyor" yazılsın mı, yoksa 2.5'te yönetici sütunu hiç olmasın mı?
3. **Giriş yeri:** Yönetim sekmesinde "Kullanıcılar" düğmesi yeterli mi, ağaçta bağlantıya sağ tık menüsüne de "Kullanıcılar" eklensin mi (yoksa "tek yol" ilkesine aykırı olur)?
4. **Aktif/pasif, etiket, eklenti seçimi, Windows eşlemesi:** İlk sürümde yok önerisi; uygun mu? (Aktif/pasif 3.0+'da çok işe yarar, ekleme önerim yok yalnızca onay çıkmasın diye soruyorum.)
5. **Kendi şifresi:** "Şifremi değiştir" ayrı düğme olsun mu (yönetici olmayan kullanıcı için tek görünen işlem)? Başarılı olunca kayıtlı bağlantı şifresi (DPAPI) güncellensin mi?
6. **Şifre kuralları:** En kısa uzunluk (öneri 8), Srp 20 baytı aşan şifre için uyarı, şifrede `' : & !` karakterleri engellensin mi kabul edilsin mi (önce denenecek)?
7. **SYSDBA koruması:** `SYSDBA` silme, pasif yapma ve yönetici bayrağı değiştirme ekranda hiç görünmesin mi yoksa uyarıyla mı reddedilsin?
8. **Yetki verirken onay düzeyi (3d-3 olursa):** SQL önizleme ile tek onay mı yoksa her GRANT/REVOKE için ayrı mı?
9. **Gömülü kip:** Gömülü bağlantıda "Kullanıcılar" düğmesi kapalı olsun mu (güvenlik veritabanı yok) ve neden yazılsın mı?
10. **Test düzeni:** 3d-1 kodlandığında kendi `Test\KullaniciTest.dpr` testi sunucu kipinde (3052/3053) çalışsın, 3050/3051'de yalnızca okuma testi yapılsın; uygun mu?

## 10. Kaynaklar

- [Firebird 5.0 Language Reference: Güvenlik](https://firebirdsql.org/docs/chunk/en/refdocs/fblangref50/fblangref50-security.html) (RDB$ADMIN, yöneticiler, sistem ayrıcalıkları)
- [5.0: Kullanıcı yönetimi SQL](https://firebirdsql.org/docs/chunk/en/refdocs/fblangref50/fblangref50-security-user.html)
- [3.0: Kullanıcı yönetimi SQL](https://firebirdsql.org/file/documentation/chunk/en/refdocs/fblangref30/fblangref30-security-user.html)
- [5.0 Ek D: RDB$USER_PRIVILEGES](https://firebirdsql.org/docs/chunk/en/refdocs/fblangref50/fblangref-appx04-userprivs.html), [5.0 Ek F: Güvenlik tabloları](https://firebirdsql.org/docs/chunk/en/refdocs/fblangref50/fblangref50-appx06-sectables.html)
- [2.5 Language Ref. Update: SQL kullanıcı yönetimi](https://firebirdsql.org/refdocs/langrefupd25-security-sql-user-mgmt.html), [gsec (2.5)](https://firebirdsql.org/file/documentation/html/en/firebirddocs/gsec/firebird-gsec.html)
- [3.0 sürüm notları: güvenlik](https://firebirdsql.org/file/documentation/release_notes/html/en/3_0/rnfb30-security.html), [4.0 sürüm notları](https://firebirdsql.org/file/documentation/release_notes/html/en/4_0/rlsnotes40.html)
- FireDAC: `FireDAC.Phys.IBBase.TFDIBSecurity` ([DocWiki](https://docwiki.embarcadero.com/Libraries/Rio/en/FireDAC.Phys.IBBase.TFDIBSecurity)), yerel kaynak `source\data\firedac\FireDAC.Phys.IBBase.pas` ve `FireDAC.Phys.IBWrapper.pas`.
- Not: Belge sayfaları büyük olduğu için bazı bölümler yalnızca arama/özet ile görüldü; sürüm tablosunda "Sahibi denesin" yazan hücreler bu yüzden işaretlendi.
