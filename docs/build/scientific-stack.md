# Stack científica

## Objetivo

Construir incrementalmente as bibliotecas necessárias ao MPAS,
mantendo as dependências científicas sob `/opt/mpas`.

## Prefixo

```text
/opt/mpas
├── bin
├── include
├── lib
└── lib64
```

## Componentes implementados

| Componente | Versão | Papel principal |
|---|---:|---|
| zlib | 1.3.2 | compressão usada pela stack HDF5/netCDF |
| HDF5 | 1.14.6 | armazenamento hierárquico usado pelo netCDF-4 |
| netCDF-C | 4.10.1 | API C e ferramentas netCDF |
| netCDF-Fortran | 4.6.3 | interface Fortran sobre netCDF-C |
| PnetCDF | 1.15.0 | I/O paralelo dos formatos CDF por MPI-IO |
| PIO | 2.7.0 | abstração de I/O paralelo usada pelo MPAS, com backend PnetCDF |
| METIS | 5.1.0 | particionamento serial offline do grafo da mesh para os ranks MPI |

WPS não é uma biblioteca da stack. A instalação separada
`/opt/wps-4.7.0` fornece somente `ungrib.exe`. MPAS-Model também usa prefixo
separado: `/opt/mpas-model-8.4.1` contém os cores `init_atmosphere` e
`atmosphere`, compilados em ciclos incrementais na mesma árvore.

## PnetCDF 1.15.0

PnetCDF fornece APIs paralelas semelhantes às APIs clássicas do netCDF para
que múltiplos ranks MPI acessem coletivamente um mesmo arquivo. Neste ciclo ele
foi construído com interfaces C, C++ e Fortran, bibliotecas shared e static e
instalado no mesmo prefixo científico `/opt/mpas`.

netCDF-C e PnetCDF não são duas camadas obrigatoriamente empilhadas. A stack
netCDF existente oferece, entre outros recursos, netCDF-4 sobre HDF5. O
PnetCDF aprovado opera diretamente sobre CDF-1, CDF-2 e CDF-5 usando MPI-IO;
por isso não depende de HDF5 nem exigiu reconstruir HDF5, netCDF-C ou
netCDF-Fortran. A integração NetCDF-4 opcional do PnetCDF permaneceu
desabilitada.

O caminho validado é:

```text
programa Fortran
    ↓
API Fortran do PnetCDF
    ↓
PnetCDF 1.15.0
    ↓
MPI-IO (componente ROMIO incluído no OpenMPI)
    ↓
OpenMPI 4.1.6
```

### Configuração

O build usa os wrappers MPI declarados pela própria release:

```sh
MPICC=mpicc \
MPICXX=mpicxx \
MPIF77=mpif77 \
MPIF90=mpifort \
./configure \
  --prefix=/opt/mpas \
  --disable-gio \
  --enable-shared \
  --enable-static
```

Fortran permanece habilitado porque essa é a configuração padrão e a opção
que o desabilitaria seria `--disable-fortran`. As flags shared/static foram
mantidas explícitas para que a receita não dependa de defaults documentais
divergentes. Não foram habilitados NetCDF-4, ADIOS, subfiling, thread safety,
profiling ou outros backends opcionais.

A release 1.15.0 tornou GIO o backend padrão. GIO agrega e redistribui I/O com
foco em otimizações para sistemas como Lustre. O ciclo inicial escolheu
`--disable-gio`, que preserva o caminho MPI-IO tradicional, mais direto para
estudar os conceitos HPC e suficiente antes de existir uma necessidade de
performance que justifique GIO.

OpenMPI 4.1.6 fornece dois componentes MPI-IO, OMPIO e ROMIO. Os testes locais
com o OMPIO selecionado por padrão apresentaram escrita incompleta em casos
coletivos do PnetCDF. O `make ptest` e o teste versionado selecionam, apenas no
comando, `--mca io romio321`. Isso usa um componente já distribuído pelo mesmo
OpenMPI; não substitui nem reconstrói a implementação MPI e não define uma
configuração global para futuras aplicações.

### Instalação e descoberta

O ambiente final preserva:

```sh
NETCDF=/opt/mpas
PNETCDF=/opt/mpas
```

Foram confirmados os utilitários instalados pela release:

