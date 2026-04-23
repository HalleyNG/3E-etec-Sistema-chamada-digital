1. Modelo Entidade-Relacionamento (Conceitual)As principais entidades identificadas para o sistema são:Aluno: Informações cadastrais do estudante.Professor: Responsável por gerenciar as aulas.Turma/Disciplina: Agrupamento de alunos em um horário/matéria específica.Chamada (Registro): O evento onde a presença é marcada.2. Dicionário de Dados (Lógico)Tabela: alunosAtributoTipoDescriçãoid (PK)INT/UUIDIdentificador único do aluno.nomeVARCHARNome completo.matriculaVARCHARCódigo único de identificação escolar.emailVARCHAREmail institucional (como os citados no README).qr_code_tokenTEXTToken único para geração do QR Code individual.Tabela: professoresAtributoTipoDescriçãoid (PK)INTIdentificador do professor.nomeVARCHARNome do docente.emailVARCHARLogin para o sistema.senhaVARCHARHash da senha para autenticação.Tabela: turmasAtributoTipoDescriçãoid (PK)INTIdentificador da turma.nome_disciplinaVARCHAREx: Matemática, História.professor_id (FK)INTRelaciona qual professor ministra essa turma.Tabela: presencas (O coração do sistema)AtributoTipoDescriçãoid (PK)INTIdentificador do registro.aluno_id (FK)INTQuem marcou presença.turma_id (FK)INTEm qual aula a presença foi marcada.data_horaTIMESTAMPRegistro automático de quando o aluno chegou.metodoENUM'QR Code', 'Manual', 'Login'.3. Script SQL para Implementação (Físico)Se você estiver usando MySQL ou SQLite (citados no README), pode usar este código para criar as tabelas:SQL-- Criação da tabela de Alunos
CREATE TABLE alunos (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    nome VARCHAR(100) NOT NULL,
    matricula VARCHAR(20) UNIQUE NOT NULL,
    email VARCHAR(100),
    qr_code_token TEXT UNIQUE
);

-- Criação da tabela de Professores
CREATE TABLE professores (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    nome VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    senha VARCHAR(255) NOT NULL
);

-- Criação da tabela de Turmas/Disciplinas
CREATE TABLE turmas (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    nome_disciplina VARCHAR(50) NOT NULL,
    professor_id INTEGER,
    FOREIGN KEY (professor_id) REFERENCES professores(id)
);

-- Tabela de ligação Aluno <-> Turma (Muitos para Muitos)
CREATE TABLE turma_alunos (
    turma_id INTEGER,
    aluno_id INTEGER,
    PRIMARY KEY (turma_id, aluno_id),
    FOREIGN KEY (turma_id) REFERENCES turmas(id),
    FOREIGN KEY (aluno_id) REFERENCES alunos(id)
);

-- Registro de Presença
CREATE TABLE presencas (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    aluno_id INTEGER,
    turma_id INTEGER,
    data_hora TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    metodo VARCHAR(20),
    FOREIGN KEY (aluno_id) REFERENCES alunos(id),
    FOREIGN KEY (turma_id) REFERENCES turmas(id)
);
