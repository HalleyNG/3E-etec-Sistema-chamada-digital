# ARQUITETURA RELACIONAL: CHAMADA INTELIGENTE (NÚCLEO)

**Disciplina:** Programação e Administração de Banco de Dados
**Avaliação Intermediária — Etapa 1**
**Versão:** 4.0 (inconsistências entre escopo do MVP e modelo tratadas; ver seção 13.5)

## Informações do Projeto

**Nome do Projeto:** Chamada Inteligente (Projeto 1 — Núcleo)

**Equipe:**

- Analista: Halley Pedroso Suniga — e2281524@edu.mt.gov.br
- Frontend: Andressa da Cruz Melo — e2316551@edu.mt.gov.br
- Backend: Gustavo Leal — e2520025@edu.mt.gov.br
- Monitor responsável: Diorge

**Descrição do Projeto:**

Sistema de gestão de presença dos alunos. O Núcleo fornece cadastro de Alunos, Turmas e Professores, autenticação JWT e registro de presença por biometria digital da mão ou por cartão do aluno. Os demais projetos da turma reutilizam esse banco e essa API.

## 1. JUSTIFICATIVA DA ARQUITETURA RELACIONAL

### Tecnologia Selecionada

**SGBD:** PostgreSQL 16

**Stack da aplicação (definida na spec):**

- Backend: Quarkus 3.40.1 (Java 17), acesso ao banco via JDBC
- Frontend: Angular 22

### Razão Principal para Escolha Relacional

Os dados são bem estruturados e estáveis: aluno, responsável, turma, disciplina, professor, aula e registro de frequência seguem um padrão fixo durante o ano letivo. Cada presença precisa estar ligada a um aluno e a uma aula válidos, o que é garantido por chaves estrangeiras e transações ACID. Como o sistema lida com dados de menores de idade e com dados biométricos, a consistência e o controle de acesso em nível de banco são importantes. Os relatórios dependem de JOIN, agrupamento e contagem.

### Por que PostgreSQL (e não MySQL)

- **Constraints mais expressivas:** `CHECK` aplicado a qualquer coluna, e restrição de não sobreposição de períodos (`EXCLUDE`) para bimestres.
- **Procedures e funções com PL/pgSQL:** cobrem o uso de procedures na disciplina, com `CALL`, funções que retornam valor e tratamento de exceções.
- **`INSERT ... ON CONFLICT`** e **`RETURNING`:** substituem `ON DUPLICATE KEY` e `LAST_INSERT_ID()`.
- **`FILTER (WHERE ...)`** em agregações: contagens condicionais legíveis.
- **Tipo `BYTEA`** para o template biométrico e triggers para regras de consentimento.
- **Integração com Quarkus** via `quarkus-jdbc-postgresql` (extensão oficial).

## 2. MODELO DE DADOS RELACIONAL

### Levantamento de Entidades

| **Entidade** | **Atributos Principais** | **Tipo de Dados** | **Restrições** |
| --- | --- | --- | --- |
| **Aluno** | ID_Aluno (PK), Matricula, Nome, Email, Data_Nascimento, Codigo_Cartao, Ativo | INT, VARCHAR(20), VARCHAR(100), VARCHAR(100), DATE, VARCHAR(30), BOOLEAN | NOT NULL, Matricula UNIQUE, Codigo_Cartao UNIQUE (nulo até a emissão) |
| **Professor** | ID_Professor (PK), Nome, Email, Ativo | INT, VARCHAR(100), VARCHAR(100), BOOLEAN | NOT NULL, Email UNIQUE |
| **Usuario** | ID_Usuario (PK), Email, Senha_Hash, Perfil, ID_Professor (FK, opcional), Ativo | INT, VARCHAR(100), VARCHAR(255), VARCHAR(20), INT, BOOLEAN | NOT NULL, Email UNIQUE, Perfil IN ('ADMIN','PROFESSOR') |
| **Responsavel** | ID_Responsavel (PK), Nome, Telefone, Email | INT, VARCHAR(100), VARCHAR(20), VARCHAR(100) | NOT NULL |
| **Aluno_Responsavel** | ID_Aluno (FK), ID_Responsavel (FK), Parentesco, Autoriza_Biometria | INT, INT, VARCHAR(30), BOOLEAN | PK composta, Foreign Keys |
| **Cadastro_Biometrico** | ID_Cadastro (PK), ID_Aluno (FK), Dedo, Template_Biometrico, Consentimento_Data, Ativo | INT, INT, SMALLINT, BYTEA, DATE, BOOLEAN | NOT NULL, FK, UNIQUE(ID_Aluno, Dedo), Dedo 1–10 |
| **Turma** | ID_Turma (PK), Codigo, Ano_Letivo, Serie, Sala, Horario_Inicio | INT, VARCHAR(20), INT, INT, VARCHAR(10), TIME | NOT NULL, Codigo UNIQUE. `Horario_Inicio` é o horário previsto, usado para classificar atraso |
| **Disciplina** | ID_Disciplina (PK), Nome, Codigo, Carga_Horaria | INT, VARCHAR(100), VARCHAR(20), INT | NOT NULL, Codigo UNIQUE, Carga_Horaria > 0 |
| **Turma_Disciplina** | ID_Turma (FK), ID_Disciplina (FK), ID_Professor (FK) | INT, INT, INT | PK composta, Foreign Keys, ID_Professor NOT NULL |
| **Matricula_Turma** | ID_Aluno (FK), ID_Turma (FK), Situacao | INT, INT, VARCHAR(12) | PK composta, Situacao IN ('ATIVA','TRANSFERIDA','CONCLUIDA') |
| **Bimestre** | ID_Bimestre (PK), Ano_Letivo, Numero, Data_Inicio, Data_Fim | INT, INT, SMALLINT, DATE, DATE | NOT NULL, UNIQUE(Ano_Letivo, Numero), Numero 1–4, períodos sem sobreposição |
| **Calendario_Letivo** | Data (PK), Letivo, Descricao | DATE, BOOLEAN, VARCHAR(100) | NOT NULL. Dia sem registro não tem aula |
| **Aula** | ID_Aula (PK), ID_Turma (FK), ID_Disciplina (FK), Data_Aula, Hora_Abertura, Fechada_Em | INT, INT, INT, DATE, TIMESTAMP, TIMESTAMP | NOT NULL, UNIQUE(ID_Turma, ID_Disciplina, Data_Aula), FK composta para Turma_Disciplina. `Fechada_Em` NULL = chamada aberta |
| **Frequencia** | ID_Frequencia (PK), ID_Aluno (FK), ID_Aula (FK), Hora_Registro, Status, Metodo, Score_Correspondencia | INT, INT, INT, TIME, VARCHAR(10), VARCHAR(12), NUMERIC(5,2) | NOT NULL, UNIQUE(ID_Aluno, ID_Aula), Status IN ('PRESENTE','ATRASADO','FALTA','JUSTIFICADA'), Metodo IN ('BIOMETRICO','CARTAO','SIMULADO','FACIAL','MANUAL') |

