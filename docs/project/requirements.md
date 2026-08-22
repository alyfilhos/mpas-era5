# Requisitos do projeto MPAS-ERA5

## Objetivo deste documento

Este documento transforma o plano técnico do projeto em requisitos
rastreáveis. Ele separa o que pertence ao escopo original das decisões de
implementação tomadas depois. Essa distinção evita tratar uma escolha atual
como se fosse uma necessidade científica permanente.

O escopo original determina **o que** o projeto deve entregar. As decisões do
projeto determinam **como** uma versão concreta da solução será construída.
Uma decisão pode mudar somente pelo fluxo descrito em
[[development-workflow|development-workflow.md]] e, quando for arquitetural,
por um ADR em `docs/decisions/`.

## Requisitos originais

### Ambiente e stack de compilação

- **REQ-ENV-001 — Ambiente GNU + MPI:** fornecer um ambiente Linux com
  compiladores GNU para C e Fortran e uma implementação MPI, apropriado para
  compilar e executar a stack científica e o MPAS.
- **REQ-STACK-001 — zlib:** incluir zlib como camada de compressão requerida
  pelas bibliotecas posteriores.
- **REQ-STACK-002 — HDF5:** incluir HDF5 compatível com zlib e com a estratégia
  de I/O aprovada para o projeto.
- **REQ-STACK-003 — netCDF-C:** incluir a interface C do netCDF, integrada ao
  HDF5 adotado.
- **REQ-STACK-004 — netCDF-Fortran:** incluir a interface Fortran do netCDF,
  integrada ao netCDF-C adotado.
- **REQ-STACK-005 — PnetCDF:** incluir Parallel-NetCDF depois de pesquisa
  oficial, proposta e aprovação de versão. A implementação não faz parte do
  ciclo 0001.
- **REQ-STACK-006 — PIO2:** incluir ParallelIO/PIO2 depois da validação de suas
  dependências e da aprovação de versão. A implementação não faz parte do
  ciclo 0001.
- **REQ-STACK-007 — METIS:** incluir METIS na versão e configuração aprovadas
  para o MPAS. A implementação não faz parte do ciclo 0001.

### Pré-processamento, modelo e dados

- **REQ-PRE-001 — WPS/ungrib:** compilar e configurar a parte necessária do
  WPS para decodificar os campos meteorológicos usados no fluxo do MPAS.
- **REQ-MPAS-001 — init_atmosphere:** compilar e executar o núcleo
  `init_atmosphere` para gerar os arquivos de inicialização do caso.
- **REQ-MPAS-002 — atmosphere:** compilar e executar o núcleo atmosférico do
  MPAS.
- **REQ-DATA-001 — ERA5:** obter e preparar dados ERA5 com período, área,
  níveis e variáveis formalmente aprovados. Credenciais do CDS e os dados
  grandes não devem ser versionados.
- **REQ-MESH-001 — Primeira malha:** usar uma malha pública de baixa resolução
  como ponto de partida. A malha exata e a estratégia do primeiro caso exigem
  decisão do usuário.

### Artefatos, execução e validação

- **REQ-CASE-001 — `static.nc`:** produzir e validar o arquivo de campos
  estáticos requerido pelo primeiro caso.
- **REQ-CASE-002 — `init.nc`:** produzir e validar o estado inicial do modelo.
- **REQ-CASE-003 — LBC quando aplicável:** produzir condições laterais de
  contorno somente se a configuração aprovada for de área limitada e exigir
  LBC. Um caso global não deve receber artificialmente essa exigência.
- **REQ-RUN-001 — Execução:** executar o caso aprovado com configuração,
  comandos, entradas, saídas e recursos computacionais rastreáveis.
- **REQ-VAL-001 — Validação física:** avaliar não apenas o término do programa,
  mas também a coerência física e numérica dos campos e diagnósticos definidos
  para o caso.
- **REQ-DOC-001 — Documentação final:** consolidar procedimento reproduzível,
  fontes, versões, decisões, resultados de testes, limitações e material de
  aprendizado.

## Decisões posteriores já materializadas no repositório

Estas escolhas são implementações atuais, não requisitos originais imutáveis:

| Assunto | Decisão materializada | Evidência atual |
|---|---|---|
| Isolamento do ambiente | Docker | [`Dockerfile`](../../Dockerfile) |
| Linux da imagem | Ubuntu 24.04 | `FROM ubuntu:24.04` no `Dockerfile` |
| Compiladores | GCC e GFortran fornecidos pelos pacotes Ubuntu | `build-essential` e `gfortran` no `Dockerfile` |
| MPI | OpenMPI fornecido pelos pacotes Ubuntu | `openmpi-bin` e `libopenmpi-dev` no `Dockerfile` |
| Prefixo científico | `/opt/mpas` | `MPAS_PREFIX` no `Dockerfile` |
| Bibliotecas adotadas até agora | zlib 1.3.2, HDF5 1.14.6, netCDF-C 4.10.1, netCDF-Fortran 4.6.3, PnetCDF 1.15.0, PIO 2.7.0 e METIS 5.1.0 | argumentos de build no `Dockerfile` |
| Arquitetura de I/O inicial | HDF5/netCDF serial preservado; PIO usa PnetCDF/MPI-IO para o I/O paralelo padrão do MPAS | [[../decisions/0002-pio2-pnetcdf-with-serial-netcdf|ADR 0002]] |
| Particionamento inicial | METIS 5.1.0 serial e externo; `gpmetis` pré-computa `graph.info.part.N` | [[../decisions/0003-metis-5.1.0-partitioning-baseline|ADR 0003]] |
| Pré-processamento GRIB inicial | WPS 4.7.0 separado em `/opt/wps-*`; `ungrib.exe` e `g1print.exe`, GNU serial, `--nowrf`, bibliotecas GRIB2 internas e `Vtable.ECMWF` upstream validada para a baseline ERA5 | [[../decisions/0004-wps-mpas-version-and-layout|ADR 0004]] e [[../testing/validation-matrix|matriz]] |
| Versão MPAS | MPAS-Model 8.4.1; `init_atmosphere_model` validado funcionalmente para static/init e `atmosphere_model` para a primeira hora | [[../decisions/0004-wps-mpas-version-and-layout|ADR 0004]] e [[../testing/validation-matrix|matriz]] |
| Layout de instalação | `/opt/mpas` para bibliotecas, `/opt/wps-*` para WPS e `/opt/mpas-model-*` para o modelo | [[../decisions/0004-wps-mpas-version-and-layout|ADR 0004]] |
| Primeira mesh | x1.10242 oficial, global quasi-uniforme, ~240 km e 10.242 células | [[../decisions/0005-first-mesh-baseline|ADR 0005]] |
| Primeiro particionamento | `part.4` gerado localmente com METIS 5.1.0; quatro partições corresponderam aos quatro ranks do init e da primeira integração reais | [[../decisions/0005-first-mesh-baseline|ADR 0005]] |
| Primeiro caso descrito publicamente | global e de baixa resolução; pipeline até `init.nc` e primeira integração de 1 hora com history/diagnostics validados | [[../cases/first-global-240km|Primeiro caso]] |
| Primeira previsão funcional | cold start em 2014-09-10 00 UTC; 1 hora; `dt=1200 s`; 4 ranks/`part.4`; `mesoscale_reference`; Noah; LBC/restart/SST update desligados; radiação a cada hora | [[../cases/first-global-240km|Primeiro caso]] e [[../testing/validation-matrix|matriz]] |
| Política da mesh | entrada científica reproduzivelmente adquirida em `data/`, fora da imagem e do Git | [`.gitignore`](../../.gitignore) e [`fetch-mesh.sh`](../../scripts/data/fetch-mesh.sh) |
| Baseline ERA5 | 2014-09-10 00 UTC, global, 5 variáveis em 37 níveis e 19 single-level, GRIB1 real | [[../decisions/0007-first-era5-baseline|ADR 0007]] |
| Conversão ERA5 | `Vtable.ECMWF` upstream WPS 4.7.0, pressure/single separados e WPS intermediate combinado version 5 | [[../testing/validation-matrix|matriz de validação]] |

