# Versões adotadas e pendentes

## Natureza deste arquivo

Este é um lock **documental** da stack: registra somente versões já adotadas ou
comprovadas pelo repositório e destaca explicitamente o que ainda depende de
decisão. Ele não substitui hashes de artefatos, digest da imagem, lock de
pacotes do sistema ou testes de compatibilidade.

Última conferência: **2026-08-04**.

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
| CMake_Fortran_utils | commit `05ff8d8e4c88786e94a02c853d3ff921113d785c` | auxiliar de build PIO fixado | checkout detached antes da configuração; evita clone sem pin executado internamente pelo PIO |
| genf90 | commit `4816965ba946731352bad195b7d946a5fe682ff5` | auxiliar de build PIO fixado | checkout detached passado por `GENF90_PATH`; evita resolução mutável durante o build |

## Versões ainda não decididas

| Componente | Versão | Estado | Próximo gate |
|---|---|---|---|
| METIS | a decidir | não implementado | requisitos do MPAS escolhido → release oficial → proposta → decisão do usuário |
| WPS | a decidir | não implementado | compatibilidade com `ungrib`, formato ERA5 e stack aprovada → decisão do usuário |
| MPAS | a decidir | não implementado | release oficial, compatibilidade da stack e estratégia do primeiro caso → decisão do usuário |

## Itens relacionados ainda não fixados

- digest da imagem Ubuntu;
- versões dos pacotes APT, incluindo GCC, GFortran e OpenMPI;
- checksum do HDF5 1.14.6;
- necessidade e arquitetura de HDF5/netCDF paralelo para um caso futuro que
  exija NetCDF-4 paralelo;
- release e tabelas auxiliares do WPS;
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
