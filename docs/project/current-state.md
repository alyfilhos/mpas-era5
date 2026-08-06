# Estado atual do projeto

## Como interpretar a referência Git

Este documento registra o estado técnico produzido por um ciclo, mas não tenta
prever o hash do commit que futuramente o materializará. Um arquivo escrito
antes do commit não pode conhecer o SHA desse commit.

A partir do ciclo 0004, cada atualização distingue:

- **base do ciclo:** commit real sobre o qual o trabalho começou;
- **estado produzido pelo ciclo:** conteúdo e validações presentes no
  worktree;
- **commit que materializa o estado:** consultar o Git depois do commit, por
  exemplo com `git log --oneline -- docs/project/current-state.md`;
- **HEAD atual:** obter sempre com `git rev-parse HEAD`, sem confiar em um SHA
  antigo escrito neste documento.

Consequentemente, a referência abaixo é uma observação datada, não uma
declaração eterna do `HEAD`.

## Referência do ciclo 0007

Estado atualizado em **2026-08-05** depois da implementação, build, smoke e
regressões do MPAS-Model 8.4.1/`atmosphere`:

- branch inspecionada: `main`;
- base e `HEAD` observados antes das mudanças:
  `a70df2714667e57d2042762e822fe0344cbe8ec6`
  (`build: add MPAS init_atmosphere support`);
- relação observada: `main` alinhada com `origin/main`;
- worktree inicial: limpo;
- estado produzido: mudanças do ciclo 0007 no worktree, sem commit e sem push,
  aguardando relatório pré-commit e aprovação;
- commit que materializa este estado: **consultar Git**; nenhum SHA futuro foi
  escrito;
- comando normativo para o `HEAD` atual: `git rev-parse HEAD`.

O ciclo começou com `init_atmosphere` finalizado no commit base acima. Esta
referência não antecipa o hash de um possível commit 0007.

## Ambiente definido no repositório

O [`Dockerfile`](../../Dockerfile) define:

- imagem base Ubuntu 24.04;
- toolchain GNU por `build-essential` e `gfortran`;
- OpenMPI por `openmpi-bin` e `libopenmpi-dev`;
- prefixo científico `/opt/mpas`;
- `PATH`, `LD_LIBRARY_PATH`, `CPPFLAGS` e `LDFLAGS` para o prefixo;
- `NETCDF=/opt/mpas`, `PNETCDF=/opt/mpas` e `PIO=/opt/mpas`.
- WPS separado em `/opt/wps-4.7.0`, com `/opt/wps` como link estável;
- MPAS-Model separado em `/opt/mpas-model-8.4.1`, com `/opt/mpas-model` como
  link estável; `/opt/mpas` continua sendo somente o prefixo científico.

Não foi criada uma variável `METIS`: o workflow usa
`/opt/mpas/bin/gpmetis` descoberto por `PATH`.

## Componentes implementados

| Componente | Versão | Estado e evidência atual |
|---|---:|---|
| zlib | 1.3.2 | camada existente preservada; recuperada do cache no build do ciclo 0004 |
| HDF5 | 1.14.6 | camada serial existente preservada e recuperada do cache |
| netCDF-C | 4.10.1 | camada serial preservada; `nc-config` reconfirmado na regressão |
| netCDF-Fortran | 4.6.3 | camada preservada; `nf-config` reconfirmado |
| PnetCDF | 1.15.0 | camada MPI-IO preservada; F90/CDF-5 em quatro ranks aprovado |
| PIO | 2.7.0 | C/Fortran static, PnetCDF habilitado; integração CDF-2 aprovada com OMPIO e ROMIO |
| METIS | 5.1.0 | static, índices/reais 32 bits, GKlib incluída; `gpmetis` offline validado |
| WPS/ungrib | 4.7.0 | GNU serial; sem WRF; GRIB2 privado; build e smoke offline aprovados |
| MPAS/init_atmosphere | 8.4.1 | GNU/MPI, single precision, PIO2 e ESMF embedded; build e smoke estrutural aprovados |
| MPAS/atmosphere | 8.4.1 | GNU/MPI, single precision, PIO2, ESMF embedded, externals e lookup tables fixados; build e smoke estrutural aprovados |

