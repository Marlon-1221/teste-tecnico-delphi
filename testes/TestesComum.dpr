program TestesComum;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.JSON,
  System.Generics.Collections,
  UExcecoes in '..\comum\UExcecoes.pas',
  LibTexto in '..\comum\LibTexto.pas',
  UEntidade in '..\comum\UEntidade.pas',
  UPessoa in '..\comum\UPessoa.pas',
  UPagina in '..\comum\UPagina.pas',
  UStatusCep in '..\comum\UStatusCep.pas',
  USistema in '..\comum\USistema.pas',
  UConversorJson in '..\comum\UConversorJson.pas',
  UrotValidacaoDocumento in '..\comum\UrotValidacaoDocumento.pas',
  UrotValidacaoPessoa in '..\comum\UrotValidacaoPessoa.pas',
  LibPlanilhaClientes in '..\cliente\Lib\LibPlanilhaClientes.pas';

var
  GFalhas: Integer = 0;

procedure Verificar(ACondicao: Boolean; const ADescricao: string);
begin
  if ACondicao then
    Writeln('[OK]    ', ADescricao)
  else
  begin
    Writeln('[FALHA] ', ADescricao);
    Inc(GFalhas);
  end;
end;

procedure TestarDocumentos;
var
  LCpf, LCnpj: IValidadorDocumento;
begin
  LCpf := TFabricaValidadorDocumento.Criar(npFisica);
  LCnpj := TFabricaValidadorDocumento.Criar(npJuridica);
  Verificar(LCpf.EhValido('529.982.247-25'), 'CPF valido com mascara');
  Verificar(not LCpf.EhValido('529.982.247-24'), 'CPF com digito errado');
  Verificar(not LCpf.EhValido('111.111.111-11'), 'CPF com digitos repetidos');
  Verificar(not LCpf.EhValido('123'), 'CPF curto');
  Verificar(LCnpj.EhValido('11.222.333/0001-81'), 'CNPJ valido');
  Verificar(not LCnpj.EhValido('11.222.333/0001-80'), 'CNPJ com digito errado');
  Verificar(LCpf.CompletarDigitosVerificadores('529982247') = '52998224725', 'Completar digitos CPF');
end;

function CriarPessoaValida: TPessoa;
begin
  Result := TPessoa.Create;
  Result.Natureza := npFisica;
  Result.Documento := '529.982.247-25';
  Result.PrimeiroNome := '  Jo'#$00E3'o ';
  Result.SegundoNome := 'Concei'#$00E7#$00E3'o';
  Result.DataRegistro := EncodeDate(2026, 9, 27);
  Result.AdicionarEndereco('01001-000');
end;

procedure TestarValidacaoPessoa;
var
  LPessoa: TPessoa;
  LLote: TObjectList<TPessoa>;
  LMensagem: string;