- `pnetcdf_version` e `pnetcdf-config` para versão e configuração;
- `ncmpidump` e `ncmpigen` para inspecionar e gerar CDF;
- `ncmpidiff` e `cdfdiff` para comparação;
- `ncoffsets` para offsets do arquivo;
- `ncvalidator` para validação de CDF.

### Testes executados

- `make check`: aprovado; todas as suítes sequenciais terminaram com sucesso;
- `make ptest`: aprovado com 4 ranks, ROMIO e a exceção localizada
  `--allow-run-as-root` necessária durante o Docker build;
- smoke instalado: versão 1.15.0, prefixo, GIO, Fortran, bibliotecas e
  utilitários conferidos com `pnetcdf_version`/`pnetcdf-config`;
- integração: o programa F90 em `tests/smoke/pnetcdf_mpi.f90` criou CDF-5,
  cada um dos 4 ranks escreveu e releu sua posição, e `ncmpidump` mostrou
  `rank_value = 0, 1, 2, 3`;
- linkagem: `ldd` encontrou `libpnetcdf.so.8` em `/opt/mpas/lib` e as
  bibliotecas MPI do OpenMPI do Ubuntu;
- regressão: `nc-config` permaneceu em 4.10.1 e `nf-config` em 4.6.3.

O uso de `--allow-run-as-root` é limitado aos comandos executados durante o
build/validação do container, cujo usuário é root. Ele não recomenda nem
configura execuções HPC normais como root. `make ptests`, a suíte paralela mais
extensa com múltiplas contagens de ranks, não foi executada; `make check` e
`make ptest` são a validação upstream aprovada deste ciclo.

## PIO 2.7.0

PIO organiza a decomposição dos dados e encaminha operações a um backend de
arquivo. `init_atmosphere_model` e `atmosphere_model` foram compilados com
`USE_PIO2=true` e encontraram `NETCDF`, `PNETCDF` e `PIO` no mesmo prefixo
`/opt/mpas`.

A arquitetura aprovada preserva HDF5 1.14.6 e netCDF-C 4.10.1 seriais. O
primeiro caso MPAS usa o `io_type=pnetcdf` padrão, de modo que o caminho
paralelo validado é independente de HDF5:

```text
MPAS init_atmosphere/atmosphere (USE_PIO2=true)
    ↓
PIO 2.7.0 — PIO_IOTYPE_PNETCDF
    ↓
PnetCDF 1.15.0
    ↓
MPI-IO
    ↓
OpenMPI 4.1.6
```

### Compatibilidade da stack serial

As fontes oficiais 2.7.0 contêm uma divergência textual. O `README.md` afirma
que netCDF-C deve ser construído com MPI e HDF5 paralelo; o
`doc/source/Installing.txt` diz que isso é ideal. O CMake e o teste empírico
resolvem a compatibilidade efetiva:

- `CMakeLists.txt` exige netCDF, testa NetCDF-4 e testa separadamente
  `HAVE_NETCDF_PAR`;
- `cmake/TryNetCDF_PARALLEL.c` consulta `NC_HAS_PARALLEL` de
  `netcdf_meta.h`; não chama `nc_create_par` nem `nc_open_par`;
- falhar `HAVE_NETCDF_PAR` não aborta a configuração;
- `_NETCDF4` só é definido quando `HAVE_NETCDF_PAR` é verdadeiro. Por isso,
  nesta release, a mesma condição remove tanto `PIO_IOTYPE_NETCDF4P` quanto
  `PIO_IOTYPE_NETCDF4C`, mesmo que o netCDF-4 serial exista;
- os caminhos `PIO_IOTYPE_PNETCDF` e `PIO_IOTYPE_NETCDF` permanecem
  compilados em `src/clib/pio_file.c` e `src/clib/pio_nc.c`.

O build permanente confirmou `HAVE_NETCDF4` com sucesso e
`HAVE_NETCDF_PAR` com falha esperada. A consulta em runtime confirmou:

```text
PNETCDF=1 NETCDF=1 NETCDF4C=0 NETCDF4P=0
```