A imagem validada é `mpas-era5:mpas-atmosphere-8.4.1`, com ID local
`sha256:54281c60db053982692d21bef27cf522293e8e2568be748cf4a83f2d5f0e4c93`
e tamanho reportado de 466.941.565 bytes. Todas as 27 etapas até o build de
`init_atmosphere` foram recuperadas do cache; nenhuma camada científica
anterior foi reconstruída ou alterada.

A evidência resumida está em
[[../testing/validation-matrix|validation-matrix.md]]; nenhum log de build ou
validação é versionado.

## WPS preservado e MPAS init_atmosphere no ciclo 0006

- WPS 4.7.0, tag `v4.7.0`, commit
  `5feccecd63384381b6942371c7a837f66e4ccb84`;
- archive oficial da tag e SHA-256 local
  `5232d20d7556338391b66aba45824d4fcd6c42712ebe9325f359f3c6cf043808`,
  confirmado por dois downloads independentes;
- configuração `--nowrf --build-grib2-libs`, GNU/GCC/GFortran, Linux x86_64,
  serial;
- seleção não interativa derivada de `arch/configure.defaults`, sem número de
  menu fixado por suposição;
- somente `./compile ungrib` executado;
- `ungrib.exe` em `/opt/wps-4.7.0`, acessível por `/opt/wps/ungrib.exe`;
- zlib 1.2.11, libpng 1.6.37 e JasPer 1.900.29 privados em
  `/opt/wps-4.7.0/grib2`;
- Vtables ECMWF, ECMWF sigma e ERA-Interim presentes, sem escolha ERA5;
- único pacote de sistema novo: `csh`, observado como `20230828-1`.

MPAS-Model 8.4.1 foi clonado da tag oficial `v8.4.1`; o build falha se
`git rev-parse HEAD` não for
`91c5eac175eebeaf4206bacd5cb50c39dff3c152`. A metadata Git foi preservada
para `git describe`. O comando real foi:

```sh
make -j8 gnu CORE=init_atmosphere USE_PIO2=true MPAS_ESMF=embedded
```

Somente `init_atmosphere_model` foi produzido, com
`namelist.init_atmosphere`, `streams.init_atmosphere` e seus defaults. O
resumo comprovou GNU/MPI, `mpi_f08`, single precision, otimização, PIO 2.x e
ESMF embedded; DEBUG, OpenMP, OpenMP offload, OpenACC, MUSICA e PT-Scotch estão
desligados. O source não solicitou downloads manuais de MMM-physics, UGWP ou
outros externos para esse core.

## MPAS atmosphere no ciclo 0007

O core `atmosphere` foi acrescentado à mesma árvore
`/opt/mpas-model-8.4.1`; nenhuma segunda cópia do MPAS foi clonada. O comando
real foi:

```sh
make -j8 gnu CORE=atmosphere USE_PIO2=true MPAS_ESMF=embedded
```

O `Externals.cfg` oficial da tag 8.4.1 determinou, sem escolha de versões:

- MMM-physics, tag `20250616-MPASv8.3`, commit
  `a4baf7f3243d1db0dbc5f63473f895bdbdc05c30`;
- UGWP, tag `MPAS_20241223`, commit
  `c1c893edcf171af5639af60e3a3a528816f6cc2b`;
- MPAS-Data, tag `v8.2`, commit
  `c57dbc7be629802c6e848770a9e44b9bc602be41`.

Os três pins foram resolvidos nos repositórios oficiais em 2026-08-05. O
Dockerfile falha se os checkouts não estiverem detached no commit registrado
ou se tiverem mudanças rastreadas. As 16 lookup tables de física são copiadas
explicitamente para `src/core_atmosphere/physics/physics_wrf/files`, recebem
manifesto SHA-256 e não são versionadas no Git do projeto. O arquivo
`COMPATIBILITY` do MPAS-Data v8.2 declara compatibilidade com `8.2`, exatamente
o valor `mpas_vers="8.2"` usado pelo script upstream. Em seguida,
`checkout_data_files.sh` confirma que os dados compatíveis já existem e não
faz download durante o `make`.

