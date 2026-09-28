unit UConversorJson;

interface

uses
  System.JSON,
  System.Generics.Collections,
  UPessoa,
  UPagina,
  UStatusCep,
  USistema;

type
  TJsonLeitor = class abstract
  private
    class function Valor(AObjeto: TJSONObject; const ANome: string): TJSONValue; static;
  public
    class function Texto(AObjeto: TJSONObject; const ANome: string; const APadrao: string = ''): string; static;
    class function Inteiro(AObjeto: TJSONObject; const ANome: string; APadrao: Integer = 0): Integer; static;
    class function Inteiro64(AObjeto: TJSONObject; const ANome: string; APadrao: Int64 = 0): Int64; static;
    class function Booleano(AObjeto: TJSONObject; const ANome: string; APadrao: Boolean = False): Boolean; static;
    class function Data(AObjeto: TJSONObject; const ANome: string): TDate; static;
    class function DataHora(AObjeto: TJSONObject; const ANome: string): TDateTime; static;
    class function Objeto(AObjeto: TJSONObject; const ANome: string): TJSONObject; static;
    class function Lista(AObjeto: TJSONObject; const ANome: string): TJSONArray; static;
    class function ComoObjeto(AValor: TJSONValue; const AContexto: string): TJSONObject; static;
  end;

  TJsonEscritor = class abstract
  public
    class function Booleano(AValor: Boolean): TJSONValue; static;
    class function Data(AValor: TDate): TJSONValue; static;
    class function DataHora(AValor: TDateTime): TJSONValue; static;
  end;

  TPessoaJson = class abstract
  private
    class function IntegracaoParaJson(AIntegracao: TEnderecoIntegracao): TJSONValue; static;
    class function IntegracaoDeJson(AJson: TJSONObject): TEnderecoIntegracao; static;
    class function EnderecoParaJson(AEndereco: TEndereco): TJSONObject; static;
    class function EnderecoDeJson(AJson: TJSONObject): TEndereco; static;
  public
    class function ParaJson(APessoa: TPessoa): TJSONObject; static;
    class function DeJson(AJson: TJSONObject): TPessoa; static;
    class function ListaParaJson(APessoas: TList<TPessoa>): TJSONArray; static;
    class function ListaDeJson(AJson: TJSONArray): TObjectList<TPessoa>; static;
    class function PaginaParaJson(APagina: TPagina<TPessoa>): TJSONObject; static;
    class function PaginaDeJson(AJson: TJSONObject): TPagina<TPessoa>; static;
  end;

  TStatusAtualizacaoCepJson = class abstract
  public
    class function ParaJson(AStatus: TStatusAtualizacaoCep): TJSONObject; static;
    class function DeJson(AJson: TJSONObject): TStatusAtualizacaoCep; static;
  end;

  TInformacoesBancoJson = class abstract
  public
    class function ParaJson(const AInformacoes: TInformacoesBanco): TJSONObject; static;
    class function DeJson(AJson: TJSONObject): TInformacoesBanco; static;
  end;

implementation

uses
  System.SysUtils,
  System.DateUtils,
  UExcecoes;

const
  FORMATO_DATA = 'yyyy-mm-dd';

class function TJsonLeitor.Valor(AObjeto: TJSONObject; const ANome: string): TJSONValue;
begin
  Result := AObjeto.GetValue(ANome);
  if Result is TJSONNull then
    Result := nil;
end;

class function TJsonLeitor.Texto(AObjeto: TJSONObject; const ANome, APadrao: string): string;
var
  LValor: TJSONValue;
begin
  LValor := Valor(AObjeto, ANome);
  if LValor = nil then
    Result := APadrao
  else
    Result := LValor.Value;
end;

class function TJsonLeitor.Inteiro64(AObjeto: TJSONObject; const ANome: string; APadrao: Int64): Int64;
var
  LTexto: string;
begin
  LTexto := Texto(AObjeto, ANome);
  if LTexto = '' then
    Exit(APadrao);
  if not TryStrToInt64(LTexto, Result) then
    raise EValidacao.CreateFmt('O campo "%s" deve ser numérico. Valor recebido: "%s".', [ANome, LTexto]);
end;

class function TJsonLeitor.Inteiro(AObjeto: TJSONObject; const ANome: string; APadrao: Integer): Integer;
var
  LTexto: string;
begin
  LTexto := Texto(AObjeto, ANome);
  if LTexto = '' then
    Exit(APadrao);
  if not TryStrToInt(LTexto, Result) then
    raise EValidacao.CreateFmt('O campo "%s" deve ser numérico. Valor recebido: "%s".', [ANome, LTexto]);
end;

