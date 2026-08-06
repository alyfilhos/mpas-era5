# Versões adotadas e pendentes

## Natureza deste arquivo

Este é um lock **documental** da stack: registra somente versões já adotadas ou
comprovadas pelo repositório e destaca explicitamente o que ainda depende de
decisão. Ele não substitui hashes de artefatos, digest da imagem, lock de
pacotes do sistema ou testes de compatibilidade.

Última conferência: **2026-08-05**.

## Ambiente e versões adotadas

| Componente | Versão/seleção | Estado | Evidência e observações |
|---|---|---|---|
| Ubuntu | 24.04 | adotada | `FROM ubuntu:24.04` no [`Dockerfile`](../../Dockerfile); digest não fixado |
| Toolchain C | GCC fornecido pelo Ubuntu 24.04 | adotada, versão exata não fixada | pacote `build-essential`; o índice APT não está congelado |
| Toolchain Fortran | GFortran fornecido pelo Ubuntu 24.04 | adotada, versão exata não fixada | pacote `gfortran`; o índice APT não está congelado |
| MPI | OpenMPI fornecido pelo Ubuntu 24.04 | implementação adotada, versão exata não fixada | pacotes `openmpi-bin` e `libopenmpi-dev`; mudança de MPI exige decisão do usuário |
| Python | 3.12.3 observado | runtime de build do `manage_externals`; pacote APT não fixado | `python3` instalado depois da camada init; índice APT não está congelado |
| zlib | 1.3.2 | adotada | `ZLIB_VERSION=1.3.2`; SHA-256 registrado no `Dockerfile` |
| HDF5 | 1.14.6 | adotada | `HDF5_VERSION=1.14.6`; checksum ainda não registrado |
| netCDF-C | 4.10.1 | adotada | `NETCDF_C_VERSION=4.10.1`; SHA-256 registrado no `Dockerfile` |
| netCDF-Fortran | 4.6.3 | adotada | `NETCDF_FORTRAN_VERSION=4.6.3`; SHA-256 registrado no `Dockerfile` |
| PnetCDF | 1.15.0 | adotada | tarball oficial; SHA-256 local verificado; MPI-IO/OpenMPI; GIO desabilitado; Fortran e shared/static; [[../decisions/0001-pnetcdf-mpiio-backend|ADR 0001]] |
| PIO | 2.7.0 (`pio2_7_0`) | adotada e validada | release oficial atual; SHA-256 local verificado; CMake; C/Fortran; timing desabilitado; PnetCDF habilitado; [[../decisions/0002-pio2-pnetcdf-with-serial-netcdf|ADR 0002]] |
| METIS | 5.1.0 | adotada e validada | tarball first-party histórico; SHA-256 local confirmado em dois downloads; static; `IDXTYPEWIDTH=32`; `REALTYPEWIDTH=32`; GKlib incluída; `gpmetis` offline; [[../decisions/0003-metis-5.1.0-partitioning-baseline|ADR 0003]] |
| WPS | 4.7.0 (`v4.7.0`) | adotada; `ungrib` validado | commit `5feccecd63384381b6942371c7a837f66e4ccb84`; GNU serial; `--nowrf`; `--build-grib2-libs`; somente `./compile ungrib`; SHA-256 local confirmado em dois downloads; [[../decisions/0004-wps-mpas-version-and-layout|ADR 0004]] |
| MPAS-Model | 8.4.1 (`v8.4.1`) | adotada; `init_atmosphere` e `atmosphere` compilados e validados estruturalmente; execução funcional pendente | tag/commit `91c5eac175eebeaf4206bacd5cb50c39dff3c152`; GNU/MPI; single precision; PIO2; ESMF embedded; [[../decisions/0004-wps-mpas-version-and-layout|ADR 0004]] |
| MMM-physics | `20250616-MPASv8.3` | external atmosphere adotado pelo source MPAS | commit `a4baf7f3243d1db0dbc5f63473f895bdbdc05c30`; checkout detached e limpo |
| UGWP | `MPAS_20241223` | external atmosphere adotado pelo source MPAS | commit `c1c893edcf171af5639af60e3a3a528816f6cc2b`; checkout detached e limpo |
| MPAS-Data | `v8.2` | lookup tables adotadas pelo script MPAS 8.4.1 | commit `c57dbc7be629802c6e848770a9e44b9bc602be41`; `COMPATIBILITY` 8.2; 16 arquivos com manifesto SHA-256 |
| CMake_Fortran_utils | commit `05ff8d8e4c88786e94a02c853d3ff921113d785c` | auxiliar de build PIO fixado | checkout detached antes da configuração; evita clone sem pin executado internamente pelo PIO |
| genf90 | commit `4816965ba946731352bad195b7d946a5fe682ff5` | auxiliar de build PIO fixado | checkout detached passado por `GENF90_PATH`; evita resolução mutável durante o build |

Pins explícitos de WPS e MPAS:

```text
WPS_VERSION=4.7.0
WPS_TAG=v4.7.0
WPS_COMMIT=5feccecd63384381b6942371c7a837f66e4ccb84
WPS_SOURCE_URL=https://github.com/wrf-model/WPS/archive/refs/tags/v4.7.0.tar.gz
WPS_SHA256=5232d20d7556338391b66aba45824d4fcd6c42712ebe9325f359f3c6cf043808

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
```

O SHA-256 WPS foi calculado localmente e confirmado por dois downloads; não
foi encontrado checksum SHA-256 publicado pelo upstream.

## Itens relacionados ainda não fixados

- digest da imagem Ubuntu;
- versões dos pacotes APT, incluindo GCC, GFortran e OpenMPI;
- checksum do HDF5 1.14.6;
- necessidade e arquitetura de HDF5/netCDF paralelo para um caso futuro que
  exija NetCDF-4 paralelo;
- eventual experimento com METIS 5.2.1 + GKlib fixada ou PT-Scotch online;
  essas alternativas não são versões adotadas e estão somente em
  [[../project/future-experiments|future-experiments.md]];
- Vtable definitiva e mapeamento dos campos ERA5 para o WPS;
- execução funcional de `init_atmosphere` e `atmosphere` com mesh,
  partição e entradas representativas;
- mesh pública exata;
- período, área, níveis e variáveis ERA5.

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
