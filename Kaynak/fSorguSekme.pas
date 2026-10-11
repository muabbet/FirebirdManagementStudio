{ fSorguSekme.pas - Bir sorgu sekmesinin icerigi: ustte SQL editoru, altta sonuc.
  Frame sadece arayuzu bilir; is uSorgu, uEditor ve uSonucGrid unit'lerindedir.

  Sekme, baglantiyi adiyla (BaglantiAd) hatirlar; calistirirken acik baglantiyi
  listeden alir. Baglanti kapanmissa komut calismaz ve bunu yazar. }
unit fSorguSekme;

interface

uses
  System.SysUtils, System.Classes, Data.DB, Vcl.Controls, Vcl.Forms, Vcl.ExtCtrls,
  Vcl.StdCtrls, Vcl.Grids, Vcl.DBGrids,
  uDil, uOnay, uBaglanti, uSorgu, uEditor, uSonucGrid;

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
  YazilariYenile;
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

{ F5 / Calistir dugmesi: secili yazi varsa onu, yoksa tum editoru calistirir. }
procedure TSorguSekme.Calistir;
var
  Sql, OnayAnahtari: string;
  Bag: TAcikBaglanti;
begin
  Sql := FEditor.CalistirilacakMetin;
  if Trim(Sql) = '' then
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
  OnayAnahtari := TehlikeliSorguUyarisi(Sql);
  if (OnayAnahtari <> '') and not OnayIste(T(OnayAnahtari)) then
  begin
    memMesaj.Lines.Text := T('MSG_SORGU_VAZGECILDI');
    Exit;
  end;
  SonucuBirak;
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

{ Ctrl+L / Plan dugmesi: komutu calistirmadan planini mesaj kutusuna yazar. }
procedure TSorguSekme.PlanGoster;
var
  Sql, Plan: string;
  Bag: TAcikBaglanti;
begin
  Sql := FEditor.CalistirilacakMetin;
  if Trim(Sql) = '' then
  begin
    memMesaj.Lines.Text := T('ERR_SORGU_BOS');
    Exit;
  end;
  if not TekKomutMu(Sql) then
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
    Plan := SorguPlaniAl(Bag, Sql);
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
