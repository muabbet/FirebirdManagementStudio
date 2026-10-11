{ fSorguSekme.pas - Bir sorgu sekmesinin icerigi: ustte SQL editoru, altta sonuc.
  Frame sadece arayuzu bilir; is uSorgu, uEditor ve uSonucGrid unit'lerindedir.

  Sekme, baglantiyi adiyla (BaglantiAd) hatirlar; calistirirken acik baglantiyi
  listeden alir. Baglanti kapanmissa komut calismaz ve bunu yazar. }
unit fSorguSekme;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, Data.DB, Vcl.Controls, Vcl.Forms, Vcl.ExtCtrls,
  Vcl.StdCtrls, Vcl.Grids, Vcl.DBGrids,
  FireDAC.Comp.Client,
  uDil, uOnay, uBaglanti, uMetadata, uSorgu, uEditor, uSonucGrid;

type
  TSorguSekme = class(TFrame)
    pnlEditor: TPanel;
    Bolucu: TSplitter;
    pnlSonuc: TPanel;
    lblSonuc: TLabel;
    memMesaj: TMemo;
    gridSonuc: TDBGrid;
    dsSonuc: TDataSource;
    procedure dsSonucDataChange(Sender: TObject; Field: TField);
  private
    FEditor: TSqlEditor;
    FGrid: TSonucGrid;
    FSonuc: TSorguSonucu;
    procedure SonucuBirak;
    procedure SatirSayisiniYaz;
    procedure HataYaz(Hata: Exception);
    function OnayAl(const Komutlar: TArray<string>): Boolean;
    procedure TekKomutCalistir(Bag: TAcikBaglanti; const Sql: string);
    function KayitSatiri(No: Integer; const Kayit: TKomutKaydi): string;
    procedure CokluKomutCalistir(Bag: TAcikBaglanti; const Komutlar: TArray<string>);
    procedure OneriHazirla;
    procedure KolonlariGetir(const Tablo: string; Kolonlar: TStrings);
  public
    BaglantiAd: string;
    No: Integer;
    destructor Destroy; override;
    procedure Hazirla(SekmeNo: Integer; const Baglanti: string);
    procedure Calistir;
    procedure PlanGoster;
    procedure EditoreOdaklan;
    function Baslik: string;
    procedure YazilariYenile;
  end;

implementation

{$R *.dfm}

destructor TSorguSekme.Destroy;
begin
  SonucuBirak;
  inherited;
end;

procedure TSorguSekme.Hazirla(SekmeNo: Integer; const Baglanti: string);
begin
  No := SekmeNo;
  BaglantiAd := Baglanti;
  FEditor := TSqlEditor.Create(pnlEditor);
  FGrid := TSonucGrid.Create(gridSonuc);
  FEditor.KolonGetirici := KolonlariGetir;
  OneriHazirla;
  YazilariYenile;
end;

{ Ctrl+Bosluk listesi icin anahtar kelimeleri ve veritabani nesne adlarini editore verir. }
procedure TSorguSekme.OneriHazirla;
var
  Bag: TAcikBaglanti;
  Adlar, Gecici: TStringList;
begin
  Bag := FbAcikBaglanti(BaglantiAd);
  if Bag = nil then
    Exit;
  FEditor.AnahtarKelimeleriYukle(ExtractFilePath(ParamStr(0)) + 'anahtar_kelimeler.txt', Bag.Surum);
  Adlar := TStringList.Create;
  Gecici := TStringList.Create;
  try
    try
      TablolariGetir(Bag, Gecici);
      Adlar.AddStrings(Gecici);
      ViewlariGetir(Bag, Gecici);
      Adlar.AddStrings(Gecici);
      ProsedurleriGetir(Bag, Gecici);
      Adlar.AddStrings(Gecici);
      GeneratorleriGetir(Bag, Gecici);
      Adlar.AddStrings(Gecici);
    except
      { Nesne adlari alinamazsa sadece anahtar kelimeler onerilir; sekme yine acilir. }
    end;
    FEditor.NesneAdlariniVer(Adlar);
  finally
    Gecici.Free;
    Adlar.Free;
  end;
end;

{ "ad." yazilinca editor bunu cagirir: tablonun kolon adlarini verir, tablo yoksa bos birakir. }
procedure TSorguSekme.KolonlariGetir(const Tablo: string; Kolonlar: TStrings);
var
  Bag: TAcikBaglanti;
  Kolon: TFDMemTable;
begin
  Bag := FbAcikBaglanti(BaglantiAd);
  if Bag = nil then
    Exit;
  try
    Kolon := KolonTablosuOlustur(Bag, Tablo, nil);
    try
      while not Kolon.Eof do
      begin
        Kolonlar.Add(Kolon.FieldByName('AD').AsString);
        Kolon.Next;
      end;
    finally
      Kolon.Free;
    end;
  except
    { Tablo bulunamadi ya da okunamadi: kolon onerisi acilmaz, hata gosterilmez. }
  end;
end;

