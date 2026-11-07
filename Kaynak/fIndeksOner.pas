{ fIndeksOner.pas - "Index oner" penceresi (Asama 7d, 2. adim).
  Form sadece arayuzu bilir; oneriler uIndeksOner'dedir. Pencere acilirken sorgunun plani incelenir (veritabanina yazmaz);
  kullanici onerilerden istediklerini isaretler, "Secilenleri olustur" net onay ister ve index'leri olusturur; sonra plan
  yeniden alinip once / sonra gosterilir. }
unit fIndeksOner;

interface

uses
  System.SysUtils, System.Classes, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls,
  uDil, uOnay, uBaglanti, uKullanici, uProsedur, uSorgu, uIndeksOner;

type
  TfrmIndeksOner = class(TForm)
    lblPlan: TLabel;
    memPlan: TMemo;
    lvOneriler: TListView;
    memNot: TMemo;
    pnlAlt: TPanel;
    btnOlustur: TButton;
    btnKapat: TButton;
    procedure btnOlusturClick(Sender: TObject);
  private
    FBag: TAcikBaglanti;
    FSql: string;
    FSqlYaz: TSqlGoster;
    FSonuc: TStrings;
    FRapor: TIndeksRaporu;
    procedure YazilariYaz;
    procedure ListeyiDoldur;
  end;

