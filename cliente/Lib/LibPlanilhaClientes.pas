unit LibPlanilhaClientes;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  UPessoa;

type
  TImportacaoPlanilha = class
  private
    FPessoas: TObjectList<TPessoa>;
    FLinhas: TList<Integer>;
    FInconsistencias: TList<string>;
  public
    constructor Create;
    destructor Destroy; override;
    function LinhaDoRegistro(ANumeroRegistro: Integer): Integer;
    property Pessoas: TObjectList<TPessoa> read FPessoas;
    property Linhas: TList<Integer> read FLinhas;
    property Inconsistencias: TList<string> read FInconsistencias;
  end;

  TLeitorPlanilhaClientes = class abstract
  private const
    COLUNA_NATUREZA = 0;
    COLUNA_DOCUMENTO = 1;
    COLUNA_PRIMEIRO_NOME = 2;
    COLUNA_SEGUNDO_NOME = 3;
    COLUNA_CEP = 4;
    QUANTIDADE_COLUNAS = 5;
    LINHA_CABECALHO = 1;
    TAMANHO_CEP = 8;
  private
    class function ConverterNatureza(const ATexto: string; out ANatureza: TNaturezaPessoa): Boolean; static;
    class function CompletarZeros(const ATexto: string; ATamanho: Integer): string; static;
    class procedure ProcessarLinha(AImportacao: TImportacaoPlanilha; ALinha: Integer;
      const AValores: TArray<string>; ADocumentosLidos: TDictionary<string, Integer>); static;
  public
    class function Ler(const AArquivo: string): TImportacaoPlanilha; static;
  end;

implementation

uses
  System.Classes,
  System.Zip,
  System.Variants,
  Xml.xmldom,
  Xml.XMLIntf,
  Xml.XMLDoc,
  Xml.omnixmldom,
  UExcecoes,
  LibTexto,
  UrotValidacaoPessoa,
  UrotValidacaoDocumento;

type
  TLinhaPlanilha = record
    Numero: Integer;
    Valores: TArray<string>;
  end;

  TLeitorXlsx = class
  private
    FZip: TZipFile;
    FTextosCompartilhados: TList<string>;
    function LerXml(const AEntrada: string): IXMLDocument;
    function CaminhoPrimeiraPlanilha: string;
    procedure CarregarTextosCompartilhados;
    function TextoDaCelula(ACelula: IXMLNode): string;
    class function Filhos(ANo: IXMLNode; const ANome: string): TArray<IXMLNode>; static;
    class function Filho(ANo: IXMLNode; const ANome: string): IXMLNode; static;
    class function Atributo(ANo: IXMLNode; const ANome: string): string; static;
    class function TextoConcatenado(ANo: IXMLNode): string; static;
    class function IndiceColuna(const AReferencia: string): Integer; static;
    class function NumeroComoTexto(const AValor: string): string; static;
  public
    constructor Create(const AArquivo: string);
    destructor Destroy; override;
    function LerLinhas(AQuantidadeColunas: Integer): TList<TLinhaPlanilha>;
  end;

constructor TImportacaoPlanilha.Create;
begin
  inherited Create;
  FPessoas := TObjectList<TPessoa>.Create(True);
  FLinhas := TList<Integer>.Create;
  FInconsistencias := TList<string>.Create;
end;

destructor TImportacaoPlanilha.Destroy;
begin
  FInconsistencias.Free;
  FLinhas.Free;
  FPessoas.Free;
  inherited;
end;

function TImportacaoPlanilha.LinhaDoRegistro(ANumeroRegistro: Integer): Integer;
begin
  if (ANumeroRegistro >= 1) and (ANumeroRegistro <= FLinhas.Count) then
    Result := FLinhas[ANumeroRegistro - 1]
  else
    Result := 0;
end;

constructor TLeitorXlsx.Create(const AArquivo: string);
begin
  inherited Create;
  DefaultDOMVendor := sOmniXmlVendor;
  FTextosCompartilhados := TList<string>.Create;
  FZip := TZipFile.Create;
  try
    FZip.Open(AArquivo, zmRead);
  except
    on E: Exception do
      raise EAplicacao.CreateFmt('O arquivo não é uma planilha Excel (.xlsx) válida: %s', [E.Message]);
  end;
  CarregarTextosCompartilhados;
