# Ciclo 0003 — Adicionar PIO2 sobre PnetCDF

## Objetivo de aprendizado

Este ciclo ensina como introduzir uma biblioteca de abstração de I/O paralelo
sem presumir que toda a stack de armazenamento precisa ser paralela. O ponto
central não é apenas compilar PIO: é separar requisito documental, capacidade
detectada pelo build, backend selecionado em runtime e necessidade real da
aplicação.

Ao final, o leitor deve conseguir explicar:

1. qual papel PIO desempenha entre MPAS e as bibliotecas de arquivo;
2. por que PnetCDF oferece I/O paralelo sem HDF5 paralelo;
3. por que a falta de NetCDF paralelo não impede este PIO;
4. quais IOTYPEs foram realmente compilados;
5. como CMake descobre capacidades em vez de apenas versões;
6. como o smoke test prova a cadeia PIO → PnetCDF → MPI-IO;
7. por que uma suíte upstream e um teste instalado respondem perguntas
   diferentes.

## Estado inicial real

Antes de mudar arquivos, foram executados:

```sh
git status
git log --oneline -10
```

O `HEAD` real era:

```text
2d6c5eec92766c6a7ca4018070e2aa6a21adc192
build: add PnetCDF MPI-IO support
```

`docs/project/current-state.md` ainda descrevia o estado pré-commit do ciclo
0002 e apontava para `e1f86a4`. Isso demonstra por que o workflow exige
inspeção Git: documentação de estado é uma fotografia que pode ficar
desatualizada; o repositório real decide qual base está sendo modificada.

A stack inicial relevante era:

```text
HDF5 1.14.6 serial
    ↓
netCDF-C 4.10.1 com --disable-parallel4
    ↓
netCDF-Fortran 4.6.3

PnetCDF 1.15.0 com MPI-IO
    ↓
OpenMPI 4.1.6
```

HDF5/netCDF e PnetCDF são caminhos que coexistem. PnetCDF não é uma camada
obrigatoriamente colocada sobre HDF5: ele implementa acesso paralelo aos
formatos CDF clássicos diretamente por MPI-IO.

## O que é PIO

PIO, ou ParallelIO, fornece uma interface que separa a decomposição dos dados
da biblioteca concreta que grava o arquivo. Uma aplicação científica distribui
um campo entre ranks; PIO conhece essa decomposição, rearranja os dados quando
necessário e delega a operação a um IOTYPE.

Os IOTYPEs relevantes são:

| IOTYPE | Backend | Paralelismo de arquivo |
|---|---|---|
| `PIO_IOTYPE_PNETCDF` | PnetCDF | MPI-IO paralelo |
| `PIO_IOTYPE_NETCDF` | netCDF clássico | I/O serial nos ranks de I/O |
| `PIO_IOTYPE_NETCDF4C` | netCDF-4/HDF5 | criação serial |
| `PIO_IOTYPE_NETCDF4P` | netCDF-4/HDF5 paralelo | MPI + HDF5 paralelo |

O MPAS não precisa conhecer todos os detalhes do backend. Ele será compilado
com `USE_PIO2=true`, e a configuração de streams escolhe o `io_type`. A
documentação oficial registra `pnetcdf` como padrão. Portanto, a pergunta
correta para o primeiro caso não é “temos todos os IOTYPEs?”, mas “o backend
padrão necessário está disponível e funciona?”.

## Pesquisa e conflito oficial

A pesquisa consultou a própria tag da release, não apenas a documentação
publicada no site:

- repositório e página oficial de releases NCAR/ParallelIO;
- `README.md` da tag;
- `doc/source/Installing.txt` da tag;
- `CMakeLists.txt`;
- módulos/testes CMake;
- despachos C dos backends;
- MPAS-Atmosphere User's Guide oficial.

O `README.md` diz que NetCDF-C deve ser compilado com MPI, o que implica
HDF5 paralelo. O `Installing.txt` diz que isso é ideal. Como as duas frases
pertencem à mesma release, escolher uma por conveniência seria frágil.

A resolução veio do código de build.

### Como o CMake testa NetCDF paralelo

`cmake/TryNetCDF_PARALLEL.c` inclui `netcdf_meta.h` e verifica:

```c
#if NC_HAS_PARALLEL==1
    return 0;
#else
    /* falha de compilação intencional */
#endif
```

O teste não tenta linkar `nc_create_par` nem `nc_open_par`. Ele usa a
capacidade que netCDF-C publicou no header. O resultado alimenta
`HAVE_NETCDF_PAR`.

Falhar esse teste não executa `message(FATAL_ERROR)`. PIO continua
configurando os backends clássicos. O detalhe surpreendente da release 2.7.0 é
que a macro interna `_NETCDF4` só é definida quando `HAVE_NETCDF_PAR` é
verdadeiro. Consequentemente, o build atual perde simultaneamente NETCDF4P e
NETCDF4C.

