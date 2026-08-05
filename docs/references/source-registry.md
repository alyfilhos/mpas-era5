# Registro de fontes

## Finalidade

Este registro documenta de onde vêm requisitos, fatos técnicos, versões e
orientações de troubleshooting. Uma fonte deve ser classificada antes de ser
usada; autoridade e utilidade não são a mesma coisa.

Última revisão deste registro: **2026-08-05**.

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
| DOC-WPS-004 | WPS 4.7.0 | [`compile` da tag](https://github.com/wrf-model/WPS/blob/v4.7.0/compile) | shebang csh, targets aceitos e confirmação de `./compile ungrib` | lido integralmente e exercitado em 2026-08-05 |
| DOC-WPS-005 | WPS 4.7.0 | [`arch/Config.pl`](https://github.com/wrf-model/WPS/blob/v4.7.0/arch/Config.pl) e [`arch/configure.defaults`](https://github.com/wrf-model/WPS/blob/v4.7.0/arch/configure.defaults) | geração do menu, plataforma Linux x86_64/GFortran serial, compiladores e flags | inspecionados na tag e usados na seleção reproduzível em 2026-08-05 |
| DOC-WPS-006 | WPS 4.7.0 | `external/Makefile`, `arch/preamble` e `ungrib/Makefile` contidos no archive da tag | versões e instalação privada de zlib/libpng/JasPer, flags GRIB2 e alvo ungrib | inspecionados no artefato adotado em 2026-08-05 |
| DOC-MPAS-004 | MPAS-Model 8.4.1 | [`README.md` da tag](https://github.com/MPAS-Dev/MPAS-Model/blob/v8.4.1/README.md) | heading `MPAS-v8.4.1` no próprio source da tag | lido em 2026-08-05; versão somente documental neste ciclo |
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

### Releases, artefatos e versões fixadas pela implementação atual

As URLs usadas pelo build são reproduzidas literalmente do
[`Dockerfile`](../../Dockerfile), portanto não são inferidas. A entrada MPAS é
explicitamente documental e não aparece na receita. O estado de cada artefato
ou pin é informado individualmente na última coluna.

| ID | Componente | Release/artefato registrado | Integridade no build | Estado da verificação |
|---|---|---|---|---|
| REL-UBUNTU-001 | Ubuntu | imagem `ubuntu:24.04` | tag sem digest fixado | referência confirmada no `Dockerfile`; origem/digest devem ser verificados antes de uma mudança de base |
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
| REL-MPAS-001 | MPAS-Model 8.4.1 | [release oficial `v8.4.1`](https://github.com/MPAS-Dev/MPAS-Model/releases/tag/v8.4.1), [tag](https://github.com/MPAS-Dev/MPAS-Model/tree/v8.4.1) e [hotfix/commit](https://github.com/MPAS-Dev/MPAS-Model/commit/91c5eac175eebeaf4206bacd5cb50c39dff3c152) | tag/commit fixados documentalmente; nenhum artefato baixado pelo build | release, README do source da tag e [histórico oficial](https://github.com/MPAS-Dev/MPAS-Model/releases) cruzados em 2026-08-05; nenhuma release estável posterior encontrada |

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
estável posterior. Essa verificação fixa a versão do ciclo futuro, sem
autorizar download, configuração ou build do modelo agora.

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
