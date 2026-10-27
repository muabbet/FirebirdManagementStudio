{ fProsedurSekme.pas - Sakli prosedur duzenleme sekmesi (Asama 3e-1): ustte "Kaydet" dugmesi, altta SQL editoru.
  Frame sadece arayuzu bilir; yedekleme ve calistirma uProsedur'dedir.

  Bu sekmede tek yol: Kaydet dugmesi ve Ctrl+S (ikisi de Kaydet'i cagirir). F5 bu sekmede bir sey calistirmaz,
  sadece ipucu yazar; boylece "calistir" ve "kaydet" karismaz. Mesajlar ana pencerenin sonuc alanina (AnaSonuc) yazilir. }
unit fProsedurSekme;

interface

uses
  System.SysUtils, System.Classes, Data.DB, Vcl.Controls, Vcl.Forms, Vcl.ExtCtrls, Vcl.StdCtrls,
  FireDAC.Comp.Client,
  uDil, uOnay, uBaglanti, uMetadata, uSorgu, uEditor, uKullanici, uProsedur;

type
  TProsedurSekme = class(TFrame)
    pnlUst: TPanel;
    lblBilgi: TLabel;
    btnKaydet: TButton;
    pnlEditor: TPanel;
    procedure btnKaydetClick(Sender: TObject);
  private
    FEditor: TSqlEditor;
    procedure Yaz(const Metin: string);
    procedure OneriHazirla(Bag: TAcikBaglanti);
    procedure KolonlariGetir(const Tablo: string; Kolonlar: TStrings);
    function OnayMetni(const Metin: string): string;
  public
    BaglantiAd: string;
    ProsedurAdi: string;
    { Mesajlar buraya (ana pencerenin sonuc alani) yazilir; ana pencere atar. }
    AnaSonuc: TStrings;
    { Calistirilan SQL'i mesaj alaninda gostermek icin ana pencere atar. }
    SqlYaz: TSqlGoster;
    { Prosedurun CREATE OR ALTER metnini editore koyar. Hata verirse istisna firlar, cagiran gosterir. }
    procedure Yukle(Bag: TAcikBaglanti; const Ad: string);
    procedure Kaydet;
    procedure F5Ipucu;
    procedure EditoreOdaklan;
    function Baslik: string;
    procedure YazilariYenile;
  end;

implementation

{$R *.dfm}

procedure TProsedurSekme.Yaz(const Metin: string);
begin
  if AnaSonuc <> nil then
    AnaSonuc.Add(Metin);
end;

procedure TProsedurSekme.Yukle(Bag: TAcikBaglanti; const Ad: string);
var
  Metin: string;
begin
  BaglantiAd := Bag.Tanim.Ad;
  ProsedurAdi := Ad;
  Metin := ProsedurDuzenleMetni(Bag, Ad);
  FEditor := TSqlEditor.Create(pnlEditor);
  FEditor.KolonGetirici := KolonlariGetir;
  OneriHazirla(Bag);
  FEditor.MetinYaz(Metin);
  YazilariYenile;
end;

{ Ctrl+Bosluk listesi icin anahtar kelimeleri ve nesne adlarini editore verir (bkz. fSorguSekme). }
procedure TProsedurSekme.OneriHazirla(Bag: TAcikBaglanti);
var
  Adlar, Gecici: TStringList;
begin
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

procedure TProsedurSekme.KolonlariGetir(const Tablo: string; Kolonlar: TStrings);
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

function TProsedurSekme.Baslik: string;
begin
  Result := TF('PRS_SEKME', [ProsedurAdi, BaglantiAd]);
end;

procedure TProsedurSekme.EditoreOdaklan;
begin
  FEditor.OdakVer;
end;

procedure TProsedurSekme.YazilariYenile;
begin
  btnKaydet.Caption := T('PRS_KAYDET');
  DugmeyiYaziyaUydur(btnKaydet);
  lblBilgi.Caption := TF('PRS_BILGI', [ProsedurAdi]);
end;

procedure TProsedurSekme.F5Ipucu;
begin
  Yaz(T('MSG_PRS_F5_IPUCU'));
end;

{ Onay metni: ne olacagi acik yazilir. Metinde birden fazla komut varsa hepsinin calisacagi, tehlikeli
  (DROP, WHERE'siz DELETE/UPDATE) komut varsa ayrica uyari eklenir. }
function TProsedurSekme.OnayMetni(const Metin: string): string;
var
  Komutlar: TArray<string>;
  Komut, Anahtar: string;
  Uyarilar: string;
begin
  Result := TF('ONAY_PRS_KAYDET', [ProsedurAdi]);
  Komutlar := KomutlaraBol(Metin);
  if Length(Komutlar) > 1 then
    Result := Result + sLineBreak + sLineBreak + TF('ONAY_PRS_COK_KOMUT', [Length(Komutlar)]);
  Uyarilar := '';
  for Komut in Komutlar do
  begin
    Anahtar := TehlikeliSorguUyarisi(Komut);
    if Anahtar <> '' then
      Uyarilar := Uyarilar + sLineBreak + '- ' + Copy(Trim(Komut), 1, 60) + ': ' + T(Anahtar);
  end;
  if Uyarilar <> '' then
    Result := Result + sLineBreak + Uyarilar;
end;

{ Kaydet: kural kontrolu, net onay, eski tanim yedegi + calistirma (uProsedur), sonucu mesaj alanina yazma. }
procedure TProsedurSekme.Kaydet;
var
  Bag: TAcikBaglanti;
  Metin, Uyari: string;
  Sonuc: TProsedurSonucu;
begin
  Bag := FbAcikBaglanti(BaglantiAd);
  if Bag = nil then
  begin
    Yaz(TF('ERR_SORGU_BAGLANTI_YOK', [BaglantiAd]));
    Exit;
  end;
  Metin := FEditor.TumMetin;
  Uyari := ProsedurAdiniDogrula(Metin, ProsedurAdi);
  if Uyari <> '' then
  begin
    UyariGoster(Uyari);
    Exit;
  end;
  if not OnayIste(OnayMetni(Metin)) then
  begin
    Yaz(T('MSG_PRS_VAZGECILDI'));
    Exit;
  end;
  Sonuc := ProsedurKaydet(Bag, ProsedurAdi, Metin);
  if Sonuc.Basarili then
  begin
    Yaz(TF('MSG_PRS_KAYDEDILDI', [ProsedurAdi]));
    Yaz(TF('MSG_PRS_YEDEKLENDI', [Sonuc.YedekDosyasi]));
  end
  else
  begin
    Yaz(TF('ERR_PRS_KAYDEDILEMEDI', [ProsedurAdi]) + ' ' + Sonuc.Cumle);
    if Sonuc.Ayrinti <> '' then
      Yaz(T('AYRINTI') + ': ' + Sonuc.Ayrinti);
    if Length(Sonuc.Komutlar) = 0 then
      Yaz(T('MSG_PRS_DOKUNULMADI'))
    else
      Yaz(T('MSG_PRS_GERI_ALINDI'));
    if Sonuc.Satir > 0 then
    begin
      Yaz(TF('MSG_PRS_HATA_SATIRI', [Sonuc.Satir]));
      FEditor.SatiraGit(Sonuc.Satir);
    end;
  end;
  if (Length(Sonuc.Komutlar) > 0) and Assigned(SqlYaz) then
    SqlYaz(Sonuc.Komutlar);
end;

procedure TProsedurSekme.btnKaydetClick(Sender: TObject);
begin
  Kaydet;
end;

end.
