# Görsel düzeltme raporu (dal `gorsel`)

Yalnızca görünüm değişti; işlev, SQL ve menüler aynı. **Arayüzü gözle denemedim**, her adım hatasız derlendi (çalışan program exe'yi kilitlediği için geçici klasöre derlendi). Mevcut testler bu görevde yeniden koşulmadı.

## Yapılanlar

| Alt iş | Dosya | Ne |
|---|---|---|
| g-1 ızgara | `uSonucGrid.pas` | İnce açık gri hücre çizgileri (hücre içinde çizilir), Segoe UI 9, satır yüksekliği yazıdan hesaplanır, gri kalın olmayan başlık, yumuşak mavi seçim, hafif zebra, sayılar sola hizalı (`SAYI_SAGA = True` ile sağa döner), NULL gri eğik kaldı |
| ikon | `FirebirdYonetici.dproj`, `FirebirdYonetici_Icon.ico` | StokluBulut ikonu uygulama ikonu oldu (`C:\Baris\Kodlar\win32\StokluBulut\SystemStokluBulut_Icon.ico` kopyası). Derlenen exe'de görüldü |
| g-2 editör | `uEditor.pas` | Gutter ve aktif satır renkleri açık gri/hafif mavi, altta ince durum satırı `Sat: N, Sütun: M` (tr/en/de). Hatalı satır kırmızı işareti korunur |
| g-3 durum çubuğu | `fAna.pas/.dfm`, `fSorguSekme.pas` | İki yeni panel: son sorgunun süresi ve satır sayısı. Sürüm, bağlantı, işlem durumu zaten vardı |
| dil | `Diller\*.json` | `DURUM_SURE`, `DURUM_SATIR`, `EDITOR_KONUM` (üç dilde) |

## Bilerek yapılmayanlar

- **Satır numarası sütunu:** standart `TDBGrid` indikatör sütununa numara çizmeye izin vermez; ızgara sınıfını türetmek gerekir. Sahibine soru.
- **CRLF / UTF-8 göstergesi:** editörde dosya kodlaması yok, uydurmadım.
- **Yakınlaştırma, Sonuçlar/İletiler sekmeleri:** yeni özellik, bu görevde yok.
- **g-4 (ağaç boşluğu):** ağaç zaten SSMS'ten rahat aralıklı; dokunulmadı.

## Sahibine sorular

1. Sayılar sola mı (şimdi) sağa mı hizalansın?
2. NULL gri eğik mi (şimdi) SSMS gibi sarı zemin mi?
3. Satır numarası sütunu isteniyor mu (ızgara sınıfı türetilir)?

## Bilinen sınırlar

- Editör durum satırının yazısı dil değişince bir sonraki imleç hareketinde yenilenir.
- Durum çubuğunun süre/satır panelleri en son sonuç yazan sekmeyi gösterir (sekme değişince güncellenmez).
- VCL Style'ın hücre/başlık renklerini ezip ezmediği gözle denenmedi (`StyleElements` ayarlandı).

## Sahibine deneme listesi

1. Sorgu çalıştır: ızgara `Referans\ssms.png` gibi mi (çizgi, dar satır, gri başlık, mavi seçim)? Satır yüksekliği DPI 125/150'de kesiliyor mu?
2. Ctrl+C, başlığa tıkla sıralama, NULL, uzun metin çift tık hâlâ çalışıyor mu?
3. Editör altında `Sat/Sütun` değişiyor mu; satır numaraları gri mi?
4. Sorgu sonrası alt durum çubuğunda süre ve satır sayısı var mı? Almanca'da kesiliyor mu?
5. Program ve görev çubuğunda StokluBulut ikonu görünüyor mu?
