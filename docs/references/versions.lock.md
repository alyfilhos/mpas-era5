# Versões adotadas e pendentes

## Natureza deste arquivo

Este é um lock **documental** da stack: registra somente versões já adotadas ou
comprovadas pelo repositório e destaca explicitamente o que ainda depende de
decisão. Ele não substitui hashes de artefatos, digest da imagem, lock de
pacotes do sistema ou testes de compatibilidade.

Última conferência: **2026-08-21**.

## Ambiente e versões adotadas

| Componente | Versão/seleção | Estado | Evidência e observações |
|---|---|---|---|
| Ubuntu | 24.04 | adotada | `FROM ubuntu:24.04` no [`Dockerfile`](../../Dockerfile); digest não fixado |
| Toolchain C | GCC fornecido pelo Ubuntu 24.04 | adotada, versão exata não fixada | pacote `build-essential`; o índice APT não está congelado |
| Toolchain Fortran | GFortran fornecido pelo Ubuntu 24.04 | adotada, versão exata não fixada | pacote `gfortran`; o índice APT não está congelado |
| MPI | OpenMPI fornecido pelo Ubuntu 24.04 | implementação adotada, versão exata não fixada | pacotes `openmpi-bin` e `libopenmpi-dev`; mudança de MPI exige decisão do usuário |
| Python | 3.12.3 observado | runtime de build do `manage_externals`; pacote APT não fixado | `python3` instalado depois da camada init; índice APT não está congelado |
| Python do cliente CDS | 3.12.13 slim-bookworm | adotada e fixada por digest, separada da stack científica | imagem oficial `python:3.12.13-slim-bookworm@sha256:d50fb7611f86d04a3b0471b46d7557818d88983fc3136726336b2a4c657aa30b` em `docker/cds/Dockerfile` |
| cdsapi | 0.7.7 | adotada e validada | versão direta e dependências transitivas fixadas em `docker/cds/requirements.txt`; `pip check`, autenticação, probes e downloads PASS |
| zlib | 1.3.2 | adotada | `ZLIB_VERSION=1.3.2`; SHA-256 registrado no `Dockerfile` |
| HDF5 | 1.14.6 | adotada | `HDF5_VERSION=1.14.6`; checksum ainda não registrado |
| netCDF-C | 4.10.1 | adotada | `NETCDF_C_VERSION=4.10.1`; SHA-256 registrado no `Dockerfile` |
| netCDF-Fortran | 4.6.3 | adotada | `NETCDF_FORTRAN_VERSION=4.6.3`; SHA-256 registrado no `Dockerfile` |
| PnetCDF | 1.15.0 | adotada | tarball oficial; SHA-256 local verificado; MPI-IO/OpenMPI; GIO desabilitado; Fortran e shared/static; [[../decisions/0001-pnetcdf-mpiio-backend|ADR 0001]] |
| PIO | 2.7.0 (`pio2_7_0`) | adotada e validada | release oficial atual; SHA-256 local verificado; CMake; C/Fortran; timing desabilitado; PnetCDF habilitado; [[../decisions/0002-pio2-pnetcdf-with-serial-netcdf|ADR 0002]] |
| METIS | 5.1.0 | adotada e validada | tarball first-party histórico; SHA-256 local confirmado em dois downloads; static; `IDXTYPEWIDTH=32`; `REALTYPEWIDTH=32`; GKlib incluída; `gpmetis` offline; [[../decisions/0003-metis-5.1.0-partitioning-baseline|ADR 0003]] |
| WPS | 4.7.0 (`v4.7.0`) | adotada; `ungrib` e `g1print` validados | commit `5feccecd63384381b6942371c7a837f66e4ccb84`; GNU serial; `--nowrf`; `--build-grib2-libs`; `./compile ungrib` e alvo incremental `./compile g1print`; SHA-256 local confirmado em dois downloads; [[../decisions/0004-wps-mpas-version-and-layout|ADR 0004]] |
| MPAS-Model | 8.4.1 (`v8.4.1`) | adotada; `init_atmosphere` executado para static/init e `atmosphere` executado por 1 hora em 4 ranks | tag/commit `91c5eac175eebeaf4206bacd5cb50c39dff3c152`; GNU/MPI; single precision; PIO2; ESMF embedded; first forecast functional PASS; [[../decisions/0004-wps-mpas-version-and-layout|ADR 0004]] |
| MMM-physics | `20250616-MPASv8.3` | external atmosphere adotado pelo source MPAS | commit `a4baf7f3243d1db0dbc5f63473f895bdbdc05c30`; checkout detached e limpo |
| UGWP | `MPAS_20241223` | external atmosphere adotado pelo source MPAS | commit `c1c893edcf171af5639af60e3a3a528816f6cc2b`; checkout detached e limpo |
| MPAS-Data | `v8.2` | lookup tables adotadas pelo script MPAS 8.4.1 | commit `c57dbc7be629802c6e848770a9e44b9bc602be41`; `COMPATIBILITY` 8.2; 16 arquivos com manifesto SHA-256 |
| Mesh MPAS | x1.10242 / ~240 km / 10.242 células | adotada, validada e consumida pelo init para static e condição inicial | pacote oficial first-party; global quasi-uniforme/SCVT; SHA-256 local confirmado em dois downloads; `part.4` gerado com METIS 5.1.0; [[../decisions/0005-first-mesh-baseline|ADR 0005]] |
| WPS_GEOG do primeiro static | high mandatory + MODIS landuse 30s + USGS landuse 30s | adotado e validado para MPAS 8.4.1 | três artefatos first-party, tamanhos/hashes abaixo; extração seletiva 16.563.576.021 bytes; [[../decisions/0006-first-static-baseline|ADR 0006]] |
| Static x1.10242 | CDF-2, `config_noahmp_static=false`, supersampling 1 | gerado e validado localmente; não versionado | 18.201.336 bytes; SHA-256 observado `36e50a8f8d0233327b6505f74e2f909aaaa6c7cee03499affabadd5cc11a144f`; 1 task MPI; não usar com física que exija Noah-MP |
| Baseline ERA5 | 2014-09-10 00 UTC, global, GRIB, 37 pressure levels | selecionada, adquirida, validada e convertida localmente | pressure: 384.168.780 bytes, SHA-256 `11a0a10a5727a19f64c529179af8b9e5fc4f92cdb60eb32ac90c68926b2e06ac`; single: 41.995.970 bytes, SHA-256 `5d0c6aeeef07c5109f044428266d822928c2cf4ccda1ccbb430c916f0b5b693b`; [[../decisions/0007-first-era5-baseline|ADR 0007]] |
| Vtable ERA5 | `Vtable.ECMWF` upstream WPS 4.7.0 | adotada diretamente para esta baseline real | todas as 204 mensagens casam uma única entrada por parameter/level type/levels; SHA-256 local `989bf7227ae5c822bfdd8467267dacc41396e08f2270735eac08c56a0096b335`; nenhuma cópia no repositório |
| WPS intermediate ERA5 | format version 5, 1440×721, `iproj=0`, 0,25° | gerado e validado localmente; não versionado | pressure 185 slabs, single 19, combined 204; combinado SHA-256 `2d7a3ac93d1c904e45b3a19a9f524e6367f7fe72abab41a5263888f1a72b50f0` |
| Init x1.10242 | CDF-2; 55 níveis; topo 30 km; 4 soil; Time 1 | gerado e validado localmente; não versionado | 92.641.692 bytes; SHA-256 `9f2625d9f93ec873a8c1f3abef24083d1b03b910a77efea2f6dbfd2e13c36c7d`; 4 ranks/part.4; [[../decisions/0008-first-initial-condition-baseline|ADR 0008]] |
| Primeira integração x1.10242 | 1 hora; `dt=1200 s`; 4 ranks; `mesoscale_reference` | executada e validada localmente; outputs não versionados | 00→01 UTC; history/diag CDF-2; 0 errors/critical; SST fixa; sanity científico PASS no ciclo 0014; skill não avaliado |
| CMake_Fortran_utils | commit `05ff8d8e4c88786e94a02c853d3ff921113d785c` | auxiliar de build PIO fixado | checkout detached antes da configuração; evita clone sem pin executado internamente pelo PIO |
| genf90 | commit `4816965ba946731352bad195b7d946a5fe682ff5` | auxiliar de build PIO fixado | checkout detached passado por `GENF90_PATH`; evita resolução mutável durante o build |

