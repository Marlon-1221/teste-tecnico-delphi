<#
  Teste ponta a ponta da rotina de atualização de endereços via ViaCEP (item 2.2).
  Requer o servidor em execução e pessoas cadastradas (ex.: lote do TestarServidor.ps1).
  Uso:  powershell -ExecutionPolicy Bypass -File testes\TestarIntegracaoCep.ps1 [-Url http://localhost:9000] [-Todos]
#>
param(
  [string]$Url = 'http://localhost:9000',
  [switch]$Todos,
  [int]$TimeoutSegundos = 600
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
  $req.Accept = 'application/json'
  if ($Corpo) {
    $bytes = $Utf8.GetBytes($Corpo)
    $req.ContentType = 'application/json; charset=utf-8'
    $req.ContentLength = $bytes.Length
    $s = $req.GetRequestStream(); $s.Write($bytes, 0, $bytes.Length); $s.Close()
  } elseif ($Metodo -eq 'POST') { $req.ContentLength = 0 }
  try { $resp = $req.GetResponse() } catch [System.Net.WebException] {
    $resp = $_.Exception.Response; if (-not $resp) { throw } }
  $leitor = New-Object System.IO.StreamReader($resp.GetResponseStream(), $Utf8)
  $texto = $leitor.ReadToEnd(); $leitor.Close()
  $status = [int]$resp.StatusCode; $resp.Close()
  $json = $null; if ($texto) { $json = $texto | ConvertFrom-Json }
  return [pscustomobject]@{ Status = $status; Json = $json }
}

Write-Host "== Atualização de CEPs em $Url ==" -ForegroundColor Cyan

$pessoa = @{ natureza = 2; documento = '11222333000181'; primeiroNome = 'Empresa Teste CEP Ltda';
             segundoNome = 'Teste CEP'; enderecos = @(@{ cep = '99999999' }, @{ cep = '01001000' }) } | ConvertTo-Json -Depth 5
$r = Chamar 'POST' '/pessoas' $pessoa
Verificar ($r.Status -eq 201) 'Pessoa jurídica (CNPJ) com um CEP inexistente cadastrada'
$idPessoa = $r.Json.id

$somentePendentes = if ($Todos) { 'false' } else { 'true' }
$inicio = Get-Date
$r = Chamar 'POST' "/enderecos/atualizacao-cep?somentePendentes=$somentePendentes"
Verificar ($r.Status -eq 202 -and $r.Json.emExecucao) "POST /enderecos/atualizacao-cep -> 202 (obtido $($r.Status))"

$r2 = Chamar 'POST' "/enderecos/atualizacao-cep?somentePendentes=$somentePendentes"
Verificar ($r2.Status -eq 409 -or -not (Chamar 'GET' '/enderecos/atualizacao-cep').Json.emExecucao) `
  "Segunda execução simultânea é recusada -> 409 (obtido $($r2.Status))"

do {
  Start-Sleep -Milliseconds 500
  $s = (Chamar 'GET' '/enderecos/atualizacao-cep').Json
  Write-Host ("        {0,3}% | CEPs {1}/{2} | endereços atualizados {3}/{4} | não encontrados {5} | falhas {6}" -f
    $s.percentual, $s.cepsProcessados, $s.totalCeps, $s.enderecosAtualizados, $s.totalEnderecos, $s.cepsNaoEncontrados, $s.falhas)
} while ($s.emExecucao -and ((Get-Date) - $inicio).TotalSeconds -lt $TimeoutSegundos)
$duracao = [int]((Get-Date) - $inicio).TotalMilliseconds

Verificar (-not $s.emExecucao) "Rotina finalizada em $duracao ms"
Verificar ($s.cepsProcessados -eq $s.totalCeps) 'Todos os CEPs distintos processados'
Verificar ($s.falhas -eq 0) "Sem falhas (último erro: '$($s.ultimoErro)')"
Verificar ($s.cepsNaoEncontrados -ge 1) 'CEP inexistente contabilizado como não encontrado'
Verificar ($s.totalCeps -lt $s.totalEnderecos -or $s.totalEnderecos -le 1) "CEPs repetidos consultados uma única vez ($($s.totalCeps) consultas para $($s.totalEnderecos) endereços)"

$r = Chamar 'GET' "/pessoas/$idPessoa"
$semIntegracao = $r.Json.enderecos | Where-Object { $_.cep -eq '99999999' }
$comIntegracao = $r.Json.enderecos | Where-Object { $_.cep -eq '01001000' }
Verificar ($null -eq $semIntegracao.integracao) 'CEP inexistente permanece sem integração'
Verificar ($comIntegracao.integracao.cidade -eq 'São Paulo' -and $comIntegracao.integracao.uf -eq 'SP' -and
           $comIntegracao.integracao.logradouro -eq 'Praça da Sé') 'endereco_integracao gravado com dados do ViaCEP (acentos OK)'

$r = Chamar 'GET' '/pessoas?pagina=1&tamanho=20'
$amostra = @($r.Json.dados | ForEach-Object { $_.enderecos } | Where-Object { $_.cep -ne '99999999' })
$atualizados = @($amostra | Where-Object { $_.integracao }).Count
# Endereços sem integração só são aceitos se o próprio ViaCEP disser que o CEP não existe.
$cepsSemIntegracao = @($amostra | Where-Object { -not $_.integracao } | ForEach-Object { $_.cep } | Sort-Object -Unique)
$cepsInexistentes = @($cepsSemIntegracao | Where-Object { (Invoke-RestMethod "https://viacep.com.br/ws/$_/json/" -TimeoutSec 15).erro })
Verificar ($cepsSemIntegracao.Count -eq $cepsInexistentes.Count) `
  ("Amostra da 1ª página: $atualizados de $($amostra.Count) endereços com integração" +
   $(if ($cepsSemIntegracao) { "; sem integração apenas CEPs inexistentes no ViaCEP ($($cepsInexistentes -join ', '))" } else { '' }))
$amostra | Where-Object { $_.integracao } | Select-Object -First 3 | ForEach-Object {
  Write-Host ("        {0} -> {1}, {2} - {3}/{4}" -f $_.cep, $_.integracao.logradouro, $_.integracao.bairro, $_.integracao.cidade, $_.integracao.uf) }

$r = Chamar 'DELETE' "/pessoas/$idPessoa"
Verificar ($r.Status -eq 204) 'Limpeza da pessoa de teste'

Write-Host ''
Write-Host "Falhas: $script:Falhas" -ForegroundColor $(if ($script:Falhas -eq 0) { 'Green' } else { 'Red' })
exit $script:Falhas
