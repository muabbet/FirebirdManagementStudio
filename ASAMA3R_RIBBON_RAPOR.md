# Aşama 3R: Gruplu şerit (ribbon) raporu

Dal: `asama3r-ribbon` (`main` f5ca9d9 üstünden). Üçüncü parti bileşen yok, `Vcl.Ribbon` yok; yalnızca standart VCL (`TPanel`, `TLabel`, `TBevel`, `TGraphicControl`, `TImageCollection`). `main`'e birleştirme yok.

## Ne değişti

| Dosya | Değişiklik |
|---|---|
| `Kaynak/uSerit.pas` (yeni, ~390 satır) | Şerit, kod ile kurulur. `TSerit` (gruplar, yerleşim, dil yenileme) ve `TSeritDugmesi` (büyük ikon üstte, yazı altta, üzerine gelince/basılınca/pasif görünüm). Renkler `StyleServices`'ten, sabit renk yok. Düğme genişliği yazıya göre uzar; 100 px'i aşan yazı iki satıra bölünür, tüm düğmeler aynı yükseklikte. |
| `Kaynak/fAna.pas` | `tbAna` ve 7 `TToolButton` kalktı; `SeritKur` (satır 195) düğme listesini tek yerde sıralar (grup, yazı anahtarı, ikon, tıklama yordamı). `YazilariYenile` şeridi de yeniler (dil anında değişir). `DurumuGuncelle` şeridin `Enabled` ve Bağlan/Kes durumunu güncelliyor (ayrı kopya yok). Yeni `btnMetadataClick` (1042), `btnYedekClick` (1048). `Vcl.ToolWin` kullanımı kalktı. |
| `Kaynak/fAna.dfm` | `tbAna` bloğu çıkarıldı; `pnlUst` yüksekliği 104 (çalışma anında şerit kendi yüksekliğine ayarlar), ağaç/sağ panel `Top`/`Height` buna uyduruldu. `.dfm` açılıyor, derleme hatasız. |
| `Kaynak/uIkon.pas` | `IkonlariKoleksiyonaYukle` ayrıldı (şerit kendi koleksiyonunu kullanır). `IKON_METADATA` = `file-plus` (yeni giriş, var olan PNG), `IKON_YEDEK` = klasör ikonu (geçici). |
| `Diller/tr,en,de.json` | 3 anahtar: `GRUP_BAGLANTI`, `GRUP_SORGU`, `GRUP_YONETIM`. Düğme yazıları mevcut anahtarlardan (`BTN_*`, `MENU_METADATA_CIKAR`, `MENU_YEDEK`). |
| `Kaynak/FirebirdYonetici.dpr`, `.dproj` | `uSerit.pas` eklendi. |
| `Test/SeritTest.dpr`, `SeritTestDerle.bat` (yeni) | Şeridi ayrı formda kurar, üç dilde PNG ekran görüntüsü ve genişlik ölçümü yazar. Fare/klavye denemesi değildir. |

## Düğme eşlemesi (eski → yeni)

| Düğme | Eski | Yeni grup | Yordam (değişmedi) |
|---|---|---|---|
| Yeni Bağlantı | araç çubuğu | Bağlantı | `btnYeniBaglantiClick` |
| Klonla | araç çubuğu | Bağlantı | `btnKlonlaClick` |
| Bağlan / Bağlantıyı Kes (tek düğme, ikon+yazı durumla değişir) | araç çubuğu | Bağlantı | `btnBaglanClick` |
| Yenile | araç çubuğu | Bağlantı | `btnYenileClick` |
| Yeni Sorgu | araç çubuğu | Sorgu | `btnYeniSorguClick` |
| Çalıştır (F5) | araç çubuğu | Sorgu | `btnCalistirClick` |
| Plan (Ctrl+L) | araç çubuğu | Sorgu | `btnPlanClick` |
| Metadata çıkar | yalnız sağ tık | Yönetim | `btnMetadataClick` → `MetadataCikarAc` (sağ tık maddesi duruyor) |
| Yedekle / Geri yükle | yalnız sağ tık | Yönetim | `btnYedekClick` → `YedekPenceresiAc` (sağ tık maddesi duruyor) |

