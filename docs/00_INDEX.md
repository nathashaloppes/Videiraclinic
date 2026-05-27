# Videira Dental Clinic — Índice

> Mapa central do projeto. Abra este arquivo no Obsidian para navegar por toda a documentação.

---

## 01 · Projeto

| Documento | Descrição |
|-----------|-----------|
| [[FONTE_DA_VERDADE]] | Documento master — spec canônica do sistema |
| [[CONTEXT]] | Fonte da verdade de implementação — decisões e correções reais |
| [[ATIVIDADES]] | Backlog priorizado de tarefas pendentes |
| [[ROADMAP]] | Fases e marcos do produto |
| [[ROADMAP_TECNICO]] | Tarefas técnicas em ordem de implementação, com prompts prontos |

## 02 · Arquitetura

| Documento | Descrição |
|-----------|-----------|
| [[ARQUITETURA]] | Camadas, convenções e padrões de código |
| [[BANCO_DE_DADOS]] | Schema PostgreSQL e migrations |
| [[MODULOS]] | Mapa funcional dos 5 módulos do sistema |

## 03 · Design

| Documento | Descrição |
|-----------|-----------|
| [[README]] (em `03_design/`) | **Comece aqui** — índice e fluxo recomendado |
| [[TEMPLATE_TELA_E_MODAL]] | Esqueletos prontos para criar telas e modais novos |
| [[DESIGN_SYSTEM]] | Tokens, classes utilitárias `.btn-*`/`.card-*`/`.badge-*` e helpers Ruby |
| [[CATALOGO_TELAS]] | Mapa das telas existentes para reuso ao construir telas novas |
| [[ARCHIVE_RESTYLING]] | Histórico (arquivado) do restyling inicial — não usar como guia |

## 04 · Processo

| Documento | Descrição |
|-----------|-----------|
| [[JORNADA_DEV_SOLO]] | Guia prático de uso do Claude Code para devs solo |
| [[PROMPT_ARCHITECTURE]] | Arquitetura de documentação e prompts para projetos com IA |

## 05 · Setup

| Documento | Descrição |
|-----------|-----------|
| [[VSCODE_SETUP]] | Configuração completa do editor para o projeto Rails |

---

## Fluxo de leitura recomendado

```
FONTE_DA_VERDADE → ARQUITETURA → BANCO_DE_DADOS → MODULOS
       ↓
  ROADMAP_TECNICO → ATIVIDADES
       ↓
  03_design/README → TEMPLATE_TELA_E_MODAL → DESIGN_SYSTEM → CATALOGO_TELAS
```

> **README.md** (raiz do projeto) cobre setup local, OAuth, MercadoPago e deploy com Kamal.
