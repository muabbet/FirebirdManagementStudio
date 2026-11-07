unit uBakim;

{ Veritabani bakimi (Asama 7d): "arabayi bakima sokmak gibi". Once DEGISTIRMEYEN bir rapor, sonra onayla bakim.

  Hedeflenen Firebird surumleri: 2.5, 3.0, 4.0, 5.0
  Denenen Firebird surumleri: 5.0.4 (2.5.9, 3.0 ve 4.0 sunucularda sahibi deneyecek)

  RAPOR (hicbir sey degismez):
    - Veritabani durumu: SQL ile (MON$DATABASE): sayfa boyutu, ODS, islem sayaclari, sweep araligi, bagli kisi sayisi.
    - Tablo ve index analizi: gstat -r (Firebird'in kendi araci). Tablo basina satir, eski ve silinmis kayit surumleri, sayfa doluluk;
      index basina derinlik, yaprak sayisi, dolulugu. Silinmis kayit izi = gstat'in saydigi kayit - gercek (canli) satir.
    - Istege bagli bozuk kayit taramasi: gfix -v -n -full (hicbir sey onarilmaz, yalniz bildirir).
    - Rapordan "yapilacaklar" listesi cikar (PlanKur).
  BAKIM (onaydan sonra), sirayla:
    1. Sweep (gfix -sweep): silinmis ve eski kayit surumlerini temizler. Cevrimici calisir.
    2. Seyrek ya da cok derin indexler yeniden kurulur (ALTER INDEX ... INACTIVE, sonra ACTIVE). YALNIZ kisit (PK/UNIQUE/FK) ve benzersiz
       olmayan indexler: pasifken baskasi ayni degeri eklemesin diye benzersiz ve kisitli indexlere dokunulmaz (onlar icin yedek / geri
       yukleme onerilir). Baska kullanici o tabloyu kullaniyorsa Firebird reddeder; index oldugu gibi kalir ve raporda yazar.
    3. Tum indexlerin istatistikleri yenilenir (SET STATISTICS INDEX): sorgu planlayici dogru secim yapsin.
  Onarma YAPILMAZ (gfix -mend yok); bozukluk bulunursa yalniz bildirilir ve yedek / geri yukleme onerilir.
  Araclar (gstat.exe, gfix.exe) fbclient.dll'in yanindaki istemci klasorundedir; sifre komut satirina yazilmaz (yalniz ISC_PASSWORD).
  Hata istisna olarak firlamaz (BakimRaporuHazirla, BakimiYap); sonuc kaydina yazilir. }

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, uBaglanti, uYedek;

type
  TBakimDurumu = record
    Yol: string;
    Surum: string;
    SayfaBoyutu: Integer;
    Ods: string;
    SweepAraligi: Integer;
    EnEskiIslem: Int64;
    EnEskiAktif: Int64;
    EnEskiSnapshot: Int64;
    SiradakiIslem: Int64;
    { Dosya boyutu (tahmini: sayfa sayisi x sayfa boyutu); 0 = okunamadi }
    Boyut: Int64;
    { Bu uygulamanin kendisi disinda bagli kisi sayisi; -1 = okunamadi }
    BagliKisi: Integer;
  end;

  TBakimTablosu = record
    Ad: string;
    { gstat'in saydigi kayit (silinmis kayit izleri dahil) }
    Kayit: Int64;
    { Eski kayit surumleri (guncelleme / silme artiklari) }
    EskiSurum: Int64;
    EnCokSurum: Integer;
    VeriSayfasi: Int64;
    BosSayfa: Int64;
    { Veri sayfalarinin ortalama doluluk yuzdesi }
    Doluluk: Integer;
    { Gercek (canli) satir sayisi; -1 = sayilmadi (yalniz temizlenecek tablolar sayilir) }
    CanliSatir: Int64;
    { Silinmis kayit izi = Kayit - CanliSatir; -1 = bilinmiyor }
    SilinmisIzi: Int64;
    Temizlenecek: Boolean;
    { Veri sayfalari cok seyrek: sweep dosyayi kucultmez, yedek / geri yukleme kucultur }
    Seyrek: Boolean;
  end;

  TIndeksKarari = (ikTamam, ikYenidenKur, ikYedekGeriYukle);

  TBakimIndeksi = record
    Tablo: string;
    Ad: string;
    { 'PRIMARY KEY', 'UNIQUE', 'FOREIGN KEY' ya da bos (kisitsiz index) }
    Tur: string;
    Benzersiz: Boolean;
    Pasif: Boolean;
    Derinlik: Integer;
    Yaprak: Integer;
    Dugum: Int64;
    Cift: Int64;
    EnCokCift: Int64;
    { Yaprak sayfalarin yuzde kaci %40'in altinda dolu }
    SeyrekYuzde: Integer;
    Karar: TIndeksKarari;
    { Neden: 'derin', 'seyrek' ya da bos }
    Neden: string;
  end;

  TBakimIsTuru = (bisSweep, bisIndeksKur, bisIstatistik);

  TBakimIsi = record
    Tur: TBakimIsTuru;
    { Index adi (bisIndeksKur); bos = hepsi }
    Hedef: string;
    Aciklama: string;
  end;

  TTaramaDurumu = (tdYapilmadi, tdTemiz, tdBozuk, tdYapilamadi);

  TBakimRaporu = record
    Basarili: Boolean;
    Iptal: Boolean;
    Cumle: string;
    Ayrinti: string;
    Durum: TBakimDurumu;
    Tablolar: TArray<TBakimTablosu>;
    Indeksler: TArray<TBakimIndeksi>;
    Tarama: TTaramaDurumu;
    TaramaCikti: string;
    Isler: TArray<TBakimIsi>;
    { Bakimi etkileyen notlar (bagli kisiler, yedek onerisi...), satir satir }
    Notlar: TArray<string>;
  end;

  TBakimSonucu = record
    Basarili: Boolean;
    Iptal: Boolean;
    { Her isin sonucu (yapildi / yapilamadi ve neden) }
    Satirlar: TArray<string>;
    Hatali: Integer;
    { Calisan SQL komutlari (mesaj alani icin) }
    Komutlar: TArray<string>;
  end;

{ gstat.exe ve gfix.exe istemci klasorunde var mi? }
function BakimAraclariVar: Boolean;

{ gstat -r ciktisini tablolara ve indexlere ayirir (saf yordam; ham metin verilir). Hic tablo bulunamazsa False. }
function GstatAyristir(const Ham: string; out Tablolar: TArray<TBakimTablosu>; out Indeksler: TArray<TBakimIndeksi>): Boolean;

{ Raporun yapilacaklar listesini (Isler), tablo ve index kararlarini ve notlari kurar (saf yordam; sayilar rapordadir). }
procedure PlanKur(var Rapor: TBakimRaporu);

{ Raporu hazirlar: durum + gstat + (istege bagli) bozuk kayit taramasi + plan. Veritabanina YAZMAZ. Cikti: araclarin satirlari ve
  beklerken aralikla (Satir bos) cagrilir; Iptal True yapilirsa durur. }
function BakimRaporuHazirla(Bag: TAcikBaglanti; TaramaYap: Boolean; Cikti: TYedekCiktisi): TBakimRaporu;

{ Onay penceresinin metni: yapilacaklar ve uyarilar. }
function BakimOnayMetni(const Rapor: TBakimRaporu): string;

{ Rapordaki yapilacaklari sirayla uygular. Cagiran once kullanicidan net onay almis olmalidir. }
function BakimiYap(Bag: TAcikBaglanti; const Rapor: TBakimRaporu; Cikti: TYedekCiktisi): TBakimSonucu;

{ Bir yazi icin yerellestirilmis kisa ozet (rapor sekmesinin ustu): "Bakim gerekli / gerekmiyor", sayilar. }
function BakimOzetMetni(const Rapor: TBakimRaporu): string;

implementation

uses
  System.IOUtils, System.StrUtils, System.Math, System.RegularExpressions, System.Variants, Data.DB,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Comp.Client, uDil, uPaket, uDDL;

const
  { Bir tablo, bu kadar eski surum ya da kaydin %10'u eski surum ise temizlenecek sayilir }
  ESKI_SURUM_ESIK = 100;
  ESKI_SURUM_ORAN = 10;
  { Index bu derinlikten sonra, ya da yaprak sayfalarin bu yuzdesi %40'in altinda ise yeniden kurulur }
  INDEKS_DERIN = 4;
  INDEKS_SEYREK_YUZDE = 40;
  INDEKS_EN_AZ_YAPRAK = 20;
  { Veri sayfalari bu doluluktan azsa (ve en az bu kadar sayfa varsa) "seyrek" }
  SAYFA_SEYREK_DOLULUK = 50;
  SAYFA_EN_AZ = 100;
  { Sweep icin: bu kadar islem birikmisse (en eski islemden sirada olana) eski kayit olmasa da sweep onerilir }
  ISLEM_FARKI_ESIK = 20000;

type
  TTablo = TBakimTablosu;
  TIndeks = TBakimIndeksi;

function GstatYolu: string;
begin
  Result := TPath.Combine(PaketKlasoru, 'istemci\gstat.exe');
end;

function GfixYolu: string;
begin
  Result := TPath.Combine(PaketKlasoru, 'istemci\gfix.exe');
end;

function BakimAraclariVar: Boolean;
begin
  Result := TFile.Exists(GstatYolu) and TFile.Exists(GfixYolu) and TFile.Exists(GbakYolu);
end;

{ ---------- gstat ciktisini ayirma ---------- }

function SayiAl(const Satir, Desen: string; var Deger: Int64): Boolean;
var
  Eslesme: TMatch;
begin
  Eslesme := TRegEx.Match(Satir, Desen, [roIgnoreCase]);
  Result := Eslesme.Success;
  if Result then
    Deger := StrToInt64Def(Eslesme.Groups[1].Value, 0);
end;

function GstatAyristir(const Ham: string; out Tablolar: TArray<TBakimTablosu>; out Indeksler: TArray<TBakimIndeksi>): Boolean;
var
  Satirlar: TStringList;
  Satir, Duz: string;
  Tablo: TBakimTablosu;
  Indeks: TBakimIndeksi;
  TabloListesi: TList<TBakimTablosu>;
  IndeksListesi: TList<TBakimIndeksi>;
  Eslesme: TMatch;
  Sayi: Int64;
  TabloAcik, IndeksAcik: Boolean;
  Dilim: array[0..4] of Int64;
  DilimSayisi: Integer;

  procedure IndeksiBitir;
  var
    Az: Int64;
  begin
    if not IndeksAcik then
      Exit;
    { Yaprak sayfalarin %40'in altinda dolu olanlari: ilk iki dilim (0-19, 20-39) }
    Az := Dilim[0] + Dilim[1];
    if Indeks.Yaprak > 0 then
      Indeks.SeyrekYuzde := Round(100 * Az / Indeks.Yaprak)
    else
      Indeks.SeyrekYuzde := 0;
    IndeksListesi.Add(Indeks);
    IndeksAcik := False;
  end;

  procedure TabloyuBitir;
  begin
    IndeksiBitir;
    if TabloAcik then
      TabloListesi.Add(Tablo);
    TabloAcik := False;
  end;

begin
  Dilim[0] := 0;
  Dilim[1] := 0;
  DilimSayisi := 0;
  TabloListesi := TList<TBakimTablosu>.Create;
  IndeksListesi := TList<TBakimIndeksi>.Create;
  Satirlar := TStringList.Create;
  try
    Satirlar.Text := Ham;
    TabloAcik := False;
    IndeksAcik := False;
    for Satir in Satirlar do
    begin
      if Satir = '' then
        Continue;
      { Tablo basligi: satir basinda, "ADI (128)" }
      Eslesme := TRegEx.Match(Satir, '^(\S.*?) \((\d+)\)\s*$');
      if Eslesme.Success and not StartsText('Database', Satir) then
      begin
        TabloyuBitir;
        Tablo := Default(TBakimTablosu);
        Tablo.Ad := Trim(Eslesme.Groups[1].Value);
        Tablo.CanliSatir := -1;
        Tablo.SilinmisIzi := -1;
        TabloAcik := True;
        Continue;
      end;
      if not TabloAcik then
        Continue;
      Duz := Trim(Satir);
      { Index basligi: "Index ADI (1)" }
      Eslesme := TRegEx.Match(Duz, '^Index (.+?) \((\d+)\)$', [roIgnoreCase]);
      if Eslesme.Success then
      begin
        IndeksiBitir;
        Indeks := Default(TBakimIndeksi);
        Indeks.Tablo := Tablo.Ad;
        Indeks.Ad := Trim(Eslesme.Groups[1].Value);
        IndeksAcik := True;
        DilimSayisi := 0;
        FillChar(Dilim, SizeOf(Dilim), 0);
        Continue;
      end;
      if IndeksAcik then
      begin
        Eslesme := TRegEx.Match(Duz, 'depth: (\d+), leaf buckets: (\d+), nodes: (\d+)', [roIgnoreCase]);
        if Eslesme.Success then
        begin
          Indeks.Derinlik := StrToIntDef(Eslesme.Groups[1].Value, 0);
          Indeks.Yaprak := StrToIntDef(Eslesme.Groups[2].Value, 0);
          Indeks.Dugum := StrToInt64Def(Eslesme.Groups[3].Value, 0);
        end;
        Eslesme := TRegEx.Match(Duz, 'total dup: (\d+), max dup: (\d+)', [roIgnoreCase]);
        if Eslesme.Success then
        begin
          Indeks.Cift := StrToInt64Def(Eslesme.Groups[1].Value, 0);
          Indeks.EnCokCift := StrToInt64Def(Eslesme.Groups[2].Value, 0);
        end;
        { Doluluk dagilimi: "0 - 19% = 3" }
        Eslesme := TRegEx.Match(Duz, '^(\d+) - (\d+)% = (\d+)$');
        if Eslesme.Success and (DilimSayisi < 5) then
        begin
          Dilim[DilimSayisi] := StrToInt64Def(Eslesme.Groups[3].Value, 0);
          Inc(DilimSayisi);
        end;
      end
      else
      begin
        if SayiAl(Duz, 'total records: (\d+)', Sayi) then
          Tablo.Kayit := Sayi;
        Eslesme := TRegEx.Match(Duz, 'total versions: (\d+), max versions: (\d+)', [roIgnoreCase]);
        if Eslesme.Success then
        begin
          Tablo.EskiSurum := StrToInt64Def(Eslesme.Groups[1].Value, 0);
          Tablo.EnCokSurum := StrToIntDef(Eslesme.Groups[2].Value, 0);
        end;
        Eslesme := TRegEx.Match(Duz, 'Data pages: (\d+).*?average fill: (\d+)%', [roIgnoreCase]);
        if Eslesme.Success then
        begin
          Tablo.VeriSayfasi := StrToInt64Def(Eslesme.Groups[1].Value, 0);
          Tablo.Doluluk := StrToIntDef(Eslesme.Groups[2].Value, 0);
        end;
        if SayiAl(Duz, 'Empty pages: (\d+)', Sayi) then
          Tablo.BosSayfa := Sayi;
      end;
    end;
    TabloyuBitir;
    Tablolar := TabloListesi.ToArray;
    Indeksler := IndeksListesi.ToArray;
    Result := Length(Tablolar) > 0;
  finally
    Satirlar.Free;
    IndeksListesi.Free;
    TabloListesi.Free;
  end;
end;

{ ---------- plan ---------- }

procedure PlanKur(var Rapor: TBakimRaporu);
var
  Isler: TList<TBakimIsi>;
  Notlar: TList<string>;
  Is_: TBakimIsi;
  i, Temizlenecek, YenidenKurulacak, Seyrek, YedekOnerilen: Integer;
  Garip: Int64;
  SweepGerek: Boolean;
begin
  Isler := TList<TBakimIsi>.Create;
  Notlar := TList<string>.Create;
  try
    Temizlenecek := 0;
    Seyrek := 0;
    for i := 0 to High(Rapor.Tablolar) do
    begin
      Rapor.Tablolar[i].Temizlenecek := (Rapor.Tablolar[i].EskiSurum >= ESKI_SURUM_ESIK) or
        ((Rapor.Tablolar[i].EskiSurum > 0) and (Rapor.Tablolar[i].Kayit > 0) and
        (Rapor.Tablolar[i].EskiSurum * ESKI_SURUM_ORAN >= Rapor.Tablolar[i].Kayit));
      Rapor.Tablolar[i].Seyrek := (Rapor.Tablolar[i].VeriSayfasi >= SAYFA_EN_AZ) and (Rapor.Tablolar[i].Doluluk < SAYFA_SEYREK_DOLULUK);
      if Rapor.Tablolar[i].Temizlenecek then
        Inc(Temizlenecek);
      if Rapor.Tablolar[i].Seyrek then
        Inc(Seyrek);
    end;
    { Index kararlari }
    YenidenKurulacak := 0;
    YedekOnerilen := 0;
    for i := 0 to High(Rapor.Indeksler) do
    begin
      Rapor.Indeksler[i].Karar := ikTamam;
      Rapor.Indeksler[i].Neden := '';
      if Rapor.Indeksler[i].Derinlik >= INDEKS_DERIN then
        Rapor.Indeksler[i].Neden := 'derin'
      else if (Rapor.Indeksler[i].Yaprak >= INDEKS_EN_AZ_YAPRAK) and (Rapor.Indeksler[i].SeyrekYuzde >= INDEKS_SEYREK_YUZDE) then
        Rapor.Indeksler[i].Neden := 'seyrek';
      if Rapor.Indeksler[i].Neden <> '' then
      begin
        { Kisitli, benzersiz ve pasif indexlere dokunulmaz (pasifken ayni deger girilebilir): yedek / geri yukleme onerilir }
        if (Rapor.Indeksler[i].Tur <> '') or Rapor.Indeksler[i].Benzersiz or Rapor.Indeksler[i].Pasif then
        begin
          Rapor.Indeksler[i].Karar := ikYedekGeriYukle;
          Inc(YedekOnerilen);
        end
        else
        begin
          Rapor.Indeksler[i].Karar := ikYenidenKur;
          Inc(YenidenKurulacak);
        end;
      end;
    end;
    { Yapilacaklar }
    Garip := Rapor.Durum.SiradakiIslem - Rapor.Durum.EnEskiIslem;
    SweepGerek := (Temizlenecek > 0) or (Garip > ISLEM_FARKI_ESIK);
    if SweepGerek then
    begin
      Is_ := Default(TBakimIsi);
      Is_.Tur := bisSweep;
      if Temizlenecek > 0 then
        Is_.Aciklama := TF('BAKIM_IS_SWEEP', [Temizlenecek])
      else
        Is_.Aciklama := TF('BAKIM_IS_SWEEP_FARK', [Garip]);
      Isler.Add(Is_);
    end;
    for i := 0 to High(Rapor.Indeksler) do
      if Rapor.Indeksler[i].Karar = ikYenidenKur then
      begin
        Is_ := Default(TBakimIsi);
        Is_.Tur := bisIndeksKur;
        Is_.Hedef := Rapor.Indeksler[i].Ad;
        Is_.Aciklama := TF('BAKIM_IS_INDEKS', [Rapor.Indeksler[i].Ad, Rapor.Indeksler[i].Tablo, T('BAKIM_NEDEN_' + UpperCase(Rapor.Indeksler[i].Neden))]);
        Isler.Add(Is_);
      end;
    if Length(Rapor.Indeksler) > 0 then
    begin
      Is_ := Default(TBakimIsi);
      Is_.Tur := bisIstatistik;
      Is_.Aciklama := TF('BAKIM_IS_ISTATISTIK', [Length(Rapor.Indeksler)]);
      Isler.Add(Is_);
    end;
    { Notlar }
    if (YenidenKurulacak > 0) and (Rapor.Durum.BagliKisi > 0) then
      Notlar.Add(TF('BAKIM_NOT_BAGLI', [Rapor.Durum.BagliKisi]));
    if YedekOnerilen > 0 then
      Notlar.Add(TF('BAKIM_NOT_YEDEK_INDEKS', [YedekOnerilen]));
    if Seyrek > 0 then
      Notlar.Add(TF('BAKIM_NOT_YEDEK_SAYFA', [Seyrek]));
    if Rapor.Tarama = tdBozuk then
      Notlar.Add(T('BAKIM_NOT_BOZUK'));
    Rapor.Isler := Isler.ToArray;
    Rapor.Notlar := Notlar.ToArray;
  finally
    Notlar.Free;
    Isler.Free;
  end;
end;

{ ---------- arac cagrisi ---------- }

function Tirnakla(const Metin: string): string;
begin
  Result := '"' + Metin + '"';
end;

function KullaniciArgumani(const Tanim: TBaglantiTanimi): string;
begin
  if Tanim.Kullanici = '' then
    Result := ''
  else
    Result := ' -user ' + Tirnakla(Tanim.Kullanici);
end;

{ Araclarin ham ciktisindan anlasilir cumle. }
function AracHatasiniCevir(const Ham: string): string;
begin
  if ContainsText(Ham, 'USE_GSTAT_UTILITY') or ContainsText(Ham, 'system privilege') or ContainsText(Ham, 'no permission for') then
    Result := T('ERR_BAKIM_YETKI')
  else if ContainsText(Ham, 'user name and password') or ContainsText(Ham, 'authentication error') or
    ContainsText(Ham, 'error occurred during login') or ContainsText(Ham, 'incorrect user name') then
    Result := T('ERR_SIFRE')
  else if ContainsText(Ham, 'network request') or ContainsText(Ham, 'connection refused') or
    ContainsText(Ham, 'failed to establish a connection') or ContainsText(Ham, 'unavailable database') then
    Result := T('ERR_SUNUCU')
  else if ContainsText(Ham, 'connection lost') or ContainsText(Ham, 'error reading data from the connection') then
    Result := T('ERR_KOPTU')
  else
    Result := T('ERR_BAKIM_ARAC');
end;

function TekDegerYazi(Bag: TAcikBaglanti; const Sql: string): string;
begin
  Result := VarToStr(Bag.Baglanti.ExecSQLScalar(Sql));
end;

{ MON$DATABASE ve bagli kisi sayisi. Okunamayan alanlar 0 / -1 kalir; hata istisna olarak gelmez. }
procedure DurumuOku(Bag: TAcikBaglanti; var Durum: TBakimDurumu);
var
  Sorgu: TFDQuery;
begin
  Durum := Default(TBakimDurumu);
  Durum.Yol := Bag.Tanim.VeritabaniYolu;
  Durum.Surum := Bag.Surum;
  Durum.BagliKisi := -1;
  Sorgu := TFDQuery.Create(nil);
  try
    try
      Sorgu.Connection := Bag.Baglanti;
      Sorgu.SQL.Text := 'select mon$page_size, mon$ods_major, mon$ods_minor, mon$oldest_transaction, mon$oldest_active, ' +
        'mon$oldest_snapshot, mon$next_transaction, mon$sweep_interval, mon$pages from mon$database';
      Sorgu.Open;
      Durum.SayfaBoyutu := Sorgu.Fields[0].AsInteger;
      Durum.Ods := Sorgu.Fields[1].AsString + '.' + Sorgu.Fields[2].AsString;
      Durum.EnEskiIslem := Sorgu.Fields[3].AsLargeInt;
      Durum.EnEskiAktif := Sorgu.Fields[4].AsLargeInt;
      Durum.EnEskiSnapshot := Sorgu.Fields[5].AsLargeInt;
      Durum.SiradakiIslem := Sorgu.Fields[6].AsLargeInt;
      Durum.SweepAraligi := Sorgu.Fields[7].AsInteger;
      Durum.Boyut := Sorgu.Fields[8].AsLargeInt * Durum.SayfaBoyutu;
    except
      { MON$ tablolari okunamazsa (cok eski surum ya da yetki) rapor yine hazirlanir }
    end;
  finally
    Sorgu.Free;
  end;
  try
    Durum.BagliKisi := StrToIntDef(TekDegerYazi(Bag, 'select count(*) from mon$attachments where mon$attachment_id <> current_connection ' +
      'and mon$system_flag = 0'), -1);
  except
    try
      Durum.BagliKisi := StrToIntDef(TekDegerYazi(Bag, 'select count(*) from mon$attachments where mon$attachment_id <> current_connection'), -1);
    except
      Durum.BagliKisi := -1;
    end;
  end;
end;

{ RDB$INDICES: kisit turu, benzersizlik, pasiflik. Ada gore eslesir. }
procedure IndeksBilgisiniYaz(Bag: TAcikBaglanti; var Indeksler: TArray<TBakimIndeksi>);
var
  Sorgu: TFDQuery;
  i: Integer;
begin
  Sorgu := TFDQuery.Create(nil);
  try
    try
      Sorgu.Connection := Bag.Baglanti;
      Sorgu.SQL.Text := 'select trim(i.rdb$index_name) as AD, coalesce(i.rdb$unique_flag, 0) as BENZERSIZ, ' +
        'coalesce(i.rdb$index_inactive, 0) as PASIF, ' +
        '(select first 1 trim(rc.rdb$constraint_type) from rdb$relation_constraints rc where rc.rdb$index_name = i.rdb$index_name) as TUR ' +
        'from rdb$indices i';
      Sorgu.Open;
      while not Sorgu.Eof do
      begin
        for i := 0 to High(Indeksler) do
          if SameText(Indeksler[i].Ad, Sorgu.FieldByName('AD').AsString) then
          begin
            Indeksler[i].Benzersiz := Sorgu.FieldByName('BENZERSIZ').AsInteger = 1;
            Indeksler[i].Pasif := Sorgu.FieldByName('PASIF').AsInteger = 1;
            Indeksler[i].Tur := Sorgu.FieldByName('TUR').AsString;
          end;
        Sorgu.Next;
      end;
    except
      { Okunamazsa kisitli indexler kisitsiz sayilmasin diye hepsi kisitli gibi davranilir }
      for i := 0 to High(Indeksler) do
        Indeksler[i].Tur := 'UNKNOWN';
    end;
  finally
    Sorgu.Free;
  end;
end;

{ Temizlenecek tablolarin gercek satir sayisi (silinmis kayit izini bulmak icin). Hata varsa -1 kalir. }
procedure CanliSatirlariSay(Bag: TAcikBaglanti; var Tablolar: TArray<TBakimTablosu>);
var
  i: Integer;
begin
  for i := 0 to High(Tablolar) do
    if Tablolar[i].Temizlenecek then
      try
        Tablolar[i].CanliSatir := StrToInt64Def(TekDegerYazi(Bag, 'select count(*) from ' + AdiYaz(Bag, Tablolar[i].Ad)), -1);
        if Tablolar[i].CanliSatir >= 0 then
          Tablolar[i].SilinmisIzi := Max(0, Tablolar[i].Kayit - Tablolar[i].CanliSatir);
      except
        Tablolar[i].CanliSatir := -1;
      end;
end;

function BakimRaporuHazirla(Bag: TAcikBaglanti; TaramaYap: Boolean; Cikti: TYedekCiktisi): TBakimRaporu;
var
  Ham: string;
  Kod: Cardinal;
  Hedef: string;
  Bitti: Boolean;
begin
  Result := Default(TBakimRaporu);
  Result.Tarama := tdYapilmadi;
  if not BakimAraclariVar then
  begin
    Result.Cumle := T('ERR_BAKIM_ARAC_YOK');
    Exit;
  end;
  try
    DurumuOku(Bag, Result.Durum);
    Hedef := Tirnakla(GbakBaglantiMetni(Bag.Tanim, Bag.Tanim.VeritabaniYolu));
    { 1. gstat -r: tablo ve index analizi }
    Bitti := AltIslemCalistir(GstatYolu, '-r' + KullaniciArgumani(Bag.Tanim) + ' ' + Hedef, Bag.Tanim.Sifre, Cikti, Ham, Kod);
    if not Bitti then
    begin
      Result.Iptal := True;
      Exit;
    end;
    if not GstatAyristir(Ham, Result.Tablolar, Result.Indeksler) then
    begin
      { Tablo yoksa: bos veritabani (hata degil) ya da arac hatasi }
      if Kod <> 0 then
      begin
        Result.Cumle := AracHatasiniCevir(Ham);
        Result.Ayrinti := Ham;
        Exit;
      end;
    end;
    IndeksBilgisiniYaz(Bag, Result.Indeksler);
    { 2. istege bagli bozuk kayit taramasi }
    if TaramaYap then
    begin
      Bitti := AltIslemCalistir(GbakYolu, '-b -g' + KullaniciArgumani(Bag.Tanim) + ' ' + Hedef + ' nul', Bag.Tanim.Sifre, Cikti, Ham, Kod);
      if not Bitti then
      begin
        Result.Iptal := True;
        Exit;
      end;
      Result.TaramaCikti := Trim(Ham);
      if (Kod = 0) and (Result.TaramaCikti = '') then
        Result.Tarama := tdTemiz
      else if (Kod <> 0) and (Pos('error', LowerCase(Ham)) = 0) and (Pos('corrupt', LowerCase(Ham)) = 0) and
        (Pos('wrong page', LowerCase(Ham)) = 0) and (Pos('orphan', LowerCase(Ham)) = 0) then
      begin
        { Cikis kodu hata ama bozukluk sozcugu yok: arac calisamadi (yetki, baglanti...) }
        Result.Tarama := tdYapilamadi;
        Result.TaramaCikti := AracHatasiniCevir(Ham) + sLineBreak + Result.TaramaCikti;
      end
      else
        Result.Tarama := tdBozuk;
    end;
    PlanKur(Result);
    CanliSatirlariSay(Bag, Result.Tablolar);
    { Silinmis kayit izi de temizlenecek sayilir (eski surum az olsa bile); plan yeniden kurulur }
    PlanKur(Result);
    Result.Basarili := True;
  except
    on E: Exception do
    begin
      Result.Basarili := False;
      Result.Cumle := T('ERR_BAKIM_ARAC') + ' ' + E.Message;
      Result.Ayrinti := E.Message;
    end;
  end;
end;

{ ---------- onay ve ozet ---------- }

function BakimOnayMetni(const Rapor: TBakimRaporu): string;
var
  Is_: TBakimIsi;
  Not_: string;
  i: Integer;
begin
  Result := T('BAKIM_ONAY_BASLIK') + sLineBreak + sLineBreak;
  i := 0;
  for Is_ in Rapor.Isler do
  begin
    Inc(i);
    Result := Result + IntToStr(i) + '. ' + Is_.Aciklama + sLineBreak;
  end;
  if Length(Rapor.Notlar) > 0 then
    Result := Result + sLineBreak + T('BAKIM_ONAY_NOTLAR') + sLineBreak;
  for Not_ in Rapor.Notlar do
    Result := Result + '- ' + Not_ + sLineBreak;
  Result := Result + sLineBreak + T('BAKIM_ONAY_YEDEK') + sLineBreak + sLineBreak + T('BAKIM_ONAY_SORU');
end;

function BakimOzetMetni(const Rapor: TBakimRaporu): string;
var
  Tablo: TBakimTablosu;
  Indeks: TBakimIndeksi;
  EskiToplam, IzToplam: Int64;
  Temiz, YenidenKur, YedekGeri: Integer;
begin
  EskiToplam := 0;
  IzToplam := 0;
  Temiz := 0;
  for Tablo in Rapor.Tablolar do
  begin
    Inc(EskiToplam, Tablo.EskiSurum);
    if Tablo.SilinmisIzi > 0 then
      Inc(IzToplam, Tablo.SilinmisIzi);
    if Tablo.Temizlenecek then
      Inc(Temiz);
  end;
  YenidenKur := 0;
  YedekGeri := 0;
  for Indeks in Rapor.Indeksler do
    case Indeks.Karar of
      ikYenidenKur: Inc(YenidenKur);
      ikYedekGeriYukle: Inc(YedekGeri);
    end;
  Result := TF('BAKIM_OZET_TABLO', [Length(Rapor.Tablolar), Temiz, EskiToplam, IzToplam]) + sLineBreak +
    TF('BAKIM_OZET_INDEKS', [Length(Rapor.Indeksler), YenidenKur, YedekGeri]);
  case Rapor.Tarama of
    tdTemiz: Result := Result + sLineBreak + T('BAKIM_OZET_TARAMA_TEMIZ');
    tdBozuk: Result := Result + sLineBreak + T('BAKIM_OZET_TARAMA_BOZUK');
    tdYapilamadi: Result := Result + sLineBreak + T('BAKIM_OZET_TARAMA_YAPILAMADI');
  else
    Result := Result + sLineBreak + T('BAKIM_OZET_TARAMA_YOK');
  end;
  if Length(Rapor.Isler) = 0 then
    Result := Result + sLineBreak + sLineBreak + T('BAKIM_OZET_GEREKSIZ')
  else
    Result := Result + sLineBreak + sLineBreak + TF('BAKIM_OZET_GEREKLI', [Length(Rapor.Isler)]);
end;

{ ---------- bakim ---------- }

{ Tek SQL komutu kendi islemiyle calisir ve onaylanir; hata istisna olarak gelir. }
procedure SqlCalistir(Bag: TAcikBaglanti; const Sql: string);
var
  Islem: TFDTransaction;
  Sorgu: TFDQuery;
begin
  Islem := TFDTransaction.Create(nil);
  Sorgu := TFDQuery.Create(nil);
  try
    Islem.Connection := Bag.Baglanti;
    Islem.Options.AutoCommit := False;
    Sorgu.Connection := Bag.Baglanti;
    Sorgu.Transaction := Islem;
    Sorgu.ResourceOptions.ParamCreate := False;
    Sorgu.ResourceOptions.MacroCreate := False;
    Sorgu.SQL.Text := Sql;
    Islem.StartTransaction;
    try
      Sorgu.ExecSQL;
      Islem.Commit;
    except
      try
        if Islem.Active then
          Islem.Rollback;
      except
        { asil hata gosterilir }
      end;
      raise;
    end;
  finally
    Sorgu.Free;
    Islem.Free;
  end;
end;

function BakimiYap(Bag: TAcikBaglanti; const Rapor: TBakimRaporu; Cikti: TYedekCiktisi): TBakimSonucu;
var
  Satirlar: TList<string>;
  Komutlar: TList<string>;
  Is_: TBakimIsi;
  Ham, Ad, Sql, Hedef: string;
  Kod: Cardinal;
  Iptal: Boolean;
  Indeks: TBakimIndeksi;
  Yapilan, Hata: Integer;
  Bitti: Boolean;
begin
  Result := Default(TBakimSonucu);
  Satirlar := TList<string>.Create;
  Komutlar := TList<string>.Create;
  try
    Hata := 0;
    Hedef := Tirnakla(GbakBaglantiMetni(Bag.Tanim, Bag.Tanim.VeritabaniYolu));
    for Is_ in Rapor.Isler do
    begin
      Iptal := False;
      if Assigned(Cikti) then
        Cikti(Is_.Aciklama, Iptal);
      if Iptal then
      begin
        Result.Iptal := True;
        Break;
      end;
      case Is_.Tur of
        bisSweep:
          begin
            Komutlar.Add('gfix -sweep');
            Bitti := AltIslemCalistir(GfixYolu, '-sweep' + KullaniciArgumani(Bag.Tanim) + ' ' + Hedef, Bag.Tanim.Sifre, Cikti, Ham, Kod);
            if not Bitti then
            begin
              Result.Iptal := True;
              Satirlar.Add(T('BAKIM_SONUC_SWEEP_IPTAL'));
              Break;
            end;
            if Kod = 0 then
              Satirlar.Add(T('BAKIM_SONUC_SWEEP_TAMAM'))
            else
            begin
              Inc(Hata);
              Satirlar.Add(T('BAKIM_SONUC_SWEEP_HATA') + ' ' + AracHatasiniCevir(Ham));
            end;
          end;
        bisIndeksKur:
          begin
            Ad := AdiYaz(Bag, Is_.Hedef);
            try
              Sql := 'ALTER INDEX ' + Ad + ' INACTIVE';
              Komutlar.Add(Sql + ';');
              SqlCalistir(Bag, Sql);
            except
              on E: Exception do
              begin
                { Hic degismedi: index oldugu gibi duruyor }
                Inc(Hata);
                Satirlar.Add(TF('BAKIM_SONUC_INDEKS_YAPILAMADI', [Is_.Hedef, E.Message]));
                Continue;
              end;
            end;
            try
              Sql := 'ALTER INDEX ' + Ad + ' ACTIVE';
              Komutlar.Add(Sql + ';');
              try
                SqlCalistir(Bag, Sql);
              except
                { Bir kez daha dene }
                Sleep(300);
                SqlCalistir(Bag, Sql);
              end;
              Satirlar.Add(TF('BAKIM_SONUC_INDEKS_TAMAM', [Is_.Hedef]));
            except
              on E: Exception do
              begin
                { Pasif kaldi: kullanici elle etkinlestirmeli }
                Inc(Hata);
                Satirlar.Add(TF('BAKIM_SONUC_INDEKS_PASIF', [Is_.Hedef, Ad, E.Message]));
              end;
            end;
          end;
        bisIstatistik:
          begin
            Yapilan := 0;
            for Indeks in Rapor.Indeksler do
            begin
              Iptal := False;
              if Assigned(Cikti) then
                Cikti('', Iptal);
              if Iptal then
              begin
                Result.Iptal := True;
                Break;
              end;
              try
                SqlCalistir(Bag, 'SET STATISTICS INDEX ' + AdiYaz(Bag, Indeks.Ad));
                Inc(Yapilan);
              except
                on E: Exception do
                begin
                  Inc(Hata);
                  Satirlar.Add(TF('BAKIM_SONUC_ISTATISTIK_HATA', [Indeks.Ad, E.Message]));
                end;
              end;
            end;
            Komutlar.Add('SET STATISTICS INDEX ...; (' + IntToStr(Yapilan) + ')');
            Satirlar.Add(TF('BAKIM_SONUC_ISTATISTIK_TAMAM', [Yapilan, Length(Rapor.Indeksler)]));
            if Result.Iptal then
              Break;
          end;
      end;
    end;
    Result.Hatali := Hata;
    Result.Basarili := (not Result.Iptal) and (Hata = 0);
    Result.Satirlar := Satirlar.ToArray;
    Result.Komutlar := Komutlar.ToArray;
  finally
    Komutlar.Free;
    Satirlar.Free;
  end;
end;

end.
