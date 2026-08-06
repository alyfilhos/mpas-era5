# Matriz de validação

## Como interpretar

Esta matriz separa quatro perguntas:

1. a suite do projeto upstream passou?
2. a instalação funciona em um caso mínimo?
3. o componente integra com a camada anterior?
4. onde está a evidência persistida do resultado?

**Planejado** não significa executado. **Definido no Dockerfile** significa que
o comando faz parte da receita e deverá falhar o build se retornar erro, mas
não prova que a execução ocorreu nesta máquina nem preserva o resultado. Um
componente só poderá receber status validado quando comando, resultado e
evidência estiverem registrados.

Última revisão: **2026-08-05**.

## Ambiente e stack existente

| Componente | Upstream test | Smoke test | Integration test | Status | Evidência |
|---|---|---|---|---|---|
| Ubuntu 24.04 + GNU | Não se aplica como suite única; validar os pacotes instalados | Planejado: registrar versões de `gcc`, `gfortran`, `make` e ferramentas essenciais | Planejado: compilar e executar programas mínimos C e Fortran dentro da imagem | Ambiente definido; resultado persistido ausente | [`Dockerfile`](../../Dockerfile) e [`current-state.md`](../project/current-state.md) |
| OpenMPI | suite própria não executada neste ciclo | wrappers e componentes MPI-IO consultados | programa Fortran/PnetCDF compilado com `mpifort` e executado em 4 ranks via ROMIO | OpenMPI 4.1.6 observado e integração PnetCDF aprovada; pacote continua sem versão fixada no APT | evidência do ciclo 0002 abaixo |
| zlib 1.3.2 | Não executado no `Dockerfile`; identificar e executar a suite oficial da release | Planejado: compilar/rodar compressão e descompressão mínima contra `/opt/mpas` | Planejado: confirmar que o HDF5 usa a zlib do prefixo | Build definido; validação incompleta | download, hash, build e install no [`Dockerfile`](../../Dockerfile); sem log de resultado |
| HDF5 1.14.6 | Não executado no `Dockerfile`; confirmar o comando upstream da release antes de executar | Planejado: consultar wrappers/configuração e criar/ler arquivo HDF5 mínimo em C e Fortran | Planejado: verificar zlib e fornecer HDF5 ao netCDF-C | Build definido; validação incompleta | configuração e install no [`Dockerfile`](../../Dockerfile); sem checksum ou relatório |
| netCDF-C 4.10.1 | `make check` está definido; resultado histórico não preservado | Planejado: `nc-config` e programa C que cria e relê um arquivo mínimo | Planejado: verificar linkagem com HDF5/zlib do prefixo | Teste exigido pela receita; smoke/integração e evidência ausentes | [`Dockerfile`](../../Dockerfile); nenhum relatório versionado |
| netCDF-Fortran 4.6.3 | `make check` está definido; resultado histórico não preservado | Planejado: `nf-config` e programa Fortran que cria e relê um arquivo mínimo | Planejado: verificar módulos, linkagem com netCDF-C e runtime do prefixo | Teste exigido pela receita; smoke/integração e evidência ausentes | [`Dockerfile`](../../Dockerfile); nenhum relatório versionado |
| PnetCDF 1.15.0 | `make check` e `make ptest` executados com código 0 | versão, prefixo, configuração, utilitários e shared/static conferidos na instalação | F90 → PnetCDF → MPI-IO/ROMIO → OpenMPI, escrita/leitura coletiva em 4 ranks | Implementado e validado no ciclo 0002 | [`Dockerfile`](../../Dockerfile), [`pnetcdf.sh`](../../scripts/validate/pnetcdf.sh), [`pnetcdf_mpi.f90`](../../tests/smoke/pnetcdf_mpi.f90) e evidência abaixo |
| PIO 2.7.0 | CTest: 109/109 testes aprovados | versão, configuração, headers, módulos, bibliotecas e pacote CMake conferidos | C → PIO/PnetCDF → MPI-IO → OpenMPI; CDF-2 escrito e relido em 4 ranks com OMPIO e ROMIO | Implementado e validado no ciclo 0003 | [`Dockerfile`](../../Dockerfile), [`pio.sh`](../../scripts/validate/pio.sh), [`pio_pnetcdf.c`](../../tests/smoke/pio_pnetcdf.c) e evidência abaixo |
| METIS 5.1.0 | não há `make check`/CTest formal; `graphchk` e `gpmetis` passaram no `4elt.graph` fornecido upstream | versão por macros, ferramentas, biblioteca, help e opções conferidos | fixture → `gpmetis` → `graph.info.part.4`; estrutura, IDs, quatro partições, edge cut e conectividade validados | Implementado e validado no ciclo 0004 | [`Dockerfile`](../../Dockerfile), [`metis.sh`](../../scripts/validate/metis.sh), [`graph.info`](../../tests/fixtures/metis/graph.info) e evidência abaixo |
| WPS 4.7.0 / ungrib | não foi identificada suíte formal para este recorte; build aplicável `configure` + `compile ungrib` passou | executável, links, `file`, `ldd`, `configure.wps`, proveniência, GRIB2 privado e Vtables conferidos offline | ERA5 GRIB → ungrib → WPS intermediate pendente; nenhum dado artificial ou aleatório foi usado | Build e smoke validados no ciclo 0005; integração funcional pendente | [`Dockerfile`](../../Dockerfile), [`wps-ungrib.sh`](../../scripts/validate/wps-ungrib.sh) e evidência abaixo |
| MPAS 8.4.1 `init_atmosphere` | a tag não contém suíte autocontida aplicável sem mesh/configuração; o build real do core passou | executável, defaults, proveniência, opções, `file`, `ldd`, símbolos e interfaces conferidos offline | mesh → `init_atmosphere` e mesh + WPS/ERA5 → `init.nc` pendentes | Build e smoke estrutural validados no ciclo 0006 e regressão aprovada no ciclo 0007; funcional/científico pendentes | [`Dockerfile`](../../Dockerfile), [`mpas-init.sh`](../../scripts/validate/mpas-init.sh) e evidência abaixo |
| MPAS 8.4.1 `atmosphere` | a tag não contém suíte autocontida aplicável sem mesh, `init.nc` e configuração; o build real do core passou | executável, defaults, configuração, pins, lookup tables, `file`, `ldd` e símbolos conferidos offline | `init.nc` + mesh + partição → `atmosphere_model` pendente | Build e smoke estrutural validados no ciclo 0007; funcional/científico pendentes | [`Dockerfile`](../../Dockerfile), [`mpas-atmosphere.sh`](../../scripts/validate/mpas-atmosphere.sh) e evidência abaixo |