**Decisões importantes de modelagem:**

- **Entidades do escopo oficial:** Aluno, Professor, Turma, Disciplina e Usuário (autenticação JWT). Responsável e vínculo com aluno são mantidos porque a autorização de biometria depende deles.
- **Dois métodos de identificação deste projeto:** biometria digital da mão (`Cadastro_Biometrico`) e cartão do aluno (`Aluno.Codigo_Cartao`, número único). A biometria do MVP é simulada (`Metodo = SIMULADO`).
- **Presença por aula:** a presença pertence a uma `Aula`, não a turma e data. Uma turma com duas disciplinas no mesmo dia tem duas chamadas.
- **Abertura e fechamento são etapas separadas:** o professor abre a aula, espera os alunos registrarem presença, e então fecha a chamada parcialmente. Fechar na abertura marcaria todos como falta.
- **Presença por método:** `Metodo` identifica como a presença foi registrada. O Catraca Facial (Projeto 2) grava na mesma `FREQUENCIA` com `Metodo = FACIAL`.
- **Imagem da digital não é guardada.** Guardamos apenas o template biométrico, um conjunto de minúcias a partir do qual não é possível reconstruir a digital original.
- **Até 10 dedos por aluno:** dedo 1 a 10 (polegar ao mínimo de cada mão), mínimo de 1. A tela de cadastro recomenda dois dedos.
- **Faltas são registros explícitos.** Ao fechar a chamada parcial, a procedure `sp_fechar_chamada_parcial` cria linhas `FALTA` para os alunos matriculados sem presença naquela aula.
- **Correção manual substitui falta.** Depois do fechamento, o professor registra o atrasado manualmente, e a linha `FALTA` é atualizada, não duplicada.
- **Consentimento aplicado pelo banco:** um trigger bloqueia o cadastro biométrico se nenhum responsável do aluno tiver `Autoriza_Biometria = TRUE`.
- **Professor por disciplina:** `Turma_Disciplina` guarda quem leciona cada disciplina em cada turma. A abertura de aula só é aceita para o professor vinculado.
- **Fora do Núcleo:** notificações ao responsável (Connect) e alerta de evasão (módulo de relatórios, fase futura). O Núcleo só expõe a consulta de percentual de frequência.

### Diagrama Entidade-Relacionamento (DER)

- **Aluno 1:N Cadastro_Biometrico** — até 10 dedos por aluno.
- **Aluno N:N Responsavel** — resolvido por `Aluno_Responsavel`.
- **Aluno N:N Turma** — resolvido por `Matricula_Turma` (permite troca de turma ao longo dos anos).
- **Turma N:N Disciplina** — resolvido por `Turma_Disciplina`, que também liga o Professor.
- **Turma_Disciplina 1:N Aula** — cada aula pertence a um vínculo turma-disciplina.
- **Aula 1:N Frequencia** e **Aluno 1:N Frequencia** — cada presença pertence a uma aula e a um aluno.
- **Professor 1:N Usuario** (opcional) — login de professores no sistema.
- **Bimestre** e **Calendario_Letivo** — tabelas independentes, consultadas por `fn_abrir_aula` e pelas procedures de fechamento e de correção manual.

```text
USUARIO --(N:1, opcional)-- PROFESSOR --(1:N)-- TURMA_DISCIPLINA --(1:N)-- AULA --(1:N)-- FREQUENCIA --(N:1)-- ALUNO
                                                       |          |                                             |
                                                  DISCIPLINA      +--(N:1)-- TURMA --(N:N via MATRICULA_TURMA)--+
                                                                                                                |
RESPONSAVEL --(N:N via ALUNO_RESPONSAVEL)-- ALUNO --(1:N)-- CADASTRO_BIOMETRICO

BIMESTRE e CALENDARIO_LETIVO (independentes; consultados pelas regras de abertura e de correção)
```

## 3. CARACTERÍSTICAS DA ARQUITETURA RELACIONAL

### Propriedades ACID Aplicadas ao Projeto

| **Propriedade ACID** | **Garantia Técnica** | **Aplicação no Projeto** |
| --- | --- | --- |
| **Atomicidade** | Transação completa ou não executa | Ao registrar uma presença, a validação de matrícula e a gravação em `FREQUENCIA` acontecem na mesma chamada de procedure. Ao fechar a chamada, a alteração de `AULA` e a criação das faltas acontecem juntas |
| **Consistência** | Dados mantêm regras de integridade | Presença só existe para aluno matriculado em uma aula válida; não há duas presenças do mesmo aluno na mesma aula; cadastro biométrico só existe com consentimento; cartão é único por aluno; bimestres não se sobrepõem |
| **Isolamento** | Transações concorrentes não se interferem | Leitores em portas diferentes gravam ao mesmo tempo sem duplicar registros, graças à `UNIQUE` e ao `ON CONFLICT`. O fechamento usa `SELECT ... FOR UPDATE`, para que uma leitura e o fechamento não se cruzem. O nível padrão `READ COMMITTED` é suficiente para este caso |
| **Durabilidade** | Dados persistem após commit | Histórico preservado mesmo com queda de energia, pelo WAL do PostgreSQL |

## 4. NORMALIZAÇÃO E ESTRUTURA DE DADOS

### Nível de Normalização Aplicado

**Forma Normal:** 3NF

- **1NF:** atributos atômicos. Um aluno pode ter vários responsáveis, dedos e turmas, então usamos tabelas separadas em vez de colunas repetidas.
- **2NF:** nas tabelas com chave composta (`Aluno_Responsavel`, `Matricula_Turma`, `Turma_Disciplina`), os atributos dependem da chave inteira.
- **3NF:** sem dependências transitivas. `FREQUENCIA` não repete turma nem data, que são obtidas pela `AULA`. Dados do responsável ficam em `Responsavel`, e dados do aluno em `Aluno`.

### Integridade Referencial

- `FREQUENCIA` → `ALUNO` e `AULA`: **ON DELETE RESTRICT.** Não é possível apagar aluno ou aula com histórico de presença.
- `AULA` → `TURMA_DISCIPLINA`: **ON DELETE RESTRICT.** Não é possível remover um vínculo que já tem aulas.
- `CADASTRO_BIOMETRICO` → `ALUNO`: **ON DELETE CASCADE.** Remoção definitiva do aluno apaga o dado biométrico, atendendo ao direito de exclusão da LGPD.
- `TURMA_DISCIPLINA` → `PROFESSOR`: **ON DELETE RESTRICT.**
- Obs.: o PostgreSQL não cria índice automático em colunas de FK. Os índices de FK estão na seção 6.