Logo, NetCDF/HDF5 paralelo é requisito específico dos IOTYPEs NetCDF-4 na
implementação atual do PIO, não do backend PnetCDF nem do backend NetCDF
clássico. Adicioná-lo futuramente exigiria reconstruir HDF5 e netCDF, novo gate
de arquitetura e regressão de toda a cadeia.

### Release, integridade e auxiliares de build

O build usa a tag oficial `pio2_7_0` e verifica antes da extração:

```text
SHA-256 cce83743156ae723e7890931c2b48dcfe7ea8a276962dc4429f839d8f58d4a5a
```

O CMake upstream obtém `CMake_Fortran_utils` e `genf90` durante a configuração
quando eles não são fornecidos. Para evitar dependências mutáveis, o
`Dockerfile` faz checkout detached dos commits observados e aprovados no
probe, verifica cada `HEAD` e passa os caminhos por
`USER_CMAKE_MODULE_PATH` e `GENF90_PATH`:

```text
CMake_Fortran_utils 05ff8d8e4c88786e94a02c853d3ff921113d785c
genf90              4816965ba946731352bad195b7d946a5fe682ff5
```

### Configuração CMake

O CMake foi escolhido porque a documentação oficial do MPAS recomenda
explicitamente `PIO_ENABLE_TIMING=OFF`, a release oferece descoberta separada
das dependências e a suíte pode ser dirigida por CTest.

```sh
CC=mpicc FC=mpifort cmake \
  -S pio-src \
  -B pio-build \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/opt/mpas \
  -DCMAKE_PREFIX_PATH=/opt/mpas \
  -DUSER_CMAKE_MODULE_PATH=/tmp/pio-build/CMake_Fortran_utils \
  -DGENF90_PATH=/tmp/pio-genf90 \
  -DPIO_ENABLE_FORTRAN=ON \
  -DPIO_ENABLE_TIMING=OFF \
  -DPIO_ENABLE_LOGGING=OFF \
  -DPIO_ENABLE_DOC=OFF \
  -DPIO_ENABLE_EXAMPLES=ON \
  -DPIO_ENABLE_NETCDF_INTEGRATION=OFF \
  -DPIO_ENABLE_TESTS=ON \
  -DPIO_USE_GDAL=OFF \
  -DWITH_PNETCDF=ON \
  -DBUILD_SHARED_LIBS=OFF
```

`pioc` e `piof` são construídos em paralelo. O alvo `tests` usa
`--parallel 1` porque dois arquivos-fonte Fortran gerados pela release produzem o
mesmo nome de módulo e apresentam corrida quando compilados simultaneamente.
Isso não reduz a cobertura: os 109 testes foram construídos e executados.

### Instalação e testes executados

A instalação preserva `PIO=/opt/mpas`, `pio.h`, os módulos Fortran,
`libpioc.a`, `libpiof.a`, `libpio.settings` e os arquivos de pacote CMake.

- CTest upstream: 109/109 aprovados, incluindo C, Fortran, async, decomposição,
  rearranjo e exemplos;
- smoke C instalado: compilado com `mpicc` contra `libpioc.a`, PnetCDF e
  netCDF do prefixo;
- integração: quatro ranks criaram e reabriram CDF-2 explicitamente por
  `PIO_IOTYPE_PNETCDF`, escrevendo `1000, 1001, 1002, 1003`;
- MPI-IO: o mesmo teste passou com OMPIO padrão e com seleção local
  `--mca io romio321`;
- linkagem: `nm` encontrou `PIOc_Init_Intracomm`; `ldd` encontrou PnetCDF e
  netCDF em `/opt/mpas/lib` e MPI no OpenMPI esperado;
- regressão: o smoke PnetCDF/Fortran do ciclo 0002 passou na imagem PIO e
  preservou netCDF-C 4.10.1, netCDF-Fortran 4.6.3 e PnetCDF 1.15.0.

Detalhes auditáveis estão em
[[../testing/validation-matrix|validation-matrix.md]] e a decisão em
[[../decisions/0002-pio2-pnetcdf-with-serial-netcdf|ADR 0002]].

## METIS 5.1.0

METIS particiona grafos. Uma mesh pode ser representada por um **grafo**:
cada elemento relevante à decomposição é um **vértice**, e uma **aresta** liga
dois vértices adjacentes. Particionar é distribuir os vértices entre grupos.
Para execução paralela, cada grupo será associado a um rank MPI.