## Componentes futuros

| Componente | Upstream test | Smoke test | Integration test | Status | Evidência |
|---|---|---|---|---|---|
| ERA5 | Não se aplica como suite de software única; validar cliente e esquema segundo fontes oficiais | Planejado: baixar uma amostra mínima sem registrar credenciais e conferir metadados/unidades | Planejado: amostra ERA5 → `ungrib` → `init_atmosphere` | Período/área/variáveis a decidir | [[../project/requirements|REQ-DATA-001]] |
| Mesh pública inicial | Validar com ferramentas/recomendações oficiais da release MPAS escolhida | Planejado: conferir dimensões, conectividade e metadados da mesh | Planejado: mesh aceita pelo `init_atmosphere` e pelo caso curto | Mesh a decidir | [[../project/requirements|REQ-MESH-001]] |
| `static.nc` | Não se aplica | Planejado: inspecionar dimensões, variáveis, atributos, valores ausentes e faixas plausíveis | Planejado: arquivo aceito na geração do estado inicial | Não gerado | [[../project/requirements|REQ-CASE-001]] |
| `init.nc` | Não se aplica | Planejado: verificar estrutura, completude, tempo e faixas físicas iniciais | Planejado: arquivo aceito por `atmosphere` em execução curta | Não gerado | [[../project/requirements|REQ-CASE-002]] |
| LBC | Não se aplica | Planejado somente para área limitada: verificar sequência temporal, cobertura e continuidade | Planejado somente quando aplicável: execução curta consome todos os contornos | Condicional; estratégia do caso a decidir | [[../project/requirements|REQ-CASE-003]] |
| Primeira execução | Não se aplica | Planejado: execução curta termina sem erro e produz logs/saídas esperados | Planejado: pipeline completo reproduz a execução a partir das entradas registradas | Não executada | [[../project/requirements|REQ-RUN-001]] |
| Validação física | Não se aplica | Planejado: checagens de sanidade, conservação, extremos, NaN/Inf e coerência temporal/espacial | Planejado: comparar entradas, estado inicial e evolução conforme critérios aprovados | Critérios quantitativos a decidir | [[../project/requirements|REQ-VAL-001]] |

## Evidência do ciclo 0002 — PnetCDF 1.15.0

