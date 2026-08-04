# Ciclo 0002 — adicionar PnetCDF com MPI-IO

## Objetivo e resultado

Este ciclo adiciona PnetCDF 1.15.0 à imagem científica, preservando todas as
camadas anteriores. A biblioteca foi instalada em `/opt/mpas` com interface
Fortran, bibliotecas shared e static e backend MPI-IO. GIO foi desabilitado
explicitamente.

O resultado funcional validado é:

```text
Fortran
  ↓
API Fortran moderna do PnetCDF
  ↓
PnetCDF 1.15.0
  ↓
MPI-IO / ROMIO
  ↓
OpenMPI 4.1.6
  ↓
arquivo CDF-5
```

Quatro ranks criaram coletivamente um arquivo, escreveram partes distintas,
fecharam, reabriram e releram seus dados. O conteúdo final foi:

```text
rank_value = 0, 1, 2, 3 ;
```

PIO2, METIS, WPS, MPAS e ERA5 não fazem parte deste ciclo.

## O problema de I/O em HPC

Paralelizar cálculo e paralelizar I/O são problemas relacionados, mas
diferentes.

Na computação paralela, vários processos executam cálculos ao mesmo tempo. Por
exemplo, cada rank pode atualizar um subconjunto das células de uma malha
atmosférica. Isso reduz o tempo de cálculo se o trabalho e a comunicação forem
bem distribuídos.

No I/O paralelo, esses processos precisam armazenar ou recuperar seus
subconjuntos sem transformar um único rank em gargalo. Uma solução ingênua
seria todos enviarem seus resultados ao rank 0 e somente ele gravar o arquivo.
Isso concentra memória, comunicação e escrita em um processo. Outra solução
seria criar um arquivo por rank, o que pode produzir milhares de arquivos e
dificultar análise, metadados e reinício.

O objetivo típico é permitir que muitos ranks participem da criação de um
arquivo lógico único, mantendo uma visão coerente das dimensões, variáveis e
offsets.

## O que é MPI-IO

MPI-IO é a parte do padrão MPI dedicada a I/O paralelo. Ela oferece operações
para:

- abrir e fechar arquivos coletivamente;
- representar posições e tamanhos com tipos adequados a arquivos grandes;
- descrever quais regiões do arquivo pertencem a cada rank;
- realizar operações independentes ou coletivas;
- fornecer hints ao runtime sobre agregação, striping e acesso.

Uma operação coletiva não significa que todos os ranks escrevem os mesmos
bytes. Significa que todos participam da chamada e o runtime pode coordenar os
acessos. Cada rank ainda pode fornecer um `start` e um `count` diferente.

No smoke test, para `N` ranks, a dimensão global tem tamanho `N`. O rank
`r` escreve um inteiro na posição `r + 1` da interface Fortran:

```text
rank 0 → posição 1 → valor 0
rank 1 → posição 2 → valor 1
rank 2 → posição 3 → valor 2
rank 3 → posição 4 → valor 3
```

O OpenMPI instalado contém duas implementações de componentes MPI-IO: OMPIO e
ROMIO. O ciclo não troca OpenMPI. Ele seleciona ROMIO somente nos comandos
PnetCDF porque esse caminho passou nos testes coletivos desta versão.

## O que é PnetCDF

PnetCDF, ou Parallel netCDF, fornece uma interface de alto nível para
armazenamento paralelo nos formatos CDF. Em vez de a aplicação calcular
manualmente todos os offsets de bytes via MPI-IO, ela trabalha com conceitos
netCDF: arquivo, dimensão, variável, atributo, `start` e `count`.

O PnetCDF traduz essas operações para MPI-IO. Isso mantém a descrição
autocontida do conjunto de dados e permite que múltiplos ranks acessem um
arquivo compartilhado.

As interfaces instaladas incluem C, C++, Fortran 77 e Fortran 90. O consumidor
futuro, MPAS, é majoritariamente Fortran; por isso o teste próprio usa
`use pnetcdf`, e não apenas a API C.

## PnetCDF versus netCDF-C

Os nomes são parecidos, mas as bibliotecas não são intercambiáveis:

- netCDF-C é a implementação principal das APIs netCDF e, nesta stack, oferece
  netCDF-4 sobre HDF5, além dos formatos clássicos;
- PnetCDF é orientado ao acesso paralelo aos formatos CDF por MPI-IO;
- a integração opcional do PnetCDF com NetCDF-4 não foi habilitada;
- PnetCDF não precisa ligar com netCDF-C nem com HDF5 para seu caminho CDF
  básico.