Pins explícitos de WPS e MPAS:

```text
WPS_VERSION=4.7.0
WPS_TAG=v4.7.0
WPS_COMMIT=5feccecd63384381b6942371c7a837f66e4ccb84
WPS_SOURCE_URL=https://github.com/wrf-model/WPS/archive/refs/tags/v4.7.0.tar.gz
WPS_SHA256=5232d20d7556338391b66aba45824d4fcd6c42712ebe9325f359f3c6cf043808
WPS_VTABLE=ungrib/Variable_Tables/Vtable.ECMWF
WPS_VTABLE_SHA256=989bf7227ae5c822bfdd8467267dacc41396e08f2270735eac08c56a0096b335
WPS_INTERMEDIATE_FORMAT_VERSION=5

MPAS_VERSION=8.4.1
MPAS_TAG=v8.4.1
MPAS_COMMIT=91c5eac175eebeaf4206bacd5cb50c39dff3c152
MPAS_SOURCE_URL=https://github.com/MPAS-Dev/MPAS-Model.git
MPAS_MODEL_PREFIX=/opt/mpas-model-8.4.1
MMM_PHYSICS_TAG=20250616-MPASv8.3
MMM_PHYSICS_COMMIT=a4baf7f3243d1db0dbc5f63473f895bdbdc05c30
UGWP_TAG=MPAS_20241223
UGWP_COMMIT=c1c893edcf171af5639af60e3a3a528816f6cc2b
MPAS_DATA_TAG=v8.2
MPAS_DATA_COMMIT=c57dbc7be629802c6e848770a9e44b9bc602be41

make -j8 gnu CORE=init_atmosphere USE_PIO2=true MPAS_ESMF=embedded
make -j8 gnu CORE=atmosphere USE_PIO2=true MPAS_ESMF=embedded

MPAS_MESH=x1.10242
MPAS_MESH_RESOLUTION_KM=240
MPAS_MESH_CELLS=10242
MPAS_MESH_SOURCE_URL=https://www2.mmm.ucar.edu/projects/mpas/atmosphere_meshes/x1.10242.tar.gz
MPAS_MESH_ARCHIVE_SIZE=6321104
MPAS_MESH_ARCHIVE_SHA256=4dde31932bc45aaf467e2717d17ec8e5e54d73c3ebbeea027087bfdb8b98ab56
MPAS_MESH_PARTITIONS_BASELINE=4

WPS_GEOG_HIGH_URL=https://www2.mmm.ucar.edu/wrf/src/wps_files/geog_high_res_mandatory.tar.gz
WPS_GEOG_HIGH_SIZE=2772782816
WPS_GEOG_HIGH_SHA256=89b026b9db0a03c0c995e53b4a1d99663af1f6bda21b3b34c3c2c07386da5493
WPS_GEOG_MODIS_URL=https://www2.mmm.ucar.edu/wrf/src/wps_files/modis_landuse_20class_30s.tar.bz2
WPS_GEOG_MODIS_SIZE=32334661
WPS_GEOG_MODIS_SHA256=b21ca154d1038ec271abaa1be2fd38a0cd055b8a4ddfaab520719478ac48d326
WPS_GEOG_GWD_URL=https://www2.mmm.ucar.edu/wrf/src/wps_files/landuse_30s.tar.bz2
WPS_GEOG_GWD_SIZE=20988479
WPS_GEOG_GWD_SHA256=143cd195ae91f64011a43eae52ca00228709672c6a2ba614cb437eeb4cd41160

CDS_PYTHON_IMAGE=python:3.12.13-slim-bookworm
CDS_PYTHON_IMAGE_DIGEST=sha256:d50fb7611f86d04a3b0471b46d7557818d88983fc3136726336b2a4c657aa30b
CDSAPI_VERSION=0.7.7
ERA5_TIMESTAMP=2014-09-10T00:00:00Z
ERA5_AREA=global
ERA5_DATA_FORMAT=grib
ERA5_PRESSURE_DATASET=reanalysis-era5-pressure-levels
ERA5_PRESSURE_LEVELS=37
ERA5_PRESSURE_VARIABLES=5
ERA5_SINGLE_DATASET=reanalysis-era5-single-levels
ERA5_SINGLE_VARIABLES=19
```