| Campo | Evidência real |
|---|---|
| Data | 2026-08-04 |
| `HEAD` usado | `e1f86a4f29b10421946b054b85e2aea1f40c725c`; mudanças do ciclo ainda sem commit |
| Imagem | `mpas-era5:pnetcdf-1.15.0` |
| ID da imagem | `sha256:c31e25c9e36aa66a528203ff1edf9f2b6753ff54b7bdc69c15905f72e6295d03` |
| Build | `docker build --progress=plain --build-arg BUILD_JOBS=8 -t mpas-era5:pnetcdf-1.15.0 .`; código 0 |
| Integridade | SHA-256 do tarball conferido antes da extração: `39813fe91ec901c7cfca3212731edbb5201029ebf55caeaaaa08d9e33c6bad65` |
| Configuração | `--prefix=/opt/mpas --disable-gio --enable-shared --enable-static`; Fortran habilitado; NetCDF-4, ADIOS, subfiling, profiling e thread safety desabilitados |
| Toolchain | `/usr/bin/mpicc`, `mpicxx`, `mpif77`, `mpifort`; OpenMPI 4.1.6, MPI 3.1, GCC/GFortran 13.3.0 |
| `make check` | código 0; mensagem upstream “All sequential test programs have run successfully”; resumos sem `FAIL`/`ERROR`, com XFAILs esperados da suíte |
| `make ptest` | código 0; 4 ranks; grupos C, C++, F77, F90, exemplos, tutorial e benchmarks C/WRF-IO/FLASH-IO reportaram `pass`; `tst_max_var_dims` foi `skip` upstream |
| Launcher paralelo | `TESTMPIRUN="mpiexec --allow-run-as-root --mca io romio321 -n NP"`; exceção root somente no Docker build e componente ROMIO já fornecido pelo OpenMPI |
| Smoke instalado | `pnetcdf_version`, `pnetcdf-config --help/--all`, `ncmpidump`, prefixo, GIO, Fortran, `libpnetcdf.a` e `libpnetcdf.so` conferidos; código 0 |
| Integração versionada | `scripts/validate/pnetcdf.sh`; código 0; compilou a interface F90 instalada e executou 4 ranks em tmpfs efêmero |
| Resultado funcional | cada rank escreveu e releu seu índice; mensagem “PnetCDF MPI/Fortran smoke test passed with 4 ranks” |
| `ncmpidump` | formato `64-bit data`/CDF-5, dimensão `rank = 4`, variável inteira `rank_value = 0, 1, 2, 3` |
| Linkagem | executável carregou `/opt/mpas/lib/libpnetcdf.so.8`, `libmpi_mpifh.so.40` e `libmpi.so.40`; a própria `libpnetcdf.so` carregou `libmpi.so.40` |
| Regressão | `nc-config --version` → `netCDF 4.10.1`; `nf-config --version` → `netCDF-Fortran 4.6.3` |

### Limitações e testes não executados

- `make ptests` não foi executado; ele é a variante mais extensa com 3, 4, 6
  e 8 ranks. A validação upstream aprovada para o ciclo é `make check` mais
  `make ptest`.
- Os logs completos ficaram temporariamente em
  `/tmp/mpas-era5-pnetcdf-build.log` e
  `/tmp/mpas-era5-pnetcdf-validation.log`; não foram versionados. Esta matriz
  preserva a evidência resumida sem adicionar logs grandes.
- OMPIO produziu escrita incompleta em tentativas diagnósticas. ROMIO foi
  selecionado nos comandos PnetCDF; não houve alteração global ou reconstrução
  do OpenMPI.
- O primeiro smoke em diretório bind-mounted terminou corretamente, mas com
  latência anormal. A execução final usa tmpfs efêmero e timeout localizado de
  2 minutos e terminou com código 0 em aproximadamente 1,7 segundo.

## Evidência do ciclo 0003 — PIO 2.7.0

| Campo | Evidência real |
|---|---|
| Data | 2026-08-04 |
| `HEAD` usado | `2d6c5eec92766c6a7ca4018070e2aa6a21adc192`; mudanças do ciclo ainda sem commit |
| Imagem | `mpas-era5:pio-2.7.0` |
| ID/digest local da imagem | `sha256:0a54e71725fbdcbe44dee5f4012198ae504ddf191e4cf79fe2b7630c5bfe1c91` |
| Build | `docker build --progress=plain --build-arg BUILD_JOBS=8 -t mpas-era5:pio-2.7.0 .`; código 0 |
| Preservação da stack | etapas zlib, HDF5, netCDF-C, netCDF-Fortran e PnetCDF reportaram `CACHED`; nenhuma dessas camadas foi reconstruída |
| Integridade | SHA-256 do tarball PIO conferido antes da extração: `cce83743156ae723e7890931c2b48dcfe7ea8a276962dc4429f839d8f58d4a5a` |
| Auxiliares CMake | `CMake_Fortran_utils` em `05ff8d8e4c88786e94a02c853d3ff921113d785c`; `genf90` em `4816965ba946731352bad195b7d946a5fe682ff5`; ambos conferidos por `git rev-parse HEAD` |
| Configuração | CMake Release, `/opt/mpas`, `CC=mpicc`, `FC=mpifort`, Fortran/testes/exemplos/PnetCDF ON, timing/logging/docs/netCDF integration/GDAL OFF, static PIO |
| Descoberta | netCDF-C 4.10.1, netCDF-Fortran 4.6.3, MPI C/Fortran 3.1 e PnetCDF encontrados; `HAVE_NETCDF4` passou; `HAVE_NETCDF_PAR` falhou sem abortar |
| Suite upstream | `cmake --build pio-build --target tests --parallel 1` e CTest serial; 109/109 passaram, 0 falharam, em 37,12 s |
| Instalação | `pio.h`, `pio.mod`, `libpioc.a`, `libpiof.a`, `libpio.settings` e `PIOConfig.cmake` conferidos; PIO 2.7.0, Fortran e PnetCDF registrados |
| IOTYPEs | consulta runtime: `PNETCDF=1 NETCDF=1 NETCDF4C=0 NETCDF4P=0` |
| Integração versionada | `scripts/validate/pio.sh`; código 0; compilou `tests/smoke/pio_pnetcdf.c` contra a instalação final e executou 4 ranks em tmpfs |
| Resultado funcional | `PIO_IOTYPE_PNETCDF` permaneceu selecionado na criação/abertura; cada rank escreveu e releu `1000 + rank` |
| MPI-IO | teste passou uma vez com OMPIO padrão e uma vez com `--mca io romio321`, sem configuração global |
| `ncmpidump` | CDF-2/`64-bit offset`, dimensão `rank = 4`, `rank_value = 1000, 1001, 1002, 1003` |
| Linkagem | `nm` encontrou `PIOc_Init_Intracomm`; `ldd` encontrou `/opt/mpas/lib/libpnetcdf.so.8`, `/opt/mpas/lib/libnetcdf.so.22` e `libmpi.so.40` |
| Regressão PnetCDF | `PNETCDF_IMAGE=mpas-era5:pio-2.7.0 scripts/validate/pnetcdf.sh`; código 0; F90/CDF-5 em 4 ranks e versões netCDF-C 4.10.1, netCDF-Fortran 4.6.3, PnetCDF 1.15.0 preservadas |

