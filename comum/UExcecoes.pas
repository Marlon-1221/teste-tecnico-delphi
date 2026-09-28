unit UExcecoes;

interface

uses
  System.SysUtils;

type
  EAplicacao = class(Exception);

  EValidacao = class(EAplicacao)
  private
    FDetalhes: TArray<string>;
  public
    constructor Create(const AMensagem: string; const ADetalhes: TArray<string>); overload;
    property Detalhes: TArray<string> read FDetalhes;
  end;

  ERegistroNaoEncontrado = class(EAplicacao);

  EOperacaoEmAndamento = class(EAplicacao);

implementation

constructor EValidacao.Create(const AMensagem: string; const ADetalhes: TArray<string>);
begin
  inherited Create(AMensagem);
  FDetalhes := ADetalhes;
end;

end.