Essas decisões não autorizam alterações automáticas. Troca de MPI, estratégia
serial/paralela do HDF5, mudanças nas versões de dependências — inclusive
MPAS/WPS —, substituição da primeira mesh, recorte ERA5 ou mudança do domínio
global aprovado continuam sujeitos aos gates do [`AGENTS.md`](../../AGENTS.md).

## Itens deliberadamente ainda não decididos

- eventual experimento com METIS 5.2.1 + GKlib fixada ou PT-Scotch,
  conforme [[future-experiments|future-experiments.md]];
- eventual necessidade futura de HDF5/netCDF paralelo e
  `PIO_IOTYPE_NETCDF4P`, fora do primeiro caso;
- desenho futuro de forecast verification, incluindo verdade de referência,
  métricas de skill e tolerâncias sustentadas; o ciclo 0014 concluiu sanity
  científico, não verificação meteorológica.

Esses itens devem permanecer como **a decidir** até que pesquisa oficial,
proposta e decisão do usuário sejam registradas.

## Fora do escopo do ciclo 0001

O ciclo 0001 cria somente governança, rastreabilidade, documentação e material
de aprendizado. Ele não implementa PnetCDF, não muda dependências, não altera a
arquitetura científica e não executa commit ou push.

## Materialização de REQ-VAL-001 no ciclo 0014

| Item | Estado | Evidência |
|---|---|---|
| Integridade dos quatro NetCDFs | PASS | hashes do manifesto, CDF-2, timestamps/dimensões e 0 NaN/Inf/missing |
| Estabilidade e sanity físico | PASS | pressão/densidade/espessura/temperatura positivas; prognósticos evoluíram |
| Diagnóstico de `q2` | REPORT-ONLY concluído | 11 células localizadas; fórmula/call path e ausência de clamp documentados |
| Massa de ar seco | REPORT-ONLY | `sum(rho*areaCell*diff(zgrid))`, sem tolerância inventada |
| Água | REPORT-ONLY | inventário WSM6 + precipitação, orçamento explicitamente não fechado |
| Forecast skill | NOT_EVALUATED | não há observação nem ERA5 de 01 UTC |
| Spin-up | INSUFFICIENT_TEMPORAL_WINDOW | somente t0 e t1 |

A análise adota container próprio por [[../decisions/0009-separate-analysis-container|ADR 0009]].
Isso não altera a decisão, a build ou as versões da stack MPAS/WPS. A execução
normativa e seus limites estão em
[[../validation/first-atmosphere-run|first-atmosphere-run.md]].

## Rastreabilidade final do escopo original

Status permitidos nesta auditoria:

- `SATISFIED`: requisito demonstrado por evidência executada e rastreável;
- `SATISFIED_WITH_LIMITATION`: entrega demonstrada, com limite de evidência
  ou alcance que não bloqueia o objetivo original;
- `NOT_APPLICABLE`: condição do requisito não ocorre na baseline aprovada;
- `FUTURE_EXTENSION`: hipótese fora do escopo base (nenhum requisito original
  recebeu este status).

