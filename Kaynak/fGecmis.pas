{ fGecmis.pas - "SQL gecmisi ve sik kullanilan sorgular" penceresi (Asama 7e).
  Form sadece arayuzu bilir; kayit islerini uSorguGecmisi yapar. Iki sekme: Gecmis (calistirilan sorgular)
  ve Sik kullanilanlar (adlandirilmis). Secilen sorgu "Editore ekle" ile (ya da cift tiklayarak) editorun
  sonuna eklenir; pencere hicbir sorguyu kendisi calistirmaz. }
unit fGecmis;

interface

uses
  System.SysUtils, System.Classes, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls,
  uDil, uOnay, uSorguGecmisi, fMetinSor;

type
  TfrmGecmis = class(TForm)
    pgSekmeler: TPageControl;
    tsGecmis: TTabSheet;
    tsSik: TTabSheet;
    lvGecmis: TListView;
    lvSik: TListView;
    memSql: TMemo;
    lblNot: TLabel;
    pnlAlt: TPanel;
    btnEditore: TButton;
    btnSikEkle: TButton;
    btnEditordekiniEkle: TButton;
    btnSil: TButton;
    btnTemizle: TButton;
    btnKapat: TButton;
    procedure pgSekmelerChange(Sender: TObject);
    procedure lvGecmisSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
    procedure lvSikSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
    procedure lvDblClick(Sender: TObject);
    procedure btnEditoreClick(Sender: TObject);
    procedure btnSikEkleClick(Sender: TObject);
    procedure btnEditordekiniEkleClick(Sender: TObject);
    procedure btnSilClick(Sender: TObject);
    procedure btnTemizleClick(Sender: TObject);
  private
    FGecmis: TArray<TGecmisKaydi>;
    FSik: TArray<TSikSorgu>;
    FEditorMetni: string;
    FSecilen: string;
    procedure YazilariYaz;
    procedure GecmisiDoldur;
    procedure SikiDoldur;
    procedure DugmeleriAyarla;
    function SeciliSql: string;
  end;

{ Pencereyi gosterir. EditorMetni: aktif sorgu sekmesindeki yazi ("Editordekini ekle" icin).
  Kullanici bir sorgu secip "Editore ekle" derse True doner ve Secilen o sorgudur. }
function GecmisPenceresiniGoster(const EditorMetni: string; out Secilen: string): Boolean;

implementation

{$R *.dfm}

function GecmisPenceresiniGoster(const EditorMetni: string; out Secilen: string): Boolean;
var
  Pencere: TfrmGecmis;
begin
  Secilen := '';
  Pencere := TfrmGecmis.Create(Application);
  try
    Pencere.FEditorMetni := EditorMetni;
    Pencere.YazilariYaz;
    Pencere.GecmisiDoldur;
    Pencere.SikiDoldur;
    Pencere.DugmeleriAyarla;
    Pencere.ShowModal;
    Secilen := Pencere.FSecilen;
    Result := Secilen <> '';
  finally
    Pencere.Free;
  end;
end;

procedure TfrmGecmis.YazilariYaz;
begin
  Caption := T('GECMIS_BASLIK');
  tsGecmis.Caption := T('GECMIS_SEKME_GECMIS');
  tsSik.Caption := T('GECMIS_SEKME_SIK');
  lvGecmis.Columns[0].Caption := T('GECMIS_KOL_ZAMAN');
  lvGecmis.Columns[1].Caption := T('GECMIS_KOL_BAGLANTI');
  lvGecmis.Columns[2].Caption := T('GECMIS_KOL_SQL');
  lvSik.Columns[0].Caption := T('GECMIS_KOL_AD');
  lvSik.Columns[1].Caption := T('GECMIS_KOL_SQL');
  lblNot.Caption := T('GECMIS_NOT');
  btnEditore.Caption := T('GECMIS_EDITORE');
  btnSikEkle.Caption := T('GECMIS_SIKA_EKLE');
  btnEditordekiniEkle.Caption := T('GECMIS_EDITORDEKINI_EKLE');
  btnSil.Caption := T('GECMIS_SIL');
  btnTemizle.Caption := T('GECMIS_TEMIZLE');
  btnKapat.Caption := T('BTN_KAPAT');
  DugmeyiYaziyaUydur(btnEditore);
  DugmeyiYaziyaUydur(btnSikEkle);
  DugmeyiYaziyaUydur(btnEditordekiniEkle);
  DugmeyiYaziyaUydur(btnSil);
  DugmeyiYaziyaUydur(btnTemizle);
  DugmeyiYaziyaUydur(btnKapat);
end;

