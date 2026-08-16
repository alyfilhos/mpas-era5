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
- MPAS-Model 8.4.1 / `init_atmosphere_model` GNU + MPI ✅ build, smoke
  estrutural e execução funcional static e meteorológica com ERA5
- MPAS-Model 8.4.1 / `atmosphere_model` GNU + MPI ✅ build e smoke
  estrutural; execução funcional ⏳

### Primeiro caso

- mesh oficial x1.10242, global quasi-uniforme, ~240 km e 10.242 células ✅
- `x1.10242.graph.info.part.4` gerado localmente com METIS 5.1.0 e validado ✅
- dados geográficos oficiais WPS, selecionados e validados para MPAS 8.4.1 ✅
- `x1.10242.static.nc` gerado localmente e validado ✅
- ERA5 bruto global, `Vtable.ECMWF`, `ungrib` e WPS intermediate
  combinado validados ✅
- `x1.10242.init.nc` gerado com 4 ranks e validado estrutural e fisicamente ✅
- execução funcional do `atmosphere_model` ⏳

## Roadmap

Stack científica:

`zlib → HDF5 → netCDF-C → netCDF-Fortran → PnetCDF → PIO2 → METIS`

O prefixo `/opt/mpas` permanece reservado às bibliotecas científicas. WPS e
MPAS-Model usam árvores separadas: `/opt/wps-4.7.0` com `/opt/wps`, e
`/opt/mpas-model-8.4.1` com `/opt/mpas-model`. `ungrib.exe`,
`init_atmosphere_model` e `atmosphere_model` foram construídos; WRF,
`geogrid` e `metgrid` continuam fora da imagem.

O METIS é usado offline: `gpmetis` transforma `graph.info` em
`graph.info.part.N`, e `N` deve corresponder ao número de tasks MPI da
execução MPAS que consome a partição. O backlog de alternativas está em
[`docs/project/future-experiments.md`](docs/project/future-experiments.md).

A primeira mesh real é adquirida reproduzivelmente por
[`scripts/data/fetch-mesh.sh`](scripts/data/fetch-mesh.sh), fica somente em
`data/meshes/x1.10242/` e não é incorporada à imagem nem ao Git. A partição
baseline em quatro partes é preparada por
[`scripts/prepare/partition-mesh.sh`](scripts/prepare/partition-mesh.sh) e
validada offline por [`scripts/validate/mesh.sh`](scripts/validate/mesh.sh).

Os campos geográficos são adquiridos de fontes oficiais WPS por
[`scripts/data/fetch-geog.sh`](scripts/data/fetch-geog.sh) e permanecem em
`data/geog/mpas-8.4.1/`. A configuração versionada do primeiro static fica em
[`cases/first-global-240km/static/`](cases/first-global-240km/static/). Para
reproduzir e validar:

```sh
./scripts/data/fetch-geog.sh
./scripts/run/generate-static.sh
./scripts/validate/static.sh
```

O output local é
`data/cases/first-global-240km/static/x1.10242.static.nc`; dados, NetCDF e
logs continuam fora do Git.

A baseline meteorológica é global em 2014-09-10 00 UTC. Requests pressure e
single-level versionadas ficam em
[`cases/first-global-240km/era5/`](cases/first-global-240km/era5/), enquanto
o cliente `cdsapi==0.7.7` usa um container pequeno em
[`docker/cds/`](docker/cds/), separado da imagem científica. Depois de
configurar `~/.cdsapirc` e aceitar os termos dos dois datasets no CDS:

```sh
./scripts/data/fetch-era5.sh build
./scripts/data/fetch-era5.sh probe
./scripts/data/fetch-era5.sh download
./scripts/validate/era5.sh
```

A credencial é montada read-only somente em runtime. Os dois probes e os
downloads globais passaram; os GRIBs e o manifesto ficam em
`data/era5/2014-09-10_00/`, ignorados pelo Git. A validação confirmou 185
mensagens pressure-level e 19 single-level, todas GRIB edição 1, com tamanho e
SHA-256 registrados localmente.

Para reproduzir a conversão offline e sua validação cruzada:

```sh
./scripts/validate/era5.sh
./scripts/run/ungrib-era5.sh
./scripts/validate/wps-era5.sh
```

As configurações versionadas estão em
[`cases/first-global-240km/wps/`](cases/first-global-240km/wps/). O wrapper
processa pressure e single-level em workspaces limpos com a tabela upstream
`Vtable.ECMWF`, preserva os dois resultados e promove atomicamente sua
concatenação exata. Intermediates, logs e manifesto ficam em
`data/cases/first-global-240km/wps/`, fora do Git.

O caminho atual é:

`ERA5 GRIB → Vtable → ungrib → WPS intermediate → MPAS init_atmosphere → MPAS atmosphere`

A configuração meteorológica versionada está em
[`cases/first-global-240km/init/`](cases/first-global-240km/init/). Com static,
intermediate e part.4 já validados, a reprodução local é:

```sh
./scripts/run/generate-init.sh
./scripts/validate/init.sh
```

O runner usa quatro ranks, rede desligada, rootfs e entradas read-only e não
sobrescreve output divergente. O arquivo local ignorado
`data/cases/first-global-240km/init/x1.10242.init.nc` foi validado como CDF-2,
92.641.692 bytes, SHA-256
`9f2625d9f93ec873a8c1f3abef24083d1b03b910a77efea2f6dbfd2e13c36c7d`,
10.242 células, 55 níveis, quatro camadas de solo e timestamp correto.

A `Vtable.ECMWF` da própria tag WPS 4.7.0 foi validada contra todos os 204
registros GRIB reais. O `ungrib` produziu 185 slabs pressure e 19 surface; o
arquivo combinado version 5 tem 204 slabs em grade global regular
1440×721, 0,25°, timestamp 2014-09-10 00 UTC. Isso prova ERA5 → WPS →
MPAS init. A previsão e a validação temporal continuam reservadas ao
`atmosphere_model`, que não foi executado neste ciclo.

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
