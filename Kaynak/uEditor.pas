{ uEditor.pas - SQL editorunun (SynEdit) arkasindaki sarmalayici.

  Formlar ve frame'ler SynEdit'i dogrudan bilmez; TSqlEditor'u kullanir.
  SynEdit, RAD Studio 12'ye GetIt/kurulum ile eklenmis olmalidir; editor kod
  icinde olusturulur (formda tasarim zamani bilesen yok), boylece .dfm dosyalari
  SynEdit paketine bagli kalmaz.
  SQL renklendirme SynEdit'in SQL renklendiricisinin Firebird (InterBase 6)
  ayariyla yapilir. }
unit uEditor;

interface

uses
  System.SysUtils, System.Classes, Vcl.Controls, Vcl.Graphics,
  SynEdit, SynHighlighterSQL;

type
  { Sahibi (Ust) yok olunca editor de yok olur. }
  TSqlEditor = class(TComponent)
  private
    FEdit: TSynEdit;
    FRenk: TSynSQLSyn;
  public
    constructor Create(Ust: TWinControl); reintroduce;
    { Secili yazi varsa sadece onu, yoksa editordeki tum yaziyi verir (F5 bunu calistirir). }
    function CalistirilacakMetin: string;
    procedure OdakVer;
  end;

implementation

constructor TSqlEditor.Create(Ust: TWinControl);
begin
  inherited Create(Ust);
  FRenk := TSynSQLSyn.Create(Self);
  FRenk.SQLDialect := sqlInterbase6;
  FEdit := TSynEdit.Create(Self);
  FEdit.Parent := Ust;
  FEdit.Align := alClient;
  FEdit.Font.Name := 'Consolas';
  FEdit.Font.Size := 11;
  FEdit.Gutter.ShowLineNumbers := True;
  FEdit.Highlighter := FRenk;
end;

function TSqlEditor.CalistirilacakMetin: string;
begin
  if FEdit.SelAvail then
    Result := FEdit.SelText
  else
    Result := FEdit.Text;
end;

procedure TSqlEditor.OdakVer;
begin
  if FEdit.CanFocus then
    FEdit.SetFocus;
end;

end.
