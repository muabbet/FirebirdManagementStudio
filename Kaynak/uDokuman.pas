{ uDokuman.pas - Veritabani dokumani: tum yapiyi tek bir HTML dosyasina yazar (Asama 7t).

  Hedeflenen Firebird surumleri: 2.5, 3.0, 4.0, 5.0
  Denenen Firebird surumleri: 5.0.4 (3.0 ve 4.0'da denenecek)

  Yalniz OKUR: veritabanina hicbir sey yazilmaz. Tablo (kolon, kisit, index, tetikleyici), view, prosedur, tetikleyici,
  generator, exception ve domain'ler; COMMENT ON aciklamalari yanlarinda gorunur. Dosya tek basina acilir
  (stil icinde, JavaScript yok, internet gerekmez). Basliklar uygulamanin secili dilindedir.
  Okuma icin uMetadata ve uDDL'in kullandigi ayni okuyuculara bakilir; sistem tablolarini yalniz uMetadata bilir. }
unit uDokuman;

interface

uses
  System.SysUtils, System.Classes, uBaglanti;

type
  { Uzun surerken adim adim cagrilir (ornek "Tablolar 5/40: MUSTERI"); Iptal True yapilirsa dokuman eksik biter. }
  TDokumanIlerleme = reference to procedure(const Adim: string; var Iptal: Boolean);

  TDokumanOzeti = record
    Iptal: Boolean;
    Tablo: Integer;
    View: Integer;
    Prosedur: Integer;
    Tetikleyici: Integer;
  end;

{ Dokumani Yazici'ya HTML olarak yazar. }
function DokumanUret(Bag: TAcikBaglanti; Yazici: TTextWriter; Ilerleme: TDokumanIlerleme = nil): TDokumanOzeti;

{ Dokumani dosyaya (imsiz UTF-8) yazar. Var olan dosyayi ezme onayi cagirandadir. Hata istisna olarak firlar. }
function DokumanDosyasiYaz(Bag: TAcikBaglanti; const Dosya: string; Ilerleme: TDokumanIlerleme = nil): TDokumanOzeti;

{ "veritabani_20261116_153000.html" gibi varsayilan dosya adi (veritabani dosya adindan). }
function VarsayilanDokumanAdi(Bag: TAcikBaglanti): string;

implementation

uses
  System.Generics.Collections, System.StrUtils, System.IOUtils, uDil, uMetadata;

type
  TAciklamalar = TDictionary<string, string>;

{ HTML'e yazilacak metindeki ozel karakterler. }
function H(const Metin: string): string;
begin
  Result := StringReplace(Metin, '&', '&amp;', [rfReplaceAll]);
  Result := StringReplace(Result, '<', '&lt;', [rfReplaceAll]);
  Result := StringReplace(Result, '>', '&gt;', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '&quot;', [rfReplaceAll]);
end;

{ HTML baglanti kimligi: ad "TABLO" ise "t_TABLO" (bosluk ve ozel karakter alt cizgi). }
function Kimlik(const On, Ad: string): string;
var
  i: Integer;
begin
  Result := On + Ad;
  for i := 1 to Length(Result) do
    if not CharInSet(Result[i], ['A'..'Z', 'a'..'z', '0'..'9', '_']) then
      Result[i] := '_';
end;

function Anahtar(const Tur, Ad1, Ad2: string): string;
begin
  Result := Tur + '|' + Ad1 + '|' + Ad2;
end;

function AciklamaAl(Liste: TAciklamalar; const Tur, Ad1, Ad2: string): string;
begin
  if not Liste.TryGetValue(Anahtar(Tur, Ad1, Ad2), Result) then
    Result := '';
end;

function Birlestir(const Adlar: TArray<string>): string;
var
  Ad: string;
begin
  Result := '';
  for Ad in Adlar do
  begin
    if Result <> '' then
      Result := Result + ', ';
    Result := Result + Ad;
  end;
end;

function EvetHayir(Deger: Boolean): string;
begin
  if Deger then
    Result := T('DOK_EVET')
  else
    Result := T('DOK_HAYIR');
end;

{ Baslik, sonra (varsa) aciklama paragrafi. }
procedure AciklamaYaz(Y: TTextWriter; const Metin: string);
begin
  if Metin <> '' then
    Y.WriteLine('<p class="not">' + H(Metin) + '</p>');
end;

{ Kaynak metni, tikla-ac kutusunda. }
procedure KaynakYaz(Y: TTextWriter; const Kaynak: string);
begin
  if Trim(Kaynak) = '' then
    Exit;
  Y.WriteLine('<details><summary>' + H(T('DOK_KAYNAK')) + '</summary><pre>' + H(Trim(Kaynak)) + '</pre></details>');
end;

function TetikleyiciOzeti(const Tetik: TTetikleyiciBilgisi): string;
begin
  Result := Trim(Tetik.Zaman + ' ' + Tetik.Olaylar);
  if not Tetik.Aktif then
    Result := Result + ' (' + T('DOK_PASIF') + ')';
end;

procedure KolonTablosuYaz(Y: TTextWriter; Liste: TAciklamalar; const Tablo: string; const Bilgi: TTabloBilgisi);
var
  Kolon: TKolonBilgisi;
  Kisit: TKisitBilgisi;
  Birincil, Tip, Ek: string;
begin
  Birincil := '';
  for Kisit in Bilgi.Kisitlar do
    if Kisit.Tur = ktBirincil then
      Birincil := ',' + UpperCase(Birlestir(Kisit.Kolonlar)).Replace(', ', ',') + ',';
  Y.WriteLine('<table><tr><th>' + H(T('DOK_KOLON')) + '</th><th>' + H(T('DOK_TIP')) + '</th><th>' +
    H(T('DOK_BOS_OLABILIR')) + '</th><th>' + H(T('DOK_VARSAYILAN')) + '</th><th>' + H(T('DOK_ACIKLAMA')) + '</th></tr>');
  for Kolon in Bilgi.Kolonlar do
  begin
    if Kolon.Hesaplanan <> '' then
      Tip := 'COMPUTED BY ' + Kolon.Hesaplanan
    else if Kolon.Domain <> '' then
      Tip := Kolon.Domain
    else
      Tip := Kolon.Tip;
    Ek := '';
    if Pos(',' + UpperCase(Kolon.Ad) + ',', Birincil) > 0 then
      Ek := ' <span class="pk">PK</span>';
    if Kolon.Kimlik then
      Ek := Ek + ' <span class="pk">IDENTITY</span>';
    Y.WriteLine('<tr><td>' + H(Kolon.Ad) + Ek + '</td><td>' + H(Tip) + '</td><td>' + H(EvetHayir(not Kolon.BosOlmaz)) +
      '</td><td>' + H(Kolon.Varsayilan) + '</td><td>' + H(AciklamaAl(Liste, 'COLUMN', Tablo, Kolon.Ad)) + '</td></tr>');
  end;
  Y.WriteLine('</table>');
end;

procedure KisitlariYaz(Y: TTextWriter; const Bilgi: TTabloBilgisi);
var
  Kisit: TKisitBilgisi;
  TurAdi, Ayrinti: string;
begin
  if Length(Bilgi.Kisitlar) = 0 then
    Exit;
  Y.WriteLine('<h4>' + H(T('DOK_KISITLAR')) + '</h4>');
  Y.WriteLine('<table><tr><th>' + H(T('DOK_TUR')) + '</th><th>' + H(T('DOK_AD')) + '</th><th>' + H(T('DOK_KOLON')) +
    '</th><th>' + H(T('DOK_AYRINTI')) + '</th></tr>');
  for Kisit in Bilgi.Kisitlar do
  begin
    Ayrinti := '';
    case Kisit.Tur of
      ktBirincil: TurAdi := 'PRIMARY KEY';
      ktBenzersiz: TurAdi := 'UNIQUE';
      ktYabanci:
        begin
          TurAdi := 'FOREIGN KEY';
          Ayrinti := '&rarr; ' + H(Kisit.HedefTablo) + ' (' + H(Birlestir(Kisit.HedefKolonlar)) + ')';
          if Kisit.GuncelleKurali <> '' then
            Ayrinti := Ayrinti + ' ON UPDATE ' + H(Kisit.GuncelleKurali);
          if Kisit.SilKurali <> '' then
            Ayrinti := Ayrinti + ' ON DELETE ' + H(Kisit.SilKurali);
        end;
    else
      TurAdi := 'CHECK';
      Ayrinti := H(Kisit.CheckMetni);
    end;
    Y.WriteLine('<tr><td>' + TurAdi + '</td><td>' + H(Kisit.GercekAd) + '</td><td>' + H(Birlestir(Kisit.Kolonlar)) +
      '</td><td>' + Ayrinti + '</td></tr>');
  end;
  Y.WriteLine('</table>');
end;

procedure IndeksleriYaz(Y: TTextWriter; const Bilgi: TTabloBilgisi);
var
  Indeks: TIndeksBilgisi;
  Kolonlar: string;
begin
  if Length(Bilgi.Indeksler) = 0 then
    Exit;
  Y.WriteLine('<h4>' + H(T('DOK_INDEKSLER')) + '</h4>');
  Y.WriteLine('<table><tr><th>' + H(T('DOK_AD')) + '</th><th>' + H(T('DOK_KOLON')) + '</th><th>' + H(T('DOK_BENZERSIZ')) +
    '</th><th>' + H(T('DOK_PASIF')) + '</th></tr>');
  for Indeks in Bilgi.Indeksler do
  begin
    if Indeks.Ifade <> '' then
      Kolonlar := Indeks.Ifade
    else
      Kolonlar := Birlestir(Indeks.Kolonlar);
    Y.WriteLine('<tr><td>' + H(Indeks.Ad) + '</td><td>' + H(Kolonlar) + '</td><td>' + H(EvetHayir(Indeks.Benzersiz)) +
      '</td><td>' + H(EvetHayir(Indeks.Pasif)) + '</td></tr>');
  end;
  Y.WriteLine('</table>');
end;

procedure TabloBolumu(Y: TTextWriter; Bag: TAcikBaglanti; Liste: TAciklamalar; const Tablo: TTabloOzeti);
var
  Bilgi: TTabloBilgisi;
  Tetik: TTetikleyiciBilgisi;
begin
  Bilgi := TabloBilgisiOku(Bag, Tablo.Ad);
  Y.WriteLine('<h3 id="' + Kimlik('t_', Tablo.Ad) + '">' + H(Tablo.Ad) + '</h3>');
  AciklamaYaz(Y, Tablo.Aciklama);
  KolonTablosuYaz(Y, Liste, Tablo.Ad, Bilgi);
  KisitlariYaz(Y, Bilgi);
  IndeksleriYaz(Y, Bilgi);
  if Length(Bilgi.Tetikleyiciler) > 0 then
  begin
    Y.WriteLine('<h4>' + H(T('DOK_TETIKLEYICILER')) + '</h4><ul>');
    for Tetik in Bilgi.Tetikleyiciler do
      Y.WriteLine('<li><a href="#' + Kimlik('g_', Tetik.Ad) + '">' + H(Tetik.Ad) + '</a> (' + H(TetikleyiciOzeti(Tetik)) + ')</li>');
    Y.WriteLine('</ul>');
  end;
end;

procedure ViewBolumu(Y: TTextWriter; Bag: TAcikBaglanti; Liste: TAciklamalar; const Ad: string);
var
  Bilgi: TViewBilgisi;
begin
  Bilgi := ViewBilgisiOku(Bag, Ad);
  Y.WriteLine('<h3 id="' + Kimlik('v_', Ad) + '">' + H(Ad) + '</h3>');
  AciklamaYaz(Y, AciklamaAl(Liste, 'VIEW', Ad, ''));
  Y.WriteLine('<p>' + H(Birlestir(Bilgi.Kolonlar)) + '</p>');
  KaynakYaz(Y, Bilgi.Kaynak);
end;

procedure ParametreTablosuYaz(Y: TTextWriter; Liste: TAciklamalar; const Prosedur, Baslik: string;
  const Parametreler: TArray<TParametreBilgisi>);
var
  Param: TParametreBilgisi;
  Tip: string;
begin
  if Length(Parametreler) = 0 then
    Exit;
  Y.WriteLine('<h4>' + H(Baslik) + '</h4>');
  Y.WriteLine('<table><tr><th>' + H(T('DOK_AD')) + '</th><th>' + H(T('DOK_TIP')) + '</th><th>' + H(T('DOK_ACIKLAMA')) + '</th></tr>');
  for Param in Parametreler do
  begin
    if Param.Domain <> '' then
      Tip := Param.Domain
    else
      Tip := Param.Tip;
    Y.WriteLine('<tr><td>' + H(Param.Ad) + '</td><td>' + H(Tip) + '</td><td>' +
      H(AciklamaAl(Liste, 'PROCEDURE PARAMETER', Prosedur, Param.Ad)) + '</td></tr>');
  end;
  Y.WriteLine('</table>');
end;

procedure ProsedurBolumu(Y: TTextWriter; Bag: TAcikBaglanti; Liste: TAciklamalar; const Ad: string);
var
  Bilgi: TProsedurBilgisi;
begin
  Bilgi := ProsedurBilgisiOku(Bag, Ad);
  Y.WriteLine('<h3 id="' + Kimlik('p_', Ad) + '">' + H(Ad) + '</h3>');
  AciklamaYaz(Y, AciklamaAl(Liste, 'PROCEDURE', Ad, ''));
  ParametreTablosuYaz(Y, Liste, Ad, T('DOK_GIRDILER'), Bilgi.Girdiler);
  ParametreTablosuYaz(Y, Liste, Ad, T('DOK_CIKTILAR'), Bilgi.Ciktilar);
  KaynakYaz(Y, Bilgi.Kaynak);
end;

procedure TetikleyiciBolumu(Y: TTextWriter; const Tetik: TTetikleyiciBilgisi; Liste: TAciklamalar);
var
  Bagli: string;
begin
  Bagli := Tetik.Tablo;
  if Bagli <> '' then
    Bagli := ' &mdash; <a href="#' + Kimlik('t_', Tetik.Tablo) + '">' + H(Tetik.Tablo) + '</a>';
  Y.WriteLine('<h3 id="' + Kimlik('g_', Tetik.Ad) + '">' + H(Tetik.Ad) + '</h3>');
  Y.WriteLine('<p>' + H(TetikleyiciOzeti(Tetik)) + Bagli + '</p>');
  AciklamaYaz(Y, AciklamaAl(Liste, 'TRIGGER', Tetik.Ad, ''));
  KaynakYaz(Y, Tetik.Kaynak);
end;

{ Ad listesi + yanlarinda deger/aciklama: generator, exception, domain bolumleri icin kucuk tablo. }
procedure GeneratorleriYaz(Y: TTextWriter; Bag: TAcikBaglanti; Liste: TAciklamalar);
var
  Ad, Tur: string;
  Adlar: TArray<string>;
begin
  Adlar := GeneratorAdlari(Bag);
  if Length(Adlar) = 0 then
    Exit;
  Y.WriteLine('<h2 id="generatorler">' + H(T('DOK_GENERATORLER')) + '</h2>');
  Y.WriteLine('<table><tr><th>' + H(T('DOK_AD')) + '</th><th>' + H(T('DOK_DEGER')) + '</th><th>' + H(T('DOK_ACIKLAMA')) + '</th></tr>');
  for Ad in Adlar do
  begin
    Tur := 'SEQUENCE';
    if not Liste.ContainsKey(Anahtar(Tur, Ad, '')) then
      Tur := 'GENERATOR';
    Y.WriteLine('<tr><td>' + H(Ad) + '</td><td>' + IntToStr(GeneratorBilgisiOku(Bag, Ad).Deger) + '</td><td>' +
      H(AciklamaAl(Liste, Tur, Ad, '')) + '</td></tr>');
  end;
  Y.WriteLine('</table>');
end;

procedure IstisnalariYaz(Y: TTextWriter; Bag: TAcikBaglanti; Liste: TAciklamalar);
var
  Istisna: TIstisnaBilgisi;
  Hepsi: TArray<TIstisnaBilgisi>;
begin
  Hepsi := IstisnalariOku(Bag);
  if Length(Hepsi) = 0 then
    Exit;
  Y.WriteLine('<h2 id="istisnalar">' + H(T('DOK_ISTISNALAR')) + '</h2>');
  Y.WriteLine('<table><tr><th>' + H(T('DOK_AD')) + '</th><th>' + H(T('DOK_MESAJ')) + '</th><th>' + H(T('DOK_ACIKLAMA')) + '</th></tr>');
  for Istisna in Hepsi do
    Y.WriteLine('<tr><td>' + H(Istisna.Ad) + '</td><td>' + H(Istisna.Mesaj) + '</td><td>' +
      H(AciklamaAl(Liste, 'EXCEPTION', Istisna.Ad, '')) + '</td></tr>');
  Y.WriteLine('</table>');
end;

procedure DomainleriYaz(Y: TTextWriter; Bag: TAcikBaglanti; Liste: TAciklamalar);
var
  Alan: TDomainBilgisi;
  Hepsi: TArray<TDomainBilgisi>;
  Ayrinti: string;
begin
  Hepsi := DomainleriOku(Bag);
  if Length(Hepsi) = 0 then
    Exit;
  Y.WriteLine('<h2 id="domainler">' + H(T('DOK_DOMAINLER')) + '</h2>');
  Y.WriteLine('<table><tr><th>' + H(T('DOK_AD')) + '</th><th>' + H(T('DOK_TIP')) + '</th><th>' + H(T('DOK_AYRINTI')) +
    '</th><th>' + H(T('DOK_ACIKLAMA')) + '</th></tr>');
  for Alan in Hepsi do
  begin
    Ayrinti := Trim(Alan.Varsayilan + ' ' + Alan.Kontrol);
    if Alan.BosOlmaz then
      Ayrinti := Trim(Ayrinti + ' NOT NULL');
    Y.WriteLine('<tr><td>' + H(Alan.Ad) + '</td><td>' + H(Alan.Tip) + '</td><td>' + H(Ayrinti) + '</td><td>' +
      H(AciklamaAl(Liste, 'DOMAIN', Alan.Ad, '')) + '</td></tr>');
  end;
  Y.WriteLine('</table>');
end;

{ Icindekiler: bir bolumun adlarini baglanti olarak dizer. }
procedure IcindekilerSatiri(Y: TTextWriter; const Baslik, On: string; const Adlar: TArray<string>);
var
  Ad: string;
begin
  if Length(Adlar) = 0 then
    Exit;
  Y.WriteLine('<p><b>' + H(Baslik) + ' (' + IntToStr(Length(Adlar)) + '):</b> ');
  for Ad in Adlar do
    Y.WriteLine('<a href="#' + Kimlik(On, Ad) + '">' + H(Ad) + '</a> ');
  Y.WriteLine('</p>');
end;

const
  STIL =
    'body{font-family:Segoe UI,Arial,sans-serif;margin:24px auto;max-width:1100px;padding:0 16px;color:#222}' +
    'h1{font-size:26px}h2{margin-top:40px;border-bottom:2px solid #d0d7de;padding-bottom:4px}' +
    'h3{margin-top:28px;font-size:18px}h4{margin:14px 0 4px;font-size:14px;color:#555}' +
    'table{border-collapse:collapse;width:100%;font-size:14px}th,td{border:1px solid #d0d7de;padding:4px 8px;text-align:left;vertical-align:top}' +
    'th{background:#f3f5f7}.pk{background:#e6f0ff;color:#235;font-size:11px;padding:0 4px;border-radius:3px}' +
    '.not{margin:2px 0 8px;color:#555;font-style:italic}pre{background:#f6f8fa;padding:10px;overflow:auto;font-size:13px}' +
    'a{color:#0b5cad;text-decoration:none}a:hover{text-decoration:underline}.kucuk{color:#666;font-size:13px}';

{ Ilerleme bildirir; iptal istendiyse True doner. }
function IptalMi(Ilerleme: TDokumanIlerleme; const Adim: string): Boolean;
begin
  Result := False;
  if Assigned(Ilerleme) then
    Ilerleme(Adim, Result);
end;

function DokumanUret(Bag: TAcikBaglanti; Yazici: TTextWriter; Ilerleme: TDokumanIlerleme): TDokumanOzeti;
var
  Liste: TAciklamalar;
  Aciklama: TAciklamaBilgisi;
  Tablolar: TArray<TTabloOzeti>;
  Viewlar, Prosedurler, Dongu: TArray<string>;
  Ad: string;
  Tetikler: TArray<TTetikleyiciBilgisi>;
  Ozet: TTabloOzeti;
  Tetik: TTetikleyiciBilgisi;
  TabloAdlari_: TArray<string>;
  i: Integer;
  AdMetni: string;
begin
  FillChar(Result, SizeOf(Result), 0);
  IptalMi(Ilerleme, T('DOK_HAZIRLIK'));
  Liste := TAciklamalar.Create;
  try
    for Aciklama in AciklamalariOku(Bag) do
      Liste.AddOrSetValue(Anahtar(Aciklama.Tur, Aciklama.Ad1, Aciklama.Ad2), Aciklama.Metin);
    Tablolar := TabloOzetleriniOku(Bag);
    Viewlar := ViewAdlariSirali(Bag, Dongu);
    Prosedurler := ProsedurAdlari(Bag);
    Tetikler := TetikleyicileriOku(Bag, '');
    SetLength(TabloAdlari_, Length(Tablolar));
    for i := 0 to High(Tablolar) do
      TabloAdlari_[i] := Tablolar[i].Ad;
    AdMetni := ExtractFileName(Bag.Tanim.VeritabaniYolu);

    Yazici.WriteLine('<!DOCTYPE html>');
    Yazici.WriteLine('<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">');
    Yazici.WriteLine('<title>' + H(T('DOK_BASLIK') + ' - ' + AdMetni) + '</title><style>' + STIL + '</style></head><body>');
    Yazici.WriteLine('<h1>' + H(T('DOK_BASLIK')) + ': ' + H(AdMetni) + '</h1>');
    Yazici.WriteLine('<p class="kucuk">' + H(TF('DOK_ALT_BILGI', [Bag.Tanim.VeritabaniYolu, Bag.Surum,
      FormatDateTime('yyyy-mm-dd hh:nn', Now)])) + '</p>');
    Yazici.WriteLine('<h2>' + H(T('DOK_ICINDEKILER')) + '</h2>');
    IcindekilerSatiri(Yazici, T('DOK_TABLOLAR'), 't_', TabloAdlari_);
    IcindekilerSatiri(Yazici, T('DOK_VIEWLAR'), 'v_', Viewlar);
    IcindekilerSatiri(Yazici, T('DOK_PROSEDURLER'), 'p_', Prosedurler);
    if Length(Tetikler) > 0 then
      Yazici.WriteLine('<p><a href="#tetikleyiciler">' + H(T('DOK_TETIKLEYICILER')) + ' (' + IntToStr(Length(Tetikler)) + ')</a> &middot; ' +
        '<a href="#generatorler">' + H(T('DOK_GENERATORLER')) + '</a> &middot; <a href="#istisnalar">' + H(T('DOK_ISTISNALAR')) +
        '</a> &middot; <a href="#domainler">' + H(T('DOK_DOMAINLER')) + '</a></p>')
    else
      Yazici.WriteLine('<p><a href="#generatorler">' + H(T('DOK_GENERATORLER')) + '</a> &middot; <a href="#istisnalar">' +
        H(T('DOK_ISTISNALAR')) + '</a> &middot; <a href="#domainler">' + H(T('DOK_DOMAINLER')) + '</a></p>');

    if Length(Tablolar) > 0 then
      Yazici.WriteLine('<h2>' + H(T('DOK_TABLOLAR')) + '</h2>');
    for i := 0 to High(Tablolar) do
    begin
      Ozet := Tablolar[i];
      if IptalMi(Ilerleme, TF('DOK_ADIM', [T('DOK_TABLOLAR'), i + 1, Length(Tablolar), Ozet.Ad])) then
      begin
        Result.Iptal := True;
        Break;
      end;
      TabloBolumu(Yazici, Bag, Liste, Ozet);
      Inc(Result.Tablo);
    end;
    if Length(Viewlar) > 0 then
      Yazici.WriteLine('<h2>' + H(T('DOK_VIEWLAR')) + '</h2>');
    for i := 0 to High(Viewlar) do
    begin
      Ad := Viewlar[i];
      if Result.Iptal or IptalMi(Ilerleme, TF('DOK_ADIM', [T('DOK_VIEWLAR'), i + 1, Length(Viewlar), Ad])) then
      begin
        Result.Iptal := True;
        Break;
      end;
      ViewBolumu(Yazici, Bag, Liste, Ad);
      Inc(Result.View);
    end;
    if Length(Prosedurler) > 0 then
      Yazici.WriteLine('<h2>' + H(T('DOK_PROSEDURLER')) + '</h2>');
    for i := 0 to High(Prosedurler) do
    begin
      Ad := Prosedurler[i];
      if Result.Iptal or IptalMi(Ilerleme, TF('DOK_ADIM', [T('DOK_PROSEDURLER'), i + 1, Length(Prosedurler), Ad])) then
      begin
        Result.Iptal := True;
        Break;
      end;
      ProsedurBolumu(Yazici, Bag, Liste, Ad);
      Inc(Result.Prosedur);
    end;
    if Length(Tetikler) > 0 then
      Yazici.WriteLine('<h2 id="tetikleyiciler">' + H(T('DOK_TETIKLEYICILER')) + '</h2>');
    for i := 0 to High(Tetikler) do
    begin
      Tetik := Tetikler[i];
      if Result.Iptal or IptalMi(Ilerleme, TF('DOK_ADIM', [T('DOK_TETIKLEYICILER'), i + 1, Length(Tetikler), Tetik.Ad])) then
      begin
        Result.Iptal := True;
        Break;
      end;
      TetikleyiciBolumu(Yazici, Tetik, Liste);
      Inc(Result.Tetikleyici);
    end;
    if Result.Iptal then
      Yazici.WriteLine('<p class="not">' + H(T('DOK_IPTAL_NOTU')) + '</p>')
    else
    begin
      GeneratorleriYaz(Yazici, Bag, Liste);
      IstisnalariYaz(Yazici, Bag, Liste);
      DomainleriYaz(Yazici, Bag, Liste);
    end;
    Yazici.WriteLine('</body></html>');
  finally
    Liste.Free;
  end;
end;

function DokumanDosyasiYaz(Bag: TAcikBaglanti; const Dosya: string; Ilerleme: TDokumanIlerleme): TDokumanOzeti;
var
  Yazici: TStreamWriter;
  Kodlama: TEncoding;
begin
  Kodlama := TUTF8Encoding.Create(False);
  try
    Yazici := TStreamWriter.Create(Dosya, False, Kodlama);
    try
      Result := DokumanUret(Bag, Yazici, Ilerleme);
    finally
      Yazici.Free;
    end;
  finally
    Kodlama.Free;
  end;
end;

function VarsayilanDokumanAdi(Bag: TAcikBaglanti): string;
const
  OLMAZ = '\/:*?"<>|';
var
  i: Integer;
begin
  Result := TPath.GetFileNameWithoutExtension(Bag.Tanim.VeritabaniYolu);
  if Result = '' then
    Result := 'veritabani';
  for i := 1 to Length(Result) do
    if (Pos(Result[i], OLMAZ) > 0) or (Result[i] < ' ') then
      Result[i] := '_';
  Result := Result + '_' + FormatDateTime('yyyymmdd_hhnnss', Now) + '.html';
end;

end.