## 5. JUSTIFICATIVA TÉCNICA: POR QUE NÃO ALTERNATIVAS

### Por que não NoSQL?

Os dados têm estrutura conhecida desde o início. Consistência eventual é inadequada para registro de presença, onde uma falta indevida pode prejudicar o aluno. Um template biométrico de poucos kilobytes cabe em `BYTEA`, sem ganho que justifique outra tecnologia.

### Por que não MySQL?

MySQL atende ao projeto, mas o PostgreSQL oferece `CHECK` completo, `RETURNING`, `FILTER` em agregações, restrição `EXCLUDE` para períodos, PL/pgSQL mais expressivo e tipos nativos para o template biométrico.

### Por que não SQLite?

Não atende a vários acessos simultâneos (várias câmeras e professores ao mesmo tempo) e não tem procedures.

### Por que não arquitetura com múltiplos bancos?

Um único PostgreSQL bem projetado permite focar em normalização, SQL, integridade, índices e procedures. Para a escala de uma escola, um único banco atende com folga.

## 6. MODELAGEM SQL (PostgreSQL 16)

### Criação do banco

```sql
CREATE DATABASE chamada_biometrica
    ENCODING 'UTF8'
    LC_COLLATE 'pt_BR.UTF-8'
    LC_CTYPE 'pt_BR.UTF-8'
    TEMPLATE template0;

\c chamada_biometrica

-- Horário de Mato Grosso (CURRENT_DATE e LOCALTIME dependem do fuso)
ALTER DATABASE chamada_biometrica SET timezone TO 'America/Cuiaba';
```

### Scripts de Criação

As migrações são versionadas com Flyway (`V1__nucleo.sql`, `V2__...`). O script abaixo é a versão 1.

```sql
CREATE TABLE ALUNO (
    ID_Aluno        INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    Matricula       VARCHAR(20)  NOT NULL UNIQUE,
    Nome            VARCHAR(100) NOT NULL,
    Email           VARCHAR(100) NOT NULL,
    Data_Nascimento DATE,
    Codigo_Cartao   VARCHAR(30)  UNIQUE,         -- número do cartão; NULL até a emissão
    Ativo           BOOLEAN      NOT NULL DEFAULT TRUE,
    Data_Cadastro   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE PROFESSOR (
    ID_Professor INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    Nome         VARCHAR(100) NOT NULL,
    Email        VARCHAR(100) NOT NULL UNIQUE,
    Ativo        BOOLEAN      NOT NULL DEFAULT TRUE
);

CREATE TABLE USUARIO (
    ID_Usuario   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    Email        VARCHAR(100) NOT NULL UNIQUE,
    Senha_Hash   VARCHAR(255) NOT NULL,           -- BCrypt/Argon2, nunca senha em texto
    Perfil       VARCHAR(20)  NOT NULL CHECK (Perfil IN ('ADMIN','PROFESSOR')),
    ID_Professor INT REFERENCES PROFESSOR(ID_Professor) ON DELETE RESTRICT,
    Ativo        BOOLEAN      NOT NULL DEFAULT TRUE,
    -- Senha temporária do primeiro acesso: exige troca antes de usar o sistema
    Troca_Senha_Obrigatoria BOOLEAN NOT NULL DEFAULT TRUE,
    CHECK (Perfil <> 'PROFESSOR' OR ID_Professor IS NOT NULL)
);

CREATE TABLE RESPONSAVEL (
    ID_Responsavel INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    Nome           VARCHAR(100) NOT NULL,
    Telefone       VARCHAR(20)  NOT NULL,
    Email          VARCHAR(100)
);

CREATE TABLE ALUNO_RESPONSAVEL (
    ID_Aluno           INT NOT NULL REFERENCES ALUNO(ID_Aluno),
    ID_Responsavel     INT NOT NULL REFERENCES RESPONSAVEL(ID_Responsavel),
    Parentesco         VARCHAR(30),
    Autoriza_Biometria BOOLEAN NOT NULL DEFAULT FALSE,
    PRIMARY KEY (ID_Aluno, ID_Responsavel)
);

-- Dedo: 1 a 5 = mão direita (polegar ao mínimo); 6 a 10 = mão esquerda. Até 10 por aluno.
CREATE TABLE CADASTRO_BIOMETRICO (
    ID_Cadastro         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ID_Aluno            INT      NOT NULL REFERENCES ALUNO(ID_Aluno) ON DELETE CASCADE,
    Dedo                SMALLINT NOT NULL CHECK (Dedo BETWEEN 1 AND 10),
    Template_Biometrico BYTEA    NOT NULL CHECK (octet_length(Template_Biometrico) <= 2048),
    Consentimento_Data  DATE     NOT NULL,
    Ativo               BOOLEAN  NOT NULL DEFAULT TRUE,
    Data_Cadastro       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (ID_Aluno, Dedo)
);

-- Consentimento aplicado pelo banco: só cadastra digital se algum responsável autorizou.
-- Executa com os privilégios de quem grava: o papel app_biometria precisa de SELECT em ALUNO_RESPONSAVEL.
CREATE OR REPLACE FUNCTION fn_verifica_consentimento() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM ALUNO_RESPONSAVEL
                   WHERE ID_Aluno = NEW.ID_Aluno AND Autoriza_Biometria = TRUE) THEN
        RAISE EXCEPTION 'Sem autorizacao de biometria do responsavel para o aluno %', NEW.ID_Aluno;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_consentimento_biometrico
    BEFORE INSERT OR UPDATE OF ID_Aluno, Ativo ON CADASTRO_BIOMETRICO
    FOR EACH ROW
    WHEN (NEW.Ativo)
    EXECUTE FUNCTION fn_verifica_consentimento();

CREATE TABLE TURMA (
    ID_Turma       INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    Codigo         VARCHAR(20) NOT NULL UNIQUE,
    Ano_Letivo     INT         NOT NULL,
    Serie          INT         NOT NULL,
    Sala           VARCHAR(10),
    Horario_Inicio TIME        NOT NULL              -- horário previsto; referência para ATRASADO
);

CREATE TABLE DISCIPLINA (
    ID_Disciplina INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    Nome          VARCHAR(100) NOT NULL,
    Codigo        VARCHAR(20)  NOT NULL UNIQUE,
    Carga_Horaria INT          NOT NULL CHECK (Carga_Horaria > 0)
);

CREATE TABLE TURMA_DISCIPLINA (
    ID_Turma      INT NOT NULL REFERENCES TURMA(ID_Turma),
    ID_Disciplina INT NOT NULL REFERENCES DISCIPLINA(ID_Disciplina),
    ID_Professor  INT NOT NULL REFERENCES PROFESSOR(ID_Professor) ON DELETE RESTRICT,
    PRIMARY KEY (ID_Turma, ID_Disciplina)
);

CREATE TABLE MATRICULA_TURMA (
    ID_Aluno INT NOT NULL REFERENCES ALUNO(ID_Aluno),
    ID_Turma INT NOT NULL REFERENCES TURMA(ID_Turma),
    Situacao VARCHAR(12) NOT NULL DEFAULT 'ATIVA'
             CHECK (Situacao IN ('ATIVA','TRANSFERIDA','CONCLUIDA')),
    PRIMARY KEY (ID_Aluno, ID_Turma)
);

-- Bimestres do ano letivo. Períodos não podem se sobrepor.
CREATE TABLE BIMESTRE (
    ID_Bimestre INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    Ano_Letivo  INT      NOT NULL,
    Numero      SMALLINT NOT NULL CHECK (Numero BETWEEN 1 AND 4),
    Data_Inicio DATE     NOT NULL,
    Data_Fim    DATE     NOT NULL,
    UNIQUE (Ano_Letivo, Numero),
    CHECK (Data_Fim >= Data_Inicio),
    EXCLUDE USING gist (daterange(Data_Inicio, Data_Fim, '[]') WITH &&)
);

-- Dias em que há aula. Sem registro, o dia não tem aula.
CREATE TABLE CALENDARIO_LETIVO (
    Data      DATE PRIMARY KEY,
    Letivo    BOOLEAN NOT NULL DEFAULT TRUE,
    Descricao VARCHAR(100)                        -- ex.: 'Feriado: Proclamação da República'
);

-- Aula: uma chamada por turma, disciplina e dia.
-- Fechada_Em é preenchido no fechamento parcial. Enquanto NULL, a chamada está aberta.
CREATE TABLE AULA (
    ID_Aula       INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ID_Turma      INT       NOT NULL,
    ID_Disciplina INT       NOT NULL,
    Data_Aula     DATE      NOT NULL,
    Hora_Abertura TIMESTAMP NOT NULL DEFAULT LOCALTIMESTAMP,
    Fechada_Em    TIMESTAMP,
    FOREIGN KEY (ID_Turma, ID_Disciplina) REFERENCES TURMA_DISCIPLINA(ID_Turma, ID_Disciplina) ON DELETE RESTRICT,
    UNIQUE (ID_Turma, ID_Disciplina, Data_Aula)
);

CREATE TABLE FREQUENCIA (
    ID_Frequencia         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ID_Aluno              INT NOT NULL REFERENCES ALUNO(ID_Aluno) ON DELETE RESTRICT,
    ID_Aula               INT NOT NULL REFERENCES AULA(ID_Aula) ON DELETE RESTRICT,
    Hora_Registro         TIME,
    Status                VARCHAR(10) NOT NULL DEFAULT 'PRESENTE'
                          CHECK (Status IN ('PRESENTE','ATRASADO','FALTA','JUSTIFICADA')),
    Metodo                VARCHAR(12) NOT NULL DEFAULT 'BIOMETRICO'
                          CHECK (Metodo IN ('BIOMETRICO','CARTAO','SIMULADO','FACIAL','MANUAL')),
    Score_Correspondencia NUMERIC(5,2),
    UNIQUE (ID_Aluno, ID_Aula)
);

-- Fora do Núcleo (MVP-Q2 e MVP-Q8): NOTIFICACAO e ALERTA_EVASAO não são criadas aqui.
```

