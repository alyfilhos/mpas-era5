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

Última revisão: **2026-08-14**.

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
| WPS 4.7.0 / ungrib | não foi identificada suíte formal para este recorte; `configure`, `compile ungrib` e alvo incremental `compile g1print` passaram | executáveis, links, `file`, `ldd`, configuração, proveniência, GRIB2 privado e Vtable upstream conferidos offline | 204 mensagens ERA5 GRIB1 → `Vtable.ECMWF` → dois ungribs → WPS intermediate: PASS | Build/smoke no ciclo 0005; inventário e integração funcional no ciclo 0011 | [`Dockerfile`](../../Dockerfile), [`wps-ungrib.sh`](../../scripts/validate/wps-ungrib.sh), [`ungrib-era5.sh`](../../scripts/run/ungrib-era5.sh) e [`wps-era5.sh`](../../scripts/validate/wps-era5.sh) |
| MPAS 8.4.1 `init_atmosphere` | a tag não contém suíte autocontida; build real do core passou | executável/defaults/proveniência conferidos e static NetCDF validado independentemente | mesh + WPS_GEOG → static: PASS; mesh + WPS/ERA5 → `init.nc` pendente | Build/smoke estrutural nos ciclos 0006/0007; execução static funcional no ciclo 0009 | [`Dockerfile`](../../Dockerfile), [`mpas-init.sh`](../../scripts/validate/mpas-init.sh), [`generate-static.sh`](../../scripts/run/generate-static.sh), [`static.sh`](../../scripts/validate/static.sh) e evidência abaixo |
| MPAS 8.4.1 `atmosphere` | a tag não contém suíte autocontida aplicável sem mesh, `init.nc` e configuração; o build real do core passou | executável, defaults, configuração, pins, lookup tables, `file`, `ldd` e símbolos conferidos offline | `init.nc` + mesh + partição → `atmosphere_model` pendente | Build e smoke estrutural validados no ciclo 0007; funcional/científico pendentes | [`Dockerfile`](../../Dockerfile), [`mpas-atmosphere.sh`](../../scripts/validate/mpas-atmosphere.sh) e evidência abaixo |

## Dados adquiridos e componentes futuros

| Componente | Upstream test | Smoke test | Integration test | Status | Evidência |
|---|---|---|---|---|---|
| ERA5 / cliente CDS | O dataset não possui suite; build do cliente executou `pip check` sem dependências quebradas | Python 3.12.13, `cdsapi==0.7.7`, lock, requests, framing, manifestos e reexecução idempotente validados | Probes + pressure/single global → GRIB1 bruto: PASS; GRIB real → WPS intermediate: PASS | Aquisição validada no ciclo 0010 e conversão no 0011 | [`era5.sh`](../../scripts/validate/era5.sh), [`wps-era5.sh`](../../scripts/validate/wps-era5.sh) e evidências abaixo |
| Mesh pública inicial | Fonte/proveniência e integridade do pacote x1.10242 confirmadas; `graphchk` aprovado no grafo real | NetCDF, dimensões, variáveis, grafo, part.4, edge cut, balanceamento e conectividade conferidos offline | `graph.info` real → METIS 5.1.0 → `part.4`: PASS; mesh real → init static: PASS | x1.10242 validada no ciclo 0008 e consumida funcionalmente no ciclo 0009 | [`fetch-mesh.sh`](../../scripts/data/fetch-mesh.sh), [`partition-mesh.sh`](../../scripts/prepare/partition-mesh.sh), [`mesh.sh`](../../scripts/validate/mesh.sh) e evidências abaixo |
| `static.nc` | Não se aplica | CDF-2, dimensões, atributos, Registry/source, campos, missing, NaN/Inf, categorias e ranges conferidos | x1.10242 + WPS_GEOG → init case 7 → `x1.10242.static.nc`: PASS em 1 task MPI | Gerado e validado no ciclo 0009; local/ignorado; Noah-MP ausente por decisão | [`generate-static.sh`](../../scripts/run/generate-static.sh), [`static.sh`](../../scripts/validate/static.sh), [`static_netcdf.c`](../../tests/smoke/static_netcdf.c) e evidência abaixo |
| WPS intermediate ERA5 | Não se aplica | parser streaming valida records Fortran big-endian, version 5, headers, projeção, slabs e EOF | GRIB/g1print → Vtable → logs → pressure/single/combined: PASS; campos funcionais e 37 níveis confirmados | Gerado e validado no ciclo 0011; três arquivos/logs/manifesto locais e ignorados | [`wps-intermediate.py`](../../scripts/validate/wps-intermediate.py), [`wps-era5.py`](../../scripts/validate/wps-era5.py) e evidência do ciclo 0011 |
| `init.nc` | Não se aplica | Planejado: verificar estrutura, completude, tempo e faixas físicas iniciais | Planejado: arquivo aceito por `atmosphere` em execução curta | Não gerado | [[../project/requirements|REQ-CASE-002]] |
| LBC | Não se aplica | Planejado somente para área limitada: verificar sequência temporal, cobertura e continuidade | Planejado somente quando aplicável: execução curta consome todos os contornos | Não se aplica ao primeiro caso global; condicional para casos futuros | [[../project/requirements|REQ-CASE-003]] |
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

