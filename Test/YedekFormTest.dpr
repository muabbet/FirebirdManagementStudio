program YedekFormTest;

{ Asama 3c: fYedek penceresini KOD ile surer (gercek OnClick olaylari, gercek ShowModal dongusu, gercek gbak).
  Fare/klavye ile elle deneme DEGILDIR; pencerenin acildigini, olaylarin bagli oldugunu, iki modun, canli ciktinin,
  Iptal'in, Almanca yazilarin sigdigini dener. Gomulu Firebird, gecici veritabani, dosyalar _arsiv'e tasinir.
  Cikis kodu: hata sayisi. }

{$APPTYPE GUI}

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.IOUtils, System.StrUtils,
  Vcl.Forms, Vcl.Controls, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Dialogs,
  FireDAC.Comp.Client, FireDAC.Phys.FB,
  uDil, uOnay, uBaglanti, uSorgu, uYedek, fYedek;

type
  TSurucu = class
    Adim: Integer;
    Sayac: TTimer;
    Kapatici: TTimer;
    IptalZamani: TTimer;
    procedure AdimCalistir(Sender: TObject);
    procedure DiyalogKapat(Sender: TObject);
    procedure IptalEt(Sender: TObject);
  end;

var
  Cikti: TStringList;
  Hatalar, Kontroller: Integer;
  Klasor, KucukYol, BuyukYol, Fbk, YeniYol, Fbk2: string;
  Kucuk, Buyuk: TBaglantiTanimi;
  Surucu: TSurucu;
  GorulenDiyaloglar: TStringList;
  Uretilen: TStringList;

procedure Kontrol(const Ad: string; Sonuc: Boolean);
begin
  Inc(Kontroller);
  if Sonuc then
    Cikti.Add('OK    ' + Ad)
  else
  begin
    Cikti.Add('HATA  ' + Ad);
    Inc(Hatalar);
  end;
end;

function Formu: TfrmYedek;
begin
  Result := nil;
  if Screen.ActiveForm is TfrmYedek then
    Result := TfrmYedek(Screen.ActiveForm);
end;

procedure Olustur(const Tanim: TBaglantiTanimi);
var
  Surucu1: TFDPhysFBDriverLink;
  Baglanti: TFDConnection;
begin
  Surucu1 := TFDPhysFBDriverLink.Create(nil);
  Baglanti := TFDConnection.Create(nil);
  try
    Surucu1.VendorLib := ExtractFilePath(ParamStr(0)) + 'istemci\fbclient.dll';
    Baglanti.DriverName := 'FB';
    Baglanti.LoginPrompt := False;
    Baglanti.Params.Values['Database'] := Tanim.VeritabaniYolu;
    Baglanti.Params.Values['User_Name'] := Tanim.Kullanici;
    Baglanti.Params.Values['Password'] := Tanim.Sifre;
    Baglanti.Params.Values['OpenMode'] := 'Create';
    Baglanti.Params.Values['CharacterSet'] := Tanim.KarakterSeti;
    Baglanti.Open;
    Baglanti.ExecSQL('CREATE TABLE T (ID INTEGER NOT NULL PRIMARY KEY, AD VARCHAR(50))');
    Baglanti.ExecSQL('INSERT INTO T VALUES (1, ''bir'')');
    Baglanti.Close;
  finally
    Baglanti.Free;
    Surucu1.Free;
  end;
end;

procedure BuyukDoldur(const Tanim: TBaglantiTanimi);
var
  Bag: TAcikBaglanti;
begin
  Bag := FbBaglan(Tanim);
  try
    SorguCalistir(Bag, 'CREATE TABLE T_BUYUK (ID INTEGER NOT NULL PRIMARY KEY, AD VARCHAR(50), A VARCHAR(200))').Free;
    SorguCalistir(Bag, 'EXECUTE BLOCK AS DECLARE VARIABLE I INTEGER; BEGIN I = 1; WHILE (I <= 1000000) DO BEGIN ' +
      'INSERT INTO T_BUYUK VALUES (:I, ''Kayit '' || :I, LPAD(:I, 150, ''x'')); I = I + 1; END END').Free;
  finally
    FbBaglantiyiKes(Bag);
  end;
