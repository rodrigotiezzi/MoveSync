/*
  MoveSync - Semáforo Inteligente (CitizenTech) - DDL para Azure SQL (SQL Server)
  Global Solution 2026/2

  6 tabelas (mesmos nomes e colunas das entidades JPA):
    ct_usuario    usuários (perfis CIDADAO e GESTOR)
    ct_cruzamento cruzamentos monitorados
    ct_via        vias de cada cruzamento (FK cruzamento)
    ct_leitura    leituras dos sensores por via (FK via)
    ct_decisao    decisões do semáforo (FK cruzamento + via prioritária)
    ct_relato     relatos dos cidadãos (FK usuário + cruzamento)

  O Hibernate (ddl-auto=update) também cria as tabelas ao subir a aplicação;
  este script é a referência do DDL e pode ser executado no Query editor do banco.
*/

/* ===================== DROPS (ordem inversa das FKs) ===================== */
DROP TABLE IF EXISTS ct_relato;
DROP TABLE IF EXISTS ct_decisao;
DROP TABLE IF EXISTS ct_leitura;
DROP TABLE IF EXISTS ct_via;
DROP TABLE IF EXISTS ct_cruzamento;
DROP TABLE IF EXISTS ct_usuario;

/* ================================ DDL ================================ */
CREATE TABLE ct_usuario (
    id     BIGINT IDENTITY(1,1) PRIMARY KEY,
    nome   VARCHAR(120) NOT NULL,
    email  VARCHAR(160) NOT NULL,
    senha  VARCHAR(100) NOT NULL,
    perfil VARCHAR(20)  NOT NULL,
    CONSTRAINT uk_usuario_email UNIQUE (email),
    CONSTRAINT ck_usuario_perfil CHECK (perfil IN ('CIDADAO', 'GESTOR'))
);

CREATE TABLE ct_cruzamento (
    id              BIGINT IDENTITY(1,1) PRIMARY KEY,
    nome            VARCHAR(120) NOT NULL,
    endereco        VARCHAR(200) NOT NULL,
    latitude        FLOAT NOT NULL,
    longitude       FLOAT NOT NULL,
    ativo           BIT NOT NULL,
    tempo_min_verde INT NOT NULL,
    tempo_max_verde INT NOT NULL,
    tempo_fixo      INT NOT NULL
);

CREATE TABLE ct_via (
    id             BIGINT IDENTITY(1,1) PRIMARY KEY,
    cruzamento_id  BIGINT NOT NULL,
    nome           VARCHAR(120) NOT NULL,
    sentido        VARCHAR(60)  NOT NULL,
    CONSTRAINT fk_via_cruzamento FOREIGN KEY (cruzamento_id) REFERENCES ct_cruzamento (id)
);

CREATE TABLE ct_leitura (
    id                  BIGINT IDENTITY(1,1) PRIMARY KEY,
    via_id              BIGINT NOT NULL,
    quantidade_veiculos INT NOT NULL,
    tamanho_fila_metros INT NOT NULL,
    veiculo_emergencia  BIT NOT NULL,
    registrado_em       DATETIMEOFFSET(6) NOT NULL,
    CONSTRAINT fk_leitura_via FOREIGN KEY (via_id) REFERENCES ct_via (id)
);
CREATE INDEX ix_leitura_via_data ON ct_leitura (via_id, registrado_em);

CREATE TABLE ct_decisao (
    id                   BIGINT IDENTITY(1,1) PRIMARY KEY,
    cruzamento_id        BIGINT NOT NULL,
    via_prioritaria_id   BIGINT NOT NULL,
    tempo_verde_segundos INT NOT NULL,
    modo                 VARCHAR(20) NOT NULL,
    explicacao           VARCHAR(1000) NOT NULL,
    criado_em            DATETIMEOFFSET(6) NOT NULL,
    CONSTRAINT fk_decisao_cruzamento FOREIGN KEY (cruzamento_id) REFERENCES ct_cruzamento (id),
    CONSTRAINT fk_decisao_via FOREIGN KEY (via_prioritaria_id) REFERENCES ct_via (id),
    CONSTRAINT ck_decisao_modo CHECK (modo IN ('ADAPTATIVO', 'FALLBACK_FIXO', 'EMERGENCIA'))
);

CREATE TABLE ct_relato (
    id            BIGINT IDENTITY(1,1) PRIMARY KEY,
    usuario_id    BIGINT NOT NULL,
    cruzamento_id BIGINT NOT NULL,
    descricao     VARCHAR(1000) NOT NULL,
    categoria     VARCHAR(30)  NOT NULL,
    gravidade     INT NOT NULL,
    resumo_ia     VARCHAR(300) NOT NULL,
    status        VARCHAR(20)  NOT NULL,
    criado_em     DATETIMEOFFSET(6) NOT NULL,
    CONSTRAINT fk_relato_usuario FOREIGN KEY (usuario_id) REFERENCES ct_usuario (id),
    CONSTRAINT fk_relato_cruzamento FOREIGN KEY (cruzamento_id) REFERENCES ct_cruzamento (id),
    CONSTRAINT ck_relato_status CHECK (status IN ('ABERTO', 'EM_ANALISE', 'RESOLVIDO')),
    CONSTRAINT ck_relato_gravidade CHECK (gravidade BETWEEN 1 AND 5)
);

/*
  Os usuários de teste e o cruzamento de exemplo (com 3 vias) são criados pelo DataLoader
  na primeira vez que a aplicação sobe com o banco vazio.

  Consultas para conferir o CRUD direto no banco (vídeo):
    SELECT * FROM ct_usuario;
    SELECT * FROM ct_cruzamento;
    SELECT * FROM ct_via;
    SELECT * FROM ct_leitura ORDER BY registrado_em DESC;
    SELECT * FROM ct_decisao ORDER BY criado_em DESC;
    SELECT * FROM ct_relato ORDER BY criado_em DESC;
*/