function TSorguSekme.Baslik: string;
begin
  Result := T('SEKME_SORGU') + ' ' + IntToStr(No) + ' [' + BaglantiAd + ']';
end;

procedure TSorguSekme.EditoreOdaklan;
begin
  FEditor.OdakVer;
end;

procedure TSorguSekme.YazilariYenile;
begin
  SatirSayisiniYaz;
end;

{ Onceki sonucu kapatir: once izgaranin baglantisi kopar, sonra sorgu serbest kalir. }
procedure TSorguSekme.SonucuBirak;
begin
  dsSonuc.DataSet := nil;
  FreeAndNil(FSonuc);
end;

procedure TSorguSekme.SatirSayisiniYaz;
var
  Sayi: Integer;
begin
  if (FSonuc = nil) or not FSonuc.SatirVar then
  begin
    lblSonuc.Caption := T('LBL_SONUC');
    Exit;
  end;
  Sayi := FSonuc.Sorgu.RecordCount;
  lblSonuc.Caption := TF('LBL_SATIR_YUKLENDI', [Sayi]);
  if (Sayi > 0) and (Sayi mod SATIR_PARCASI = 0) then
    lblSonuc.Caption := lblSonuc.Caption + ' ' + TF('LBL_SATIR_DEVAMI', [SATIR_PARCASI]);
end;

{ Kullanici asagi indikce yeni satirlar gelir; yazi her satirda guncellenir. }
procedure TSorguSekme.dsSonucDataChange(Sender: TObject; Field: TField);
begin
  SatirSayisiniYaz;
end;

procedure TSorguSekme.HataYaz(Hata: Exception);
begin
  memMesaj.Lines.Clear;
  memMesaj.Lines.Add(HataMetniniCevir(Hata));
  memMesaj.Lines.Add(T('AYRINTI') + ': ' + Hata.Message);
end;

{ Tek komut: kullanici onayi (tehlikeliyse). Birden fazla: tek onay penceresi, tehlikeli
  komutlar (en fazla ilk 60 karakteri) acikca listelenir. Onay verilmezse hicbiri calismaz. }
function TSorguSekme.OnayAl(const Komutlar: TArray<string>): Boolean;
var
  i: Integer;
  Anahtar, Liste: string;
begin
  Result := True;
  if Length(Komutlar) = 1 then
  begin
    Anahtar := TehlikeliSorguUyarisi(Komutlar[0]);
    if Anahtar <> '' then
      Result := OnayIste(T(Anahtar));
    Exit;
  end;
  Liste := '';
  for i := 0 to High(Komutlar) do
  begin
    Anahtar := TehlikeliSorguUyarisi(Komutlar[i]);
    if Anahtar = 'ONAY_SORGU_DROP' then
      Liste := Liste + TF('ONAY_COKLU_SATIR', [i + 1, Copy(Trim(Komutlar[i]), 1, 60), T('ETIKET_DROP')]) + sLineBreak
    else if Anahtar <> '' then
      Liste := Liste + TF('ONAY_COKLU_SATIR', [i + 1, Copy(Trim(Komutlar[i]), 1, 60), T('ETIKET_WHERE_YOK')]) + sLineBreak;
  end;
  if Liste <> '' then
    Result := OnayIste(TF('ONAY_COKLU_KOMUT', [Length(Komutlar)]) + sLineBreak + sLineBreak + Liste +
      sLineBreak + T('ONAY_COKLU_SON'));
end;

