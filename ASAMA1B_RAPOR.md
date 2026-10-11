# Aşama 1b Raporu: Çoklu bağlantı ağacı

Dal: `asama1b-coklu-baglanti` (`main` d831c08 üzerine). `main`'e yazılmadı. SynEdit'e dokunulmadı, projeye eklenmedi, yeni bileşen yok.

## 1. Ne yapıldı

- **`uBaglanti.pas`**: Tek global bağlantı (`GBaglanti`, `FbBaglantisi`) kalktı. Yerine basit bir liste var: `TAcikBaglanti` (tanım, sürüm, `TFDConnection`) nesneleri tek bir listede tutulur. `FbBaglan(Tanim)` bağlantıyı listeye ekler ve diğerlerini kapatmaz (aynı adlı bağlantı zaten açıksa onu verir). `FbBaglantiyiKes(Bag)`, `FbAcikBaglanti(Ad)`, `FbIslemAcikMi(Bag)` var. Eski tek-bağlantı işlevleri silindi, ikinci yol yok.
- **`uMetadata.pas` / `uSorgu.pas`**: Tüm işlevler hangi bağlantıyla çalışacaklarını ilk parametre olarak alır (`TablolariGetir(Bag, ...)`, `KolonTablosuOlustur(Bag, ...)`, `TabloVerisiSorgusu(Bag, ...)`).
- **`baglantilar.json`**: Her bağlantıda `Klasor` alanı, kökte boş klasörler için `Klasorler` listesi. Eski biçimdeki dosya (bu alanlar yok) aynen okunur. Atomik yazma (`.tmp` + `MoveFileEx`) ve bozuk dosyayı silmeden `.bozuk-...` adıyla yanına taşıma davranışı aynı. Dosyada listede olmayan bir klasör adı geçerse (elle bozulmuş) klasör kaybolmaz, listeye eklenir.
- **`uBaglanti.pas` klasör işlevleri**: `KlasorEkle`, `KlasorYenidenAdlandir`, `KlasorKaldir`, `BaglantiKlasoruAyarla`. Ad boş veya aynı (büyük/küçük harf fark etmez) ise `EKayitKurali` ile anlaşılır cümle verir.
- **`BaglantiKaydet(Tanim, EskiAd)`**: Ad değiştirmeyi (düzenleme) destekler; sıra ve klasör korunur.
- **Ağaç (`fAna`)**: Açılışta kökte klasörler (üstte) ve kayıtlı bağlantılar görünür, hiçbiri bağlı değildir (kapalı bağlantı "fişi çekilmiş" ikonuyla, açık olan veritabanı ikonuyla). Çift tık veya sağ tık "Bağlan" ile bağlanır, altında dört dal dolar. Birden fazlası aynı anda açık kalır.
- **Sağ tık menüleri**: Bağlantı: Bağlan, Bağlantıyı Kes, Yenile, Düzenle, Kayıttan Kaldır (5 madde). Klasör: Yeniden adlandır, Klasörü kaldır. Boş alan: Yeni klasör. Tablo: Aç, Yenile. Menü maddeleri tıklanan düğüme göre gizlenir/gösterilir.
- **Kayıttan Kaldır**: `OnayIste` ile sorar. Bağlantı açıksa önce kesileceğini ve sekmelerin kapanacağını yazar. Listeden ve `baglantilar.json`'dan çıkarır, veritabanına dokunmaz.
- **Klonla** (sağ tık): seçili bağlantının bilgileriyle dolu, adı "… (kopya)" olan yeni bağlantı penceresi açar; kayıt kaynağın klasörüne girer. Bağlantı menüsü 6 madde oldu.
- **Düzenle**: Bağlantı açıksa önce kesileceğini yazan onay penceresi çıkar. Bağlantı penceresi artık "yeni/düzenle" penceresi: Kaydet (sadece kaydeder), Bağlan (bağlanır, başarılıysa kaydeder), Kapat. Sol taraftaki kayıtlı liste, Yeni ve Sil düğmeleri kalktı (liste artık ağaçta). Aynı adlı ikinci kayıt reddedilir.
- **Klasörler**: Araç çubuğundan veya kök sağ tık menüsünden "Yeni klasör". Yalnızca düz klasör. Bağlantıyı fareyle klasörün üstüne bırakınca klasöre girer (standart `TTreeView` olayları: `OnMouseDown` + `BeginDrag`, `OnDragOver`, `OnDragDrop`). Bağlantıyı ağacın boş alanına bırakmak onu kök düzeye çıkarır (klasörden çıkarmanın sürükle-bırak yolu). Klasör kaldırılınca içindeki bağlantılar silinmez, kök düzeye çıkar (onay ister).
- **Şifre**: Kayıtlı şifresi olmayan bağlantıya bağlanırken küçük "Şifre girin" penceresi (`fMetinSor.pas`, `PasswordChar`) çıkar. Şifre kaydedilmez, yalnızca o bağlantı için kullanılır. Aynı küçük pencere klasör adı sorarken de kullanılıyor.
- **Durum çubuğu**: Ağaçta seçili bağlantının adı, Firebird sürümü ve işlem durumu (açık/kapalı). Bağlı olmayan bağlantı seçilince "Bağlı değil", hiçbir şey seçili değilse yönlendirme yazısı.
- **Sekmeler**: Tablo sekmesi hangi bağlantıya ait olduğunu bilir (`BaglantiAd`, `TabloAdi`). Başlık: `Tablo [Bağlantı]`. Aynı adlı tablo iki ayrı bağlantıda ayrı sekmelerde açılır, aynı bağlantıda tekrar açılırsa mevcut sekmeye geçilir. Bağlantı kesilince veya kayıttan kaldırılınca o bağlantının sekmeleri kapanır (önce sekmeler, sonra bağlantı).
- **Araç çubuğu** (tek çubuk, 6 düğme): Yeni Bağlantı, Bağlan/Bağlantıyı Kes (tek düğme, seçili bağlantının durumuna göre yazısı ve ikonu değişir), Yenile, Yeni Klasör, Klonla, Kayıttan Kaldır. Klonla (`copy`) ve Kayıttan Kaldır (`trash`) ikonları Tabler 3.49.0 setinden eklendi (`Ikonlar\svg` içinde kaynak SVG'leri var).
- **Dil dosyaları**: `tr`, `en`, `de` üçünde aynı anahtarlar (anahtar kontrolü yapıldı: kodda kullanılan her `T('...')` üç dosyada da var, üç dosyanın anahtar listesi aynı). Menü: "Kayıttan Kaldır" / "Unregister" / "Registrierung aufheben". Kullanılmayan eski anahtarlar (`BTN_YENI`, `BTN_SIL`, `LBL_KAYITLI`, `ONAY_BAGLANTI_SIL`) çıkarıldı. `MSG_KESILDI`, `MSG_AGAC_YENILENDI`, `MSG_TABLO_ACILDI` artık bağlantı adı da gösteriyor.
- **`CLAUDE.md`**: Bölüm 8 sol panel satırı ve Bölüm 11 "Aşama 1b" başlığı, istenen metinle eklendi. Aşama 4 maddesi aynen duruyor. `README.md` kısa güncellendi.
- Düğme ve menü genişlikleri yazıya göre uzar (araç çubuğu düğmeleri `AutoSize`, pencere düğmeleri yazıya göre genişletiliyor).

## 2. Ne denendi

- `Derle.bat` ile temiz (Rebuild) derleme: uyarı ve hata yok.
- `BaglantiDosyasiTest`: **52/52 OK**. Eski testler (bozuk dosya, atomik yazma, DPAPI) hâlâ geçiyor. Yeni: eski biçim okuma (2 bağlantı, alanlar doğru, klasör listesi boş, dosya silinmedi), klasör gidiş-dönüşü (boş klasör dahil Türkçe karakterli ad), aynı/boş ad reddi, olmayan klasöre taşıma reddi, bağlantıyı klasöre koyma, düzenlemede klasörün korunması, ad değiştirme, klasör yeniden adlandırma ve kaldırma, bağlantı kaldırılınca klasörün durması, listede olmayan klasör adının kurtarılması.
- `MetadataTest`: Firebird 5.0.4 gömülü kipte iki geçici veritabanıyla (gerçek veriye dokunmadan): iki bağlantı aynı anda açık, aynı adla tekrar `FbBaglan` aynı nesneyi veriyor, birincisi kesilince ikincisi çalışmaya devam ediyor. Ayrıca gerçek sunuculara (localhost 3050 = 2.5.9, 3051 = 5.0.4) bilerek yanlış şifreyle bağlanma denendi: ikisinde de "Kullanıcı adı veya şifre yanlış." cümlesi geldi, açık bağlantı listesine bir şey girmedi. Veritabanı yolu uydurma bir yoldu, gerçek veritabanlarına dokunulmadı.
- Program derlenmiş hâlde açıldı: hata vermeden açılıyor, ağaçta iki kayıtlı bağlantınız (kapalı ikonlarla) görünüyor, araç çubuğu yeni düğmelerle geliyor. Kendi `baglantilar.json` dosyanıza yazılmadı (sadece okundu).

## 3. Neler eksik kaldı / denenmedi

- **Arayüz etkileşimleri elle denenmedi** (çift tıkla bağlanma, sağ tık menüleri, sürükle-bırak, klasör oluşturma/adlandırma/kaldırma, şifre penceresi, sekme kapanması, durum çubuğu). Programın veri klasörü `%APPDATA%` ortam değişkeniyle değiştirilemiyor ve gerçek bağlantılarınızın şifrelerini girmem uygun değil; bu yüzden aşağıdaki liste sizin denemeniz için.
- Sürükle-bırakta `TTreeView.BeginDrag` kullanıldı. Standart bileşen olayları, ama davranışını (özellikle çift tıkla çakışma ve boş alana bırakma) sizin makinenizde görmek gerekiyor.
- Firebird 3.0 ve 4.0 hâlâ denenmedi.
- Bağlantı sunucu tarafından düşerse (ağ koptu) ağaçtaki bağlantı kendiliğinden "kapalı" görünmez, sonraki işlemde hata mesajı çıkar. Aşama 1'de de böyleydi, bu işe eklenmedi.
- Yenile ve bağlantı kesme sırasında silinen ağaç düğümlerinin küçük kimlik nesneleri form kapanana kadar bellekte kalır (birkaç yüz bayt, pratikte önemsiz).
- Klasörlerin ağaçtaki sırası: klasörler üstte, yeni klasör kökteki ilk bağlantının önüne girer. Sürükleyerek bağlantı sırasını değiştirme yok (istenmedi).

## 4. Elle deneme listesi (Windows)

Önce `Derle.bat` ile derleyin (veya IDE'den). Bu denemeler `%APPDATA%\FirebirdYonetici\baglantilar.json` dosyanızı değiştirir; denemeden önce kopyasını almanız iyi olur.

1. **Açılış**: Program açılınca kayıtlı iki bağlantı kökte, kapalı (fişi çekilmiş ikon) görünmeli. Durum çubuğunda "Ağaçta bir bağlantı seçin". Araç çubuğunda 6 düğme var, "Bağlan", "Yenile", "Klonla", "Kayıttan Kaldır" bağlantı seçilene kadar soluk.
2. **İki bağlantı aynı anda**: 2.5.9 bağlantısına çift tıkla (şifre kayıtlı değilse "Şifre girin" penceresi çıkar, `*` ile gizli yazılmalı). Dört dal dolmalı, durum çubuğunda ad + "Firebird 2.5.9" + işlem durumu. Sonra 5.0.4 bağlantısına çift tıkla. İlki kapanmamış olmalı, ikisi de açık.
3. **Aynı anda iki tablo**: Her birinden bir tabloyu çift tıkla aç. İki sekme açılır, başlıkları `Tablo [Bağlantı adı]`. Mümkünse iki veritabanında aynı adlı bir tabloyu aç: iki ayrı sekme olmalı. Aynı tabloya tekrar çift tıklayınca yeni sekme açılmamalı, var olan sekmeye geçilmeli.
4. **Birini kapat**: 5.0.4 bağlantısına sağ tık, "Bağlantıyı Kes". O bağlantının sekmeleri kapanmalı, diğer bağlantının sekmeleri ve ağacı kalmalı. Ağaçta bağlantı yine görünür ama kapalı.
5. **Klasör oluştur**: Araç çubuğundan "Yeni Klasör" (ad iste). Boş alana sağ tıkla: sadece "Yeni Klasör" çıkmalı. Aynı adı tekrar yazınca uyarı çıkmalı. Boş ad girince uyarı çıkmalı.
6. **Sürükle-bırak**: Bir bağlantıyı fareyle klasörün üstüne sürükleyip bırak. Bağlantı klasörün içine girmeli (açıksa dalları da birlikte gelmeli). Ağacın boş alanına bırakınca kök düzeye çıkmalı. Bağlantıyı bağlantının üstüne bırakınca bir şey olmamalı (imleç yasak).
7. **Klasör menüsü**: Klasöre sağ tık: "Yeniden adlandır" (ad değişmeli, içindeki bağlantı klasörde kalmalı), "Klasörü kaldır" (onay sorar; evet deyince bağlantılar kökte kalmalı, silinmemeli).
8. **Kayıttan Kaldır**: Açık bir bağlantıya sağ tık, "Kayıttan Kaldır". Onay penceresi "bağlantı kesilecek" demeli. Hayır de: hiçbir şey olmasın. Sonra evet de: bağlantı kesilir, sekmeleri kapanır, ağaçtan ve listeden kalkar. Veritabanı dosyasına dokunulmamalı. (Bu denemeyi yedeklediğiniz dosyayla ya da önce "Yeni Bağlantı" ile eklediğiniz fazladan bir kayıtla yapın.)
9. **Düzenle**: Açık bağlantıya sağ tık, "Düzenle": önce "bağlantı kesilecek" onayı çıkmalı. Ad değiştirip Kaydet: ağaçtaki ad değişmeli, sıra ve klasör korunmalı.
10. **Kapat ve aç**: Programı kapatıp yeniden aç. Klasörler, bağlantıların klasörleri ve sırası aynı gelmeli. Hiçbir bağlantı açık olmamalı. (`baglantilar.json`'da `Klasorler` ve `Klasor` alanlarına bakabilirsiniz.)
11. **Yanlış şifre**: Şifresi kayıtlı olmayan bir bağlantıda "Şifre girin" penceresine bilerek yanlış şifre yaz: alt alandaki sonuç kutusunda "Kullanıcı adı veya şifre yanlış." çıkmalı, bağlantı açılmamalı, ağaç değişmemeli. Aynısını "Yeni Bağlantı" penceresinde yanlış şifreyle "Bağlan" ile dene: pencerede kırmızı uyarı çıkmalı, pencere kapanmamalı. (Gerçek veritabanlarında da bilerek yanlış şifreyle deneyin.)
12. **Dil**: Sağ üstten Almanca, İngilizce, Türkçe seçin: araç çubuğu, menüler (sağ tıkta "Kayıttan Kaldır" / "Unregister" / "Registrierung aufheben"), dal başlıkları, durum çubuğu anında değişmeli. Almancada yazılar kesilmemeli.
13. **Eski dosya**: Klasör alanları olmayan eski bir `baglantilar.json` ile açıldığında bağlantılar yine görünmeli.