class function TJsonLeitor.Booleano(AObjeto: TJSONObject; const ANome: string; APadrao: Boolean): Boolean;
var
  LTexto: string;
begin
  LTexto := Texto(AObjeto, ANome);
  if LTexto = '' then
    Result := APadrao
  else
    Result := SameText(LTexto, 'true');
end;

class function TJsonLeitor.Data(AObjeto: TJSONObject; const ANome: string): TDate;
var
  LTexto: string;
  LData: TDateTime;
begin
  LTexto := Texto(AObjeto, ANome);
  if LTexto = '' then
    Exit(0);
  if (Length(LTexto) < Length(FORMATO_DATA)) or not TryEncodeDate(
    StrToIntDef(Copy(LTexto, 1, 4), 0), StrToIntDef(Copy(LTexto, 6, 2), 0),
    StrToIntDef(Copy(LTexto, 9, 2), 0), LData) then
    raise EValidacao.CreateFmt('O campo "%s" deve estar no formato AAAA-MM-DD. Valor recebido: "%s".',
      [ANome, LTexto]);
  Result := LData;
end;

class function TJsonLeitor.DataHora(AObjeto: TJSONObject; const ANome: string): TDateTime;
var
  LTexto: string;
begin
  LTexto := Texto(AObjeto, ANome);
  if LTexto = '' then
    Exit(0);
  try
    Result := ISO8601ToDate(LTexto, False);
  except
    raise EValidacao.CreateFmt('O campo "%s" deve estar no formato ISO 8601. Valor recebido: "%s".',
      [ANome, LTexto]);
  end;
end;

class function TJsonLeitor.Objeto(AObjeto: TJSONObject; const ANome: string): TJSONObject;
var
  LValor: TJSONValue;
begin
  LValor := Valor(AObjeto, ANome);
  if LValor = nil then
    Exit(nil);
  Result := ComoObjeto(LValor, ANome);
end;

class function TJsonLeitor.Lista(AObjeto: TJSONObject; const ANome: string): TJSONArray;
var
  LValor: TJSONValue;
begin
  LValor := Valor(AObjeto, ANome);
  if LValor = nil then
    Exit(nil);
  if not (LValor is TJSONArray) then
    raise EValidacao.CreateFmt('O campo "%s" deve ser uma lista.', [ANome]);
  Result := TJSONArray(LValor);
end;

class function TJsonLeitor.ComoObjeto(AValor: TJSONValue; const AContexto: string): TJSONObject;
begin
  if not (AValor is TJSONObject) then
    raise EValidacao.CreateFmt('Era esperado um objeto JSON em "%s".', [AContexto]);
  Result := TJSONObject(AValor);
end;

class function TJsonEscritor.Booleano(AValor: Boolean): TJSONValue;
begin
  if AValor then
    Result := TJSONTrue.Create
  else
    Result := TJSONFalse.Create;
end;

class function TJsonEscritor.Data(AValor: TDate): TJSONValue;
begin
  if AValor <= 0 then
    Result := TJSONNull.Create
  else
    Result := TJSONString.Create(FormatDateTime(FORMATO_DATA, AValor));
end;

class function TJsonEscritor.DataHora(AValor: TDateTime): TJSONValue;
begin
  if AValor <= 0 then
    Result := TJSONNull.Create
  else
    Result := TJSONString.Create(DateToISO8601(AValor, False));
end;

class function TPessoaJson.IntegracaoParaJson(AIntegracao: TEnderecoIntegracao): TJSONValue;
var
  LJson: TJSONObject;
begin
  if AIntegracao = nil then
    Exit(TJSONNull.Create);

  LJson := TJSONObject.Create;
  LJson.AddPair('uf', AIntegracao.Uf);
  LJson.AddPair('cidade', AIntegracao.Cidade);
  LJson.AddPair('bairro', AIntegracao.Bairro);
  LJson.AddPair('logradouro', AIntegracao.Logradouro);
  LJson.AddPair('complemento', AIntegracao.Complemento);
  Result := LJson;
end;

class function TPessoaJson.IntegracaoDeJson(AJson: TJSONObject): TEnderecoIntegracao;
begin
  if AJson = nil then
    Exit(nil);

  Result := TEnderecoIntegracao.Create;
  Result.Uf := TJsonLeitor.Texto(AJson, 'uf');
  Result.Cidade := TJsonLeitor.Texto(AJson, 'cidade');
  Result.Bairro := TJsonLeitor.Texto(AJson, 'bairro');
  Result.Logradouro := TJsonLeitor.Texto(AJson, 'logradouro');
  Result.Complemento := TJsonLeitor.Texto(AJson, 'complemento');
end;

