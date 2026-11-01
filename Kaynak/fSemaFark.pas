{ fSemaFark.pas - "Sema farki" sekmesi (Asama 4b): iki veritabanini secip karsilastirir. Ustte kaynak ve hedef,
  ortada fark listesi, altta secili farkin ayrintisi (yalniz bir tarafta varsa CREATE script'i, farkliysa satir farki).
  Sekme yalniz arayuzu bilir; isi uSemaFark yapar. Veritabaninda hicbir sey degistirilmez. }
unit fSemaFark;

interface

uses
  System.SysUtils, System.Classes, Vcl.Controls, Vcl.Forms, Vcl.ExtCtrls, Vcl.StdCtrls, Vcl.ComCtrls, Vcl.Graphics,
  uDil, uOnay, uBaglanti, uDDL, uSemaFark, uCokluSorgu;

type
  TSemaFarkSekme = class(TFrame)
    pnlUst: TPanel;
    lblKaynak: TLabel;
    cmbKaynak: TComboBox;
    lblHedef: TLabel;
    cmbHedef: TComboBox;
    btnKarsilastir: TButton;
    lblOzet: TLabel;
    lvFark: TListView;
    Bolucu: TSplitter;
    memAyrinti: TMemo;
    procedure btnKarsilastirClick(Sender: TObject);
    procedure lvFarkSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
  private
    FFarklar: TArray<TFarkKaydi>;
    FKarsilastirildi: Boolean;
    procedure ListeyiDoldur;
    procedure SonucuGoster;
    procedure OzetiYaz;
  public
    { Islem ozeti ana pencerenin sonuc alanina yazilir; ana pencere atar. }
    AnaSonuc: TStrings;
    procedure Hazirla;
    procedure YazilariYenile;
  end;

implementation

{$R *.dfm}

function TurAdi(Tur: TNesneTuru): string;
begin
  case Tur of
    ntTablo: Result := T('FARK_TUR_TABLO');
    ntView: Result := T('FARK_TUR_VIEW');
    ntProsedur: Result := T('FARK_TUR_PROSEDUR');
    ntTetikleyici: Result := T('FARK_TUR_TETIKLEYICI');
    ntDomain: Result := T('FARK_TUR_DOMAIN');
    ntIstisna: Result := T('FARK_TUR_ISTISNA');
  else
    Result := T('FARK_TUR_GENERATOR');
  end;
end;

function DurumAdi(Durum: TFarkDurumu): string;
begin
  case Durum of
    fdSadeceKaynakta: Result := T('FARK_DURUM_KAYNAKTA');
    fdSadeceHedefte: Result := T('FARK_DURUM_HEDEFTE');
  else
    Result := T('FARK_DURUM_FARKLI');
  end;
end;

procedure TSemaFarkSekme.Hazirla;
begin
  YazilariYenile;
  ListeyiDoldur;
end;

procedure TSemaFarkSekme.YazilariYenile;
begin
  lblKaynak.Caption := T('FARK_KAYNAK');
  lblHedef.Caption := T('FARK_HEDEF');
  btnKarsilastir.Caption := T('BTN_KARSILASTIR');
  DugmeyiYaziyaUydur(btnKarsilastir);
  lvFark.Columns[0].Caption := T('FARK_SUTUN_TUR');
  lvFark.Columns[1].Caption := T('FARK_SUTUN_AD');
  lvFark.Columns[2].Caption := T('FARK_SUTUN_DURUM');
  OzetiYaz;
end;

{ Kullanilabilir (acik veya sifresi kayitli) baglantilar iki kutuya konur; onceki secimler korunur. }
procedure TSemaFarkSekme.ListeyiDoldur;
var
  EskiKaynak, EskiHedef: string;
  Kayit: TBaglantiTanimi;
begin
  EskiKaynak := cmbKaynak.Text;
  EskiHedef := cmbHedef.Text;
  cmbKaynak.Items.Clear;
  cmbHedef.Items.Clear;
  for Kayit in KayitliBaglantilar do
    if CokluBaglantiKullanilabilir(Kayit.Ad) then
    begin
      cmbKaynak.Items.Add(Kayit.Ad);
      cmbHedef.Items.Add(Kayit.Ad);
    end;
  cmbKaynak.ItemIndex := cmbKaynak.Items.IndexOf(EskiKaynak);
  cmbHedef.ItemIndex := cmbHedef.Items.IndexOf(EskiHedef);
  if (cmbKaynak.ItemIndex < 0) and (cmbKaynak.Items.Count > 0) then
    cmbKaynak.ItemIndex := 0;
  if (cmbHedef.ItemIndex < 0) and (cmbHedef.Items.Count > 1) then
    cmbHedef.ItemIndex := 1;
end;

{ Ozet satiri: karsilastirilmadiysa ipucu, yoksa fark sayilari. }
procedure TSemaFarkSekme.OzetiYaz;
var
  Fark: TFarkKaydi;
  Kaynakta, Hedefte, Farkli: Integer;
begin
  if not FKarsilastirildi then
  begin
    lblOzet.Caption := T('FARK_IPUCU');
    Exit;
  end;
  if Length(FFarklar) = 0 then
  begin
    lblOzet.Caption := T('FARK_YOK');
    Exit;
  end;
  Kaynakta := 0;
  Hedefte := 0;
  Farkli := 0;
  for Fark in FFarklar do
    case Fark.Durum of
      fdSadeceKaynakta: Inc(Kaynakta);
      fdSadeceHedefte: Inc(Hedefte);
    else
      Inc(Farkli);
    end;
  lblOzet.Caption := TF('FARK_OZET', [Length(FFarklar), Kaynakta, Hedefte, Farkli]);
end;

procedure TSemaFarkSekme.SonucuGoster;
var
  Fark: TFarkKaydi;
  Satir: TListItem;
begin
  lvFark.Items.BeginUpdate;
  try
    lvFark.Items.Clear;
    for Fark in FFarklar do
    begin
      Satir := lvFark.Items.Add;
      Satir.Caption := TurAdi(Fark.Tur);
      Satir.SubItems.Add(Fark.Ad);
      Satir.SubItems.Add(DurumAdi(Fark.Durum));
    end;
  finally
    lvFark.Items.EndUpdate;
  end;
  memAyrinti.Clear;
  OzetiYaz;
end;

procedure TSemaFarkSekme.btnKarsilastirClick(Sender: TObject);
var
  KaynakAd, HedefAd: string;
begin
  ListeyiDoldur;
  if (cmbKaynak.ItemIndex < 0) or (cmbHedef.ItemIndex < 0) then
  begin
    UyariGoster(T('FARK_SECIM_YOK'));
    Exit;
  end;
  KaynakAd := cmbKaynak.Text;
  HedefAd := cmbHedef.Text;
  if KaynakAd = HedefAd then
  begin
    UyariGoster(T('FARK_AYNI'));
    Exit;
  end;
  Screen.Cursor := crHourGlass;
  try
    try
      FFarklar := SemaKarsilastirAdlarla(KaynakAd, HedefAd,
        procedure(Tur: TNesneTuru)
        begin
          lblOzet.Caption := TF('FARK_ILERLEME', [TurAdi(Tur)]);
          lblOzet.Update;
        end);
    except
      on E: Exception do
      begin
        Screen.Cursor := crDefault;
        UyariGoster(HataMetniniCevir(E));
        if AnaSonuc <> nil then
          AnaSonuc.Add(T('AYRINTI') + ': ' + E.Message);
        OzetiYaz;
        Exit;
      end;
    end;
  finally
    Screen.Cursor := crDefault;
  end;
  FKarsilastirildi := True;
  SonucuGoster;
  if AnaSonuc <> nil then
    AnaSonuc.Add(TF('FARK_SONUC_SATIRI', [KaynakAd, HedefAd]) + ' ' + lblOzet.Caption);
end;

{ Secili farkin ayrintisi: yalniz bir tarafta olan nesnede CREATE script'i (kopyalanabilir), farkli olanda satir farki. }
procedure TSemaFarkSekme.lvFarkSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
var
  Fark: TFarkKaydi;
  Baslik: string;
begin
  if (not Selected) or (Item = nil) or (Item.Index >= Length(FFarklar)) then
    Exit;
  Fark := FFarklar[Item.Index];
  case Fark.Durum of
    fdSadeceKaynakta: Baslik := '-- ' + T('FARK_BASLIK_KAYNAKTA');
    fdSadeceHedefte: Baslik := '-- ' + T('FARK_BASLIK_HEDEFTE');
  else
    Baslik := '-- ' + T('FARK_BASLIK_FARKLI');
  end;
  memAyrinti.Text := Baslik + sLineBreak + sLineBreak + Fark.Ayrinti;
end;

end.