O SHA-256 WPS foi calculado localmente e confirmado por dois downloads; não
foi encontrado checksum SHA-256 publicado pelo upstream.

O SHA-256 da mesh também é local: dois downloads independentes do mesmo
artefato first-party produziram o valor acima e foram comparados byte a byte.
Não foi encontrado SHA-256 publicado pela NCAR, e o valor não é atribuído ao
upstream. O static file pronto de 240 km foi deliberadamente excluído; o
projeto gerou o próprio `static.nc` no ciclo 0009.

Também não foram encontrados SHA-256 upstream para os três archives
geográficos. Os valores acima são locais. Os dois suplementos foram confirmados
por downloads independentes; o high foi verificado por ranges independentes,
tamanho, hash e integridade gzip/tar. O pacote low-resolution foi inspecionado
e rejeitado por ausência dos datasets requeridos, não por escolha de versão.

## Itens relacionados ainda não fixados

- digest da imagem Ubuntu;
- versões dos pacotes APT, incluindo GCC, GFortran e OpenMPI;
- checksum do HDF5 1.14.6;
- necessidade e arquitetura de HDF5/netCDF paralelo para um caso futuro que
  exija NetCDF-4 paralelo;
- eventual experimento com METIS 5.2.1 + GKlib fixada ou PT-Scotch online;
  essas alternativas não são versões adotadas e estão somente em
  [[../project/future-experiments|future-experiments.md]];
