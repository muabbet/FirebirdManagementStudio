# Aşama 3d-2 / 3d-3 raporu: Yetkiler (görüntüle, ver, geri al)

Dal: `asama3d`. Yerel çalışma, itme/PR yok, `CLAUDE.md` kutularına dokunulmadı, dosya silinmedi, yeni üçüncü parti bileşen yok.
**Pencerelerin görünümünü elle denemedim**; her adım hatasız derlendi, mantık testlerle dört sürümde denendi.

## Ekran (sade tutuldu: tek pencere, tek yol)

- **Tablo, view veya prosedüre sağ tık → "Yetkiler..."** (tablo menüsü 6 madde, view 5, prosedür 4). Pencere o nesnede kimin ne yetkisi olduğunu listeler (kullanıcı, rol, herkes/PUBLIC; yetkiler ve "başkasına verebilir"). Altta **Yetki ver...** ve **Yetkiyi geri al...** düğmeleri.
- **Kullanıcılar sekmesi → "Yetkileri..." düğmesi** (Yeni kullanıcı'nın yanında): seçili kullanıcının hangi nesnelerde ne yetkisi olduğunu listeler. Altta **Hepsini geri al...**.
- **Yetki ver penceresi:** Kime (Kullanıcı / Rol / Herkes), ad (kullanıcı ya da rol listesinden seçilir, elle de yazılabilir), yetkiler (SELECT, INSERT, UPDATE, DELETE, REFERENCES; prosedürde EXECUTE), "başkalarına da verebilsin (WITH GRANT OPTION)". Altta çalışacak SQL canlı görünür.
- **Geri al penceresi:** seçili satırın kişisi ve yetkileri hazır gelir (kişi değiştirilemez), işaretli yetkiler geri alınır.
- Her işlemde net onay (komut gösterilir; PUBLIC'e ve GRANT OPTION'a ek uyarı), tek açık işlemde çalışır, SQL ana pencerenin alt alanında görünür, hata anlaşılır cümleyle.

## Kod

`uYetki.pas` (yeni): okuma (`NesneYetkileriOku`, `KullaniciYetkileriOku`), komut üretimi (`YetkiKomutu`), onay metni, uygulama, `HepsiniAlKomutlari/Uygula`. Formlar: `fYetkiler` (liste), `fYetkiVer` (ver/geri al penceresi). `fAna`, `fKullanicilar` yalnız menü/düğme ekler. Üç dilde yeni anahtarlar (596 anahtar).

## Test: `YetkiTest.dpr` (45 kontrol)

5.0.4 gömülü 45/0, 3.0.14 gömülü 45/0, 4.0.7 sunucu 45/0, 2.5.9 sunucu 45/0. İçerik: komut üretimi, doğrulama, kullanıcıya/role/PUBLIC'e verme, WITH GRANT OPTION, kolon düzeyi yetkinin okunması (`UPDATE (AD)`), view, prosedür EXECUTE, geri alma, hepsini geri alma (rol üyeliğine dokunmaz), hata cümleleri, pencerelerin `.dfm` duman testi. Ölçülen: **verilmemiş yetkiyi geri almak hata vermez** (dört sürüm); olmayan nesneye yetki verilince "nesne bulunamadı" cümlesi çıkar.

## Bilinen sınırlar

- Pencere yalnız **tablo düzeyi** yetkiyi verir/alır; kolon düzeyi yetkiler (`UPDATE (AD)`) listede görünür ama verilmez (elle SQL).
- Rol üyeliği (`GRANT rol TO kullanıcı`), generator/exception (`USAGE`) yetkileri ve rol yönetimi bu aşamada yok; üyelikler kullanıcı penceresinde "Rol üyeliği" olarak görünür, "Hepsini geri al" onlara dokunmaz.
- Nesnenin sahibinin ve SYSDBA'nın yetkileri listede görünmez (Firebird bunları otomatik verir).
- Yetki vermeyi yalnızca nesnenin sahibi, SYSDBA ya da "grant option"lı kullanıcı yapabilir; yetkisizse mevcut cümle ("Bu işlem için yetkiniz yok") çıkar. Başka kullanıcıyla bu hata üretilmedi (yetkisiz ikinci bağlantı testte yok).
- Kullanıcı adı listesi sunucu kipinde okunur; okunamazsa (gömülü bağlantı, yetkisiz) kutu boş kalır, ad elle yazılır.

## Önemli düzeltme (aynı oturumda bulundu, `main`'e de alındı: `263ef0d`)

Tek-.exe paketi (`paket` dalı) sırasında üç dosyada `anahtar_kelimeler.txt` yolu bozulmuştu (`\a` karakteri "zil" karakterine dönmüş). Sonuç: **SQL editörü kelime önerileri ve metadata çıkarımında ayrılmış kelime adlarının tırnaklanması çalışmıyordu** (örn. `ORDER` adlı kolon). `DDLTest` yakaladı. `uDDL`, `fSorguSekme`, `fProsedurSekme` düzeltildi; DDLTest/SorguTest tekrar geçiyor. **Bu düzeltmeden önce derlenen exe'ler bu iki özellikte eksik çalışır**; müşteri exe'sini yeniden derleyip verin.

## Sahibine deneme listesi

1. Tabloya sağ tık → Yetkiler: liste açılıyor, Yetki ver → bir kullanıcı seç, SELECT + INSERT işaretle, SQL önizlemesi doğru mu; onay → liste yenileniyor, alt alanda `GRANT ...` görünüyor.
2. Aynı satır → Yetkiyi geri al: kişi ve yetkiler hazır geliyor, INSERT'i geri al.
3. Prosedüre sağ tık → Yetkiler → EXECUTE ver.
4. Herkese (PUBLIC) ver: ek uyarı çıkıyor mu.
5. Kullanıcılar sekmesi → bir kullanıcı seç → Yetkileri...: yetkileri listeleniyor; Hepsini geri al → onay listesi.
6. Almanca'da pencereler/düğmeler kesilmeden görünüyor mu.
7. SQL editöründe `ord` yazıp Ctrl+Boşluk: ORDER önerisi çıkıyor mu (düzeltme kontrolü).