Assim, instalar PnetCDF não exigiu transformar o HDF5 serial em paralelo nem
reconstruir HDF5, netCDF-C ou netCDF-Fortran. O `ldd` de
`libpnetcdf.so.8` mostra MPI e runtimes de compilador, não HDF5/netCDF-C.

## CDF-1, CDF-2 e CDF-5

CDF é o formato binário clássico do netCDF. Em nível introdutório:

- CDF-1 é o formato clássico original e possui limites menores para dimensões,
  variáveis e offsets;
- CDF-2, também chamado 64-bit offset, amplia offsets para acomodar arquivos e
  variáveis maiores, mantendo o modelo de dados clássico;
- CDF-5, mostrado pelo `ncmpidump` como `64-bit data`, amplia também tipos e
  contagens, sendo apropriado para conjuntos paralelos grandes.

Esses formatos não são HDF5. Eles têm cabeçalho e layout próprios e podem ser
acessados diretamente por MPI-IO. O smoke usa
`NF90_64BIT_DATA` para pedir CDF-5.

## Toolchain e wrappers MPI

A release exige compilador C MPI e `m4`; C++, F77 e F90 são opcionais de
acordo com as interfaces desejadas. Como Fortran é obrigatório para este
projeto, foram verificados:

```sh
command -v mpicc
command -v mpicxx
command -v mpifort
command -v mpif77
mpicc --showme
mpifort --showme
```

Wrappers como `mpicc` e `mpifort` não são compiladores novos. Eles chamam o
compilador base e acrescentam include paths, módulos e bibliotecas corretos do
MPI. A validação mostrou:

```text
mpicc   → gcc + includes/libs OpenMPI
mpifort → gfortran + módulos/libs Fortran OpenMPI
```

Usar `gcc` ou `gfortran` diretamente exigiria reproduzir manualmente essas
opções e poderia misturar headers ou bibliotecas de outra implementação.
Para uma biblioteca cujo backend é MPI-IO, os wrappers são parte da
correção, não apenas conveniência.

O PnetCDF documenta variáveis próprias para selecioná-los:

```sh
MPICC=mpicc
MPICXX=mpicxx
MPIF77=mpif77
MPIF90=mpifort
```

O resultado instalado registrou exatamente `/usr/bin/mpicc`,
`/usr/bin/mpicxx`, `/usr/bin/mpif77` e `/usr/bin/mpifort`.

## Release, proveniência e integridade

A release oficial é PnetCDF 1.15.0, publicada em 1º de julho de 2026. Foi
usado o tarball de release:

```text
https://parallel-netcdf.github.io/Release/pnetcdf-1.15.0.tar.gz
```

Uma tag ou snapshot gerado pelo GitHub não foi usado como substituto.

O download foi repetido e o SHA-256 local coincidiu nas duas cópias:

```text
39813fe91ec901c7cfca3212731edbb5201029ebf55caeaaaa08d9e33c6bad65
```

A página Download oficial publica SHA-1, não SHA-256. O SHA-1 local também
coincidiu com o valor upstream
`fec63e5d1cdb4de4f3fd85f11be45294d4a8ed66`. A documentação atribui
corretamente somente o SHA-1 ao upstream; o Dockerfile verifica o SHA-256
calculado localmente antes de extrair o tarball.

Na consulta ao vivo deste ciclo, a página Download já listava 1.15.0. A
possível defasagem entre a página e o repositório não estava mais presente.

## Configuração usada

Depois de ler integralmente o `INSTALL` contido no próprio tarball e conferir
`./configure --help`, o build usou:

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

Fortran é habilitado por padrão; `--disable-fortran` seria a opção para
removê-lo. Não foi inventada uma flag `--enable-fortran`.

O `INSTALL` informa shared desabilitado e static habilitado por padrão. O
`configure --help` gerado pelo artefato exibiu shared e static habilitados.
Como as duas fontes pertencem à mesma release e divergem, as duas flags
explícitas eliminam dependência do default e registram a intenção aprovada.

Os seguintes recursos permaneceram desabilitados:

- integração NetCDF-4;
- ADIOS;
- subfiling;
- burst buffering;
- profiling;
- thread safety.

## GIO e a escolha MPI-IO

GIO é um backend introduzido em PnetCDF 1.15.0. Ele agrega e redistribui
requisições e inclui otimizações voltadas a sistemas paralelos como Lustre. A
release tornou GIO o backend padrão. As release notes descrevem agregação,
redistribuição e otimizações Lustre, mas não dão uma justificativa histórica
separada para o default; interpretar a mudança como priorização desse caminho
otimizado é uma inferência a partir das capacidades publicadas.