- forecast verification com ERA5 futuro, avaliação de spin-up e budgets em
  uma janela maior; o sanity científico da hora base já é PASS, sem alegação
  de skill;

Essas lacunas não devem ser preenchidas por suposição. Qualquer fixação ou
mudança deve atualizar o registro de fontes, este arquivo, a matriz de
validação e, quando a decisão for arquitetural, um ADR.

## Regra de atualização

Uma versão passa de **a decidir** para **adotada** somente depois de:

1. conferência dos requisitos originais;
2. pesquisa em documentação e release oficiais;
3. análise de compatibilidade com a stack já adotada;
4. proposta com alternativas e riscos;
5. decisão explícita do usuário;
6. registro da fonte e data de verificação.

O status **adotada** não significa automaticamente **validada**. A validação é
registrada separadamente em
[[../testing/validation-matrix|validation-matrix.md]].

## Ambiente de análise adotado no ciclo 0014

Esta stack é independente da imagem científica e foi aprovada em 2026-08-21:

| Componente | Pin | Validação |
|---|---|---|
| Base | `python:3.12.13-slim-bookworm@sha256:d50fb7611f86d04a3b0471b46d7557818d88983fc3136726336b2a4c657aa30b` | digest resolvido no build |
| NumPy | 2.5.2 | import/version, análise float64 e wheel SHA-256 |
| xarray | 2026.7.0 | import/version e leitura explícita com backend netCDF4 |
| netCDF4-python | 1.7.4 | import/version e leitura CDF-2 |
| Matplotlib | 3.11.1 | Agg, Mollweide e sete PNGs válidos |
| Lock transitivo | 16 distribuições exatas | `pip --require-hashes` e `pip check` |

Pins principais:

```text
ANALYSIS_PYTHON_IMAGE=python:3.12.13-slim-bookworm
ANALYSIS_PYTHON_IMAGE_DIGEST=sha256:d50fb7611f86d04a3b0471b46d7557818d88983fc3136726336b2a4c657aa30b
NUMPY_VERSION=2.5.2
XARRAY_VERSION=2026.7.0
NETCDF4_PYTHON_VERSION=1.7.4
MATPLOTLIB_VERSION=3.11.1
```

O lock de wheels é específico da plataforma Linux x86-64/CPython 3.12. A
imagem foi construída com rede, mas seu runtime científico passou com
`--network none --read-only`. Jupyter e Cartopy não foram adotados.

## Auditoria final do ciclo 0015

- nenhuma versão, dependência ou estratégia serial/paralela foi alterada;
- as versões adotadas têm origem registrada no
  [[source-registry|source-registry.md]] ou evidência direta nas receitas;
- checksums produzidos pelo projeto continuam identificados como **locais** e
  não são atribuídos aos upstreams;
- nenhum SHA upstream foi inferido ou inventado;
- ERA5/CDS, a imagem científica e a imagem de análise permanecem registradas
  como papéis separados;
- digest Ubuntu, locks APT e checksum HDF5 continuam limitações explícitas,
  sem preenchimento por suposição.

Esta baseline fica congelada como a configuração efetivamente reproduzida.
Novas releases pertencem a extensões futuras e exigem nova decisão e
validação.
