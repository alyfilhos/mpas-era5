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


## Referência do ciclo 0015 em validação no worktree

Estado atualizado em **2026-08-21** depois da consolidação final, sem novo
experimento meteorológico:

- branch inspecionada: `main`, alinhada com `origin/main` no início;
- base e `HEAD` real do ciclo:
  `872cd8c644f765959cabbb8f438c3510cd377905`
  (`analysis: validate first MPAS forecast`);
- worktree inicial: limpo;
- auditoria dos 19 requisitos: 13 `SATISFIED`, 5
  `SATISFIED_WITH_LIMITATION`, 1 `NOT_APPLICABLE` e nenhum blocker;
- smokes instalados de zlib/HDF5/netCDF-C/netCDF-Fortran: PASS, sem rebuild;
- `final-project.sh`: PASS sobre stack e artefatos canônicos;
- README público, guia end-to-end, relatório final, portfólio, grafo,
  documentação e learning note consolidados;
- stack científica, `Dockerfile`, `run-001` e dados brutos inalterados;
- estado produzido: `PROJECT_BASE_STATUS = COMPLETE`;
- limites preservados: `forecast_skill=NOT_EVALUATED` e
  `spinup=INSUFFICIENT_TEMPORAL_WINDOW`;
- commit que materializará o estado: consultar o Git depois da aprovação;
  nenhum SHA futuro é escrito aqui;
- nenhum commit ou push foi executado neste ciclo.

## Ciclo 0014 materializado no commit real

O ciclo 0014 foi desenvolvido sobre:

- base do ciclo:
  `66ffe7746b4ba144f179d4cea3011e1f0b178d38`
  (`run: add first MPAS atmosphere integration`);
- estado produzido: validação científica/visual da primeira hora, sem nova
  integração do modelo;
- commit que materializou esse estado:
  `872cd8c644f765959cabbb8f438c3510cd377905`
  (`analysis: validate first MPAS forecast`).

Essa distinção registra apenas fatos que passaram a ser conhecidos em seus
respectivos momentos; não reescreve o worktree pré-commit como se ele já
conhecesse o SHA futuro.

Evidências: `init.sh` e `atmosphere-run.sh` PASS; análise separada offline e
read-only; integridade, sanity numérico e científico PASS; 11 valores `q2`
limitados/documentados; massa seca e água REPORT-ONLY; sete figuras,
`summary.json` e CSV. `run-001`, os quatro NetCDFs e a imagem científica
permaneceram inalterados.

## Ciclo 0013 materializado no commit real

Estado atualizado em **2026-08-21** depois da primeira integração temporal
real do MPAS Atmosphere:

- branch inspecionada: `main`, inicialmente alinhada com `origin/main`;
- base real do ciclo:
  `0d499294e94661444243f9dbdadae0c776fa5c23`
  (`data: generate MPAS initial conditions`);
- o worktree inicial já continha arquivos não commitados exatamente no escopo
  do ciclo 0013; eles foram auditados e continuados, sem descartar trabalho;
- regressões diretamente consumidas `init.sh`, `mpas-atmosphere.sh` e
  `mesh.sh`: PASS;
- source MPAS exato: v8.4.1, commit
  `91c5eac175eebeaf4206bacd5cb50c39dff3c152`;
- comando: `mpiexec -n 4 /opt/mpas-model-8.4.1/atmosphere_model`;
- configuração: 2014-09-10 00 UTC, 1 hora, `dt=1200 s`, `part.4`,
  `mesoscale_reference`, Noah, radiação horária, sem LBC/restart/SST update;
- estado produzido: relógio concluído em 01 UTC, history/diagnostics em 00/01,
  zero errors/critical e evolução prognóstica validada;
- execução local em
  `data/cases/first-global-240km/atmosphere/run-001/`, ignorada pelo Git;
- estado materializado no commit
  `66ffe7746b4ba144f179d4cea3011e1f0b178d38`
  (`run: add first MPAS atmosphere integration`);
- imagem, Dockerfile, dependências e versões científicas inalterados.

## Ciclo 0012 materializado no commit real

Estado atualizado em **2026-08-16** depois da execução meteorológica real do
MPAS init e da validação estrutural/física do primeiro `init.nc`:

- branch inspecionada: `main`, inicialmente alinhada com `origin/main`;
- base real do ciclo: `6352463b91db6e0e56faf6b9fe283569c3119cb8`
  (`data: convert ERA5 to WPS intermediate`);
