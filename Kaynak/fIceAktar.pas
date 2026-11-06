{ fIceAktar.pas - "Ice aktar" (CSV -> tablo) penceresi (Asama 7b).
  Form sadece arayuzu bilir; is uIceAktar'dadir. Akis: dosya sec -> bicim (ayrac, kodlama, ondalik) dosyadan tahmin edilir
  -> onizleme ve kolon esleme -> Ice aktar (net onay, tek islem). Uzun surerken ilerleme yazilir, Iptal ile durdurulur
  (iptalde hicbir satir eklenmez). }
unit fIceAktar;

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.Math, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls,
  Vcl.Grids, Vcl.Dialogs,
  uDil, uOnay, uBaglanti, uKullanici, uAktar, uIceAktar;

type
  TfrmIceAktar = class(TForm)
    lblDosya: TLabel;
    edtDosya: TEdit;
    btnSec: TButton;
    lblAyrac: TLabel;
    cmbAyrac: TComboBox;
    lblKodlama: TLabel;
    cmbKodlama: TComboBox;
    lblOndalik: TLabel;
    cmbOndalik: TComboBox;
    chkBaslik: TCheckBox;
    lblOnizleme: TLabel;
    gridOnizleme: TStringGrid;
    lblEsleme: TLabel;
    sbxEsleme: TScrollBox;
    lblDurum: TLabel;
    pnlAlt: TPanel;
    btnKapat: TButton;
    btnBaslat: TButton;
    dlgAc: TOpenDialog;
    procedure btnSecClick(Sender: TObject);
    procedure SecenekDegisti(Sender: TObject);
    procedure btnBaslatClick(Sender: TObject);
    procedure btnKapatClick(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
  private
    FBag: TAcikBaglanti;
    FTablo: string;
    FSqlYaz: TSqlGoster;
    FSonuc: TStrings;
    FKolonlar: TArray<TIceKolon>;
    FSecenek: TIceSecenek;
    FOnizleme: TCsvOnizleme;
    { Tablo kolonu basina bir kutu: secilen CSV kolonu (0. oge "bos birak"). }
    FKutular: TArray<TComboBox>;
    FYukleniyor: Boolean;
    FCalisiyor: Boolean;
    FIptalIstendi: Boolean;
    FEklendi: Boolean;
    FSonGuncelleme: Cardinal;
    procedure YazilariYaz;
    procedure CalisiyorAyarla(Calisiyor: Boolean);
    procedure Ilerle(SatirSayisi: Int64; var Iptal: Boolean);
    procedure SeceneklerdenOku;
    procedure SecenekleriYaz;
    procedure DosyayiOku;
    procedure OnizlemeyiDoldur;
    procedure EslemeKutulariniKur;
    function SutunAdi(No: Integer): string;
  end;

{ Pencereyi gosterir. Sonuc: ana pencerenin sonuc alani (ozet buraya yazilir); SqlYaz: calisan INSERT'in SQL karsiligi.
  Satir eklendiyse True doner (cagiran tablo verisini yeniden okur). }
function IceAktarPenceresiniGoster(Bag: TAcikBaglanti; const Tablo: string; SqlYaz: TSqlGoster; Sonuc: TStrings): Boolean;

implementation

{$R *.dfm}

const
  ONIZLEME_SATIRI = 20;
  AYRACLAR: array[0..3] of Char = (';', ',', #9, '|');

function IceAktarPenceresiniGoster(Bag: TAcikBaglanti; const Tablo: string; SqlYaz: TSqlGoster; Sonuc: TStrings): Boolean;
var
  Pencere: TfrmIceAktar;
begin
  Result := False;
  Pencere := TfrmIceAktar.Create(Application);
  try
    Pencere.FBag := Bag;
    Pencere.FTablo := Tablo;
    Pencere.FSqlYaz := SqlYaz;
    Pencere.FSonuc := Sonuc;
    try
      Pencere.FKolonlar := IceAktarKolonlari(Bag, Tablo);
    except
      on E: Exception do
      begin
        UyariGoster(HataMetniniCevir(E) + sLineBreak + sLineBreak + T('AYRINTI') + ': ' + E.Message);
        Exit;
      end;
    end;
    Pencere.YazilariYaz;
    Pencere.ShowModal;
    Result := Pencere.FEklendi;
  finally
    Pencere.Free;
  end;
end;

procedure TfrmIceAktar.YazilariYaz;
begin
  Caption := T('ICE_BASLIK') + ' - ' + FTablo;
  lblDosya.Caption := T('ICE_DOSYA');
  btnSec.Caption := T('ICE_SEC');
  lblAyrac.Caption := T('ICE_AYRAC');
  lblKodlama.Caption := T('ICE_KODLAMA');
  lblOndalik.Caption := T('ICE_ONDALIK');
  chkBaslik.Caption := T('ICE_BASLIK_VAR');
  lblEsleme.Caption := T('ICE_ESLEME');
  lblOnizleme.Caption := TF('ICE_ONIZLEME', [ONIZLEME_SATIRI]);
  btnBaslat.Caption := T('ICE_BASLAT');
  btnKapat.Caption := T('BTN_KAPAT');
  dlgAc.Filter := T('ICE_FILTRE');
  cmbAyrac.Items.Clear;
  cmbAyrac.Items.Add(';');
  cmbAyrac.Items.Add(',');
  cmbAyrac.Items.Add(T('ICE_AYRAC_SEKME'));
  cmbAyrac.Items.Add('|');
  cmbKodlama.Items.Clear;
  cmbKodlama.Items.Add(T('ICE_KODLAMA_UTF8'));
  cmbKodlama.Items.Add(T('ICE_KODLAMA_ANSI'));
  cmbOndalik.Items.Clear;
  cmbOndalik.Items.Add(',');
  cmbOndalik.Items.Add('.');
  FSecenek.Ayrac := WindowsCsvSecenekleri.Ayrac;
  FSecenek.Ondalik := WindowsCsvSecenekleri.Ondalik;
  FSecenek.Kodlama := ikUtf8;
  FSecenek.BaslikVar := True;
  SecenekleriYaz;
  DugmeyiYaziyaUydur(btnSec);
  DugmeyiYaziyaUydur(btnBaslat);
  DugmeyiYaziyaUydur(btnKapat);
  btnBaslat.Enabled := False;
end;

{ Kutulari FSecenek'e gore ayarlar (degisiklik olayi tetiklenmesin diye FYukleniyor). }
procedure TfrmIceAktar.SecenekleriYaz;
var
  i: Integer;
begin
  FYukleniyor := True;
  try
    cmbAyrac.ItemIndex := 0;
    for i := 0 to High(AYRACLAR) do
      if AYRACLAR[i] = FSecenek.Ayrac then
        cmbAyrac.ItemIndex := i;
    cmbKodlama.ItemIndex := Ord(FSecenek.Kodlama);
    if FSecenek.Ondalik = '.' then
      cmbOndalik.ItemIndex := 1
    else
      cmbOndalik.ItemIndex := 0;
    chkBaslik.Checked := FSecenek.BaslikVar;
  finally
    FYukleniyor := False;
  end;
end;

procedure TfrmIceAktar.SeceneklerdenOku;
begin
  if cmbAyrac.ItemIndex >= 0 then
    FSecenek.Ayrac := AYRACLAR[cmbAyrac.ItemIndex];
  FSecenek.Kodlama := TIceKodlama(Max(cmbKodlama.ItemIndex, 0));
  if cmbOndalik.ItemIndex = 1 then
    FSecenek.Ondalik := '.'
  else
    FSecenek.Ondalik := ',';
  FSecenek.BaslikVar := chkBaslik.Checked;
end;

{ Dosya sec: bicim tahmin edilir, onizleme ve esleme kurulur. }
procedure TfrmIceAktar.btnSecClick(Sender: TObject);
begin
  if not dlgAc.Execute then
    Exit;
  edtDosya.Text := dlgAc.FileName;
  try
    FSecenek := IceAktarVarsayilan(dlgAc.FileName);
  except
    on E: Exception do
    begin
      UyariGoster(T('ICE_DOSYA_OKUNAMADI') + sLineBreak + sLineBreak + T('AYRINTI') + ': ' + E.Message);
      Exit;
    end;
  end;
  SecenekleriYaz;
  DosyayiOku;
end;

{ Ayrac, kodlama, ondalik ya da baslik kutusu degisti: dosya yeni ayarlarla yeniden okunur ve esleme bastan kurulur. }
procedure TfrmIceAktar.SecenekDegisti(Sender: TObject);
begin
  if FYukleniyor or (Trim(edtDosya.Text) = '') then
    Exit;
  SeceneklerdenOku;
  DosyayiOku;
end;

procedure TfrmIceAktar.DosyayiOku;
begin
  try
    FOnizleme := CsvOnizle(Trim(edtDosya.Text), FSecenek, ONIZLEME_SATIRI);
  except
    on E: Exception do
    begin
      UyariGoster(T('ICE_DOSYA_OKUNAMADI') + sLineBreak + sLineBreak + T('AYRINTI') + ': ' + E.Message);
      Exit;
    end;
  end;
  OnizlemeyiDoldur;
  EslemeKutulariniKur;
  btnBaslat.Enabled := True;
end;

{ Baslik yoksa kolonlar "1, 2, 3..." diye numaralanir. }
function TfrmIceAktar.SutunAdi(No: Integer): string;
begin
  if FSecenek.BaslikVar and (No < Length(FOnizleme.Baslik)) and (Trim(FOnizleme.Baslik[No]) <> '') then
    Result := IntToStr(No + 1) + ': ' + Trim(FOnizleme.Baslik[No])
  else
    Result := IntToStr(No + 1);
end;

procedure TfrmIceAktar.OnizlemeyiDoldur;
var
  Sutun, i, j: Integer;
begin
  Sutun := Length(FOnizleme.Baslik);
  for i := 0 to High(FOnizleme.Satirlar) do
    Sutun := Max(Sutun, Length(FOnizleme.Satirlar[i]));
  Sutun := Max(Sutun, 1);
  gridOnizleme.ColCount := Sutun;
  gridOnizleme.RowCount := Length(FOnizleme.Satirlar) + 1;
  gridOnizleme.FixedRows := 1;
  for j := 0 to Sutun - 1 do
  begin
    gridOnizleme.Cells[j, 0] := SutunAdi(j);
    gridOnizleme.ColWidths[j] := 110;
  end;
  for i := 0 to High(FOnizleme.Satirlar) do
    for j := 0 to Sutun - 1 do
      if j < Length(FOnizleme.Satirlar[i]) then
        gridOnizleme.Cells[j, i + 1] := StringReplace(StringReplace(FOnizleme.Satirlar[i][j], #13, ' ', [rfReplaceAll]),
          #10, ' ', [rfReplaceAll])
      else
        gridOnizleme.Cells[j, i + 1] := '';
end;

{ Her tablo kolonu icin: ad + CSV kolonu secim kutusu. Otomatik esleme (ada gore, yoksa sirayla) onceden secilir. }
procedure TfrmIceAktar.EslemeKutulariniKur;
var
  Esleme: TArray<Integer>;
  i, j, Sutun, Ust: Integer;
  Etiket: TLabel;
  Kutu: TComboBox;
begin
  while sbxEsleme.ControlCount > 0 do
    sbxEsleme.Controls[0].Free;
  Sutun := gridOnizleme.ColCount;
  Esleme := OtomatikEsleme(FKolonlar, FOnizleme, FSecenek.BaslikVar);
  SetLength(FKutular, Length(FKolonlar));
  Ust := 4;
  for i := 0 to High(FKolonlar) do
  begin
    Etiket := TLabel.Create(sbxEsleme);
    Etiket.Parent := sbxEsleme;
    Etiket.SetBounds(8, Ust + 4, 250, 17);
    Etiket.AutoSize := False;
    Etiket.Caption := FKolonlar[i].Ad;
    Kutu := TComboBox.Create(sbxEsleme);
    Kutu.Parent := sbxEsleme;
    Kutu.Style := csDropDownList;
    Kutu.SetBounds(270, Ust, 390, 25);
    Kutu.Items.Add(T('ICE_BOS_BIRAK'));
    for j := 0 to Sutun - 1 do
      Kutu.Items.Add(SutunAdi(j));
    Kutu.ItemIndex := Esleme[i] + 1;
    FKutular[i] := Kutu;
    Inc(Ust, 30);
  end;
end;

procedure TfrmIceAktar.CalisiyorAyarla(Calisiyor: Boolean);
begin
  FCalisiyor := Calisiyor;
  FIptalIstendi := False;
  btnSec.Enabled := not Calisiyor;
  btnBaslat.Enabled := not Calisiyor;
  sbxEsleme.Enabled := not Calisiyor;
  cmbAyrac.Enabled := not Calisiyor;
  cmbKodlama.Enabled := not Calisiyor;
  cmbOndalik.Enabled := not Calisiyor;
  chkBaslik.Enabled := not Calisiyor;
  if Calisiyor then
    btnKapat.Caption := T('BTN_IPTAL')
  else
    btnKapat.Caption := T('BTN_KAPAT');
  DugmeyiYaziyaUydur(btnKapat);
end;

{ Aktarma sirasinda cagrilir: durum yazisini gunceller, pencerenin donmamasi icin mesajlari isler, iptali bildirir. }
procedure TfrmIceAktar.Ilerle(SatirSayisi: Int64; var Iptal: Boolean);
begin
  if GetTickCount - FSonGuncelleme > 80 then
  begin
    FSonGuncelleme := GetTickCount;
    lblDurum.Caption := TF('ICE_CALISIYOR', [SatirSayisi]);
    Application.ProcessMessages;
  end;
  Iptal := FIptalIstendi;
end;

procedure TfrmIceAktar.btnKapatClick(Sender: TObject);
begin
  if FCalisiyor then
    FIptalIstendi := True
  else
    ModalResult := mrCancel;
end;

procedure TfrmIceAktar.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  if FCalisiyor then
  begin
    FIptalIstendi := True;
    CanClose := False;
  end;
end;

{ Ice aktar: esleme kontrol edilir, satir sayisi ve calisacak komutla NET ONAY istenir, sonra tek islemde eklenir.
  Hata olursa hicbir satir eklenmez ve pencere acik kalir (ayar duzeltilip yeniden denenebilir). }
procedure TfrmIceAktar.btnBaslatClick(Sender: TObject);
var
  Dosya, Komut: string;
  Esleme: TArray<Integer>;
  Satir: Int64;
  i, Eslenen: Integer;
  Sonuc: TIceSonuc;
begin
  Dosya := Trim(edtDosya.Text);
  if (Dosya = '') or not FileExists(Dosya) then
  begin
    UyariGoster(T('ERR_AKTAR_DOSYA_BOS'));
    Exit;
  end;
  SeceneklerdenOku;
  SetLength(Esleme, Length(FKolonlar));
  Eslenen := 0;
  for i := 0 to High(FKolonlar) do
  begin
    Esleme[i] := FKutular[i].ItemIndex - 1;
    if Esleme[i] >= 0 then
      Inc(Eslenen);
  end;
  if Eslenen = 0 then
  begin
    UyariGoster(T('ICE_ESLENMEDI'));
    Exit;
  end;
  try
    Satir := CsvVeriSatiriSayisi(Dosya, FSecenek);
  except
    on E: Exception do
    begin
      UyariGoster(T('ICE_DOSYA_OKUNAMADI') + sLineBreak + sLineBreak + T('AYRINTI') + ': ' + E.Message);
      Exit;
    end;
  end;
  if Satir = 0 then
  begin
    UyariGoster(T('ICE_BOS_DOSYA'));
    Exit;
  end;
  Komut := IceAktarKomutu(FTablo, FKolonlar, Esleme, False);
  if not OnayIste(TF('ICE_ONAY', [FTablo, Satir, Eslenen, Komut])) then
    Exit;
  CalisiyorAyarla(True);
  try
    Sonuc := IceAktar(FBag, FTablo, Dosya, FSecenek, FKolonlar, Esleme, Ilerle);
  finally
    CalisiyorAyarla(False);
  end;
  lblDurum.Caption := '';
  if Sonuc.Basarili then
  begin
    FSonuc.Add(TF('MSG_ICE_TAMAM', [FTablo, Sonuc.Eklenen]));
    if Assigned(FSqlYaz) then
      FSqlYaz([Komut + ';']);
    FEklendi := True;
    ModalResult := mrOk;
  end
  else if Sonuc.Iptal then
    FSonuc.Add(T('MSG_ICE_IPTAL'))
  else
  begin
    FSonuc.Add(TF('ERR_ICE_UYGULANAMADI', [FTablo]) + ' ' + Sonuc.Cumle);
    if Sonuc.Ayrinti <> '' then
      FSonuc.Add(T('AYRINTI') + ': ' + Sonuc.Ayrinti);
    if Assigned(FSqlYaz) then
      FSqlYaz([Komut + ';']);
    UyariGoster(TF('ERR_ICE_UYGULANAMADI', [FTablo]) + sLineBreak + sLineBreak + Sonuc.Cumle);
  end;
end;

end.
