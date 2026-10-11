# Aşama 2b Raporu (Adım 0-4)

Dal: `asama2b` (`claude/sleepy-pascal-nd1dcw` üzerinden açıldı, `main`'e yazılmadı). Rapor sırayla Adım 0-1 (ilk bölümler) ve Adım 2-4 + toplu durum (sondaki bölümler) içerir. Elle deneme listesi ve sizden gerekenler en sonda.

## 1. Derleme

`Derle.bat` (Win64 Release) ilk denemede iki aşamada takıldı, ikisi de Aşama 2 kodundan değil proje ayarından geliyordu:

1. İlk çalıştırmada `BRCC32` görevi `FirebirdYonetici.vrc` bulunamadı diye düştü. Hemen ardından ikinci çalıştırmada aynı hata gelmedi (sürüm bilgisi kaynağı geçici dosya olarak üretilip siliniyor); yeniden üretemedim, kalıcı bir sorun saymıyorum. Tekrar görülürse haber verin.
2. `SynUnicode.pas(36): F2613 Unit 'Windows' not found`. Sebep: `.dproj`'daki `DCC_Namespace` listesinde `Winapi`, `System.Win`, `Data.Win` yoktu (SynEdit eski biçimde `Windows` yazıyor). **Düzeltme:** bu üç isim alanı eklendi (`Kaynak\FirebirdYonetici.dproj`, tek satır). Commit `bbd17ed`.

Sonuç: **`Derle.bat` hatasız bitti (çıkış kodu 0)**, yani Aşama 2'nin elle yazılmış kodu (uEditor, uSorgu, uSonucGrid, uBaglanti, fSorguSekme, fMetinGoster, fAna) olduğu gibi derlendi; GOREV belgesindeki şüpheli SynEdit/FireDAC adlarının hiçbiri değişiklik gerektirmedi. Yalnızca SynEdit kaynağında 2 uyarı (W1075, bizim kodumuz değil). Program açılıyor (4 sn sonra çalışıyor, pencere başlığı geliyor).

**SynEdit kaynağı:** Derleme, GetIt'ten değil `C:\Baris\Componnt\Ortak\SynEdit\Source` yolundan yapıyor (Delphi kütüphane yolunda `$(COMPATH)\SynEdit\Source`). Bu TurboPack SynEdit (readme: 10.4 Sydney sürümü, MIT/MPL). GetIt'teki `SynEdit-12` klasöründe yalnızca EULA var, kurulu değil. CLAUDE.md "GetIt, olmazsa GitHub kaynağı" diyor; bu GitHub kaynağıyla aynı proje, ama sürümü 10.4. Bilginiz olsun diye yazıyorum; projeye yerel yol yazmadım, kütüphane yolundan geliyor. Başkasının derlemesi için README'de "SynEdit (TurboPack) kütüphane yolunda olmalı" notu zaten var mı, Aşama 2b sonunda bakacağım.

## 2. `GDS_TOKEN_UNKNOWN` ve hata kodları

- `GDS_TOKEN_UNKNOWN = 335544634` Firebird 5.0.4 `iberror_c.h` ile **doğrulandı** (`isc_dsql_token_unk_err`). `uBaglanti.pas`'taki diğer 13 `GDS_*` sabitinin hepsi de aynı dosyayla karşılaştırıldı, hepsi doğru.
- **Ama yazım hatası cümlesi çalışmıyordu.** `selec 1 ...` çalıştırınca FireDAC hata listesinde yalnızca `335544569` (`isc_dsql_error`, "Dynamic SQL Error") veriyor; 335544634 listede hiç yok. Sonuç "Beklenmeyen bir hata oluştu" idi. **Düzeltme:** `MetindenCevir` içine `token unknown` / `SQL error code = -104` araması eklendi (`uBaglanti.pas`, 2 satır). Artık: "SQL komutunda yazım hatası var. Aynı anda yalnızca tek bir komut çalıştırılır." geliyor. `GDS_TOKEN_UNKNOWN` dalını silmedim (zararsız, 2.5'te farklı davranabilir; 2.5.9'da ölçülünce karar veririm).
- Diğer üç cümle 5.0.4'te doğru çalışıyor: benzersiz ihlali (`ekUKViolated`), yabancı anahtar (`ekFKViolated`), nesne yok (`ekObjNotExists`, "Table unknown").

## 3. Ölçümler

Ölçüm programı: `Test\Adim0Olcum.dpr` (+ `Test\Adim0OlcumDerle.bat`). Geçici bir tablo (2300 satır) açar, ölçer, DROP eder. Gerçek veriye dokunmaz.

### Firebird 5.0.4 (gömülü kip, geçici veritabanı): TAMAM

1. **`fmOnDemand` parça parça geliyor.** `Open` sonrası `RecordCount = 500`; 500. satıra gelince 1000, sonra 1500, 2000, en sonunda 2300 (son parça 300). Beklendiği gibi.
2. **Kısmen yüklenmiş sonuçta başlık sıralaması:** `IndexFieldNames := 'ID:D'` verince FireDAC **geri kalan tüm satırları hemen çekiyor** (`RecordCount` 500 → 2300) ve sıralama **tüm sonuç üzerinde** doğru yapılıyor (ilk ID = 2300, son = 1). Yani Aşama 2 raporundaki "sadece yüklenen satırlar sıralanır" endişesi geçersiz; sıralama doğru. **Bedeli:** çok büyük sonuçta başlığa tıklamak tüm sonucu belleğe çeker (parça parça mantığı o an bozulur). Sıralamayı kaldırınca (IndexFieldNames boş) asıl sıra geri geliyor. Bunun için kod değiştirmedim; kararınız: (a) böyle kalsın, (b) başlık tıklamasında satır sayısı çoksa uyarı/sınır.
3. **Açık sorgu varken başka sekmede `insert`:** Sekme 1 açıkken (500 satır yüklü) sekme 2'de `insert` çalıştı (`Etkilenen = 1`, kendi işlemi, otomatik onay). Sekme 1 **bozulmadı**, açık kaldı, sona kadar gitti, `RecordCount = 2300` (eski görüntü; yeni satır görünmedi, çünkü sekme 1'in işlemi kendi görüntüsünü koruyor). Sonra yeni sorgu `count(*) = 2301` verdi, insert kalıcı. Sunucuda sekme 1'in işlemi açık görünüyor (cursor bitene kadar). Bu beklenen ve Aşama 2 kararıyla (her sekmenin kendi işlemi) uyumlu.