*Observação:* nomes de tabelas e colunas sem acento. No PostgreSQL, identificadores sem aspas são convertidos para minúsculas (`aluno`, `frequencia`), então o código Java/JDBC deve usar a mesma convenção.

### Índices para Performance

```sql
-- Índices de FK: o PostgreSQL não cria automaticamente
CREATE INDEX idx_aluno_resp_responsavel ON ALUNO_RESPONSAVEL (ID_Responsavel);
CREATE INDEX idx_turma_disc_disciplina  ON TURMA_DISCIPLINA (ID_Disciplina);
CREATE INDEX idx_turma_disc_professor   ON TURMA_DISCIPLINA (ID_Professor);
CREATE INDEX idx_matricula_turma        ON MATRICULA_TURMA (ID_Turma);
CREATE INDEX idx_freq_aula              ON FREQUENCIA (ID_Aula);

-- Painel do dia e relatório mensal
CREATE INDEX idx_aula_turma_data ON AULA (ID_Turma, Data_Aula);
CREATE INDEX idx_aula_data       ON AULA (Data_Aula);

CREATE INDEX idx_aluno_nome ON ALUNO (Nome);
```

Índices `UNIQUE` (Matricula, Codigo_Cartao, Email, Codigo, `(ID_Aluno, ID_Aula)`, `(ID_Turma, ID_Disciplina, Data_Aula)`) já são criados automaticamente. `UNIQUE(ID_Aluno, ID_Aula)` atende às consultas por aluno, então não há índice separado por aluno.

### Funções e procedures de chamada

Sequência de uso de uma aula:

1. **`fn_abrir_aula`:** o professor abre a aula no início. Valida o vínculo do professor, o dia letivo e o bimestre.
2. **`sp_registrar_frequencia`:** cada leitura (cartão ou digital simulada) registra presença enquanto a chamada estiver aberta.
3. **`sp_fechar_chamada_parcial`:** o professor fecha a chamada. Os ausentes recebem `FALTA`.
4. **`sp_registrar_presenca_manual`:** depois do fechamento, o professor registra atrasados. Até o fim do bimestre, o professor pode; depois, só o ADMIN.

```sql
-- Abre a aula do dia. Retorna o ID_Aula, usado nas leituras da chamada.
CREATE OR REPLACE FUNCTION fn_abrir_aula(p_turma INT, p_disciplina INT, p_professor INT)
RETURNS INT
LANGUAGE plpgsql AS $$
DECLARE
    v_id INT;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM TURMA_DISCIPLINA
                   WHERE ID_Turma = p_turma AND ID_Disciplina = p_disciplina
                     AND ID_Professor = p_professor) THEN
        RAISE EXCEPTION 'Professor nao leciona esta disciplina nesta turma';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM CALENDARIO_LETIVO
                   WHERE Data = CURRENT_DATE AND Letivo = TRUE) THEN
        RAISE EXCEPTION 'Hoje nao e dia letivo';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM BIMESTRE
                   WHERE CURRENT_DATE BETWEEN Data_Inicio AND Data_Fim) THEN
        RAISE EXCEPTION 'Hoje nao esta em nenhum bimestre cadastrado';
    END IF;

    INSERT INTO AULA (ID_Turma, ID_Disciplina, Data_Aula)
    VALUES (p_turma, p_disciplina, CURRENT_DATE)
    RETURNING ID_Aula INTO v_id;

    RETURN v_id;
END;
$$;
```

