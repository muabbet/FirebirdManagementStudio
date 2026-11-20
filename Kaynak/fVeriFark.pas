{ fVeriFark.pas - "Veri farki" penceresi (Asama 7u).
  Form sadece arayuzu bilir; is uVeriFark'tadir. Akis: kaynak ve hedef (acik baglanti + tablo) secilir -> Karsilastir
  (iki tabloya da yalniz okunur, ozet yazilir) -> "Script'i yeni sekmede ac" (hedefi kaynaga esitleyen komutlar,
  hedef baglantida yeni sorgu sekmesinde, CALISTIRILMAZ). }
unit fVeriFark;

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls,
  uDil, uOnay, uBaglanti, uMetadata, uAktar, uVeriFark;

type
  TfrmVeriFark = class(TForm)
    lblKaynak: TLabel;
    cmbKaynakDb: TComboBox;
    cmbKaynakTablo: TComboBox;
    lblHedef: TLabel;
    cmbHedefDb: TComboBox;
    cmbHedefTablo: TComboBox;
    chkSil: TCheckBox;
    memSonuc: TMemo;
    pnlAlt: TPanel;
    btnKapat: TButton;
    btnScript: TButton;
    btnKarsilastir: TButton;
    procedure KaynakDbDegisti(Sender: TObject);
    procedure HedefDbDegisti(Sender: TObject);
    procedure SecimDegisti(Sender: TObject);
    procedure btnKarsilastirClick(Sender: TObject);
    procedure btnScriptClick(Sender: TObject);
    procedure btnKapatClick(Sender: TObject);
  private
    FSonuc: TStrings;
    FScriptAc: TScriptAcici;
    { Acik baglanti adlari, iki baglanti kutusunda da ayni sirayla. }
    FAdlar: TArray<string>;
    { Son karsilastirmanin script'i ve hangi baglanti icin uretildigi. }
    FScript: string;
    FScriptBaglanti: string;
    FScriptAciklama: string;
    procedure YazilariYaz;
    procedure TabloListesiniDoldur(Kutu: TComboBox; const BaglantiAd, Secilecek: string);
    function KaynakBaglanti: TAcikBaglanti;
    function HedefBaglanti: TAcikBaglanti;
    procedure SonucuSil;
  end;

{ Pencereyi gosterir. KaynakBaglantiAd ve KaynakTablo baslangic secimidir (bos olabilir). Script acilirsa ozet Sonuc'a yazilir. }
procedure VeriFarkPenceresiniGoster(const KaynakBaglantiAd, KaynakTablo: string; Sonuc: TStrings; ScriptAc: TScriptAcici);

implementation

{$R *.dfm}

procedure VeriFarkPenceresiniGoster(const KaynakBaglantiAd, KaynakTablo: string; Sonuc: TStrings; ScriptAc: TScriptAcici);
var
  Pencere: TfrmVeriFark;
  Ad: string;
begin
  Pencere := TfrmVeriFark.Create(Application);
  try
    Pencere.FSonuc := Sonuc;
    Pencere.FScriptAc := ScriptAc;
    Pencere.FAdlar := FbAcikBaglantiAdlari;
    Pencere.YazilariYaz;
    for Ad in Pencere.FAdlar do
    begin
      Pencere.cmbKaynakDb.Items.Add(Ad);
      Pencere.cmbHedefDb.Items.Add(Ad);
    end;
    { Kaynak: verilen baglanti; hedef: kaynaktan farkli ilk acik baglanti (yoksa ayni). }
    Pencere.cmbKaynakDb.ItemIndex := Pencere.cmbKaynakDb.Items.IndexOf(KaynakBaglantiAd);
    if Pencere.cmbKaynakDb.ItemIndex < 0 then
      Pencere.cmbKaynakDb.ItemIndex := 0;
    Pencere.cmbHedefDb.ItemIndex := 0;
    for Ad in Pencere.FAdlar do
      if not SameText(Ad, Pencere.cmbKaynakDb.Text) then
      begin
        Pencere.cmbHedefDb.ItemIndex := Pencere.cmbHedefDb.Items.IndexOf(Ad);
        Break;
      end;
    Pencere.TabloListesiniDoldur(Pencere.cmbKaynakTablo, Pencere.cmbKaynakDb.Text, KaynakTablo);
    Pencere.TabloListesiniDoldur(Pencere.cmbHedefTablo, Pencere.cmbHedefDb.Text, Pencere.cmbKaynakTablo.Text);
    Pencere.ShowModal;
  finally
    Pencere.Free;
  end;
end;

procedure TfrmVeriFark.YazilariYaz;
begin
  Caption := T('VF_BASLIK');
  lblKaynak.Caption := T('VF_KAYNAK');
  lblHedef.Caption := T('VF_HEDEF');
  chkSil.Caption := T('VF_SIL');
  btnKarsilastir.Caption := T('VF_KARSILASTIR');
  btnScript.Caption := T('VF_SCRIPT_AC');
  btnKapat.Caption := T('BTN_KAPAT');
  btnScript.Enabled := False;
  DugmeyiYaziyaUydur(btnKarsilastir);
  DugmeyiYaziyaUydur(btnScript);
  DugmeyiYaziyaUydur(btnKapat);
end;

function TfrmVeriFark.KaynakBaglanti: TAcikBaglanti;
begin
  Result := nil;
  if cmbKaynakDb.ItemIndex >= 0 then
    Result := FbAcikBaglanti(cmbKaynakDb.Text);
end;

function TfrmVeriFark.HedefBaglanti: TAcikBaglanti;
begin
  Result := nil;
  if cmbHedefDb.ItemIndex >= 0 then
    Result := FbAcikBaglanti(cmbHedefDb.Text);
end;

{ Kutuya baglantinin tablolarini koyar; Secilecek listedeyse o secilir (yoksa ilki). }
procedure TfrmVeriFark.TabloListesiniDoldur(Kutu: TComboBox; const BaglantiAd, Secilecek: string);
var
  Bag: TAcikBaglanti;
  Liste: TStringList;
begin
  Kutu.Items.Clear;
  Bag := FbAcikBaglanti(BaglantiAd);
  if Bag = nil then
    Exit;
  Liste := TStringList.Create;
  try
    try
      TablolariGetir(Bag, Liste);
    except
      on E: Exception do
      begin
        memSonuc.Text := HataMetniniCevir(E) + sLineBreak + T('AYRINTI') + ': ' + E.Message;
        Exit;
      end;
    end;
    Liste.Sort;
    Kutu.Items.Assign(Liste);
  finally
    Liste.Free;
  end;
  Kutu.ItemIndex := Kutu.Items.IndexOf(Secilecek);
  if (Kutu.ItemIndex < 0) and (Kutu.Items.Count > 0) then
    Kutu.ItemIndex := 0;
end;

{ Secim degisti: onceki sonuc gecersiz, script dugmesi kapanir. }
procedure TfrmVeriFark.SonucuSil;
begin
  FScript := '';
  btnScript.Enabled := False;
  memSonuc.Clear;
end;

procedure TfrmVeriFark.KaynakDbDegisti(Sender: TObject);
begin
  TabloListesiniDoldur(cmbKaynakTablo, cmbKaynakDb.Text, '');
  SonucuSil;
end;

procedure TfrmVeriFark.HedefDbDegisti(Sender: TObject);
begin
  TabloListesiniDoldur(cmbHedefTablo, cmbHedefDb.Text, cmbKaynakTablo.Text);
  SonucuSil;
end;

procedure TfrmVeriFark.SecimDegisti(Sender: TObject);
begin
  SonucuSil;
end;

procedure TfrmVeriFark.btnKarsilastirClick(Sender: TObject);
var
  Kaynak, Hedef: TAcikBaglanti;
  Fark: TVeriFarkSonucu;
  Silinecek, Uyari: string;
begin
  SonucuSil;
  Kaynak := KaynakBaglanti;
  Hedef := HedefBaglanti;
  if (Kaynak = nil) or (Hedef = nil) or (cmbKaynakTablo.ItemIndex < 0) or (cmbHedefTablo.ItemIndex < 0) then
  begin
    UyariGoster(T('ERR_VF_SECIM'));
    Exit;
  end;
  if SameText(Kaynak.Tanim.Ad, Hedef.Tanim.Ad) and SameText(cmbKaynakTablo.Text, cmbHedefTablo.Text) then
  begin
    UyariGoster(T('ERR_VF_AYNI'));
    Exit;
  end;
  memSonuc.Text := T('VF_CALISIYOR');
  Application.ProcessMessages;
  Screen.Cursor := crHourGlass;
  try
    Fark := VeriFarkiBul(Kaynak, cmbKaynakTablo.Text, Hedef, cmbHedefTablo.Text, chkSil.Checked);
  finally
    Screen.Cursor := crDefault;
  end;
  if not Fark.Basarili then
  begin
    memSonuc.Text := T('ERR_VF_YAPILAMADI') + ' ' + Fark.Cumle;
    if Fark.Ayrinti <> '' then
      memSonuc.Lines.Add(T('AYRINTI') + ': ' + Fark.Ayrinti);
    Exit;
  end;
  if chkSil.Checked then
    Silinecek := T('VF_DELETE_YAZILDI')
  else
    Silinecek := T('VF_DELETE_YAZILMADI');
  memSonuc.Lines.Text := TF('VF_SONUC', [Fark.SadeceKaynakta, Fark.Farkli, Fark.SadeceHedefte, Silinecek, Fark.Ayni]);
  for Uyari in Fark.Uyarilar do
    memSonuc.Lines.Add(Uyari);
  if Fark.Script = '' then
  begin
    if (Fark.SadeceKaynakta = 0) and (Fark.Farkli = 0) and (Fark.SadeceHedefte = 0) then
      memSonuc.Lines.Add(T('VF_AYNI_TABLO'))
    else
      memSonuc.Lines.Add(T('VF_KOMUT_YOK'));
    Exit;
  end;
  FScript := Fark.Script;
  FScriptBaglanti := Hedef.Tanim.Ad;
  FScriptAciklama := TF('VF_BITTI', [cmbKaynakDb.Text + '.' + cmbKaynakTablo.Text, cmbHedefDb.Text + '.' + cmbHedefTablo.Text]);
  btnScript.Enabled := True;
end;

procedure TfrmVeriFark.btnScriptClick(Sender: TObject);
begin
  if (FScript = '') or not Assigned(FScriptAc) then
    Exit;
  FScriptAc(FScriptBaglanti, FScript);
  FSonuc.Add(FScriptAciklama);
  ModalResult := mrOk;
end;

procedure TfrmVeriFark.btnKapatClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

end.