### Firebird 2.5.9: **YAPILAMADI, sizden bir şey gerekiyor**

Sunucular çalışıyor (3050 = 2.5.9, 3051 = 5.0.4, `Aşama 1b` raporuyla aynı), ama SYSDBA şifresini bilmiyorum ve tahmin etmeyeceğim. 2.5.9'un gömülü kipi 32 bit olduğu için Win64 programdan kullanılamıyor (sadece ağ üzerinden denenebilir). Ayrıca 5.0.4 *sunucusunda* (3051) da aynı ölçümü yapmak isterim (gömülü kip ile motor aynı ama ağ yolu farklı).

## 4. Ne eksik

- 2.5.9 ve 5.0.4-sunucu ölçümleri (yukarıdaki sebep).
- Aşama 2'nin elle deneme listesinin (ASAMA2_RAPOR.md Bölüm 4) arayüz kısmı: ben arayüzü tıklayarak denemedim (yalnızca programın açıldığını gördüm). Madde 1-13'ü siz Windows'ta deneyebilirsiniz; sonuçlarda bir şey bozuk çıkarsa bana yazın.
- Adım 1-4 başlamadı.

## 5. Sizden istenenler

1. **2.5.9 ölçümü için** aşağıdaki komutları kendi pencerenizde çalıştırın (şifre ekrana/dosyaya yazılmaz, yalnızca o pencerenin ortam değişkeni olur) ve `olcum.txt` içeriğini bana yapıştırın ya da "ölç" deyin, ben okurum. **Bir test veritabanı** kullanın, gerçek veri değil; program yalnızca `OLCUM_T` ve `OLCUM_C` adlı geçici tabloları açıp siler.

   ```
   cd C:\Baris\Kodlar\FirebirdYonetici
   Test\Adim0OlcumDerle.bat
   set FBTEST_SUNUCU=localhost
   set FBTEST_PORT=3050
   set FBTEST_YOL=C:\...\test.fdb
   set FBTEST_KULLANICI=SYSDBA
   set FBTEST_SIFRE=...
   set FBTEST_CIKTI=%TEMP%\olcum.txt
   bin\Win64\Release\Adim0Olcum.exe
   ```
   (Port 3051 ve 5.0.4 test veritabanı yoluyla ikinci kez.)
2. Başlık sıralamasında (madde 3.2) yukarıdaki (a)/(b) kararı.
3. Adım 1'e (sorgu planı) geçmem için onay.