Dois objetivos precisam ser equilibrados:

- **balanceamento:** manter carga semelhante em cada partição;
- **edge cut:** reduzir arestas cujas pontas pertencem a partições diferentes,
  pois essas fronteiras tendem a exigir comunicação entre ranks.

**Contiguidade** significa que os vértices de uma partição formam um subgrafo
conectado. Ela facilita uma decomposição espacial coerente. Nenhuma dessas
métricas, isoladamente e sobretudo em um fixture artificial, prova melhor
desempenho do MPAS.

### METIS serial versus MPI

O executável `gpmetis` é serial e roda **antes** do modelo. Ele não substitui
OpenMPI, não é ligado ao MPAS como implementação MPI e não determina como o
modelo troca mensagens. Seu papel é preparar a atribuição:

```text
graph.info
    ↓
gpmetis -minconn -contig -niter=200 graph.info N
    ↓
graph.info.part.N
    ↓
MPAS executado futuramente com N ranks MPI
```

`graph.info` descreve a adjacência do grafo da mesh. O primeiro campo do
cabeçalho é o número de vértices, o segundo é o número de arestas não
direcionadas. Segue uma linha por vértice, na ordem 1..n, listando vizinhos
também numerados a partir de 1. `graph.info.part.N` contém exatamente uma linha
por vértice, com um ID de partição no intervalo 0..`N-1`.

A relação operacional é uma invariável:

```text
N partições ↔ N tasks MPI
```

Assim, `graph.info.part.4` é a decomposição que futuramente acompanhará uma
execução como `mpirun -np 4 atmosphere_model`. O modelo não foi compilado ou
simulado neste ciclo.

### Opções adotadas

A documentação atual do MPAS recomenda:

```sh
gpmetis -minconn -contig -niter=200 graph.info N
```

- `-minconn` tenta minimizar o grau do grafo de conectividade entre
  subdomínios;
- `-contig` exige partições contíguas;
- `-niter=200` permite até 200 iterações de refinamento em cada estágio,
  acima do default 10 do METIS 5.1.0.

### Release, build e larguras

O tarball first-party histórico `metis-5.1.0.tar.gz` foi baixado da página
Karypis e verificado antes da extração:

```text
SHA-256 76faebe03f6c963127dbb73c13eab58c9a3faeae48779f049066a21c087c5db2
```

O upstream não publicou ali um SHA-256. O valor foi calculado localmente sobre
o artefato first-party e confirmado por dois downloads independentes
idênticos; ele não é atribuído ao upstream.

Os arquivos `Install.txt`, `BUILD.txt`, `Makefile` e `CMakeLists.txt` do
próprio tarball definem a receita usada:

```sh
make config prefix=/opt/mpas
make -j8
make install
```

A release usa GNU make para dirigir CMake e requer compilador C99. Foi mantido
o build estático default; `shared=1` não foi solicitado. A instalação normal
preserva `libmetis.a`, `metis.h` e os executáveis `gpmetis`, `ndmetis`,
`mpmetis`, `m2gmetis`, `graphchk` e `cmpfillin` em `/opt/mpas`.
Não foi criada uma variável `METIS`, porque o workflow usa o executável
descoberto por `PATH`.

Os defaults do source foram preservados:

| Macro | Valor | Significado |
|---|---:|---|
| `IDXTYPEWIDTH` | 32 | largura dos índices de vértices, arestas e partições do METIS |
| `REALTYPEWIDTH` | 32 | largura do tipo real usado internamente pelo METIS |

Não foram habilitados `i64=1` nem `r64=1`, pois não existe uma mesh aprovada
que demonstre essa necessidade e a documentação atual do MPAS exige
compatibilidade de particionadores com índices de 32 bits. `REALTYPEWIDTH`
não define a precisão dos campos atmosféricos do MPAS.

O tarball 5.1.0 contém o diretório `GKlib/`; o build o usa diretamente e
compila essas fontes em `libmetis`. Por isso nenhuma GKlib externa foi
baixada. Essa relação não deve ser inferida das instruções do METIS 5.2.1, que
passou a exigir GKlib externa.

### Validação

