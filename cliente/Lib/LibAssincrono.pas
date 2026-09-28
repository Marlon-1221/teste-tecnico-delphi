unit LibAssincrono;

interface

uses
  System.SysUtils;

type
  TProcFalha = reference to procedure(const AMensagem: string);

  TAssincrono = class abstract
  public
    class procedure Executar<T>(const ATarefa: TFunc<T>; const ASucesso: TProc<T>; const AFalha: TProcFalha); static;
    class procedure ExecutarAcao(const ATarefa: TProc; const ASucesso: TProc; const AFalha: TProcFalha); static;
  end;

implementation

uses
  System.Classes;

class procedure TAssincrono.Executar<T>(const ATarefa: TFunc<T>; const ASucesso: TProc<T>; const AFalha: TProcFalha);
begin
  TThread.CreateAnonymousThread(
    procedure
    var
      LResultado: T;
      LMensagem: string;
    begin
      try
        LResultado := ATarefa();
      except
        on E: Exception do
        begin
          LMensagem := E.Message;
          TThread.Queue(nil,
            procedure
            begin
              AFalha(LMensagem);
            end);
          Exit;
        end;
      end;

      TThread.Queue(nil,
        procedure
        begin
          ASucesso(LResultado);
        end);
    end).Start;
end;

class procedure TAssincrono.ExecutarAcao(const ATarefa: TProc; const ASucesso: TProc; const AFalha: TProcFalha);
begin
  Executar<Boolean>(
    function: Boolean
    begin
      ATarefa();
      Result := True;
    end,
    procedure(AIgnorado: Boolean)
    begin
      ASucesso();
    end,
    AFalha);
end;

end.