Pasif/aktif: Bağlan, Klonla, Yenile, Yeni Sorgu, Çalıştır, Plan eski koşullarla aynı. Metadata çıkar: açık bağlantı varsa; Yedekle: seçili bir bağlantı (ya da altındaki öğe) varsa, bağlantı açık olmak zorunda değil (eski sağ tık davranışıyla aynı). F5 ve Ctrl+L `FormKeyDown`'da olduğu gibi duruyor.

## Denenenler

- `Derle.bat` hatasız çıktı; uyarı yalnızca SynEdit kaynağından (`W1075`, önceden de var), kendi kodumuzdan uyarı yok.
- `SeritTest` (üç dilde, 100% ölçek, açık VCL stili) hatasız: şerit genişliği tr 765 px, en 770 px, de 816 px; dil kutusu için ayrılan alan 910 px'e **sığıyor**, yazılar kesilmiyor (Almanca "Sichern / Wiederherstellen..." ve "Metadaten extrahieren" iki satıra bölünüyor). Pasif düğmeye tıklama `OnClick`'i çağırmıyor, aktif çağırıyor. PNG'leri gözle inceledim (ikonlar saydam, pasif düğmeler soluk, grup adları altta gri, gruplar arası ince çizgi).
- Gerçek `FirebirdYonetici.exe` açılıyor, şerit görünüyor (ekran görüntüsü).
- Gömülü Firebird 5.0.4 ile `DDLTest` (0 hata), `AktarTest` (70 kontrol, 0 hata), `YedekTest` (94 kontrol, 0 hata) geçti. Bu testlerin kullandığı birimlere (`uDil`, `uMetadata`, `uSorgu`, `uDDL`, `uAktar`, `uYedek`) dokunulmadı.

## Denemediklerim (açıkça)

