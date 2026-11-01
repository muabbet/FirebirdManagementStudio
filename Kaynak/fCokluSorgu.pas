{ fCokluSorgu.pas - "Coklu sorgu" sekmesi (Asama 4a): solda veritabani listesi (kutucuklu), sagda SQL editoru, altta her
  veritabaninin durumu ve birlesik sonuc izgarasi. Sekme yalniz arayuzu bilir; isi uCokluSorgu yapar. F5 calistirir. }
unit fCokluSorgu;

interface

uses
  System.SysUtils, System.Classes, Data.DB, Vcl.Controls, Vcl.Forms, Vcl.ExtCtrls, Vcl.StdCtrls, Vcl.Grids,
  Vcl.DBGrids, Vcl.ComCtrls, Vcl.CheckLst, Vcl.Graphics,
  uDil, uPaket, uOnay, uBaglanti, uEditor, uSonucGrid, uCokluSorgu;

type
  TCokluSorguSekme = class(TFrame)
    pnlSol: TPanel;
    lblVeritabanlari: TLabel;
    pnlSolDugme: TPanel;
    btnHepsi: TButton;
    btnHicbiri: TButton;
    clbVeritabani: TCheckListBox;
    BolucuSol: TSplitter;
    pnlSag: TPanel;
    pnlEditor: TPanel;
    Bolucu: TSplitter;
    pnlSonuc: TPanel;
    lblOzet: TLabel;
    lvDurum: TListView;
    gridSonuc: TDBGrid;
    dsSonuc: TDataSource;
    procedure btnHepsiClick(Sender: TObject);
    procedure btnHicbiriClick(Sender: TObject);
    procedure lvDurumCustomDrawItem(Sender: TCustomListView; Item: TListItem; State: TCustomDrawState;
      var DefaultDraw: Boolean);
  private
    FEditor: TSqlEditor;
    FGrid: TSonucGrid;
    FSonuc: TCokluSonuc;
    { Listedeki gercek baglanti adlari (kutucuk yazisi sifre uyarisi eklenmis olabilir). }
    FAdlar: TArray<string>;
    procedure SonucuBirak;
    procedure ListeyiDoldur;
    function SeciliAdlar: TArray<string>;
    procedure DurumuYaz;
  public
    { Islem ozeti ana pencerenin sonuc alanina yazilir; ana pencere atar. }
    AnaSonuc: TStrings;
    destructor Destroy; override;
    procedure Hazirla;
    { F5: secili veritabanlarinda sorguyu calistirir. }
    procedure Calistir;
    procedure YazilariYenile;
  end;

implementation

{$R *.dfm}

destructor TCokluSorguSekme.Destroy;
begin
  SonucuBirak;
  inherited;
end;

procedure TCokluSorguSekme.Hazirla;
begin
  FEditor := TSqlEditor.Create(pnlEditor);
  FGrid := TSonucGrid.Create(gridSonuc);
  FEditor.AnahtarKelimeleriYukle(PaketKlasoru + '\anahtar_kelimeler.txt', '');
  FEditor.MetinYaz('SELECT * FROM ');
  YazilariYenile;
  ListeyiDoldur;
end;

procedure TCokluSorguSekme.YazilariYenile;
begin
  lblVeritabanlari.Caption := T('COKLU_VERITABANLARI');
  btnHepsi.Caption := T('BTN_HEPSI_SEC');
  btnHicbiri.Caption := T('BTN_HICBIRI_SEC');
  DugmeyiYaziyaUydur(btnHepsi);
  DugmeyiYaziyaUydur(btnHicbiri);
  lvDurum.Columns[0].Caption := T('COKLU_SUTUN_VERITABANI');
  lvDurum.Columns[1].Caption := T('COKLU_SUTUN_DURUM');
  lvDurum.Columns[2].Caption := T('COKLU_SUTUN_SATIR');
  lvDurum.Columns[3].Caption := T('COKLU_SUTUN_SURE');
  lvDurum.Columns[4].Caption := T('COKLU_SUTUN_NOT');
  if FSonuc = nil then
    lblOzet.Caption := T('COKLU_IPUCU')
  else
    DurumuYaz;
end;

{ Sonucu serbest birakir: once izgaranin baglantisi kopar, sonra tablo yok edilir. }
procedure TCokluSorguSekme.SonucuBirak;
begin
  dsSonuc.DataSet := nil;
  FreeAndNil(FSonuc);
end;

{ Kayitli baglantilar listelenir; acik degil ve sifresi kayitli olmayanlar kutucuksuz (kapali) yazilir. Onceki secimler
  korunur. }
procedure TCokluSorguSekme.ListeyiDoldur;
var
  Eski: TStringList;
  Kayitlar: TArray<TBaglantiTanimi>;
  Kayit: TBaglantiTanimi;
  i: Integer;