### Limitações e testes ainda pendentes

- o build de `init_atmosphere` confirmou descoberta/link do PIO2; execução de
  I/O pelo modelo ainda aguarda mesh e configuração representativas;
- `PIO_IOTYPE_NETCDF4C` e `PIO_IOTYPE_NETCDF4P` não foram compilados, por
  consequência da stack netCDF/HDF5 serial e da condicional `_NETCDF4` do
  CMake PIO 2.7.0;
- `PIO_IOTYPE_NETCDF` foi confirmado como disponível, mas não recebeu neste
  ciclo um smoke funcional dedicado de criação/leitura;
- o alvo de testes foi construído serialmente para evitar a corrida upstream
  entre `pio_rearr_opts.F90.in` e `pio_rearr_opts2.F90.in`, que geram o mesmo
  módulo Fortran;
- os logs completos ficaram em `/tmp/mpas-era5-pio-build.log`,
  `/tmp/mpas-era5-pio-validation-final.log` e
  `/tmp/mpas-era5-pio-pnetcdf-regression.log`; não foram versionados.

## Evidência do ciclo 0004 — METIS 5.1.0

| Campo | Evidência real |
|---|---|
| Data | 2026-08-05 |
| Base do ciclo | `7e1d672696e6b892ca36b57ec53a1b3041aeedcf` (`build: add PIO2 with PnetCDF backend`); mudanças do ciclo sem commit |
| Imagem | `mpas-era5:metis-5.1.0` |
| ID/digest local da imagem | `sha256:4d1cd35469cf12c710643d78a93448924dcd5bb1af6155846dd1e4f213af53b3`; 337.756.200 bytes |
| Build | `docker build --progress=plain --build-arg BUILD_JOBS=8 -t mpas-era5:metis-5.1.0 .`; execução final terminou com código 0 |
| Preservação da stack | todas as etapas zlib, HDF5, netCDF-C, netCDF-Fortran, PnetCDF e PIO apareceram como `CACHED`; somente a nova camada METIS foi construída |
| Origem | `https://karypis.github.io/glaros/files/sw/metis/metis-5.1.0.tar.gz`, ligada pela página histórica first-party de George Karypis |
| Integridade | dois downloads independentes, 4.984.968 bytes cada, produziram SHA-256 local `76faebe03f6c963127dbb73c13eab58c9a3faeae48779f049066a21c087c5db2`; conferido antes da extração; upstream não publicou esse SHA-256 |
| Configuração | GNU make dirigindo CMake: `make config prefix=/opt/mpas`, `make -j8`, `make install`; build estático default, sem `shared=1`, `i64=1` ou `r64=1` |
| Larguras | header instalado confirmou `IDXTYPEWIDTH=32` e `REALTYPEWIDTH=32`; versão por macros 5.1.0 |
| GKlib | diretório `GKlib/` incluído no source 5.1.0 e compilado em `libmetis`; nenhum download externo |
| Instalação | `gpmetis`, `ndmetis`, `mpmetis`, `m2gmetis`, `graphchk`, `cmpfillin`, `metis.h` e `libmetis.a` presentes em `/opt/mpas`; símbolo `METIS_PartGraphKway` confirmado |
| Teste upstream disponível | não há alvos `make check`, CTest/`add_test` ou suíte formal no source; o diretório `graphs/` contém grafos de teste |
| Validação upstream aplicável | `graphchk graphs/4elt.graph` e `gpmetis -minconn -contig -niter=200 graphs/4elt.graph 4`; 15.606 vértices, 45.878 arestas, `Edgecut: 341`, balanceamento 1.001 e quatro partições contíguas |
| Smoke da instalação | `command -v` para seis executáveis; `gpmetis -help` confirmou `-minconn`, `-contig` e `-niter`; o banner legado informa `METIS 5.0`, enquanto os macros instalados comprovam 5.1.0 |
| Fixture | 16 vértices e 27 arestas: quatro cliques K4 ligadas em cadeia por três arestas-ponte; grafo não ponderado, conectado e independente de mesh MPAS |
| Comando funcional | `gpmetis -minconn -contig -niter=200 graph.info 4`; código 0 em tmpfs, com o repositório montado read-only |
| Arquivo gerado | `graph.info.part.4` criado apenas no diretório temporário; 16 linhas, exatamente uma atribuição por vértice, sem linha extra |
| IDs e cobertura | todas as linhas contêm um único inteiro em 0..3; partições 0, 1, 2 e 3 presentes; nenhum vértice sem atribuição |
| Contagem/balanceamento | 4 vértices em cada partição; média 4, mínimo 4, máximo 4; imbalance simples máximo/média 1.000, ou 0% |
| Edge cut | `gpmetis` reportou 3; recálculo independente sobre as 27 arestas também encontrou 3 |
| Contiguidade | `gpmetis` reportou cada partição contígua; busca independente confirmou quatro subgrafos conectados de 4 vértices |
| Invariável demonstrada | quatro partições produzem `graph.info.part.4`, correspondente a quatro tasks MPI futuras; MPAS não foi executado |
| Regressão PnetCDF | `PNETCDF_IMAGE=mpas-era5:metis-5.1.0 ./scripts/validate/pnetcdf.sh`; código 0; `nc-config` 4.10.1, `nf-config` 4.6.3, PnetCDF 1.15.0, F90/CDF-5 com 4 ranks e valores 0..3 |
| Regressão PIO | `PIO_IMAGE=mpas-era5:metis-5.1.0 ./scripts/validate/pio.sh`; código 0; PIO 2.7.0/PnetCDF, CDF-2 com 4 ranks e valores 1000..1003 passaram com OMPIO e ROMIO |

