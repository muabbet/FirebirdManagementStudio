{ fTopluGuncelle.pas - "Toplu guncelleme" sekmesi (Asama 4c): solda veritabani listesi (kutucuklu), sagda UPDATE yazilan
  editor, altta Onizle ve Uygula dugmeleri ile her veritabaninin durumu. Sekme yalniz arayuzu bilir; isi uTopluGuncelle yapar.
  Akis: UPDATE yaz, veritabanlarini isaretle, Onizle (F5: veri DEGISMEZ, kac satir degisecegi yazilir), sonra Uygula
  (acik bir onay penceresi sorar). Komut ya da secim onizlemeden sonra degistiyse Uygula once yeniden onizleme ister. }
unit fTopluGuncelle;

interface

uses
  System.SysUtils, System.Classes, Vcl.Controls, Vcl.Forms, Vcl.ExtCtrls, Vcl.StdCtrls, Vcl.ComCtrls, Vcl.CheckLst,
  Vcl.Graphics,
  uDil, uPaket, uOnay, uBaglanti, uEditor, uCokluSorgu, uTopluGuncelle;

type
  TTopluGuncelleSekme = class(TFrame)
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
    pnlDugme: TPanel;
    btnOnizle: TButton;
    btnUygula: TButton;
    lblOzet: TLabel;
    lvDurum: TListView;
    procedure btnHepsiClick(Sender: TObject);
    procedure btnHicbiriClick(Sender: TObject);
    procedure btnOnizleClick(Sender: TObject);
    procedure btnUygulaClick(Sender: TObject);
    procedure lvDurumCustomDrawItem(Sender: TCustomListView; Item: TListItem; State: TCustomDrawState;
      var DefaultDraw: Boolean);
  private
    FEditor: TSqlEditor;
    { Listedeki gercek baglanti adlari (kutucuk yazisi sifre uyarisi eklenmis olabilir). }
    FAdlar: TArray<string>;
    { Son onizlemenin kaydi: Uygula ancak bununla ayni komut ve ayni secimde, hatasiz onizlemeden sonra calisir. }
    FOnizSql: string;
    FOnizAdlar: TArray<string>;
    FOnizKayitlar: TArray<TTopluKayit>;
    FOnizlendi: Boolean;
    procedure ListeyiDoldur;
    function SeciliAdlar: TArray<string>;
    function AyniSecim(const A, B: TArray<string>): Boolean;
    function KomutuAl(out Sql: string): Boolean;
    procedure KayitlariGoster(const Kayitlar: TArray<TTopluKayit>);
    function Toplam(const Kayitlar: TArray<TTopluKayit>): Integer;
    function HataSayisi(const Kayitlar: TArray<TTopluKayit>): Integer;
    procedure SonucuYaz(const Kayitlar: TArray<TTopluKayit>; const Sql, OzetAnahtar: string);
  public
    { Islem ozeti ana pencerenin sonuc alanina yazilir; ana pencere atar. }
    AnaSonuc: TStrings;
    procedure Hazirla;
    { F5: onizler (veri degismez). }
    procedure Onizle;
    procedure YazilariYenile;
  end;

implementation

{$R *.dfm}

procedure TTopluGuncelleSekme.Hazirla;
begin
  FEditor := TSqlEditor.Create(pnlEditor);
  FEditor.AnahtarKelimeleriYukle(PaketKlasoru + '\anahtar_kelimeler.txt', '');
  FEditor.MetinYaz('UPDATE TABLO SET ALAN = DEGER WHERE ');
  YazilariYenile;
  ListeyiDoldur;
end;

procedure TTopluGuncelleSekme.YazilariYenile;
begin
  lblVeritabanlari.Caption := T('COKLU_VERITABANLARI');
  btnHepsi.Caption := T('BTN_HEPSI_SEC');
  btnHicbiri.Caption := T('BTN_HICBIRI_SEC');
  btnOnizle.Caption := T('BTN_ONIZLE');
  btnUygula.Caption := T('BTN_UYGULA');
  DugmeyiYaziyaUydur(btnHepsi);
  DugmeyiYaziyaUydur(btnHicbiri);
  DugmeyiYaziyaUydur(btnOnizle);
  DugmeyiYaziyaUydur(btnUygula);
  lvDurum.Columns[0].Caption := T('COKLU_SUTUN_VERITABANI');
  lvDurum.Columns[1].Caption := T('COKLU_SUTUN_DURUM');
  lvDurum.Columns[2].Caption := T('TOPLU_SUTUN_SATIR');
  lvDurum.Columns[3].Caption := T('COKLU_SUTUN_SURE');
  lvDurum.Columns[4].Caption := T('COKLU_SUTUN_NOT');
  if lvDurum.Items.Count = 0 then
    lblOzet.Caption := T('TOPLU_IPUCU');