- **Gerçek arayüzde fare ile hiçbir düğmeyi denemedim**: bağlanma/kesme, klonlama, yenileme, sorgu açma, F5, plan, metadata çıkarma, yedekleme penceresi. Düğmeler yalnızca kod ile (`SeritTest`) tıklandı. Bunları sahibi deneyecek.
- Sunucuya bağlanan hiçbir şey yapılmadı, veri değiştirilmedi.
- Çalışma anında dil değişimi (açılır kutudan) elle denenmedi; `SeritTest` her dili ayrı form ile yükledi. `YazilariYenile` yolu kodla aynı.
- **125% ölçek denenmedi.** Kod `CurrentPPI` ile boyut ölçekliyor ama ikonlar 32 px PNG'den büyütülüyor (hafif bulanık olabilir). Pencere farklı ölçekli ekrana taşınırken şeridin yeniden ölçeklenmesi yok (ilk sürüm).
- `MetadataTest` ve `SorguTest` veritabanı yolu (`FBTEST_YOL`) verilmeden çalışmadı/atlandı; sonuç anlamlı değil.
- Pencere şeridin genişliğinden (Almanca'da ~816 px + dil kutusu 190 px) darsa şerit kesilir, yatay kaydırma yok (ilk sürümde daraltma yok, belgeye uygun).

## Eksik ikonlar (sahibine)

Yeni ikon çizmedim. Mevcut ikonlardan:
- **Metadata çıkar:** `file-plus.png` (daha önce ağaçta/menüde kullanılmayan, ama yerinde bir dosya ikonu).
- **Yedekle / Geri yükle:** ayrı ikon yok, **geçici olarak klasör ikonu** (`IKON_YEDEK = IKON_KLASOR`). Uygun bir Tabler ikonu (ör. `database-export`/`archive`) istenirse eklenir.

## Not (derleme ortamı)

Bu çalışma klasöründe (git worktree) `msbuild`, `Kaynak\Manifest.res` dosyasını boş (32 bayt) üretti; bu yüzden worktree'den çıkan `.exe` manifestsiz, ağaç ikonları siyah kutu görünüyordu. Aynı kaynağı düz bir klasörde derleyince sorun yoktu (ağaç ve şerit ikonları doğru). Normal depo klasörünüzde derlerken sorun beklenmiyor ama şerit/ağaç ikonları siyah kutu görünürse `Kaynak\Manifest.res` ve `FirebirdYonetici.res` dosyalarını silip yeniden derleyin (bunlar derleme çıktısıdır, depoda yok). Ekran görüntüleri ve testler düz klasörde derlenen çıktıyla alındı.

## Sahibinin arayüz deneme listesi

1. Programı aç: üstte üç gruplu şerit (Bağlantı, Sorgu, Yönetim) görünsün; ağaç ikonları normal olsun.
2. Hiçbir şey seçili değilken: yalnız "Yeni Bağlantı" aktif olsun, diğerleri soluk.
3. Kapalı bir bağlantıyı seç: "Bağlan" ve "Klonla" ve "Yedekle / Geri yükle" aktif; bağlan; düğme "Bağlantıyı Kes"e dönsün, "Yenile", "Yeni Sorgu", "Metadata çıkar" aktifleşsin.
4. Yeni Sorgu → "Çalıştır" ve "Plan" aktif olsun; F5 ve Ctrl+L çalışsın.
5. Üç dile geç: yazılar ve grup adları anında değişsin, kesilmesin, şerit dil kutusuna taşmasın.
6. Üzerine gelince ve basılı tutunca düğme geri bildirimi; pasif düğme tıklanmasın.
7. Yedekle / Geri yükle ve Metadata çıkar düğmeleri sağ tık menüsündeki maddelerle aynı pencereyi açsın.
8. Mümkünse ekran ölçeğini 125%'e alıp dene (ikon netliği, şerit genişliği).

---

## Ek: grup adları sekme oldu (sahibinin isteği)

**Ne değişti** (`Kaynak/uSerit.pas`, `Test/SeritTest.dpr`; `fAna` değişmedi):
- Üstte ince sekme satırı: Bağlantı | Sorgu | Yönetim (yazılar `GRUP_*` anahtarlarından, dil değişince yenilenir). Seçili sekmenin altında `clHighlight` renginde kalın çizgi, üzerine gelince `StyleServices` sıcak zemin.
- Yalnızca seçili sekmenin düğmeleri görünür. Gizli sekmenin düğmeleri yerinde durur, `DurumuGuncelle` hepsini eskisi gibi günceller (`Enabled` korunuyor). F5 ve Ctrl+L `FormKeyDown`'da, sekmeden bağımsız.
- Açılış sekmesi Bağlantı; seçim `TSerit` yaşadıkça (program açıkken, dil değişse de) korunur, diske yazılmaz, kendiliğinden sekme değişmez.
- Grup adı etiketi ve gruplar arası dikey çizgi kaldırıldı; şerit yüksekliği 102 → 110 px (sekme satırı eklendi, etiket çıktı; `pnlUst.Height` zaten `FSerit.Yukseklik` ile ayarlanıyor).
- Yöntem seçimi: `TPageControl` yerine kendi küçük sekme çizimimiz ve mevcut düğmeleri tutan grup panelleri (yalnız `Visible` değişiyor). Neden: düğmeler taşınmıyor, `fAna`'ya hiç dokunmak gerekmedi, tek bileşen sınıfı (`TSeritSekmesi`) ve ~40 satır ekledi; `TPageControl` sayfa/stil/yükseklik davranışlarını ayrıca yönetmeyi gerektirirdi.

**Genişlik** (en geniş sekme, 100% ölçek): tr 298 px, en 311 px, de 302 px; dil kutusu için kalan 910 px'e rahatça sığıyor (önceki 765-816 px'e karşılık).

**Denenenler:** `SeritTest` üç dilde her sekme için PNG + ölçüm, hata 0: sekme değişince doğru sayıda ve doğru düğmeler görünür (4/3/2), gizli sekmede `Enabled` korunuyor, pasif düğme tıklanmıyor. PNG'leri gözle inceledim. `Derle.bat` hatasız; DDLTest, AktarTest, YedekTest (gömülü 5.0.4) geçti.

**Denemedim:** gerçek arayüzde fareyle sekme tıklama, sekme seçiliyken bağlantı/sorgu işlemleri, çalışma anında dil değişimi, 125% ölçek. Bunlar sahibinde.
