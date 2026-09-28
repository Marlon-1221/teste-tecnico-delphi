# Rastreabilidade de requisitos — Desafio Delphi

Cada ponto do enunciado, onde ele é atendido no projeto e como foi verificado.
Detalhes de arquitetura, execução e decisões técnicas: [README.md](README.md).

---

## 1. Ambiente

| # | Requisito | Atendimento | Verificação |
|---|---|---|---|
| A1 | Delphi Seattle ou superior | Desenvolvido no Delphi 13, evitando recursos das versões mais recentes (sem *inline var* e sem operador ternário). O `THTTPClient.ConnectionTimeout`/`ResponseTimeout` exige o 10.1 Berlin ou superior. | Compilado e executado no Delphi 13 (Win64) |
| A2 | Banco de dados, de preferência PostgreSQL | PostgreSQL + FireDAC (driver `PG`) | PostgreSQL 17.11 |

## 2. Boas práticas

| # | Critério | Onde |
|---|---|---|
| B1 | Clean Code | Nomes expressivos e curtos em português, prefixos de unit `Ubrw`/`Uca`/`Urot`/`Lib`, métodos curtos com responsabilidade única, constantes em vez de números mágicos, prefixos `F`/`A`/`L`; código sem comentários (as explicações ficam no README) |
| B2 | Padrões de projeto | Repository, Unit of Work, Factory, Strategy, Template Method, Producer-Consumer, Front Controller, Mapper/DTO, Composition Root (tabela no README) |
| B3 | POO | Entidades com estado encapsulado; serviços, repositórios e integrações atrás de interfaces |
| B4 | Herança | `TEntidade` → `TPessoa`/`TEndereco`; `TRepositorioBase` → 3 repositórios; `TValidadorDocumentoModulo11` → `TValidadorCpf`/`TValidadorCnpj`; `TThread` → coordenador/trabalhador |
| B5 | Encapsulamento | Campos `private` + `property`; regra única de posse (funções que devolvem objeto transferem a posse; `TObjectList` é dona dos itens) |
| B6 | Polimorfismo | `IValidadorDocumento` (CPF × CNPJ), métodos `virtual; abstract`, dependências por interface (`IRegraPessoa`, `IConsultaCep`, `IUnidadeTrabalho`...) |
| B7 | Projeto em 3 camadas | Apresentação (`cliente/`) → Negócio (`servidor/Web`, `Controle`, `Regras`, `Integracao`) → Dados (`servidor/Dados`, `Infra`); contratos comuns em `comum/` |
| B8 | Criação e destruição de objetos | `try..finally` em toda criação; `try..except Free; raise` em funções que devolvem objetos; `TObjectList` dono dos itens; interfaces com contagem de referência; destruição em ordem inversa na composition root; threads aguardadas antes da liberação; `ReportMemoryLeaksOnShutdown` em Debug |
| B9 | Generics | `TPagina<T>`, `ExecutarEmLote<T>` + `TPreenchimentoLote<T>`, `TAssincrono.Executar<T>`, `TThreadedQueue<T>`, `TObjectList<T>`, `TObjectDictionary<K,V>` |
| B10 | Threads | Servidor: coordenador + N trabalhadores `TThread` com fila `TThreadedQueue<T>`, progresso com `TCriticalSection`, Indy com uma thread por conexão, pool de conexões. Cliente: chamadas ao servidor em segundo plano (`TAssincrono`) com retorno via `TThread.Queue` |

## 3. Banco de dados (Orientação técnica 1)

| # | Requisito | Atendimento | Verificação |
|---|---|---|---|
| D1 | Tabela `pessoa` | `banco/01_estrutura.sql` (DDL idêntico ao enunciado) | Conferido em `information_schema` |
| D2 | Tabela `endereco` + FK cascade + índice | idem | FK e cascade testados |
| D3 | Tabela `endereco_integracao` | idem | UPSERT e cascade testados |
| D4 | Criação do banco | `banco/00_banco.sql` (UTF8) | Executado |

## 4. Arquitetura (Orientação técnica 2)

| # | Requisito | Atendimento | Verificação |
|---|---|---|---|
| R1 | Três camadas | ver B7 | — |
| R2 | REST com JSON entre cliente e servidor | Servidor Indy + `TRoteador`; cliente `THTTPClient`; contrato em `UConversorJson` | `TestarServidor.ps1` e uso do cliente |
| R3–R5 | Clean Code, OO, padrões | ver B1–B6 | — |
| R6 | **Não ter pessoa sem endereço** | Validação compartilhada (cliente e servidor), pessoa + endereços na mesma transação (Unit of Work), sincronização de endereços na alteração, sem exclusão isolada de endereço, cascade na exclusão da pessoa | PUT sem endereços → 400 e dados mantidos; rollback testado; lote inválido não grava nada; consulta no banco: 0 pessoas sem endereço |
| R7 | Persistência com FireDAC | Pool (`Pooled=True`), `TFDQuery` parametrizado, Array DML | `TestesDados` |