```sql
-- Registra uma leitura (cartão ou digital simulada) enquanto a chamada está aberta.
CREATE OR REPLACE PROCEDURE sp_registrar_frequencia(
    p_aula   INT,
    p_aluno  INT,
    p_metodo VARCHAR(12),
    p_score  NUMERIC(5,2)
)
LANGUAGE plpgsql AS $$
DECLARE
    v_turma   INT;
    v_fechada TIMESTAMP;
    v_inicio  TIME;
    v_status  VARCHAR(10);
BEGIN
    SELECT ID_Turma, Fechada_Em INTO v_turma, v_fechada
    FROM AULA WHERE ID_Aula = p_aula;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Aula inexistente';
    END IF;

    IF v_fechada IS NOT NULL THEN
        RAISE EXCEPTION 'Chamada fechada: use o registro manual';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM MATRICULA_TURMA
                   WHERE ID_Aluno = p_aluno AND ID_Turma = v_turma AND Situacao = 'ATIVA') THEN
        RAISE EXCEPTION 'Aluno nao matriculado nesta turma';
    END IF;

    SELECT Horario_Inicio INTO v_inicio FROM TURMA WHERE ID_Turma = v_turma;

    v_status := CASE WHEN LOCALTIME > v_inicio + INTERVAL '10 minutes'
                     THEN 'ATRASADO' ELSE 'PRESENTE' END;

    INSERT INTO FREQUENCIA (ID_Aluno, ID_Aula, Hora_Registro, Status, Metodo, Score_Correspondencia)
    VALUES (p_aluno, p_aula, LOCALTIME, v_status, p_metodo, p_score)
    ON CONFLICT (ID_Aluno, ID_Aula) DO NOTHING;   -- leitura repetida na mesma aula é ignorada
END;
$$;
```

```sql
-- Fecha a chamada parcialmente. Ausentes matriculados recebem FALTA.
CREATE OR REPLACE PROCEDURE sp_fechar_chamada_parcial(p_aula INT)
LANGUAGE plpgsql AS $$
DECLARE
    v_turma   INT;
    v_fechada TIMESTAMP;
BEGIN
    SELECT ID_Turma, Fechada_Em INTO v_turma, v_fechada
    FROM AULA WHERE ID_Aula = p_aula
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Aula inexistente';
    END IF;

    IF v_fechada IS NOT NULL THEN
        RAISE EXCEPTION 'Chamada ja fechada';
    END IF;

    UPDATE AULA SET Fechada_Em = LOCALTIMESTAMP WHERE ID_Aula = p_aula;

    INSERT INTO FREQUENCIA (ID_Aluno, ID_Aula, Status, Metodo)
    SELECT m.ID_Aluno, p_aula, 'FALTA', 'MANUAL'
    FROM MATRICULA_TURMA m
    WHERE m.ID_Turma = v_turma
      AND m.Situacao = 'ATIVA'
      AND NOT EXISTS (SELECT 1 FROM FREQUENCIA f
                      WHERE f.ID_Aluno = m.ID_Aluno AND f.ID_Aula = p_aula)
    ON CONFLICT (ID_Aluno, ID_Aula) DO NOTHING;
END;
$$;
```

*Observação:* a falta gerada pelo fechamento usa `Metodo = 'MANUAL'`, porque não há um valor próprio para a rotina automática. Ver seção 13.4.

```sql
-- Registro manual de atrasado após o fechamento. Substitui a FALTA, não duplica.
-- Professor: até o fim do bimestre. ADMIN: a qualquer momento.
CREATE OR REPLACE PROCEDURE sp_registrar_presenca_manual(
    p_aula   INT,
    p_aluno  INT,
    p_status VARCHAR(10),
    p_perfil VARCHAR(20)
)
LANGUAGE plpgsql AS $$
DECLARE
    v_turma INT;
    v_data  DATE;
    v_fim   DATE;
BEGIN
    IF p_status NOT IN ('PRESENTE','ATRASADO') THEN
        RAISE EXCEPTION 'Status manual invalido: %', p_status;
    END IF;

    SELECT ID_Turma, Data_Aula INTO v_turma, v_data
    FROM AULA WHERE ID_Aula = p_aula;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Aula inexistente';
    END IF;

    SELECT Data_Fim INTO v_fim FROM BIMESTRE
    WHERE v_data BETWEEN Data_Inicio AND Data_Fim;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Aula fora de bimestre cadastrado';
    END IF;

    IF p_perfil <> 'ADMIN' AND CURRENT_DATE > v_fim THEN
        RAISE EXCEPTION 'Bimestre encerrado: apenas ADMIN pode corrigir';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM MATRICULA_TURMA
                   WHERE ID_Aluno = p_aluno AND ID_Turma = v_turma AND Situacao = 'ATIVA') THEN
        RAISE EXCEPTION 'Aluno nao matriculado nesta turma';
    END IF;

    INSERT INTO FREQUENCIA (ID_Aluno, ID_Aula, Hora_Registro, Status, Metodo)
    VALUES (p_aluno, p_aula, LOCALTIME, p_status, 'MANUAL')
    ON CONFLICT (ID_Aluno, ID_Aula) DO UPDATE
        SET Status                = EXCLUDED.Status,
            Metodo                = 'MANUAL',
            Hora_Registro         = EXCLUDED.Hora_Registro,
            Score_Correspondencia = NULL;
END;
$$;
```

*Observação:* a correção manual pode sobrescrever uma presença lida pelo leitor. Isso é intencional para o professor corrigir erros do sistema, e o `Metodo = 'MANUAL'` deixa a alteração visível no histórico.

Uso pelo backend (JDBC): `SELECT fn_abrir_aula(?, ?, ?)`, `CALL sp_registrar_frequencia(?, ?, ?, ?)`, `CALL sp_fechar_chamada_parcial(?)` e `CALL sp_registrar_presenca_manual(?, ?, ?, ?)`.

## 7. OPERAÇÕES PRINCIPAIS: DML, DQL e PROCEDURES

### Consultas Principais (SELECT)

**Consulta 1: Relatório mensal de frequência de uma turma**

Conta registros por aula. Uma aula sem fechamento ainda não gerou faltas, então não entra como falta.

