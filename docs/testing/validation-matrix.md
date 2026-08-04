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

Última revisão: **2026-08-04**.

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

## Componentes futuros

| Componente | Upstream test | Smoke test | Integration test | Status | Evidência |
|---|---|---|---|---|---|
| PIO2 | Planejado: suite oficial da versão aprovada | Planejado: exemplo mínimo do upstream | Planejado: MPI + backend(s) aprovado(s), incluindo PnetCDF/netCDF quando aplicável | Não implementado; versão a decidir | [[../references/versions.lock|versions.lock.md]] |
| METIS | Planejado: suite ou testes oficiais disponíveis para a release | Planejado: executar particionamento mínimo de um grafo conhecido | Planejado: verificar consumo pelo build/fluxo do MPAS aprovado | Não implementado; versão a decidir | [[../references/versions.lock|versions.lock.md]] |
| WPS/ungrib | Planejado: testes oficiais disponíveis para a release | Planejado: executar `ungrib` sobre amostra pequena e controlada | Planejado: transformar campos ERA5 aprovados para o formato consumido pelo `init_atmosphere` | Não implementado; versão a decidir | [[../project/requirements|REQ-PRE-001]] |
| MPAS `init_atmosphere` | Planejado: testes upstream disponíveis para a release | Planejado: validar inicialização mínima na mesh aprovada | Planejado: WPS/ERA5 + mesh → `static.nc`, `init.nc` e LBC quando aplicável | Não implementado; versão a decidir | [[../project/requirements|REQ-MPAS-001]] |
| MPAS `atmosphere` | Planejado: testes upstream disponíveis para a release | Planejado: integração curta e determinística do caso aprovado | Planejado: ler artefatos do `init_atmosphere` e produzir saída MPAS | Não implementado; versão a decidir | [[../project/requirements|REQ-MPAS-002]] |
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