class function TPessoaJson.EnderecoParaJson(AEndereco: TEndereco): TJSONObject;
begin
  Result := TJSONObject.Create;
  try
    Result.AddPair('id', TJSONNumber.Create(AEndereco.Id));
    Result.AddPair('cep', AEndereco.Cep);
    Result.AddPair('integracao', IntegracaoParaJson(AEndereco.Integracao));
  except
    Result.Free;
    raise;
  end;
end;

class function TPessoaJson.EnderecoDeJson(AJson: TJSONObject): TEndereco;
begin
  Result := TEndereco.Create;
  try
    Result.Id := TJsonLeitor.Inteiro64(AJson, 'id');
    Result.Cep := TJsonLeitor.Texto(AJson, 'cep');
    Result.Integracao := IntegracaoDeJson(TJsonLeitor.Objeto(AJson, 'integracao'));
  except
    Result.Free;
    raise;
  end;
end;

class function TPessoaJson.ParaJson(APessoa: TPessoa): TJSONObject;
var
  LEnderecos: TJSONArray;
  LEndereco: TEndereco;
begin
  Result := TJSONObject.Create;
  try
    Result.AddPair('id', TJSONNumber.Create(APessoa.Id));
    Result.AddPair('natureza', TJSONNumber.Create(APessoa.Natureza.ParaInteiro));
    Result.AddPair('documento', APessoa.Documento);
    Result.AddPair('primeiroNome', APessoa.PrimeiroNome);
    Result.AddPair('segundoNome', APessoa.SegundoNome);
    Result.AddPair('dataRegistro', TJsonEscritor.Data(APessoa.DataRegistro));

    LEnderecos := TJSONArray.Create;
    Result.AddPair('enderecos', LEnderecos);
    for LEndereco in APessoa.Enderecos do
      LEnderecos.AddElement(EnderecoParaJson(LEndereco));
  except
    Result.Free;
    raise;
  end;
end;

class function TPessoaJson.DeJson(AJson: TJSONObject): TPessoa;
var
  LEnderecos: TJSONArray;
  LEndereco: TEndereco;
  I: Integer;
begin
  Result := TPessoa.Create;
  try
    Result.Id := TJsonLeitor.Inteiro64(AJson, 'id');
    Result.Natureza := TNaturezaPessoa.DeInteiro(TJsonLeitor.Inteiro(AJson, 'natureza'));
    Result.Documento := TJsonLeitor.Texto(AJson, 'documento');
    Result.PrimeiroNome := TJsonLeitor.Texto(AJson, 'primeiroNome');
    Result.SegundoNome := TJsonLeitor.Texto(AJson, 'segundoNome');
    Result.DataRegistro := TJsonLeitor.Data(AJson, 'dataRegistro');

    LEnderecos := TJsonLeitor.Lista(AJson, 'enderecos');
    if LEnderecos <> nil then
      for I := 0 to LEnderecos.Count - 1 do
      begin
        LEndereco := EnderecoDeJson(TJsonLeitor.ComoObjeto(LEnderecos.Items[I], 'enderecos'));
        LEndereco.IdPessoa := Result.Id;
        Result.Enderecos.Add(LEndereco);
      end;
  except
    Result.Free;
    raise;
  end;
end;

class function TPessoaJson.ListaParaJson(APessoas: TList<TPessoa>): TJSONArray;
var
  LPessoa: TPessoa;
begin
  Result := TJSONArray.Create;
  try
    for LPessoa in APessoas do
      Result.AddElement(ParaJson(LPessoa));
  except
    Result.Free;
    raise;
  end;
end;

class function TPessoaJson.ListaDeJson(AJson: TJSONArray): TObjectList<TPessoa>;
var
  I: Integer;
begin
  Result := TObjectList<TPessoa>.Create(True);
  try
    Result.Capacity := AJson.Count;
    for I := 0 to AJson.Count - 1 do
      Result.Add(DeJson(TJsonLeitor.ComoObjeto(AJson.Items[I], Format('item %d da lista', [I + 1]))));
  except
    Result.Free;
    raise;
  end;
end;

class function TPessoaJson.PaginaParaJson(APagina: TPagina<TPessoa>): TJSONObject;
begin
  Result := TJSONObject.Create;
  try
    Result.AddPair('pagina', TJSONNumber.Create(APagina.Numero));
    Result.AddPair('tamanho', TJSONNumber.Create(APagina.Tamanho));
    Result.AddPair('totalRegistros', TJSONNumber.Create(APagina.TotalRegistros));
    Result.AddPair('totalPaginas', TJSONNumber.Create(APagina.TotalPaginas));
    Result.AddPair('dados', ListaParaJson(APagina.Itens));
  except
    Result.Free;
    raise;
  end;
