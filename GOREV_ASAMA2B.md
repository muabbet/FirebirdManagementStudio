# Görev: Aşama 2b, Aşama 2'yi tamamlama

Bu görev, **Delphi/RAD Studio 12 ve gerçek Firebird sunucuları olan makinede** çalışacak ajan içindir (Linux'ta çalışan ajan derleyemediği için Aşama 2 derlenmeden geldi).

**Önce `CLAUDE.md` dosyasının tamamını oku** (özellikle Bölüm 3 kod kuralları, Bölüm 5 bileşen politikası, Bölüm 6 çok dillilik, Bölüm 10 güvenlik, Bölüm 12 çalışma kuralları). Sonra `ASAMA2_RAPOR.md` dosyasını oku: Aşama 2'de ne yazıldığı, nelerin denenmediği orada.

- Çıkış dalı: `claude/sleepy-pascal-nd1dcw` (Aşama 2 kodu burada). Ondan `asama2b` adlı yeni bir dal aç. `main`'e yazma.
- Tüm yanıt ve rapor Türkçe. Üç dil dosyasını (tr, en, de) her yeni yazı için güncelle. Dosya silme yok (`_arsiv`). Yeni bileşen ekleme (SynEdit paketindekiler dışında). Belirsiz bir şey olursa tahmin etme, sahibine sor.
- Sahibin kararları: aşağıdaki 1-4. maddelerin hepsi onaylandı.

---

## Adım 0: Derle ve düzelt (zorunlu, ilk iş)

Aşama 2 kodu hiç derlenmedi. `Derle.bat` (Win64 Release) ile temiz derle. Çıkan hataları **en küçük değişiklikle** düzelt, kuralları bozma. Beklenen şüpheli yerler:

- `uEditor.pas`: SynEdit adları (`TSynSQLSyn.SQLDialect`, `sqlInterbase6`, `Gutter.ShowLineNumbers`, `SelAvail`, `SelText`). GetIt'teki sürümde farklıysa yalnızca bu unit'te düzelt.
- `uSorgu.pas`: `OpenOrExecute`, `RowsAffected`, `ResourceOptions.*` adları, `TStopwatch`, `TRegEx`.
- `uSonucGrid.pas`: `Canvas.TextRect` (TTextFormat sürümü), `IndexFieldNames`, `Columns.State := csDefault`.
- `uBaglanti.pas`: `Hata.Errors[i].Kind` ve `ekUKViolated/ekFKViolated/ekObjNotExists`. `GDS_TOKEN_UNKNOWN = 335544634` değerini Firebird `iberror_c.h` ile **doğrula**, yanlışsa düzelt.

Sonra `ASAMA2_RAPOR.md` Bölüm 4'teki elle deneme listesinin **otomatik yapılabilen** kısmını kendin dene (bir sorgu sekmesi aç, SELECT çalıştır, 500'den fazla satır dönen bir sorguda aşağı inince satırların arttığını, ikinci sekmede `insert` çalışırken ilk sekmenin sonucunun bozulmadığını doğrula). Özellikle şunları gerçek veritabanında (2.5.9 ve 5.0.4) ölç ve rapora yaz:
1. `fmOnDemand` ile gerçekten parça parça geliyor mu (`RecordCount` 500, 1000, ...)?
2. Kısmen yüklenmiş sonuçta başlık sıralaması nasıl davranıyor?
3. Açık bir sorgu sekmesi varken başka sekmede `insert`/`commit` yapınca açık sonuç bozuluyor mu?

Hata veya beklenmedik davranış varsa düzelt; düzeltemiyorsan raporda aç aç yaz.

---

## Adım 1: Sorgu planı (iki yol, sırayla denenecek)

Amaç: SQL editöründeki komutun **çalıştırılmadan** (sadece prepare edilerek) Firebird sorgu planını göstermek. Plan almak komutu çalıştırmamalı; INSERT/UPDATE/DELETE için bile veri değişmemeli.

