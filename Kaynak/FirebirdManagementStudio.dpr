program FirebirdManagementStudio;

{ Firebird Management Studio - Win64, Delphi (RAD Studio 12), VCL + FireDAC.
  Hedeflenen Firebird surumleri: 2.5, 3.0, 4.0, 5.0
  Denenen Firebird surumleri: 2.5.9, 5.0.4 }

uses
  System.SysUtils,
  Vcl.Forms,
  Vcl.Themes,
  Vcl.Styles,
  uPaket in 'uPaket.pas',
  uUygulama in 'uUygulama.pas',
  uYonetici in 'uYonetici.pas',
  uDil in 'uDil.pas',
  uIkon in 'uIkon.pas',
  uSerit in 'uSerit.pas',
  uOnay in 'uOnay.pas',
  uBaglanti in 'uBaglanti.pas',
  uMetadata in 'uMetadata.pas',
  uSorgu in 'uSorgu.pas',
  uSonucGrid in 'uSonucGrid.pas',
  uEditor in 'uEditor.pas',
  uDDL in 'uDDL.pas',
  uAktar in 'uAktar.pas',
  uYedek in 'uYedek.pas',
  uKullanici in 'uKullanici.pas',
  uProsedur in 'uProsedur.pas',
  uNesneYonet in 'uNesneYonet.pas',
  uKolon in 'uKolon.pas',
  uIndeksKisit in 'uIndeksKisit.pas',
  fYapiIslem in 'fYapiIslem.pas' {frmYapiIslem},
  fKolonIslem in 'fKolonIslem.pas' {frmKolonIslem},
  fProsedurSekme in 'fProsedurSekme.pas' {ProsedurSekme: TFrame},
  fKullanicilar in 'fKullanicilar.pas' {Kullanicilar: TFrame},
  fKullaniciDuzenle in 'fKullaniciDuzenle.pas' {frmKullaniciDuzenle},
  fTabloSekme in 'fTabloSekme.pas' {TabloSekme: TFrame},
  fSorguSekme in 'fSorguSekme.pas' {SorguSekme: TFrame},
  fMetinGoster in 'fMetinGoster.pas' {frmMetinGoster},
  fMetinSor in 'fMetinSor.pas' {frmMetinSor},
  fGeneratorDeger in 'fGeneratorDeger.pas' {frmGeneratorDeger},
  fMetadataCikar in 'fMetadataCikar.pas' {frmMetadataCikar},
  fCsvAktar in 'fCsvAktar.pas' {frmCsvAktar},
  fYedek in 'fYedek.pas' {frmYedek},
  uCokluSorgu in 'uCokluSorgu.pas',
  fCokluSorgu in 'fCokluSorgu.pas' {CokluSorguSekme: TFrame},
  uYetki in 'uYetki.pas',
  fYetkiVer in 'fYetkiVer.pas' {frmYetkiVer},
  fYetkiler in 'fYetkiler.pas' {frmYetkiler},
  uSunucuBul in 'uSunucuBul.pas',
  fSunucuSec in 'fSunucuSec.pas' {frmSunucuSec},
  fBaglanti in 'fBaglanti.pas' {frmBaglanti},
  fTabloListe in 'fTabloListe.pas' {TabloListeSekme: TFrame},
  uTopluGuncelle in 'uTopluGuncelle.pas',
  uKayitDuzelt in 'uKayitDuzelt.pas',
  uIceAktar in 'uIceAktar.pas',
  fIceAktar in 'fIceAktar.pas' {frmIceAktar},
  uTabloKopya in 'uTabloKopya.pas',
  fTabloKopya in 'fTabloKopya.pas' {frmTabloKopya},
  fTopluGuncelle in 'fTopluGuncelle.pas' {TopluGuncelleSekme: TFrame},
  uSemaFark in 'uSemaFark.pas',
  fSemaFark in 'fSemaFark.pas' {SemaFarkSekme: TFrame},
  fAcilis in 'fAcilis.pas' {frmAcilis},
  fHakkinda in 'fHakkinda.pas' {frmHakkinda},
  fAna in 'fAna.pas' {frmAna};

{$R *.res}
{$R 'Manifest.res' 'Manifest.rc'}
{$R 'Paket.res' 'Paket.rc'}

{ Acik tema: Stiller klasorundeki Windows10.vsf yuklenir. Dosya yoksa standart gorunum kalir. }
procedure StilYukle;
var
  Dosya: string;
begin
  Dosya := PaketKlasoru + '\Stiller\Windows10.vsf';
  if FileExists(Dosya) and TStyleManager.IsValidStyle(Dosya) then
  begin
    TStyleManager.LoadFromFile(Dosya);
    TStyleManager.TrySetStyle('Windows10');
  end;
end;

begin
  UygulamaKimliginiAyarla;
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  StilYukle;
  AcilisGoster;
  Application.CreateForm(TfrmAna, frmAna);
  AcilisKapat;
  Application.Run;
end.
