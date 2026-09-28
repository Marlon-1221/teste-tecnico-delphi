-- Estrutura das tabelas conforme o enunciado do desafio.
-- Executar conectado ao banco "teste_tecnico":
--   psql -h localhost -U postgres -d teste_tecnico -f 01_estrutura.sql
--
-- Observações:
--   * idpessoa / idendereco são bigserial. As sequences geradas
--     (pessoa_idpessoa_seq / endereco_idendereco_seq) são usadas pelo servidor
--     para reservar IDs em bloco na inserção em lote (Array DML).
--   * ON DELETE CASCADE: ao excluir uma pessoa, os endereços e os dados de
--     integração são removidos juntos.
--   * A regra "não ter pessoa sem endereço" é garantida pela aplicação
--     (validação + gravação de pessoa e endereços na mesma transação).

CREATE TABLE pessoa (
    idpessoa bigserial NOT NULL,
    flnatureza int2 NOT NULL,
    dsdocumento varchar(20) NOT NULL,
    nmprimeiro varchar(100) NOT NULL,
    nmsegundo varchar(100) NOT NULL,
    dtregistro date NULL,
    CONSTRAINT pessoa_pk PRIMARY KEY (idpessoa)
);

CREATE TABLE endereco (
    idendereco bigserial NOT NULL,
    idpessoa int8 NOT NULL,
    dscep varchar(15) NULL,
    CONSTRAINT endereco_pk PRIMARY KEY (idendereco),
    CONSTRAINT endereco_fk_pessoa FOREIGN KEY (idpessoa) REFERENCES pessoa(idpessoa) ON DELETE cascade
);
CREATE INDEX endereco_idpessoa ON endereco (idpessoa);

CREATE TABLE endereco_integracao (
    idendereco bigint NOT null,
    dsuf varchar(50) NULL,
    nmcidade varchar(100) NULL,
    nmbairro varchar(50) NULL,
    nmlogradouro varchar(100) NULL,
    dscomplemento varchar(100) NULL,
    CONSTRAINT enderecointegracao_pk PRIMARY KEY (idendereco),
    CONSTRAINT enderecointegracao_fk_endereco FOREIGN KEY (idendereco) REFERENCES endereco(idendereco) ON DELETE cascade
);
