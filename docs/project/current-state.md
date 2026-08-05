# Estado atual do projeto

## Referência da inspeção

Estado atualizado em **2026-08-04** ao final da implementação e validação
técnica do ciclo 0003, a partir do Git real, do build Docker e dos testes
executados.

- branch: `main`;
- `HEAD`: `2d6c5eec92766c6a7ca4018070e2aa6a21adc192`
  (`build: add PnetCDF MPI-IO support`);
- relação observada antes das mudanças: `main` alinhada com `origin/main`;
- estado atual: mudanças do ciclo 0003 no worktree, sem commit e sem push,
  aguardando relatório pré-commit e aprovação.

O valor anterior deste documento ainda descrevia o estado pré-commit do ciclo
0002: apontava para `e1f86a4` e dizia que PnetCDF permanecia no worktree. A
inspeção real mostrou que o ciclo 0002 já é o `HEAD` `2d6c5ee`. Essa pendência
documental conhecida foi corrigida neste ciclo; o Git, e não o texto antigo,
foi usado como fonte do estado inicial.

## Ambiente definido no repositório

O [`Dockerfile`](../../Dockerfile) define:

- imagem base Ubuntu 24.04;
- toolchain GNU por `build-essential` e `gfortran`;
- OpenMPI pelos pacotes `openmpi-bin` e `libopenmpi-dev`;
- prefixo científico `/opt/mpas`;
- `PATH`, `LD_LIBRARY_PATH`, `CPPFLAGS` e `LDFLAGS` apontando para o
  prefixo;
- `NETCDF=/opt/mpas`, `PNETCDF=/opt/mpas` e `PIO=/opt/mpas`.

O build validado reportou GCC/GFortran 13.3.0, OpenMPI 4.1.6 e MPI 3.1. As
versões dos pacotes APT continuam sem lock; são a resolução obtida do Ubuntu
24.04 na data do build.

## Stack científica implementada

| Componente | Versão | Estado e evidência atual |
|---|---:|---|
| zlib | 1.3.2 | camada existente preservada; recuperada do cache no build do ciclo 0003 |
| HDF5 | 1.14.6 | camada serial existente preservada e recuperada do cache |
| netCDF-C | 4.10.1 | camada existente preservada; NetCDF-4 presente, parallel I/O desabilitado |
| netCDF-Fortran | 4.6.3 | camada existente preservada e versão reconfirmada |
| PnetCDF | 1.15.0 | camada MPI-IO preservada; regressão F90/CDF-5 em 4 ranks aprovada |
| PIO | 2.7.0 | C/Fortran static, timing desligado, PnetCDF habilitado, 109/109 testes e integração C em 4 ranks aprovados |

A imagem validada é `mpas-era5:pio-2.7.0`, com ID/digest local
`sha256:0a54e71725fbdcbe44dee5f4012198ae504ddf191e4cf79fe2b7630c5bfe1c91`
e tamanho reportado de 336876391 bytes. O build e as duas validações
versionadas terminaram com código 0.

Os logs completos desta sessão estão temporariamente em:

- `/tmp/mpas-era5-pio-build.log`;
- `/tmp/mpas-era5-pio-validation-final.log`;
- `/tmp/mpas-era5-pio-pnetcdf-regression.log`.

Eles não são artefatos versionados. A evidência resumida e auditável está em
[[../testing/validation-matrix|validation-matrix.md]].

## PIO validado no ciclo 0003

- release oficial atual: tag `pio2_7_0`, publicada em 2026-04-29;
- tarball verificado antes da extração pelo SHA-256 local
  `cce83743156ae723e7890931c2b48dcfe7ea8a276962dc4429f839d8f58d4a5a`;
- auxiliares CMake fixados nos commits
  `05ff8d8e4c88786e94a02c853d3ff921113d785c` e
  `4816965ba946731352bad195b7d946a5fe682ff5`;
- configuração CMake com `CC=mpicc`, `FC=mpifort`,
  `CMAKE_PREFIX_PATH=/opt/mpas`, Fortran/testes/exemplos/PnetCDF habilitados
  e `PIO_ENABLE_TIMING=OFF`;
- o CMake encontrou netCDF-C 4.10.1, netCDF-Fortran 4.6.3, PnetCDF, MPI C e
  MPI Fortran; `HAVE_NETCDF4` passou e `HAVE_NETCDF_PAR` falhou como
  esperado para a stack serial;
- todas as camadas até PnetCDF apareceram como `CACHED`: HDF5, netCDF-C,
  netCDF-Fortran e PnetCDF não foram reconstruídos;
