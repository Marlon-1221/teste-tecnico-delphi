unit ULog;

interface

uses
  System.SyncObjs;

type
  ILog = interface
    ['{B2D4E6F8-1A3C-4E5F-8091-A2B3C4D5E6F7}']
    procedure Informar(const AMensagem: string);
    procedure Erro(const AMensagem: string);
  end;

  TLogConsole = class(TInterfacedObject, ILog)
  private
    FTrava: TCriticalSection;
    procedure Escrever(const ANivel, AMensagem: string);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Informar(const AMensagem: string);
    procedure Erro(const AMensagem: string);
  end;

implementation

uses
  System.SysUtils;

constructor TLogConsole.Create;
begin
  inherited Create;
  FTrava := TCriticalSection.Create;
end;

destructor TLogConsole.Destroy;
begin
  FTrava.Free;
  inherited;
end;

procedure TLogConsole.Escrever(const ANivel, AMensagem: string);
begin
  FTrava.Enter;
  try
    Writeln(Format('%s [%s] %s', [FormatDateTime('hh:nn:ss.zzz', Now), ANivel, AMensagem]));
  finally
    FTrava.Leave;
  end;
end;

procedure TLogConsole.Informar(const AMensagem: string);
begin
  Escrever('INFO', AMensagem);
end;

procedure TLogConsole.Erro(const AMensagem: string);
begin
  Escrever('ERRO', AMensagem);
end;

end.
