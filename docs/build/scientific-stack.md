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
arquivo. O futuro MPAS será compilado com `USE_PIO2=true` e encontrará
`NETCDF`, `PNETCDF` e `PIO` no mesmo prefixo `/opt/mpas`.

A arquitetura aprovada preserva HDF5 1.14.6 e netCDF-C 4.10.1 seriais. O
primeiro caso MPAS usa o `io_type=pnetcdf` padrão, de modo que o caminho
paralelo validado é independente de HDF5:

```text
MPAS (futuro, USE_PIO2=true)
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