- worktree inicial: limpo;
- regressões diretamente consumidas: mesh, static, ERA5, WPS intermediate e
  MPAS init build/proveniência, todas PASS;
- source MPAS exato: v8.4.1, commit
  `91c5eac175eebeaf4206bacd5cb50c39dff3c152`;
- estado produzido: configuração, runner, validador, ADR, learning note,
  documentação e `x1.10242.init.nc` local validado;
- estado materializado no commit
  `0d499294e94661444243f9dbdadae0c776fa5c23`
  (`data: generate MPAS initial conditions`);
- imagem, Dockerfile e versões científicas inalterados;
- o `atmosphere_model` não foi executado naquele ciclo;
- comando normativo para o `HEAD` atual: `git rev-parse HEAD`.

## Ciclo 0011 materializado no commit publicado

Estado atualizado em **2026-08-15** depois do inventário semântico, da
validação da Vtable, de duas execuções do `ungrib` e da validação do WPS
intermediate combinado:

- branch inspecionada: `main`;
- base real antes das mudanças: `78fd3a26187305612223a06ba65a52325b95d908`
  (`data: add reproducible ERA5 acquisition`), alinhado com `origin/main`;
- o trabalho foi retomado de uma execução interrompida que já continha a
  camada incremental de `g1print` no `Dockerfile`;
- estado materializado no commit
  `6352463b91db6e0e56faf6b9fe283569c3119cb8`
  (`data: convert ERA5 to WPS intermediate`);
- dados e outputs permanecem ignorados pelo Git;
- comando normativo para o `HEAD` atual: `git rev-parse HEAD`.

A imagem publicada não continha `g1print.exe`, ferramenta explicitamente
requerida para auditar os GRIBs reais. Com essa evidência, o `Dockerfile`
compila somente o alvo upstream `./compile g1print` na mesma árvore/tag WPS
4.7.0. Nenhuma versão, dependência, estratégia científica ou binário MPAS foi
trocado; as camadas anteriores foram preservadas.

## Referência do ciclo 0010 materializado no Git

Estado atualizado em **2026-08-14** depois da decisão, implementação, probes,
aquisição e validação do ERA5 bruto:

- branch inspecionada: `main`;
- base e `HEAD` observados antes das mudanças:
  `6a527d97f66a94b03e8320d5369167a9365c6490`;
- relação observada: `main` alinhada com `origin/main`;
- worktree inicial: limpo;
- baseline aprovada: 2014-09-10 00 UTC, global, 37 pressure levels,
  5 variáveis pressure e 19 single-level, GRIB;
- estado produzido: requests, ADR, container dedicado, cliente, probes e dois
  GRIBs globais validados;
- commit que materializou o estado:
  `78fd3a26187305612223a06ba65a52325b95d908`;
- autenticação e termos: comprovados pelos retrieves bem-sucedidos dos dois
  datasets, sem token em imagem, argumentos, logs ou Git;
- comando normativo para o `HEAD` atual: `git rev-parse HEAD`.

O `Dockerfile` científico permaneceu inalterado. O novo
`docker/cds/Dockerfile` é uma imagem independente para aquisição.

## Referência do ciclo 0009

Estado atualizado em **2026-08-14** depois da aquisição geográfica, execução
do init e validação do primeiro static produzido pelo projeto:

- branch inspecionada: `main`;
- base e `HEAD` observados antes das mudanças:
  `7555a96a7c706ea9e719f23ff27eaf29498ffe05`;
- relação observada: `main` alinhada com `origin/main`;
- worktree inicial: limpo;
- estado produzido: mudanças do ciclo 0009 no worktree, sem commit e sem push,
  aguardando relatório pré-commit e aprovação;
- commit que materializa este estado: **consultar Git**; nenhum SHA futuro foi
  escrito;
- comando normativo para o `HEAD` atual: `git rev-parse HEAD`.