```sql
SELECT al.Nome,
       COUNT(*) FILTER (WHERE f.Status = 'PRESENTE') AS Presencas,
       COUNT(*) FILTER (WHERE f.Status = 'ATRASADO') AS Atrasos,
       COUNT(*) FILTER (WHERE f.Status = 'FALTA')    AS Faltas
FROM FREQUENCIA f
INNER JOIN AULA a  ON a.ID_Aula  = f.ID_Aula
INNER JOIN ALUNO al ON al.ID_Aluno = f.ID_Aluno
WHERE a.ID_Turma = $1
  AND a.Data_Aula >= date_trunc('month', CURRENT_DATE)
  AND a.Data_Aula <  date_trunc('month', CURRENT_DATE) + INTERVAL '1 month'
GROUP BY al.ID_Aluno, al.Nome
ORDER BY Faltas DESC;
```

**Consulta 2: Percentual de frequência abaixo de 75% nos últimos 60 dias**

Consulta de apoio ao painel. O alerta automático de evasão saiu do Núcleo (seção 13.2). O `HAVING` não pode usar alias no PostgreSQL, então o cálculo fica em um CTE.

```sql
WITH percentual AS (
    SELECT al.ID_Aluno, al.Nome,
           ROUND(100.0 * COUNT(*) FILTER (WHERE f.Status IN ('PRESENTE','ATRASADO','JUSTIFICADA'))
                 / NULLIF(COUNT(*), 0), 2) AS Percentual_Frequencia
    FROM FREQUENCIA f
    INNER JOIN AULA a   ON a.ID_Aula   = f.ID_Aula
    INNER JOIN ALUNO al ON al.ID_Aluno = f.ID_Aluno
    WHERE a.Data_Aula >= CURRENT_DATE - INTERVAL '60 days'
    GROUP BY al.ID_Aluno, al.Nome
)
SELECT ID_Aluno, Nome, Percentual_Frequencia
FROM percentual
WHERE Percentual_Frequencia < 75
ORDER BY Percentual_Frequencia ASC;
```

**Consulta 3: Painel do dia, por aula (presentes, atrasados e ausentes)**

Uma linha por aula de hoje. Quando o professor (`$1`) é informado, a consulta mostra só as aulas dele. O ADMIN omite o parâmetro e vê todas.

```sql
SELECT a.ID_Aula,
       t.Codigo,
       d.Nome AS Disciplina,
       a.Fechada_Em IS NOT NULL AS Chamada_Fechada,
       COUNT(m.ID_Aluno)                                                AS Total_Matriculados,
       COUNT(f.ID_Frequencia) FILTER (WHERE f.Status = 'PRESENTE')      AS Presentes,
       COUNT(f.ID_Frequencia) FILTER (WHERE f.Status = 'ATRASADO')      AS Atrasados,
       COUNT(m.ID_Aluno) - COUNT(f.ID_Frequencia)
           FILTER (WHERE f.Status IN ('PRESENTE','ATRASADO'))           AS Ainda_Ausentes
FROM AULA a
INNER JOIN TURMA t       ON t.ID_Turma = a.ID_Turma
INNER JOIN DISCIPLINA d  ON d.ID_Disciplina = a.ID_Disciplina
INNER JOIN MATRICULA_TURMA m ON m.ID_Turma = a.ID_Turma AND m.Situacao = 'ATIVA'
LEFT JOIN FREQUENCIA f   ON f.ID_Aluno = m.ID_Aluno AND f.ID_Aula = a.ID_Aula
WHERE a.Data_Aula = CURRENT_DATE
  AND ($1 IS NULL OR EXISTS (SELECT 1 FROM TURMA_DISCIPLINA td
                             WHERE td.ID_Turma = a.ID_Turma
                               AND td.ID_Disciplina = a.ID_Disciplina
                               AND td.ID_Professor = $1))
GROUP BY a.ID_Aula, t.Codigo, d.Nome, a.Fechada_Em;
```

### Comandos DML

```sql
-- Cadastrar um aluno com cartão e matricular em uma turma
BEGIN;
WITH novo AS (
    INSERT INTO ALUNO (Matricula, Nome, Email, Data_Nascimento, Codigo_Cartao)
    VALUES ('2026001', 'Maria Souza', 'maria@edu.mt.gov.br', '2010-05-14', '0004821913')
    RETURNING ID_Aluno
)
INSERT INTO MATRICULA_TURMA (ID_Aluno, ID_Turma)
SELECT ID_Aluno, 1 FROM novo;
COMMIT;

-- Justificar uma falta (fora do MVP pela interface; o SQL permanece disponível em caso excepcional)
UPDATE FREQUENCIA SET Status = 'JUSTIFICADA'
WHERE ID_Aluno = 1 AND ID_Aula = 10
  AND Status = 'FALTA';

-- Desativar o cadastro biométrico (ex.: responsável retirou a autorização)
UPDATE CADASTRO_BIOMETRICO SET Ativo = FALSE WHERE ID_Aluno = 1;
```

### Procedures

No PostgreSQL, `CALL` executa em transação própria. Se a procedure lança exceção, tudo é desfeito automaticamente, então não é preciso `START TRANSACTION` / `ROLLBACK` manuais.

- **`fn_abrir_aula`:** valida vínculo do professor, dia letivo e bimestre; cria a aula e retorna o `ID_Aula`.
- **`sp_registrar_frequencia`:** grava a leitura com status pelo horário previsto da turma (`Turma.Horario_Inicio`, com 10 minutos de tolerância). Recusa aula fechada e aluno não matriculado.
- **`sp_fechar_chamada_parcial`:** marca a aula como fechada e gera `FALTA` para os ausentes.
- **`sp_registrar_presenca_manual`:** registra atrasado ou presente depois do fechamento. Substitui a falta. Professor pode até o fim do bimestre; ADMIN a qualquer momento.

## 8. SEGURANÇA E PERMISSÕES

Dois papéis de banco, com o princípio do menor privilégio:

```sql
CREATE ROLE app_chamada LOGIN PASSWORD '<definir_em_cofre>';
GRANT CONNECT ON DATABASE chamada_biometrica TO app_chamada;
GRANT USAGE ON SCHEMA public TO app_chamada;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO app_chamada;   -- necessário para colunas IDENTITY

-- Aplicação: leitura e escrita nas tabelas de negócio
GRANT SELECT, INSERT, UPDATE ON ALUNO, PROFESSOR, RESPONSAVEL, ALUNO_RESPONSAVEL,
                                TURMA, DISCIPLINA, TURMA_DISCIPLINA, MATRICULA_TURMA,
                                AULA, FREQUENCIA TO app_chamada;
GRANT SELECT, INSERT, UPDATE ON USUARIO TO app_chamada;   -- troca de senha no primeiro acesso
GRANT SELECT ON BIMESTRE, CALENDARIO_LETIVO TO app_chamada;
GRANT EXECUTE ON FUNCTION fn_abrir_aula(INT, INT, INT) TO app_chamada;
GRANT EXECUTE ON PROCEDURE sp_registrar_frequencia(INT, INT, VARCHAR, NUMERIC),
                           sp_fechar_chamada_parcial(INT),
                           sp_registrar_presenca_manual(INT, INT, VARCHAR, VARCHAR) TO app_chamada;

-- Papel separado para biometria: único com acesso à tabela de templates
CREATE ROLE app_biometria LOGIN PASSWORD '<definir_em_cofre>';
GRANT CONNECT ON DATABASE chamada_biometrica TO app_biometria;
GRANT USAGE ON SCHEMA public TO app_biometria;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO app_biometria;
GRANT SELECT, INSERT, UPDATE ON CADASTRO_BIOMETRICO TO app_biometria;
GRANT SELECT ON ALUNO_RESPONSAVEL TO app_biometria;   -- exigido pelo trigger de consentimento
```