O probe sobre `mpas-era5:mpas-init-8.4.1` inicialmente revelou a dependência
real de runtime em `python3` do `manage_externals`; Python 3.12.3 foi então
adicionado somente depois da camada init. Sem `make clean`, o build passou. A
proteção de compatibilidade comprovou `.build_opts.framework` idêntico entre
os dois cores. O conteúdo do arquivo do framework e o hash de
`init_atmosphere_model` permaneceram inalterados; o `ar -ru` upstream apenas
reempacotou/reindexou o archive e os geradores foram relinkados, sem recompilar
os objetos Fortran do framework.

Foram produzidos `atmosphere_model`, `namelist.atmosphere`,
`streams.atmosphere` e seus defaults, preservando todos os equivalentes de
`init_atmosphere`. O resumo e `.build_opts.atmosphere` comprovam GNU/MPI com
`mpi_f08`, single precision, `-O3`, PIO 2.x/PnetCDF e ESMF embedded. DEBUG,
OpenMP, offload OpenMP, OpenACC, MUSICA e PT-Scotch permanecem desligados.
`file`, `ldd` e `nm` confirmaram ELF dinâmico, MPI/netCDF/PnetCDF resolvidos
e PIO2 estático incorporado, sem `not found`.

## METIS validado no ciclo 0004

- decisão: METIS 5.1.0 como particionador serial externo e offline;
- origem: tarball first-party histórico de George Karypis;
- SHA-256 local, confirmado por dois downloads:
  `76faebe03f6c963127dbb73c13eab58c9a3faeae48779f049066a21c087c5db2`;
- build real: `make config prefix=/opt/mpas`, `make -j8`,
  `make install`;
- configuração default estática; `IDXTYPEWIDTH=32` e
  `REALTYPEWIDTH=32`;
- GKlib fornecida em `GKlib/` pelo tarball 5.1.0; nenhuma dependência GKlib
  externa;
- ferramentas instaladas: `gpmetis`, `ndmetis`, `mpmetis`,
  `m2gmetis`, `graphchk` e `cmpfillin`;
- instalação também preserva `metis.h` e `libmetis.a`;
- não há `make check`, CTest ou suíte formal registrada pela release;
- validação aplicável upstream: `graphchk` e `gpmetis` no
  `graphs/4elt.graph`, com quatro partições contíguas, `Edgecut: 341` e
  balanceamento 1.001;
- `gpmetis -help` confirmou `-minconn`, `-contig` e `-niter`;
- o banner legado imprime `METIS 5.0`; a versão exata 5.1.0 é comprovada
  pelos macros do `metis.h` instalado.

O fixture versionado representa quatro cliques K4 conectadas em cadeia:
16 vértices, 27 arestas, grafo conectado e quatro grupos naturais. O comando
real foi:

```sh
gpmetis -minconn -contig -niter=200 graph.info 4
```

Ele produziu `graph.info.part.4` somente em tmpfs. A validação confirmou:

- exatamente 16 linhas, uma por vértice;
- exatamente um inteiro por linha e IDs restritos a 0..3;
- quatro partições presentes, cada uma com 4 vértices;
- imbalance simples máximo/média 1.000, ou 0%;
- `edge cut` reportado 3 e recalculado independentemente 3;
- cada partição conectada;
- nenhum vértice ausente e nenhuma linha extra.

O fluxo futuro é:

```text
graph.info
    ↓
gpmetis
    ↓
graph.info.part.N
    ↓
MPAS com N ranks MPI
```

METIS não é a implementação MPI do modelo. A validação do ciclo 0004
demonstrou a invariável quatro partições ↔ quatro tasks MPI sem executar MPAS.

## Regressão da stack anterior

- `scripts/validate/mpas-init.sh`: código 0 na imagem final; executável,
  defaults, configuração e linkagem do core init preservados;
- `scripts/validate/pnetcdf.sh`: código 0; F90/CDF-5 em quatro ranks e
  valores `0, 1, 2, 3` preservados;
- `scripts/validate/pio.sh`: código 0; PIO/PnetCDF CDF-2 em quatro ranks com
  OMPIO e ROMIO e valores `1000, 1001, 1002, 1003` preservados;
- WPS e METIS não foram reexecutados: nenhuma camada, configuração ou script
  desses componentes mudou, e todas as respectivas etapas permaneceram
  `CACHED` no build final.

