-- Criação do banco de dados do teste técnico.
-- Executar conectado ao banco "postgres":
--   psql -h localhost -U postgres -d postgres -f 00_banco.sql

CREATE DATABASE teste_tecnico
    ENCODING 'UTF8'
    TEMPLATE template0;