{ Listede SQL tek satir gorunsun diye satir sonlari bosluga cevrilir; tamami alttaki kutuda. }
function TekSatir(const Sql: string): string;
begin
  Result := StringReplace(StringReplace(Sql, #13, ' ', [rfReplaceAll]), #10, ' ', [rfReplaceAll]);
end;

procedure TfrmGecmis.GecmisiDoldur;
var
  Kayit: TGecmisKaydi;
  Satir: TListItem;
begin
  FGecmis := GecmisiOku;
  lvGecmis.Items.Clear;
  for Kayit in FGecmis do
  begin
    Satir := lvGecmis.Items.Add;
    Satir.Caption := Kayit.Zaman;
    Satir.SubItems.Add(Kayit.Baglanti);
    Satir.SubItems.Add(TekSatir(Kayit.Sql));
  end;
end;

procedure TfrmGecmis.SikiDoldur;
var
  Sorgu: TSikSorgu;
  Satir: TListItem;
begin
  FSik := SikSorgulariOku;
  lvSik.Items.Clear;
  for Sorgu in FSik do
  begin
    Satir := lvSik.Items.Add;
    Satir.Caption := Sorgu.Ad;
    Satir.SubItems.Add(TekSatir(Sorgu.Sql));
  end;
end;

{ Hangi sekme aciksa onun dugmeleri gorunur; secim yoksa secime bagli dugmeler pasif. }
procedure TfrmGecmis.DugmeleriAyarla;
var
  GecmisSekmesi: Boolean;
begin
  GecmisSekmesi := pgSekmeler.ActivePage = tsGecmis;
  btnSikEkle.Visible := GecmisSekmesi;
  btnTemizle.Visible := GecmisSekmesi;
  btnEditordekiniEkle.Visible := not GecmisSekmesi;
  btnSil.Visible := not GecmisSekmesi;
  btnEditore.Enabled := SeciliSql <> '';
  btnSikEkle.Enabled := SeciliSql <> '';
  btnSil.Enabled := SeciliSql <> '';
  btnTemizle.Enabled := Length(FGecmis) > 0;
  btnEditordekiniEkle.Enabled := Trim(FEditorMetni) <> '';
  memSql.Text := SeciliSql;
end;

{ Aktif sekmedeki secili satirin SQL'i; secim yoksa bos. }
function TfrmGecmis.SeciliSql: string;
begin
  Result := '';
  if pgSekmeler.ActivePage = tsGecmis then
  begin
    if lvGecmis.ItemIndex >= 0 then
      Result := FGecmis[lvGecmis.ItemIndex].Sql;
  end
  else if lvSik.ItemIndex >= 0 then
    Result := FSik[lvSik.ItemIndex].Sql;
end;

procedure TfrmGecmis.pgSekmelerChange(Sender: TObject);
begin
  DugmeleriAyarla;
end;

procedure TfrmGecmis.lvGecmisSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
begin
  DugmeleriAyarla;
end;

procedure TfrmGecmis.lvSikSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
begin
  DugmeleriAyarla;
end;

{ Listede cift tiklayinca "Editore ekle" ile ayni. }
procedure TfrmGecmis.lvDblClick(Sender: TObject);
begin
  btnEditoreClick(Sender);
end;

procedure TfrmGecmis.btnEditoreClick(Sender: TObject);
begin
  if SeciliSql = '' then
    Exit;
  FSecilen := SeciliSql;
  ModalResult := mrOk;
end;

{ Gecmiste secili sorguyu sik kullanilanlara ekler (ad sorulur). }
procedure TfrmGecmis.btnSikEkleClick(Sender: TObject);
var
  Ad: string;
begin
  if SeciliSql = '' then
    Exit;
  Ad := '';
  if not MetinSor(T('GECMIS_AD_BASLIK'), T('GECMIS_AD_ETIKET'), Ad, False) then
    Exit;
  if Trim(Ad) = '' then
    Exit;
  SikSorguEkle(Trim(Ad), SeciliSql);
  SikiDoldur;
  pgSekmeler.ActivePage := tsSik;
  DugmeleriAyarla;
end;

{ Aktif sorgu sekmesindeki yaziyi sik kullanilanlara ekler (ad sorulur). }
procedure TfrmGecmis.btnEditordekiniEkleClick(Sender: TObject);
var
  Ad: string;
begin
  if Trim(FEditorMetni) = '' then
    Exit;
  Ad := '';
  if not MetinSor(T('GECMIS_AD_BASLIK'), T('GECMIS_AD_ETIKET'), Ad, False) then
    Exit;
  if Trim(Ad) = '' then
    Exit;
  SikSorguEkle(Trim(Ad), FEditorMetni);
  SikiDoldur;
  DugmeleriAyarla;
end;

{ Sik kullanilanlardan secili olani listeden cikarir (net onayla). }
procedure TfrmGecmis.btnSilClick(Sender: TObject);
begin
  if lvSik.ItemIndex < 0 then
    Exit;
  if not OnayIste(TF('GECMIS_ONAY_SIL', [FSik[lvSik.ItemIndex].Ad])) then
    Exit;
  SikSorguSil(lvSik.ItemIndex);
  SikiDoldur;
  DugmeleriAyarla;
end;

{ Gecmisi temizler: kayitlar silinmez, tarihli bir yan dosyaya tasinir (net onayla). }
procedure TfrmGecmis.btnTemizleClick(Sender: TObject);
begin
  if not OnayIste(TF('GECMIS_ONAY_TEMIZLE', [Length(FGecmis)])) then
    Exit;
  GecmisiTemizle;
  GecmisiDoldur;
  DugmeleriAyarla;
end;

end.