---

# Adım 1: Sorgu planı

**Karar (sıralama):** Başlık sıralaması olduğu gibi kalıyor (Bölüm 3, madde 2).

**Seçilen yol: A (FireDAC iç yolu).** `uSorgu.pas` içinde `SorguPlaniAl(Bag, Sql)`: komut yalnızca `Prepare` edilir, `TIBStatement.sql_explain_plan` (Firebird 3+; boşsa `sql_get_plan`) okunur. Neden A: `FStmt` alanı *private* değil *protected* (`TFDPhysIBCommandBase`); içeriye tek satırlık bir sınıf erişimi (`TFbKomutErisim = class(TFDPhysIBCommandBase)`) yetiyor, RTTI/helper gerekmedi. Toplam yaklaşık 35 satır, tek unit, Windows'a bağlı kod yok. B (`fbclient.dll`, `isc_dsql_sql_info`) ayrı bağlantı/işlem açıp C API'yi elle çağırmayı gerektirirdi, çok daha uzun olurdu. B'nin kodu yazılmadı, depoda yok.

Dikkat: A, FireDAC'in iç sınıf adlarına (`FireDAC.Phys.IBBase/IBWrapper`) bağlı; RAD Studio sürümü değişirse derleme hatası verebilir, tek yer `uSorgu.pas`. Firebird 2.5.9'da denenmedi (aşağıya bakın); orada çalışmazsa B'ye geçerim.