{ Pencereyi gosterir. Sql: tek bir komut. SqlYaz: olusturulan CREATE INDEX'in SQL karsiligi; Sonuc: ana pencerenin sonuc alani. }
procedure IndeksOnerPenceresiniGoster(Bag: TAcikBaglanti; const Sql: string; SqlYaz: TSqlGoster; Sonuc: TStrings);

implementation

{$R *.dfm}

procedure IndeksOnerPenceresiniGoster(Bag: TAcikBaglanti; const Sql: string; SqlYaz: TSqlGoster; Sonuc: TStrings);
var
  Pencere: TfrmIndeksOner;
  Rapor: TIndeksRaporu;
begin
  Screen.Cursor := crHourGlass;
  try
    Rapor := IndeksOnerisiHazirla(Bag, Sql);
  finally
    Screen.Cursor := crDefault;
  end;
  if not Rapor.Basarili then
  begin
    UyariGoster(Rapor.Cumle);
    Exit;
  end;
  Pencere := TfrmIndeksOner.Create(Application);
  try
    Pencere.FBag := Bag;
    Pencere.FSql := Sql;
    Pencere.FSqlYaz := SqlYaz;
    Pencere.FSonuc := Sonuc;
    Pencere.FRapor := Rapor;
    Pencere.YazilariYaz;
    Pencere.ListeyiDoldur;
    Pencere.ShowModal;
  finally
    Pencere.Free;
  end;
end;

procedure TfrmIndeksOner.YazilariYaz;
begin
  Caption := T('INDEKS_BASLIK') + ' - ' + FBag.Tanim.Ad;
  lblPlan.Caption := T('INDEKS_PLAN');
  btnOlustur.Caption := T('INDEKS_OLUSTUR');
  btnKapat.Caption := T('BTN_KAPAT');
  DugmeyiYaziyaUydur(btnOlustur);
  DugmeyiYaziyaUydur(btnKapat);
  lvOneriler.Columns[0].Caption := T('INDEKS_KOL_TABLO');
  lvOneriler.Columns[1].Caption := T('INDEKS_KOL_KOLON');
  lvOneriler.Columns[2].Caption := T('INDEKS_KOL_AD');
  lvOneriler.Columns[3].Caption := T('INDEKS_KOL_NEDEN');
  memPlan.Lines.Text := FRapor.Plan;
end;

function KolonlariBirlestir(const Oneri: TIndeksOnerisi): string;
var
  Kolon: string;
begin
  Result := '';
  for Kolon in Oneri.Kolonlar do
  begin
    if Result <> '' then
      Result := Result + ', ';
    Result := Result + Kolon;
  end;
end;

{ Onerileri listeye (hepsi isaretli) ve notlari alt kutuya yazar. }
procedure TfrmIndeksOner.ListeyiDoldur;
var
  Oneri: TIndeksOnerisi;
  Not_: string;
  Satir: TListItem;
begin
  lvOneriler.Items.Clear;
  for Oneri in FRapor.Oneriler do
  begin
    Satir := lvOneriler.Items.Add;
    Satir.Caption := Oneri.Tablo;
    Satir.SubItems.Add(KolonlariBirlestir(Oneri));
    Satir.SubItems.Add(Oneri.Ad);
    Satir.SubItems.Add(Oneri.Neden);
    Satir.Checked := True;
  end;
  memNot.Clear;
  if Length(FRapor.Oneriler) = 0 then
    memNot.Lines.Add(T('INDEKS_ONER_YOK'));
  for Not_ in FRapor.Notlar do
    memNot.Lines.Add('- ' + Not_);
  btnOlustur.Enabled := Length(FRapor.Oneriler) > 0;
end;

{ Isaretli onerileri olusturur: once net onay (CREATE INDEX komutlari), sonra plan yeniden alinip once / sonra gosterilir. }
procedure TfrmIndeksOner.btnOlusturClick(Sender: TObject);
var
  i: Integer;
  Onay, PlanOnce, PlanSonra: string;
  Sonuc: TProsedurSonucu;
  Yapilan: Integer;
begin
  Onay := '';
  Yapilan := 0;
  for i := 0 to lvOneriler.Items.Count - 1 do
    if lvOneriler.Items[i].Checked then
      Onay := Onay + FRapor.Oneriler[i].Sql + ';' + sLineBreak;
  if Onay = '' then
  begin
    UyariGoster(T('INDEKS_SECIM_YOK'));
    Exit;
  end;
  if not OnayIste(T('INDEKS_ONAY_BASLIK') + sLineBreak + sLineBreak + Onay + sLineBreak + T('INDEKS_ONAY_NOT') + sLineBreak +
    sLineBreak + T('INDEKS_ONAY_SORU')) then
    Exit;
  PlanOnce := FRapor.Plan;
  Screen.Cursor := crHourGlass;
  try
    for i := 0 to lvOneriler.Items.Count - 1 do
    begin
      if not lvOneriler.Items[i].Checked then
        Continue;
      Sonuc := IndeksOlustur(FBag, FRapor.Oneriler[i]);
      if Assigned(FSqlYaz) and (Length(Sonuc.Komutlar) > 0) then
        FSqlYaz(Sonuc.Komutlar);
      if Sonuc.Basarili then
      begin
        Inc(Yapilan);
        FSonuc.Add(TF('MSG_INDEKS_OLUSTU', [FRapor.Oneriler[i].Ad, FRapor.Oneriler[i].Tablo]));
      end
      else
      begin
        FSonuc.Add(TF('ERR_INDEKS_OLUSMADI', [FRapor.Oneriler[i].Ad]) + ' ' + Sonuc.Cumle);
        if Sonuc.Ayrinti <> '' then
          FSonuc.Add(T('AYRINTI') + ': ' + Sonuc.Ayrinti);
        UyariGoster(TF('ERR_INDEKS_OLUSMADI', [FRapor.Oneriler[i].Ad]) + sLineBreak + sLineBreak + Sonuc.Cumle);
      end;
    end;
    { Plan yeniden: index kullaniliyor mu? }
    try
      PlanSonra := SorguPlaniAl(FBag, FSql);
    except
      PlanSonra := '';
    end;
  finally
    Screen.Cursor := crDefault;
  end;
  if Yapilan > 0 then
  begin
    memPlan.Lines.Text := T('INDEKS_PLAN_ONCE') + sLineBreak + PlanOnce + sLineBreak + sLineBreak + T('INDEKS_PLAN_SONRA') + sLineBreak + PlanSonra;
    FSonuc.Add(T('INDEKS_PLAN_ONCE') + sLineBreak + PlanOnce);
    FSonuc.Add(T('INDEKS_PLAN_SONRA') + sLineBreak + PlanSonra);
    btnOlustur.Enabled := False;
  end;
end;

end.