O projeto escolheu `--disable-gio` porque:

- MPI-IO é a arquitetura tradicional, menor e melhor para o primeiro ciclo de
  aprendizado;
- o usuário pode observar diretamente a relação PnetCDF → MPI-IO → OpenMPI;
- ainda não existe caso MPAS ou medição que justifique otimização GIO/Lustre;
- GIO pode ser comparado experimentalmente em um ciclo futuro.

Desabilitar GIO não desabilita I/O paralelo. Ele seleciona o driver MPI-IO do
PnetCDF.

## Shared, static e `PNETCDF`

`--enable-shared` instala uma biblioteca carregada em runtime, neste caso
`libpnetcdf.so.8`. Ela reduz duplicação e permite que `ldd` revele a
resolução efetiva.

`--enable-static` instala `libpnetcdf.a`. Ela pode ser incorporada ao
executável no link, mas exige que dependências e ordem de link sejam tratadas
explicitamente.

As duas foram pedidas para manter flexibilidade de builds futuros. A validação
confere a existência de ambas.

O ambiente final contém:

```sh
ENV NETCDF=/opt/mpas
ENV PNETCDF=/opt/mpas
```

`PNETCDF` não carrega a biblioteca por si só. É uma convenção de descoberta
usada por sistemas de build como o do MPAS. `PATH`, `LD_LIBRARY_PATH`,
`CPPFLAGS` e `LDFLAGS` continuam apontando para o prefixo.

## Como o Dockerfile executa o ciclo

A nova seção vem depois de netCDF-Fortran e faz:

1. verifica wrappers e mostra suas linhas base;
2. instala `bc` somente na nova camada, pois os benchmarks de `make ptest`
   usam essa calculadora;
3. baixa o tarball oficial;
4. valida SHA-256 antes da extração;
5. configura com os wrappers e flags aprovados;
6. compila com `make -j${BUILD_JOBS}`;
7. executa `make check`;
8. confirma ROMIO com `ompi_info`;
9. executa `make ptest` em 4 ranks;
10. instala em `/opt/mpas`;
11. verifica utilitários, versão, opções e bibliotecas;
12. remove somente a árvore temporária PnetCDF.

O build comprovou que todas as camadas anteriores foram recuperadas do cache.
Não houve mudança em zlib, HDF5, netCDF-C, netCDF-Fortran ou OpenMPI.

## `make check` e `make ptest`

`make check` executa os testes sequenciais oficiais. “Sequencial” aqui
descreve como o alvo é lançado; os programas ainda podem testar muitas APIs e
formatos. O resultado final foi:

```text
All sequential test programs have run successfully.
```

Os resumos tiveram `FAIL: 0` e `ERROR: 0`. Alguns testes marcados pelo
upstream como XFAIL produziram o resultado esperado.

`make ptest` lança a suíte paralela padrão em 4 processos. Foram exercitados:

- testes C, C++, F77 e F90;
- operações coletivas, não bloqueantes, fill e redefinição;
- exemplos C/C++/F77/F90 e tutorial;
- benchmarks C, WRF-IO e FLASH-IO.

O comando foi:

```sh
make ptest \
  TESTMPIRUN="mpiexec --allow-run-as-root --mca io romio321 -n NP" \
  TESTOUTDIR=/pnetcdf-test-output/pnetcdf-1.15.0
```

`NP` é substituído pelos scripts da release. A exceção
`--allow-run-as-root` é localizada porque o Docker build executa como root.
Ela não altera a configuração de segurança do OpenMPI e não significa que
jobs HPC normais devam rodar como root.

`make ptests` é a variante mais extensa, com 3, 4, 6 e 8 processos. Ela não
foi executada porque não era obrigatória neste ciclo. A validação aprovada é
`make check` mais `make ptest`.

## Smoke test versus integration test

Um smoke test responde “a instalação básica está disponível?”:

- executáveis estão no `PATH`;
- a versão é 1.15.0;
- o prefixo é `/opt/mpas`;
- Fortran está habilitado;
- GIO está desabilitado;
- shared/static existem.

Um integration test responde “as camadas realmente funcionam juntas?”:

- `mpifort` encontra `pnetcdf.mod`;
- o linker encontra `libpnetcdf`;
- quatro processos MPI chamam a API PnetCDF;
- PnetCDF usa MPI-IO;
- o arquivo criado contém os dados esperados;
- o executável carrega as bibliotecas pretendidas.

`scripts/validate/pnetcdf.sh` executa ambos contra a instalação final, não
contra objetos deixados na árvore de build.