end;

{ Her 100 ms'de: acik bir ileti/onay penceresi varsa basligini not eder ve kapatir (Evet/Tamam). }
procedure TSurucu.DiyalogKapat(Sender: TObject);
var
  F: TForm;
begin
  F := Screen.ActiveForm;
  if (F <> nil) and not (F is TfrmYedek) and (F.ClassName <> 'TfrmYedek') and (F.Visible) then
  begin
    GorulenDiyaloglar.Add(F.Caption);
    if F.ModalResult = 0 then
      F.ModalResult := mrYes;
  end;
end;

procedure TSurucu.IptalEt(Sender: TObject);
begin
  IptalZamani.Enabled := False;
  if Formu <> nil then
    Formu.btnKapat.Click;
end;

function Sigiyor(Etiket: TLabel): Boolean;
begin
  Etiket.Canvas.Font.Assign(Etiket.Font);
  Result := Etiket.Canvas.TextWidth(Etiket.Caption) <= Etiket.Width;
end;

function DugmeSigiyor(D: TButton): Boolean;
var
  Tuval: TControlCanvas;
begin
  Tuval := TControlCanvas.Create;
  try
    Tuval.Control := D;
    Tuval.Font.Assign(D.Font);
    Result := Tuval.TextWidth(D.Caption) + 8 <= D.Width;
  finally
    Tuval.Free;
  end;
end;

procedure TSurucu.AdimCalistir(Sender: TObject);
var
  F: TfrmYedek;
  Boyut: Int64;
begin
  Sayac.Enabled := False;
  F := Formu;
  if F = nil then
  begin
    Sayac.Enabled := True;
    Exit;
  end;
  Inc(Adim);
  case Adim of
    1:
      begin
        Kontrol('acilis: pencere acildi, baslik dolu (' + F.Caption + ')', F.Caption <> '');
        Kontrol('acilis: iki islem secenegi var (' + F.rgIslem.Items.CommaText + ')',
          (F.rgIslem.Items.Count = 2) and (F.rgIslem.ItemIndex = 0));
        Kontrol('yedek modu: kaynak salt okunur ve baglanti metnini gosteriyor (' + F.edtKaynak.Text + ')',
          F.edtKaynak.ReadOnly and (Pos(KucukYol, F.edtKaynak.Text) > 0));
        Kontrol('yedek modu: varsayilan hedef .fbk ve tarihli (' + ExtractFileName(F.edtHedef.Text) + ')',
          EndsText('.fbk', F.edtHedef.Text) and (Pos('_', ExtractFileName(F.edtHedef.Text)) > 0));
        Kontrol('yedek modu: kaynak "Sec..." gizli, hedef "Sec..." gorunur',
          (not F.btnKaynakSec.Visible) and F.btnHedefSec.Visible);
        Kontrol('yedek modu: tum olay yoneticileri bagli (OnClick/OnCloseQuery dolu)',
          Assigned(F.btnBaslat.OnClick) and Assigned(F.btnKapat.OnClick) and Assigned(F.btnKaynakSec.OnClick) and
          Assigned(F.btnHedefSec.OnClick) and Assigned(F.rgIslem.OnClick) and Assigned(F.OnCloseQuery));
        { 1) yedek al }
        F.edtHedef.Text := Fbk;
        F.btnBaslat.Click;
        Kontrol('yedek: canli cikti kutusu doldu (' + IntToStr(F.memCikti.Lines.Count) + ' satir)', F.memCikti.Lines.Count > 10);
        Kontrol('yedek: .fbk olustu (' + IntToStr(TFile.GetSize(Fbk)) + ' bayt)', TFile.Exists(Fbk) and (TFile.GetSize(Fbk) > 1000));
        Kontrol('yedek: durum yazisi ozeti gosteriyor (' + StringReplace(F.lblDurum.Caption, #13#10, ' / ', [rfReplaceAll]) + ')',
          Pos(Fbk, F.lblDurum.Caption) > 0);
        Kontrol('yedek: Ayrinti blogu kutuda, sifresiz komut ve cikis kodu 0',
          (Pos('gbak', F.memCikti.Text) > 0) and (Pos(T('AYRINTI'), F.memCikti.Text) > 0) and (Pos(': 0', F.memCikti.Text) > 0));
        Kontrol('yedek: bitince Baslat tekrar etkin, Kapat yazisi "Kapat"',
          F.btnBaslat.Enabled and (F.btnKapat.Caption = T('BTN_KAPAT')));
        { 2) var olan yedek dosyasi: onay penceresi (otomatik Evet) }
        GorulenDiyaloglar.Clear;
        F.btnBaslat.Click;
        Kontrol('yedek ustune yazma: onay penceresi gosterildi (' + GorulenDiyaloglar.CommaText + ')',
          (GorulenDiyaloglar.Count >= 1) and (GorulenDiyaloglar[0] = T('ONAY_BASLIK')));
        Kontrol('yedek ustune yazma: Evet denince yedek yenilendi, .yarim kalmadi', TFile.Exists(Fbk) and not TFile.Exists(Fbk + '.yarim'));
        Uretilen.Add(Fbk);
      end;
    2:
      begin
        { geri yukle modu }
        F.rgIslem.ItemIndex := 1;
        F.rgIslem.OnClick(F.rgIslem);
        Kontrol('geri yukle modu: etiketler degisti (' + F.lblKaynak.Caption + ' / ' + F.lblHedef.Caption + ')',
          (F.lblKaynak.Caption = T('YEDEK_KAYNAK_FBK')) and (F.lblHedef.Caption = T('YEDEK_HEDEF_VT')));
        Kontrol('geri yukle modu: kaynak duzenlenebilir, hedef bos, kaynak "Sec..." gorunur',
          (not F.edtKaynak.ReadOnly) and (F.edtHedef.Text = '') and F.btnKaynakSec.Visible);
        { bos alanlarla Baslat: uyari penceresi, gbak calismaz }
        GorulenDiyaloglar.Clear;
        F.btnBaslat.Click;
        Kontrol('geri yukle: bos alanla uyari penceresi cikti, islem baslamadi',
          (GorulenDiyaloglar.Count >= 1) and (F.memCikti.Lines.Count = 0));
        F.edtKaynak.Text := Fbk;
        F.edtHedef.Text := YeniYol;
        F.btnBaslat.Click;
        Kontrol('geri yukle: yeni veritabani dosyasi olustu (' + IntToStr(TFile.GetSize(YeniYol)) + ' bayt)',
          TFile.Exists(YeniYol) and (TFile.GetSize(YeniYol) > 1000));
        Kontrol('geri yukle: ozet durum yazisinda', Pos(YeniYol, F.lblDurum.Caption) > 0);
        Uretilen.Add(YeniYol);
        { ayni hedefe tekrar: hata cumlesi (var olan veritabani uzerine yazilmaz) }
        Boyut := TFile.GetSize(YeniYol);
        GorulenDiyaloglar.Clear;
        F.btnBaslat.Click;
        Kontrol('geri yukle: ayni hedefe tekrar -> uyari penceresi, anlasilir cumle durum yazisinda (' + F.lblDurum.Caption + ')',
          (GorulenDiyaloglar.Count >= 1) and (Pos(T('ERR_YEDEK_HEDEF_VAR'), F.lblDurum.Caption) > 0));
        Kontrol('geri yukle: var olan veritabani dosyasinin boyutu degismedi', TFile.GetSize(YeniYol) = Boyut);
      end;
    3:
      begin
        { Almanca yazilarin sigmasi }
        DilYukle('de');
        F.rgIslem.ItemIndex := 0;
        F.rgIslem.Items.Clear;
        F.rgIslem.Items.Add(T('YEDEK_ISLEM_YEDEK'));
        F.rgIslem.Items.Add(T('YEDEK_ISLEM_GERI'));
        F.btnBaslat.Caption := T('YEDEK_BASLAT');
        F.btnKapat.Caption := T('BTN_KAPAT');
        F.btnKaynakSec.Caption := T('YEDEK_SEC');
        F.btnHedefSec.Caption := T('YEDEK_SEC');
        DugmeyiYaziyaUydur(F.btnBaslat);
        DugmeyiYaziyaUydur(F.btnKapat);
        DugmeyiYaziyaUydur(F.btnKaynakSec);
        DugmeyiYaziyaUydur(F.btnHedefSec);
        F.rgIslemClick(F.rgIslem);
        Kontrol('Almanca: dugme yazilari sigiyor (' + F.btnBaslat.Caption + ', ' + F.btnKapat.Caption + ', ' + F.btnHedefSec.Caption + ')',
          DugmeSigiyor(F.btnBaslat) and DugmeSigiyor(F.btnKapat) and DugmeSigiyor(F.btnHedefSec) and DugmeSigiyor(F.btnKaynakSec));
        Kontrol('Almanca: yedek modu etiketleri sigiyor (' + F.lblKaynak.Caption + ' | ' + F.lblHedef.Caption + ')',
          Sigiyor(F.lblKaynak) and Sigiyor(F.lblHedef));
        F.rgIslem.ItemIndex := 1;
        F.rgIslemClick(F.rgIslem);
        Kontrol('Almanca: geri yukle modu etiketleri sigiyor (' + F.lblKaynak.Caption + ' | ' + F.lblHedef.Caption + ')',
          Sigiyor(F.lblKaynak) and Sigiyor(F.lblHedef));
        DilYukle('tr');
        F.ModalResult := mrCancel;
      end;
    4:
      begin
        { Iptal: buyuk veritabaninin yedegi, 800 ms sonra Kapat/Iptal dugmesine basilir }
        F.rgIslem.ItemIndex := 0;
        F.rgIslemClick(F.rgIslem);
        F.edtHedef.Text := Fbk2;
        IptalZamani.Interval := 800;
        IptalZamani.Enabled := True;
        Kontrol('iptal: calisirken dugme yazisi Iptal olur (sonra denenir)', True);
        F.btnBaslat.Click;
        Kontrol('iptal: islem durdu, Baslat tekrar etkin', F.btnBaslat.Enabled and F.rgIslem.Enabled);
        Kontrol('iptal: durum yazisinda "iptal" ve yarim dosya yolu (' + StringReplace(F.lblDurum.Caption, #13#10, ' / ', [rfReplaceAll]) + ')',
          (Pos(T('YEDEK_IPTAL'), F.lblDurum.Caption) > 0) and (Pos(Fbk2 + '.yarim', F.lblDurum.Caption) > 0));
        Kontrol('iptal: yarim dosya silinmedi (' + IntToStr(TFile.GetSize(Fbk2 + '.yarim')) + ' bayt), asil hedef olusmadi',
          TFile.Exists(Fbk2 + '.yarim') and not TFile.Exists(Fbk2));
        Uretilen.Add(Fbk2 + '.yarim');
        F.ModalResult := mrCancel;
      end;
  end;
  Sayac.Enabled := True;
end;

procedure DosyalariArsiveTasi;
var
  Dosya, Arsiv: string;
begin
  Arsiv := TPath.Combine(Klasor, '_arsiv');
  ForceDirectories(Arsiv);
  for Dosya in Uretilen do
    if FileExists(Dosya) then
      TFile.Move(Dosya, TPath.Combine(Arsiv, ChangeFileExt(ExtractFileName(Dosya), '') + '_' +
        FormatDateTime('hhnnsszzz', Now) + ExtractFileExt(Dosya)));
end;

var
  Damga, Sonuc: string;
  Sonuclar: TStringList;
begin
  Cikti := TStringList.Create;
  GorulenDiyaloglar := TStringList.Create;
  Uretilen := TStringList.Create;
  try
    try
      DilYukle('tr');
      Damga := FormatDateTime('yyyymmdd_hhnnss', Now);
      Klasor := TPath.Combine(TPath.Combine(GetEnvironmentVariable('TEMP'), 'yedektest'), 'form');
      ForceDirectories(Klasor);
      Kucuk := Default(TBaglantiTanimi);
      Kucuk.Ad := 'formtest';
      Kucuk.Kullanici := 'SYSDBA';
      Kucuk.KarakterSeti := VARSAYILAN_KARAKTER_SETI;
      Kucuk.Port := 3050;
      KucukYol := TPath.Combine(Klasor, 'kucuk_' + Damga + '.fdb');
      Kucuk.VeritabaniYolu := KucukYol;
      Olustur(Kucuk);
      Buyuk := Kucuk;
      Buyuk.Ad := 'formbuyuk';
      BuyukYol := TPath.Combine(Klasor, 'buyuk_' + Damga + '.fdb');
      Buyuk.VeritabaniYolu := BuyukYol;
      Olustur(Buyuk);
      BuyukDoldur(Buyuk);
      Uretilen.Add(KucukYol);
      Uretilen.Add(BuyukYol);
      Fbk := TPath.Combine(Klasor, 'form_' + Damga + '.fbk');
      Fbk2 := TPath.Combine(Klasor, 'formbuyuk_' + Damga + '.fbk');
      YeniYol := TPath.Combine(Klasor, 'geri_' + Damga + '.fdb');

      Application.Initialize;
      Surucu := TSurucu.Create;
      Surucu.Sayac := TTimer.Create(Application);
      Surucu.Sayac.Interval := 400;
      Surucu.Sayac.OnTimer := Surucu.AdimCalistir;
      Surucu.Kapatici := TTimer.Create(Application);
      Surucu.Kapatici.Interval := 100;
      Surucu.Kapatici.OnTimer := Surucu.DiyalogKapat;
      Surucu.IptalZamani := TTimer.Create(Application);
      Surucu.IptalZamani.Enabled := False;
      Surucu.IptalZamani.OnTimer := Surucu.IptalEt;
      Sonuclar := TStringList.Create;
      try
        { Tum adimlar pencere acikken zamanlayicilarla yurur; pencere 4. adimin sonunda kapanir. }
        YedekPenceresiniGoster(Kucuk, Sonuclar);
        Surucu.Sayac.Enabled := True;
        YedekPenceresiniGoster(Buyuk, Sonuclar);
        Cikti.Add('--- ana pencere sonuc alanina yazilan satirlar (' + IntToStr(Sonuclar.Count) + ') ---');
        Cikti.AddStrings(Sonuclar);
      finally
        Sonuclar.Free;
      end;
      DosyalariArsiveTasi;
    except
      on E: Exception do
      begin
        Cikti.Add('HATA  beklenmeyen istisna: ' + E.ClassName + ': ' + E.Message);
        Inc(Hatalar);
      end;
    end;
    Cikti.Add('');
    Cikti.Add('Kontrol sayisi: ' + IntToStr(Kontroller) + ', Hata sayisi: ' + IntToStr(Hatalar));
    Sonuc := GetEnvironmentVariable('FBTEST_CIKTI');
    if Sonuc <> '' then
      Cikti.SaveToFile(Sonuc, TEncoding.UTF8);
  finally
    Uretilen.Free;
    GorulenDiyaloglar.Free;
    Cikti.Free;
  end;
  ExitCode := Hatalar;
end.
