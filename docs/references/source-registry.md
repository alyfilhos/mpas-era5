# Registro de fontes

## Finalidade

Este registro documenta de onde vêm requisitos, fatos técnicos, versões e
orientações de troubleshooting. Uma fonte deve ser classificada antes de ser
usada; autoridade e utilidade não são a mesma coisa.

Última revisão deste registro: **2026-08-15**.

## Classes de fonte

| Classe | Uso permitido | Limite |
|---|---|---|
| Requisito original | definir objetivo, restrições e entregáveis do projeto | não prova compatibilidade técnica nem informa necessariamente uma versão |
| Documentação oficial | definir interfaces, opções de build, requisitos e procedimentos mantidos pelo projeto upstream | conferir se a página corresponde à versão adotada |
| Release oficial | fixar artefato, versão, checksum e notas de release | não substitui a documentação de uso e compatibilidade |
| Fonte secundária | fornecer contexto, comparação ou explicação | não é autoridade primária para arquitetura ou versões |
| Fórum/issue para troubleshooting | investigar sintomas e hipóteses de falha | não deve decidir arquitetura ou versão; a solução precisa ser validada localmente e, se possível, confirmada em fonte oficial |

## Fontes registradas

### Requisitos originais

| ID | Fonte | Escopo | Verificação |
|---|---|---|---|
| REQ-001 | briefing técnico do responsável pelo projeto, transcrito em [[../project/requirements|requirements.md]] | plano completo GNU/MPI → stack → MPAS/WPS → ERA5 → primeiro caso → validação/documentação | conferido durante o ciclo 0001 em 2026-08-04; não possui URL pública |
| REQ-002 | [`README.md`](../../README.md) no histórico Git | objetivo educacional, primeiro caso global de baixa resolução e roadmap inicial | arquivo e histórico completo conferidos em 2026-08-04 |
| REQ-003 | [`AGENTS.md`](../../AGENTS.md) | governança, gates de decisão, testes, documentação, commit e segurança | arquivo local conferido integralmente em 2026-08-04 |

### Documentação oficial