## O código Fortran

O programa usa:

```fortran
use mpi
use pnetcdf
```

Depois de `MPI_Init`, obtém rank e tamanho:

```fortran
call MPI_Comm_rank(MPI_COMM_WORLD, rank, ierr)
call MPI_Comm_size(MPI_COMM_WORLD, nprocs, ierr)
```

As posições usam `MPI_OFFSET_KIND`, importante porque offsets de arquivo
podem exceder o intervalo de um inteiro padrão:

```fortran
start(1) = int(rank + 1, kind=MPI_OFFSET_KIND)
count(1) = 1_MPI_OFFSET_KIND
```

O arquivo é criado coletivamente como CDF-5:

```fortran
nf90mpi_create(MPI_COMM_WORLD, filename,
    ior(NF90_CLOBBER, NF90_64BIT_DATA), MPI_INFO_NULL, ncid)
```

O programa define uma dimensão global e uma variável inteira. Todos encerram o
modo de definição e chamam:

```fortran
nf90mpi_put_var_all(ncid, varid, write_buffer,
    start=start, count=count)
```

O sufixo `_all` indica operação coletiva. Cada rank fornece posição própria.
Depois de fechar, o teste reabre, consulta a variável e usa
`nf90mpi_get_var_all` para reler a mesma parte.

Cada status PnetCDF é verificado com `nf90mpi_strerror`. Erros MPI ou
PnetCDF chamam `MPI_Abort`, garantindo código não zero. Por fim,
`MPI_Allreduce` soma divergências de conteúdo; somente sucesso global imprime:

```text
PnetCDF MPI/Fortran smoke test passed with 4 ranks
```

## Como reproduzir

Build:

```sh
docker build --progress=plain \
  --build-arg BUILD_JOBS=8 \
  -t mpas-era5:pnetcdf-1.15.0 .
```

Validação instalada:

```sh
./scripts/validate/pnetcdf.sh
```

O script monta o repositório como somente leitura, usa um tmpfs de 64 MiB para
o CDF e remove o container ao terminar. O executável temporário fica em
`/tmp` do container. A chamada MPI possui timeout localizado de dois minutos.
Não há `docker prune`, credenciais ou remoção de imagens/containers alheios.

## Como interpretar `ncmpidump`

A opção `-k` respondeu:

```text
64-bit data
```

Para este arquivo, isso identifica CDF-5. A saída completa mostrou:

```text
dimensions:
    rank = 4 ;
variables:
    int rank_value(rank) ;
data:
    rank_value = 0, 1, 2, 3 ;
```

Isso prova estrutura e valores:

- uma dimensão de tamanho quatro;
- uma variável inteira indexada por essa dimensão;
- uma contribuição distinta de cada rank;
- ausência de fill values no resultado final.

`ncmpidump` não prova performance ou escalabilidade. Ele prova que o arquivo
é legível e semanticamente contém o esperado.

## Como interpretar `ldd`

`ldd` lista bibliotecas shared resolvidas em runtime. No executável:

```text
libpnetcdf.so.8 => /opt/mpas/lib/libpnetcdf.so.8
libmpi_mpifh.so.40 => /lib/x86_64-linux-gnu/libmpi_mpifh.so.40
libmpi.so.40 => /lib/x86_64-linux-gnu/libmpi.so.40
```

A primeira linha prova que o teste não carregou uma cópia PnetCDF do sistema.
As linhas MPI mostram a interface Fortran e a biblioteca principal OpenMPI.

O `ldd` da própria `libpnetcdf.so` também encontrou `libmpi.so.40`. Isso
confirma a dependência runtime PnetCDF → MPI. Endereços hexadecimais variam
entre execuções e não devem ser usados como identificador.

## Falhas, warnings e diagnóstico

### 1. OMPIO e escrita coletiva incompleta

Com o componente MPI-IO padrão OMPIO, `make ptest` falhou de duas formas:

- `f90tst_parallel4` releu fill values onde esperava valores de ranks;
- `examples/C/fill_mode` encontrou diferenças entre arquivos com e sem
  agregação intra-node.

Trocar OverlayFS por `/dev/shm` ou cache mount mudou onde a falha apareceu,
mas não a eliminou. Isso indicou comportamento de I/O/race, não simples falta
de permissão ou espaço.

`ompi_info --param io all --level 9` mostrou:

- OMPIO 4.1.6, prioridade 30;
- ROMIO 4.1.6, prioridade 10.

