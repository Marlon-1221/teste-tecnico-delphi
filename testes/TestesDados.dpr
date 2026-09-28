program TestesDados;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Diagnostics,
  System.Generics.Collections,
  FireDAC.Comp.Client,
  UExcecoes in '..\comum\UExcecoes.pas',
  LibTexto in '..\comum\LibTexto.pas',
  UEntidade in '..\comum\UEntidade.pas',
  UPessoa in '..\comum\UPessoa.pas',
  USistema in '..\comum\USistema.pas',
  UrotValidacaoDocumento in '..\comum\UrotValidacaoDocumento.pas',
  UConfiguracao in '..\servidor\Infra\UConfiguracao.pas',
  UConexao in '..\servidor\Infra\UConexao.pas',
  URepositorioBase in '..\servidor\Dados\URepositorioBase.pas',
  URepositorioPessoa in '..\servidor\Dados\URepositorioPessoa.pas',
  URepositorioEndereco in '..\servidor\Dados\URepositorioEndereco.pas',
  URepositorioIntegracao in '..\servidor\Dados\URepositorioIntegracao.pas',
  URepositorioSistema in '..\servidor\Dados\URepositorioSistema.pas',
  UUnidadeTrabalho in '..\servidor\Dados\UUnidadeTrabalho.pas';

const
  QUANTIDADE_LOTE = 50000;

var
  GFalhas: Integer = 0;
  GConfiguracao: TConfiguracaoServidor = nil;
  GFabricaConexao: IFabricaConexao;
  GFabricaUnidade: IFabricaUnidadeTrabalho;

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

function LocalizarConfiguracao: string;
const
  CANDIDATOS: array[0..2] of string = ('Servidor.ini', '..\..\..\servidor\Servidor.ini', '..\servidor\Servidor.ini');
var
  LCandidato: string;
begin
  for LCandidato in CANDIDATOS do
  begin
    Result := ExpandFileName(ExtractFilePath(ParamStr(0)) + LCandidato);
    if FileExists(Result) then
      Exit;
  end;
  raise Exception.Create('Servidor.ini não encontrado. Procurado a partir de ' + ExtractFilePath(ParamStr(0)));
end;

function ExecutarEscalar(const ASql: string): Int64;
var
  LConexao: TFDConnection;
begin
  LConexao := GFabricaConexao.CriarConexao;
  try
    Result := LConexao.ExecSQLScalar(ASql);
  finally
    LConexao.Free;
  end;
end;

procedure ExecutarComando(const ASql: string);
var
  LConexao: TFDConnection;
begin
  LConexao := GFabricaConexao.CriarConexao;
  try
    LConexao.ExecSQL(ASql);
  finally
    LConexao.Free;
  end;
end;

function GerarCpf(ASequencial: Integer): string;
begin
  Result := TFabricaValidadorDocumento.Criar(npFisica).CompletarDigitosVerificadores(Format('%.9d', [ASequencial]));
end;

function CriarPessoa(ASequencial: Integer; const ACeps: array of string): TPessoa;
var
  LCep: string;
begin
  Result := TPessoa.Create;
  Result.Natureza := npFisica;
  Result.Documento := GerarCpf(ASequencial);
  Result.PrimeiroNome := 'Jo' + #$00E3 + 'o ' + IntToStr(ASequencial);
  Result.SegundoNome := 'Concei' + #$00E7#$00E3 + 'o';
  Result.DataRegistro := Date;
  for LCep in ACeps do
    Result.AdicionarEndereco(LCep);
end;

procedure TestarConexao;
begin
  Verificar(ExecutarEscalar('select 1') = 1, 'Conexão FireDAC com o PostgreSQL');
end;

procedure TestarTransacao;
var
  LAntes: Int64;
  LPessoa: TPessoa;
  LUnidade: IUnidadeTrabalho;
begin
  LAntes := ExecutarEscalar('select count(*) from pessoa');
  LPessoa := CriarPessoa(1, ['01001000']);
  try
    LUnidade := GFabricaUnidade.Criar;
    try
      LUnidade.ExecutarEmTransacao(
        procedure(AUnidade: IUnidadeTrabalho)
        begin
          AUnidade.Pessoas.Inserir(LPessoa);
          AUnidade.Enderecos.InserirDaPessoa(LPessoa);
          raise EAplicacao.Create('falha simulada após gravar');
        end);
    except
      on E: EAplicacao do
        ;
    end;
  finally
    LPessoa.Free;
  end;
  Verificar(ExecutarEscalar('select count(*) from pessoa') = LAntes,
    'Rollback: falha no meio da transação não deixa pessoa gravada (integridade)');