end;

destructor TLeitorXlsx.Destroy;
begin
  FZip.Free;
  FTextosCompartilhados.Free;
  inherited;
end;

function TLeitorXlsx.LerXml(const AEntrada: string): IXMLDocument;
var
  LBytes: TBytes;
  LConteudo: TBytesStream;
begin
  if FZip.IndexOf(AEntrada) < 0 then
    raise EAplicacao.CreateFmt('A planilha não contém a parte "%s".', [AEntrada]);
  FZip.Read(AEntrada, LBytes);
  LConteudo := TBytesStream.Create(LBytes);
  try
    Result := TXMLDocument.Create(nil);
    Result.LoadFromStream(LConteudo);
  finally
    LConteudo.Free;
  end;
end;

class function TLeitorXlsx.Filhos(ANo: IXMLNode; const ANome: string): TArray<IXMLNode>;
var
  LLista: TList<IXMLNode>;
  I: Integer;
begin
  LLista := TList<IXMLNode>.Create;
  try
    if ANo <> nil then
      for I := 0 to ANo.ChildNodes.Count - 1 do
        if (ANo.ChildNodes[I].NodeType = ntElement) and SameText(ANo.ChildNodes[I].LocalName, ANome) then
          LLista.Add(ANo.ChildNodes[I]);
    Result := LLista.ToArray;
  finally
    LLista.Free;
  end;
end;

class function TLeitorXlsx.Filho(ANo: IXMLNode; const ANome: string): IXMLNode;
var
  LFilhos: TArray<IXMLNode>;
begin
  LFilhos := Filhos(ANo, ANome);
  if Length(LFilhos) > 0 then
    Result := LFilhos[0]
  else
    Result := nil;
end;