Isso não significa que a biblioteca netCDF-C deixou de conhecer NetCDF-4.
`HAVE_NETCDF4` passou. Significa que a condicional escolhida pelo source PIO
não compila seus caminhos NetCDF-4 nessa combinação.

## Seleção da versão

`pio2_6_5` começou como candidata, não como decisão. A consulta oficial
mostrou `pio2_7_0` como release estável atual, publicada em 2026-04-29.

Os probes descartáveis deram uma razão empírica adicional:

| Release | Resultado relevante |
|---|---|
| 2.6.5 | `pio_rearr_opts` falhou com OMPIO e também com ROMIO |
| 2.7.0 | 109/109 testes passaram |

Escolher 2.6.5 apenas porque foi citada inicialmente adotaria uma versão
anterior com uma falha reproduzida que a atual não apresentou.

## Arquitetura escolhida

A opção aprovada preserva HDF5 e netCDF seriais:

```text
MPAS futuro
  USE_PIO2=true
        ↓
PIO 2.7.0
  PIO_IOTYPE_PNETCDF
        ↓
PnetCDF 1.15.0
        ↓
MPI-IO
        ↓
OpenMPI
```

Os IOTYPEs efetivos são:

```text
PNETCDF=1
NETCDF=1
NETCDF4C=0
NETCDF4P=0
```

NetCDF-4 paralelo exigiria reconstruir HDF5 com MPI e depois reconstruir
netCDF-C/Fortran. Esse custo só faz sentido diante de um requisito concreto,
como formato NetCDF-4, compressão/filtros HDF5 ou um caso MPAS que escolha
`io_type=netcdf4`.

As alternativas e os riscos completos estão no
[[../../docs/decisions/0002-pio2-pnetcdf-with-serial-netcdf|ADR 0002]].

## Reprodutibilidade dos downloads

O tarball oficial é baixado pela tag exata:

```text
https://github.com/NCAR/ParallelIO/archive/refs/tags/pio2_7_0.tar.gz
```

Antes da extração, o build verifica:

```text
cce83743156ae723e7890931c2b48dcfe7ea8a276962dc4429f839d8f58d4a5a
```

Esse SHA-256 foi calculado localmente sobre o artefato oficial. Ele detecta
alteração do conteúdo usado pelo projeto, mas não deve ser descrito como um
checksum publicado pelo upstream.

PIO usa dois auxiliares durante o build CMake. Se não forem fornecidos, a
configuração pode cloná-los sem um commit fixado. O Dockerfile evita isso:

```text
CMake_Fortran_utils 05ff8d8e4c88786e94a02c853d3ff921113d785c
genf90              4816965ba946731352bad195b7d946a5fe682ff5
```

Cada repositório é colocado em checkout detached, `git rev-parse HEAD` é
comparado ao valor esperado e o caminho é passado ao PIO. Fixar apenas a
versão principal e deixar ferramentas geradoras mutáveis ainda permitiria que
o mesmo Dockerfile produzisse fontes diferentes no futuro.

## Por que CMake

Autotools e CMake são suportados pela release. CMake foi escolhido porque a
orientação do MPAS cita diretamente:

```text
PIO_ENABLE_TIMING=OFF
```

Além disso, CMake:

- registra descoberta de NetCDF-C, NetCDF-Fortran, PnetCDF e MPI;
- executa testes de capacidade como `HAVE_NETCDF_PAR`;
- oferece `PIO_ENABLE_TESTS`;
- usa CTest para uma contagem auditável;
- aceita os caminhos fixados dos auxiliares.

As opções principais foram:

```sh
CC=mpicc FC=mpifort cmake \
  -S pio-src \
  -B pio-build \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/opt/mpas \
  -DCMAKE_PREFIX_PATH=/opt/mpas \
  -DPIO_ENABLE_FORTRAN=ON \
  -DPIO_ENABLE_TIMING=OFF \
  -DPIO_ENABLE_TESTS=ON \
  -DWITH_PNETCDF=ON \
  -DBUILD_SHARED_LIBS=OFF
```

`CC=mpicc` e `FC=mpifort` selecionam os wrappers MPI. Um wrapper adiciona
headers e bibliotecas MPI ao compilador GNU base; ele não é outro compilador.

`CMAKE_PREFIX_PATH=/opt/mpas` orienta a descoberta para a stack adotada.
`CMAKE_INSTALL_PREFIX=/opt/mpas` define onde o PIO será instalado.

`PIO_ENABLE_TIMING=OFF` evita GPTL conforme a recomendação MPAS.
`WITH_PNETCDF=ON` torna PnetCDF uma capacidade exigida, não silenciosamente
opcional. `PIO_ENABLE_TESTS=ON` mantém a suíte.

