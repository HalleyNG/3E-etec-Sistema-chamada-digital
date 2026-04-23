Modelagem de Dados - Sistema de Chamada Digital

Este documento detalha a estrutura do banco de dados para o projeto de Chamada Digital, conforme os requisitos de automação, segurança e organização escolar.

1. Diagrama Entidade-Relacionamento (Conceitual)

O sistema baseia-se na relação entre Alunos, Professores e Disciplinas, tendo a "Presença" como a entidade central que regista a interacção entre eles.

2. Estrutura das Tabelas (Lógico)

Tabela: usuarios

Armazena as credenciais de acesso para professores e gestores.

id (PK): Inteiro, Auto-incremento.

nome: Varchar(100) - Nome completo do utilizador.

email: Varchar(100) - Identificador único (Login).

senha: Varchar(255) - Hash de segurança da password.

tipo: Enum('Professor', 'Admin') - Nível de acesso.

Tabela: alunos

Cadastro dos estudantes que realizarão a chamada.

id (PK): Inteiro, Auto-incremento.

nome: Varchar(100) - Nome completo.

matricula: Varchar(20) - Código único escolar.

qr_code_token: Varchar(255) - Código único para gerar o QR Code individual.

turma_id (FK): Referência à tabela turmas.

Tabela: turmas

Define os agrupamentos de alunos (Ex: 1º Ano A, 2º Ano B).

id (PK): Inteiro, Auto-incremento.

nome: Varchar(50) - Identificação da turma.

ano_letivo: Ano.

Tabela: disciplinas

Matérias leccionadas.

id (PK): Inteiro, Auto-incremento.

nome: Varchar(50) - Ex: Matemática, História.

professor_id (FK): Referência ao professor responsável.

Tabela: presencas

Registo automático da frequência.

id (PK): Inteiro, Auto-incremento.

aluno_id (FK): Identifica o aluno presente.

disciplina_id (FK): Identifica a aula.

data_hora: Timestamp - Registo exato da presença (Data e Hora).

status: Varchar(20) - Ex: 'Presente', 'Atraso'.

3. Implementação SQL (Físico)

Abaixo, o script compatível com SQLite ou MySQL:

-- Criar Tabela de Utilizadores/Professores
CREATE TABLE usuarios (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    nome VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    senha VARCHAR(255) NOT NULL,
    tipo TEXT CHECK(tipo IN ('Professor', 'Admin')) DEFAULT 'Professor'
);

-- Criar Tabela de Turmas
CREATE TABLE turmas (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    nome VARCHAR(50) NOT NULL
);

-- Criar Tabela de Alunos
CREATE TABLE alunos (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    nome VARCHAR(100) NOT NULL,
    matricula VARCHAR(20) UNIQUE NOT NULL,
    qr_code_token VARCHAR(255) UNIQUE,
    turma_id INTEGER,
    FOREIGN KEY (turma_id) REFERENCES turmas(id)
);

-- Criar Tabela de Disciplinas
CREATE TABLE disciplinas (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    nome VARCHAR(50) NOT NULL,
    professor_id INTEGER,
    FOREIGN KEY (professor_id) REFERENCES usuarios(id)
);

-- Criar Tabela de Registo de Chamada
CREATE TABLE presencas (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    aluno_id INTEGER,
    disciplina_id INTEGER,
    data_hora TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(20) DEFAULT 'Presente',
    FOREIGN KEY (aluno_id) REFERENCES alunos(id),
    FOREIGN KEY (disciplina_id) REFERENCES disciplinas(id)
);


4. Considerações de Escalabilidade (Melhorias Futuras)

Índices: Criar um índice no campo data_hora para acelerar a geração de relatórios mensais.

Segurança: O campo qr_code_token deve ser encriptado ou gerado de forma aleatória (UUID) para evitar que alunos criem QR Codes falsos.

Logs: Implementação de uma tabela de auditoria para registar quem alterou uma presença manualmente (caso o professor precise corrigir um erro).
