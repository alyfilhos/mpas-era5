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
- MPAS-Model 8.4.1 / `init_atmosphere_model` GNU + MPI ✅ build e smoke
  estrutural
- MPAS-Model 8.4.1 / `atmosphere_model` GNU + MPI ✅ build e smoke
  estrutural; execução funcional ⏳

### Primeiro caso

- mesh oficial x1.10242, global quasi-uniforme, ~240 km e 10.242 células ✅
- `x1.10242.graph.info.part.4` gerado localmente com METIS 5.1.0 e validado ✅
- `static.nc`, ERA5, `init.nc` e execução do modelo ⏳

## Roadmap

Stack científica:

`zlib → HDF5 → netCDF-C → netCDF-Fortran → PnetCDF → PIO2 → METIS`

O prefixo `/opt/mpas` permanece reservado às bibliotecas científicas. WPS e
MPAS-Model usam árvores separadas: `/opt/wps-4.7.0` com `/opt/wps`, e
`/opt/mpas-model-8.4.1` com `/opt/mpas-model`. `ungrib.exe`,
`init_atmosphere_model` e `atmosphere_model` foram construídos; WRF,
`geogrid` e `metgrid` continuam fora da imagem.

O METIS é usado offline: `gpmetis` transforma `graph.info` em
`graph.info.part.N`, e `N` deve corresponder ao número de tasks MPI da futura
execução MPAS. O backlog de alternativas de particionamento está em
[`docs/project/future-experiments.md`](docs/project/future-experiments.md).

A primeira mesh real é adquirida reproduzivelmente por
[`scripts/data/fetch-mesh.sh`](scripts/data/fetch-mesh.sh), fica somente em
`data/meshes/x1.10242/` e não é incorporada à imagem nem ao Git. A partição
baseline em quatro partes é preparada por
[`scripts/prepare/partition-mesh.sh`](scripts/prepare/partition-mesh.sh) e
validada offline por [`scripts/validate/mesh.sh`](scripts/validate/mesh.sh).

Depois:

`ERA5 GRIB → Vtable → ungrib → WPS intermediate → MPAS init_atmosphere → MPAS atmosphere`

A Vtable ERA5 definitiva, a geração própria de `static.nc` e as integrações
funcionais com o MPAS ainda dependem de ciclos próprios. O estado atual prova
a estrutura da mesh e seu particionamento, além do build dos dois executáveis,
mas ainda não prova que `init_atmosphere` aceita a mesh nem executa uma
previsão.

## Documentação

A documentação técnica está em [`docs/`](docs/README.md).

O mapa da estrutura e das relações entre os arquivos está em:

[`docs/architecture/project-graph.md`](docs/architecture/project-graph.md)

O material didático e as notas de aprendizado por ciclo estão em:

[`learning/`](learning/README.md)

## Referências principais

- NSF Unidata netCDF
- HDF Group
- Parallel-NetCDF
- PIO
- METIS
- WPS
- MPAS-Model
- MPAS-Atmosphere Meshes
- ECMWF Climate Data Store
