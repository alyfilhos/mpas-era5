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
    ├── PIO 2.7.0 ✅
    │     ↓
    └── METIS 5.1.0 ✅

WPS 4.7.0 / ungrib ✅ ──→ WPS intermediate ──→ dados futuros
                                                    │
                                                    ▼
PIO 2.7.0 ✅ ──→ MPAS 8.4.1
                    ├── init_atmosphere_model ✅ estrutural
                    └── atmosphere_model ✅ estrutural; execução ⏳

MPAS-Atmosphere Meshes (oficial)
        ↓
scripts/data/fetch-mesh.sh
        ↓
data/meshes/x1.10242/
        ├── x1.10242.grid.nc
        └── x1.10242.graph.info
                      ↓
              METIS 5.1.0
                      ↓
          x1.10242.graph.info.part.4
                      ↓
          init_atmosphere futuro
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

/opt/wps-4.7.0 → ungrib.exe
/opt/wps       → /opt/wps-4.7.0

/opt/mpas-model-8.4.1 → init_atmosphere_model
                       └──→ atmosphere_model
/opt/mpas-model       → /opt/mpas-model-8.4.1
```

No ciclo 0007, a stack científica sob `/opt/mpas` permaneceu inalterada e
todas as camadas até o init foram recuperadas do cache. O core `atmosphere`
foi acrescentado à mesma árvore `/opt/mpas-model-8.4.1`; os dois executáveis
estão presentes, enquanto a execução com mesh/dados continua pendente.

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

PIO preserva esse caminho paralelo e acrescenta a camada de abstração usada
por `init_atmosphere_model` e `atmosphere_model`:

```text
tests/smoke/pio_pnetcdf.c
          ↓
   API C do PIO 2.7.0
          ↓
  PIO_IOTYPE_PNETCDF
          ↓
   PnetCDF 1.15.0
          ↓
 MPI-IO (OMPIO ou ROMIO local)
          ↓
     OpenMPI 4.1.6
```

HDF5 e netCDF permanecem seriais. O PIO também disponibiliza o backend
`PIO_IOTYPE_NETCDF`; `PIO_IOTYPE_NETCDF4C` e `PIO_IOTYPE_NETCDF4P` não são
compilados nesta configuração.

METIS não pertence ao caminho de I/O e não é uma implementação MPI. Seu fluxo
é serial, externo e anterior ao modelo:

```text
tests/fixtures/metis/graph.info
          ↓
gpmetis -minconn -contig -niter=200 graph.info N
          ↓
graph.info.part.N
          ↓
MPAS com N ranks MPI em um ciclo funcional futuro
```

O script `scripts/validate/metis.sh` copia o fixture para tmpfs, gera
`graph.info.part.4` somente ali e valida estrutura, IDs, cobertura,
balanceamento, `edge cut` e conectividade.

O ciclo 0008 aplica o mesmo contrato a uma entrada científica real, mantendo
os dados fora da imagem e do Git:

```text
https://www2.mmm.ucar.edu/.../x1.10242.tar.gz
        ↓ SHA-256 local fixado
scripts/data/fetch-mesh.sh
        ↓
data/meshes/x1.10242/x1.10242.graph.info
        ↓ scripts/prepare/partition-mesh.sh
gpmetis -minconn -contig -niter=200 ... 4
        ↓
x1.10242.graph.info.part.4
        ↓ scripts/validate/mesh.sh
NetCDF + graphchk + estrutura + balanceamento + edge cut + contiguidade ✅
```

WPS prepara dados meteorológicos por um caminho distinto da stack científica:

```text
ERA5 GRIB (futuro)
       ↓
Vtable aprovada (pendente)
       ↓
/opt/wps/ungrib.exe
       ↓
WPS intermediate
       ↓
MPAS init_atmosphere (build pronto; execução pendente)
       ↓
MPAS atmosphere (build pronto; execução pendente)
```

`scripts/validate/wps-ungrib.sh` valida a instalação sem rede e sem dados.
As bibliotecas zlib, libpng e JasPer construídas por
`--build-grib2-libs` ficam em `/opt/wps-4.7.0/grib2`, separadas das versões da
stack em `/opt/mpas`. A integração funcional exige ERA5 GRIB e permanece
pendente.

As dependências de física do atmosphere são materializadas antes do make:

```text
Externals.cfg
    ├── MMM-physics tag → commit exato
    └── UGWP tag        → commit exato

checkout_data_files.sh (`mpas_vers=8.2`)
    ↓
MPAS-Data v8.2 → commit exato → COMPATIBILITY → 16 lookup tables
    ↓
physics_wrf/files → manifesto SHA-256 → build offline quanto aos dados
```

## Fluxo de governança

```text
AGENTS.md
    ↓