begin
  Eski := TStringList.Create;
  try
    for i := 0 to High(FAdlar) do
      if (i < clbVeritabani.Items.Count) and clbVeritabani.Checked[i] then
        Eski.Add(FAdlar[i]);
    clbVeritabani.Items.BeginUpdate;
    try
      clbVeritabani.Items.Clear;
      SetLength(FAdlar, 0);
      Kayitlar := KayitliBaglantilar;
      for Kayit in Kayitlar do
      begin
        SetLength(FAdlar, Length(FAdlar) + 1);
        FAdlar[High(FAdlar)] := Kayit.Ad;
        i := clbVeritabani.Items.Add(Kayit.Ad);
        if CokluBaglantiKullanilabilir(Kayit.Ad) then
          clbVeritabani.Checked[i] := Eski.IndexOf(Kayit.Ad) >= 0
        else
        begin
          clbVeritabani.Items[i] := TF('COKLU_KAPALI_ETIKET', [Kayit.Ad]);
          clbVeritabani.ItemEnabled[i] := False;
        end;
      end;
    finally
      clbVeritabani.Items.EndUpdate;
    end;
  finally
    Eski.Free;
  end;
end;

function TCokluSorguSekme.SeciliAdlar: TArray<string>;
var
  i: Integer;
begin
  SetLength(Result, 0);
  for i := 0 to clbVeritabani.Items.Count - 1 do
    if clbVeritabani.Checked[i] and clbVeritabani.ItemEnabled[i] then
    begin
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := FAdlar[i];
    end;
end;

procedure TCokluSorguSekme.btnHepsiClick(Sender: TObject);
var
  i: Integer;
begin
  for i := 0 to clbVeritabani.Items.Count - 1 do
    if clbVeritabani.ItemEnabled[i] then
      clbVeritabani.Checked[i] := True;
end;

procedure TCokluSorguSekme.btnHicbiriClick(Sender: TObject);
var
  i: Integer;
begin
  for i := 0 to clbVeritabani.Items.Count - 1 do
    clbVeritabani.Checked[i] := False;
end;

{ Hata satiri kirmizi, atlanan gri. Satirin Data'si TCokluDurum sirasidir. }
procedure TCokluSorguSekme.lvDurumCustomDrawItem(Sender: TCustomListView; Item: TListItem; State: TCustomDrawState;
  var DefaultDraw: Boolean);
begin
  case TCokluDurum(NativeInt(Item.Data)) of
    cdHata: Sender.Canvas.Font.Color := clRed;
    cdAtlandi: Sender.Canvas.Font.Color := clGrayText;
  end;
end;

{ Ozet satiri: kac veritabani, kac hata/atlanan, toplam satir. }
procedure TCokluSorguSekme.DurumuYaz;
var
  K: TCokluKayit;
  Tamam, Hata, Atlandi, Satir: Integer;
begin
  Tamam := 0;
  Hata := 0;
  Atlandi := 0;
  Satir := 0;
  for K in FSonuc.Kayitlar do
    case K.Durum of
      cdTamam:
        begin
          Inc(Tamam);
          Inc(Satir, K.Satir);
        end;
      cdHata: Inc(Hata);
    else
      Inc(Atlandi);
    end;
  lblOzet.Caption := TF('COKLU_OZET', [Tamam, Hata, Atlandi, Satir]);
end;

procedure TCokluSorguSekme.Calistir;
var
  Uyari, Sql, Not_: string;
  Adlar: TArray<string>;
  K: TCokluKayit;
  Satir: TListItem;
begin
  Sql := FEditor.CalistirilacakMetin;
  Uyari := CokluSorguKontrol(Sql);
  if Uyari <> '' then
  begin
    UyariGoster(Uyari);
    Exit;
  end;
  ListeyiDoldur;
  Adlar := SeciliAdlar;
  if Length(Adlar) = 0 then
  begin
    UyariGoster(T('COKLU_SECIM_YOK'));
    Exit;
  end;
  SonucuBirak;
  Screen.Cursor := crHourGlass;
  try
    FSonuc := CokluSorguCalistir(Adlar, Sql,
      procedure(Ad: string)
      begin
        lblOzet.Caption := TF('COKLU_ILERLEME', [Ad]);
        lblOzet.Update;
      end);
  finally
    Screen.Cursor := crDefault;
  end;
  lvDurum.Items.Clear;
  for K in FSonuc.Kayitlar do
  begin
    Satir := lvDurum.Items.Add;
    Satir.Data := Pointer(NativeInt(Ord(K.Durum)));
    Satir.Caption := K.Ad;
    case K.Durum of
      cdTamam: Satir.SubItems.Add(T('COKLU_DURUM_TAMAM'));
      cdHata: Satir.SubItems.Add(T('COKLU_DURUM_HATA'));
    else
      Satir.SubItems.Add(T('COKLU_DURUM_ATLANDI'));
    end;
    Satir.SubItems.Add(IntToStr(K.Satir));
    Satir.SubItems.Add(IntToStr(K.Sure));
    Not_ := K.Cumle;
    if K.Kesildi then
      Not_ := TF('COKLU_KESILDI', [COKLU_SATIR_SINIRI]);
    Satir.SubItems.Add(Not_);
    if (K.Durum = cdHata) and (AnaSonuc <> nil) then
    begin
      AnaSonuc.Add(TF('COKLU_HATA_MESAJI', [K.Ad]) + ' ' + K.Cumle);
      if K.Ayrinti <> '' then
        AnaSonuc.Add(T('AYRINTI') + ': ' + K.Ayrinti);
    end;
  end;
  if FSonuc.Tablo <> nil then
  begin
    dsSonuc.DataSet := FSonuc.Tablo;
    FGrid.YeniSonuc;
  end;
  DurumuYaz;
  if AnaSonuc <> nil then
    AnaSonuc.Add(lblOzet.Caption);
end;

end.