O Dockerfile e as versões de software permaneceram inalterados. Esta referência
não antecipa o hash de um possível commit 0009.

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
| zlib | 1.3.2 | compressão/descompressão instalada e link em `/opt/mpas` validados no ciclo 0015 |
| HDF5 | 1.14.6 | serial; dataset DEFLATE escrito/relido e link com zlib do prefixo validados no ciclo 0015 |
| netCDF-C | 4.10.1 | serial; NetCDF-4/deflate escrito/relido sobre HDF5/zlib no ciclo 0015 |
| netCDF-Fortran | 4.6.3 | módulo instalado criou/releu NetCDF-4/deflate sobre netCDF-C no ciclo 0015 |
| PnetCDF | 1.15.0 | camada MPI-IO preservada; F90/CDF-5 em quatro ranks aprovado |
| PIO | 2.7.0 | C/Fortran static, PnetCDF habilitado; integração CDF-2 aprovada com OMPIO e ROMIO |
| METIS | 5.1.0 | static, índices/reais 32 bits, GKlib incluída; `gpmetis` offline validado |
| WPS/ungrib | 4.7.0 | GNU serial; `ungrib`, `g1print`, `link_grib` e `Vtable.ECMWF` validados offline; integração ERA5 real aprovada |
| MPAS/init_atmosphere | 8.4.1 | GNU/MPI, single precision, PIO2 e ESMF embedded; static e init meteorológico reais aprovados |
| MPAS/atmosphere | 8.4.1 | GNU/MPI, single precision, PIO2, ESMF embedded; build/smoke e integração funcional de 1 hora em 4 ranks aprovados |
| Primeira mesh | x1.10242 | oficial, global quasi-uniforme, ~240 km, 10.242 células; NetCDF/grafo/part.4 validados e grid consumido pelo init |
| Geografia do primeiro static | WPS first-party | 8 datasets exatos, 16.563.576.021 bytes, hashes locais/manifests validados; fora do Git/imagem |
| Primeiro static | x1.10242 / CDF-2 | 18.201.336 bytes; 1 task MPI; Noah-MP false; campos/ranges/log validados; artefato local ignorado |
| Cliente CDS | Python 3.12.13 / cdsapi 0.7.7 | imagem dedicada por digest, lock transitivo, `pip check`, versão, requests, self-test e autenticação aprovados |
| Baseline ERA5 | 2014-09-10 00 UTC / global / GRIB | probes e dois downloads globais GRIB1 validados; 426.164.750 bytes locais no total |
| WPS intermediate ERA5 | version 5 / global 0,25° | pressure 185 + single 19 = 204 slabs; concatenação exata, estrutura, semântica e campos funcionais validados; local/ignorado |
| Primeiro init.nc | x1.10242 / CDF-2 | 92.641.692 bytes; 4 ranks/part.4; 55 níveis; 4 soil; topo 30 km; SHA-256 `9f2625d9f93ec873a8c1f3abef24083d1b03b910a77efea2f6dbfd2e13c36c7d`; local/ignorado |
| Primeira integração | x1.10242 / 1 hora | 4 ranks/part.4; dt 1200 s; 00→01 UTC; mesoscale_reference/Noah; history/diag CDF-2; zero errors/critical; local/ignorado |

A imagem validada é `mpas-era5:mpas-atmosphere-8.4.1`, com ID local
`sha256:9c9479db0bae4db1e8d827bf522caab312ad097217aba962cb399f18b74e93a8`
e tamanho reportado de 467.002.046 bytes. O último estágio acrescenta somente
o alvo upstream `g1print` e sua proveniência; as camadas WPS/MPAS anteriores
não foram recompiladas e nenhuma versão científica mudou.

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

## Primeira mesh real no ciclo 0008

A fonte oficial MPAS-Atmosphere classifica x1.10242 como mesh SCVT
quasi-uniforme de aproximadamente 240 km e 10.242 células horizontais. O link
da página resolveu para:

```text
https://www2.mmm.ucar.edu/projects/mpas/atmosphere_meshes/x1.10242.tar.gz
```

O tarball possui 6.321.104 bytes. Como não foi encontrado SHA-256 upstream,
dois downloads independentes foram comparados byte a byte e produziram o hash
local:

```text
4dde31932bc45aaf467e2717d17ec8e5e54d73c3ebbeea027087bfdb8b98ab56
```

O archive contém `x1.10242.grid.nc`, `x1.10242.graph.info` e partições
pré-computadas. `scripts/data/fetch-mesh.sh` valida o hash antes da extração,
lista o archive e copia somente grid e grafo para
`data/meshes/x1.10242/`. Reexecução com conteúdo idêntico terminou como
`unchanged`; conteúdo preexistente divergente causa falha. O static file
separado não foi baixado.