`PIO_ENABLE_NETCDF_INTEGRATION=OFF` merece cuidado: ele desliga a integração
que apresenta PIO como uma implementação da API netCDF. Não desliga
`PIO_IOTYPE_NETCDF`, que é um backend usado pela API PIO.

## Construção e a corrida Fortran

As bibliotecas C e Fortran foram construídas com paralelismo:

```sh
cmake --build pio-build --target pioc piof --parallel 8
```

No alvo de testes, dois templates geram fontes que declaram o mesmo nome de
módulo Fortran. Com build concorrente, ambos podem tentar escrever o mesmo
arquivo `.mod`. O sintoma é uma corrida de build, não uma falha científica de
runtime.

O alvo foi construído serialmente:

```sh
cmake --build pio-build --target tests --parallel 1
```

Isso conserva todos os executáveis e toda a cobertura; apenas remove a
concorrência durante a compilação.

## Testes executados

### 1. Suíte oficial

```sh
OMPI_ALLOW_RUN_AS_ROOT=1 \
OMPI_ALLOW_RUN_AS_ROOT_CONFIRM=1 \
OMPI_MCA_rmaps_base_oversubscribe=1 \
ctest \
  --test-dir pio-build \
  --output-on-failure \
  --timeout 120 \
  --parallel 1
```

Resultado:

```text
100% tests passed, 0 tests failed out of 109
Total Test time (real) = 37.12 sec
```

A suíte cobre APIs C/Fortran, decomposições, rearranjadores, modos async,
operações de arquivo e exemplos. Ela prova que o source configurado funciona
no diretório de build.

### 2. Verificação da instalação

O build conferiu:

```text
/opt/mpas/include/pio.h
/opt/mpas/include/pio.mod
/opt/mpas/lib/libpioc.a
/opt/mpas/lib/libpiof.a
/opt/mpas/lib/libpio.settings
/opt/mpas/lib/cmake/PIO/PIOConfig.cmake
```

`libpio.settings` registrou PIO 2.7.0, Fortran habilitado, PnetCDF habilitado
e NetCDF/HDF5 parallel I/O desabilitado.

### 3. Smoke da interface instalada

O script `scripts/validate/pio.sh` monta o repositório como somente leitura,
compila `tests/smoke/pio_pnetcdf.c` contra a instalação final e usa tmpfs
para os arquivos gerados.

O programa:

1. inicializa MPI;
2. consulta os quatro IOTYPEs;
3. cria um sistema PIO com todos os ranks de computação e um rank de I/O;
4. define uma decomposição com uma posição por rank;
5. solicita explicitamente `PIO_IOTYPE_PNETCDF`;
6. cria CDF-2;
7. escreve `1000 + rank`;
8. fecha e reabre o arquivo pelo mesmo IOTYPE;
9. relê e compara o valor de cada rank;
10. libera a decomposição, finaliza PIO e finaliza MPI.

Foram executados dois launchers:

```sh
mpiexec --allow-run-as-root --oversubscribe -n 4 ./pio_pnetcdf

mpiexec --allow-run-as-root --oversubscribe \
  --mca io romio321 -n 4 ./pio_pnetcdf
```

Os dois passaram. A segunda seleção é local ao comando; não muda a
configuração global do OpenMPI.

`ncmpidump` mostrou:

```text
// file format: CDF-2 (large file)
rank_value = 1000, 1001, 1002, 1003 ;
```

Esse resultado prova que dados distintos atravessaram coletivamente:

```text
C → PIO → PnetCDF → MPI-IO → OpenMPI
```

### 4. Símbolos e linkagem

`nm` encontrou `PIOc_Init_Intracomm` no executável. Como PIO foi linkado
estaticamente, `ldd` não lista `libpioc.so`; ele lista as dependências
dinâmicas usadas pelo código incorporado:

```text
/opt/mpas/lib/libpnetcdf.so.8
/opt/mpas/lib/libnetcdf.so.22
libmpi.so.40
```

Isso diferencia “o header compilou” de “o executável usa as bibliotecas
esperadas em runtime”.

### 5. Regressão PnetCDF

O teste do ciclo anterior foi repetido dentro da nova imagem:

```sh
PNETCDF_IMAGE=mpas-era5:pio-2.7.0 \
  ./scripts/validate/pnetcdf.sh
```

Resultado:

- netCDF-C 4.10.1 preservado;
- netCDF-Fortran 4.6.3 preservado;
- PnetCDF 1.15.0 preservado;
- smoke Fortran em quatro ranks aprovado;
- CDF-5 com `rank_value = 0, 1, 2, 3`.

Uma nova camada não está validada se ela quebra a camada anterior.

