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

## Referência do ciclo 0005

Estado atualizado em **2026-08-05** depois da implementação, build, smoke e
regressões do WPS 4.7.0/ungrib:

- branch inspecionada: `main`;
- base do ciclo:
  `7eb81e8d7a566ee16d79d9d8abdca1b6d09aadad`
  (`build: add METIS 5.1.0 partitioning support`);
- relação observada antes das mudanças: `main` alinhada com `origin/main`;
- estado produzido: mudanças do ciclo 0005 no worktree, sem commit e sem push,
  aguardando relatório pré-commit e aprovação;
- commit que materializa este estado: **consultar Git**; nenhum SHA futuro foi
  escrito;
- `HEAD` observado ao atualizar este documento:
  `7eb81e8d7a566ee16d79d9d8abdca1b6d09aadad`;
- comando normativo para o `HEAD` atual: `git rev-parse HEAD`.

O ciclo começou com o ciclo 0004 já materializado no commit base acima. A
referência continua sem antecipar o hash do futuro commit 0005.

## Ambiente definido no repositório

O [`Dockerfile`](../../Dockerfile) define:

- imagem base Ubuntu 24.04;
- toolchain GNU por `build-essential` e `gfortran`;
- OpenMPI por `openmpi-bin` e `libopenmpi-dev`;
- prefixo científico `/opt/mpas`;
- `PATH`, `LD_LIBRARY_PATH`, `CPPFLAGS` e `LDFLAGS` para o prefixo;
- `NETCDF=/opt/mpas`, `PNETCDF=/opt/mpas` e `PIO=/opt/mpas`.
- WPS separado em `/opt/wps-4.7.0`, com `/opt/wps` como link estável.

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

A imagem validada é `mpas-era5:wps-4.7.0`, com ID/digest local
`sha256:437fb5d327aaeb1a2d79d4b2c9c0024a471f123f9416fa8e3bf1762d3b07267a`
e tamanho reportado de 359.179.447 bytes. Todas as camadas até METIS foram
recuperadas do cache; nenhuma versão ou configuração científica anterior foi
reconstruída ou alterada.

A evidência resumida está em
[[../testing/validation-matrix|validation-matrix.md]]; nenhum log de build ou
validação é versionado.

## WPS e versão MPAS no ciclo 0005

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

MPAS-Model está fixado em 8.4.1, tag `v8.4.1`, hotfix/commit
`91c5eac175eebeaf4206bacd5cb50c39dff3c152`. Nenhum source MPAS foi baixado e
nenhum núcleo foi compilado neste ciclo.

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

METIS não é a implementação MPI do modelo. O ciclo demonstra a invariável
quatro partições ↔ quatro tasks MPI, sem compilar ou executar MPAS.

## Regressão da stack anterior

- `scripts/validate/pnetcdf.sh` executado com a imagem final: código 0,
  netCDF-C 4.10.1, netCDF-Fortran 4.6.3, PnetCDF 1.15.0 e F90/CDF-5 em quatro
  ranks preservados;
- `scripts/validate/pio.sh` executado com a imagem final: código 0,
  PIO 2.7.0/PnetCDF e CDF-2 em quatro ranks passaram com OMPIO e ROMIO;
- `scripts/validate/metis.sh` executado com a imagem final: código 0,
  METIS 5.1.0 produziu quatro partições conectadas, imbalance 1.000 e edge cut
  reportado/recalculado 3;
- valores funcionais preservados: `0, 1, 2, 3` no smoke PnetCDF e
  `1000, 1001, 1002, 1003` no smoke PIO.

## Arquiteturas adotadas

O caminho de I/O paralelo permanece:

```text
MPAS futuro → PIO 2.7.0 → PnetCDF 1.15.0 → MPI-IO → OpenMPI
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

## Componentes ainda não implementados

- METIS 5.2.1 e GKlib externa;
- PT-Scotch;
- MPAS `init_atmosphere` e `atmosphere`;
- aquisição ou preparação ERA5;
- seleção e preparação da primeira mesh;
- `static.nc`, `init.nc` e LBC;
- primeira execução e validação física MPAS.

## Lacunas e limitações atuais

- ainda não existe uma mesh MPAS aprovada; o fixture não prova compatibilidade
  ou performance em escala real;
- o MPAS não foi compilado; o consumo real de `graph.info.part.N` permanece
  teste de um ciclo futuro;
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
- o build e a integração do MPAS-Model 8.4.1 continuam pendentes.