Sahibin kararı: **önce A, olmazsa B'yi dene; hangisi işi daha az kodla ve sade çözüyorsa onu kullan.** Kullanmadığın yolun kodunu depoda bırakma. Her iki yolu da 2.5.9 ve 5.0.4 sunucularında dene.

**A. FireDAC iç yolu.** `FireDAC.Phys.IBWrapper.TIBStatement` içindeki `sql_get_plan` (ve Firebird 3+ için `sql_explain_plan`) özelliğini kullan. `TFDQuery.Command.CommandIntf` üzerinden `TFDPhysIBCommand` ve onun ifadesine ulaşmanın yolunu bul. Özel (private) alana ulaşmak için class helper/RTTI gerekiyorsa bu yolu **sade bulma**, B'ye geç ve nedenini raporla.

**B. İstemci API'si.** `fbclient.dll` içindeki `isc_dsql_sql_info` ile `isc_info_sql_get_plan` (22) isteği (sabitlerin değerini `ibase.h`'den doğrula). Ayrı bir kısa bağlantı/işlem açarak (`isc_attach_database`, `isc_start_transaction`, `isc_dsql_allocate_statement`, `isc_dsql_prepare`, `isc_dsql_sql_info`, kapat). Bu yol Windows/istemciye bağlıdır, kodu tek yerde (uSorgu içinde küçük bir bölüm veya yeni bir `uPlan.pas`; `uPlan.pas` eklersen Bölüm 4 tablosuna ekle) tut. 32/64 bit: Win64.

Arayüz:
- `uSorgu.pas` (veya `uPlan.pas`): `function SorguPlaniAl(Bag: TAcikBaglanti; const Sql: string): string;`
- Araç çubuğuna **Plan** düğmesi (6. düğme, `Ikonlar`'a uygun bir Tabler ikonu ekle, örn. `list-tree` veya `route`; kaynak SVG'yi `Ikonlar\svg`'ye, PNG 32x32'yi `Ikonlar`'a koy, `uIkon.pas` listesine ve `LISANSLAR.md`'ye gerek yok, aynı Tabler). Kısayol **Ctrl+L**.
- Plan, sorgu sekmesinin mesaj kutusunda başlıkla gösterilir ("Sorgu planı:" + plan metni). Hata olursa anlaşılır cümle + Ayrıntı.
- Seçim/komut belirleme Adım 3'teki kuralla aynı; plan **tek komut** içindir. Birden fazla komut varsa seçili/ilk değil, kullanıcıya "Plan için tek bir komut seçin" uyarısı ver.
- Dil anahtarları: `BTN_PLAN`, `MSG_PLAN_BASLIK`, `ERR_PLAN_TEK_KOMUT`, `ERR_PLAN_ALINAMADI` vb., üç dilde.

---

## Adım 2: Ctrl+Boşluk otomatik tamamlama

Sahibin isteği: SQL yazarken **Ctrl+Boşluk** ile öneri listesi açılsın.