O NetCDF real é `64-bit offset`, com:

- `nCells = 10242`;
- `nVertices = 20480`;
- `nEdges = 30720`;
- `maxEdges = 10`, `maxEdges2 = 20` e `vertexDegree = 3`;
- `latCell`, `lonCell`, `nEdgesOnCell`, `cellsOnCell`, `edgesOnCell`,
  `verticesOnCell` e `indexToCellID` presentes e legíveis.

`graphchk` aprovou o `graph.info` real. A validação independente confirmou o
header `10242 30720`, exatamente 10.242 linhas de vértices, índices válidos,
adjacências simétricas, contagem de arestas e conectividade de todo o grafo.
Logo, `nCells` do NetCDF e vértices do grafo coincidem.

`scripts/prepare/partition-mesh.sh` executou na imagem atual, com UID/GID do
usuário:

```sh
gpmetis -minconn -contig -niter=200 x1.10242.graph.info 4
```

O METIS reportou `Edgecut: 663`, balanceamento 1.003 e todas as partições
contíguas. `scripts/validate/mesh.sh`, sem rede e com a mesh montada read-only,
confirmou independentemente:

| Partição | Células |
|---:|---:|
| 0 | 2566 |
| 1 | 2549 |
| 2 | 2568 |
| 3 | 2559 |

A média é 2560,5, o mínimo 2549, o máximo 2568 e o imbalance simples
máximo/média é 1,002929, ou 0,292912%. As quatro partições são conectadas e o
edge cut recalculado é 663. O smoke final terminou `mesh_smoke=PASS`.

Essa evidência valida aquisição, estrutura e particionamento. Não executa
`init_atmosphere_model`, não gera `static.nc` e não prova aceitação funcional
da mesh pelo MPAS.

## Campos estáticos no ciclo 0009

A inspeção do pacote `geog_low_res_mandatory.tar.gz` confirmou que ele não
satisfaz os datasets 30s desta configuração. A baseline final usa somente
artefatos first-party publicados na página WPS: high mandatory para seis
diretórios e os suplementos exatos
`modis_landuse_20class_30s.tar.bz2` e `landuse_30s.tar.bz2`. Os archives
somam 2.826.105.956 bytes comprimidos; a extração seletiva ocupa
16.563.576.021 bytes. Nenhum SHA-256 upstream foi encontrado, portanto os três
hashes fixados são declaradamente locais.

`scripts/data/fetch-geog.sh` valida tamanho, hash, compressão, paths, links,
índices e manifesto antes de instalar em `data/geog/mpas-8.4.1/`. Uma
reexecução retornou `unchanged`; conteúdo divergente é recusado.

O namelist do caso fixa case 7, dimensões unitárias, GMTED2010,
MODIFIED_IGBP_MODIS_NOAH, STATSGO e MODIS. Static interpolation e native GWD
estão ligados; GWD GSL e todas as etapas meteorológicas estão desligados.
Supersampling é 1, adequado à mesh de ~240 km segundo a orientação do User
Guide. `config_noahmp_static=false` segue a baseline tutorial e impede
reutilização com física que exija os campos Noah-MP ausentes.

A execução final foi:

```sh
mpiexec -n 1 /opt/mpas-model-8.4.1/init_atmosphere_model
```

O wrapper isolou rede/rootfs/inputs, escreveu somente sob
`data/cases/first-global-240km/static/` e levou 1.042 segundos. O output
`x1.10242.static.nc` é CDF-2, possui 18.201.336 bytes e SHA-256
`36e50a8f8d0233327b6505f74e2f909aaaa6c7cee03499affabadd5cc11a144f`.

A validação independente confirmou `nCells=10242`, campos de terreno, land
use, solo, vegetação, albedo e native GWD, zero missing inesperado, zero
NaN/Inf e categorias/ranges plausíveis. O log terminou com 3.016 outputs,
6 warnings de metadata opcional, 0 errors e 0 critical errors. A regressão da
mesh também passou.

A primeira tentativa falhou corretamente ao chegar ao native GWD porque
`landuse_30s/` ainda não estava presente. O source exato 8.4.1 revelou essa
leitura literal; o suplemento oficial foi adquirido, e nenhum output parcial
foi promovido. Os logs de diagnóstico permanecem locais e ignorados.

A integração agora comprovada é:

```text
x1.10242.grid.nc + WPS_GEOG → init_atmosphere static → x1.10242.static.nc
```