end;

{ Kayitli baglantilar listelenir; acik degil ve sifresi kayitli olmayanlar kutucuksuz (kapali) yazilir. Onceki secimler
  korunur. }
procedure TTopluGuncelleSekme.ListeyiDoldur;
var
  Eski: TStringList;
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
      for Kayit in KayitliBaglantilar do
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

function TTopluGuncelleSekme.SeciliAdlar: TArray<string>;
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

function TTopluGuncelleSekme.AyniSecim(const A, B: TArray<string>): Boolean;
var
  i: Integer;
begin
  Result := Length(A) = Length(B);
  if Result then
    for i := 0 to High(A) do
      if A[i] <> B[i] then
        Exit(False);
end;

{ Editordeki komutu alir ve denetler; sorun varsa kullaniciya soyler ve False doner. }
function TTopluGuncelleSekme.KomutuAl(out Sql: string): Boolean;
var
  Uyari: string;
begin
  Sql := Trim(FEditor.CalistirilacakMetin);
  Uyari := TopluKontrol(Sql);
  Result := Uyari = '';
  if not Result then
    UyariGoster(Uyari);
end;

procedure TTopluGuncelleSekme.btnHepsiClick(Sender: TObject);
var
  i: Integer;
begin
  for i := 0 to clbVeritabani.Items.Count - 1 do
    if clbVeritabani.ItemEnabled[i] then
      clbVeritabani.Checked[i] := True;
end;

procedure TTopluGuncelleSekme.btnHicbiriClick(Sender: TObject);
var
  i: Integer;
begin
  for i := 0 to clbVeritabani.Items.Count - 1 do
    clbVeritabani.Checked[i] := False;
end;

