{ fMetinGoster.pas - Uzun yazi veya BLOB degerinin tamamini gosteren pencere.
  Sonuc izgarasinda hucreye cift tiklayinca acilir. Salt okunurdur. }
unit fMetinGoster;

interface

uses
  System.SysUtils, System.Classes, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls,
  Vcl.ExtCtrls,
  uDil;

type
  TfrmMetinGoster = class(TForm)
    memMetin: TMemo;
    pnlAlt: TPanel;
    btnKapat: TButton;
  end;

procedure MetinGoster(const Baslik, Metin: string);

implementation

{$R *.dfm}

procedure MetinGoster(const Baslik, Metin: string);
var
  Pencere: TfrmMetinGoster;
begin
  Pencere := TfrmMetinGoster.Create(Application);
  try
    Pencere.Caption := Baslik;
    Pencere.btnKapat.Caption := T('BTN_KAPAT');
    Pencere.memMetin.Text := Metin;
    Pencere.ShowModal;
  finally
    Pencere.Free;
  end;
end;

end.