O WPS intermediate, o `init.nc` e, no ciclo 0013, a primeira hora do
`atmosphere_model` foram concluídos.

## Baseline e cliente ERA5 no ciclo 0010

O ADR 0007 fixa 2014-09-10 00 UTC, domínio global, grade CDS regular 0,25°
sem recorte/regrid e os datasets horários pressure/single-level. As requests
versionadas selecionam cinco variáveis em todos os 37 pressure levels e 19
campos single-level, totalizando 185 e 19 mensagens esperadas.

`docker/cds/Dockerfile` parte da imagem oficial Python 3.12.13 slim-bookworm
por digest, instala `cdsapi==0.7.7` e fixa a resolução transitiva observada.
O build terminou com `pip check` sem dependências quebradas. A imagem local
`mpas-era5:cdsapi-0.7.7` tem ID
`sha256:6f7044041f5c813f4042fed3cc4edb269ec4ba8e3663def887e408e75ae951d1`
e 47.761.384 bytes.

O wrapper executa com rootfs read-only, UID/GID do host, capabilities
removidas, `no-new-privileges`, configuração/credencial read-only e volume de
dados writable somente no download. O Python valida JSON, data versus
seletores, ausência de `area`/`grid`, mensagem/edição GRIB, end marker,
tamanho e SHA-256; também recusa sobrescrita sem manifesto idêntico.

Build, versão, `pip check`, smoke de requests e self-test do framing GRIB
passaram. O self-test aceitou GRIB1/GRIB2 enquadrados e rejeitou arquivo vazio,
HTML, JSON e GRIB truncado. A primeira tentativa de probe terminou antes da
rede porque `~/.cdsapirc` não existia. Depois da configuração manual segura,
os probes dos dois datasets retornaram exatamente 185 e 19 mensagens GRIB1.

Os downloads globais foram concluídos e validados independentemente:

| Arquivo | Bytes | SHA-256 local |
|---|---:|---|
| `era5-pressure-levels.grib` | 384.168.780 | `11a0a10a5727a19f64c529179af8b9e5fc4f92cdb60eb32ac90c68926b2e06ac` |
| `era5-single-levels.grib` | 41.995.970 | `5d0c6aeeef07c5109f044428266d822928c2cf4ccda1ccbb430c916f0b5b693b` |

O manifesto registra requests, cliente, jobs concluídos, tamanhos, hashes,
contagens e edições. Uma reexecução retornou `unchanged` para ambos sem novo
retrieve. Os dados e o manifesto estão ignorados e não rastreados; as requests
continuam versionáveis. O token não foi solicitado, impresso ou copiado.

O ciclo 0010 materializado comprovou:

```text
seleção + requests + cliente isolado + credencial/termos ✅
probe + ERA5 GRIB pressure/single-level + transporte bruto ✅
ungrib.exe (ciclo 0011) → executado posteriormente ✅
```

## Conversão ERA5 para WPS intermediate no ciclo 0011

O `g1print.exe` da mesma tag WPS 4.7.0 inventariou os dois GRIBs reais. Todas
as mensagens são GRIB1, análise de 2014-09-10 00 UTC e forecast hour zero.
Pressure possui os parâmetros 129, 157, 130, 131 e 132, level type 100, em
todos os 37 níveis solicitados; single possui exatamente os 19 tuples de
parâmetro, level type e camada esperados pelas requests.

Cada tuple casou uma única linha GRIB1 da
`/opt/wps/ungrib/Variable_Tables/Vtable.ECMWF` upstream. Em particular,
geopotencial, geopotencial de superfície, skin temperature, snow depth, sea
ice e as oito camadas de solo casaram sem customização. A tabela tem SHA-256
local `989bf7227ae5c822bfdd8467267dacc41396e08f2270735eac08c56a0096b335`.
Por isso nenhuma cópia divergente nem novo ADR foi criado.

Pressure e single-level foram executados separadamente, sempre offline, com
rootfs read-only, UID/GID do host, inputs/Vtable read-only e workspace limpo.
Cada log contém `Successful completion of ungrib.`. O parser streaming de
Fortran sequential records validou markers big-endian, version 5, headers,
projeção, tamanho de slabs e EOF exato antes da promoção atômica.