begin
  LPessoa := CriarPessoaValida;
  try
    TPessoaValidador.Normalizar(LPessoa);
    Verificar(LPessoa.Documento = '52998224725', 'Normaliza documento');
    Verificar(LPessoa.PrimeiroNome = 'Jo'#$00E3'o', 'Normaliza nome (trim, acento)');
    Verificar(LPessoa.Enderecos[0].Cep = '01001000', 'Normaliza CEP');
    Verificar(Length(TPessoaValidador.Inconsistencias(LPessoa)) = 0, 'Pessoa valida sem inconsistencias');

    LPessoa.Enderecos.Clear;
    Verificar(Length(TPessoaValidador.Inconsistencias(LPessoa)) = 1, 'Pessoa sem endereco e rejeitada (R6)');
  finally
    LPessoa.Free;
  end;

  LLote := TObjectList<TPessoa>.Create(True);
  try
    LLote.Add(CriarPessoaValida);
    LLote.Add(CriarPessoaValida);
    LLote[1].Documento := '000';
    LLote[1].Enderecos.Clear;
    LMensagem := '';
    try
      TPessoaValidador.ValidarLote(LLote);
    except
      on E: EValidacao do
        LMensagem := E.Message + ' | ' + string.Join(' | ', E.Detalhes);
    end;
    Verificar(Pos('1 registro(s)', LMensagem) > 0, 'Lote conta registros invalidos: ' + LMensagem);
    Verificar(Pos('Registro 2', LMensagem) > 0, 'Lote identifica o registro invalido');
  finally
    LLote.Free;
  end;
end;

procedure TestarJson;
var
  LPessoa, LCopia: TPessoa;
  LJson: TJSONObject;
  LTexto: string;
  LValor: TJSONValue;
  LStatus, LStatusCopia: TStatusAtualizacaoCep;
begin
  LPessoa := CriarPessoaValida;
  try
    LPessoa.Id := 42;
    LPessoa.Enderecos[0].Id := 7;
    LPessoa.Enderecos[0].Integracao := TEnderecoIntegracao.Create;
    LPessoa.Enderecos[0].Integracao.Uf := 'SP';
    LPessoa.Enderecos[0].Integracao.Cidade := 'S'#$00E3'o Paulo';

    LJson := TPessoaJson.ParaJson(LPessoa);
    try
      LTexto := LJson.ToJSON;
    finally
      LJson.Free;
    end;
    Writeln('        JSON: ', LTexto);
  finally
    LPessoa.Free;
  end;

  LValor := TJSONObject.ParseJSONValue(LTexto);
  try
    LCopia := TPessoaJson.DeJson(LValor as TJSONObject);
    try
      Verificar(LCopia.Id = 42, 'JSON ida e volta: id');
      Verificar(LCopia.SegundoNome = 'Concei'#$00E7#$00E3'o', 'JSON ida e volta: acentos');
      Verificar(LCopia.DataRegistro = EncodeDate(2026, 9, 27), 'JSON ida e volta: data');
      Verificar((LCopia.Enderecos.Count = 1) and (LCopia.Enderecos[0].Id = 7), 'JSON ida e volta: endereco');
      Verificar(LCopia.Enderecos[0].PossuiIntegracao and
        (LCopia.Enderecos[0].Integracao.Cidade = 'S'#$00E3'o Paulo'), 'JSON ida e volta: integracao');
    finally
      LCopia.Free;
    end;
  finally
    LValor.Free;
  end;

  LValor := TJSONObject.ParseJSONValue('{"natureza": 3, "documento": "x"}');
  try
    try
      TPessoaJson.DeJson(LValor as TJSONObject).Free;
      Verificar(False, 'Natureza invalida deveria gerar EValidacao');
    except
      on E: EValidacao do
        Verificar(True, 'Natureza invalida gera EValidacao: ' + E.Message);
    end;
  finally
    LValor.Free;
  end;

  LStatus := TStatusAtualizacaoCep.Create;
  try
    LStatus.EmExecucao := True;
    LStatus.TotalCeps := 4;
    LStatus.CepsProcessados := 1;
    LStatus.Inicio := EncodeDate(2026, 9, 27) + EncodeTime(10, 30, 0, 0);
    LJson := TStatusAtualizacaoCepJson.ParaJson(LStatus);
    try
      LStatusCopia := TStatusAtualizacaoCepJson.DeJson(LJson);
      try
        Verificar(LStatusCopia.EmExecucao and (LStatusCopia.PercentualConcluido = 25), 'Status JSON: execucao/percentual');
        Verificar(Abs(LStatusCopia.Inicio - LStatus.Inicio) < (1 / 86400), 'Status JSON: data/hora ISO 8601');
      finally
        LStatusCopia.Free;
      end;
    finally
      LJson.Free;
    end;
  finally
    LStatus.Free;
  end;
end;

procedure TestarPagina;
var
  LPagina: TPagina<TPessoa>;
begin
  LPagina := TPagina<TPessoa>.Create(1, 100);
  try
    LPagina.TotalRegistros := 50001;
    Verificar(LPagina.TotalPaginas = 501, 'Pagina: total de paginas');
  finally
    LPagina.Free;
  end;
  Verificar(TTexto.FormatarDocumento('11222333000181') = '11.222.333/0001-81', 'Formatar CNPJ');
end;

function LocalizarArquivo(const ACandidatos: array of string): string;
var
  LCandidato: string;
begin
  for LCandidato in ACandidatos do
  begin
    Result := ExpandFileName(ExtractFilePath(ParamStr(0)) + LCandidato);
    if FileExists(Result) then
      Exit;
  end;
  raise Exception.Create('Arquivo não encontrado: ' + ACandidatos[0]);
end;

procedure TestarPlanilhaModelo;
var
  LImportacao: TImportacaoPlanilha;
  LPessoa: TPessoa;
  LComDoisCeps: Integer;
begin
  LImportacao := TLeitorPlanilhaClientes.Ler(LocalizarArquivo(['..\..\..\modelos\clientes_modelo.xlsx',
    '..\modelos\clientes_modelo.xlsx']));
  try
    Verificar(LImportacao.Pessoas.Count = 200, Format('Planilha modelo: 200 clientes lidos (lidos %d)',
      [LImportacao.Pessoas.Count]));
    Verificar(LImportacao.Inconsistencias.Count = 0, 'Planilha modelo: nenhuma inconsistência');
    LComDoisCeps := 0;
    for LPessoa in LImportacao.Pessoas do
      if LPessoa.Enderecos.Count = 2 then
        Inc(LComDoisCeps);
    Verificar(LComDoisCeps = 20, 'Planilha modelo: 20 clientes com dois CEPs');
    Verificar(LImportacao.LinhaDoRegistro(1) = 2, 'Planilha modelo: registro 1 corresponde à linha 2');
  finally
    LImportacao.Free;
  end;
end;

procedure TestarPlanilhaComErros;
var
  LImportacao: TImportacaoPlanilha;
  LTexto: string;
begin
  LImportacao := TLeitorPlanilhaClientes.Ler(LocalizarArquivo(['..\..\planilha_teste.xlsx', 'planilha_teste.xlsx']));
  try
    LTexto := string.Join(' | ', LImportacao.Inconsistencias.ToArray);
    Writeln('        Inconsistências: ', LTexto);
    Verificar(LImportacao.Pessoas.Count = 3, Format('Planilha com erros: 3 clientes válidos (lidos %d)',
      [LImportacao.Pessoas.Count]));
    Verificar(LImportacao.Inconsistencias.Count = 5, Format('Planilha com erros: 5 inconsistências (encontradas %d)',
      [LImportacao.Inconsistencias.Count]));
    Verificar(Pos('Linha 5: natureza', LTexto) > 0, 'Planilha com erros: natureza inválida na linha 5');
    Verificar(Pos('Linha 6: CPF inválido', LTexto) > 0, 'Planilha com erros: CPF inválido na linha 6');
    Verificar(Pos('Linha 7: CPF 529.982.247-25 repetido na linha 2', LTexto) > 0, 'Planilha com erros: CPF repetido');
    Verificar(Pos('Linha 9:', LTexto) > 0, 'Planilha com erros: linha 9 sem sobrenome e sem CEP');
    Verificar((LImportacao.Pessoas.Count > 1) and (LImportacao.Pessoas[1].Documento = '01234567890'),
      'Planilha com erros: CPF numérico recupera o zero à esquerda');
    Verificar((LImportacao.Pessoas.Count > 2) and (LImportacao.Pessoas[2].Enderecos.Count = 2),
      'Planilha com erros: CNPJ com dois CEPs separados por ponto e vírgula');
    Verificar(LImportacao.LinhaDoRegistro(3) = 8, 'Planilha com erros: registro 3 corresponde à linha 8');
  finally
    LImportacao.Free;
  end;
end;

begin
  ReportMemoryLeaksOnShutdown := True;
  try
    TestarDocumentos;
    TestarValidacaoPessoa;
    TestarJson;
    TestarPagina;
    TestarPlanilhaModelo;
    TestarPlanilhaComErros;
  except
    on E: Exception do
    begin
      Writeln('[ERRO]  ', E.ClassName, ': ', E.Message);
      Inc(GFalhas);
    end;
  end;
  Writeln;
  Writeln('Falhas: ', GFalhas);
  ExitCode := GFalhas;
  Writeln('Pressione ENTER para sair.');
  Readln;
end.
