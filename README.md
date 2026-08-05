# MPAS-ERA5

Ambiente reproduzível para compilação, configuração e execução do
MPAS-Atmosphere utilizando dados ERA5.

O projeto também funciona como material de estudo sobre Linux, Docker,
compilação de software científico, MPI e ferramentas utilizadas em HPC.

## Objetivos

- Construir uma stack científica reproduzível em Docker.
- Compilar e executar o MPAS-Atmosphere.
- Preparar dados ERA5 para inicialização do modelo.
- Executar um primeiro caso global de baixa resolução.
- Documentar todas as etapas, decisões e problemas encontrados.

## Estado atual

### Ambiente

- Ubuntu 24.04
- GCC / GFortran
- OpenMPI

### Stack científica

- zlib 1.3.2 ✅
- HDF5 1.14.6 ✅
- netCDF-C 4.10.1 ✅
- netCDF-Fortran 4.6.3 ✅
- PnetCDF 1.15.0 ✅
- PIO2 2.7.0 ✅
- METIS 5.1.0 ✅

### Pré-processamento e modelo

- WPS 4.7.0 / `ungrib.exe` GNU serial ✅
- MPAS-Model 8.4.1: versão fixada; build pendente

## Roadmap

Stack científica:

`zlib → HDF5 → netCDF-C → netCDF-Fortran → PnetCDF → PIO2 → METIS`

O prefixo `/opt/mpas` permanece reservado às bibliotecas científicas. O WPS
fica separado em `/opt/wps-4.7.0`, com `/opt/wps` como link estável. Neste
ciclo foram usados `--nowrf`, `--build-grib2-libs` e `./compile ungrib`; WRF,
`geogrid` e `metgrid` não foram instalados ou compilados.

O METIS é usado offline: `gpmetis` transforma `graph.info` em
`graph.info.part.N`, e `N` deve corresponder ao número de tasks MPI da futura
execução MPAS. O backlog de alternativas de particionamento está em
[`docs/project/future-experiments.md`](docs/project/future-experiments.md).

Depois:

`ERA5 GRIB → Vtable → ungrib → WPS intermediate → MPAS init_atmosphere → MPAS atmosphere`

A Vtable ERA5 definitiva e a integração funcional com dados reais ainda
dependem de um ciclo próprio.

## Documentação

A documentação técnica está em [`docs/`](docs/README.md).

O mapa da estrutura e das relações entre os arquivos está em:

[`docs/architecture/project-graph.md`](docs/architecture/project-graph.md)

O material didático e as notas de aprendizado por ciclo estão em:

[`learning/`](learning/README.md)

## Referências principais

- MPAS-Model
- NSF Unidata netCDF
- HDF Group
- Parallel-NetCDF
- PIO
- METIS
- WPS
- MPAS-Model
- ECMWF Climate Data Store