| Artefato local ignorado | Bytes | SHA-256 | Slabs |
|---|---:|---|---:|
| `ERA5_PRES:2014-09-10_00` | 768.340.520 | `f0a47a4eee5fb29ae37e6cbe8ffc19fbb68a394d8a7e14bd7e57c714cecdae8b` | 185 |
| `ERA5_SFC:2014-09-10_00` | 78.910.648 | `e1ea9841ee7a2b085e204e111d3747af87a746b4fd7c5eca2f2894d4d3a8400e` | 19 |
| `ERA5:2014-09-10_00` | 847.251.168 | `2d7a3ac93d1c904e45b3a19a9f524e6367f7fe72abab41a5263888f1a72b50f0` | 204 |

A grade observada é cilíndrica equidistante (`iproj=0`), 1440×721,
0,25°, global, com timestamp 2014-09-10 00 UTC. O combined é byte a byte
pressure seguido de single. O inventário final contém `HGT`, `RH`, `TT`,
`UU` e `VV` nos 37 níveis isobáricos, além dos campos superficiais requeridos:
`PSFC`, `PMSL`, `SOILHGT`, `TT/UU/VV/RH`, `SNOW`, `SEAICE`, `SKINTEMP`, quatro
`ST*` e quatro `SM*`. As conversões upstream substituíram `GEOPT`, `DEWPT`,
`SOILGEO` e `SNOW_EC`; não foram observados slabs adicionais.

O ciclo comprova:

```text
ERA5 GRIB real → inventário/Vtable → WPS 4.7.0 ungrib
               → ERA5:2014-09-10_00 ✅
```

`init_atmosphere_model` não foi executado no modo meteorológico e `init.nc`
não foi gerado.

## Condição inicial meteorológica no ciclo 0012

A configuração do init real usa case 7, ERA5 global em 2014-09-10 00 UTC,
38 first-guess levels, 55 níveis MPAS, topo de 30 km, quatro camadas de solo,
RH, Noah-MP false, lapse-rate, vertical/met interpolation e quatro ranks com
`part.4`. Não gera static, GWD, LBC ou surface update.

O runner executou:

```text
mpiexec -n 4 /opt/mpas-model-8.4.1/init_atmosphere_model
```

A execução científica levou 6,86265 s no timer MPAS e 7 s no manifesto. O log
terminou com 594 outputs, zero warnings, zero errors e zero critical errors.
PIO/PnetCDF escreveu CDF-2 sem flag MPI-IO extra.

| Artefato local ignorado | Bytes | SHA-256 |
|---|---:|---|
| `x1.10242.init.nc` | 92.641.692 | `9f2625d9f93ec873a8c1f3abef24083d1b03b910a77efea2f6dbfd2e13c36c7d` |
| `log.init_atmosphere.0000.out` | 20.915 observados no diretório local | preservado fora do Git |
| `manifest.json` | 1.043 observados no diretório local | hashes/config/comando/timestamps validados |

O C independente confirmou CDF-2, 10.242 células, 55 níveis, 56 interfaces,
quatro níveis de solo e `Time=1`; timestamp correto; zgrid crescente até 30
km; campos atmosféricos, superfície e solo finitos e sem missing; densidade e
pressão positivas; Noah-MP ausente. Mesh, static e init possuem as mesmas
10.242 células.

Há uma tolerância numérica documentada: seis valores `qv` entre zero e
`-1,05322406e-05 kg/kg`, derivados da conversão direta de RH sem clamp no
source 8.4.1. O validador permite no máximo `-2e-5` e reporta a contagem. Não
houve pós-processamento do arquivo.

O init prova `ERA5 → WPS → MPAS init`. O ciclo 0013 preservou esse arquivo
byte a byte e o consumiu na primeira integração do `atmosphere_model`.

## Primeira integração temporal no ciclo 0013

A configuração versionada deriva dos defaults gerados na build 8.4.1. Usa
`config_dt=1200.0`, duração `01:00:00`, quatro ranks/`part.4`, domínio
global, cold start, `mesoscale_reference`, Noah e intervalos RRTMG de uma
hora. LBC, restart e SST update permanecem desligados.

O source exato resolve a suite para WSM6, New Tiedtke, YSU, YSU-GWDO, cloud
fraction, RRTMG LW/SW, Monin–Obukhov revisado e `sf_noah`. Noah-MP não foi
ativado e nenhum campo foi inventado. As lookup tables requeridas foram
ligadas read-only a partir da árvore existente na imagem; não houve download.

