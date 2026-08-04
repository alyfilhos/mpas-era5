# Grafo do projeto

## Fluxo principal

```text
Dockerfile
    │
    ▼
Stack científica
    │
    ├── zlib
    │     ↓
    ├── HDF5
    │     ↓
    ├── netCDF-C
    │     ↓
    ├── netCDF-Fortran
    │     ↓
    ├── PnetCDF
    │     ↓
    ├── PIO2
    │     ↓
    └── METIS
          │
          ▼
       MPAS build
```

## Stack científica

```text
Dockerfile
→ zlib
→ HDF5
→ netCDF-C
→ netCDF-Fortran
→ PnetCDF
→ PIO2
→ METIS
→ MPAS
```

No ciclo 0001, a implementação termina em netCDF-Fortran. PnetCDF, PIO2,
METIS, WPS e MPAS permanecem no grafo como destino do plano, não como
componentes concluídos.

## Fluxo de governança

```text
AGENTS.md
    ↓
docs/project/requirements.md
    ├── docs/references/source-registry.md
    ├── docs/references/versions.lock.md
    ├── docs/decisions/
    └── docs/testing/validation-matrix.md
            ↓
      implementação e testes
            ↓
docs/project/current-state.md
            ↓
learning/commits/NNNN-*.md
            ↓
relatório pré-commit → aprovação → commit → push
```

## Estrutura do repositório

```text
mpas-era5/
├── AGENTS.md                         regras obrigatórias dos ciclos assistidos
├── .codex/
│   └── config.toml                   política local de aprovação e sandbox
├── Dockerfile                        ambiente e stack científica
├── README.md                         entrada pública do projeto
├── docs/
│   ├── README.md                     índice Obsidian da documentação
│   ├── architecture/
│   │   └── project-graph.md          este mapa
│   ├── build/
│   │   └── scientific-stack.md       documentação técnica da stack
│   ├── project/
│   │   ├── requirements.md           escopo original versus decisões
│   │   ├── current-state.md          somente estado e evidências atuais
│   │   └── development-workflow.md   ciclo obrigatório de desenvolvimento
│   ├── references/
│   │   ├── source-registry.md        classificação e proveniência das fontes
│   │   └── versions.lock.md          versões adotadas e a decidir
│   ├── decisions/
│   │   └── README.md                 política e template de ADR
│   ├── testing/
│   │   └── validation-matrix.md      testes, status e evidências
│   └── logs/                         reservado; atualmente vazio
├── learning/
│   ├── README.md                     índice e regras do material didático
│   ├── baseline.md                   explicação da stack já construída
│   └── commits/
│       └── 0001-bootstrap-codex-workflow.md
│                                      nota educacional deste ciclo
├── scripts/
│   ├── validate/                     validações reproduzíveis futuras
│   └── codex/                        automações de suporte a ciclos futuros
├── data/                              entradas locais; dados grandes fora do Git
├── cases/                             configurações futuras de experimentos
└── docker/                            suporte Docker futuro
```

`scripts/validate/` e `scripts/codex/` são criados vazios no ciclo 0001. Git
não preserva diretórios vazios; a primeira automação aprovada deverá criar o
arquivo correspondente e atualizar este grafo se a responsabilidade mudar.

## Responsabilidades e relações

| Caminho | Responsabilidade | Relações principais |
|---|---|---|
| `Dockerfile` | construir ambiente e bibliotecas adotadas | versões em `docs/references/versions.lock.md`; testes em `docs/testing/validation-matrix.md` |
| `docs/project/` | controlar escopo, estado e processo | lido antes de todo ciclo conforme `AGENTS.md` |
| `docs/references/` | registrar autoridade das fontes e versões | alimenta propostas, ADRs e reprodução do build |
| `docs/decisions/` | preservar decisões significativas e alternativas | depende de proposta e decisão do usuário |
| `docs/testing/` | distinguir teste planejado, executado e comprovado | atualizada após cada validação técnica |
| `learning/` | explicar conceitos e raciocínio por baseline/commit | referencia estado, fontes, ADRs e testes sem substituí-los |
| `scripts/validate/` | hospedar validações repetíveis | resultados resumidos alimentam `docs/testing/` |
| `scripts/codex/` | hospedar automação de governança aprovada | deve respeitar `AGENTS.md` e o workflow |
| `data/` | manter entradas locais do ERA5 e auxiliares | credenciais e dados grandes nunca devem entrar no Git |
| `cases/` | manter configurações de execuções MPAS | depende de mesh, ERA5 e versões aprovadas |

## Documentos relacionados

- [[../README|Índice da documentação]]
- [[../build/scientific-stack|Stack científica]]
- [[../project/requirements|Requisitos do projeto]]
- [[../project/current-state|Estado atual]]
- [[../project/development-workflow|Workflow de desenvolvimento]]
- [[../references/source-registry|Registro de fontes]]
- [[../references/versions.lock|Versões adotadas e pendentes]]
- [[../decisions/README|ADRs]]
- [[../testing/validation-matrix|Matriz de validação]]
- [[../../learning/README|Índice de aprendizado]]
