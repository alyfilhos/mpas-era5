# Estado atual do projeto

## Referência da inspeção

Estado atualizado em **2026-08-04** ao final da validação técnica do ciclo
0002, a partir do Git real, do build Docker e dos testes executados.

- branch: `main`;
- `HEAD`: `e1f86a4f29b10421946b054b85e2aea1f40c725c`
  (`docs: bootstrap Codex governance workflow`);
- relação observada antes das mudanças: `main` alinhada com `origin/main`;
- estado atual: alterações do ciclo 0002 permanecem no worktree, sem commit e
  sem push, aguardando o relatório e a aprovação do usuário.

O SHA `0f5fed1` descrito anteriormente era o estado anterior ao commit do
ciclo 0001. O ciclo 0001 está efetivamente no `HEAD`; não está apenas no
worktree.

## Ambiente definido no repositório

O [`Dockerfile`](../../Dockerfile) define:

- imagem base Ubuntu 24.04;
- toolchain GNU por `build-essential` e `gfortran`;
- OpenMPI pelos pacotes `openmpi-bin` e `libopenmpi-dev`;
- prefixo científico `/opt/mpas`;
- `PATH`, `LD_LIBRARY_PATH`, `CPPFLAGS` e `LDFLAGS` apontando para o prefixo;
- `NETCDF=/opt/mpas` e, no ciclo 0002, `PNETCDF=/opt/mpas`.

O build validado reportou GCC/GFortran 13.3.0, OpenMPI 4.1.6 e MPI 3.1. As
versões dos pacotes APT continuam sem lock; são a resolução obtida do Ubuntu
24.04 na data do build.

## Stack científica implementada

| Componente | Versão | Estado e evidência atual |
|---|---:|---|
| zlib | 1.3.2 | camada existente preservada; recuperada do cache no build do ciclo 0002 |
| HDF5 | 1.14.6 | camada existente preservada; recuperada do cache, sem mudança de estratégia serial/paralela |
| netCDF-C | 4.10.1 | camada existente preservada; `nc-config --version` reconfirmado |
| netCDF-Fortran | 4.6.3 | camada existente preservada; `nf-config --version` reconfirmado |
| PnetCDF | 1.15.0 | implementado e validado com MPI-IO, GIO desabilitado, Fortran, shared/static, `make check`, `make ptest` e integração em 4 ranks |

A imagem validada é `mpas-era5:pnetcdf-1.15.0`, com ID
`sha256:c31e25c9e36aa66a528203ff1edf9f2b6753ff54b7bdc69c15905f72e6295d03`.
O build e a validação finalizaram com código 0. Os logs completos usados na
sessão ficaram em `/tmp` e não são artefatos versionados; a evidência resumida
e auditável está em
[[../testing/validation-matrix|validation-matrix.md]].

## PnetCDF validado no ciclo 0002

- artefato oficial `pnetcdf-1.15.0.tar.gz`, verificado antes da extração pelo
  SHA-256 calculado localmente
  `39813fe91ec901c7cfca3212731edbb5201029ebf55caeaaaa08d9e33c6bad65`;
- configuração: `/opt/mpas`, `--disable-gio`, `--enable-shared` e
  `--enable-static`;
- wrappers: `/usr/bin/mpicc`, `/usr/bin/mpicxx`, `/usr/bin/mpif77` e
  `/usr/bin/mpifort`;
- recursos opcionais NetCDF-4, ADIOS, subfiling, profiling e thread safety
  permaneceram desabilitados;
- `make check`: todas as suítes sequenciais terminaram com sucesso;
- `make ptest`: grupos C, C++, F77, F90, exemplos e benchmarks passaram em
  4 ranks com o componente ROMIO já incluído no OpenMPI;
- instalação: `pnetcdf_version`, `pnetcdf-config`, `ncmpidump`, biblioteca
  shared e biblioteca static verificadas;
- integração instalada: programa Fortran criou e releu CDF-5 coletivamente;
  `ncmpidump` mostrou `rank_value = 0, 1, 2, 3`;
- linkagem: `libpnetcdf.so.8` veio de `/opt/mpas/lib` e `libmpi.so.40` do
  OpenMPI do Ubuntu.

## Componentes ainda não implementados

- PIO2;
- METIS;
- WPS/ungrib;
- MPAS `init_atmosphere`;
- MPAS `atmosphere`;
- aquisição e preparação ERA5;
- seleção e preparação da primeira malha;
- geração de `static.nc`, `init.nc` e, quando aplicável, LBC;
- primeira execução MPAS;
- validação física do caso.

PIO2 permanece sem versão ou decisão registrada. Nenhum item desta lista foi
alterado ou antecipado no ciclo 0002.

## Novos artefatos do ciclo

- `tests/smoke/pnetcdf_mpi.f90`: smoke/integration test pela interface F90;
- `scripts/validate/pnetcdf.sh`: validação reproduzível da instalação, versão,
  linkagem, regressões netCDF, 4 ranks e `ncmpidump`;
- `docs/decisions/0001-pnetcdf-mpiio-backend.md`: decisão aceita;
- `learning/commits/0002-add-pnetcdf.md`: nota educacional do ciclo.

## Lacunas e limitações atuais

- `make ptests`, que usa 3, 4, 6 e 8 processos, não foi executado; o escopo
  aprovado usa `make check` e `make ptest`;
- OMPIO, componente MPI-IO padrão deste OpenMPI, produziu escrita incompleta
  nos testes PnetCDF locais; os comandos PnetCDF selecionam ROMIO localmente,
  sem configuração global;
- o `INSTALL` da release e o `configure --help` gerado divergem sobre o default
  de shared; o build usa `--enable-shared --enable-static` explicitamente;
- o SHA-256 do PnetCDF foi calculado localmente duas vezes sobre o artefato
  oficial; o upstream publica SHA-1, não SHA-256;
- HDF5 continua sem checksum registrado e as versões APT/digest Ubuntu não
  estão totalmente fixados, dívidas herdadas que este ciclo não alterou.