O source 5.1.0 não fornece alvos `make check`, CTest/`add_test` ou uma suíte
formal equivalente. O diretório `graphs/` fornece grafos de teste. Durante o
build, `graphchk` e `gpmetis` foram executados sobre o `4elt.graph`
upstream: 15.606 vértices, 45.878 arestas, quatro partições contíguas,
`Edgecut: 341` e balanceamento 1.001.

O fixture versionado, menor e independente de uma mesh MPAS, contém quatro
cliques de quatro vértices ligadas por três arestas-ponte. A validação final
produziu quatro partições não vazias, 4 vértices em cada, imbalance simples
1.000 (0%), `edge cut` reportado e recalculado igual a 3 e conectividade
confirmada em cada partição. O script também verifica uma linha por vértice,
um único inteiro por linha, IDs 0..3 e ausência de linhas extras.

O banner do programa instalado imprime `METIS 5.0`, texto legado codificado
no programa da release. A versão exata 5.1.0 é verificada pelos macros
`METIS_VER_MAJOR=5`, `METIS_VER_MINOR=1` e `METIS_VER_SUBMINOR=0` do
`metis.h` instalado.

Detalhes e limitações estão em
[[../testing/validation-matrix|validation-matrix.md]], a decisão em
[[../decisions/0003-metis-5.1.0-partitioning-baseline|ADR 0003]] e alternativas
futuras em [[../project/future-experiments|future-experiments.md]].

## WPS 4.7.0 — somente ungrib

WPS, o WRF Preprocessing System, reúne ferramentas de preparação de entradas;
WRF é o modelo atmosférico separado. Os três programas principais do WPS têm
responsabilidades diferentes:

- `geogrid` define domínio e interpola dados geográficos estáticos;
- `ungrib` decodifica GRIB1/GRIB2 segundo uma Vtable e escreve o formato
  intermediário do WPS;
- `metgrid` interpola os campos intermediários para a grade do modelo.

O pipeline MPAS usa `ungrib` para chegar ao formato intermediário que
`init_atmosphere` consumirá em um ciclo funcional. O build atual não precisa
de WRF, `geogrid` ou `metgrid`; por isso eles não foram construídos.

### Layout e isolamento

```text
/opt/mpas                       bibliotecas científicas validadas
/opt/wps-4.7.0                  source e build WPS 4.7.0
/opt/wps -> /opt/wps-4.7.0      link estável

/opt/mpas-model-8.4.1           source e build MPAS-Model 8.4.1
/opt/mpas-model -> /opt/mpas-model-8.4.1
```

`ungrib.exe` permanece no layout upstream:

```text
/opt/wps-4.7.0/ungrib.exe -> ungrib/src/ungrib.exe
/opt/wps/ungrib.exe       -> /opt/wps-4.7.0/ungrib/src/ungrib.exe
```

Ele não é copiado para `/opt/mpas/bin`. Essa separação impede que o source do
WPS e suas dependências privadas sejam confundidos com a ABI da stack
científica compartilhada.

### Configuração e build

A release usa `configure`/`configure.wps` e um script `compile` em csh. A
imagem anterior já continha compiladores, `make`, Perl, `file` e netCDF; o
único pacote de sistema acrescentado foi `csh`, que fornece `/bin/csh`. A
versão APT observada foi `20230828-1`, mas o índice APT continua sem lock.

O comando de configuração foi:

```sh
./configure --nowrf --build-grib2-libs
```

`--nowrf` permite configurar o componente independente `ungrib` sem uma árvore
WRF compilada e marca `WRF_DIR=none`. `--build-grib2-libs` compila os sources
incluídos de zlib 1.2.11, libpng 1.6.37 e JasPer 1.900.29 sob:

```text
/opt/wps-4.7.0/grib2/include
/opt/wps-4.7.0/grib2/lib
```

Essas bibliotecas estáticas habilitam PNG e JPEG2000 para GRIB2 e não alteram
zlib 1.3.2 ou qualquer biblioteca em `/opt/mpas`.

A opção GNU serial não é tratada como número fixo. Um `awk` reproduz a ordem
de plataformas que `arch/Config.pl` deriva de `arch/configure.defaults`,
localiza exatamente `Linux x86_64, gfortran` com marca `serial`, exige uma
única correspondência e envia o índice calculado ao `configure`. Depois,
`configure.wps` precisa comprovar:

- `SFC=gfortran` e `SCC=gcc`;
- `FC=$(SFC)` e `CC=$(SCC)`;
- cabeçalho Linux x86_64/gfortran serial;
- ausência de `-D_MPI` em `CPPFLAGS`;
- `WRF_DIR=none`;
- `INTERNAL_GRIB2_PATH=/opt/wps-4.7.0/grib2`;
- `-DUSE_JPEG2000 -DUSE_PNG`.

Somente o alvo aprovado é executado:

```sh
./compile ungrib
```

Executar `./compile` sem alvo tentaria construir todos os componentes e não
faz parte da receita.

### Proveniência e integridade

O build usa a tag oficial `v4.7.0`, commit
`5feccecd63384381b6942371c7a837f66e4ccb84`, e o archive da própria tag. Não
foi encontrado SHA-256 publicado pelo upstream. Dois downloads independentes,
cada um com 4.544.769 bytes, produziram:

```text
SHA-256 5232d20d7556338391b66aba45824d4fcd6c42712ebe9325f359f3c6cf043808
```

O valor é explicitamente local, não oficial. A imagem guarda versão, tag,
commit, URL, hash e origem do hash em
`/opt/wps-4.7.0/.mpas-era5-provenance`.

### Validação e limite funcional

O build terminou com código 0. `file` confirmou ELF 64-bit x86-64 dinâmico;
`ldd` encontrou `libgfortran`, `libm`, `libgcc_s` e `libc`, sem `not found`.
As bibliotecas GRIB2 são ligadas estaticamente. O smoke offline e read-only
também valida links, configuração, proveniência, diretórios GRIB2 e a
existência de:

- `Vtable.ECMWF`;
- `Vtable.ECMWF_sigma`;
- `Vtable.ERA-interim.ml`;
- `Vtable.ERA-interim.pl`.

Esses nomes foram inspecionados, não selecionados. Em especial, tabelas
ERA-Interim não se tornam automaticamente corretas para ERA5. A integração
funcional `ERA5 GRIB → ungrib → WPS intermediate` permanece pendente até que
variáveis, níveis, amostra real e Vtable sejam aprovados. Não foi criado GRIB
falso nem baixado dataset aleatório.

O build das bibliotecas internas e do código legado produziu avisos de
formatação, `tmpnam`, uso após `realloc`, tipos/ranks Fortran e receitas make
sobrescritas. Não houve erro de compilação ou linkagem; esses avisos continuam
como dívida técnica a observar quando dados reais forem processados.

Detalhes auditáveis estão em
[[../testing/validation-matrix|validation-matrix.md]] e a decisão de versão e
layout em [[../decisions/0004-wps-mpas-version-and-layout|ADR 0004]].

## MPAS-Model 8.4.1 — init_atmosphere no ciclo 0006

MPAS é um framework que compartilha infraestrutura entre cores. O core
`init_atmosphere` prepara campos estáticos, condições iniciais e, quando
aplicável, condições laterais; o core `atmosphere` integra a evolução do
estado. Eles geram executáveis separados. No ciclo 0006 somente
`init_atmosphere_model` foi construído.

### Proveniência, layout e comando

O source é um clone Git da tag oficial `v8.4.1`, preservado dentro da imagem
para que o `git describe` executado pelo Makefile registre a versão. Antes do
build, `git rev-parse HEAD` precisa ser exatamente:

```text
91c5eac175eebeaf4206bacd5cb50c39dff3c152
```

O layout mantém bibliotecas e modelo sem ambiguidade:

```text
/opt/mpas                         NETCDF, PNETCDF e PIO
/opt/mpas-model-8.4.1             source e artefatos MPAS
/opt/mpas-model -> /opt/mpas-model-8.4.1
```

O comando executado na imagem final foi:

```sh
make -j8 gnu \
    CORE=init_atmosphere \
    USE_PIO2=true \
    MPAS_ESMF=embedded
```

O target `gnu` usa os wrappers MPI `mpif90`, `mpicc` e `mpicxx`, que
encaminham compilação e linkagem ao GNU e às bibliotecas OpenMPI. O MPAS não
produz neste target um executável serial alternativo: MPI é parte da
arquitetura escolhida, embora uma execução futura possa usar um único rank.

