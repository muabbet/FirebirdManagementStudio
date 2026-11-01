# Aşama 4b Raporu: Şema Farkı (iki veritabanını karşılaştırma)

Tarih: 2026-11-01. Dal: `asama4`.

## Ne yapıldı
- Şeritte **Yönetim** sekmesine **Şema Farkı** düğmesi. Tek sekme açılır.
- Üstte **Kaynak** ve **Hedef** kutuları (açık olan veya şifresi kayıtlı bağlantılar), **Karşılaştır** düğmesi.
- Ortada fark listesi: Tür, Ad, Durum (Yalnız kaynakta var / Yalnız hedefte var / Farklı). Üstte özet satırı ("N fark: ...").
- Altta seçili farkın ayrıntısı:
  - Yalnız bir tarafta olan nesne: o nesnenin `CREATE` script'i (kopyalanabilir; karşı tarafa eklemek için).
  - Farklı olan nesne: satır farkı (`-` yalnız kaynakta, `+` yalnız hedefte olan satır).
- Karşılaştırılan nesneler: tablo, view, prosedür, tetikleyici (yalnız veritabanı tetikleyicileri; tabloya bağlılar tablonun altında görünür), domain, exception, generator (yalnız var/yok ve artış; değer veri sayıldığı için karşılaştırılmaz).
- Veritabanlarında **hiçbir şey değiştirilmez**, yalnızca okunur.
- Yöntem sade: her nesnenin `CREATE` script'i (`uDDL`) iki tarafta üretilir ve satır satır karşılaştırılır. Tablo script'i kolon, kısıt, indeks ve tetikleyiciyi de içerir.
- Kod: `uSemaFark.pas` (mantık), `fSemaFark.pas/.dfm` (ince form), `fAna.pas` (düğme ve sekme). Üç dilde 30 yeni anahtar (her dilde 667 anahtar).

## Ne test edildi
`Test\SemaFarkTest.dpr` (yerleşik motor, Firebird 5.0.4): 21 kontrol, 0 hata.
Kapsam: aynı veritabanı kendisiyle (fark yok), yalnız kaynakta/hedefte tablo, kolon boyu farkı (`- VARCHAR(20)` / `+ VARCHAR(30)`), view ve domain aynı (fark yok), prosedür gövde farkı, exception, generator (değer farkı sayılmaz, yalnız hedefteki bulunur), ters yön, bağlantı adlarıyla çalıştırma, kayıtsız bağlantı adı hatası, dil anahtarları (tr/en/de), sekmenin dfm'i hatasız oluşuyor.

## Eksik / görülmedi
- Arayüz gözle görülmedi (otomatik tıklama güvenilir çıkmadı); yalnızca sekmenin hatasız oluştuğu test edildi.
- Firebird 2.5, 3.0 ve 4.0 ile denenmedi (karşılaştırma `uDDL` script'ine dayanır, o unit'in sürüm desteği geçerli).
- Çok büyük veritabanında süre ölçülmedi (her nesne iki kez script'e dönüştürülür).
- Hedefe uygulanacak toplu "ALTER" script'i üretilmiyor; yalnızca eksik nesnenin `CREATE` script'i ve satır farkı gösterilir (basitlik; istenirse sonra eklenir).
