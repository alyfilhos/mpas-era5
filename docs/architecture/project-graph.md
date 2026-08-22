# Grafo do projeto

Este documento é o mapa principal do repositório. Ele responde onde cada
responsabilidade vive, o que é versionado e como dados, código, documentação e
evidência se conectam.

## Pipeline científico final

```text
CDS ERA5
   ↓
GRIB
   ↓
WPS/ungrib
   ↓
WPS intermediate
   ↓
MPAS init_atmosphere
   ├── WPS_GEOG → static.nc
   └── static + ERA5 → init.nc
                           ↓
                    atmosphere_model
                           ↓
                    history / diag
                           ↓
                  analysis container
                           ↓
                 sanity + figures
```

A mesh e o particionamento entram nos dois executáveis MPAS:

```text
MPAS mesh x1.10242 ─→ grid.nc ───────────────┐
        │                                     ├→ init_atmosphere
        └→ graph.info → METIS → part.4 ──────┤       │
                                              │       └→ static.nc / init.nc
                                              └→ atmosphere_model (4 ranks)
```

## Containers e separação de responsabilidades

```text
scientific                         acquisition                    analysis
Dockerfile                         docker/cds/                    docker/analysis/
GNU + OpenMPI                    Python + cdsapi               Python + xarray
scientific libraries              CDS requests                   NumPy/netCDF4
METIS + WPS + MPAS               CDS credential at runtime      Matplotlib
        │                                  │                           │
        └── offline processing             └── writes raw ERA5         └── read-only NetCDF
```

| Imagem | Pode usar rede | Inputs | Output autorizado |
|---|---|---|---|
| científica | build/aquisição de source; runtime científico não | mesh, geog, ERA5, configs read-only | workspace sob `data/` |
| aquisição | sim, somente ao consultar CDS | requests e secret read-only | ERA5/manifesto local |
| análise | build; runtime não | init/history/diag read-only | summary/CSV/PNGs pequenos |

A separação foi formalizada no
[[../decisions/0009-separate-analysis-container|ADR 0009]].

## Stack científica

```text
Ubuntu 24.04
  └→ GNU 13.3.0 + OpenMPI 4.1.6 (observados)
      ├→ zlib 1.3.2
      │   └→ HDF5 1.14.6 serial
      │       └→ netCDF-C 4.10.1 serial
      │           └→ netCDF-Fortran 4.6.3
      ├→ PnetCDF 1.15.0 → MPI-IO
      │   └→ PIO 2.7.0
      │       └→ MPAS-Model 8.4.1
      ├→ METIS 5.1.0 → part.N
      └→ WPS 4.7.0 → ungrib + g1print
```

HDF5/netCDF permanecem seriais. O I/O paralelo usado pelo MPAS é:

```text
MPAS → PIO_IOTYPE_PNETCDF → PnetCDF → MPI-IO → OpenMPI
```

Os smokes instalados em
[`scripts/validate/core-libraries.sh`](../../scripts/validate/core-libraries.sh)
comprovam zlib → HDF5 → netCDF-C → netCDF-Fortran. PnetCDF/PIO têm smokes
MPI próprios. Evidência: [[../testing/validation-matrix|matriz]].

## Árvore final

```text
mpas-era5/
├── AGENTS.md                     governança obrigatória
├── Dockerfile                    imagem/stack científica
├── README.md                     página pública
├── cases/
│   └── first-global-240km/       configs static, ERA5, WPS, init, atmosphere
├── docker/
│   ├── cds/                      imagem de aquisição
│   └── analysis/                 imagem de análise
├── docs/
│   ├── README.md                 índice Obsidian
│   ├── architecture/             este grafo
│   ├── assets/validation/0014/   evidência visual/JSON/CSV pequena
│   ├── build/                    stack científica
│   ├── cases/                    documentação do caso
│   ├── decisions/                ADRs
│   ├── portfolio/                material de apresentação
│   ├── project/                  requisitos, estado, workflow, relatório
│   ├── references/               fontes e versões
│   ├── reproducibility/          guia end-to-end
│   ├── testing/                  matriz de validação
│   └── validation/               método e resultados científicos
├── learning/
│   ├── README.md                 índice didático
│   ├── baseline.md               conceitos da stack
│   └── commits/                  uma learning note por ciclo
├── scripts/
│   ├── analyze/                  análise científica
│   ├── data/                     aquisição de mesh/geog/ERA5
│   ├── prepare/                  partição da mesh
│   ├── run/                      static, ungrib, init, atmosphere
│   └── validate/                 smokes e validadores integrados/final
├── tests/
│   ├── fixtures/                 entradas didáticas pequenas
│   └── smoke/                    fontes mínimas de interfaces instaladas
└── data/                         dados científicos locais/ignorados
    ├── meshes/
    ├── geog/
    ├── era5/
    └── cases/
```

