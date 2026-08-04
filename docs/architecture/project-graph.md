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
    ├── PnetCDF 1.15.0 ✅
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

No ciclo 0002, a implementação termina em PnetCDF 1.15.0. PIO2, METIS, WPS e
MPAS permanecem no grafo como destino do plano, não como componentes
concluídos.

PnetCDF não depende da seta HDF5 → netCDF neste ciclo. A ordem no `Dockerfile`
preserva a stack já construída, mas o caminho funcional novo é independente:

```text
tests/smoke/pnetcdf_mpi.f90
          ↓
   API Fortran PnetCDF
          ↓
   PnetCDF 1.15.0
          ↓
 MPI-IO (ROMIO 4.1.6)
          ↓
     OpenMPI 4.1.6
```

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
│   │   ├── README.md                 política e template de ADR
│   │   └── 0001-pnetcdf-mpiio-backend.md
│   │                                  decisão PnetCDF/GIO/MPI-IO
│   ├── testing/
│   │   └── validation-matrix.md      testes, status e evidências
│   └── logs/                         reservado; atualmente vazio
├── learning/
│   ├── README.md                     índice e regras do material didático
│   ├── baseline.md                   explicação da stack já construída
│   └── commits/
│       ├── 0001-bootstrap-codex-workflow.md
│       └── 0002-add-pnetcdf.md         nota educacional do ciclo 0002
├── scripts/
│   ├── validate/
│   │   └── pnetcdf.sh                validação instalada MPI/Fortran
│   └── codex/                        automações de suporte a ciclos futuros
├── tests/
│   └── smoke/
│       └── pnetcdf_mpi.f90           I/O coletivo CDF-5 em 4 ranks
├── data/                              entradas locais; dados grandes fora do Git
├── cases/                             configurações futuras de experimentos
└── docker/                            suporte Docker futuro
```

`scripts/validate/` passa a ser rastreável pelo script PnetCDF no ciclo 0002.
`scripts/codex/` continua vazio e, por isso, não é preservado pelo Git.

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
| `tests/smoke/` | hospedar fontes mínimas independentes do build upstream | compiladas pelos scripts contra a instalação final |
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