class function TLeitorXlsx.Atributo(ANo: IXMLNode; const ANome: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to ANo.AttributeNodes.Count - 1 do
    if SameText(ANo.AttributeNodes[I].LocalName, ANome) then
      Exit(VarToStr(ANo.AttributeNodes[I].NodeValue));
end;

class function TLeitorXlsx.TextoConcatenado(ANo: IXMLNode): string;
var
  I: Integer;
  LFilho: IXMLNode;
begin
  Result := '';
  for I := 0 to ANo.ChildNodes.Count - 1 do
  begin
    LFilho := ANo.ChildNodes[I];
    if LFilho.NodeType <> ntElement then
      Continue;
    if SameText(LFilho.LocalName, 't') then
      Result := Result + LFilho.Text
    else if not SameText(LFilho.LocalName, 'rPh') then
      Result := Result + TextoConcatenado(LFilho);
  end;
end;

class function TLeitorXlsx.IndiceColuna(const AReferencia: string): Integer;
var
  LCaractere: Char;
begin
  Result := 0;
  for LCaractere in UpperCase(AReferencia) do
  begin
    if not CharInSet(LCaractere, ['A'..'Z']) then
      Break;
    Result := Result * 26 + (Ord(LCaractere) - Ord('A') + 1);
  end;
  Dec(Result);
end;

class function TLeitorXlsx.NumeroComoTexto(const AValor: string): string;
var
  LNumero: Double;
begin
  if (Pos('E', UpperCase(AValor)) > 0) or (Pos('.', AValor) > 0) then
  begin
    if TryStrToFloat(AValor, LNumero, TFormatSettings.Invariant) then
      Exit(FormatFloat('0', LNumero, TFormatSettings.Invariant));
  end;
  Result := AValor;
end;

procedure TLeitorXlsx.CarregarTextosCompartilhados;
var
  LDocumento: IXMLDocument;
  LItem: IXMLNode;
begin
  if FZip.IndexOf('xl/sharedStrings.xml') < 0 then
    Exit;
  LDocumento := LerXml('xl/sharedStrings.xml');
  for LItem in Filhos(LDocumento.DocumentElement, 'si') do
    FTextosCompartilhados.Add(TextoConcatenado(LItem));
end;

function TLeitorXlsx.CaminhoPrimeiraPlanilha: string;
var
  LLivro, LRelacoes: IXMLDocument;
  LPlanilhas: TArray<IXMLNode>;
  LIdRelacao, LDestino: string;
  LRelacao: IXMLNode;
begin
  LLivro := LerXml('xl/workbook.xml');
  LPlanilhas := Filhos(Filho(LLivro.DocumentElement, 'sheets'), 'sheet');
  if Length(LPlanilhas) = 0 then
    raise EAplicacao.Create('A planilha não possui abas.');
  LIdRelacao := Atributo(LPlanilhas[0], 'id');

  LRelacoes := LerXml('xl/_rels/workbook.xml.rels');
  for LRelacao in Filhos(LRelacoes.DocumentElement, 'Relationship') do
    if Atributo(LRelacao, 'Id') = LIdRelacao then
    begin
      LDestino := Atributo(LRelacao, 'Target').Replace('\', '/');
      if LDestino.StartsWith('/') then
        Exit(LDestino.Substring(1));
      Exit('xl/' + LDestino);
    end;
  raise EAplicacao.Create('Não foi possível localizar a primeira aba da planilha.');
end;

function TLeitorXlsx.TextoDaCelula(ACelula: IXMLNode): string;
var
  LTipo: string;
  LValor: IXMLNode;
  LIndice: Integer;
begin
  LTipo := Atributo(ACelula, 't');
  if SameText(LTipo, 'inlineStr') then
    Exit(TextoConcatenado(Filho(ACelula, 'is')));

  LValor := Filho(ACelula, 'v');
  if LValor = nil then
    Exit('');
  Result := LValor.Text;
  if SameText(LTipo, 's') then
  begin
    if TryStrToInt(Result, LIndice) and (LIndice >= 0) and (LIndice < FTextosCompartilhados.Count) then
      Result := FTextosCompartilhados[LIndice]
    else
      Result := '';
  end
  else if (LTipo = '') or SameText(LTipo, 'n') then
    Result := NumeroComoTexto(Result);
end;

function TLeitorXlsx.LerLinhas(AQuantidadeColunas: Integer): TList<TLinhaPlanilha>;
var
  LPlanilha: IXMLDocument;
  LLinhaXml, LCelula: IXMLNode;
  LLinha: TLinhaPlanilha;
  LProximoNumero, LColuna: Integer;
begin
  LPlanilha := LerXml(CaminhoPrimeiraPlanilha);
  Result := TList<TLinhaPlanilha>.Create;
  try
    LProximoNumero := 1;
    for LLinhaXml in Filhos(Filho(LPlanilha.DocumentElement, 'sheetData'), 'row') do
    begin
      LLinha.Numero := StrToIntDef(Atributo(LLinhaXml, 'r'), LProximoNumero);
      LProximoNumero := LLinha.Numero + 1;
      LLinha.Valores := nil;
      SetLength(LLinha.Valores, AQuantidadeColunas);
      for LColuna := 0 to AQuantidadeColunas - 1 do
        LLinha.Valores[LColuna] := '';
      LColuna := 0;
      for LCelula in Filhos(LLinhaXml, 'c') do
      begin
        if Atributo(LCelula, 'r') <> '' then
          LColuna := IndiceColuna(Atributo(LCelula, 'r'));
        if (LColuna >= 0) and (LColuna < AQuantidadeColunas) then
          LLinha.Valores[LColuna] := Trim(TextoDaCelula(LCelula));
        Inc(LColuna);
      end;
      Result.Add(LLinha);
    end;
  except
    Result.Free;
    raise;
  end;
end;

class function TLeitorPlanilhaClientes.ConverterNatureza(const ATexto: string; out ANatureza: TNaturezaPessoa): Boolean;
var
  LInicial: string;
begin
  LInicial := UpperCase(Copy(Trim(ATexto), 1, 1));
  Result := True;
  if (LInicial = 'F') or (LInicial = '1') then
    ANatureza := npFisica
  else if (LInicial = 'J') or (LInicial = '2') then
    ANatureza := npJuridica
  else
    Result := False;
end;

class function TLeitorPlanilhaClientes.CompletarZeros(const ATexto: string; ATamanho: Integer): string;
begin
  Result := TTexto.SomenteDigitos(ATexto);
  if (Result = Trim(ATexto)) and (Result <> '') and (Length(Result) < ATamanho) then
    Result := StringOfChar('0', ATamanho - Length(Result)) + Result
  else
    Result := Trim(ATexto);
end;

class procedure TLeitorPlanilhaClientes.ProcessarLinha(AImportacao: TImportacaoPlanilha; ALinha: Integer;
  const AValores: TArray<string>; ADocumentosLidos: TDictionary<string, Integer>);
var
  LPessoa: TPessoa;
  LNatureza: TNaturezaPessoa;
  LCep, LInconsistencia: string;
  LLinhaAnterior: Integer;
  LValida: Boolean;
begin
  if not ConverterNatureza(AValores[COLUNA_NATUREZA], LNatureza) then
  begin
    AImportacao.Inconsistencias.Add(Format('Linha %d: natureza "%s" inválida. Use Física ou Jurídica.',
      [ALinha, AValores[COLUNA_NATUREZA]]));
    Exit;
  end;

  LPessoa := TPessoa.Create;
  try
    LPessoa.Natureza := LNatureza;
    LPessoa.Documento := CompletarZeros(AValores[COLUNA_DOCUMENTO],
      TFabricaValidadorDocumento.Criar(LNatureza).Tamanho);
    LPessoa.PrimeiroNome := AValores[COLUNA_PRIMEIRO_NOME];
    LPessoa.SegundoNome := AValores[COLUNA_SEGUNDO_NOME];
    for LCep in AValores[COLUNA_CEP].Split([';', ',']) do
      if Trim(LCep) <> '' then
        LPessoa.AdicionarEndereco(CompletarZeros(LCep, TAMANHO_CEP));

    TPessoaValidador.Normalizar(LPessoa);
    LValida := True;
    for LInconsistencia in TPessoaValidador.Inconsistencias(LPessoa) do
    begin
      AImportacao.Inconsistencias.Add(Format('Linha %d: %s', [ALinha, LInconsistencia]));
      LValida := False;
    end;
    if (LPessoa.Documento <> '') and ADocumentosLidos.TryGetValue(LPessoa.Documento, LLinhaAnterior) then
    begin
      AImportacao.Inconsistencias.Add(Format('Linha %d: %s %s repetido na linha %d.', [ALinha,
        TFabricaValidadorDocumento.Criar(LNatureza).NomeDocumento, TTexto.FormatarDocumento(LPessoa.Documento),
        LLinhaAnterior]));
      LValida := False;
    end
    else if LPessoa.Documento <> '' then
      ADocumentosLidos.Add(LPessoa.Documento, ALinha);

    if LValida then
    begin
      AImportacao.Pessoas.Add(LPessoa);
      AImportacao.Linhas.Add(ALinha);
      LPessoa := nil;
    end;
  finally
    LPessoa.Free;
  end;
end;

class function TLeitorPlanilhaClientes.Ler(const AArquivo: string): TImportacaoPlanilha;
var
  LLeitor: TLeitorXlsx;
  LLinhas: TList<TLinhaPlanilha>;
  LDocumentosLidos: TDictionary<string, Integer>;
  LLinha: TLinhaPlanilha;
begin
  Result := TImportacaoPlanilha.Create;
  try
    LLeitor := TLeitorXlsx.Create(AArquivo);
    try
      LLinhas := LLeitor.LerLinhas(QUANTIDADE_COLUNAS);
    finally
      LLeitor.Free;
    end;

    LDocumentosLidos := TDictionary<string, Integer>.Create;
    try
      for LLinha in LLinhas do
      begin
        if LLinha.Numero = LINHA_CABECALHO then
          Continue;
        if string.Join('', LLinha.Valores).Trim = '' then
          Continue;
        ProcessarLinha(Result, LLinha.Numero, LLinha.Valores, LDocumentosLidos);
      end;
    finally
      LDocumentosLidos.Free;
      LLinhas.Free;
    end;

    if (Result.Pessoas.Count = 0) and (Result.Inconsistencias.Count = 0) then
      Result.Inconsistencias.Add('A planilha não possui clientes a partir da linha 2.');
  except
    Result.Free;
    raise;
  end;
end;

end.