docs/project/requirements.md
    ├── docs/references/source-registry.md
    ├── docs/references/versions.lock.md
    ├── docs/decisions/
    ├── docs/project/future-experiments.md
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
│   ├── cases/
│   │   └── first-global-240km.md     primeiro caso; mesh pronta
│   ├── project/
│   │   ├── requirements.md           escopo original versus decisões
│   │   ├── current-state.md          estado produzido e referência Git real
│   │   ├── development-workflow.md   ciclo obrigatório de desenvolvimento
│   │   └── future-experiments.md     backlog, não roadmap aprovado
│   ├── references/
│   │   ├── source-registry.md        classificação e proveniência das fontes
│   │   └── versions.lock.md          versões adotadas e pendências
│   ├── decisions/
│   │   ├── README.md                 política e template de ADR
│   │   ├── 0001-pnetcdf-mpiio-backend.md
│   │   │                              decisão PnetCDF/GIO/MPI-IO
│   │   ├── 0002-pio2-pnetcdf-with-serial-netcdf.md
│   │   │                              arquitetura PIO2 e backends habilitados
│   │   ├── 0003-metis-5.1.0-partitioning-baseline.md
│   │                                  baseline offline e alternativas futuras
│   │   ├── 0004-wps-mpas-version-and-layout.md
│   │   │                              versões, flags e prefixos separados
│   │   └── 0005-first-mesh-baseline.md
│   │                                  x1.10242 e part.4 aprovadas
│   ├── testing/
│   │   └── validation-matrix.md      testes, status e evidências
│   └── logs/                         reservado; atualmente vazio
├── learning/
│   ├── README.md                     índice e regras do material didático
│   ├── baseline.md                   explicação da stack já construída
│   └── commits/
│       ├── 0001-bootstrap-codex-workflow.md
│       ├── 0002-add-pnetcdf.md         nota educacional do ciclo 0002
│       ├── 0003-add-pio2.md            nota educacional do ciclo 0003
│       ├── 0004-add-metis.md           nota educacional do ciclo 0004
│       ├── 0005-add-wps-ungrib.md      nota educacional do ciclo 0005
│       ├── 0006-add-mpas-init-atmosphere.md
│       │                                  nota educacional do ciclo 0006
│       ├── 0007-add-mpas-atmosphere.md
│       │                                  nota educacional do ciclo 0007
│       └── 0008-add-first-mesh.md         nota educacional do ciclo 0008
├── scripts/
│   ├── data/
│   │   └── fetch-mesh.sh             aquisição first-party e integridade
│   ├── prepare/
│   │   └── partition-mesh.sh         graph.info + N → part.N com METIS
│   ├── validate/
│   │   ├── pnetcdf.sh                validação instalada MPI/Fortran
│   │   ├── pio.sh                    validação PIO/PnetCDF e IOTYPEs
│   │   ├── metis.sh                  partição e validação estrutural em tmpfs
│   │   ├── wps-ungrib.sh             smoke WPS offline e read-only
│   │   ├── mpas-init.sh              smoke MPAS init offline/read-only
│   │   ├── mpas-atmosphere.sh        smoke MPAS atmosphere offline/read-only
│   │   └── mesh.sh                   validação da mesh real e partição
│   └── codex/                        automações de suporte a ciclos futuros
├── tests/
│   ├── fixtures/
│   │   └── metis/
│   │       └── graph.info            grafo didático de 16 vértices
│   └── smoke/
│       ├── pnetcdf_mpi.f90           I/O coletivo CDF-5 em 4 ranks
│       └── pio_pnetcdf.c             PIO explícito sobre PnetCDF em 4 ranks
├── data/                              entradas científicas locais fora do Git
│   └── meshes/x1.10242/               grid, graph.info e part.4 ignorados
├── cases/                             configurações futuras de experimentos
└── docker/                            suporte Docker futuro
```

`scripts/validate/` contém validações instaladas e repetíveis para PnetCDF,
PIO, METIS, WPS/ungrib, os dois cores MPAS e a mesh x1.10242.
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
| `scripts/data/` | adquirir dados externos reproduzivelmente | usa somente fontes e hashes registrados; instala sob `data/` |
| `scripts/prepare/` | transformar entradas sem incorporá-las à imagem | gera `graph.info.part.N` com UID/GID do usuário |
| `tests/smoke/` | hospedar fontes mínimas independentes do build upstream | compiladas pelos scripts contra a instalação final |
| `tests/fixtures/` | manter entradas pequenas, deliberadas e versionadas | copiadas para espaço efêmero; nunca recebem saídas geradas |
| `scripts/codex/` | hospedar automação de governança aprovada | deve respeitar `AGENTS.md` e o workflow |
| `data/` | manter meshes, ERA5 e outras entradas científicas locais | credenciais, NetCDF, GRIB, partições e outputs nunca devem entrar no Git |
| `cases/` | manter configurações de execuções MPAS | depende de mesh, ERA5 e versões aprovadas |

## Documentos relacionados

- [[../README|Índice da documentação]]
- [[../build/scientific-stack|Stack científica]]
- [[../project/requirements|Requisitos do projeto]]
- [[../project/current-state|Estado atual]]
- [[../project/development-workflow|Workflow de desenvolvimento]]
- [[../project/future-experiments|Experimentos técnicos futuros]]
- [[../references/source-registry|Registro de fontes]]
- [[../references/versions.lock|Versões adotadas e pendentes]]
- [[../decisions/README|ADRs]]
- [[../decisions/0003-metis-5.1.0-partitioning-baseline|ADR 0003 — METIS 5.1.0]]
- [[../decisions/0004-wps-mpas-version-and-layout|ADR 0004 — WPS/MPAS e layout]]
- [[../decisions/0005-first-mesh-baseline|ADR 0005 — primeira mesh e part.4]]
- [[../cases/first-global-240km|Primeiro caso global de ~240 km]]
- [[../testing/validation-matrix|Matriz de validação]]
- [[../../learning/README|Índice de aprendizado]]