**Ne eklendi**
- `uSorgu.pas`: `SorguPlaniAl`, `TekKomutMu` (yorum/tırnak dışında `;` yoksa tek komut; Adım 3'te `KomutlaraBol` ile değişecek). CREATE/ALTER/DROP/SET gibi komutların planı yoktur, boş döner ("Bu komut için sorgu planı yok" yazar).
- Araç çubuğunda 6. düğme **Plan** (Tabler `list-tree` ikonu, `Ikonlar\list-tree.png` + `Ikonlar\svg\list-tree.svg`), **Ctrl+L**. Sorgu sekmesi aktifken açık. Sonuç sekmenin mesaj kutusunda: "Sorgu planı:" + plan + "Komut çalıştırılmadı, yalnızca hazırlandı."
- Birden fazla komut varsa: "Plan için tek bir komut seçin." Hata olursa: "Sorgu planı alınamadı." + anlaşılır cümle + Ayrıntı.
- Dil: `BTN_PLAN`, `MSG_PLAN_BASLIK`, `MSG_PLAN_YOK`, `MSG_PLAN_CALISTIRILMADI`, `ERR_PLAN_TEK_KOMUT`, `ERR_PLAN_ALINAMADI` (tr, en, de).

**Denenen (5.0.4 gömülü, geçici veritabanı, `Adim0Olcum` bölüm 5)**
- `select ... where ID = 5`: ayrıntılı plan geldi (Filter / Table "OLCUM_T" Access By ID / Index Unique Scan).
- `update ... where`, `delete`: plan geldi (satırlar **değişmedi**: 2301 / 2301, `ID=5` yazısı aynı).
- `insert`: plan boş (Firebird INSERT için plan üretmiyor); satır eklenmedi.
- DDL (`create table`): boş, tablo oluşmadı. Hatalı SQL: "bulunamadı" cümlesi + ayrıntı.
- Uygulama derlendi ve açılıyor. **Arayüzde Plan düğmesine tıklayarak denemedim.**
- **Firebird 2.5.9 / 5.0.4 sunucu: DENENMEDİ** (şifre sizde, yukarıdaki komutlar).

---

# Adım 2: Ctrl+Boşluk otomatik tamamlama (kolon önerisi dahil)

**Ne yapıldı** (derlendi; arayüzde elle denenmedi, bkz. "Elle deneme listesi")
- `uEditor.pas`: SynEdit paketindeki `TSynCompletionProposal` kullanıldı (yeni paket yok). `TSqlEditor`'a eklendi: `AnahtarKelimeleriYukle(Dosya, Surum)`, `NesneAdlariniVer(Liste)`, `KolonGetirici` (kolonları sekmeden isteyen basit bir yöntem göstergesi). Ctrl+Boşluk bileşenin varsayılan kısayolu; `.` yazılınca 50 ms sonra liste kendiliğinden açılır (bileşenin yerleşik zamanlayıcısı, `TriggerChars = '.'`).
- Öneri kaynakları: (1) `anahtar_kelimeler.txt`, bağlı sunucunun sürümüne göre; (2) tablo, view, prosedür, generator adları (sekme açılırken bir kez alınır, `fSorguSekme.OneriHazirla`); (3) **kolon önerisi**: imleçten önce `ad.` varsa `ad` çözülür ve o tablonun kolonları önerilir.
- Takma ad çözümü `uSorgu.TabloAdiniBul(Metin, Ad)`: tüm metinde `FROM`/`JOIN` sonrası `tablo [AS] takma_ad` kalıbını `TRegEx` ile arar (imleçten sonraki `FROM` da bulunur). Takma ad yoksa `ad` tablo adı sayılır. `WHERE`, `LEFT`, `ON` gibi sözcükler takma ad sayılmaz. Tırnaklı ad (`"Musteri"`) büyük/küçük harfi korunur, tırnaksız ad büyük harfe çevrilir.
- Kolonlar `uMetadata.KolonTablosuOlustur` ile alınır, **tablo başına bir kez** saklanır (bulunamayan tablo için boş liste saklanır, tekrar sorgu atılmaz). Tablo yoksa liste açılmaz, hata gösterilmez.
- Anahtar kelime seçilince büyük harf yazılır; nesne ve kolon adları olduğu gibi kalır. Süzme SynEdit'in standart davranışı (büyük/küçük harf duyarsız).
- Yeni görünen yazı yok, bu adım için dil anahtarı eklenmedi.

**`anahtar_kelimeler.txt` (24 → 515 satır), kaynak ve yöntem**
- Kaynak: Firebird 2.5, 3.0, 4.0, 5.0 Language Reference, Ek C "Reserved Words and Keywords" (firebirdsql.org/file/documentation/html/en/refdocs/fblangrefNN). Dört sürümün listesi (ayrılmış sözcükler + anahtar kelimeler; veri tipleri bunların içinde) çekilip karşılaştırıldı, her sürümde **yeni gelen** kelimeler ilgili bölüme konuldu: ilk bölüm (başlıksız) 346 kelime (2.5 ve sonrası), `#FB3` 63, `#FB4` 83, `#FB5` 8.
- Örnekler: `BOOLEAN` → `#FB3`; `INT128`, `DECFLOAT`, `VARBINARY` → `#FB4`; `OPTIMIZE`, `LOCKED`, `BLOB_APPEND` → `#FB5`. Çok sözcüklü tipler (`DOUBLE PRECISION`, `CHARACTER VARYING`; `TIMESTAMP WITH TIME ZONE`, `TIME WITH TIME ZONE` FB4) elle, doğru bölüme eklendi.
- Biçim: satır başına bir kelime, `#` ile başlayan satırlar yorum, `#FB3`/`#FB4`/`#FB5` bölüm başlığı. Bağlı sürümden büyük bölümler önerilmez. Sonraki sürümlerde **kaldırılan** kelimeler (ör. `MAXIMUM_SEGMENT`) silinmedi, zararsız.
- Dosya kodun içine gömülü değil (Bölüm 9.3).

**Bilinen sınırlar**
- `FROM a, b x` gibi **virgüllü tablo listelerinde** yalnızca ilk tablo çözülür. `JOIN` kullanan sorgularda sorun yok. İsterseniz virgüllü listeyi de ekleyebilirim.
- `(select ...) x` gibi alt sorgu takma adlarının kolonları önerilmez.
- Yorum içinde yazılmış `from musteri m` de takma ad sayılır (yorumlar ayıklanmıyor; kod sade kalsın diye).
- Sekme açıkken bir tabloya kolon eklenirse öneri listesi eski kalır (yeni sekme açınca güncellenir).

# Adım 3: Çoklu komut çalıştırma

**Ne yapıldı** (`uSorgu.pas` + `fSorguSekme.pas`; çalıştırma mantığı testle doğrulandı, arayüz değil)
- `KomutlaraBol(Metin): TArray<string>`: `;` ile böler, `SET TERM` ile ayırıcı değişir (`SET TERM ^ ;` ... `END ^` ... `SET TERM ; ^`), tırnak ve yorum içindeki ayırıcı bölmez, boş (ve yalnızca yorumdan oluşan) komutlar atılır. `TekKomutMu` artık bunun üzerine kurulu.
- `KomutTuruBul`: `COMMIT`, `ROLLBACK`, isql'e özgü komutlar (`SET SQL DIALECT`, `SET NAMES`, `SET AUTODDL`, `SET STATS`, `CONNECT`, `SHOW`, `INPUT`, `OUTPUT`, `QUIT` ...) ve normal komut ayrımı. `SET GENERATOR`, `SET TRANSACTION` gibi DSQL komutları normal sayılır.
- `BetikCalistir`: komutları sırayla çalıştırır, her biri için bir kayıt döner. `COMMIT`: atlanır ("otomatik onay açık"). `ROLLBACK`: **orada durur**, "desteklenmez, önceki komutlar geri alınamaz" yazar. **Karar (onayınıza açık):** isql komutları için görev "uyarı ver" diyordu; durmak yerine **uyarıyla atlayıp devam ediyor** (betiğin başındaki `SET SQL DIALECT 3` yüzünden tüm betik durmasın diye). Durmasını isterseniz tek satırlık değişiklik.
- Tek komut ve normal türdeyse eski yol aynen çalışır (ızgara, 500'er satır, tek hata cümlesi). Tek başına yazılmış `COMMIT`/`ROLLBACK`/isql komutu çoklu yoldan gidip açık bir mesaj verir (sessizce yutulmaz).
- Çoklu komutta son SELECT'in sonucu ızgarada kalır; mesaj kutusunda her komut için bir satır ("1) 3 satır etkilendi (12 ms).", "2) tamam"), ilk hatada "3. komutta hata: ..." + Ayrıntı + "Hatadan sonraki N komut çalıştırılmadı." En sonda her zaman: "Her komut ayrı ayrı otomatik onaylandı (commit). Hata olsa bile önceki komutlar geri alınmaz."
- Onay penceresi: komutlardan herhangi biri tehlikeliyse **tek** pencere; kaç komut çalışacağı, tehlikeli komutların numarası, ilk 60 karakteri ve nedeni (DROP / WHERE yok) yazılır. Hayır → hiçbiri çalışmaz.
- Plan (Ctrl+L) artık `KomutlaraBol` kullanıyor: birden fazla komut varsa "Plan için tek bir komut seçin."
- Dil anahtarları (tr, en, de; 14 yeni): `MSG_KOMUT_SATIRI_SECIM/DEGISTI/TAMAM`, `MSG_COMMIT_ATLANDI`, `MSG_ISQL_ATLANDI`, `ERR_ROLLBACK_YOK`, `ERR_KOMUT_HATASI`, `MSG_KOMUT_DURDU`, `MSG_COKLU_ONAY_NOTU`, `ONAY_COKLU_KOMUT`, `ONAY_COKLU_SATIR`, `ONAY_COKLU_SON`, `ETIKET_DROP`, `ETIKET_WHERE_YOK`. Üç JSON dosyası geçerli (PowerShell ile ayrıştırıldı) ve aynı sayıda anahtar içeriyor.

# Adım 4: Testler

`Test\SorguTest.dpr` + `Test\SorguTestDerle.bat` (diğer testlerle aynı biçim; geçici veritabanı, `FBTEST_*` ortam değişkenleri; `FBTEST_YOL` verilmezse yalnızca veritabanısız kontroller çalışır). Çıkış kodu = hata sayısı.

**Firebird 5.0.4 (gömülü kip, geçici veritabanı): 66 kontrolün tamamı geçti, hata 0.**
- Veritabanısız: `KomutlaraBol` 11 (basit `;`, tırnak/yorum içinde `;`, iki katlı tırnak, `SET TERM` ile prosedür, küçük harf/bitişik `SET TERM`, boş komutlar, son satırda `;` yok), `TehlikeliSorguUyarisi` 10 (DROP, ALTER..DROP, WHERE'siz/li DELETE/UPDATE, UPDATE OR INSERT, yazı/yorum içinde drop), `KomutTuruBul` 8, `TabloAdiniBul` 9.
- Veritabanı: `SorguCalistir` (SELECT ilk parça 500, sona gidince 1200; INSERT `Etkilenen=1`; UPDATE `=10`; DDL; kalıcılık), hata cümleleri (benzersiz, yabancı anahtar, nesne yok, yazım hatası), plan (SELECT planı geliyor; **INSERT/UPDATE/DELETE planı alınınca veri değişmedi**), çoklu komut (3 komut; ortada hata → 3. çalışmadı, 1. geri alınmadı; COMMIT atlama; ROLLBACK durdurma; isql komutu atlama; `SET TERM` ile prosedür oluşturma ve çağırma).
- `BaglantiDosyasiTest` (hata 0) ve `MetadataTest` mevcut haliyle derlenip çalıştı, geçti.
- Test sırasında bulunan hata düzeltildi: `TabloAdiniBul` takma adsız `FROM tablo` kalıbında `Groups[2]` için `ERegularExpressionError` verdi. Bir test beklentisi de yanlıştı, düzeltildi.
- Gözlem (hata değil): test sonunda `DROP TABLE SORGUTEST_T` çalıştırmaların bir kısmında "lock conflict on no wait transaction" verdi (aynı bağlantıda bir işlem tabloyu tutuyor). Nedenini kesinleştiremedim; ara kontrolde açık başka işlem görünmedi. Testi etkilemiyor (sonraki çalıştırmanın başında artıklar temizleniyor), ama sonraki turda `mon$statements` ile bakmak isterim.
- Gömülü kip için `bin\Win64\Release\istemci\plugins\` içine `engine13.dll` kopyaladım (yalnızca derleme çıktısı, depoya girmiyor; `SonDerleme.bat` bunu kopyalamıyor, normal kullanım ağ bağlantısı).

**Plan için A/B kararı (Adım 1'den): A (FireDAC iç yolu) kaldı.** 5.0.4'te çalışıyor; 2.5.9'da denenemedi.

# Aşama 2b: toplu durum

**Yapılmayan / eksik kalan (sizden gerekenler)**
1. **Firebird 2.5.9 ve 5.0.4 sunucu (3050/3051) ile testler:** SYSDBA şifresini bilmediğim için yapılamadı, tahmin etmedim. Test hazır; kendi pencerenizde (şifre dosyaya yazılmaz):
   ```
   cd C:\Baris\Kodlar\FirebirdYonetici
   Test\SorguTestDerle.bat
   set FBTEST_SUNUCU=localhost
   set FBTEST_PORT=3050
   set FBTEST_YOL=C:\...\test.fdb
   set FBTEST_KULLANICI=SYSDBA
   set FBTEST_SIFRE=...
   set FBTEST_CIKTI=%TEMP%\sorgutest.txt
   bin\Win64\Release\SorguTest.exe
   ```
   (3051 için `FBTEST_PORT=3051`.) Sonucu "oku" diyerek bana okutabilirsiniz. 2.5.9'da özellikle bakılacaklar: plan (Adım 1; çalışmazsa B'ye geçilir), `selec` için yazım hatası cümlesi, `SET TERM` betiği.
2. Arayüz elle denenmedi. Özellikle Ctrl+Boşluk (SynEdit API'si derlendi ama liste açılışı görülmedi) ve çoklu komut onay penceresi.
3. CLAUDE.md Bölüm 11'deki iki madde (`Ctrl+Boşluk`, çoklu komut) zaten vardı, işaretlenmedi (onayınızla işaretlenir).

**Elle deneme listesi (Windows)**
1. Sorgu sekmesi aç, `sel` yazıp Ctrl+Boşluk: `SELECT` çıkmalı, seçince büyük harf yazılmalı. Boş yerde Ctrl+Boşluk: kelimeler ve tablo adları.
2. `select m. from musteri m` yazarken `m` sonrası `.`'ya basın: Ctrl+Boşluk gerekmeden MUSTERI kolonları açılmalı. Ayrıca `musteri.` (takma adsız), `join` içeren sorgu, olmayan bir ad (`x.`: liste açılmamalı, hata çıkmamalı).
3. Sürüm bölümleri: FB 2.5 bağlantısında `BOOLEAN`/`INT128` önerilmemeli, 5.0'da önerilmeli.
4. Üç komutlu betik (`create table t(a int); insert into t values (1); select * from t;`) F5: üç satırlık mesaj, son SELECT ızgarada. Ortada hata: "N. komutta hata" + önceki komutların kalıcı olduğu notu.
5. İçinde `drop` veya WHERE'siz `delete` olan betik: tek onay penceresi, komut numarası ve nedeni yazmalı; Hayır → hiçbiri çalışmamalı.
6. Seçili kısım: editörde birçok komut yazıp yalnızca ikisini seçin, F5: yalnızca seçilenler çalışmalı. `SET TERM ^ ;` ile prosedür betiği.
7. Ctrl+L: tek SELECT'te plan, iki komutta "Plan için tek bir komut seçin."
8. Dil değiştirip (en, de) yeni mesajların çevrildiğini görün.

Aşama 3'e **geçilmedi**, onayınızı bekliyorum.