## 5. Cadastro de pessoas (2.1)

| # | Requisito | API | Cliente VCL | Verificação |
|---|---|---|---|---|
| C1 | Tabelas Pessoa e Endereco | — | — | — |
| C2 | Insert | `POST /pessoas` | Novo | API + tela |
| C3 | Update | `PUT /pessoas/{id}` | Editar / duplo clique | API + tela |
| C4 | Delete | `DELETE /pessoas/{id}` | Excluir (com confirmação) | API + tela |
| C5 | Consulta | `GET /pessoas?pagina=&tamanho=`, `GET /pessoas/{id}` | Grade com rolagem contínua (lista virtual, blocos de 500 sob demanda) e **busca** por nome, razão social, cidade, CPF/CNPJ ou CEP (`GET /pessoas?busca=`) | API + tela |
| C6 | Inclusão em lote | `POST /pessoas/lote` | Menu Processos → Inclusão de clientes em lote: gerar clientes de teste (quantidade configurável) ou **importar planilha Excel** (`modelos\clientes_modelo.xlsx`, erros apontados por linha) | API + tela + `TestesComum` (planilhas) |
| C7 | **Lote performático (50.000)** | Validação prévia (tudo ou nada) → IDs reservados em um comando → Array DML em blocos de 5.000 → transação única | — | **50.000 pessoas + 50.000 endereços em 1,7 s no servidor** |
| C8 | Validações | Natureza 1/2, CPF/CNPJ com dígito verificador e **único** (não repete no lote nem entre clientes), nomes obrigatórios (≤ 100), CEP com 8 dígitos | Validação na tela antes do envio; a tela só fecha após o servidor confirmar | Erros 400 com a lista de detalhes |

## 6. Rotina com threads — atualização de endereços (2.2)

| # | Requisito | Atendimento | Verificação |
|---|---|---|---|
| T1 | Threads | `TCoordenadorAtualizacaoCep` + N `TTrabalhadorCep` (`TThread`) com `TThreadedQueue<T>`; cada thread com a sua conexão e o seu cliente HTTP | `TestarIntegracaoCep.ps1` |
| T2 | Atualizar os endereços cadastrados | `POST /enderecos/atualizacao-cep` (202; 409 se já estiver em andamento), `GET` para o andamento | idem |
| T3 | Ler o CEP da tabela `endereco` | `IRepositorioEndereco.ListarParaIntegracao` (pendentes ou todos) | idem |
| T4 | Integração com `viacep.com.br/ws/{cep}/json/` | `TConsultaViaCep` com timeout, novas tentativas (429/5xx/rede) e CEP inexistente tratado | Formato real da API conferido |
| T5 | Gravar em `endereco_integracao` | UPSERT: uf→`dsuf`, localidade→`nmcidade`, bairro→`nmbairro`, logradouro→`nmlogradouro`, complemento→`dscomplemento` | 45.000 registros conferidos no banco, com acentos |
| T6 | Desempenho | Cada CEP é consultado uma única vez; quantidade de threads configurável | **21 consultas para 50.002 endereços; 2,6–3,6 s com 4 threads; 0 falhas** |
| T7 | Acompanhamento | Menu Processos → Atualizar endereços; barra de progresso na tela principal (consulta a cada 1 s); cancelamento e espera das threads ao encerrar o servidor | Tela |

## 7. Entrega

| # | Requisito | Atendimento |
|---|---|---|
| E1 | Prazo de 3 dias | — |
| E2 | `.zip` com os fontes ou link (Git/Drive) | `.zip` sem artefatos de compilação; `.gitignore` pronto para Git |
| E3 | Instruções para a avaliação | `README.md`, `TesteTecnico.groupproj`, `.dproj` já configurados para Win64 |

## 8. Extras

| # | Item |
|---|---|
| X1 | README com arquitetura (diagrama), decisões técnicas, API e resultados medidos |
| X2 | Configuração por `.ini` (banco, porta, threads, timeout, URL do servidor) |
| X3 | Log no console do servidor (método, rota, status, tempo) |
| X4 | Erros HTTP padronizados em JSON (400/404/405/409/500) |
| X5 | Grupo de projetos `TesteTecnico.groupproj` |
| X6 | Testes automatizados: `TestesComum`, `TestesDados`, `TestarServidor.ps1`, `TestarIntegracaoCep.ps1` |
| X7 | Tela principal com menu (Cadastros → Clientes; Processos → Inclusão de clientes em lote / Atualizar endereços) e rodapé com banco conectado (via `GET /sistema`), data e desenvolvedor |
| X8 | Todas as mensagens e menus em português (`LibMensagem`: títulos e botões Sim/Não/Cancelar/Confirmar) |