- CTest upstream: 109/109 testes aprovados em 37,12 segundos;
- instalação: `pio.h`, módulos Fortran, `libpioc.a`, `libpiof.a`,
  `libpio.settings` e pacote CMake conferidos;
- IOTYPEs em runtime:
  `PNETCDF=1 NETCDF=1 NETCDF4C=0 NETCDF4P=0`;
- integração instalada: programa C criou e releu CDF-2 explicitamente por
  `PIO_IOTYPE_PNETCDF` em quatro ranks;
- valores conferidos por `ncmpidump`:
  `rank_value = 1000, 1001, 1002, 1003`;
- o smoke passou com OMPIO padrão e com seleção ROMIO apenas no comando;
- linkagem: o executável contém `PIOc_Init_Intracomm`, carrega PnetCDF e
  netCDF de `/opt/mpas/lib` e MPI do OpenMPI do Ubuntu;
- regressão da camada anterior: o smoke PnetCDF/Fortran passou em quatro ranks,
  criou CDF-5 e preservou as versões netCDF/PnetCDF.

## Arquitetura de I/O adotada

O primeiro caso MPAS usará `USE_PIO2=true` e o `io_type=pnetcdf` padrão.
Seu caminho de I/O paralelo é:

```text
MPAS → PIO 2.7.0 → PnetCDF 1.15.0 → MPI-IO → OpenMPI
```

HDF5 e netCDF permanecem seriais. Essa arquitetura suporta os backends PIO
PnetCDF e NetCDF clássico. Não oferece `PIO_IOTYPE_NETCDF4C` nem
`PIO_IOTYPE_NETCDF4P` na release/configuração atual. O primeiro caso não tem
necessidade comprovada de NetCDF-4 paralelo.

A decisão, alternativas e consequências estão em
[[../decisions/0002-pio2-pnetcdf-with-serial-netcdf|ADR 0002]].

## Componentes ainda não implementados

- METIS;
- WPS/ungrib;
- MPAS `init_atmosphere`;
- MPAS `atmosphere`;
- aquisição e preparação ERA5;
- seleção e preparação da primeira malha;
- geração de `static.nc`, `init.nc` e, quando aplicável, LBC;
- primeira execução MPAS;
- validação física do caso.

## Novos artefatos do ciclo

- `tests/smoke/pio_pnetcdf.c`: integração C, PIO e PnetCDF em quatro ranks;
- `scripts/validate/pio.sh`: validação da instalação, IOTYPEs, linkagem,
  OMPIO/ROMIO e CDF-2;
- `docs/decisions/0002-pio2-pnetcdf-with-serial-netcdf.md`: decisão aceita;
- `learning/commits/0003-add-pio2.md`: nota educacional do ciclo.

## Lacunas e limitações atuais

- o MPAS ainda não foi compilado; a compatibilidade foi estabelecida por
  documentação oficial e pela cadeia PIO/PnetCDF, mas a integração
  `USE_PIO2=true` será um teste obrigatório do próximo ciclo aplicável;
- o CMake 2.7.0 associa a macro interna `_NETCDF4` a
  `HAVE_NETCDF_PAR`; por isso o backend NetCDF-4 serial também fica ausente.
  Mudar essa lógica localmente não foi aprovado nem necessário;
- o alvo upstream `tests` é construído com `--parallel 1` para evitar uma
  corrida entre dois arquivos-fonte Fortran gerados com o mesmo nome de módulo;
- `PIO_ENABLE_NETCDF_INTEGRATION=OFF` desliga a camada opcional que apresenta
  PIO como implementação interna da API netCDF; não desliga o backend
  `PIO_IOTYPE_NETCDF`;
- PIO é instalado somente como bibliotecas estáticas, a forma selecionada para
  o futuro link do MPAS; shared PIO não foi validado;
- o SHA-256 PIO foi calculado localmente sobre o artefato oficial; não foi
  encontrado checksum SHA-256 publicado pelo upstream;
- o probe PIO 2.6.5 teve uma falha persistente em `pio_rearr_opts`; 2.7.0
  corrigiu o comportamento observado e foi adotado;
- a falha OMPIO do ciclo 0002 permanece relevante para testes PnetCDF
  upstream, embora o smoke PIO deste ciclo tenha passado tanto com OMPIO quanto
  com ROMIO;
- HDF5 continua sem checksum registrado, e as versões APT/digest Ubuntu não
  estão totalmente fixadas; são dívidas herdadas e não alteradas neste ciclo.