## Evidência do ciclo 0008 — primeira mesh MPAS x1.10242

| Campo | Evidência real |
|---|---|
| Data | 2026-08-06 |
| Base do ciclo | `d13c82f1b46832cd0d063ed8151b56d294707771` (`build: add MPAS atmosphere support`); worktree inicial limpo, mudanças do ciclo sem commit |
| Imagem usada | `mpas-era5:mpas-atmosphere-8.4.1`, ID local `sha256:54281c60db053982692d21bef27cf522293e8e2568be748cf4a83f2d5f0e4c93`, 466.941.565 bytes |
| Fonte oficial | página [Meshes & Mesh Utilities](https://www2.mmm.ucar.edu/projects/mpas/site/downloads/meshes.html): seção quasi-uniforme, 240 km, 10.242 células, pacote com SCVT/`graph.info`/partições |
| URL resolvida | `https://www2.mmm.ucar.edu/projects/mpas/atmosphere_meshes/x1.10242.tar.gz` |
| Integridade | dois downloads independentes de 6.321.104 bytes, byte-a-byte iguais; SHA-256 local `4dde31932bc45aaf467e2717d17ec8e5e54d73c3ebbeea027087bfdb8b98ab56`; nenhum SHA-256 upstream encontrado |
| Archive | `x1.10242.grid.nc`, `x1.10242.graph.info` e partições pré-computadas para 2, 4, 6, 8, 12, 16, 24, 32, 36, 48 e 64 partes; somente grid e grafo copiados |
| Aquisição | `scripts/data/fetch-mesh.sh`; hash antes da extração, listagem antes de extrair, extração temporária, nomes canônicos exigidos, conteúdo existente divergente rejeitado; segunda execução `unchanged` |
| Política de dados | artefatos em `data/meshes/x1.10242/`, ignorados pelo Git e ausentes da imagem; static file pronto não baixado |
| NetCDF | `ncdump -k`: `64-bit offset`; `nCells=10242`, `nVertices=20480`, `nEdges=30720`, `maxEdges=10`, `maxEdges2=20`, `vertexDegree=3` |
| Variáveis | `latCell`, `lonCell`, `nEdgesOnCell`, `cellsOnCell`, `edgesOnCell`, `verticesOnCell` e `indexToCellID` presentes e lidas por `ncdump` |
| `graphchk` | código 0; “The format of the graph is correct”; 10.242 vértices e 30.720 arestas |
| Grafo independente | header `10242 30720`; exatamente 10.242 linhas; índices em 1..10242; sem self-edge/duplicata/assimetria; arestas coerentes; grafo conectado |
| Vínculo mesh ↔ grafo | `nCells = 10242 =` número de vértices do `graph.info` |
| Comando METIS | `gpmetis -minconn -contig -niter=200 x1.10242.graph.info 4`; METIS 5.1.0 da imagem; código 0; UID/GID do usuário |
| Resultado `gpmetis` | `Edgecut: 663`; balanceamento 1.003; quatro partições contíguas; reexecução produziu conteúdo idêntico |
| Contagens da partição | partição 0: 2566; 1: 2549; 2: 2568; 3: 2559; total 10.242; média 2560,5 |
| Imbalance independente | mínimo 2549, máximo 2568; máximo/média 1,002929, ou 0,292912% |
| Edge cut independente | 663, igual ao valor reportado por `gpmetis` |
| Contiguidade independente | quatro subgrafos conectados: 2566, 2549, 2568 e 2559 células alcançadas |
| Smoke | `scripts/validate/mesh.sh`; `--network none`, raiz e bind da mesh read-only, tmpfs para temporários; `mesh_smoke=PASS` |
| Regressão | Dockerfile e versões inalterados; imagem existente acessível; scripts `mpas-init.sh` e `mpas-atmosphere.sh` presentes; smokes MPAS não reexecutados por ausência de impacto |

### Estado dos gates da primeira mesh

| Gate | Estado |
|---|---|
| SOURCE/PROVENANCE | PASS |
| ARTIFACT INTEGRITY | PASS |
| NETCDF STRUCTURE | PASS |
| GRAPH STRUCTURE | PASS |
| REAL METIS PARTITION | PASS |
| MPAS `init_atmosphere` integration | PENDING |
| `static.nc` | PENDING |

Esses dois estados PENDING descrevem o fechamento histórico do ciclo 0008;
ambos são superados pelos PASS registrados no ciclo 0009 abaixo.

### Limites

- uma partição válida não é um benchmark nem prova configuração ótima de
  performance; quatro ranks são apenas a baseline aprovada;
- a partição upstream `.part.4` presente no archive não foi usada;
- `init_atmosphere_model`, datasets geográficos, `static.nc`, ERA5,
  `init.nc` e `atmosphere_model` não foram executados;
- a mesh ainda não foi aceita funcionalmente pelo MPAS; a evidência deste
  ciclo é de proveniência, integridade, estrutura e particionamento.

## Evidência do ciclo 0009 — campos estáticos x1.10242

| Campo | Evidência real |
|---|---|
| Data | 2026-08-14 |
| Base do ciclo | `7555a96a7c706ea9e719f23ff27eaf29498ffe05` (`data: add reproducible MPAS mesh workflow`); branch `main`, alinhada a `origin/main`; worktree inicial limpo |
| Imagem | `mpas-era5:mpas-atmosphere-8.4.1`, ID `sha256:54281c60db053982692d21bef27cf522293e8e2568be748cf4a83f2d5f0e4c93`, 466.941.565 bytes; Dockerfile inalterado |
| Pesquisa | Running MPAS/Static Fields, tutorial St Andrews 2025, Geographic Static Data WPS e Registry/source exatos v8.4.1 |
| Low mandatory | 149.872.777 bytes; SHA-256 local `cbdbcc43554d946a38cbce658b7d563afd7a2889f2c0735b8aa3f2206c7256e7`; inspecionado e rejeitado: não contém os diretórios 30s requeridos |
| High mandatory | URL first-party; 2.772.782.816 bytes; SHA-256 local `89b026b9db0a03c0c995e53b4a1d99663af1f6bda21b3b34c3c2c07386da5493`; ranges/tamanho/gzip/tar PASS |
| MODIS supplement | 32.334.661 bytes; SHA-256 local `b21ca154d1038ec271abaa1be2fd38a0cd055b8a4ddfaab520719478ac48d326`; dois downloads iguais; bzip2/tar/index PASS |
| GWD landuse supplement | 20.988.479 bytes; SHA-256 local `143cd195ae91f64011a43eae52ca00228709672c6a2ba614cb437eeb4cd41160`; dois downloads iguais; bzip2/tar/index PASS |
| SHA upstream | nenhum SHA-256 publicado encontrado; hashes registrados explicitamente como locais |
| Instalação geográfica | 8 diretórios, 5.274 arquivos/indexes, 16.563.576.021 bytes; manifesto por arquivo; segunda execução do fetch retornou `unchanged` |
| Datasets | `albedo_modis`, `greenfrac_fpar_modis`, `landuse_30s`, `maxsnowalb_modis`, `modis_landuse_20class_30s`, `soiltemp_1deg`, `soiltype_top_30s`, `topo_gmted2010_30s` |
| Configuração | case 7; dimensões static=1; GMTED2010/MODIS/STATSGO; supersampling 1; Noah-MP false; static/native GWD true; GWD GSL/vertical/met/SST/seaice false |
| Streams | input `x1.10242.grid.nc`; output `x1.10242.static.nc`; surface/lbc/ugwp preservados e ignorados pelos stages desligados |
| Isolamento | `--network none`, rootfs/inputs read-only, somente output writable, UID/GID do host, sem alteração de `/opt/mpas-model` |
| Comando científico | `mpiexec -n 1 /opt/mpas-model-8.4.1/init_atmosphere_model`; exatamente 1 task MPI |
| Tempo | wrapper: 1.042 s; timer MPAS: 1.041,84729 s |
| Primeiro intento | falhou no native GWD por ausência de `landuse_30s/`; source exato confirmou path literal; output parcial não foi promovido, logs locais preservados e ignorados |
| Output | `data/cases/first-global-240km/static/x1.10242.static.nc`; 18.201.336 bytes; SHA-256 `36e50a8f8d0233327b6505f74e2f909aaaa6c7cee03499affabadd5cc11a144f` |
| NetCDF | CDF-2 / 64-bit offset; `nCells=10242`, `nEdges=30720`, `nVertices=20480`, `nMonths=12`, `Time=1` |
| Campos | terreno, máscara/land use, solo, vegetation fraction, albedo/snow albedo e GWD `var2d/con/oa1..4/ol1..4` presentes |
| Noah-MP | `soilcomp` e `soilcl1..4` ausentes como esperado; static proibido para física futura que exija esses campos |
| Integridade física | todos os campos testados com missing=0 e NaN/Inf=0; categorias integrais; ranges plausíveis; `shdmin <= shdmax`; `static_validation=PASS` |
| Ranges principais | `ter=-27..5112,52686`; `ivgtyp=1..19`; `isltyp=1..16`; `snoalb=0..0,839999974`; `soiltemp=0..305,01825`; `albedo12m=6,29671335..70`; `var2d=0..2023,71582`; `con=0..232,8871`; OA=-1..1; OL=0..1 |
| Log | 3.016 output, 6 warnings de metadata opcional, 0 errors, 0 critical; `Logging complete` |
| Regressão mesh | formato/dimensões/grafo/part.4 novamente aprovados; edge cut 663, imbalance 0,292912%, quatro partições conectadas; `mesh_smoke=PASS` |
| Limite | prova mesh + geografia → static; não prova ERA5, WPS intermediate, `init.nc`, Noah-MP nem previsão |

### Divergências documentais resolvidas

- User Guide: uma task; tutorial recente: static paralelo. A baseline usa uma
  task sem afirmar que paralelismo é impossível.
- User Guide: supersampling 1; Registry 8.4.1: default 3; tutorial deixa 3
  implícito. A mesh de ~240 km fixa 1 explicitamente.
- Tutorial: Noah-MP false; Registry: default true. A baseline fixa false e
  valida a ausência dos campos.
- O User Guide não explicita o `landuse_30s/` de native GWD. Para o
  comportamento 8.4.1 prevaleceu o path literal no source.

### Gates do ciclo

| Gate | Estado |
|---|---|
| OFFICIAL SOURCE RESEARCH | PASS |
| ARCHIVE CONTENT/INTEGRITY | PASS |
| REPRODUCIBLE ACQUISITION | PASS |
| MESH REGRESSION | PASS |
| MPAS STATIC EXECUTION | PASS |
| NETCDF/PHYSICAL VALIDATION | PASS |
| ERA5 → `init.nc` | PENDING, fora do escopo |
| `atmosphere_model` forecast | PENDING, fora do escopo |

## Evidência do ciclo 0010 — baseline e aquisição ERA5

| Campo | Evidência real |
|---|---|
| Data | 2026-08-14 |
| Base | `6a527d97f66a94b03e8320d5369167a9365c6490`; branch `main` alinhada a `origin/main`; worktree inicial limpo |
| Decisão | 2014-09-10 00 UTC, global, 37 níveis, 5 variáveis pressure, 19 single-level, GRIB e container dedicado aprovados explicitamente |
| Requests | JSON válido; pressure: 5 × 37 = 185 mensagens; single: 19 mensagens; `area`/`grid` ausentes; request SHA-256 `13cf2e50f81dadb4bb347c39ac4ebc77cf519e96a88fe9f50e2152e75d49873a` e `de3a1bce687a56f4be55ab62439498bd7eca659b6adda9b2c55ee0a3be0d73f4` |
| Base do cliente | Python Official Image 3.12.13 slim-bookworm; digest `sha256:d50fb7611f86d04a3b0471b46d7557818d88983fc3136726336b2a4c657aa30b` |
| Cliente | `cdsapi==0.7.7`; dependências transitivas fixadas; build e `pip check` código 0 |
| Imagem local | `mpas-era5:cdsapi-0.7.7`, ID `sha256:6f7044041f5c813f4042fed3cc4edb269ec4ba8e3663def887e408e75ae951d1`, 47.761.384 bytes |
| Isolamento | rootfs read-only, UID/GID do host, capabilities removidas, `no-new-privileges`, requests/credencial read-only e somente output writable no download |
| Self-test | framing GRIB1/GRIB2 aceito; vazio, HTML, JSON e GRIB truncado rejeitados; manifesto idêntico aceito e checksum divergente recusado; ambos os self-tests PASS no host e no container |
| Config smoke | ambos os datasets, instante, domínio, 5/37/185 e 19/0/19 conferidos com rede desligada |
| Preflight da credencial | ausência inicial recusada com código 1 e sem criar dados; arquivo depois fornecido como regular, não symlink e modo `600` |
| Autenticação/termos | retrieves bem-sucedidos nos dois datasets; confirmação empírica sem imprimir ou copiar o token |
| Probe pressure | job `11024332-1fd6-47f6-af20-a70d42ca4539` successful; 29.230 bytes; 185 mensagens GRIB1; SHA-256 `ee199692c9cee1a1c6983be1f90a523f903889a1b06d58fefeb7d0a98b60f341` |
| Probe single | job `9a0c3182-d923-4fc1-9377-7fcc38f7b39e` successful; 3.118 bytes; 19 mensagens GRIB1; SHA-256 `b18bee89bcca223af1be15e4ecbd97a3b46556e651d51c945d9e221d2c928420` |
| Pressure global | job `b7a6ac07-dcae-4fac-81d6-41da9daca21c` successful; 384.168.780 bytes; 185 mensagens GRIB1; SHA-256 `11a0a10a5727a19f64c529179af8b9e5fc4f92cdb60eb32ac90c68926b2e06ac` |
| Single global | job `548eaa8b-7e65-41f9-bac1-040b71b82153` successful; 41.995.970 bytes; 19 mensagens GRIB1; SHA-256 `5d0c6aeeef07c5109f044428266d822928c2cf4ccda1ccbb430c916f0b5b693b` |
| Recuperação de transporte | pressure teve duas `IncompleteRead`; o cliente retomou do byte parcial e a validação final integral passou |
| Validação independente | arquivos regulares/não vazios, framing e terminadores GRIB, edição, contagens, tamanho, SHA-256, manifesto/request e Git hygiene: PASS |
| Idempotência | segunda execução retornou `unchanged` para os dois arquivos e não submeteu novo retrieve |
| Segurança | nenhuma credencial em args/env/imagem; `.cdsapirc`, GRIBs e manifesto ignorados; requests trackable |
| Preservação | imagem científica manteve ID `sha256:54281c60db053982692d21bef27cf522293e8e2568be748cf4a83f2d5f0e4c93` e 466.941.565 bytes; Dockerfile científico inalterado |

### Gates do ciclo 0010 neste ponto

| Gate | Estado |
|---|---|
| ERA5 source/provenance | PASS |
| Baseline/request schema | PASS |
| Acquisition container build | PASS |
| Client/version/dependency check | PASS |
| CDS authentication | PASS |
| Dataset Terms of Use | PASS, confirmado pelos dois retrieves |
| Pressure GRIB probe | PASS |
| Single-level GRIB probe | PASS |
| Pressure GRIB acquisition | PASS |
| Single-level GRIB acquisition | PASS |
| Raw transport validation | PASS |
| ERA5 → ungrib | PENDING, ciclo 0011 |
| ERA5 → `init.nc` | PENDING, ciclo posterior |

## Evidência do ciclo 0011 — ERA5 para WPS intermediate

| Campo | Evidência real |
|---|---|
| Data/base | 2026-08-15; `78fd3a26187305612223a06ba65a52325b95d908` (`data: add reproducible ERA5 acquisition`) |
| Imagem | `mpas-era5:mpas-atmosphere-8.4.1`; ID `sha256:9c9479db0bae4db1e8d827bf522caab312ad097217aba962cb399f18b74e93a8`; 467.002.046 bytes |
| Ferramentas | `/opt/wps/ungrib.exe`, `/opt/wps/g1print.exe`, `/opt/wps/link_grib.csh` e `/opt/wps/ungrib/Variable_Tables/Vtable.ECMWF`: presentes e funcionais |
| Ajuste de imagem | a imagem anterior não continha `g1print`; somente o target upstream `./compile g1print` da mesma tag 4.7.0 foi acrescentado depois das camadas existentes; nenhuma versão ou core MPAS mudou |
| Regressão de entrada | `./scripts/validate/era5.sh`: PASS antes e dentro da validação integrada; nenhum retrieve/download |
| Pressure GRIB | GRIB Edition 1; 185 mensagens; 2014-09-10 00 UTC; forecast zero; 5 parâmetros × os 37 níveis solicitados |
| Single GRIB | GRIB Edition 1; 19 mensagens; 2014-09-10 00 UTC; forecast zero; 19 tuples semânticos distintos |
| Vtable | upstream WPS 4.7.0 usada diretamente; SHA-256 local `989bf7227ae5c822bfdd8467267dacc41396e08f2270735eac08c56a0096b335`; nenhum arquivo custom e nenhum ADR novo |
| Execução | rede desligada, rootfs read-only, UID/GID do host, capabilities removidas, `no-new-privileges`, GRIB/config read-only e workspace novo/writable por conjunto |
| Pressure command | `./scripts/run/ungrib-era5.sh`; internamente `link_grib.csh /input/era5.grib` e `/opt/wps/ungrib.exe`, namelist `prefix='ERA5_PRES'` |
| Single command | mesma invocação, segundo workspace limpo, `prefix='ERA5_SFC'`; nenhum `GRIBFILE.*` reaproveitado |
| Logs | pressure: 23.763 bytes, SHA-256 `7d5aee76e36af5295f68be1377fb79750ee546fe8495fff1a77447e311a78e4e`; single: 2.953 bytes, SHA-256 `27d79466b5f31479683875447f5bbbc4f319215ec868e126919a29afb49df9c3`; ambos contêm sucesso explícito |
| Pressure intermediate | 768.340.520 bytes; SHA-256 `f0a47a4eee5fb29ae37e6cbe8ffc19fbb68a394d8a7e14bd7e57c714cecdae8b`; 185 slabs |
| Single intermediate | 78.910.648 bytes; SHA-256 `e1ea9841ee7a2b085e204e111d3747af87a746b4fd7c5eca2f2894d4d3a8400e`; 19 slabs |
| Combined intermediate | 847.251.168 bytes; SHA-256 `2d7a3ac93d1c904e45b3a19a9f524e6367f7fe72abab41a5263888f1a72b50f0`; 204 slabs; bytes e headers exatamente pressure seguidos de single |
| Grade observada | 1440×721; cilíndrica equidistante `iproj=0`; `SWCORNER`; 0,25°; cobertura 180° × 360°; timestamp 2014-09-10_00:00:00 |
| Estrutura | 4-byte big-endian leading/trailing markers coerentes; version 5; data, field, units, xlvl, dimensões, projeção, flag lógica, `nx*ny*4` bytes por slab e EOF exato: PASS; seis casos sintéticos aceitaram o válido e rejeitaram version/marker/slab/EOF inválidos |
| Idempotência | reexecução retornou intermediates/combined `unchanged`, preservou logs canônicos de sucesso e não sobrescreveu conteúdo divergente |
| Git hygiene | GRIBs, intermediates, logs e manifestos ignorados e não rastreados: PASS |
| Limite | não executou `init_atmosphere_model` meteorológico e não gerou `init.nc` |

### Inventário GRIB1 e correspondência com `Vtable.ECMWF`

Cada linha abaixo representa um tuple semântico único. O validador exige uma e
somente uma entrada da Vtable por mensagem; portanto a coluna de níveis também
explica a identificação de todas as 204 mensagens, e não apenas sua contagem.

| Fonte | Parâmetro | Level type / níveis observados | Entrada/campo Vtable | Mensagens |
|---|---:|---|---|---:|
| pressure | 129 | 100; 37 níveis de 1 a 1000 hPa aprovados | `GEOPT`; convertido upstream para `HGT` | 37 |
| pressure | 157 | 100; mesmos 37 níveis | `RH` | 37 |
| pressure | 130 | 100; mesmos 37 níveis | `TT` | 37 |
| pressure | 131 | 100; mesmos 37 níveis | `UU` | 37 |
| pressure | 132 | 100; mesmos 37 níveis | `VV` | 37 |
| single | 165, 166, 167, 168 | 1; superfície 0/0 | `UU`, `VV`, `TT`, `DEWPT`; `DEWPT` + `TT` vira `RH` | 4 |
| single | 129, 134, 151, 172, 235 | 1; superfície 0/0 | `SOILGEO`, `PSFC`, `PMSL`, `LANDSEA`, `SKINTEMP`; `SOILGEO` vira `SOILHGT` | 5 |
| single | 31, 141 | 1; superfície 0/0 | `SEAICE`, `SNOW_EC`; snow vira `SNOW` | 2 |
| single | 139, 170, 183, 236 | 112; 0/7, 7/28, 28/100, 100/255 | `ST000007`, `ST007028`, `ST028100`, `ST100289` | 4 |
| single | 39, 40, 41, 42 | 112; 0/7, 7/28, 28/100, 100/255 | `SM000007`, `SM007028`, `SM028100`, `SM100289` | 4 |

O valor GRIB1 255 da última camada é a codificação observada; a linha
upstream nomeia o campo como camada 100–289 cm. Isso foi validado contra a
request e a própria tabela, não reinterpretado por uma lista inventada.

### Inventário final do combined

| Campo | Slabs / função |
|---|---|
| `HGT` | 37; altura geopotencial 3-D para interpolação vertical |
| `TT`, `UU`, `VV`, `RH` | 38 cada; 37 isobáricos + um nível próximo à superfície |
| `PSFC`, `PMSL`, `SOILHGT` | 1 cada; pressão de superfície, MSLP e terreno/geopotencial de superfície |
| `LANDSEA`, `SKINTEMP`, `SEAICE`, `SNOW` | 1 cada; máscara, skin/SST input, gelo marinho e neve |
| `ST000007`, `ST007028`, `ST028100`, `ST100289` | 1 cada; quatro temperaturas de solo |
| `SM000007`, `SM007028`, `SM028100`, `SM100289` | 1 cada; quatro umidades de solo |

As conversões `GEOPT→HGT`, `DEWPT→RH`, `SOILGEO→SOILHGT` e
`SNOW_EC→SNOW` substituem os campos fonte. Nenhum campo adicional fora desse
inventário foi produzido.

### Gates do ciclo 0011

| Gate | Estado |
|---|---|
| ERA5 raw regression | PASS |
| WPS tools / version / linkage | PASS |
| `g1print` pressure semantic inventory | PASS, 185 |
| `g1print` single semantic inventory | PASS, 19 |
| GRIB ↔ requests ↔ Vtable | PASS, 204 correspondências únicas |
| Pressure ungrib / explicit log success | PASS |
| Single ungrib / explicit log success | PASS |
| WPS intermediate structural parser | PASS; cinco corrupções rejeitadas no teste negativo |
| Combined exact concatenation | PASS |
| Required ERA5 field inventory | PASS |
| Generated artifact Git hygiene | PASS |
| Meteorological `init_atmosphere` / `init.nc` | NOT RUN, ciclo 0012 |

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