### Limitações, avisos e testes não executados

- não foi inventada uma suíte upstream: a release não registra `make check`
  ou testes CTest; os grafos upstream e o fixture funcional cobrem as
  validações aplicáveis;
- o CMake atual emite aviso de depreciação para compatibilidade antiga, e o
  compilador emite avisos `-Wmisleading-indentation` em fontes legadas da
  GKlib incluída; não houve erro de compilação;
- o build reportou aviso de jobserver ao forçar `-j8` no submake;
- o banner `METIS 5.0` é texto legado da release; a receita não o apresenta
  como prova de subversão e valida os macros 5.1.0 do header;
- nenhuma mesh MPAS real, MPAS, WPS, ERA5, METIS 5.2.1, GKlib externa ou
  PT-Scotch foi construída ou executada;
- as métricas do fixture didático não são conclusões de performance;
- logs completos permanecem temporariamente em
  `/tmp/mpas-era5-metis-build.log`,
  `/tmp/mpas-era5-metis-validation.log`,
  `/tmp/mpas-era5-metis-pnetcdf-regression.log` e
  `/tmp/mpas-era5-metis-pio-regression.log`; eles não serão versionados.

## Evidência do ciclo 0005 — WPS 4.7.0 / ungrib

| Campo | Evidência real |
|---|---|
| Data | 2026-08-05 |
| Base do ciclo | `7eb81e8d7a566ee16d79d9d8abdca1b6d09aadad` (`build: add METIS 5.1.0 partitioning support`); mudanças do ciclo sem commit |
| Imagem | `mpas-era5:wps-4.7.0` |
| ID/digest local da imagem | `sha256:437fb5d327aaeb1a2d79d4b2c9c0024a471f123f9416fa8e3bf1762d3b07267a`; 359.179.447 bytes |
| Build | `docker build --progress=plain --build-arg BUILD_JOBS=8 -t mpas-era5:wps-4.7.0 .`; código 0 |
| Preservação da stack | todas as etapas até METIS apareceram como `CACHED`; nenhuma versão/configuração científica anterior foi alterada |
| Origem | release/tag oficial `v4.7.0`, archive `https://github.com/wrf-model/WPS/archive/refs/tags/v4.7.0.tar.gz`, commit `5feccecd63384381b6942371c7a837f66e4ccb84` |
| Integridade | dois downloads independentes de 4.544.769 bytes produziram SHA-256 local `5232d20d7556338391b66aba45824d4fcd6c42712ebe9325f359f3c6cf043808`; conferido antes da extração; nenhum SHA-256 upstream foi encontrado |
| Dependência nova | somente pacote `csh`, que fornece `/bin/csh`; versão observada `20230828-1`, não fixada no APT |
| Configuração | `./configure --nowrf --build-grib2-libs`; Linux x86_64, GCC/GFortran, serial, `WRF_DIR=none`, sem `-D_MPI` |
| Seleção não interativa | `awk` deriva a numeração a partir de `arch/configure.defaults`, exige uma única entrada `Linux x86_64, gfortran` serial e envia o índice calculado; no source 4.7.0 observado, o resultado foi 1 |
| Build classificado | BUILD: `configure` + `./compile ungrib`; somente o alvo `ungrib` foi executado, com código 0 |
| Instalação | `/opt/wps-4.7.0/ungrib.exe` → `ungrib/src/ungrib.exe`; `/opt/wps` → `/opt/wps-4.7.0`; ausência de `geogrid.exe`, `metgrid.exe` e `/opt/mpas/bin/ungrib.exe` |
| Binário/linkagem | `file -L`: ELF 64-bit LSB PIE x86-64, dinâmico; `ldd`: `libgfortran.so.5`, `libm.so.6`, `libgcc_s.so.1`, `libc.so.6` e loader, sem `not found` |
| GRIB2 interno | zlib 1.2.11, libpng 1.6.37 e JasPer 1.900.29 construídos sob `/opt/wps-4.7.0/grib2`; `libz.a`, `libpng.a` e `libjasper.a` presentes; nenhuma JasPer em `/opt/mpas` |
| Vtables inspecionadas | `Vtable.ECMWF`, `Vtable.ECMWF_sigma`, `Vtable.ERA-interim.ml` e `Vtable.ERA-interim.pl` presentes; nenhum link `/opt/wps-4.7.0/Vtable` criado e nenhuma escolha ERA5 feita |
| Proveniência na imagem | `.mpas-era5-provenance` confirma versão, tag, commit, URL, SHA-256 e sua origem local |
| Smoke classificado | `scripts/validate/wps-ungrib.sh`; código 0; executado com `--network none`, raiz read-only e tmpfs, sem dados meteorológicos |
| Regressão PnetCDF | código 0; netCDF-C 4.10.1, netCDF-Fortran 4.6.3, PnetCDF 1.15.0 e F90/CDF-5 com quatro ranks preservados |
| Regressão PIO | código 0; PIO 2.7.0/PnetCDF e CDF-2 com quatro ranks passaram com OMPIO e ROMIO |
| Regressão METIS | código 0; METIS 5.1.0, quatro partições conectadas de 4 vértices, imbalance 1.000 e edge cut 3 conferido |
| Integração funcional | PENDENTE: ERA5 GRIB → Vtable aprovada → ungrib → WPS intermediate; ERA5 não foi baixado e nenhum GRIB falso foi criado |
| MPAS no estado do ciclo 0005 | 8.4.1/tag `v8.4.1`/commit `91c5eac175eebeaf4206bacd5cb50c39dff3c152` estavam fixados documentalmente; source e build ainda ausentes naquele ciclo |