O run canônico levou 8 s no manifesto e terminou normalmente:

| Evidência | Resultado |
|---|---|
| Relógio | 00:00 → 01:00 UTC; timesteps iniciados em 00:00, 00:20 e 00:40 |
| Log | 634 outputs; 3 warnings cold-start (`qi/qs/qg`); 0 errors; 0 critical |
| History | CDF-2 em 00/01; 10.242 células; 55 níveis; 4 soil |
| Diagnostics | CDF-2 em 00/01; 10.242 células |
| Finitude | 47.603.258 valores varridos; 0 NaN/Inf |
| Evolução | `rho`, `theta`, `u` e `qv` alterados; SST exatamente fixa |
| `qv` | mínimo -1,05322406e-05 no init → +8,90079619e-08 kg/kg em 1 h |
| Dívida `q2` | mínimo -4,71175474e-04 kg/kg em 11 células; finito e limitado |

Os quatro NetCDFs e o log, com tamanhos e SHA-256, estão inventariados no
manifesto local. O runner usa rede desligada, rootfs/inputs read-only,
UID/GID do host, capabilities removidas e promoção atômica; uma segunda
chamada retornou `unchanged`.

## Preservação da stack anterior

- a imagem científica validada e o `Dockerfile` permaneceram inalterados;
- nenhuma versão, dependência, estratégia HDF5/netCDF ou implementação MPI foi
  modificada;
- `init_atmosphere_model` e `atmosphere_model` permaneceram os binários já
  construídos e validados estruturalmente;
- somente as regressões diretamente consumidas foram executadas;
- a integração `part.4 ↔ 4 ranks` passou no init sem workaround MPI-IO.

## Arquiteturas adotadas

O caminho de I/O paralelo permanece:

```text
MPAS init_atmosphere/atmosphere
    → PIO 2.7.0 → PnetCDF 1.15.0 → MPI-IO → OpenMPI
```

O particionamento é uma preparação independente:

```text
x1.10242.grid.nc + graph.info → METIS 5.1.0 serial → graph.info.part.4
```

As decisões e alternativas estão em
[[../decisions/0002-pio2-pnetcdf-with-serial-netcdf|ADR 0002]],
[[../decisions/0003-metis-5.1.0-partitioning-baseline|ADR 0003]] e
[[../decisions/0004-wps-mpas-version-and-layout|ADR 0004]],
[[../decisions/0005-first-mesh-baseline|ADR 0005]], além de
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

## Artefatos do ciclo 0008

- `.gitignore`: política de exclusão de dados científicos locais;
- `scripts/data/fetch-mesh.sh`: aquisição first-party com SHA-256 fixado;
- `scripts/prepare/partition-mesh.sh`: geração reutilizável de `.part.N`;
- `scripts/validate/mesh.sh`: smoke offline/read-only estrutural e matemático;
- `docs/decisions/0005-first-mesh-baseline.md`: decisão de mesh e part.4;
- `docs/cases/first-global-240km.md`: documento evolutivo do primeiro caso;
- `learning/commits/0008-add-first-mesh.md`: nota educacional do ciclo.

## Artefatos do ciclo 0009

- `.gitignore`: política para dados geográficos locais;
- `scripts/data/fetch-geog.sh`: aquisição first-party, hashes e manifesto;
- `cases/first-global-240km/static/`: namelist e streams da release;
- `scripts/run/generate-static.sh`: execução MPI isolada;
- `scripts/validate/static.sh` e `tests/smoke/static_netcdf.c`: validação;
- `docs/decisions/0006-first-static-baseline.md`: baseline geográfica/static;
- `learning/commits/0009-generate-static-fields.md`: nota educacional.

## Artefatos do ciclo 0010

- `cases/first-global-240km/era5/`: duas requests e instruções;
- `docker/cds/`: imagem Python/CDS separada e lock completo;
- `scripts/data/fetch-era5.py`: aquisição, framing GRIB, SHA-256 e manifesto;
- `scripts/data/fetch-era5.sh`: build e execução isolada;
- `scripts/validate/era5.sh`: validação local e Git hygiene;
- `docs/decisions/0007-first-era5-baseline.md`: decisão meteorológica;
- `learning/commits/0010-add-era5-acquisition.md`: nota educacional.

## Artefatos do ciclo 0011