end;

class function TPessoaJson.PaginaDeJson(AJson: TJSONObject): TPagina<TPessoa>;
var
  LDados: TJSONArray;
  I: Integer;
begin
  Result := TPagina<TPessoa>.Create(TJsonLeitor.Inteiro(AJson, 'pagina', 1),
    TJsonLeitor.Inteiro(AJson, 'tamanho'));
  try
    Result.TotalRegistros := TJsonLeitor.Inteiro64(AJson, 'totalRegistros');
    LDados := TJsonLeitor.Lista(AJson, 'dados');
    if LDados <> nil then
      for I := 0 to LDados.Count - 1 do
        Result.Itens.Add(DeJson(TJsonLeitor.ComoObjeto(LDados.Items[I], 'dados')));
  except
    Result.Free;
    raise;
  end;
end;

class function TStatusAtualizacaoCepJson.ParaJson(AStatus: TStatusAtualizacaoCep): TJSONObject;
begin
  Result := TJSONObject.Create;
  try
    Result.AddPair('emExecucao', TJsonEscritor.Booleano(AStatus.EmExecucao));
    Result.AddPair('somentePendentes', TJsonEscritor.Booleano(AStatus.SomentePendentes));
    Result.AddPair('totalEnderecos', TJSONNumber.Create(AStatus.TotalEnderecos));
    Result.AddPair('totalCeps', TJSONNumber.Create(AStatus.TotalCeps));
    Result.AddPair('cepsProcessados', TJSONNumber.Create(AStatus.CepsProcessados));
    Result.AddPair('enderecosAtualizados', TJSONNumber.Create(AStatus.EnderecosAtualizados));
    Result.AddPair('cepsNaoEncontrados', TJSONNumber.Create(AStatus.CepsNaoEncontrados));
    Result.AddPair('falhas', TJSONNumber.Create(AStatus.Falhas));
    Result.AddPair('percentual', TJSONNumber.Create(AStatus.PercentualConcluido));
    Result.AddPair('inicio', TJsonEscritor.DataHora(AStatus.Inicio));
    Result.AddPair('fim', TJsonEscritor.DataHora(AStatus.Fim));
    Result.AddPair('ultimoErro', AStatus.UltimoErro);
  except
    Result.Free;
    raise;
  end;
end;

class function TStatusAtualizacaoCepJson.DeJson(AJson: TJSONObject): TStatusAtualizacaoCep;
begin
  Result := TStatusAtualizacaoCep.Create;
  try
    Result.EmExecucao := TJsonLeitor.Booleano(AJson, 'emExecucao');
    Result.SomentePendentes := TJsonLeitor.Booleano(AJson, 'somentePendentes');
    Result.TotalEnderecos := TJsonLeitor.Inteiro(AJson, 'totalEnderecos');
    Result.TotalCeps := TJsonLeitor.Inteiro(AJson, 'totalCeps');
    Result.CepsProcessados := TJsonLeitor.Inteiro(AJson, 'cepsProcessados');
    Result.EnderecosAtualizados := TJsonLeitor.Inteiro(AJson, 'enderecosAtualizados');
    Result.CepsNaoEncontrados := TJsonLeitor.Inteiro(AJson, 'cepsNaoEncontrados');
    Result.Falhas := TJsonLeitor.Inteiro(AJson, 'falhas');
    Result.Inicio := TJsonLeitor.DataHora(AJson, 'inicio');
    Result.Fim := TJsonLeitor.DataHora(AJson, 'fim');
    Result.UltimoErro := TJsonLeitor.Texto(AJson, 'ultimoErro');
  except
    Result.Free;
    raise;
  end;
end;

class function TInformacoesBancoJson.ParaJson(const AInformacoes: TInformacoesBanco): TJSONObject;
begin
  Result := TJSONObject.Create;
  try
    Result.AddPair('versao', AInformacoes.Versao);
    Result.AddPair('servidor', AInformacoes.Servidor);
    Result.AddPair('porta', TJSONNumber.Create(AInformacoes.Porta));
    Result.AddPair('banco', AInformacoes.Banco);
  except
    Result.Free;
    raise;
  end;
end;

class function TInformacoesBancoJson.DeJson(AJson: TJSONObject): TInformacoesBanco;
begin
  Result.Versao := TJsonLeitor.Texto(AJson, 'versao');
  Result.Servidor := TJsonLeitor.Texto(AJson, 'servidor');
  Result.Porta := TJsonLeitor.Inteiro(AJson, 'porta');
  Result.Banco := TJsonLeitor.Texto(AJson, 'banco');
end;

end.