### Limitações, avisos e testes não executados

- a release não forneceu, para o recorte `ungrib`, uma suíte formal adicional
  identificada; build bem-sucedido não é apresentado como teste funcional de
  dados;
- a primeira execução do smoke falhou porque o teste esperava um texto de
  versão que não existe no `compile`; a segunda revelou que o README descreve
  Vtables genericamente. As asserções foram alinhadas ao source da tag e a
  execução final passou sem remover verificações de instalação;
- libpng e JasPer emitiram avisos de código legado, inclusive formatação,
  `tmpnam` e possível uso após `realloc`; código Fortran antigo emitiu avisos
  de tipo/rank e make registrou receitas sobrescritas; não houve erro;
- não foram testados GRIB1 ou GRIB2 reais, cobertura de variáveis ERA5,
  níveis, unidades, tempos, Vtable ou consumo por `init_atmosphere`;
- `csh` e demais pacotes APT não possuem lock completo;
- o source WPS e seus binários existem somente na imagem; não são versionados
  no repositório.

## Evidência do ciclo 0006 — MPAS-Model 8.4.1 / init_atmosphere

| Campo | Evidência real |
|---|---|
| Data | 2026-08-05 |
| Base do ciclo | `5ed474e0fcdd1a111b0220ce64badc817c4bd244` (`build: add WPS ungrib support`); worktree inicial limpo, mudanças do ciclo sem commit |
| Imagem base | `mpas-era5:wps-4.7.0`, ID `sha256:437fb5d327aaeb1a2d79d4b2c9c0024a471f123f9416fa8e3bf1762d3b07267a` |
| Imagem final | `mpas-era5:mpas-init-8.4.1`, ID local `sha256:f5e6040cec6de2f0f9af14f1d37a091cbdbdf315cedce1c8f1cbc37a1b936193`, 411.742.970 bytes |
| Build da imagem | `docker build --progress=plain --build-arg BUILD_JOBS=8 -t mpas-era5:mpas-init-8.4.1 .`; código 0 |
| Preservação | todas as etapas até WPS apareceram como `CACHED`; nenhuma versão ou configuração anterior foi alterada |
| Source | clone Git oficial `--branch v8.4.1 --single-branch`; `git rev-parse HEAD` = `91c5eac175eebeaf4206bacd5cb50c39dff3c152`; metadata Git preservada |
| Probe | imagem WPS validada, ferramentas/variáveis/interfaces conferidas; build descartável passou antes da edição definitiva |
| Comando MPAS | `make -j8 gnu CORE=init_atmosphere USE_PIO2=true MPAS_ESMF=embedded`; código 0 |
| Arquitetura | GNU, wrappers MPI e `mpi_f08`; single precision; `-O3`; DEBUG off; OpenMP/offload/OpenACC off; PIO 2.x; ESMF embedded; MUSICA/PT-Scotch off |
| Artefatos | `/opt/mpas-model-8.4.1/init_atmosphere_model`, `namelist.init_atmosphere`, `streams.init_atmosphere` e cópias em `default_inputs/`; symlink `/opt/mpas-model` |
| Ausências deliberadas | nenhum `atmosphere_model`; nenhum download/configuração manual de MMM-physics, UGWP, MUSICA ou PT-Scotch |
| Binário | `file`: ELF 64-bit LSB PIE x86-64, dinâmico, não stripped; `ldd`: netCDF, PnetCDF, MPI, GFortran, HDF5, zlib e sistema resolvidos, sem `not found` |
| Evidência PIO2/PnetCDF | resumo “Using the PIO 2.x library”; `-DMPAS_PIO_SUPPORT`, `-lpiof -lpioc -lpnetcdf`; símbolos definidos `PIOc_Init_Intracomm`/`PIOc_createfile`/`PIOc_openfile`; `libpnetcdf.so.8` no `ldd` |
| Smoke | `scripts/validate/mpas-init.sh`; sem rede, raiz read-only e tmpfs; código 0 |
| Classificação | BUILD: PASS; STRUCTURAL/INSTALL SMOKE: PASS; FUNCTIONAL: PENDENTE; SCIENTIFIC/REAL-DATA: PENDENTE |
| Regressão PnetCDF | código 0; F90/CDF-5 em quatro ranks, valores 0–3 |
| Regressão PIO | código 0; PIO/PnetCDF CDF-2 com OMPIO e ROMIO, valores 1000–1003 |
| Regressão WPS | código 0; instalação/configuração/GRIB2/Vtables preservadas; funcional ERA5 ainda pendente |
| METIS | não reexecutado: nenhuma camada, configuração ou código de particionamento mudou; a etapa anterior foi recuperada do cache |