- A aplicação Quarkus conecta como `app_chamada`. A senha fica em variável de ambiente ou cofre, nunca no código.
- O template biométrico só é acessível pelo papel `app_biometria`. O papel lê `ALUNO_RESPONSAVEL` apenas para o trigger de consentimento.
- Senhas de usuários da aplicação são guardadas como hash (`Senha_Hash`), nunca em texto. A troca obrigatória no primeiro acesso é controlada por `Troca_Senha_Obrigatoria`.

## 9. FERRAMENTAS E TECNOLOGIAS

| **Camada** | **Tecnologia** | **Justificativa** |
| --- | --- | --- |
| **Banco de Dados** | PostgreSQL 16 | `CHECK`, `RETURNING`, `FILTER`, `ON CONFLICT`, `EXCLUDE`, PL/pgSQL, `BYTEA` e triggers |
| **Backend / API** | Quarkus 3.40.1 (Java 17) | Definido na spec. Extensões: `quarkus-jdbc-postgresql`, `quarkus-agroal`, `quarkus-smallrye-jwt`, `quarkus-hibernate-validator`, `quarkus-rest-jackson`, `quarkus-flyway` |
| **Frontend** | Angular 22 | Definido na spec. Painel administrativo e presença |
| **Acesso a dados** | SQL explícito via JDBC (`quarkus-agroal`) | Decisão Q4: o SQL do documento é o SQL que roda na aplicação |
| **Migrações** | Flyway (`quarkus-flyway`) | Decisão Q5: scripts `V<n>__*.sql` versionados no backend |
| **Leitura biométrica** | Simulada no MVP; leitor USB + SDK do fabricante depois | MVP-Q2 e MVP-Q3 (simulação). Decisão Q10: integração direta pelo Quarkus, se o SDK tiver Java ou JNI |

## 10. DECISÕES DE ESCOPO (sessão de grill-me, Núcleo)

| # | Tema | Decisão | Impacto no modelo |
| --- | --- | --- | --- |
| Q1 | Biometria digital | Entra no Núcleo | `CADASTRO_BIOMETRICO`, trigger de consentimento, papel `app_biometria` |
| Q2 | Notificações ao responsável | Saem do Núcleo; ficam com o Connect | `NOTIFICACAO` não existe no Núcleo |
| Q3 | Dias letivos | Tabela `CALENDARIO_LETIVO`, preenchida pela escola | Aula só é aberta em dia letivo |
| Q4 | Acesso a dados | SQL puro via JDBC | Sem ORM; queries e procedures escritas à mão |
| Q5 | Migrações | Flyway | Scripts versionados; `quarkus-flyway` |
| Q6 | Cartão do aluno | Número único em `ALUNO.Codigo_Cartao` | Nova coluna UNIQUE; `Metodo` inclui `CARTAO` |
| Q7 | Dedos por aluno | Até 10 (dedo 1 a 10), mínimo 1; tela recomenda 2 | Mantém `UNIQUE(ID_Aluno, Dedo)` e `CHECK` 1–10 |
| Q8 | Alerta de evasão | Sai do Núcleo; o Núcleo só expõe a consulta de percentual | `ALERTA_EVASAO` não existe no Núcleo |
| Q9 | Catraca Facial (Projeto 2) | Grava na mesma `FREQUENCIA`, com `Metodo = FACIAL` | `Metodo` inclui `FACIAL` |
| Q10 | Integração do leitor | Direta pelo Quarkus, se o SDK tiver Java ou JNI | Se o SDK não tiver Java/JNI, reabrir: alternativa é agente local em HTTP |

As decisões do escopo do MVP estão na seção 13 (referenciadas como **MVP-Qn**).

**Pendências que não bloqueiam o banco:**

- Modelo do leitor e linguagem do SDK (escola/fabricante). Só bloqueiam a integração biométrica real.
- Valor de `Metodo` para faltas geradas pelo fechamento (hoje `MANUAL`).

## 11. QUESTÕES TÉCNICAS

**Pergunta: Esta arquitetura é suficiente para um projeto que pode crescer?**
Sim. Uma arquitetura normalizada escala verticalmente com índices e, se necessário, particionamento da tabela `FREQUENCIA` por ano letivo (suportado nativamente no PostgreSQL).

**Pergunta: Como o Catraca Facial (Projeto 2) se integra?**
Ele grava na mesma `FREQUENCIA`, pela mesma procedure `sp_registrar_frequencia`, com `Metodo = FACIAL`. Isso mantém um único histórico de presença para a escola.

**Pergunta: Guardar a impressão digital no banco não é um risco?**
Guardamos apenas o template (pontos característicos), nunca a imagem, e apenas com consentimento do responsável registrado pelo trigger. O acesso é restrito ao papel `app_biometria`.

**Pergunta: Por que usar banco de dados e não apenas arquivo JSON/CSV?**
Arquivos servem para dados estáticos. O banco oferece integridade referencial, consultas complexas sem carregar tudo na memória, controle de acesso e suporte a vários usuários simultâneos.

## 12. CONCLUSÃO

O Núcleo do Projeto Chamada Inteligente usa PostgreSQL 16 como SGBD, com a stack Quarkus (backend) e Angular (frontend) definida na spec. A presença é registrada por chamada de aula, por cartão, por digital simulada ou pelo Catraca Facial, em uma única tabela de frequência. O escopo do MVP está na seção 13.

## 13. ESCOPO DO MVP (4º BIMESTRE)

Entrega da apresentação final: semana de 09 a 16/11/2026. As decisões desta seção foram tomadas na sessão de escopo do MVP e são referenciadas como **(MVP-Qn)**.

### 13.1 Entra no MVP

