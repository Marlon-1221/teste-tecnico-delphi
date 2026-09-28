<#
  Testes ponta a ponta da API REST (servidor precisa estar em execução).
  Uso:  powershell -ExecutionPolicy Bypass -File testes\TestarServidor.ps1 [-Url http://localhost:9000] [-QuantidadeLote 50000]

  Os registros do CRUD são excluídos ao final. Os do lote são mantidos, pois
  servem de massa para a rotina de atualização de CEPs.
#>
param(
  [string]$Url = 'http://localhost:9000',
  [int]$QuantidadeLote = 50000
)

$ErrorActionPreference = 'Stop'
$script:Falhas = 0
$Utf8 = New-Object System.Text.UTF8Encoding($false)

function Verificar([bool]$Condicao, [string]$Descricao) {
  if ($Condicao) { Write-Host "[OK]    $Descricao" -ForegroundColor Green }
  else { Write-Host "[FALHA] $Descricao" -ForegroundColor Red; $script:Falhas++ }
}

function Chamar([string]$Metodo, [string]$Rota, [string]$Corpo = $null) {
  $req = [System.Net.HttpWebRequest]::Create("$Url$Rota")
  $req.Method = $Metodo
  $req.Timeout = 600000
  $req.ReadWriteTimeout = 600000
  $req.Accept = 'application/json'
  if ($Corpo) {
    $bytes = $Utf8.GetBytes($Corpo)
    $req.ContentType = 'application/json; charset=utf-8'
    $req.ContentLength = $bytes.Length
    $s = $req.GetRequestStream(); $s.Write($bytes, 0, $bytes.Length); $s.Close()
  }
  try { $resp = $req.GetResponse() } catch [System.Net.WebException] {
    $resp = $_.Exception.Response
    if (-not $resp) { throw }
  }
  $leitor = New-Object System.IO.StreamReader($resp.GetResponseStream(), $Utf8)
  $texto = $leitor.ReadToEnd(); $leitor.Close()
  $status = [int]$resp.StatusCode; $resp.Close()
  $json = $null
  if ($texto) { $json = $texto | ConvertFrom-Json }
  return [pscustomobject]@{ Status = $status; Json = $json; Texto = $texto }
}

function Completar-Documento([string]$Base, [int[]]$Pesos1, [int[]]$Pesos2) {
  foreach ($pesos in @($Pesos1, $Pesos2)) {
    $soma = 0
    for ($i = 0; $i -lt $pesos.Length; $i++) { $soma += ([int][string]$Base[$i]) * $pesos[$i] }
    $resto = $soma % 11
    $Base += if ($resto -lt 2) { '0' } else { [string](11 - $resto) }
  }
  return $Base
}
$PesosCpf1 = 10..2; $PesosCpf2 = 11..2
function Gerar-Cpf([int]$Sequencial) { Completar-Documento ('{0:D9}' -f $Sequencial) $PesosCpf1 $PesosCpf2 }

function Documentos-Cadastrados([string[]]$Documentos) {
  $corpo = '[' + (($Documentos | ForEach-Object { '"' + $_ + '"' }) -join ',') + ']'
  $r = Chamar 'POST' '/pessoas/documentos' $corpo
  return @($r.Json)
}

function Cpfs-Livres([int]$Quantidade) {
  $inicio = Get-Random -Minimum 1 -Maximum (999999999 - $Quantidade)
  $cpfs = New-Object 'System.Collections.Generic.List[string]'
  for ($i = 0; $i -lt $Quantidade; $i++) { $cpfs.Add((Gerar-Cpf ($inicio + $i))) }
  $usados = New-Object 'System.Collections.Generic.HashSet[string]'
  foreach ($c in $cpfs) { [void]$usados.Add($c) }
  $conferir = @($cpfs)
  for ($tentativa = 1; $tentativa -le 5 -and $conferir.Count -gt 0; $tentativa++) {
    $existentes = New-Object 'System.Collections.Generic.HashSet[string]'
    foreach ($e in (Documentos-Cadastrados $conferir)) { if ($e) { [void]$existentes.Add($e) } }
    $trocados = @()
    for ($i = 0; $i -lt $cpfs.Count; $i++) {
      if ($existentes.Contains($cpfs[$i])) {
        do { $novo = Gerar-Cpf (Get-Random -Minimum 1 -Maximum 999999999) } while (-not $usados.Add($novo))
        $cpfs[$i] = $novo; $trocados += $novo
      }
    }
    $conferir = $trocados
  }
  return ,$cpfs.ToArray()
}

Write-Host "== API em $Url ==" -ForegroundColor Cyan

# ---------- Insert ----------
$cpfsLivres = Cpfs-Livres 3
$cpf = $cpfsLivres[0]
$corpo = @{ natureza = 1; documento = $cpf; primeiroNome = 'João'; segundoNome = 'Conceição';
            enderecos = @(@{ cep = '01001-000' }, @{ cep = '20040020' }) } | ConvertTo-Json -Depth 5
$r = Chamar 'POST' '/pessoas' $corpo
Verificar ($r.Status -eq 201) "POST /pessoas -> 201 (obtido $($r.Status))"
$id = $r.Json.id
Verificar ($id -gt 0 -and $r.Json.enderecos.Count -eq 2) 'Insert retorna id e endereços'
Verificar ($r.Json.enderecos[0].cep -eq '01001000') 'CEP normalizado (sem máscara)'
Verificar ($r.Json.dataRegistro -eq (Get-Date -Format 'yyyy-MM-dd')) 'dtregistro preenchida pelo servidor'

# ---------- Get ----------
$r = Chamar 'GET' "/pessoas/$id"
Verificar ($r.Status -eq 200 -and $r.Json.segundoNome -eq 'Conceição') 'GET /pessoas/{id} com acentos'

# ---------- Busca ----------
$r = Chamar 'GET' ('/pessoas?tamanho=10&busca=' + $cpf)
Verificar ($r.Status -eq 200 -and $r.Json.totalRegistros -eq 1 -and $r.Json.dados[0].id -eq $id) 'Busca pelo CPF encontra o cliente'
$mascara = '{0}.{1}.{2}' -f $cpf.Substring(0,3), $cpf.Substring(3,3), $cpf.Substring(6,2)
$r = Chamar 'GET' ('/pessoas?tamanho=50&busca=' + [uri]::EscapeDataString($mascara))
Verificar (@($r.Json.dados | Where-Object { $_.id -eq $id }).Count -eq 1) "Busca pelo início do CPF com máscara ($mascara)"
$r = Chamar 'GET' ('/pessoas?tamanho=5&busca=' + [uri]::EscapeDataString('CONCEIÇÃO'))
Verificar ($r.Status -eq 200 -and $r.Json.totalRegistros -ge 1 -and @($r.Json.dados | Where-Object { ($_.primeiroNome + ' ' + $_.segundoNome) -notmatch 'concei' }).Count -eq 0) "Busca por nome com acento, sem diferenciar maiúsculas ($($r.Json.totalRegistros) encontrados)"
$r = Chamar 'GET' '/pessoas?tamanho=5&busca=zzzqqqxxx'
Verificar ($r.Status -eq 200 -and $r.Json.totalRegistros -eq 0) 'Busca sem resultado devolve lista vazia'

# ---------- Update ----------
$r = Chamar 'GET' "/pessoas/$id"
$end1 = $r.Json.enderecos[0].id
$corpo = @{ natureza = 1; documento = $cpf; primeiroNome = 'Maria'; segundoNome = 'Conceição';
            enderecos = @(@{ id = $end1; cep = '30130010' }, @{ cep = '40026010' }) } | ConvertTo-Json -Depth 5
$r = Chamar 'PUT' "/pessoas/$id" $corpo
Verificar ($r.Status -eq 200 -and $r.Json.primeiroNome -eq 'Maria') 'PUT /pessoas/{id} -> 200'
Verificar ($r.Json.enderecos.Count -eq 2 -and $r.Json.enderecos[0].id -eq $end1 -and $r.Json.enderecos[0].cep -eq '30130010') 'Update sincroniza endereços'

# ---------- Integridade: pessoa sem endereço ----------
$corpo = @{ natureza = 1; documento = $cpf; primeiroNome = 'Maria'; segundoNome = 'Conceição'; enderecos = @() } | ConvertTo-Json -Depth 5
$r = Chamar 'PUT' "/pessoas/$id" $corpo
Verificar ($r.Status -eq 400) "PUT sem endereços -> 400 (obtido $($r.Status)): $($r.Json.detalhes -join '; ')"
$r = Chamar 'GET' "/pessoas/$id"
Verificar ($r.Json.enderecos.Count -eq 2) 'Pessoa continua com os endereços após tentativa inválida'

# ---------- CPF/CNPJ único ----------
$r = Chamar 'POST' '/pessoas/documentos' ('["' + $cpf + '","' + $cpfsLivres[1] + '"]')
Verificar ($r.Status -eq 200 -and @($r.Json).Count -eq 1 -and @($r.Json)[0] -eq $cpf) 'POST /pessoas/documentos devolve só os já cadastrados'
$r = Chamar 'POST' '/pessoas' (@{ natureza = 1; documento = $cpf; primeiroNome = 'Outro'; segundoNome = 'Cliente';
                                  enderecos = @(@{ cep = '01001000' }) } | ConvertTo-Json -Depth 5)
Verificar ($r.Status -eq 400 -and ($r.Json.detalhes -join ' ') -match "cliente $id") "POST com CPF já cadastrado -> 400: $($r.Json.detalhes -join '; ')"
$r = Chamar 'POST' '/pessoas' (@{ natureza = 1; documento = $cpfsLivres[1]; primeiroNome = 'Outro'; segundoNome = 'Cliente';
                                  enderecos = @(@{ cep = '01001000' }) } | ConvertTo-Json -Depth 5)
$idOutro = $r.Json.id
$r = Chamar 'PUT' "/pessoas/$idOutro" (@{ natureza = 1; documento = $cpf; primeiroNome = 'Outro'; segundoNome = 'Cliente';
                                          enderecos = @(@{ cep = '01001000' }) } | ConvertTo-Json -Depth 5)
Verificar ($r.Status -eq 400) "PUT trocando para CPF de outro cliente -> 400: $($r.Json.detalhes -join '; ')"
[void](Chamar 'DELETE' "/pessoas/$idOutro")

# ---------- Validações e erros ----------
$r = Chamar 'POST' '/pessoas' (@{ natureza = 1; documento = '11111111111'; primeiroNome = ''; segundoNome = 'X'; enderecos = @(@{ cep = '123' }) } | ConvertTo-Json -Depth 5)
Verificar ($r.Status -eq 400 -and $r.Json.detalhes.Count -eq 3) "POST inválido -> 400 com 3 detalhes: $($r.Json.detalhes -join '; ')"
$r = Chamar 'POST' '/pessoas' '{ json quebrado'
Verificar ($r.Status -eq 400) 'JSON malformado -> 400'
$r = Chamar 'POST' '/pessoas' (@{ natureza = 7 } | ConvertTo-Json)
Verificar ($r.Status -eq 400) 'Natureza inválida -> 400'
$r = Chamar 'GET' '/pessoas/999999999'
Verificar ($r.Status -eq 404) 'Pessoa inexistente -> 404'
$r = Chamar 'GET' '/pessoas/abc'
Verificar ($r.Status -eq 400) 'Id não numérico -> 400'
$r = Chamar 'GET' '/nao-existe'
Verificar ($r.Status -eq 404) 'Rota inexistente -> 404'
$r = Chamar 'DELETE' '/pessoas'
Verificar ($r.Status -eq 405) 'Método não permitido -> 405'

# ---------- Delete ----------
$r = Chamar 'DELETE' "/pessoas/$id"
Verificar ($r.Status -eq 204) 'DELETE /pessoas/{id} -> 204'
$r = Chamar 'GET' "/pessoas/$id"
Verificar ($r.Status -eq 404) 'Pessoa excluída não é mais encontrada'

# ---------- Lote inválido (tudo ou nada) ----------
$r0 = Chamar 'GET' '/pessoas?tamanho=1'
$totalAntes = $r0.Json.totalRegistros
$loteInvalido = '[' + (@{ natureza = 1; documento = (Gerar-Cpf 1); primeiroNome = 'A'; segundoNome = 'B'; enderecos = @(@{ cep = '01001000' }) } | ConvertTo-Json -Depth 5 -Compress) + ',' +
                     (@{ natureza = 1; documento = '000'; primeiroNome = 'A'; segundoNome = 'B'; enderecos = @() } | ConvertTo-Json -Depth 5 -Compress) + ']'
$r = Chamar 'POST' '/pessoas/lote' $loteInvalido
Verificar ($r.Status -eq 400) "Lote com registro inválido -> 400: $($r.Json.erro)"
$r = Chamar 'GET' '/pessoas?tamanho=1'
Verificar ($r.Json.totalRegistros -eq $totalAntes) 'Lote inválido não grava nenhum registro'
$registro = { param($doc) @{ natureza = 1; documento = $doc; primeiroNome = 'A'; segundoNome = 'B'; enderecos = @(@{ cep = '01001000' }) } | ConvertTo-Json -Depth 5 -Compress }
$r = Chamar 'POST' '/pessoas/lote' ('[' + (& $registro $cpfsLivres[2]) + ',' + (& $registro $cpfsLivres[2]) + ']')
Verificar ($r.Status -eq 400 -and ($r.Json.detalhes -join ' ') -match 'repetido no lote') "Lote com CPF repetido no próprio lote -> 400: $($r.Json.detalhes -join '; ')"
$existente = (Chamar 'GET' '/pessoas?tamanho=1').Json.dados[0].documento
$r = Chamar 'POST' '/pessoas/lote' ('[' + (& $registro $cpfsLivres[2]) + ',' + (& $registro $existente) + ']')
Verificar ($r.Status -eq 400 -and ($r.Json.detalhes -join ' ') -match 'Registro 2.*já cadastrado') "Lote com CPF/CNPJ já cadastrado -> 400: $($r.Json.detalhes -join '; ')"
$r = Chamar 'GET' '/pessoas?tamanho=1'
Verificar ($r.Json.totalRegistros -eq $totalAntes) 'Lotes com duplicidade não gravam nenhum registro'

# ---------- Lote de N pessoas ----------
if ($QuantidadeLote -gt 0) {
  # CEPs reais de capitais (conferidos no ViaCEP)
  $ceps = '01001000','20040020','30130010','40026010','80010000','88010001','90010000','70040010','60060000','50030000',
          '69005000','66010000','64000020','57020000','49010000','58010000','59010000','78005000','79002000','74003010'
  $nomes = 'Ana','Bruno','Carla','Diego','Elisa','Fábio','Gabriela','Heitor','Íris','João'
  $sobrenomes = 'Silva','Souza','Oliveira','Conceição','Araújo','Lima','Pereira','Gonçalves'
  Write-Host "Gerando $QuantidadeLote pessoas com CPF ainda não cadastrado..."
  $cpfsLote = Cpfs-Livres $QuantidadeLote
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.Append('[')
  for ($i = 1; $i -le $QuantidadeLote; $i++) {
    if ($i -gt 1) { [void]$sb.Append(',') }
    [void]$sb.Append('{"natureza":1,"documento":"').Append($cpfsLote[$i - 1]).
      Append('","primeiroNome":"').Append($nomes[$i % $nomes.Length]).
      Append('","segundoNome":"').Append($sobrenomes[$i % $sobrenomes.Length]).
      Append('","enderecos":[{"cep":"').Append($ceps[$i % $ceps.Length]).Append('"}]}')
  }
  [void]$sb.Append(']')
  $inicio = Get-Date
  $r = Chamar 'POST' '/pessoas/lote' $sb.ToString()
  $totalMs = [int]((Get-Date) - $inicio).TotalMilliseconds
  Verificar ($r.Status -eq 201 -and $r.Json.inseridos -eq $QuantidadeLote) "POST /pessoas/lote -> 201, $($r.Json.inseridos) inseridos"
  Write-Host ("        Tempo no servidor: {0} ms | tempo total da requisição: {1} ms ({2:N1} MB de JSON)" -f $r.Json.tempoMs, $totalMs, ($sb.Length / 1MB))
  $r = Chamar 'GET' '/pessoas?tamanho=1'
  Verificar ($r.Json.totalRegistros -eq $totalAntes + $QuantidadeLote) 'Total de registros após o lote'
}

# ---------- Paginação ----------
$r = Chamar 'GET' '/pessoas?pagina=2&tamanho=50'
Verificar ($r.Status -eq 200 -and $r.Json.pagina -eq 2 -and $r.Json.dados.Count -le 50) "GET /pessoas paginado (total de páginas: $($r.Json.totalPaginas))"

Write-Host ''
Write-Host "Falhas: $script:Falhas" -ForegroundColor $(if ($script:Falhas -eq 0) { 'Green' } else { 'Red' })
exit $script:Falhas