{ Tek komut: sonuc izgarada, 500'er satir. }
procedure TSorguSekme.TekKomutCalistir(Bag: TAcikBaglanti; const Sql: string);
begin
  try
    FSonuc := SorguCalistir(Bag, Sql);
  except
    on E: Exception do
    begin
      HataYaz(E);
      SatirSayisiniYaz;
      Exit;
    end;
  end;
  if FSonuc.SatirVar then
  begin
    dsSonuc.DataSet := FSonuc.Sorgu;
    FGrid.YeniSonuc;
    memMesaj.Lines.Text := TF('MSG_SORGU_SECIM', [FSonuc.Sure]);
  end
  else if FSonuc.Etkilenen >= 0 then
    memMesaj.Lines.Text := TF('MSG_SORGU_DEGISTI', [FSonuc.Etkilenen, FSonuc.Sure])
  else
    memMesaj.Lines.Text := TF('MSG_SORGU_TAMAM', [FSonuc.Sure]);
  SatirSayisiniYaz;
end;

{ Bir komutun mesaj kutusundaki satiri. }
function TSorguSekme.KayitSatiri(No: Integer; const Kayit: TKomutKaydi): string;
begin
  case Kayit.Durum of
    kdAtlandi:
      if Kayit.Tur = ktCommit then
        Result := TF('MSG_COMMIT_ATLANDI', [No])
      else
        Result := TF('MSG_ISQL_ATLANDI', [No, Kayit.Komut]);
    kdDurdu:
      Result := TF('ERR_ROLLBACK_YOK', [No]);
    kdHata:
      Result := TF('ERR_KOMUT_HATASI', [No, Kayit.Hata]) + sLineBreak + T('AYRINTI') + ': ' + Kayit.Ayrinti;
  else
    if Kayit.SatirVar then
      Result := TF('MSG_KOMUT_SATIRI_SECIM', [No, Kayit.Sure])
    else if Kayit.Etkilenen >= 0 then
      Result := TF('MSG_KOMUT_SATIRI_DEGISTI', [No, Kayit.Etkilenen, Kayit.Sure])
    else
      Result := TF('MSG_KOMUT_SATIRI_TAMAM', [No, Kayit.Sure]);
  end;
end;

{ Birden fazla komut: sirayla calisir, ilk hatada durur. Son SELECT'in sonucu izgarada kalir.
  Her komut ayri otomatik onaylandigi icin hata olursa onceki komutlar geri alinmaz; mesajda yazar. }
procedure TSorguSekme.CokluKomutCalistir(Bag: TAcikBaglanti; const Komutlar: TArray<string>);
var
  Kayitlar: TList<TKomutKaydi>;
  i: Integer;
begin
  Kayitlar := TList<TKomutKaydi>.Create;
  try
    FSonuc := BetikCalistir(Bag, Komutlar, Kayitlar);
    memMesaj.Lines.Clear;
    for i := 0 to Kayitlar.Count - 1 do
      memMesaj.Lines.Add(KayitSatiri(i + 1, Kayitlar[i]));
    if (Kayitlar.Count > 0) and (Kayitlar.Last.Durum in [kdDurdu, kdHata]) then
      memMesaj.Lines.Add(TF('MSG_KOMUT_DURDU', [Length(Komutlar) - Kayitlar.Count]));
    memMesaj.Lines.Add(T('MSG_COKLU_ONAY_NOTU'));
  finally
    Kayitlar.Free;
  end;
  if FSonuc <> nil then
  begin
    dsSonuc.DataSet := FSonuc.Sorgu;
    FGrid.YeniSonuc;
  end;
  SatirSayisiniYaz;
end;

{ F5 / Calistir dugmesi: secili yazi varsa onu, yoksa tum editoru calistirir.
  Birden fazla komut varsa hepsi sirayla calisir (bkz. CokluKomutCalistir). }
procedure TSorguSekme.Calistir;
var
  Komutlar: TArray<string>;
  Bag: TAcikBaglanti;
begin
  Komutlar := KomutlaraBol(FEditor.CalistirilacakMetin);
  if Length(Komutlar) = 0 then
  begin
    memMesaj.Lines.Text := T('ERR_SORGU_BOS');
    Exit;
  end;
  Bag := FbAcikBaglanti(BaglantiAd);
  if Bag = nil then
  begin
    memMesaj.Lines.Text := TF('ERR_SORGU_BAGLANTI_YOK', [BaglantiAd]);
    Exit;
  end;
  if not OnayAl(Komutlar) then
  begin
    memMesaj.Lines.Text := T('MSG_SORGU_VAZGECILDI');
    Exit;
  end;
  SonucuBirak;
  if (Length(Komutlar) = 1) and (KomutTuruBul(Komutlar[0]) = ktNormal) then
    TekKomutCalistir(Bag, Komutlar[0])
  else
    CokluKomutCalistir(Bag, Komutlar);
end;

{ Ctrl+L / Plan dugmesi: komutu calistirmadan planini mesaj kutusuna yazar. }
procedure TSorguSekme.PlanGoster;
var
  Komutlar: TArray<string>;
  Plan: string;
  Bag: TAcikBaglanti;
begin
  Komutlar := KomutlaraBol(FEditor.CalistirilacakMetin);
  if Length(Komutlar) = 0 then
  begin
    memMesaj.Lines.Text := T('ERR_SORGU_BOS');
    Exit;
  end;
  if Length(Komutlar) > 1 then
  begin
    memMesaj.Lines.Text := T('ERR_PLAN_TEK_KOMUT');
    Exit;
  end;
  Bag := FbAcikBaglanti(BaglantiAd);
  if Bag = nil then
  begin
    memMesaj.Lines.Text := TF('ERR_SORGU_BAGLANTI_YOK', [BaglantiAd]);
    Exit;
  end;
  try
    Plan := SorguPlaniAl(Bag, Komutlar[0]);
  except
    on E: Exception do
    begin
      memMesaj.Lines.Clear;
      memMesaj.Lines.Add(T('ERR_PLAN_ALINAMADI') + ' ' + HataMetniniCevir(E));
      memMesaj.Lines.Add(T('AYRINTI') + ': ' + E.Message);
      Exit;
    end;
  end;
  if Plan = '' then
    memMesaj.Lines.Text := T('MSG_PLAN_YOK')
  else
    memMesaj.Lines.Text := T('MSG_PLAN_BASLIK') + sLineBreak + Plan + sLineBreak + sLineBreak +
      T('MSG_PLAN_CALISTIRILMADI');
end;

end.