| **Área** | **Entrega** | **Quem usa** | **Decisão** |
| --- | --- | --- | --- |
| Cadastros | Alunos, professores, turmas, disciplinas, vínculos professor-disciplina e bimestres. Cadastro anual | ADMIN | Premissa (ver 13.4) |
| Matrícula | Matrícula de alunos em turmas, pela tela ou por CSV | ADMIN | MVP-Q13 |
| Credenciais | Cartão do aluno (`Codigo_Cartao`) e digital cadastrada pelo painel, com consentimento registrado antes | ADMIN | MVP-Q6 |
| Autenticação | Login JWT. ADMIN cria a conta do professor com senha temporária, com troca obrigatória no primeiro acesso. ADMIN redefine senhas | ADMIN, PROFESSOR | MVP-Q4, MVP-Q15 |
| Abertura de aula | Professor abre a aula no início (turma e disciplina). É uma ação separada do fechamento | PROFESSOR | MVP-Q8, MVP-Q12, seção 13.5 |
| Fechamento parcial | Professor fecha a chamada depois que os alunos registraram presença. Ausentes recebem falta naquele momento | PROFESSOR | MVP-Q7 |
| Presença após fechamento | Após o fechamento, leituras são recusadas. Atrasado é registrado manualmente pelo professor, substituindo a falta | PROFESSOR | MVP-Q9 |
| Presença por cartão | Registro pelo número do cartão | Sistema | MVP-Q1 (cartão) |
| Presença por digital | Digital simulada pelo painel, com `Metodo = SIMULADO` | Sistema | MVP-Q1, MVP-Q2, MVP-Q3 |
| Registro manual | Professor registra presença manual até o fim do bimestre. ADMIN corrige depois | PROFESSOR, ADMIN | MVP-Q10 |
| Fechamento do bimestre | Automático, pela `Data_Fim` cadastrada na tabela `BIMESTRE` | Sistema | MVP-Q11 |
| Painel do dia | Presentes, atrasados e ausentes de cada aula da própria turma (Consulta 3) | PROFESSOR | MVP-Q5 |
| Relatório mensal | Frequência mensal por turma (Consulta 1) | ADMIN | MVP-Q5 |

### 13.2 Fica fora do MVP

- Biometria com leitor real e SDK. A integração (Q10 da seção 10) fica para quando o leitor for definido.
- Catraca Facial (Projeto 2). A presença `FACIAL` continua no modelo, sem implementação no bimestre.
- Notificações ao responsável, que ficam com o Connect (Q2 da seção 10).
- Alerta de evasão e a consulta de percentual abaixo de 75% na interface. A consulta fica disponível só no banco (MVP-Q5).
- Justificativa de falta pela interface. O status `JUSTIFICADA` permanece no modelo (MVP-Q14).
- Recuperação de senha por e-mail (MVP-Q15).
- Plano de backup como código. Se a banca cobrar, entra como documento.

### 13.3 Critérios de aceite

Critérios verificados por testes automatizados e pela demonstração (MVP-Q16):

1. **Fluxo de cadastro até a chamada:** ADMIN cadastra turma, disciplina, professor e bimestre, matricula aluno. O professor abre a aula, os alunos registram presença, e o professor fecha a chamada. O painel do dia reflete o resultado.
2. **Presença por cartão:** leitura de cartão registra presença com o método correto e status conforme o horário previsto da turma.
3. **Presença por digital simulada:** registra presença com `Metodo = SIMULADO`. Sem autorização de biometria, o cadastro da digital é recusado.
4. **Fechamento com faltas:** ausentes recebem `FALTA` no fechamento. Leitura após o fechamento é recusada. O registro manual de atrasado substitui a falta e é aceito até o fim do bimestre.
5. **Integridade no banco:** matrícula inválida é recusada; presença duplicada na mesma aula é ignorada; cartão repetido é recusado; abertura de aula por professor sem vínculo é recusada.
6. **Autenticação:** professor com senha temporária é obrigado a trocá-la no primeiro acesso. Professor vê só as próprias turmas.

### 13.4 Premissas a confirmar

- **Cadastro anual (MVP-Q12):** entendi que o ADMIN cadastra turmas, disciplinas e vínculos uma vez por ano, e o professor abre cada aula. Não há grade semanal no modelo.
- **Falta automática:** o fechamento grava `Metodo = MANUAL`, porque não há um valor próprio para a rotina automática.
- **Horário de referência do atraso:** `Turma.Horario_Inicio`, com 10 minutos de tolerância. Se duas disciplinas da mesma turma começam em horários diferentes, o modelo precisa de horário por aula.
- **Backup:** fica fora do MVP.

### 13.5 Decisões tomadas nesta revisão

Ao alinhar o modelo ao escopo, estas escolhas foram feitas e ficam sujeitas a confirmação:

- **Abertura e fechamento são ações separadas.** A alternativa, fechar no momento da abertura, marcaria todos os alunos como falta.
- **Aula com chave por turma, disciplina e dia.** Uma turma com a mesma disciplina duas vezes no mesmo dia não é suportada.
- **`FREQUENCIA` referencia `AULA`, e não turma e data.** Isso elimina a dependência transitiva e mantém 3NF.
- **Correção manual substitui falta.** A alternativa, duplicar a linha, violaria a `UNIQUE`.
- **Bimestres não se sobrepõem.** Garantido por `EXCLUDE`.
- **`app_biometria` lê `ALUNO_RESPONSAVEL`.** Sem essa leitura, o trigger de consentimento falha quando executa com os privilégios do papel.

## Checklist de Entregáveis

- ☒ Escopo do MVP fechado (seção 13)
- ☒ Inconsistências entre escopo e modelo tratadas (seção 13.5)
- ☒ Modelo Entidade-Relacionamento revisado (PostgreSQL)
- ☒ Scripts SQL escritos (PostgreSQL), incluindo `AULA`, `BIMESTRE` e `SIMULADO`
- ☐ Scripts SQL executados em PostgreSQL
- ☒ Integridade referencial definida
- ☒ Consentimento biométrico garantido por trigger
- ☒ Faltas geradas pelo fechamento parcial da aula (`sp_fechar_chamada_parcial`)
- ☒ Índices definidos
- ☒ Procedures e função principais escritas em PL/pgSQL
- ☒ Conflitos de escopo decididos (seção 10 e seção 13)
- ☐ Consultas validadas com dados de teste
- ☐ Plano de backup documentado (`pg_dump` / `pg_basebackup`)
- ☐ Integração com Quarkus testada

## Referências Consultadas

- Aulas de Programação e Administração de Banco de Dados
- Documentação oficial do PostgreSQL 16
- Normalização de Dados (Codd)
- ANSI SQL Standards
- Lei Geral de Proteção de Dados (Lei nº 13.709/2018)
- Documentação do Quarkus 3.40 e do Angular 22