end;

procedure TestarCrud;
var
  LUnidade: IUnidadeTrabalho;
  LPessoa, LLida: TPessoa;
  LIdPessoa, LIdMantido, LIdRemovido: Int64;
  LIntegracao: TEnderecoIntegracao;
begin
  LUnidade := GFabricaUnidade.Criar;

  LPessoa := CriarPessoa(2, ['01001000', '20040020']);
  try
    LUnidade.ExecutarEmTransacao(
      procedure(AUnidade: IUnidadeTrabalho)
      begin
        AUnidade.Pessoas.Inserir(LPessoa);
        AUnidade.Enderecos.InserirDaPessoa(LPessoa);
      end);
    LIdPessoa := LPessoa.Id;
    LIdMantido := LPessoa.Enderecos[0].Id;
    LIdRemovido := LPessoa.Enderecos[1].Id;
    Verificar((LIdPessoa > 0) and (LIdMantido > 0) and (LIdRemovido > 0), 'Insert: IDs retornados (returning)');
  finally
    LPessoa.Free;
  end;

  LIntegracao := TEnderecoIntegracao.Create;
  try
    LIntegracao.Uf := 'SP';
    LIntegracao.Cidade := 'S' + #$00E3 + 'o Paulo';
    LIntegracao.Bairro := 'S' + #$00E9;
    LIntegracao.Logradouro := 'Pra' + #$00E7 + 'a da S' + #$00E9;
    LUnidade.Integracoes.Salvar([LIdMantido, -999], LIntegracao);
    LIntegracao.Complemento := 'lado ' + #$00ED + 'mpar';
    LUnidade.Integracoes.Salvar([LIdMantido], LIntegracao);
  finally
    LIntegracao.Free;
  end;

  LLida := LUnidade.Pessoas.BuscarPorId(LIdPessoa);
  try
    Verificar(LLida <> nil, 'BuscarPorId encontra a pessoa');
    LUnidade.Enderecos.CarregarDasPessoas([LLida]);
    Verificar(LLida.SegundoNome = 'Concei' + #$00E7#$00E3 + 'o', 'Acentos gravados e lidos (UTF8)');
    Verificar(LLida.Enderecos.Count = 2, 'Endereços carregados');
    Verificar(LLida.Enderecos[0].PossuiIntegracao and
      (LLida.Enderecos[0].Integracao.Complemento = 'lado ' + #$00ED + 'mpar'),
      'Integração gravada via UPSERT (insere e atualiza)');

    LLida.PrimeiroNome := 'Maria';
    LLida.Enderecos[0].Cep := '30130010';
    LLida.Enderecos.Delete(1);
    LLida.AdicionarEndereco('40020000');
    LUnidade.ExecutarEmTransacao(
      procedure(AUnidade: IUnidadeTrabalho)
      begin
        Verificar(AUnidade.Pessoas.Atualizar(LLida), 'Update: pessoa atualizada');
        AUnidade.Enderecos.SincronizarDaPessoa(LLida);
      end);
  finally
    LLida.Free;
  end;

  LLida := LUnidade.Pessoas.BuscarPorId(LIdPessoa);
  try
    LUnidade.Enderecos.CarregarDasPessoas([LLida]);
    Verificar(LLida.PrimeiroNome = 'Maria', 'Update: nome alterado');
    Verificar((LLida.Enderecos.Count = 2) and (LLida.Enderecos[0].Id = LIdMantido) and
      (LLida.Enderecos[0].Cep = '30130010'), 'Update: endereço mantido com CEP alterado');
    Verificar(not LLida.Enderecos[0].PossuiIntegracao, 'Update: integração descartada ao trocar o CEP');
    Verificar(LLida.Enderecos[1].Cep = '40020000', 'Update: novo endereço incluído');
  finally
    LLida.Free;
  end;
  Verificar(ExecutarEscalar('select count(*) from endereco where idendereco = ' + IntToStr(LIdRemovido)) = 0,
    'Update: endereço removido excluído');

  Verificar(LUnidade.Pessoas.Excluir(LIdPessoa), 'Delete: pessoa excluída');
  Verificar(ExecutarEscalar('select count(*) from endereco where idpessoa = ' + IntToStr(LIdPessoa)) = 0,
    'Delete: endereços removidos em cascata');
  Verificar(not LUnidade.Pessoas.Excluir(LIdPessoa), 'Delete: segunda exclusão informa inexistente');
end;

procedure TestarLote;
var
  LPessoas: TObjectList<TPessoa>;
  LUnidade: IUnidadeTrabalho;
  LCronometro: TStopwatch;
  LPrimeiro, LUltimo: Int64;
  LEnderecos: TObjectList<TEndereco>;
  I: Integer;
begin
  LPessoas := TObjectList<TPessoa>.Create(True);
  try
    for I := 1 to QUANTIDADE_LOTE do
      LPessoas.Add(CriarPessoa(100000 + I, ['01001000']));

    LUnidade := GFabricaUnidade.Criar;
    LCronometro := TStopwatch.StartNew;
    LUnidade.ExecutarEmTransacao(
      procedure(AUnidade: IUnidadeTrabalho)
      begin
        AUnidade.Pessoas.InserirLote(LPessoas);
        AUnidade.Enderecos.InserirLote(LPessoas);
      end);
    LCronometro.Stop;
    Writeln(Format('        Lote de %d pessoas + %d endereços gravado em %d ms',
      [QUANTIDADE_LOTE, QUANTIDADE_LOTE, LCronometro.ElapsedMilliseconds]));

    LPrimeiro := LPessoas.First.Id;
    LUltimo := LPessoas.Last.Id;
    Verificar(ExecutarEscalar(Format('select count(*) from pessoa where idpessoa between %d and %d',
      [LPrimeiro, LUltimo])) = QUANTIDADE_LOTE, 'Lote: todas as pessoas gravadas');
    Verificar(ExecutarEscalar(Format(
      'select count(*) from pessoa p where p.idpessoa between %d and %d ' +
      'and not exists (select 1 from endereco e where e.idpessoa = p.idpessoa)',
      [LPrimeiro, LUltimo])) = 0, 'Lote: nenhuma pessoa sem endereço');

    LEnderecos := LUnidade.Enderecos.ListarParaIntegracao(True);
    try
      Verificar(LEnderecos.Count >= QUANTIDADE_LOTE, 'ListarParaIntegracao retorna os endereços pendentes');
    finally
      LEnderecos.Free;
    end;

    ExecutarComando(Format('delete from pessoa where idpessoa between %d and %d', [LPrimeiro, LUltimo]));
    Verificar(ExecutarEscalar(Format('select count(*) from pessoa where idpessoa between %d and %d',
      [LPrimeiro, LUltimo])) = 0, 'Limpeza dos registros do lote');
  finally
    LPessoas.Free;
  end;
end;

procedure Executar(const ANome: string; const ATeste: TProc);
begin
  try
    ATeste();
  except
    on E: Exception do
    begin
      Writeln(Format('[ERRO]  %s: %s: %s', [ANome, E.ClassName, E.Message]));
      Inc(GFalhas);
    end;
  end;
end;

begin
  ReportMemoryLeaksOnShutdown := True;
  try
    {$IFNDEF WIN64}
    raise Exception.Create('Compile para Windows 64-bit: a libpq.dll do PostgreSQL instalado é 64 bits.');
    {$ENDIF}
    GConfiguracao := TConfiguracaoServidor.Create(LocalizarConfiguracao);
    GFabricaConexao := TFabricaConexao.Create(GConfiguracao.Banco);
    GFabricaUnidade := TFabricaUnidadeTrabalho.Create(GFabricaConexao);

    Executar('Conexão', TestarConexao);
    Executar('Transação', TestarTransacao);
    Executar('CRUD', TestarCrud);
    Executar('Lote', TestarLote);
  except
    on E: Exception do
    begin
      Writeln('[ERRO]  ', E.ClassName, ': ', E.Message);
      Inc(GFalhas);
    end;
  end;
  GFabricaUnidade := nil;
  GFabricaConexao := nil;
  GConfiguracao.Free;

  Writeln;
  Writeln('Falhas: ', GFalhas);
  ExitCode := GFalhas;
  Writeln('Pressione ENTER para sair.');
  Readln;
end.
