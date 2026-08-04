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
- PnetCDF ⏳
- PIO2 ⏳
- METIS ⏳

## Roadmap

Stack científica:

`zlib → HDF5 → netCDF-C → netCDF-Fortran → PnetCDF → PIO2 → METIS`

Depois:

`WPS/ungrib → MPAS init_atmosphere → MPAS atmosphere → ERA5 → mesh → primeira simulação`

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
- ECMWF Climate Data Store
