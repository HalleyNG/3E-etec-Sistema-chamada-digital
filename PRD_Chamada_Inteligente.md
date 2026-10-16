# PRD: Chamada Inteligente (Projeto 1 — Núcleo)

O projeto é um sistema centralizado de gestão de presença escolar com controlo de frequência via biometria e cartões de identificação.

**Equipa do Projeto:**

* **Analista:** Andressa da Cruz Melo (e2316551@edu.mt.gov.br)
* **Frontend:** Halley Pedroso Suniga (e2281524@edu.mt.gov.br)
* **Backend:** Gustavo Leal (e2520025@edu.mt.gov.br)
* **Monitor responsável:** Diorge

---

## 1) Visão Geral e Objetivo

O objetivo é gerir a presença dos alunos, fornecendo os cadastros centrais e autenticação JWT da instituição. O sistema regista a frequência de forma segura via biometria digital da mão ou cartão, operando como base de dados e API para os restantes projetos.

## 2) Público-Alvo

* **Administradores (ADMIN):** Realizam cadastros anuais, gerem senhas e matrículas, e visualizam relatórios.
* **Professores:** Abrem sessões de aulas, fecham chamadas, ajustam frequência manualmente e consultam o painel diário.
* **Alunos e Responsáveis:** Alunos submetem o registo de presença. Responsáveis autorizam a recolha biométrica dos educandos.

## 3) Escopo

**Dentro (MVP):**

* Parametrização cadastral (alunos, professores, turmas, disciplinas, bimestres) e matrículas.
* Gestão de credenciais (cartão único e biometria digital simulada) e autenticação JWT com troca de senha obrigatória.
* Operações de chamada (abertura, registo automatizado simulado, fechamento parcial e correção manual).
* Painel do dia por aula e relatório consolidado mensal.

**Fora (MVP):**

* Integração física com leitores biométricos e SDKs.
* Módulo Catraca Facial (Projeto 2) e envio de notificações aos responsáveis.
* Alertas automáticos de evasão escolar, justificação de faltas via ecrã e recuperação de senha por e-mail.
* Plano de backup como código.

## 4) Requisitos Funcionais

* **RF01:** O sistema deve permitir o cadastro de Alunos, Professores, Turmas, Disciplinas e Bimestres.
* **RF02:** O sistema deve exigir o registo de autorização do responsável antes de cadastrar dados biométricos.
* **RF03:** O sistema deve autenticar os perfis ADMIN e PROFESSOR via JWT.
* **RF04:** O sistema deve obrigar a alteração da senha no primeiro acesso do perfil PROFESSOR.
* **RF05:** O sistema deve permitir que o professor abra aulas apenas nas suas turmas em dias letivos.
* **RF06:** O sistema deve registar presenças automatizadas via cartão ou biometria simulada.
* **RF07:** O sistema deve atribuir "FALTA" automática aos alunos sem registo durante o fechamento parcial da chamada.
* **RF08:** O sistema deve permitir aos professores a retificação manual da frequência pós-fechamento.

## 5) Requisitos Não Funcionais

* **Arquitetura:** O backend será em Quarkus 3.40.1 (Java 17) via JDBC, frontend em Angular 22, com SGBD PostgreSQL 16.
* **Segurança e LGPD:** O sistema deve armazenar apenas *templates* biométricos irreversíveis (formato `BYTEA`), excluindo-os em cascata na remoção do aluno. As senhas devem possuir hash criptográfico.
* **Transacionalidade:** O banco de dados deve assegurar as propriedades ACID, utilizando transações e regras de exclusividade (`UNIQUE`, `ON CONFLICT`) para evitar dados duplicados.

## 6) Regras de Negócio

* A presença está vinculada à entidade "Aula" (turma, disciplina e dia), não apenas à turma.
* Um *trigger* no banco de dados bloqueia irreversivelmente a recolha biométrica sem o consentimento validado do responsável.
* Registos efetuados com mais de 10 minutos de atraso recebem automaticamente o status "ATRASADO".
* Professores podem corrigir presenças apenas até ao encerramento do bimestre. Após esta data, a ação é restrita ao perfil ADMIN.

## 7) Fluxos Principais

* **Abertura e Execução:** O professor autentica-se e abre a aula. Os alunos validam credenciais, e os registos refletem-se no painel em tempo real.
* **Fechamento:** O professor encerra a chamada. O sistema computa presenças e gera "FALTAS" para os ausentes.
* **Correção Excecional:** O professor atualiza manualmente o status de um aluno atrasado, e o sistema substitui a falta gerada pelo registo manual audível.

## 8) Critérios de Aceitação

* **Fluxo inicial garantido:** O ADMIN parametriza as bases e o professor executa o ciclo completo da chamada sem erros.
* **Restrição legal cumprida:** A tentativa de registo biométrico sem permissão legal resulta em falha sistémica imediata.
* **Fechamento fiável:** Todos os alunos matriculados não verificados recebem falta automática no momento do encerramento da chamada.
* **Consistência de dados:** Tentativas de leitura duplicadas ou em sessões fechadas são rejeitadas de imediato pelo banco de dados.

## 9) Priorização (MVP) e Riscos

* **Priorização:** O MVP concentra-se na estabilidade do modelo relacional, nas permissões baseadas em perfis e na validação do fluxo operatório com recurso a biometria simulada.
* **Riscos:** A integração futura com leitores físicos dependerá do suporte do fabricante para Java/JNI. A mitigação exigirá o desenvolvimento de um agente HTTP local em caso de incompatibilidade tecnológica.