## Arquiteturas adotadas

O caminho de I/O paralelo permanece:

```text
MPAS init_atmosphere/atmosphere
    → PIO 2.7.0 → PnetCDF 1.15.0 → MPI-IO → OpenMPI
```

O particionamento é uma preparação independente:

```text
mesh futura → graph.info → METIS 5.1.0 serial → graph.info.part.N
```

As decisões e alternativas estão em
[[../decisions/0002-pio2-pnetcdf-with-serial-netcdf|ADR 0002]],
[[../decisions/0003-metis-5.1.0-partitioning-baseline|ADR 0003]] e
[[../decisions/0004-wps-mpas-version-and-layout|ADR 0004]], além de
[[future-experiments|future-experiments.md]].

## Artefatos do ciclo 0004

- `tests/fixtures/metis/graph.info`: grafo didático deliberadamente
  versionado;
- `scripts/validate/metis.sh`: validação instalada e estrutural em tmpfs;
- `docs/decisions/0003-metis-5.1.0-partitioning-baseline.md`: decisão aceita;
- `docs/project/future-experiments.md`: backlog não aprovado de comparações;
- `learning/commits/0004-add-metis.md`: nota educacional do ciclo.

## Artefatos do ciclo 0005

- `scripts/validate/wps-ungrib.sh`: smoke final sem rede ou dados;
- `docs/decisions/0004-wps-mpas-version-and-layout.md`: decisão aceita;
- `learning/commits/0005-add-wps-ungrib.md`: nota educacional do ciclo.

## Artefatos do ciclo 0006

- `scripts/validate/mpas-init.sh`: smoke estrutural offline e read-only;
- `learning/commits/0006-add-mpas-init-atmosphere.md`: nota educacional;
- camada MPAS adicionada ao `Dockerfile`, sem novo ADR porque o ADR 0004 já
  cobre versão, layout e separação da stack.

## Artefatos do ciclo 0007

- `scripts/validate/mpas-atmosphere.sh`: smoke estrutural offline e read-only;
- `learning/commits/0007-add-mpas-atmosphere.md`: nota educacional;
- camada atmosphere adicionada ao `Dockerfile`, sem novo ADR: versão e layout
  continuam cobertos pelo ADR 0004 e os pins reproduzem contratos upstream.

## Componentes ainda não implementados

- METIS 5.2.1 e GKlib externa;
- PT-Scotch;
- execução funcional de `init_atmosphere` e `atmosphere`;
- aquisição ou preparação ERA5;
- seleção e preparação da primeira mesh;
- `static.nc`, `init.nc` e LBC;
- primeira execução e validação física MPAS.

## Lacunas e limitações atuais

- ainda não existe uma mesh MPAS aprovada; o fixture não prova compatibilidade
  ou performance em escala real;
- o consumo real de `graph.info.part.N` e a execução do `init_atmosphere`
  permanecem testes de um ciclo futuro;
- a release METIS 5.1.0 não fornece suíte formal; foram usados seus grafos de
  teste, `graphchk`, o comando real MPAS e validação independente;
- CMake emitiu aviso de depreciação e a GKlib incluída produziu avisos
  `-Wmisleading-indentation`; não houve erro;
- a imagem Ubuntu e as versões APT não possuem digest/lock completos;
- `csh` foi acrescentado por APT, mas sua versão não está fixada na receita;
- o checksum HDF5 continua ausente;
- HDF5 e netCDF continuam seriais por decisão anterior;
- METIS 5.2.1 + GKlib fixada e PT-Scotch online são somente hipóteses futuras,
  sem conclusão de superioridade;
- a Vtable ERA5 não foi escolhida e nenhum GRIB real foi processado;
- avisos de código legado em libpng, JasPer e Fortran permanecem, apesar do
  build e da linkagem bem-sucedidos;
- os builds estruturais de `init_atmosphere` e `atmosphere` passaram, mas
  qualquer afirmação funcional ou científica continua pendente até existir
  mesh/configuração e, para `init.nc`, entradas WPS/ERA5 representativas;
- a imagem Ubuntu e os pacotes APT, inclusive Python, não têm lock por digest.
