unit uYonetici;

{ Programin yonetici (yukseltilmis) yetkisiyle calisip calismadigini bulur ve gerekirse yonetici olarak yeniden baslatir.
  Windows'a bagli her sey bu unit'in arkasinda durur. }

interface

function YoneticiMi: Boolean;
{ Windows yetki penceresini (UAC) acar ve programi yonetici olarak yeniden baslatir. Baslatildiysa True doner
  (cagiran kendini kapatir); kullanici yetki penceresinde "Hayir" derse False doner. }
function YoneticiOlarakYenidenBaslat: Boolean;

implementation

uses
  Winapi.Windows, Winapi.ShellAPI, System.SysUtils;

const
  JETON_YUKSELME_SINIFI = 20;

type
  TJetonYukselme = record
    YukseltilmisMi: DWORD;
  end;

function YoneticiMi: Boolean;
var
  Jeton: THandle;
  Yukselme: TJetonYukselme;
  Boyut: DWORD;
begin
  Result := False;
  if not OpenProcessToken(GetCurrentProcess, TOKEN_QUERY, Jeton) then
    Exit;
  try
    if GetTokenInformation(Jeton, TTokenInformationClass(JETON_YUKSELME_SINIFI), @Yukselme, SizeOf(Yukselme), Boyut) then
      Result := Yukselme.YukseltilmisMi <> 0;
  finally
    CloseHandle(Jeton);
  end;
end;

function YoneticiOlarakYenidenBaslat: Boolean;
begin
  Result := ShellExecute(0, 'runas', PChar(ParamStr(0)), nil, nil, SW_SHOWNORMAL) > 32;
end;

end.