### Limitações, avisos e testes não executados

- o primeiro probe encontrou a proteção Git “dubious ownership” porque o
  source bind-mounted tinha UID diferente; a árvore descartável foi marcada
  como safe directory. O clone permanente é root-owned e não precisou disso;
- `USE_PIO2=true` é aceito, mas ignorado como seletor na 8.4.1; PIO2 é
  autodetectado. A configuração foi provada pelo resumo, opções e símbolos;
- ESMF embedded, Registry e make emitiram avisos de código legado, tabs,
  possível truncamento e regras antigas; não houve erro de compilação/linkagem;
- não se executou o binário porque a tag não fornece mesh/configuração/entradas
  autocontidas para este recorte;
- nenhuma mesh, ERA5, GRIB, NetCDF, `static.nc`, `init.nc`, LBC ou saída
  científica foi criada;
- o source e o binário MPAS existem somente na imagem e não são versionados no
  Git; logs completos também não são versionados;
- a árvore `.git` na imagem é intencional para `git describe` e
  proveniência, com custo de tamanho.

## Evidência do ciclo 0007 — MPAS-Model 8.4.1 / atmosphere

| Campo | Evidência real |
|---|---|
| Data | 2026-08-05 |
| Base do ciclo | `a70df2714667e57d2042762e822fe0344cbe8ec6` (`build: add MPAS init_atmosphere support`); worktree inicial limpo, mudanças do ciclo sem commit |
| Imagem base | `mpas-era5:mpas-init-8.4.1`, ID `sha256:f5e6040cec6de2f0f9af14f1d37a091cbdbdf315cedce1c8f1cbc37a1b936193`, 411.742.970 bytes |
| Imagem final | `mpas-era5:mpas-atmosphere-8.4.1`, ID local `sha256:54281c60db053982692d21bef27cf522293e8e2568be748cf4a83f2d5f0e4c93`, 466.941.565 bytes |
| Probe | primeiro make falhou porque `manage_externals` requer `python3`; com Python 3.12.3 numa árvore descartável, externals/lookup tables e o build passaram sem `make clean` |
| Build da imagem | `docker build --progress=plain --build-arg BUILD_JOBS=8 -t mpas-era5:mpas-atmosphere-8.4.1 .`; código 0 |
| Preservação | todas as 27 etapas até o MPAS init apareceram como `CACHED`; nenhuma camada científica anterior foi reconstruída |
| Source MPAS | tag `v8.4.1`, commit `91c5eac175eebeaf4206bacd5cb50c39dff3c152`, mesma árvore `/opt/mpas-model-8.4.1` e symlink `/opt/mpas-model` |
| MMM-physics | repo oficial, tag `20250616-MPASv8.3`, commit `a4baf7f3243d1db0dbc5f63473f895bdbdc05c30`; detached e sem mudanças rastreadas |
| UGWP | repo oficial, tag `MPAS_20241223`, commit `c1c893edcf171af5639af60e3a3a528816f6cc2b`; detached e sem mudanças rastreadas |
| MPAS-Data | repo oficial, tag `v8.2`, commit `c57dbc7be629802c6e848770a9e44b9bc602be41`; `COMPATIBILITY` contém 8.2 |
| Lookup tables | 16 arquivos copiados para `physics_wrf/files`, manifesto SHA-256 conferido; `checkout_data_files.sh` reportou dados compatíveis já existentes e não baixou durante o make |
| Comando MPAS | `make -j8 gnu CORE=atmosphere USE_PIO2=true MPAS_ESMF=embedded`; código 0 |
| Framework | `.build_opts.framework` = init = atmosphere; hash de conteúdo do archive e hash de `init_atmosphere_model` inalterados; `ar -ru` reempacotou/reindexou o archive, sem recompilar objetos Fortran do framework |
| Arquitetura | `CORE=atmosphere`; GNU, wrappers MPI e `mpi_f08`; single precision; `-O3`; PIO 2.x/PnetCDF; ESMF embedded; DEBUG/OpenMP/offload/OpenACC/MUSICA/PT-Scotch off |
| Artefatos | `atmosphere_model`, `namelist.atmosphere`, `streams.atmosphere` e cópias em `default_inputs/`; todos os equivalentes init preservados |
| Binário/linkagem | ELF 64-bit PIE x86-64 dinâmico; `ldd` resolveu MPI/netCDF/PnetCDF sem `not found`; ausência de `libpio.so` esperada; símbolos `PIOc_*` definidos e `ncmpi_*` resolvidos |
| Smoke atmosphere | `scripts/validate/mpas-atmosphere.sh`; sem rede, raiz read-only e tmpfs; código 0 |
| Regressão init | `MPAS_INIT_IMAGE=mpas-era5:mpas-atmosphere-8.4.1 ./scripts/validate/mpas-init.sh`; código 0 |
| Regressão PIO | código 0; PIO/PnetCDF CDF-2 em quatro ranks com OMPIO e ROMIO; valores 1000–1003 |
| Regressão PnetCDF | código 0; F90/CDF-5 em quatro ranks; valores 0–3 |
| WPS/METIS | não reexecutados: nenhum arquivo, camada ou contrato desses componentes mudou; etapas correspondentes estavam `CACHED` |
| Classificação | BUILD: PASS; STRUCTURAL SMOKE: PASS; FUNCTIONAL: PENDENTE; SCIENTIFIC: PENDENTE |

