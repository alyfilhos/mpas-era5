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
| zlib | 1.3.2 | adotada | `ZLIB_VERSION=1.3.2`; SHA-256 registrado no `Dockerfile` |
| HDF5 | 1.14.6 | adotada | `HDF5_VERSION=1.14.6`; checksum ainda não registrado |
| netCDF-C | 4.10.1 | adotada | `NETCDF_C_VERSION=4.10.1`; SHA-256 registrado no `Dockerfile` |
| netCDF-Fortran | 4.6.3 | adotada | `NETCDF_FORTRAN_VERSION=4.6.3`; SHA-256 registrado no `Dockerfile` |
| PnetCDF | 1.15.0 | adotada | tarball oficial; SHA-256 local verificado; MPI-IO/OpenMPI; GIO desabilitado; Fortran e shared/static; [[../decisions/0001-pnetcdf-mpiio-backend|ADR 0001]] |
| PIO | 2.7.0 (`pio2_7_0`) | adotada e validada | release oficial atual; SHA-256 local verificado; CMake; C/Fortran; timing desabilitado; PnetCDF habilitado; [[../decisions/0002-pio2-pnetcdf-with-serial-netcdf|ADR 0002]] |
| METIS | 5.1.0 | adotada e validada | tarball first-party histórico; SHA-256 local confirmado em dois downloads; static; `IDXTYPEWIDTH=32`; `REALTYPEWIDTH=32`; GKlib incluída; `gpmetis` offline; [[../decisions/0003-metis-5.1.0-partitioning-baseline|ADR 0003]] |
| WPS | 4.7.0 (`v4.7.0`) | adotada; `ungrib` validado | commit `5feccecd63384381b6942371c7a837f66e4ccb84`; GNU serial; `--nowrf`; `--build-grib2-libs`; somente `./compile ungrib`; SHA-256 local confirmado em dois downloads; [[../decisions/0004-wps-mpas-version-and-layout|ADR 0004]] |
| MPAS-Model | 8.4.1 (`v8.4.1`) | adotada documentalmente; build pendente | hotfix/tag no commit `91c5eac175eebeaf4206bacd5cb50c39dff3c152`; nenhum source ou executável instalado neste ciclo; [[../decisions/0004-wps-mpas-version-and-layout|ADR 0004]] |
| CMake_Fortran_utils | commit `05ff8d8e4c88786e94a02c853d3ff921113d785c` | auxiliar de build PIO fixado | checkout detached antes da configuração; evita clone sem pin executado internamente pelo PIO |
| genf90 | commit `4816965ba946731352bad195b7d946a5fe682ff5` | auxiliar de build PIO fixado | checkout detached passado por `GENF90_PATH`; evita resolução mutável durante o build |

Pins explícitos deste ciclo:

```text
WPS_VERSION=4.7.0
WPS_TAG=v4.7.0
WPS_COMMIT=5feccecd63384381b6942371c7a837f66e4ccb84
WPS_SOURCE_URL=https://github.com/wrf-model/WPS/archive/refs/tags/v4.7.0.tar.gz
WPS_SHA256=5232d20d7556338391b66aba45824d4fcd6c42712ebe9325f359f3c6cf043808

MPAS_VERSION=8.4.1
MPAS_TAG=v8.4.1
MPAS_COMMIT=91c5eac175eebeaf4206bacd5cb50c39dff3c152
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
- configuração, build e validação do MPAS-Model 8.4.1;
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
