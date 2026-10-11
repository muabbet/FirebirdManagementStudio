# Aşama 2c Raporu

Dal: `asama2c` (`asama2b` üzerinden açıldı, `main`'e yazılmadı). `Derle.bat` (Win64 Release) hatasız derlendi.

## Adım 1: Mesaj kutusu

- `fSorguSekme.pas`: mesaj yazan her yer tek yardımcıdan geçiyor: `MesajYaz(const Metin)` (metni yazar, kutuyu **en üste** kaydırır: `EM_LINESCROLL`). Hata, plan, tek komut, çoklu komut, "boş sorgu", "bağlantı yok", "vazgeçildi" hepsi bunu kullanıyor. `HataYaz` ve çoklu komut artık metni birleştirip tek seferde yazıyor (satır satır `Lines.Add` kalmadı).
- `fSorguSekme.dfm`: kutu 80 → 115 px; kutunun üstüne `BolucuMesaj` (TSplitter, olay yok) eklendi, kutu elle yeniden boyutlanabilir.
- Çoklu komut sırası değişmedi: başarılı satırlar, hata satırı, "Ayrıntı", "Hatadan sonraki N komut çalıştırılmadı", sonda otomatik onay notu. Yalnızca kaydırma düzeltildi (görev metnindeki "yalnızca kaydırmayı düzeltmek yeterli olabilir" yolu).
- **Arayüzde denemedim.** Kodu derledim, ama uzun/hatalı betiği programın penceresinde çalıştırıp ilk satırı görmedim (masaüstü otomasyonuyla bağlantı penceresini sürmedim). Elle deneme listesi aşağıda. Not: 115 px yaklaşık 7 satır; ortada hata olan çok uzun betikte hata satırı kutunun altında kalabilir, o zaman kaydırma çubuğu/ayırıcı kullanılır. İsterseniz hata satırını her zaman en üste koyarız (karar sizin).

## Adım 2: Açık SELECT sonucu tabloyu kilitliyor

### Ölçüm (Firebird 5.0.4 gömülü, geçici veritabanı; `SorguTest` içinde)

Tablo 1200 satır, A sekmesi `select * from t order by id` açık (yalnızca ilk 500 satır çekilmiş), B sekmesi başka işlemle:

| Senaryo | Sonuç | Hata listesi (FireDAC `Errors[i]`) |
|---|---|---|
| A açık, `drop table t` | **reddedilir** | tek kayıt: `335544351` (isc_no_meta_update), Kind 0. Mesaj metni: "lock conflict on no wait transaction / unsuccessful metadata update / object TABLE "T" is in use" |
| A açık, `alter table t add c integer` | geçer | – |
| A açık, `create index` | geçer | – |
| A açık, `insert` / `update` / `delete` | geçer | – |
| A bırakıldı (sonuç serbest), `drop table` | geçer | – |
| Betik `select * from t; drop table t;` | 2. komut hata: aynı "is in use" | aynı |

Önemli bulgu: `isc_obj_in_use` (335544453) FireDAC hata listesinde **hiç yok**; "in use" yalnızca mesaj metninde. Bazı çalıştırmalarda listede ilk kod `335544345` (lock_conflict, Kind `ekRecordLocked`) çıkıyor ve eski kodla kullanıcıya "Kayıt başka bir kullanıcı tarafından kilitlenmiş" yazılıyordu. Yani kodla kayıt kilidi ile nesne kilidi ayırt edilemiyor. Görevin izin verdiği yol: mesaj metninden ayırdım.

Sabit `isc_obj_in_use = 335544453`, hem Firebird 5.0 (`include\firebird\impl\iberror_c.h`) hem 2.5 (`Firebird_2_5\include\iberror.h`) başlığıyla doğrulandı.

### Düzeltme

- `uSorgu.BetikCalistir`: **DDL** komutundan (`ALTER`, `DROP`, `RECREATE`, `CREATE OR ALTER`; yeni `KomutDDLMi`) önce tutulan SELECT sonucu kapatılır. DML'de tutulmaya devam eder. Kayda `OncekiSonucKapandi` yazılır, mesaj satırı: "N) öncesinde önceki sonuç kapatıldı (nesne kullanımda kalmasın)." (`MSG_ONCEKI_SONUC_KAPANDI`). `ALTER ADD` ölçümde zaten geçiyordu, ama `ALTER ... DROP` gibi biçimler için listede bırakıldı (ölçmedim).
- `uBaglanti.HataMetniniCevir`: mesajda `" is in use` varsa `ERR_NESNE_KULLANIMDA` (tr/en/de) gelir, öbür kontrollerden önce. `GDS_OBJ_IN_USE` kod dalı da eklendi (zararsız). `ERR_KILIT` kayıt kilidi için aynen duruyor.
- Başka sekmedeki sonuç kendiliğinden kapatılmıyor.

### Yeni testler

`SorguTest`: 66 → **80 kontrol, hata 0** (5.0.4 gömülü). Yeni 14: açık SELECT varken DROP cümlesi, ALTER ADD/CREATE INDEX/DML geçer, sonuç bırakılınca DROP geçer, betik `select; drop`, `select + DML` (sonuç kalır), `select; alter; select`. Test, gömülü kipte veritabanı dosyası yoksa kendisi oluşturur (`GeciciVeritabaniOlustur`), elle hazırlık gerekmez. `BaglantiDosyasiTest` hata 0; `MetadataTest` derlendi, geçici veritabanında çıkış kodu 0 (ekrana çıktı yazmadı).

### Çözülemeyen gözlem

Test sonunda `DROP TABLE SORGUTEST_T` hâlâ "is in use" veriyor (önceki rapordaki gözlem). Araştırdım: `mon$statements` ve `mon$transactions` bu bağlantıda açık ifade/işlem göstermiyor; 4 sn beklemek ve ikinci bağlantıdan denemek işe yaramadı; ayrı ayrı denediğim işlemlerin (plan, benzersiz/FK ihlali, UPDATE, betikte hata, ana/alt tablo) hiçbiri sonrasında tabloyu kullanımda bırakmadı. Nedeni **bulamadım**; yalnızca test veritabanında, uygulamayı etkilemiyor (test başında artıklar temizleniyor). Araştırma kodunu testten çıkardım.

### Sahibinden beklenenler (şifre gerektiği için yapılamadı)

Firebird 2.5.9 (3050) ve 5.0.4 sunucu (3051) ölçümü. `SorguTest` içinde yeni bölüm hazır; `ASAMA2B_RAPOR.md` Bölüm 5'teki komutlarla çalıştırıp çıktıyı bana okutun. Özellikle bakılacak: 2.5.9'da açık SELECT + `drop table` mesajında `" is in use` metni gerçekten geliyor mu ve `ERR_NESNE_KULLANIMDA` çıkıyor mu; `alter table add` 2.5'te de geçiyor mu (testte kontrol var, geçmezse "HATA" yazar).

## Adım 3: SynEdit lisansı

Kaynaktan okunan:
- Yerel kopyada (`...\SynEdit\Source`) ayrı lisans dosyası **yok**, yalnızca `readme.md` ("TurboPack SynEdit, 10.4 Sydney / VER340 / PKG 270") ve kaynak dosya başlıkları var.
- Dosya başlıkları: MPL 1.1 **veya** GNU GPL 2+. Telif: Martin Waldenburg (mwEdit, 1998), Maël Hörz (Unicode), katkıda bulunanlar `Contributors.txt`'te.
- GitHub `TurboPack/SynEdit` `LICENSE` dosyası: MPL 1.1 **veya** GNU LGPL 2.1+. Yani başlıklarla (GPL 2+) GitHub'daki (LGPL 2.1+) **farklı**; ortak seçenek MPL 1.1.
- `LISANSLAR.md` SynEdit satırı ve notu düzeltildi (sürüm, iki lisans metni farkı, edinme: GitHub, kütüphane yoluna eklenir, depoya konmaz). Hazır pakete MPL notu konması gerektiğini/önerildiğini ve kararın sahibinde olduğunu "Notlar"a yazdım.
- `README.md` Derleme bölümü: "SynEdit (TurboPack) kütüphane yolunda olmalı (RAD Studio 12 GetIt sürümü kurulu olmayabilir)". Yerel yol yazılmadı.
- CLAUDE.md Bölüm 5 bildirimi: SynEdit GetIt'ten değil GitHub kaynağından (TurboPack, 10.4 sürümü) kullanılıyor; sahibine bildirilmişti, burada tekrar bildiriyorum.

## Adım 4: Temizlik

1. **Öneri listesinde seçili satır (`m.` → KODU yerine SIRANO): yapılmadı.** Çalışan arayüz olmadan nedenini doğrulayamadım. `SynCompletionProposal.pas` içinde `Position` yalnızca `CurrentString` değişince 0'a çekiliyor; `.` ile tetiklenen listede `CurrentString`'in ne olduğu (örn. "." mı) şüpheli, ama denemeden kod değiştirmedim. Önerim: sonraki turda Delphi hata ayıklayıcıyla `OneriHazirla` sonrası `Position` değerine bakmak.
2. `ASAMA2B_RAPOR.md` bayat iki yere not eklendi (dosya silinmedi).
3. `README.md`'ye "Test klasörü: geliştirici ölçüm ve testleri, kullanıcı için gerekmez" satırı eklendi.

## Sahibin elle deneme listesi

1. Sorgu sekmesinde 10+ satır çıktı üreten betik (örn. 12 komut) çalıştırın: mesaj kutusunun ilk satırı görünüyor mu?
2. Ortada hata olan betik (`select 1 from rdb$database; selec 2; select 3`): hata satırı ve "Ayrıntı" görünüyor mu, kutu yukarıda mı? Ayırıcıyı sürükleyerek boyutlandırın.
3. Uzun plan (Ctrl+L, çok tablolu sorgu): plan başı görünüyor mu?
4. Geçici tabloda: sekme A `select * from t` (açık kalsın), sekme B `drop table t`: yeni "bu nesne başka bir sorgu sekmesinde ... açık" cümlesi çıkıyor mu?
5. Tek betik `select * from t; drop table t;`: önce onay penceresi, sonra "önceki sonuç kapatıldı" satırı, DROP geçiyor mu? (Gerçek veride değil, geçici tabloda.)
6. Dil değiştirip (tr/en/de) 4 ve 5'i tekrarlayın.
7. `m.` listesi hâlâ ikinci satırı mı seçili açıyor (Adım 4.1 açık kaldı).

## Yapılmayanlar

Aşama 2 kutuları CLAUDE.md'de işaretlenmedi, Aşama 3'e geçilmedi. Firebird 2.5.9 ve 5.0.4 sunucu testleri ile Adım 1'in arayüz denemesi sahibinde.