## Responsabilidade e política de versionamento

| Caminho | Responsabilidade | Versionado | Não versionado / onde procurar |
|---|---|---|---|
| `cases/` | contrato científico do primeiro caso | namelists, streams, lists e requests JSON | outputs ficam no espelho sob `data/cases/` |
| `docker/` | ambientes por responsabilidade | Dockerfiles e locks | imagens/layers/cache ficam no Docker |
| `docs/` | estado, arquitetura, decisão, operação e evidência | Markdown e artefatos pequenos selecionados | dados/logs completos ficam sob `data/` |
| `learning/` | ensinar conceitos, comandos, falhas e trade-offs | baseline e notas por ciclo | não substitui matriz/ADRs |
| `scripts/data/` | adquirir fontes externas com integridade | scripts | downloads sob `data/` |
| `scripts/prepare/` | transformar entradas antes do modelo | scripts | `part.N` sob `data/meshes/` |
| `scripts/run/` | executar transformações científicas | runners | workspaces/outputs sob `data/` |
| `scripts/analyze/` | ler NetCDFs e produzir evidência | Python | somente output documental selecionado entra no Git |
| `scripts/validate/` | provar instalação, artefatos e ciência | validadores | temporários em tmpfs/`/tmp` |
| `tests/smoke/` | programas independentes do build upstream | C/Fortran pequenos | executáveis e arquivos gerados são efêmeros |
| `data/` | store local de entradas/saídas grandes | somente placeholders deliberados | mesh, WPS_GEOG, GRIB, intermediate, NetCDF, logs, manifests |

## Fluxos por responsabilidade

### Mesh e static

```text
fetch-mesh.sh → grid.nc + graph.info
                       └→ partition-mesh.sh → part.4
fetch-geog.sh → WPS_GEOG
grid.nc + WPS_GEOG → generate-static.sh → static.nc → static.sh
```

### ERA5 e WPS

```text
cases/.../era5/*.json → docker/cds → fetch-era5.sh → GRIB
GRIB → g1print + Vtable.ECMWF → ungrib-era5.sh
     → pressure + surface → combined intermediate → wps-era5.sh
```

### Init e atmosphere

```text
static + combined intermediate + part.4
    → generate-init.sh → init.nc → init.sh
init.nc + part.4 + lookup tables
    → run-atmosphere.sh → run-001 → atmosphere-run.sh
```

### Análise e publicação

```text
run-001 + init.nc (read-only)
    → scientific-run.sh
    → scripts/analyze/first-atmosphere-run.py
    → docs/assets/validation/0014/{summary,CSV,PNGs}
```

## Validação final

`./scripts/validate/final-project.sh` é o ponto de entrada para validar um
estado já materializado. Ele não baixa nem regenera artefatos caros:

```text
core library smokes
  → PnetCDF/PIO
  → mesh
  → static
  → ERA5 raw
  → WPS intermediate
  → init
  → atmosphere run
  → scientific sanity
  → project_validation=PASS
```

Se um artefato faltar, o preflight falha e informa o comando de reprodução.

## Fluxo de governança

```text
requirements + sources + versions
          ↓
       proposal
          ↓
     user decision
          ↓
implementation → tests → review
          ↓
docs + learning note + current state
          ↓
pre-commit report → user approval → commit/push
```

O ciclo 0015 termina antes de commit/push, conforme
[[../project/development-workflow|workflow]].

## Índice de relações

- [[../project/completion-report|Relatório técnico final]]
- [[../reproducibility/end-to-end|Reprodução end-to-end]]
- [[../project/requirements|Requisitos e rastreabilidade]]
- [[../project/current-state|Estado atual]]
- [[../project/future-experiments|Extensões futuras]]
- [[../testing/validation-matrix|Matriz de validação]]
- [[../validation/first-atmosphere-run|Validação científica]]
- [[../cases/first-global-240km|Primeiro caso]]
- [[../references/source-registry|Fontes]]
- [[../references/versions.lock|Versões]]
- [[../decisions/README|ADRs]]
- [[../portfolio/project-showcase|Showcase]]
- [[../../learning/README|Aprendizado]]
