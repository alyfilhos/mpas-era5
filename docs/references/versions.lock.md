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

## Versões ainda não decididas

| Componente | Versão | Estado | Próximo gate |
|---|---|---|---|
| PnetCDF | a decidir | não implementado | requisitos → fontes oficiais → compatibilidade → proposta → decisão do usuário |
| PIO2 | a decidir | não implementado | requisitos → fontes oficiais → compatibilidade com MPI/PnetCDF/netCDF → proposta → decisão do usuário |
| METIS | a decidir | não implementado | requisitos do MPAS escolhido → release oficial → proposta → decisão do usuário |
| WPS | a decidir | não implementado | compatibilidade com `ungrib`, formato ERA5 e stack aprovada → decisão do usuário |
| MPAS | a decidir | não implementado | release oficial, compatibilidade da stack e estratégia do primeiro caso → decisão do usuário |

## Itens relacionados ainda não fixados

- digest da imagem Ubuntu;
- versões dos pacotes APT, incluindo GCC, GFortran e OpenMPI;
- checksum do HDF5 1.14.6;
- estratégia formal HDF5 serial/paralela para a stack completa;
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