| ID | Projeto/versão | Fonte oficial | Finalidade e resultado | Verificação |
|---|---|---|---|---|
| DOC-WPS-001 | WPS | [repositório oficial wrf-model/WPS](https://github.com/wrf-model/WPS) | identidade do projeto, tags e histórico oficial | consultado em 2026-08-05 |
| DOC-WPS-002 | WPS 4.7.0 | [`README` da tag](https://github.com/wrf-model/WPS/blob/v4.7.0/README) | versão 4.7.0, papéis de geogrid/ungrib/metgrid, execução serial do ungrib, GRIB1/GRIB2, Vtables e build básico | lido no source da própria tag em 2026-08-05 |
| DOC-WPS-003 | WPS 4.7.0 | [`configure` da tag](https://github.com/wrf-model/WPS/blob/v4.7.0/configure) | `--nowrf`, `--build-grib2-libs`, requisitos de WRF e diretório GRIB2 interno | lido integralmente e exercitado em 2026-08-05 |
| DOC-WPS-004 | WPS 4.7.0 | [`compile` da tag](https://github.com/wrf-model/WPS/blob/v4.7.0/compile) | shebang csh, targets aceitos e confirmação de `./compile ungrib` e `./compile g1print` | lido integralmente; `ungrib` exercitado em 2026-08-05 e `g1print` em 2026-08-14 |
| DOC-WPS-005 | WPS 4.7.0 | [`arch/Config.pl`](https://github.com/wrf-model/WPS/blob/v4.7.0/arch/Config.pl) e [`arch/configure.defaults`](https://github.com/wrf-model/WPS/blob/v4.7.0/arch/configure.defaults) | geração do menu, plataforma Linux x86_64/GFortran serial, compiladores e flags | inspecionados na tag e usados na seleção reproduzível em 2026-08-05 |
| DOC-WPS-006 | WPS 4.7.0 | `external/Makefile`, `arch/preamble` e `ungrib/Makefile` contidos no archive da tag | versões e instalação privada de zlib/libpng/JasPer, flags GRIB2 e alvo ungrib | inspecionados no artefato adotado em 2026-08-05 |
| DOC-MPAS-004 | MPAS-Model 8.4.1 | [`README.md` da tag](https://github.com/MPAS-Dev/MPAS-Model/blob/v8.4.1/README.md) | heading `MPAS-v8.4.1` no próprio source da tag | lido no clone verificado em 2026-08-05 |
| DOC-MPAS-005 | MPAS-Model 8.4.1 | [`Makefile` da tag](https://github.com/MPAS-Dev/MPAS-Model/blob/v8.4.1/Makefile), [`build_options.mk` do init](https://github.com/MPAS-Dev/MPAS-Model/blob/v8.4.1/src/core_init_atmosphere/build_options.mk) e [`setup_run_dir.py`](https://github.com/MPAS-Dev/MPAS-Model/blob/v8.4.1/testing_and_setup/atmosphere/setup_run_dir.py) | target GNU, wrappers MPI, seleção do core/executável, precisão default, descoberta de PIO2/NETCDF/PNETCDF/PIO, ESMF e artefatos/defaults | arquivos da tag clonada lidos e exercitados em 2026-08-05 |
| DOC-MPAS-006 | MPAS oficial | [Building MPAS](https://www2.mmm.ucar.edu/projects/mpas/site/documentation/users_guide/building_mpas.html) | visão geral do build, cores, targets e variáveis de dependências | consultada em 2026-08-05; quando o texto geral diverge da 8.4.1, prevalece o source exato da tag |
| DOC-MPAS-007 | MPAS oficial | [Running MPAS](https://www2.mmm.ucar.edu/projects/mpas/site/documentation/users_guide/running.html) | papel do `init_atmosphere`, modos de inicialização e necessidade de mesh/entradas | consultada em 2026-08-05; fundamenta o limite funcional deste ciclo |
| DOC-MPAS-008 | MPAS oficial | [Configuring I/O](https://www2.mmm.ucar.edu/projects/mpas/site/documentation/users_guide/configuring_io.html) | distinção entre namelist, streams e arquivos default | consultada em 2026-08-05 |
| DOC-MPAS-009 | MPAS-Model 8.4.1 | [`build_options.mk` do atmosphere](https://github.com/MPAS-Dev/MPAS-Model/blob/v8.4.1/src/core_atmosphere/build_options.mk), [`Externals.cfg`](https://github.com/MPAS-Dev/MPAS-Model/blob/v8.4.1/src/core_atmosphere/Externals.cfg) e [Makefile da física](https://github.com/MPAS-Dev/MPAS-Model/blob/v8.4.1/src/core_atmosphere/physics/Makefile) | `CORE=atmosphere`, executável, defaults, MMM-physics, UGWP, manage_externals e ordem das lookup tables | arquivos da tag lidos e exercitados em 2026-08-05 |
| DOC-MPAS-010 | MPAS-Model 8.4.1 | [`checkout_data_files.sh`](https://github.com/MPAS-Dev/MPAS-Model/blob/v8.4.1/src/core_atmosphere/physics/checkout_data_files.sh) | `mpas_vers="8.2"`, leitura de `COMPATIBILITY`, localização dos 16 arquivos e fallback de download | lido integralmente e exercitado offline em 2026-08-05 |
| DOC-MPAS-DATA-001 | MPAS-Data v8.2 | [árvore oficial de lookup tables](https://github.com/MPAS-Dev/MPAS-Data/tree/v8.2/atmosphere/physics_wrf/files) | `COMPATIBILITY` declara 8.0/8.2 e a tag fornece os 16 arquivos esperados pelo source MPAS 8.4.1 | tag e conteúdo conferidos em 2026-08-05 |
| DOC-PNETCDF-001 | PnetCDF | [repositório oficial](https://github.com/Parallel-NetCDF/PnetCDF) | identidade do projeto, release atual, formatos e interfaces | consultado em 2026-08-04 |
| DOC-PNETCDF-002 | PnetCDF | [página oficial](https://parallel-netcdf.github.io/) | relação entre PnetCDF, CDF e MPI-IO | consultada em 2026-08-04 |
| DOC-PNETCDF-003 | PnetCDF 1.15.0 | `INSTALL` dentro do tarball oficial `pnetcdf-1.15.0.tar.gz` | requisitos MPI/m4, wrappers, defaults Fortran, `make check`, `make ptest`, `make ptests` e `TESTMPIRUN` | 381 linhas lidas integralmente em 2026-08-04; corresponde ao artefato, não à branch master |
| DOC-PNETCDF-004 | PnetCDF 1.15.0 | `./configure --help` gerado pelo tarball oficial | flags disponíveis e recursos opcionais; confirmou `--disable-gio`, shared/static e ausência de flags redundantes | executado em 2026-08-04 |
| DOC-OPENMPI-001 | OpenMPI | [Modular Component Architecture](https://docs.open-mpi.org/en/main/mca.html) | mecanismo `--mca framework component` para selecionar componentes em runtime | consultado em 2026-08-04; disponibilidade local confirmada por `ompi_info` 4.1.6 |
| DOC-PIO-001 | PIO | [repositório oficial NCAR/ParallelIO](https://github.com/NCAR/ParallelIO) | identidade do projeto, releases, interfaces C/Fortran e backends NetCDF/PnetCDF | consultado em 2026-08-04 |
| DOC-PIO-002 | PIO 2.7.0 | [`README.md` da tag](https://github.com/NCAR/ParallelIO/blob/pio2_7_0/README.md) | requisitos declarados, Autotools, CMake, NetCDF 4.6.1+, PnetCDF 1.9.0+ e afirmação de NetCDF-C com MPI | lido na própria tag em 2026-08-04 |
| DOC-PIO-003 | PIO 2.7.0 | [`doc/source/Installing.txt` da tag](https://github.com/NCAR/ParallelIO/blob/pio2_7_0/doc/source/Installing.txt) | instalação, wrappers MPI, testes, GPTL/timing, CMake e formulação de NetCDF paralelo como ideal | lido na própria tag em 2026-08-04 |
| DOC-PIO-004 | PIO 2.7.0 | [`CMakeLists.txt` da tag](https://github.com/NCAR/ParallelIO/blob/pio2_7_0/CMakeLists.txt) | opções, descoberta de dependências, testes de recursos, auxiliares CMake e condicionais de compilação | inspecionado e exercitado em 2026-08-04 |
| DOC-PIO-005 | PIO 2.7.0 | [`cmake/TryNetCDF_PARALLEL.c`](https://github.com/NCAR/ParallelIO/blob/pio2_7_0/cmake/TryNetCDF_PARALLEL.c) | teste explícito de `NC_HAS_PARALLEL`; não chama `nc_create_par` ou `nc_open_par` | inspecionado em 2026-08-04 |
| DOC-PIO-006 | PIO 2.7.0 | [`src/clib/pio_file.c`](https://github.com/NCAR/ParallelIO/blob/pio2_7_0/src/clib/pio_file.c), [`pio_nc.c`](https://github.com/NCAR/ParallelIO/blob/pio2_7_0/src/clib/pio_nc.c) e [`pio_nc4.c`](https://github.com/NCAR/ParallelIO/blob/pio2_7_0/src/clib/pio_nc4.c) | despacho dos IOTYPEs PnetCDF, NetCDF clássico e NetCDF-4; blocos NetCDF-4 protegidos por `_NETCDF4` | inspecionados em 2026-08-04; comportamento confirmado pelo smoke em runtime |
| DOC-MPAS-001 | MPAS-Atmosphere 8.4.0 | [User's Guide oficial](https://www2.mmm.ucar.edu/projects/mpas/mpas_atmosphere_users_guide_8.4.0.pdf) | `USE_PIO2=true`, variáveis `NETCDF`/`PNETCDF`/`PIO`, PIO 2.x, `PIO_ENABLE_TIMING=OFF`, `io_type` padrão e formatos suportados | consultado em 2026-08-04; sustenta [[../decisions/0002-pio2-pnetcdf-with-serial-netcdf|ADR 0002]] |
| DOC-METIS-001 | METIS histórico | [página first-party de George Karypis](https://karypis.github.io/glaros/software/metis/overview.html) | identidade, natureza serial, release estável histórica 5.1.0, manual e link de download | consultada em 2026-08-05; a página continua em 5.1.0 |
| DOC-METIS-002 | METIS 5.1.0 | [manual oficial](https://karypis.github.io/glaros/files/sw/metis/manual.pdf) | formato do grafo, arquivo de partição, algoritmo multilevel e opções `gpmetis` `-minconn`, `-contig` e `-niter` | manual versão 5.1.0 consultado em 2026-08-05 |
| DOC-METIS-003 | METIS 5.1.0 | `Install.txt` e `BUILD.txt` contidos no tarball first-party | requisitos C99/GNU make/CMake, `make config`, prefixo, static/shared e larguras | arquivos do artefato adotado lidos em 2026-08-05 |
| DOC-METIS-004 | METIS 5.1.0 | `Makefile`, `CMakeLists.txt`, `include/metis.h`, `programs/CMakeLists.txt` e `GKlib/` contidos no tarball | defaults 32/32, GKlib incluída, biblioteca, executáveis e ausência de registro CTest formal | arquivos do artefato adotado inspecionados em 2026-08-05 |
| DOC-METIS-005 | METIS 5.2.1 | [repositório moderno oficial](https://github.com/KarypisLab/METIS), [release v5.2.1](https://github.com/KarypisLab/METIS/releases/tag/v5.2.1) e [README da tag](https://github.com/KarypisLab/METIS/blob/v5.2.1/README.md) | existência da linha moderna, GKlib externa, configuração por `gklib_path` e preservação de `gpmetis` | consultados em 2026-08-05 apenas para alternativa futura; não implementados |
| DOC-MPAS-002 | MPAS atual | [Preparing Meshes — Graph Partitioning with METIS](https://www2.mmm.ucar.edu/projects/mpas/site/documentation/users_guide/preparing_meshes.html) | fluxo offline `gpmetis -minconn -contig -niter=200 graph.info N`, arquivo `.part.N`, correspondência com tasks MPI e coexistência com particionamento online | consultada em 2026-08-05; sustenta [[../decisions/0003-metis-5.1.0-partitioning-baseline|ADR 0003]] |
| DOC-MPAS-003 | MPAS atual | [Building MPAS — PT-Scotch](https://www2.mmm.ucar.edu/projects/mpas/site/documentation/users_guide/building_mpas.html) | particionamento online desde v8.4.0, PT-Scotch mínimo 7.0.8, build MPAS e compatibilidade com índices de 32 bits | consultada em 2026-08-05 apenas para [[../project/future-experiments|experimento futuro]] |
| DOC-MPAS-MESH-001 | MPAS-Atmosphere atual | [Meshes & Mesh Utilities](https://www2.mmm.ucar.edu/projects/mpas/site/downloads/meshes.html) | página first-party: classifica x1.10242 entre as meshes quasi-uniformes, registra 240 km/10.242 células e informa que cada pacote contém SCVT na esfera, `graph.info` e partições pré-computadas; oferece separadamente um static file | consultada diretamente em 2026-08-06; link da mesh de 240 km resolvido para o artefato registrado abaixo |
| DOC-MPAS-MESH-002 | MPAS-Atmosphere atual | [Overview of MPAS Atmosphere](https://www2.mmm.ucar.edu/projects/mpas/site/documentation/mpas_overview.html) | uso de mesh de Voronoi centroidal não estruturada, dual triangular e suporte a aplicações globais uniformes e de resolução variável | consultada em 2026-08-06 para contexto conceitual da primeira mesh |
| DOC-MPAS-TUTORIAL-001 | Tutorial MPAS-Atmosphere | [Practice Session Guide](https://www2.mmm.ucar.edu/projects/mpas/tutorial/UK2015/) | exemplo oficial recorrente com x1.10242, 10.242 células e resolução aproximada de 240 km para geração de campos estáticos e iniciais | consultado em 2026-08-06 como justificativa didática, não como origem do artefato |
| DOC-MPAS-STATIC-001 | MPAS atual | [Running MPAS — Static Fields](https://www2.mmm.ucar.edu/projects/mpas/site/documentation/users_guide/running.html#static-fields) | case 7, dimensões unitárias, data sources, supersampling 1, preproc stages e orientação conservadora de uma task MPI | consultado em 2026-08-13; source 8.4.1 prevalece para nomes/comportamento da versão |
| DOC-MPAS-TUTORIAL-002 | MPAS-Atmosphere St Andrews 2025 | [tutorial first-party](https://www2.mmm.ucar.edu/projects/mpas/tutorial/StAndrews2025/) | caso x1.10242; static e init real; 55/4/38/4; ERA5; RH; Noah-MP false; ztop 30 km; 4 ranks/part.4; streams | reconferido em 2026-08-16; source 8.4.1 prevaleceu |
| DOC-MPAS-REGISTRY-001 | MPAS-Model 8.4.1 | [`Registry.xml` do core init](https://github.com/MPAS-Dev/MPAS-Model/blob/v8.4.1/src/core_init_atmosphere/Registry.xml), `mpas_init_atm_static.F`, `mpas_init_atm_gwd.F` e defaults gerados na imagem | opções válidas, defaults, campos de output, seleção de diretórios, ausência Noah-MP e leitura literal de `landuse_30s/` por native GWD | source/tag exatos inspecionados e exercitados em 2026-08-13/14/16; autoridade operacional da versão |
| DOC-WPS-GEOG-001 | WPS atual | [Geographic Static Data Downloads](https://www2.mmm.ucar.edu/wrf/site/geog_data.html) | classifica low-resolution para testing/educação, publica high mandatory e suplementos WPSv3; origem first-party dos três artefatos adotados | página e links reais consultados em 2026-08-13; conteúdo de cada archive inspecionado antes da adoção |
| DOC-CDS-001 | Climate Data Store atual | [CDSAPI setup](https://cds.climate.copernicus.eu/how-to-api) | formato atual `client.retrieve(dataset, request, target)`, `data_format=grib`, instalação `cdsapi>=0.7.7`, configuração por `$HOME/.cdsapirc` e aceitação manual dos termos por dataset | consultado em 2026-08-14; orientou autenticação montada read-only e probe anterior ao download final |
| DOC-ERA5-PL-001 | ERA5 hourly pressure levels | [catálogo oficial CDS](https://cds.climate.copernicus.eu/datasets/reanalysis-era5-pressure-levels) e [DOI 10.24381/cds.bd0915c6](https://doi.org/10.24381/cds.bd0915c6) | dataset `reanalysis-era5-pressure-levels`, reanálise global horária, grade regular 0,25°, GRIB, 37 níveis de 1000 a 1 hPa, nomes atuais e licença | consultado em 2026-08-14; dataset/inventário aprovados no ADR 0007 e entrega global GRIB1 comprovada por probe/download autenticados |
| DOC-ERA5-SL-001 | ERA5 hourly single levels | [catálogo oficial CDS](https://cds.climate.copernicus.eu/datasets/reanalysis-era5-single-levels) e [DOI 10.24381/cds.adbb2d47](https://doi.org/10.24381/cds.adbb2d47) | dataset `reanalysis-era5-single-levels`, cobertura global, formato GRIB e nomes atuais dos 19 campos de superfície/solo aprovados | consultado em 2026-08-14; dataset/inventário aprovados no ADR 0007 e entrega global GRIB1 comprovada por probe/download autenticados |
| DOC-ERA5-PARAM-001 | ERA5/ECMWF | [ERA5 parameter listings](https://confluence.ecmwf.int/pages/viewpage.action?pageId=185075432) e [ERA5 data documentation](https://confluence.ecmwf.int/display/CKB/ERA5%3A+data+documentation) | nomes, IDs, unidades, nível de superfície e profundidades das quatro camadas de solo; distinção pressure/model levels e codificação ERA5 | consultado em 2026-08-14 e cruzado com os catálogos CDS e o Vtable da versão adotada |
| DOC-WPS-ERA5-001 | WPS 4.7.0 | [`Vtable.ECMWF` da tag](https://github.com/wrf-model/WPS/blob/v4.7.0/ungrib/Variable_Tables/Vtable.ECMWF) e [`rrpr.F`](https://github.com/wrf-model/WPS/blob/v4.7.0/ungrib/src/rrpr.F) | códigos ECMWF/GRIB, nomes WPS, conversões GEOPT→HGT, SOILGEO→SOILHGT, dew point→RH e SNOW_EC→SNOW | source exato e 204 mensagens reais cruzados em 2026-08-15; tabela upstream adotada diretamente e `ungrib` funcional PASS |
| DOC-WPS-REQ-001 | WPS atual | [Required input for running WRF](https://github.com/wrf-model/Users_Guide/blob/main/wps.rst#required-input-for-running-wrf) | conjunto meteorológico/superficial mínimo esperado após ungrib e papel de Vtable/link_grib | consultado em 2026-08-14 como requisito de consumidor, sem substituir o source 4.7.0 |
| DOC-WPS-INT-001 | WPS 4.7.0 / formato oficial | [WPS intermediate format](https://www2.mmm.ucar.edu/wrf/OnLineTutorial/Basics/IM_files/IM_wps.php), [`wps.rst`](https://github.com/wrf-model/Users_Guide/blob/main/wps.rst) e [`write_met_module.F` da tag](https://github.com/wrf-model/WPS/blob/v4.7.0/metgrid/src/write_met_module.F) | version 5, registros Fortran unformatted big-endian, header, projeção, flag de vento e slab `nx*ny` | especificação e source exato inspecionados em 2026-08-15; fundamentam o parser streaming e a validação estrutural |
| DOC-MPAS-ERA5-001 | MPAS-Model 8.4.1 | [`Registry.xml`](https://github.com/MPAS-Dev/MPAS-Model/blob/v8.4.1/src/core_init_atmosphere/Registry.xml), [`mpas_init_atm_cases.F`](https://github.com/MPAS-Dev/MPAS-Model/blob/v8.4.1/src/core_init_atmosphere/mpas_init_atm_cases.F) e leitor real-data da tag | campos, packages, 37 + superfície = 38, RH→qv, SKINTEMP/SST, soil, sea ice, caso global sem LBC | source exato e output exercitados em 2026-08-16 |
| DOC-PYTHON-IMAGE-001 | Python Official Image | [tags oficiais](https://hub.docker.com/_/python) e [`3.12.13-slim-bookworm`](https://hub.docker.com/layers/library/python/3.12.13-slim-bookworm/) | disponibilidade da variante slim-bookworm, versão Python e digest multi-platform publicado | consultado e resolvido pelo Docker em 2026-08-14; base exclusiva do cliente CDS, não da imagem científica |

### Releases, artefatos e versões fixadas pela implementação atual

As URLs usadas pelo build são reproduzidas literalmente do
[`Dockerfile`](../../Dockerfile), portanto não são inferidas. WPS usa archive
com SHA-256 local; MPAS usa clone Git da tag com commit verificado e metadata
preservada. O estado de cada artefato ou pin é informado individualmente na
última coluna.

| ID | Componente | Release/artefato registrado | Integridade no build/aquisição | Estado da verificação |
|---|---|---|---|---|
| REL-UBUNTU-001 | Ubuntu | imagem `ubuntu:24.04` | tag sem digest fixado | referência confirmada no `Dockerfile`; origem/digest devem ser verificados antes de uma mudança de base |
| REL-PYTHON-CDS-001 | Python Official Image 3.12.13 | [`python:3.12.13-slim-bookworm`](https://hub.docker.com/_/python) | index digest `sha256:d50fb7611f86d04a3b0471b46d7557818d88983fc3136726336b2a4c657aa30b` no `docker/cds/Dockerfile` | digest resolvido e imagem construída em 2026-08-14; usada somente por `mpas-era5:cdsapi-0.7.7` |
| REL-CDSAPI-001 | cdsapi 0.7.7 | [PyPI oficial](https://pypi.org/project/cdsapi/0.7.7/) e [release/repositório ECMWF](https://github.com/ecmwf/cdsapi/releases/tag/0.7.7) | versão direta e todas as dependências transitivas observadas fixadas em `docker/cds/requirements.txt`; `pip check` no build | release publicada em 2025-09-30, Python ≥3.8; build/smoke, autenticação, probes e retrieves dos dois datasets PASS em 2026-08-14 |
| REL-ZLIB-001 | zlib 1.3.2 | `https://zlib.net/fossils/zlib-1.3.2.tar.gz` | SHA-256 `bb329a0a2cd0274d05519d61c667c062e06990d72e125ee2dfa8de64f0119d16` | URL e hash confirmados no `Dockerfile`; autoridade externa não revalidada neste ciclo |
| REL-HDF5-001 | HDF5 1.14.6 | `https://github.com/HDFGroup/hdf5/releases/download/hdf5_1.14.6/hdf5-1.14.6.tar.gz` | nenhum SHA-256 registrado | URL confirmada no `Dockerfile`; checksum e release oficial precisam de verificação futura |
| REL-NETCDF-C-001 | netCDF-C 4.10.1 | `https://downloads.unidata.ucar.edu/netcdf-c/4.10.1/netcdf-c-4.10.1.tar.gz` | SHA-256 `db3b69ff4a5ee1a7d79a5c36664d2128b752c266e966369fcf7311ec5f927564` | URL e hash confirmados no `Dockerfile`; autoridade externa não revalidada neste ciclo |
| REL-NETCDF-F-001 | netCDF-Fortran 4.6.3 | `https://downloads.unidata.ucar.edu/netcdf-fortran/4.6.3/netcdf-fortran-4.6.3.tar.gz` | SHA-256 `f642050e90025e7bb25848cc8f818545e1d3bdeb73fe6d103a6f8dc000a1a3d6` | URL e hash confirmados no `Dockerfile`; autoridade externa não revalidada neste ciclo |
| REL-PNETCDF-001 | PnetCDF 1.15.0 | [tarball oficial `pnetcdf-1.15.0.tar.gz`](https://parallel-netcdf.github.io/Release/pnetcdf-1.15.0.tar.gz) | SHA-256 `39813fe91ec901c7cfca3212731edbb5201029ebf55caeaaaa08d9e33c6bad65` | baixado duas vezes e calculado localmente com o mesmo resultado em 2026-08-04; o upstream não publica SHA-256 |
| REL-PIO-001 | PIO 2.7.0 | [release oficial `pio2_7_0`](https://github.com/NCAR/ParallelIO/releases/tag/pio2_7_0) e [tarball da tag](https://github.com/NCAR/ParallelIO/archive/refs/tags/pio2_7_0.tar.gz) | SHA-256 local `cce83743156ae723e7890931c2b48dcfe7ea8a276962dc4429f839d8f58d4a5a` | API de releases, tag, artefato e hash conferidos em 2026-08-04; era a release estável atual, publicada em 2026-04-29 |
| REL-CMAKE-FORTRAN-UTILS-001 | CMake_Fortran_utils | [repositório oficial](https://github.com/CESM-Development/CMake_Fortran_utils) | commit `05ff8d8e4c88786e94a02c853d3ff921113d785c` | commit efetivamente resolvido pelo probe PIO 2.7.0 e fixado no build em 2026-08-04 |
| REL-GENF90-001 | genf90 | [repositório oficial PARALLELIO](https://github.com/PARALLELIO/genf90) | commit `4816965ba946731352bad195b7d946a5fe682ff5` | commit da dependência auxiliar observada e fixada no build em 2026-08-04 |
| REL-METIS-001 | METIS 5.1.0 | [tarball first-party `metis-5.1.0.tar.gz`](https://karypis.github.io/glaros/files/sw/metis/metis-5.1.0.tar.gz) | SHA-256 local `76faebe03f6c963127dbb73c13eab58c9a3faeae48779f049066a21c087c5db2` | URL ligada pela página histórica first-party; dois downloads independentes de 4.984.968 bytes produziram o mesmo SHA-256 em 2026-08-05; nenhum SHA-256 upstream foi encontrado |
| REL-WPS-001 | WPS 4.7.0 | [release oficial `v4.7.0`](https://github.com/wrf-model/WPS/releases/tag/v4.7.0), [archive da tag](https://github.com/wrf-model/WPS/archive/refs/tags/v4.7.0.tar.gz) e [commit da tag](https://github.com/wrf-model/WPS/commit/5feccecd63384381b6942371c7a837f66e4ccb84) | SHA-256 local `5232d20d7556338391b66aba45824d4fcd6c42712ebe9325f359f3c6cf043808` | release, source da tag e [histórico oficial](https://github.com/wrf-model/WPS/releases) cruzados em 2026-08-05; dois downloads independentes de 4.544.769 bytes produziram o mesmo hash; nenhum SHA-256 upstream foi encontrado |
| REL-MPAS-001 | MPAS-Model 8.4.1 | [release oficial `v8.4.1`](https://github.com/MPAS-Dev/MPAS-Model/releases/tag/v8.4.1), [repositório/tag](https://github.com/MPAS-Dev/MPAS-Model/tree/v8.4.1) e [hotfix/commit](https://github.com/MPAS-Dev/MPAS-Model/commit/91c5eac175eebeaf4206bacd5cb50c39dff3c152) | clone `--branch v8.4.1 --single-branch`; `git rev-parse HEAD` e tag exata precisam corresponder a `91c5eac175eebeaf4206bacd5cb50c39dff3c152`; metadata Git mantida | release, clone da tag, commit e histórico oficial cruzados em 2026-08-05; commit verificado nos probes e builds definitivos |
| REL-MPAS-MESH-001 | MPAS x1.10242 | [tarball first-party de 240 km](https://www2.mmm.ucar.edu/projects/mpas/atmosphere_meshes/x1.10242.tar.gz) | 6.321.104 bytes; SHA-256 local `4dde31932bc45aaf467e2717d17ec8e5e54d73c3ebbeea027087bfdb8b98ab56` | URL resolvida a partir de DOC-MPAS-MESH-001; dois downloads independentes foram byte-a-byte iguais em 2026-08-06; nenhum SHA-256 upstream foi encontrado; archive contém a mesh, `graph.info` e partições, mas o workflow copia somente os dois primeiros |
| REL-WPS-GEOG-LOW-001 | WPS geographic low mandatory | [`geog_low_res_mandatory.tar.gz`](https://www2.mmm.ucar.edu/wrf/src/wps_files/geog_low_res_mandatory.tar.gz) | 149.872.777 bytes; SHA-256 local `cbdbcc43554d946a38cbce658b7d563afd7a2889f2c0735b8aa3f2206c7256e7` | archive real inspecionado em 2026-08-13 e rejeitado para esta baseline por ausência dos datasets 30s requeridos; nenhum SHA-256 upstream encontrado |
| REL-WPS-GEOG-HIGH-001 | WPS geographic high mandatory | [`geog_high_res_mandatory.tar.gz`](https://www2.mmm.ucar.edu/wrf/src/wps_files/geog_high_res_mandatory.tar.gz) | 2.772.782.816 bytes; SHA-256 local `89b026b9db0a03c0c995e53b4a1d99663af1f6bda21b3b34c3c2c07386da5493` | tamanho HTTP, ranges independentes, hash, `gzip -t` e listagem `tar` conferidos em 2026-08-13; nenhum SHA-256 upstream encontrado; somente seis diretórios necessários são extraídos |
| REL-WPS-GEOG-MODIS-001 | WPSv3 MODIS land use | [`modis_landuse_20class_30s.tar.bz2`](https://www2.mmm.ucar.edu/wrf/src/wps_files/modis_landuse_20class_30s.tar.bz2) | 32.334.661 bytes; SHA-256 local `b21ca154d1038ec271abaa1be2fd38a0cd055b8a4ddfaab520719478ac48d326` | dois downloads independentes byte-a-byte iguais, bzip2/tar e índice MODIFIED_IGBP verificados em 2026-08-13; nenhum SHA-256 upstream encontrado |
| REL-WPS-GEOG-GWD-001 | WPSv3 USGS land use | [`landuse_30s.tar.bz2`](https://www2.mmm.ucar.edu/wrf/src/wps_files/landuse_30s.tar.bz2) | 20.988.479 bytes; SHA-256 local `143cd195ae91f64011a43eae52ca00228709672c6a2ba614cb437eeb4cd41160` | dois downloads independentes, um por ranges, byte-a-byte iguais; bzip2/tar e índice USGS 24 categorias verificados em 2026-08-13; requerido pelo source GWD 8.4.1; nenhum SHA-256 upstream encontrado |
| REL-MMM-PHYSICS-001 | MMM-physics | [release oficial `20250616-MPASv8.3`](https://github.com/NCAR/MMM-physics/releases/tag/20250616-MPASv8.3) | tag anotada resolvida para commit `a4baf7f3243d1db0dbc5f63473f895bdbdc05c30`; checkout detached e limpo | repo/tag impostos por `Externals.cfg`; objeto de tag e commit peeled verificados em 2026-08-05 |
| REL-UGWP-001 | UGWP | [release oficial `MPAS_20241223`](https://github.com/NOAA-GSL/UGWP/releases/tag/MPAS_20241223) | tag leve/commit `c1c893edcf171af5639af60e3a3a528816f6cc2b`; checkout detached e limpo | repo/tag impostos por `Externals.cfg`; commit verificado em 2026-08-05 |
| REL-MPAS-DATA-001 | MPAS-Data | [tag oficial `v8.2`](https://github.com/MPAS-Dev/MPAS-Data/tree/v8.2) | tag anotada resolvida para commit `c57dbc7be629802c6e848770a9e44b9bc602be41`; compatibilidade e hashes dos arquivos verificados | tag usada pelo script da física; objeto de tag e commit peeled verificados em 2026-08-05 |

### Release PnetCDF 1.15.0

| ID | Fonte oficial | Informação verificada | Verificação |
|---|---|---|---|
| REL-PNETCDF-NOTES-001 | [release notes 1.15.0](https://github.com/Parallel-NetCDF/Parallel-NetCDF.github.io/blob/master/Release_notes/1.15.0.md) | release de 1º de julho de 2026; introdução de GIO e mudança do backend padrão | consultada em 2026-08-04; sustenta [[../decisions/0001-pnetcdf-mpiio-backend|ADR 0001]] |
| REL-PNETCDF-DOWNLOAD-001 | [Download oficial](https://parallel-netcdf.github.io/wiki/Download.html) | lista 1.15.0 e publica SHA-1 `fec63e5d1cdb4de4f3fd85f11be45294d4a8ed66` | consultada em 2026-08-04; o SHA-1 local coincidiu |

Foi investigada a possível defasagem da página Download: na consulta ao vivo
de 2026-08-04 ela **já listava 1.15.0**. Portanto não existe divergência atual
entre a página, o repositório e as release notes quanto à release estável. A
limitação real é de integridade: a página publica SHA-1, mas não SHA-256. O
SHA-256 usado no `Dockerfile` não é atribuído ao upstream; ele foi calculado
localmente duas vezes a partir do artefato oficial.

Há uma inconsistência dentro do próprio artefato: o `INSTALL` informa shared
desabilitado e static habilitado por padrão, enquanto o `configure --help`
gerado pela release 1.15.0 exibiu shared e static habilitados por padrão. A
decisão já aprovada usa `--enable-shared --enable-static` explicitamente, o que
torna o build determinístico sem escolher um dos defaults conflitantes.

### Release PIO 2.7.0 e conflito documental

A API oficial do GitHub e a página de releases apontavam `pio2_7_0` como
release estável atual em 2026-08-04. `pio2_6_5` foi tratada apenas como
candidata inicial. O probe 2.6.5 deixou uma falha no teste `pio_rearr_opts` em
OMPIO e ROMIO, enquanto 2.7.0 executou 109/109 testes; não surgiu razão técnica
para adotar a release anterior.

O `README.md` 2.7.0 diz que netCDF-C deve usar MPI/HDF5 paralelo. O
`Installing.txt` da mesma tag diz “ideally”. O conflito não foi resolvido por
preferência textual: o CMake aceitou netCDF serial, registrou
`HAVE_NETCDF_PAR` como falso e manteve PnetCDF/NetCDF clássico. A suíte e o
smoke explícito PnetCDF passaram. O resultado e a limitação dos IOTYPEs estão
registrados em [[../testing/validation-matrix|validation-matrix.md]].

### Release METIS 5.1.0 e linha moderna

A página histórica first-party permanece em METIS 5.1.0 e aponta para o
artefato adotado. Nenhum SHA-256 publicado pelo upstream foi encontrado nessa
página, no manual ou junto ao download. O valor no `Dockerfile` foi calculado
localmente e confirmado pelo segundo download do mesmo URL. Ele identifica o
artefato first-party observado; não é apresentado como checksum oficial.

Os arquivos de build do tarball mostram que a GKlib está incluída em
`GKlib/` e é usada pelo próprio build 5.1.0. Logo, nenhuma GKlib externa foi
introduzida. O repositório oficial moderno contém a release 5.2.1 e suas
instruções exigem GKlib externa. Essa observação histórica não altera a versão
adotada: 5.2.1 só poderá ser experimentada com revisão/release GKlib fixada,
conforme [[../project/future-experiments|future-experiments.md]].

### Mesh MPAS x1.10242

A página oficial liga a entrada quasi-uniforme de 240 km e 10.242 células
diretamente a `x1.10242.tar.gz` no domínio first-party da NSF NCAR. O archive
observado contém `x1.10242.grid.nc`, `x1.10242.graph.info` e partições
pré-computadas para 2, 4, 6, 8, 12, 16, 24, 32, 36, 48 e 64 partes. Os nomes
canônicos já coincidem com o uso no projeto; nenhuma renomeação foi inventada.

Não foi encontrado checksum SHA-256 na página, junto ao download ou na
documentação oficial consultada. Dois downloads independentes de 6.321.104
bytes foram comparados byte a byte e produziram o mesmo SHA-256 local:

```text
4dde31932bc45aaf467e2717d17ec8e5e54d73c3ebbeea027087bfdb8b98ab56
```

Esse valor identifica o artefato first-party observado e fica fixado no
script de aquisição; não é descrito como checksum publicado pela NCAR. O
static file de 240 km, oferecido por link separado, não foi baixado. Essa
exclusão implementou a decisão de gerar `static.nc` localmente, concluída no
ciclo 0009.

### Dados geográficos WPS para MPAS 8.4.1

A inspeção real de `geog_low_res_mandatory.tar.gz` mostrou ausência dos
datasets 30s desta configuração. O high mandatory tampouco contém
`modis_landuse_20class_30s/` sem lakes nem `landuse_30s/`. O source exato
8.4.1 seleciona o primeiro pelo namelist e lê o segundo diretamente no native
GWD. Por isso a baseline usa a extração seletiva do high junto aos dois
suplementos first-party exatos ligados pela página WPS.

Os três SHA-256 são de origem local, não upstream. Não há alias entre produtos.
O conteúdo final, 16.563.576.021 bytes, recebe manifesto por arquivo e fica
fora do Git e da imagem. O conflito User Guide/tutorial sobre uma versus várias
tasks é registrado sem generalizar: a baseline executada tem uma task; o
tutorial demonstra que paralelismo existe.

### Releases WPS 4.7.0 e MPAS-Model 8.4.1

A checagem inicial do WPS partiu de 4.6.0, mas o cruzamento entre release,
source da tag e histórico oficial encontrou a release estável posterior
4.7.0. O ciclo parou no gate de versão; depois o usuário aprovou explicitamente
4.7.0. A tag aponta para
`5feccecd63384381b6942371c7a837f66e4ccb84`, o README da própria tag declara
4.7.0 e nenhuma release estável posterior foi encontrada em 2026-08-05.

O GitHub não publicou SHA-256 para o archive gerado da tag WPS. O hash adotado
foi calculado localmente e confirmado por dois downloads independentes do URL
oficial. Ele identifica o artefato observado, mas não é apresentado como hash
publicado pelo upstream.

Para MPAS, 8.4.0 chegou a ser considerado. A verificação direta mostrou a tag
oficial `v8.4.1`, o heading `MPAS-v8.4.1` no README dessa tag e o hotfix
`91c5eac175eebeaf4206bacd5cb50c39dff3c152`; o histórico não mostrou release
estável posterior. O ciclo 0006 clonou essa tag, verificou o commit antes do
build e preservou `.git` para o `git describe` do Makefile.

A página geral Building MPAS contém orientações que não representam todos os
detalhes da tag 8.4.1. Para precisão, `USE_PIO2=true`, single precision, target
`gnu`, `CORE=init_atmosphere`, PIO2 autodetectado e ESMF embedded foram
confirmados no Makefile e nos build options da própria tag e depois no resumo
real do build. Essa priorização da fonte versionada evita projetar defaults de
outras releases sobre 8.4.1.

Para o atmosphere, `Externals.cfg` é a autoridade sobre os nomes e tags de
MMM-physics e UGWP; nenhuma versão alternativa foi escolhida. As tags foram
resolvidas com `git ls-remote` e o Dockerfile valida os commits exatos. O
`checkout_data_files.sh` da própria 8.4.1 é a autoridade para `mpas_vers=8.2`.
A tag MPAS-Data v8.2 foi compatível e forneceu exatamente as tabelas esperadas;
o build as materializa antes do make para impedir resolução de rede indireta.

Registrar uma URL aqui não autoriza download novo, mudança de versão ou
alteração da stack. Para isso, a fonte deve ser consultada conforme o workflow,
a compatibilidade deve ser avaliada e o usuário deve aprovar a proposta.

### Fontes secundárias

| ID | Fonte | Uso restrito | Verificação |
|---|---|---|---|
| SEC-METIS-001 | [EasyConfig METIS 5.1.0 da LUMI Software Library](https://lumi-supercomputer.github.io/LUMI-EasyBuild-docs/m/METIS/METIS-5.1.0-cpeGNU-22.08/) | cross-check secundário do SHA-256 e do tamanho; não define origem, versão, arquitetura ou flags do projeto | consultado em 2026-08-05; registra o mesmo SHA-256 `76faebe03f6c963127dbb73c13eab58c9a3faeae48779f049066a21c087c5db2` |

A evidência adotada continua sendo o artefato first-party baixado e comparado
localmente duas vezes. Nenhuma fonte secundária sustenta a arquitetura ou as
alternativas deste ciclo.

### Fóruns e issues para troubleshooting

| ID | Fonte | Sintoma/hipótese aproveitada | Validação local |
|---|---|---|---|
| TROUBLE-OPENMPI-001 | [issue oficial OpenMPI #10297](https://github.com/open-mpi/ompi/issues/10297) | falha aberta no caminho `mca_io_ompio_file_write_at_all()` durante escrita paralela PnetCDF, marcada para OpenMPI 4.1.x | OMPIO 4.1.6 produziu valores ausentes/incompletos; `ompi_info` mostrou ROMIO 4.1.6 disponível e `--mca io romio321` fez `make ptest` e a integração passarem |

A issue foi usada somente para troubleshooting. A arquitetura MPI-IO/GIO e a
versão PnetCDF já haviam sido decididas por fontes primárias e pelo usuário.
ROMIO é um componente do OpenMPI instalado, não uma troca de implementação MPI.

## Campos obrigatórios para novas entradas

Toda nova fonte deve registrar:

1. identificador estável;
2. classe de fonte;
3. componente e versão aplicável;
4. título ou descrição;
5. URL exata, quando houver;
6. finalidade da consulta;
7. data de verificação;
8. resultado da verificação;
9. decisão, ADR ou teste que a utiliza.

URLs não abertas ou não presentes em uma fonte já rastreada devem permanecer
fora do registro até verificação. Em caso de conflito entre fontes oficiais, o
ciclo deve parar e apresentar o conflito ao usuário.
