# Aşama 2b Raporu (Adım 0: derleme ve ölçümler)

Dal: `asama2b` (`claude/sleepy-pascal-nd1dcw` üzerinden açıldı, `main`'e yazılmadı). Bu rapor yalnızca **Adım 0**'ı kapsar. Adım 1-4 (plan, Ctrl+Boşluk, çoklu komut, testler) **henüz başlamadı**; Adım 0 sonuçlarını görmenizi ve aşağıdaki sorunuzu yanıtlamanızı bekliyorum.

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
