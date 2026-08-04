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