### Limitações, avisos e testes não executados

- `USE_PIO2=true` não é evidência isolada: a 8.4.1 autodetecta PIO2; resumo,
  opções, linkagem e símbolos comprovaram o backend;
- o build emitiu avisos de statement functions obsolescentes e avisos
  make/`ar` upstream; não houve erro de compilação ou linkagem;
- Python foi obtido por APT e não possui pin completo por versão/digest;
- externals e lookup tables ficam na imagem, não no Git do projeto;
- nenhuma mesh, partição real, ERA5, GRIB, `static.nc`, `init.nc`, LBC ou
  saída científica foi criada;
- `atmosphere_model` não foi executado: a validação funcional exige entradas
  representativas e uma decisão futura sobre mesh/caso.

## Evidência mínima de um resultado futuro

Cada atualização de status deve registrar:

- componente e versão;
- imagem/commit usado;
- comando completo;
- data e ambiente;
- código de saída;
- resumo contável (`passed`, `failed`, `skipped`) quando fornecido;
- artefato ou log pequeno e seguro;
- interpretação do resultado e limitações;
- teste de integração associado.

Não versionar credenciais, ERA5 volumoso, saídas MPAS grandes ou logs com
segredos. Resultados resumidos devem ser suficientes para auditar o teste e
indicar onde artefatos externos controlados podem ser encontrados.
