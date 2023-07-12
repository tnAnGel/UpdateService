unit UpdateService;

interface

uses
  System.SysUtils, System.Classes, Winapi.Windows, Winapi.Messages, Winapi.ShellAPI;

type
  TUpdateService = class(TService)
    Timer: TTimer;
    procedure ServiceCreate(Sender: TObject);
    procedure TimerTimer(Sender: TObject);
    procedure ServiceAfterInstall(Sender: TService);
  strict private
    FAppPath: string;
    FUpdateURL: string;
    procedure CheckForUpdates;
    function GetFileVersion(const FileName: string): string;
  public
    function GetServiceController: TServiceController; override;
  end;

var
  UpdateService: TUpdateService;

implementation

{$R *.dfm}

uses
  IdHTTP, IdURI;

procedure ServiceController(CtrlCode: DWord); stdcall;
begin
  UpdateService.Controller(CtrlCode);
end;

function TUpdateService.GetServiceController: TServiceController;
begin
  Result := ServiceController;
end;

procedure TUpdateService.ServiceAfterInstall(Sender: TService);
begin
  FAppPath := ExtractFilePath(ParamStr(0));
  FUpdateURL := 'http://www.example.com/update/check';
end;

procedure TUpdateService.ServiceCreate(Sender: TObject);
begin
  Timer := TTimer.Create(nil);
  Timer.Interval := 24 * 60 * 60 * 1000; // 1 day 
  Timer.OnTimer := TimerTimer;
  Timer.Enabled := True;
end;

procedure TUpdateService.TimerTimer(Sender: TObject);
begin
  CheckForUpdates;
end;

procedure TUpdateService.CheckForUpdates;
var
  HTTPClient: TIdHTTP;
  VersionURL: string;
  NewVersion, CurrentVersion: string;
begin
  try
    VersionURL := TIdURI.URLEncode(FUpdateURL) + '?appversion=' + GetFileVersion(FAppPath + 'MyApp.exe');
    
    HTTPClient := TIdHTTP.Create(nil);
    try
      CurrentVersion := HTTPClient.Get(VersionURL);
    finally
      HTTPClient.Free;
    end;
    
    if CurrentVersion > GetCurrentVersion then
    begin
      ShellExecute(0, 'open', PChar('Updater.exe'), nil, nil, SW_SHOW);
    end;
  except
    on E: Exception do
      LogMessage(E.Message);
  end;
end;

function TUpdateService.GetFileVersion(const FileName: string): string;
var
  Size, Handle: DWORD;
  Buffer: TBytes;
  FixedFileInfo: PVSFixedFileInfo;
  FileInfoSize: UINT;
begin
  Size := GetFileVersionInfoSize(PChar(FileName), Handle);
  if Size = 0 then
    RaiseLastOSError;

  SetLength(Buffer, Size);
  GetFileVersionInfo(PChar(FileName), Handle, Size, Buffer);

  if not VerQueryValue(Buffer, '\', Pointer(FixedFileInfo), FileInfoSize) then
    RaiseLastOSError;

  Result := Format('%d.%d.%d.%d',
    [LongRec(FixedFileInfo.dwFileVersionMS).Hi,
    LongRec(FixedFileInfo.dwFileVersionMS).Lo,
    LongRec(FixedFileInfo.dwFileVersionLS).Hi,
    LongRec(FixedFileInfo.dwFileVersionLS).Lo]);
end;

end.