{ Hata satiri kirmizi, atlanan gri. Satirin Data'si TTopluDurum sirasidir. }
procedure TTopluGuncelleSekme.lvDurumCustomDrawItem(Sender: TCustomListView; Item: TListItem; State: TCustomDrawState;
  var DefaultDraw: Boolean);
begin
  case TTopluDurum(NativeInt(Item.Data)) of
    tdHata: Sender.Canvas.Font.Color := clRed;
    tdAtlandi: Sender.Canvas.Font.Color := clGrayText;
  end;
end;

function TTopluGuncelleSekme.Toplam(const Kayitlar: TArray<TTopluKayit>): Integer;
var
  K: TTopluKayit;
begin
  Result := 0;
  for K in Kayitlar do
    if K.Durum = tdTamam then
      Inc(Result, K.Satir);
end;

function TTopluGuncelleSekme.HataSayisi(const Kayitlar: TArray<TTopluKayit>): Integer;
var
  K: TTopluKayit;
begin
  Result := 0;
  for K in Kayitlar do
    if K.Durum <> tdTamam then
      Inc(Result);
end;

procedure TTopluGuncelleSekme.KayitlariGoster(const Kayitlar: TArray<TTopluKayit>);
var
  K: TTopluKayit;
  Satir: TListItem;
begin
  lvDurum.Items.Clear;
  for K in Kayitlar do
  begin
    Satir := lvDurum.Items.Add;
    Satir.Data := Pointer(NativeInt(Ord(K.Durum)));
    Satir.Caption := K.Ad;
    case K.Durum of
      tdTamam: Satir.SubItems.Add(T('COKLU_DURUM_TAMAM'));
      tdHata: Satir.SubItems.Add(T('COKLU_DURUM_HATA'));
    else
      Satir.SubItems.Add(T('COKLU_DURUM_ATLANDI'));
    end;
    Satir.SubItems.Add(IntToStr(K.Satir));
    Satir.SubItems.Add(IntToStr(K.Sure));
    Satir.SubItems.Add(K.Cumle);
  end;
end;

{ Ozet satirini ve ana pencerenin sonuc alanini yazar: calisan komut (SQL karsiligi), her veritabani, hatalar. }
procedure TTopluGuncelleSekme.SonucuYaz(const Kayitlar: TArray<TTopluKayit>; const Sql, OzetAnahtar: string);
var
  K: TTopluKayit;
begin
  lblOzet.Caption := TF(OzetAnahtar, [Length(Kayitlar) - HataSayisi(Kayitlar), HataSayisi(Kayitlar), Toplam(Kayitlar)]);
  if AnaSonuc = nil then
    Exit;
  AnaSonuc.Add(T('TOPLU_SQL') + ' ' + Sql);
  for K in Kayitlar do
    if K.Durum = tdHata then
    begin
      AnaSonuc.Add(TF('COKLU_HATA_MESAJI', [K.Ad]) + ' ' + K.Cumle);
      if K.Ayrinti <> '' then
        AnaSonuc.Add(T('AYRINTI') + ': ' + K.Ayrinti);
    end;
  AnaSonuc.Add(lblOzet.Caption);
end;

procedure TTopluGuncelleSekme.Onizle;
var
  Sql: string;
  Adlar: TArray<string>;
  Kayitlar: TArray<TTopluKayit>;
begin
  if not KomutuAl(Sql) then
    Exit;
  ListeyiDoldur;
  Adlar := SeciliAdlar;
  if Length(Adlar) = 0 then
  begin
    UyariGoster(T('COKLU_SECIM_YOK'));
    Exit;
  end;
  Screen.Cursor := crHourGlass;
  try
    Kayitlar := TopluOnizle(Adlar, Sql,
      procedure(Ad: string)
      begin
        lblOzet.Caption := TF('COKLU_ILERLEME', [Ad]);
        lblOzet.Update;
      end);
  finally
    Screen.Cursor := crDefault;
  end;
  FOnizSql := Sql;
  FOnizAdlar := Adlar;
  FOnizKayitlar := Kayitlar;
  FOnizlendi := True;
  KayitlariGoster(Kayitlar);
  SonucuYaz(Kayitlar, Sql, 'TOPLU_ONIZLEME_OZET');
end;

procedure TTopluGuncelleSekme.btnOnizleClick(Sender: TObject);
begin
  Onizle;
end;

{ Uygula: once onizleme yapilmis olmali (ayni komut, ayni secim, hatasiz); sonra acik onay penceresi sorar. }
procedure TTopluGuncelleSekme.btnUygulaClick(Sender: TObject);
var
  Sql, Soru, Satirlar: string;
  Adlar: TArray<string>;
  Kayitlar: TArray<TTopluKayit>;
  K: TTopluKayit;
begin
  if not KomutuAl(Sql) then
    Exit;
  Adlar := SeciliAdlar;
  if (not FOnizlendi) or (Sql <> FOnizSql) or (not AyniSecim(Adlar, FOnizAdlar)) then
  begin
    UyariGoster(T('TOPLU_ONCE_ONIZLE'));
    Exit;
  end;
  if HataSayisi(FOnizKayitlar) > 0 then
  begin
    UyariGoster(T('TOPLU_ONIZLEME_HATALI'));
    Exit;
  end;
  Satirlar := '';
  for K in FOnizKayitlar do
    Satirlar := Satirlar + K.Ad + ': ' + IntToStr(K.Satir) + sLineBreak;
  Soru := TF('TOPLU_ONAY', [Sql, Satirlar, Length(FOnizKayitlar), Toplam(FOnizKayitlar)]);
  if not TopluWhereVar(Sql) then
    Soru := Soru + sLineBreak + sLineBreak + T('TOPLU_ONAY_WHERE_YOK');
  if not OnayIste(Soru) then
    Exit;
  Screen.Cursor := crHourGlass;
  try
    Kayitlar := TopluUygula(Adlar, Sql,
      procedure(Ad: string)
      begin
        lblOzet.Caption := TF('COKLU_ILERLEME', [Ad]);
        lblOzet.Update;
      end);
  finally
    Screen.Cursor := crDefault;
  end;
  { Uygulandi: ayni komutla yanlislikla ikinci kez calismasin diye yeniden onizleme gerekir. }
  FOnizlendi := False;
  KayitlariGoster(Kayitlar);
  SonucuYaz(Kayitlar, Sql, 'TOPLU_UYGULANDI_OZET');
end;

end.