Assim, OMPIO era selecionado por padrão. Os testes PnetCDF usam hints
`cb_nodes` e referências ROMIO. Uma issue oficial OpenMPI 4.1.x também
registra falha no caminho OMPIO durante escrita paralela PnetCDF.

A hipótese foi testada, não assumida: com
`--mca io romio321`, o caso crítico, toda a suíte paralela e o teste próprio
passaram. A seleção ficou localizada nos comandos.

### 2. `bc` ausente

Depois de corrigir MPI-IO, todos os testes e exemplos passaram até
`benchmarks/C`. O script upstream tentou calcular tempo com `bc`, que não
é listado pelo `INSTALL`, e o alvo terminou com código 2.

`bc` foi instalado somente na nova camada PnetCDF. A repetição mostrou tempos
nos exemplos e todos os benchmarks passaram. Ele é dependência do harness de
teste, não da biblioteca PnetCDF em runtime.

### 3. Warnings Fortran de mismatch

GFortran emitiu warnings de mismatch de tipos em bindings e exemplos legados.
A própria configuração PnetCDF acrescentou `-fallow-argument-mismatch`.
Como a compilação e as suítes passaram, os warnings foram preservados e
documentados; não foram escondidos com flags adicionais.

### 4. Latência no bind mount

O primeiro teste próprio gravou o CDF em um diretório do host montado no
container. Ele passou, mas levou cerca de 28 minutos. Para um arquivo de quatro
inteiros, isso é latência anormal da combinação ROMIO/mount, não carga útil.

O script foi alterado para CDF em tmpfs. A primeira tentativa também colocou o
executável no tmpfs, que era `noexec`; `ldd` respondeu “not a dynamic
executable”. O desenho final mantém:

- executável em `/tmp` efêmero do container;
- CDF no tmpfs;
- timeout de dois minutos;
- inspeção antes de `docker run --rm` encerrar.

A execução final passou em aproximadamente 1,7 segundo.

### 5. Defaults documentais divergentes

O `INSTALL` e `configure --help` da mesma release divergem sobre shared.
Isso não foi resolvido inventando qual documento está “certo”; as duas opções
aprovadas foram explicitadas no comando.

## Arquivos criados

- `tests/smoke/pnetcdf_mpi.f90`;
- `scripts/validate/pnetcdf.sh`;
- `docs/decisions/0001-pnetcdf-mpiio-backend.md`;
- `learning/commits/0002-add-pnetcdf.md`.

## Arquivos modificados

- `Dockerfile`;
- `README.md`;
- `docs/build/scientific-stack.md`;
- `docs/README.md`;
- `docs/decisions/README.md`;
- `docs/project/current-state.md`;
- `docs/references/source-registry.md`;
- `docs/references/versions.lock.md`;
- `docs/testing/validation-matrix.md`;
- `docs/architecture/project-graph.md`;
- `learning/README.md`.

## Limitações

- `make ptests` não foi executado;
- os testes usam um único container e uma única máquina, não vários nós;
- tmpfs valida semântica e integração, não performance de um filesystem HPC;
- ROMIO é selecionado nos comandos PnetCDF, não globalmente;
- nenhuma comparação de desempenho GIO versus MPI-IO foi feita;
- PIO2 ainda não foi pesquisado, escolhido, compilado ou testado;
- a imagem Ubuntu e pacotes APT ainda não têm lock completo;
- o checksum HDF5 herdado continua ausente.

## O que aprender antes do próximo ciclo PIO2

Antes de decidir PIO2, o usuário deve conseguir explicar:

1. por que MPI paralelo não implica automaticamente I/O paralelo eficiente;
2. a diferença entre MPI-IO, PnetCDF e netCDF-C;
3. como `start` e `count` distribuem uma variável entre ranks;
4. quando usar operação coletiva e por que todos os ranks devem participar;
5. as diferenças introdutórias entre CDF-1, CDF-2, CDF-5 e netCDF-4/HDF5;
6. por que wrappers MPI evitam mistura de headers e bibliotecas;
7. o papel de PnetCDF como backend possível de uma camada de I/O de nível mais
   alto;
8. o que um futuro PIO2 acrescenta: decomposição, rearrangers e abstração de
   múltiplos backends;
9. por que a versão e os backends de PIO2 ainda exigem pesquisa, proposta e
   decisão separadas;
10. como distinguir correção funcional de performance e escalabilidade.

O próximo ciclo não deve começar tratando PIO2 como “apenas mais uma
biblioteca”. Primeiro é necessário entender quais APIs e backends a versão do
MPAS escolhida exige, como PIO2 se relaciona com PnetCDF/netCDF e quais testes
upstream provam essa integração.