Na release 8.4.1, `USE_PIO2` é mantido por compatibilidade, mas o Makefile
avisa que a variável é ignorada e detecta PIO2 por compilação/linkagem. A
receita ainda passa `USE_PIO2=true` para tornar a intenção explícita. A
evidência efetiva vem do resumo final, de `-DMPAS_PIO_SUPPORT`, das bibliotecas
`-lpiof -lpioc` e de símbolos PIO no executável. `NETCDF`, `PNETCDF` e
`PIO` apontam para `/opt/mpas`.

### Configuração comprovada

O resumo do próprio build e `.build_opts.framework`/
`.build_opts.init_atmosphere` comprovaram:

- core `init_atmosphere`, target GNU e MPI/`mpi_f08` habilitados;
- single precision default, `-DSINGLE_PRECISION`, sem `PRECISION=double`;
- otimização `-O3`, debugging desligado;
- OpenMP, offload OpenMP e OpenACC desligados;
- PIO 2.x detectado e PnetCDF presente;
- ESMF timekeeping embedded;
- MUSICA e PT-Scotch ausentes.

O build usou apenas componentes incluídos no source necessários a esse core,
como ESMF timekeeping embedded, SMIOL e ezXML. Não houve download ou
configuração manual de MMM-physics, UGWP, MUSICA, PT-Scotch ou outro externo.

### Artefatos e linkagem

A instalação preserva:

```text
init_atmosphere_model
namelist.init_atmosphere
streams.init_atmosphere
default_inputs/namelist.init_atmosphere
default_inputs/streams.init_atmosphere
```

`file` identificou ELF 64-bit PIE x86-64 dinâmico. `ldd` resolveu netCDF,
PnetCDF, MPI, GFortran, HDF5, zlib e bibliotecas de sistema, sem `not found`.
PIO 2.7.0 foi construído static; por isso sua ausência no `ldd` é esperada.
`nm` confirmou símbolos definidos `PIOc_Init_Intracomm`, `PIOc_createfile` e
`PIOc_openfile`, enquanto `ncmpi_create`/`ncmpi_open` aparecem como
referências resolvidas pela `libpnetcdf.so.8` vista no `ldd`.

### Validação e limites

O [`mpas-init.sh`](../../scripts/validate/mpas-init.sh) roda sem rede, com
raiz read-only e tmpfs. Ele valida proveniência Git, layout, defaults,
configuração, interfaces, `file`, `ldd` e símbolos. A classificação é
deliberada:

- BUILD: PASS;
- STRUCTURAL/INSTALL SMOKE: PASS;
- FUNCTIONAL, mesh → `init_atmosphere`: PENDENTE;
- SCIENTIFIC/REAL-DATA, mesh + static data + WPS/ERA5 → `init.nc`: PENDENTE.

A tag não fornece uma suíte autocontida aplicável a esse recorte sem entradas;
os helpers upstream de setup também requerem configuração e dados. Nenhuma
mesh, GRIB, ERA5, `static.nc`, `init.nc` ou LBC foi criada para fabricar um
resultado funcional.

O compilador emitiu avisos de código legado no ESMF embedded e nas ferramentas
de Registry, além de avisos make; não houve erro. A árvore Git completa aumenta
o tamanho da imagem, trade-off aceito para preservar `git describe` e a
proveniência solicitada.

## MPAS-Model 8.4.1 — atmosphere no ciclo 0007

`atmosphere_model` integra no tempo o estado atmosférico preparado pelo
`init_atmosphere_model`. O ciclo 0007 construiu o core na mesma árvore
`/opt/mpas-model-8.4.1`, preservando o source, o symlink e os artefatos do
core init.

### Externals e lookup tables reproduzíveis

O `src/core_atmosphere/Externals.cfg` da tag 8.4.1 exige dois repositórios
para a física. As tags oficiais foram resolvidas e fixadas em 2026-08-05:

| Dependência | Repositório | Tag | Commit |
|---|---|---|---|
| MMM-physics | `https://github.com/NCAR/MMM-physics.git` | `20250616-MPASv8.3` | `a4baf7f3243d1db0dbc5f63473f895bdbdc05c30` |
| UGWP | `https://github.com/NOAA-GSL/UGWP.git` | `MPAS_20241223` | `c1c893edcf171af5639af60e3a3a528816f6cc2b` |
| MPAS-Data | `https://github.com/MPAS-Dev/MPAS-Data.git` | `v8.2` | `c57dbc7be629802c6e848770a9e44b9bc602be41` |

Cada checkout precisa estar detached no commit esperado e sem mudanças
rastreadas; qualquer divergência falha o build. O `manage_externals` usado
pela física requer Python 3, por isso Python 3.12.3 foi instalado numa camada
posterior ao init já validado.

O script upstream `checkout_data_files.sh` usa deliberadamente
`mpas_vers="8.2"`. Esse valor não foi alterado. A árvore MPAS-Data `v8.2`
contém `COMPATIBILITY` compatível com 8.2 e 16 lookup tables. O Dockerfile
resolve o commit, verifica a compatibilidade, copia os arquivos para
`physics_wrf/files` e grava um manifesto SHA-256 antes do `make`. Quando o
script upstream roda, ele reconhece os arquivos já presentes e não inicia
download mutável. As tabelas e sources externos ficam somente na imagem.

### Build incremental e configuração efetiva

O comando executado foi:

```sh
make -j8 gnu \
    CORE=atmosphere \
    USE_PIO2=true \
    MPAS_ESMF=embedded
```

Nenhum `make clean` foi usado. A proteção de compatibilidade do MPAS comparou
as opções do framework; `.build_opts.framework`,
`.build_opts.init_atmosphere` e `.build_opts.atmosphere` são iguais. O hash
do executável init e o conteúdo do archive framework permaneceram iguais. O
Makefile executou novamente `ar -ru` e relinkou geradores, alterando metadata
do archive sem recompilar seus objetos Fortran.

O resumo do build e `.build_opts.atmosphere` comprovam:

- `CORE=atmosphere`, target GNU, wrappers MPI e interface `mpi_f08`;
- single precision com `-DSINGLE_PRECISION` e otimização `-O3`;
- PIO 2.x autodetectado, PnetCDF presente e ESMF timekeeping embedded;
- DEBUG, OpenMP, offload OpenMP, OpenACC, MUSICA e PT-Scotch desligados.

`USE_PIO2=true` registra intenção, mas não seleciona sozinho PIO2 na 8.4.1.
A evidência efetiva é o resumo, as opções, a linkagem e os símbolos.

### Artefatos, linkagem e classificação

A árvore final contém os dois executáveis e seus defaults:

```text
atmosphere_model
namelist.atmosphere
streams.atmosphere
default_inputs/namelist.atmosphere
default_inputs/streams.atmosphere
init_atmosphere_model
namelist.init_atmosphere
streams.init_atmosphere
default_inputs/namelist.init_atmosphere
default_inputs/streams.init_atmosphere
```

`file` identificou `atmosphere_model` como ELF 64-bit PIE x86-64 dinâmico.
`ldd` resolveu MPI, netCDF e PnetCDF sem `not found`. Como PIO continua
static, não se espera `libpio.so` no `ldd`; `nm` confirmou símbolos
`PIOc_*` definidos no executável e referências `ncmpi_*` resolvidas por
`libpnetcdf.so.8`.

O `scripts/validate/mpas-atmosphere.sh` executou sem rede, com filesystem
read-only e tmpfs, e a regressão `scripts/validate/mpas-init.sh` passou na
imagem combinada. As regressões PIO e PnetCDF também passaram em quatro ranks.
A classificação permanece:

- BUILD atmosphere: PASS;
- STRUCTURAL/INSTALL SMOKE atmosphere: PASS;
- FUNCTIONAL, `init.nc` + mesh + partição → `atmosphere_model`: PENDENTE;
- SCIENTIFIC, primeira simulação e avaliação dos campos: PENDENTE.

Nenhuma previsão foi executada, e nenhuma mesh, ERA5, GRIB, `static.nc`,
`init.nc`, LBC ou saída científica foi criada. WPS e METIS não foram
reexecutados porque suas camadas ficaram em cache e nenhum arquivo ou contrato
desses componentes foi alterado.