## Arquivos modificados

| Arquivo | Papel |
|---|---|
| `Dockerfile` | baixa, verifica, configura, testa e instala PIO |
| `tests/smoke/pio_pnetcdf.c` | prova funcional mínima do backend PnetCDF |
| `scripts/validate/pio.sh` | automatiza instalação, IOTYPEs, linkagem e dois MPI-IO |
| `README.md` | mostra PIO 2.7.0 concluído |
| `docs/build/scientific-stack.md` | documenta build e arquitetura |
| `docs/architecture/project-graph.md` | conecta MPAS/PIO/PnetCDF/MPI-IO |
| `docs/references/*` | fixa fontes, release, hash e auxiliares |
| `docs/testing/validation-matrix.md` | preserva resultados contáveis |
| `docs/project/current-state.md` | corrige o HEAD e registra o novo estado |
| `docs/decisions/0002-*.md` | preserva a decisão e alternativas |
| índices em `docs/` e `learning/` | tornam ADR e nota localizáveis |

## Falhas e como interpretá-las

### PIO 2.6.5: `pio_rearr_opts`

O teste falhou com OMPIO e continuou falhando com ROMIO. Isso distinguiu o
sintoma do problema PnetCDF/OMPIO visto no ciclo anterior. A release atual
2.7.0 passou, então não houve justificativa para depurar ou adotar 2.6.5.

### Build paralelo dos testes 2.7.0

A falha ocorreu durante geração/compilação de módulos Fortran de dois alvos.
Construir o alvo serialmente eliminou a corrida e todos os testes passaram.
Isso é uma limitação de build upstream registrada, não uma falha ocultada.

### `HAVE_NETCDF_PAR` falhou

Essa falha era esperada e informativa: a stack declara NetCDF serial. O CMake
continuou, PnetCDF foi encontrado e a suíte passou. Transformá-la em “erro a
corrigir” teria levado a uma reconstrução não requerida.

### OMPIO

No ciclo 0002, casos PnetCDF mostraram escrita incompleta com OMPIO e
selecionaram ROMIO. Neste ciclo, o smoke PIO passou com ambos. O resultado
menor não invalida a falha anterior nem prova OMPIO para todos os padrões de
acesso; por isso ROMIO continua disponível como seleção local de diagnóstico.

## Trade-offs e dívida técnica

- o primeiro caso não dispõe de NetCDF-4 por PIO;
- o backend NetCDF clássico está disponível, mas não recebeu smoke dedicado;
- a integração MPAS real ainda não foi executada;
- shared PIO não foi construída nem testada;
- auxiliares fixados por commit ainda dependem da disponibilidade futura dos
  repositórios Git;
- o SHA-256 PIO é local, não publicado pelo upstream;
- o build dos testes precisa permanecer serial enquanto a corrida upstream
  existir;
- digest Ubuntu, pacotes APT e checksum HDF5 continuam dívidas herdadas.

Essas limitações são aceitáveis porque não comprometem o caminho aprovado do
primeiro caso. Elas se tornam bloqueantes apenas se um requisito futuro mudar.

## Como reproduzir

```sh
docker build \
  --progress=plain \
  --build-arg BUILD_JOBS=8 \
  -t mpas-era5:pio-2.7.0 .

./scripts/validate/pio.sh

PNETCDF_IMAGE=mpas-era5:pio-2.7.0 \
  ./scripts/validate/pnetcdf.sh
```

Se o usuário não tiver acesso direto ao socket Docker, os comandos podem ser
executados no grupo Docker conforme a política local da máquina. Nenhum teste
precisa preservar o CDF gerado: os scripts usam armazenamento efêmero.

## Checklist conceitual

Depois deste ciclo, o leitor deve conseguir responder:

- PIO substitui PnetCDF? Não; PIO delega a ele.
- PnetCDF precisa de HDF5 paralelo? Não para CDF/MPI-IO.
- PIO rejeita netCDF serial? Não nesta release/configuração.
- O que fica indisponível? NETCDF4C e NETCDF4P no build PIO atual.
- O primeiro MPAS precisa de NETCDF4P? Não há necessidade comprovada enquanto
  usar o `io_type=pnetcdf` padrão.
- Por que executar CTest e smoke? CTest valida o build upstream; o smoke valida
  a instalação, o backend escolhido, a linkagem e o arquivo produzido.
- Por que não reconstruir tudo “para garantir”? Porque cada reconstrução muda
  a arquitetura e invalida evidência já obtida; capacidade sem requisito também
  tem custo de manutenção.

## Estado do ciclo

Implementação, testes, revisão técnica, ADR e documentação foram preparados no
worktree. Commit e push permanecem condicionados ao relatório pré-commit e à
aprovação explícita do usuário, conforme `AGENTS.md`.
