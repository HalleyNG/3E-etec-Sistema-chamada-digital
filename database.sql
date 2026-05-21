-- ==========================================
-- BANCO DE DADOS - SISTEMA DE CHAMADA DIGITAL
-- ==========================================

CREATE DATABASE IF NOT EXISTS chamada_digital;
USE chamada_digital;

-- =====================
-- TABELA DE ALUNOS
-- =====================

CREATE TABLE alunos (
    id INT AUTO_INCREMENT PRIMARY KEY,
    matricula VARCHAR(20) NOT NULL UNIQUE,
    nome VARCHAR(100) NOT NULL,
    turma VARCHAR(50) NOT NULL,
    email VARCHAR(100),
    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =====================
-- TABELA DE PRESENÇAS
-- =====================

CREATE TABLE presencas (
    id INT AUTO_INCREMENT PRIMARY KEY,
    aluno_id INT NOT NULL,
    data_chamada DATE NOT NULL,
    horario_registro TIME NOT NULL,
    status ENUM('presente', 'ausente', 'atrasado') DEFAULT 'presente',
    metodo_registro ENUM('login', 'qr_code', 'manual') DEFAULT 'login',
    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_presenca_aluno
        FOREIGN KEY (aluno_id)
        REFERENCES alunos(id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

-- =====================
-- DADOS DE TESTE
-- =====================

INSERT INTO alunos (matricula, nome, turma, email) VALUES
('2025001', 'João Silva', '2º Ano DS E', 'joao@email.com'),
('2025002', 'Maria Souza', '2º Ano DS E', 'maria@email.com');

INSERT INTO presencas (
    aluno_id,
    data_chamada,
    horario_registro,
    status,
    metodo_registro
) VALUES
(1, CURDATE(), CURTIME(), 'presente', 'qr_code'),
(2, CURDATE(), CURTIME(), 'presente', 'login');