- `cases/first-global-240km/wps/`: namelists pressure e single-level;
- `scripts/run/ungrib-era5.sh`: execução isolada e promoção atômica;
- `scripts/validate/wps-intermediate.py`: parser streaming do formato version 5;
- `scripts/validate/wps-era5.py` e `wps-era5.sh`: auditoria cruzada completa;
- `scripts/validate/wps-ungrib.sh`: smoke estendido para `g1print`;
- `learning/commits/0011-ungrib-era5.md`: nota educacional do ciclo.

## Artefatos do ciclo 0012

- `cases/first-global-240km/init/`: namelist, streams e contrato do caso;
- `scripts/run/generate-init.sh`: preflight, isolamento, MPI, manifesto e
  promoção/idempotência;
- `scripts/validate/init.sh` e `tests/smoke/init_netcdf.c`: validação de log,
  estrutura, vertical, estado, superfície, solo e proveniência;
- `docs/decisions/0008-first-initial-condition-baseline.md`: baseline aceita;
- `learning/commits/0012-generate-initial-conditions.md`: nota educacional;
- outputs locais em `data/cases/first-global-240km/init/`, ignorados pelo Git.

## Artefatos do ciclo 0013

- `cases/first-global-240km/atmosphere/`: namelist, streams e stream lists
  derivados dos defaults 8.4.1;
- `scripts/run/run-atmosphere.sh`: preflight, isolamento, MPI, lookup links,
  manifesto, promoção e idempotência;
- `scripts/validate/atmosphere-run.sh` e
  `tests/smoke/atmosphere_netcdf.c`: validação do log, manifesto, NetCDF,
  ranges e evolução;
- `learning/commits/0013-first-atmosphere-run.md`: nota educacional;
- outputs locais em `data/cases/first-global-240km/atmosphere/`, ignorados.

## Extensões futuras, não componentes faltantes

- METIS 5.2.1 e GKlib externa;
- PT-Scotch;
- LBC permanece somente para eventual caso futuro de área limitada;
- forecast verification com ERA5 futuro, janela de spin-up e budgets
  científicos em integrações mais longas.

O projeto base não depende dessas extensões. A auditoria do ciclo 0015 conclui
`PROJECT_BASE_STATUS=COMPLETE` para o escopo técnico aprovado.

## Lacunas e limitações atuais

- a hora funcional consumiu `part.4` em quatro ranks, mas não mede
  escalabilidade nem desempenho;
- o static tem `config_noahmp_static=false` e não serve a uma física que
  exija os cinco campos Noah-MP ausentes;
- a release METIS 5.1.0 não fornece suíte formal; foram usados seus grafos de
  teste, `graphchk`, o comando real MPAS e validação independente;
- CMake emitiu aviso de depreciação e a GKlib incluída produziu avisos
  `-Wmisleading-indentation`; não houve erro;
- a imagem Ubuntu e as versões APT não possuem digest/lock completos;
- `csh` foi acrescentado por APT, mas sua versão não está fixada na receita;
- o checksum HDF5 continua ausente;
- os smokes instalados de zlib, HDF5, netCDF-C e netCDF-Fortran passaram no
  ciclo 0015; logs históricos das suítes upstream dessas quatro bibliotecas
  não foram preservados e permanecem como dívida documental;
- HDF5 e netCDF continuam seriais por decisão anterior;
- METIS 5.2.1 + GKlib fixada e PT-Scotch online são somente hipóteses futuras,
  sem conclusão de superioridade;
- a `Vtable.ECMWF` está validada somente para a baseline ERA5 real aprovada;
- avisos de código legado em libpng, JasPer e Fortran permanecem, apesar do
  build e da linkagem bem-sucedidos;
- o `q2` diagnóstico terminou com 11 valores negativos e mínimo
  -4,71175474e-04 kg/kg; o source da surface layer explica a extrapolação,
  e o caso está limitado/documentado; sua relevância meteorológica exige uma
  janela futura apropriada;
- os PASS funcional, numérico e científico de uma hora não provam forecast
  skill, equilíbrio de spin-up, desempenho multiday ou budgets fechados;
- o high mandatory exige download de 2,77 GB e seus hashes são locais porque
  o upstream não publica SHA-256;
- os seis warnings de metadata opcional da mesh permanecem documentados;
- a imagem Ubuntu e os pacotes APT, inclusive Python, não têm lock por digest.
