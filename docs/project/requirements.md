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
| Versão MPAS | MPAS-Model 8.4.1; `init_atmosphere_model` e `atmosphere_model` compilados e validados estruturalmente | [[../decisions/0004-wps-mpas-version-and-layout|ADR 0004]] |
| Layout de instalação | `/opt/mpas` para bibliotecas, `/opt/wps-*` para WPS e `/opt/mpas-model-*` para o modelo | [[../decisions/0004-wps-mpas-version-and-layout|ADR 0004]] |
| Primeira mesh | x1.10242 oficial, global quasi-uniforme, ~240 km e 10.242 células | [[../decisions/0005-first-mesh-baseline|ADR 0005]] |
| Primeiro particionamento | `part.4` gerado localmente com METIS 5.1.0; quatro partições corresponderam aos quatro ranks do init real e serão reutilizadas pela primeira previsão | [[../decisions/0005-first-mesh-baseline|ADR 0005]] |
| Primeiro caso descrito publicamente | global e de baixa resolução; mesh, geografia, static, ERA5 bruto, WPS intermediate e `init.nc` preparados; previsão pendente | [[../cases/first-global-240km|Primeiro caso]] |
| Política da mesh | entrada científica reproduzivelmente adquirida em `data/`, fora da imagem e do Git | [`.gitignore`](../../.gitignore) e [`fetch-mesh.sh`](../../scripts/data/fetch-mesh.sh) |
| Baseline ERA5 | 2014-09-10 00 UTC, global, 5 variáveis em 37 níveis e 19 single-level, GRIB1 real | [[../decisions/0007-first-era5-baseline|ADR 0007]] |
| Conversão ERA5 | `Vtable.ECMWF` upstream WPS 4.7.0, pressure/single separados e WPS intermediate combinado version 5 | [[../testing/validation-matrix|matriz de validação]] |

Essas decisões não autorizam alterações automáticas. Troca de MPI, estratégia
serial/paralela do HDF5, mudanças nas versões de dependências — inclusive
MPAS/WPS —, substituição da primeira mesh, recorte ERA5 ou mudança do domínio
global aprovado continuam sujeitos aos gates do [`AGENTS.md`](../../AGENTS.md).

## Itens deliberadamente ainda não decididos

- duração, timestep, física e demais parâmetros ainda não fixados da primeira previsão;
- eventual experimento com METIS 5.2.1 + GKlib fixada ou PT-Scotch,
  conforme [[future-experiments|future-experiments.md]];
- eventual necessidade futura de HDF5/netCDF paralelo e
  `PIO_IOTYPE_NETCDF4P`, fora do primeiro caso;
- critérios quantitativos finais de validação física.

Esses itens devem permanecer como **a decidir** até que pesquisa oficial,
proposta e decisão do usuário sejam registradas.

## Fora do escopo do ciclo 0001

O ciclo 0001 cria somente governança, rastreabilidade, documentação e material
de aprendizado. Ele não implementa PnetCDF, não muda dependências, não altera a
arquitetura científica e não executa commit ou push.