- Bileşen: SynEdit paketindeki `TSynCompletionProposal` (yeni bir paket/bileşen **değil**, SynEdit'in içinde). Kullanılmıyorsa veya yoksa dur ve sahibine sor.
- Yalnızca `uEditor.pas` içinde (formlar bilmez). `TSqlEditor`'a, ör. `AnahtarKelimeleriYukle(const Dosya, Surum: string)` ve `NesneAdlariniVer(Liste: TStrings)` gibi **basit** işlevler eklenir. Kod sade kalsın.
- Öneri kaynağı 1: **`anahtar_kelimeler.txt`** (uygulamanın yanında, `SonDerleme.bat` zaten kopyalıyor). Biçim: satır başına bir kelime, `#` ile başlayan satırlar yorum, `#FB3`, `#FB4`, `#FB5` gibi başlıklar o sürüm ve sonrası için geçerli bölümleri ayırır. Bağlı sunucunun sürümüne (`TAcikBaglanti.Surum`) göre, **o sürümde var olan** bölümler önerilir. Dosyayı Firebird 2.5, 3.0, 4.0 ve 5.0 Language Reference'larından (anahtar kelimeler ve veri tipleri) **gerçek içerikle doldur** (şu an 24 kelime var). Sürüme özgü olanları (örn. `BOOLEAN` FB3, `INT128` / `TIMESTAMP WITH TIME ZONE` FB4, `DECFLOAT` FB4) doğru bölüme koy ve kaynağı rapora yaz. Bu listeler kodun içine gömülmeyecek (Bölüm 9.3).
- Öneri kaynağı 2: bağlı veritabanının **tablo, view, prosedür, generator adları** (`uMetadata` zaten listeliyor; sekme açılırken bir kez al, `fSorguSekme` içinde `TSqlEditor`'a ver).
- Öneri kaynağı 3 (**zorunlu, sahibin özel isteği**): **kolon önerisi.** İmleçten hemen önce `ad.` yazılmışsa (örn. `select m. from musteri m` içinde `m.`) `ad`, SQL metnindeki **takma ad** (alias) veya doğrudan tablo adı olarak çözülür ve o tablonun kolon adları önerilir. Çözümleme basit olsun: editördeki metinde `FROM` ve `JOIN` sonrası `tablo [AS] takma_ad` kalıplarını bulan küçük bir işlev (`uEditor.pas` veya `uSorgu.pas` içinde, kendi kodumuzla, örn. `TRegEx`). Takma ad yoksa `ad` tablo adı kabul edilir. `ad.` yazılınca Ctrl+Boşluk'a basmadan da kolon listesi açılsın (nokta yazıldığı anda) ve tablo bulunamazsa liste açılmasın, hata verilmesin. Kolonlar `uMetadata.KolonTablosuOlustur` ile alınır, aynı tablo için sekme açıkken bir kez alınıp saklanır (her tuş vuruşunda sorgu atma). İmleç `FROM` yazılmadan önceki bir `select m.` satırında olabilir: tüm metin taranır, imleçten sonraki `FROM` da bulunur.
- Liste yazıya göre süzülür (SynEdit'in standart davranışı). Büyük/küçük harf duyarsız.
- SQL anahtar kelimesi seçilince büyük harf yazılır.

---

## Adım 3: Çoklu komut çalıştırma (IBExpert gibi)

Sahibin isteği: **Editörde birden fazla komut varsa, seçtiğim kısım çalışsın; seçili kısmın içinde birden fazla komut varsa hepsi sırayla çalışsın.** (IBExpert'teki gibi.)

Kurallar (bunları değiştirme, belirsizlik görürsen sor):
- Çalışacak metin: seçili yazı varsa **yalnızca o**, yoksa editördeki tüm yazı (`TSqlEditor.CalistirilacakMetin` zaten böyle).
- Metin **bir** komutsa, mevcut davranış aynen kalır (sonuç ızgarası, 500'er satır, hata gösterimi).
- Metin **birden fazla** komutsa hepsi sırayla çalışır. Son SELECT'in sonucu ızgarada kalır. Mesaj kutusunda her komut için bir satır yazılır ("1) 3 satır etkilendi (12 ms)", "2) tamam", ...). **İlk hatada durur**, hata mesajına kaçıncı komut olduğu yazılır ("3. komutta hata: ..."). Önceki komutlar otomatik onaylandığı için geri alınmaz, bu mesajda **açıkça yazılsın** (Bölüm 10: işlem davranışı açık olmalı).
- Komutlara bölme `uSorgu.pas` içinde, kendi basit kodumuzla: `function KomutlaraBol(const Metin: string): TArray<string>;`. `isql` gibi **`SET TERM`** desteklenir (yeni sonlandırıcıya göre böler; `CREATE PROCEDURE ... BEGIN ... ; ... END ^` gibi gövdelerdeki `;` komutu bölmez). Tırnak (`'...'`, `"..."`) ve yorum (`--`, `/* */`) içindeki `;` bölmez. Boş komutlar atılır.
- `COMMIT` / `COMMIT WORK` komutları: otomatik onay zaten açık olduğu için **atlanır**, mesajda "atlandı (otomatik onay açık)" yazılır. `ROLLBACK`: **desteklenmez**, o noktada durur ve açık cümleyle nedenini yazar (kullanıcı geri alındı sanmasın). `SET SQL DIALECT`, `CONNECT`, `SET NAMES` gibi isql komutlarının DSQL'de çalışmadığını bil; çalışmayanlar için anlaşılır uyarı ver, sessizce yutma.
- **Onay penceresi:** Bölünen komutlardan **herhangi biri** tehlikeliyse (`TehlikeliSorguUyarisi`) çalıştırmadan önce **tek bir** onay penceresi göster, pencerede kaç komutun çalışacağı ve hangi komutun tehlikeli olduğu (komutun ilk ~60 karakteri) açıkça yazılsın. Hayır denirse hiçbiri çalışmaz.
- Plan (Adım 1) ve gerçek çalıştırma ayrı: Plan çoklu komutta uyarı verir.
- Dil anahtarları: ör. `MSG_KOMUT_SATIRI`, `ERR_KOMUT_HATASI` (`%d. komutta hata`), `MSG_COMMIT_ATLANDI`, `ERR_ROLLBACK_YOK`, `ONAY_COKLU_KOMUT` ve diğerleri, üç dilde.

---

## Adım 4: Testler

`Test\` altında yeni bir `SorguTest.dpr` (mevcut `MetadataTest.dpr` / `BaglantiDosyasiTest.dpr` biçimine uy) yaz. Geçici veritabanlarıyla (gömülü 5.0.4 ve 2.5.9 sunucu; **gerçek veriye dokunma**):

- `KomutlaraBol`: basit `;`, tırnak/yorum içinde `;`, `SET TERM ^ ;` ile prosedür gövdesi, boş komutlar, son satırda `;` olmaması.
- `TehlikeliSorguUyarisi`: `DROP`, `ALTER TABLE ... DROP`, WHERE'siz `DELETE/UPDATE`, WHERE'li olanlar, `UPDATE OR INSERT`, yorum/yazı içinde `drop`.
- `SorguCalistir`: SELECT (500'den fazla satır, `RecordCount` artışı), INSERT/UPDATE (`Etkilenen`), DDL, hatalı SQL (hata cümlesi: benzersiz ihlali, yabancı anahtar, nesne yok, yazım hatası).
- Plan: SELECT için plan geliyor ve **INSERT planı alınınca satır eklenmiyor**. Hem 2.5.9 hem 5.0.4.
- Çoklu komut: 3 komutluk bir betik, ortada hata olan betik (2. komut hata verince 3. çalışmamış olmalı), `COMMIT` atlama, `ROLLBACK` durdurma.
- Mevcut testler (`BaglantiDosyasiTest`, `MetadataTest`) hâlâ geçmeli.

---

## Bitiş ve rapor

- `CLAUDE.md` Bölüm 11 Aşama 2 listesine iki madde ekle: `Ctrl+Boşluk otomatik tamamlama`, `Çoklu komut çalıştırma (seçili kısım)` (kutuları **işaretleme**, sahip onaylayınca işaretlenir). "Sorgu planını göstermek" maddesi zaten orada.
- `README.md` ve `LISANSLAR.md` gerekirse güncelle. Bölüm 4 tablosuna yeni unit eklediysen yaz.
- `ASAMA2B_RAPOR.md` yaz: ne yapıldı, ne test edildi (hangi Firebird sürümünde, hangi sonuç), Adım 0'daki ölçümlerin sonuçları, plan için A ve B'den hangisi seçildi ve **neden** (kısaca, kod satırı/karmaşıklık), neler eksik kaldı, sahibin Windows'ta elle deneme listesi.
- Sahibinden onay alınmadan Aşama 3'e geçme.