| ID | Requisito | Status | Evidência | Limitação | Ciclo |
|---|---|---|---|---|---|
| REQ-ENV-001 | ambiente Linux GNU + MPI | SATISFIED | imagem científica; versões GNU/OpenMPI e compilação C/Fortran em [`core-libraries.sh`](../../scripts/validate/core-libraries.sh); execução MPI real | pacotes APT não possuem lock/digest completo | baseline, 0002–0013, 0015 |
| REQ-STACK-001 | zlib | SATISFIED_WITH_LIMITATION | 1.3.2 instalada; compressão/descompressão e link em `/opt/mpas` passam | suíte upstream histórica não executada/preservada | baseline + 0015 |
| REQ-STACK-002 | HDF5 | SATISFIED_WITH_LIMITATION | 1.14.6 serial; dataset DEFLATE criado, escrito e relido; link com zlib do prefixo | suíte upstream e checksum do archive não preservados | baseline + 0015 |
| REQ-STACK-003 | netCDF-C | SATISFIED_WITH_LIMITATION | 4.10.1; NetCDF-4/deflate criado e relido sobre HDF5/zlib; integração MPAS | `make check` está na receita, mas o log histórico não foi preservado | baseline + 0015 |
| REQ-STACK-004 | netCDF-Fortran | SATISFIED_WITH_LIMITATION | 4.6.3; módulo Fortran cria/relê NetCDF-4/deflate e liga netCDF-C | `make check` está na receita, mas o log histórico não foi preservado | baseline + 0015 |
| REQ-STACK-005 | PnetCDF | SATISFIED | `make check`/`ptest` e F90 CDF-5 coletivo em 4 ranks via MPI-IO | `ptests` extensa não executada; diagnóstico OMPIO documentado | 0002 |
| REQ-STACK-006 | PIO2 | SATISFIED | PIO 2.7.0, 109/109 CTest e PnetCDF/CDF-2 em 4 ranks com OMPIO/ROMIO | NetCDF4P não compilado por decisão da stack serial | 0003 |
| REQ-STACK-007 | METIS | SATISFIED | 5.1.0, `graphchk`/`gpmetis`, fixture e partição x1.10242 válida/consumida | release sem suíte formal; não mede performance | 0004, 0008, 0012–0013 |
| REQ-PRE-001 | WPS/ungrib | SATISFIED | WPS 4.7.0, `g1print`, Vtable cruzada com 204 GRIBs e intermediate version 5 | Vtable validada para esta baseline ERA5 | 0005, 0011 |
| REQ-MPAS-001 | `init_atmosphere` | SATISFIED | build/smoke, geração real de static e init meteorológico | static baseline não contém campos Noah-MP | 0006, 0009, 0012 |
| REQ-MPAS-002 | `atmosphere` | SATISFIED | build/smoke e integração de 1 h em 4 ranks com history/diag | execução curta; sem skill/escalabilidade | 0007, 0013 |
| REQ-DATA-001 | ERA5 | SATISFIED | requests aprovadas, CDSAPI isolado, probes, 185+19 GRIBs e conversão | um único instante; credencial/dados permanecem locais | 0010–0012 |
| REQ-MESH-001 | primeira malha pública | SATISFIED | x1.10242 oficial, 10.242 células, grafo e `part.4` validados/consumidos | ~240 km e 4 ranks não constituem benchmark | 0008–0013 |
| REQ-CASE-001 | `static.nc` | SATISFIED | CDF-2 gerado em 1 task; campos, ranges, log e hash validados | `config_noahmp_static=false` | 0009 |
| REQ-CASE-002 | `init.nc` | SATISFIED | CDF-2, 55 níveis, 4 soil, 4 ranks, estrutura/física/proveniência PASS | seis `qv` negativos pequenos, limitados e documentados | 0012 |
| REQ-CASE-003 | LBC quando aplicável | NOT_APPLICABLE | domínio global aprovado, `config_apply_lbcs=false` e nenhum LBC artificial | será requisito somente de eventual caso limitado | 0012–0013 |
| REQ-RUN-001 | execução rastreável | SATISFIED | configuração, comando, inputs/outputs, 4 ranks, manifestos, 1 h e idempotência | uma hora e SST fixa | 0013 |
| REQ-VAL-001 | validação física/numérica | SATISFIED_WITH_LIMITATION | integridade, estabilidade e sanity PASS; massa/água/`q2` classificados; figuras | skill não avaliado; spin-up insuficiente; budgets não fechados | 0014 |
| REQ-DOC-001 | documentação final | SATISFIED | README público, guia end-to-end, relatório, grafo, matriz, fontes, learning note e portfólio | documentação não substitui dados locais nem novos experimentos | 0015 |

Resumo:

| Status | Quantidade |
|---|---:|
| SATISFIED | 13 |
| SATISFIED_WITH_LIMITATION | 5 |
| NOT_APPLICABLE | 1 |
| FUTURE_EXTENSION | 0 |

### O escopo original do projeto foi concluído?

**Sim.** Cada requisito original foi satisfeito com evidência, satisfeito com
uma limitação explicitamente não bloqueante, ou corretamente considerado não
aplicável ao caso global. Não há blocker escondido como “experimento futuro”.

`PROJECT_BASE_STATUS = COMPLETE` significa escopo técnico aprovado concluído.
Permanece ao lado de `forecast_skill=NOT_EVALUATED` e
`spinup=INSUFFICIENT_TEMPORAL_WINDOW`.
