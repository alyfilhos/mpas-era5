# Ciclo 0004 — adicionar METIS 5.1.0

## Objetivo e decisão

Este ciclo instala, valida e documenta somente METIS 5.1.0. A decisão já
aprovada mantém METIS como particionador serial externo e usa `gpmetis` para
pré-computar os arquivos que o MPAS consumirá futuramente:

```text
graph.info
    ↓
gpmetis
    ↓
graph.info.part.N
    ↓
MPAS executado com N ranks MPI
```

Não foram implementados WPS, MPAS, ERA5, mesh definitiva, METIS 5.2.1, GKlib
externa ou PT-Scotch. zlib, HDF5, netCDF, PnetCDF e PIO não foram alterados.

## Por que uma mesh pode ser representada como grafo

Uma mesh discretiza um domínio em elementos conectados. Para distribuir esse
trabalho, interessa saber quais unidades computacionais existem e quais
dependem de vizinhas. Um grafo abstrai exatamente essas duas informações:

- um **vértice** representa uma unidade da mesh que receberá trabalho;
- uma **aresta** representa adjacência ou dependência entre dois vértices;
- a **lista de adjacência** de um vértice enumera seus vizinhos.

A geometria detalhada deixa de ser necessária para o problema combinatório.
O particionador enxerga conectividade. A tradução concreta entre entidades da
mesh MPAS e vértices será fornecida pelos utilitários e pela mesh reais em
ciclo futuro; o fixture deste ciclo ensina o formato sem fingir ser uma mesh.

## Partição, carga e comunicação

Uma **partição** atribui cada vértice a um entre `N` grupos. Se cada grupo for
entregue a um rank MPI, sua quantidade de trabalho constitui a **carga** desse
rank. Em um grafo não ponderado, contar vértices é uma aproximação simples de
carga. Grafos ponderados podem expressar custos diferentes.

O **balanceamento** mede quão semelhantes são as cargas. Se um rank recebe
muito mais trabalho, os demais podem esperar por ele em pontos de
sincronização. Para o fixture, usamos:

```text
imbalance simples = maior número de vértices / média por partição
```

Valor 1.000 significa distribuição perfeitamente uniforme por essa métrica.
Isso não prova igualdade de custo num modelo real, em que física, pesos e
hardware podem alterar o trabalho por vértice.

Uma aresta cujo primeiro vértice está numa partição e o segundo em outra é uma
aresta **cortada**. O número delas é o **edge cut**. Em uma decomposição
paralela, fronteiras entre partições tendem a exigir troca de dados entre
ranks. Menos cortes frequentemente significa menos comunicação, mas não é uma
garantia isolada de menor tempo total: volume por aresta, topologia de rede,
balanceamento e algoritmo do modelo também importam.

**Contiguidade** exige que os vértices de uma partição permaneçam conectados
entre si. Uma partição espacialmente fragmentada pode dificultar raciocínio,
aumentar fronteiras e prejudicar a comunicação. `-contig` impõe essa
propriedade, e o script a recalcula com uma busca em largura dentro de cada
partição.

Uma partição ruim pode, portanto, prejudicar o paralelismo de duas formas:

1. desbalancear trabalho e deixar ranks ociosos;
2. aumentar fronteiras e comunicação entre ranks.

O objetivo não é minimizar uma única métrica a qualquer custo. É encontrar
uma decomposição válida, suficientemente equilibrada e com fronteiras
adequadas ao problema.

## Ideia do particionamento multilevel

METIS usa algoritmos multilevel. Em nível introdutório, o procedimento tem
três fases:

1. **coarsening:** agrupa vértices e arestas para criar grafos
   progressivamente menores;
2. **partitioning:** encontra uma divisão inicial no grafo reduzido, onde o
   espaço de busca é menor;
3. **uncoarsening/refinement:** projeta a divisão de volta pelos níveis e move
   fronteiras para melhorar corte e balanceamento.

Coarsening não apaga o problema original: cria uma representação comprimida.
Uncoarsening recupera os detalhes. O refinamento corrige decisões que pareciam
boas no nível grosso, mas podem ser melhoradas à medida que o grafo original
reaparece.

`-niter` controla o número de iterações de refinamento em cada estágio. O
default documentado do METIS 5.1.0 é 10; o MPAS recomenda `-niter=200` para
seu fluxo. Mais iterações aumentam oportunidade de refinamento e também o
trabalho do particionador; não implicam automaticamente melhor desempenho
final do modelo.

## METIS e gpmetis

METIS é um conjunto serial de programas e uma biblioteca para particionamento
de grafos, particionamento de meshes e ordenação de matrizes esparsas.
`gpmetis` é o programa que recebe o grafo e o número de partições.

Ser serial não entra em conflito com preparar uma aplicação paralela:

- `gpmetis` roda uma vez, antes do modelo;
- ele grava a atribuição de vértices;
- o futuro MPAS roda em MPI e usa essa atribuição para decompor seu domínio.

METIS não envia mensagens MPI e não substitui OpenMPI. Ele prepara a estrutura
que permitirá ao MPAS distribuir trabalho.

As opções adotadas são as da documentação atual do MPAS:

- `-minconn`: tenta minimizar o grau do grafo de conectividade entre
  subdomínios;
- `-contig`: exige partições contíguas;
- `-niter=200`: permite até 200 iterações de refinamento por estágio.

## Formato graph.info

O manual METIS 5.1.0 define o formato. Comentários podem começar com `%`. A
primeira linha de dados é:

```text
número_de_vértices número_de_arestas
```

Depois há uma linha por vértice, em ordem 1..n. Cada linha lista os vizinhos
com numeração também iniciada em 1. Em grafo não direcionado, cada adjacência
aparece nas duas listas, mas o número de arestas no cabeçalho conta cada aresta
uma vez.

O fixture tem 16 vértices e 27 arestas:

```text
16 27
2 3 4
1 3 4
1 2 4
1 2 3 5
4 6 7 8
5 7 8
5 6 8
5 6 7 9
8 10 11 12
9 11 12
9 10 12
9 10 11 13
12 14 15 16
13 15 16
13 14 16
13 14 15
```

É possível desenhá-lo mentalmente:

- 1–4 formam uma clique K4;
- 5–8 formam outra K4;
- 9–12 formam a terceira K4;
- 13–16 formam a quarta K4;
- as pontes 4–5, 8–9 e 12–13 ligam as quatro cliques em cadeia.

Cada K4 tem 6 arestas; quatro cliques têm 24. Somando três pontes, o cabeçalho
deve registrar 27. O grafo é pequeno, conectado e possui quatro grupos
naturais não vazios.

`graph.info.part.4` contém uma linha por vértice. Cada linha guarda exatamente
um ID 0, 1, 2 ou 3. A linha 1 é a partição do vértice 1, e assim por diante. O
arquivo é saída gerada e não foi escrito em `tests/fixtures/`.

## A invariável N ↔ ranks MPI

O argumento final de `gpmetis` é o número de partições. O sufixo do arquivo
registra o mesmo número:

```text
gpmetis graph.info 4 → graph.info.part.4
```

No uso futuro:

```text
4 partições ↔ 4 tasks MPI
graph.info.part.4 ↔ mpirun -np 4 atmosphere_model
```

O ciclo testa a parte esquerda dessa relação. Não cria um
`atmosphere_model` falso e não chama MPAS.

## Pesquisa da release 5.1.0

A página histórica first-party de George Karypis continua apresentando 5.1.0
como release estável histórica e descreve METIS como serial. Foram consultados
o manual 5.1.x, o tarball oficial e os arquivos de build contidos nele.

O artefato foi baixado duas vezes do URL first-party:

```sh
curl -fL https://karypis.github.io/glaros/files/sw/metis/metis-5.1.0.tar.gz -o /tmp/metis-5.1.0-first.tar.gz

curl -fL https://karypis.github.io/glaros/files/sw/metis/metis-5.1.0.tar.gz -o /tmp/metis-5.1.0-second.tar.gz

sha256sum /tmp/metis-5.1.0-first.tar.gz /tmp/metis-5.1.0-second.tar.gz
```

Resultado real, idêntico nos dois arquivos de 4.984.968 bytes:

```text
76faebe03f6c963127dbb73c13eab58c9a3faeae48779f049066a21c087c5db2
```

Não foi encontrado SHA-256 publicado pelo upstream. Portanto o valor é
descrito como calculado localmente sobre o artefato first-party, não como
checksum oficial. Um resultado secundário coincidiu, mas não substitui origem
nem verificação local.

## Build real do METIS 5.1.0

`Install.txt`, `BUILD.txt`, o `Makefile` e os arquivos CMake do tarball foram
lidos antes da receita. A release requer toolchain C99, GNU make e CMake. O
Makefile dirige CMake:

```sh
make config prefix=/opt/mpas
make -j8
make install
```

O default é biblioteca estática; `shared=1` não foi habilitado. A instalação
normal forneceu:

- `/opt/mpas/bin/gpmetis`;
- `ndmetis`, `mpmetis`, `m2gmetis`, `graphchk` e `cmpfillin`;
- `/opt/mpas/include/metis.h`;
- `/opt/mpas/lib/libmetis.a`.

`nm` confirmou o símbolo `METIS_PartGraphKway`. Não foi criada uma variável
`ENV METIS`, pois nem o fluxo aprovado nem o comando `gpmetis` precisam dela.

### IDXTYPEWIDTH e REALTYPEWIDTH

Os defaults do header instalado foram preservados:

```text
IDXTYPEWIDTH  = 32
REALTYPEWIDTH = 32
```

`IDXTYPEWIDTH` limita a representação de índices do grafo: vértices, posições
de adjacência e IDs usados pelo METIS. Uma mesh que excedesse o alcance de
32 bits exigiria avaliação própria.

`REALTYPEWIDTH` define o tipo real interno usado pelo METIS em pesos e
cálculos. Ele não é a precisão numérica do MPAS e não transforma campos
atmosféricos em single ou double precision.

Não foram usados `i64=1` ou `r64=1` porque não existe necessidade comprovada
para o primeiro fluxo e o MPAS documenta compatibilidade de particionadores
com índices de 32 bits.

### GKlib em 5.1.0

O tarball contém o diretório `GKlib/`. O build 5.1.0 usa essas fontes
diretamente e as compila em `libmetis`. Baixar GKlib separadamente teria
misturado instruções da linha moderna com uma release que já traz o código
necessário.

## Testes upstream realmente disponíveis

O source 5.1.0 não registra `make check`, `ctest`, `enable_testing` ou
`add_test`. Não foi inventada uma suíte. O diretório `graphs/` contém grafos
de teste e seu README os descreve para esse uso.

Durante o Docker build foram executados:

```sh
graphchk graphs/4elt.graph
gpmetis -minconn -contig -niter=200 graphs/4elt.graph 4
```

Resultados reais do `4elt.graph` upstream:

- 15.606 vértices;
- 45.878 arestas;
- quatro partições contíguas;
- `Edgecut: 341`;
- balanceamento 1.001;
- memória máxima reportada 1,482 MB.

Isso é uma validação funcional sobre entrada fornecida pela release, não uma
suíte formal nem um benchmark MPAS.

## Script de validação e isolamento da fixture

`scripts/validate/metis.sh` usa `set -euo pipefail`. Ele:

1. verifica a imagem final;
2. monta o repositório read-only;
3. cria `/validation-output` como tmpfs de 16 MiB;
4. copia `graph.info` para esse espaço efêmero;
5. executa o comando real recomendado pelo MPAS;
6. valida o arquivo produzido;
7. deixa a limpeza ao `docker run --rm` e ao tmpfs.

O `-i` de `docker run --rm -i` mantém stdin aberto para que o heredoc do script
seja recebido pelo Bash do container. O fixture nunca recebe
`graph.info.part.4`.

Comando de validação executado:

```sh
sg docker -c "bash -o pipefail -c './scripts/validate/metis.sh 2>&1 | tee /tmp/mpas-era5-metis-validation.log'"
```

Dentro do container, o comando de interesse foi exatamente:

```sh
gpmetis -minconn -contig -niter=200 graph.info 4
```

## Validações estruturais e resultados

Aceitar apenas código de saída 0 seria insuficiente. O script confirmou:

- `graph.info.part.4` existe e não está vazio;
- há 16 linhas para 16 vértices;
- cada linha contém exatamente um inteiro;
- cada ID está em 0..3;
- todos os quatro IDs aparecem;
- nenhum vértice está sem atribuição;
- não há linha extra;
- cada partição é conectada.

Resultado real:

```text
partition_0_vertices=4
partition_1_vertices=4
partition_2_vertices=4
partition_3_vertices=4
average_vertices_per_partition=4.000
min_vertices_per_partition=4
max_vertices_per_partition=4
simple_imbalance_ratio=1.000
simple_imbalance_percent=0.000%
reported_edge_cut=3
independently_computed_edge_cut=3
```

O `edge cut` foi recalculado percorrendo cada aresta apenas quando o vizinho
tinha ID maior que o vértice atual, evitando contar duas vezes. Uma busca em
largura independente alcançou os quatro vértices de cada partição.

`gpmetis` também reportou volume de comunicação 6, balanceamento 1.000, quatro
partições contíguas e memória máxima 0,057 MB. Esses números descrevem somente
o fixture artificial.

## Banner legado e prova da versão

A primeira suposição foi que `gpmetis -help` exibiria a versão exata. Não
exibe. Depois, uma asserção esperou `METIS 5.1.0` no output e falhou: o banner
do executável da própria release imprime `METIS 5.0`.

A investigação do source mostrou que esse é texto legado do programa. A versão
exata passou a ser verificada pelos macros instalados:

```text
METIS_VER_MAJOR    5
METIS_VER_MINOR    1
METIS_VER_SUBMINOR 0
```

O banner continua verificado apenas como identificação da família 5.x. Essa
separação impede tanto um falso negativo quanto afirmar que o banner prova
5.1.0.

## Falhas e avisos encontrados

- Um probe `make config` no host descartável falhou porque `make` não estava
  disponível fora da imagem. A validação relevante foi movida para o ambiente
  Docker que contém a toolchain aprovada.
- A primeira receita de smoke assumiu versão no `-help` e falhou.
- A segunda receita assumiu banner `5.1.0` e falhou; a inspeção do source
  revelou o banner legado `5.0` e levou à verificação correta pelo header.
- A primeira execução do script não usou `docker run -i`; o heredoc não chegou
  ao processo do container. Uma pipeline sem `pipefail` também não era uma
  evidência confiável. O script ganhou `-i` e a execução final usou
  `bash -o pipefail`.
- CMake emitiu aviso de depreciação por compatibilidade antiga da release.
- GCC emitiu avisos `-Wmisleading-indentation` em fontes legadas da GKlib
  incluída.
- O submake reportou aviso de jobserver ao receber `-j8`. Nenhum desses avisos
  foi erro de compilação ou teste.

Somente a última build e as validações com código 0 sustentam o status.

## Regressão da stack

Build final:

```sh
sg docker -c "docker build --progress=plain --build-arg BUILD_JOBS=8 -t mpas-era5:metis-5.1.0 . 2>&1 | tee /tmp/mpas-era5-metis-build.log"
```

Todas as etapas até PIO foram `CACHED`. A imagem final tem:

```text
sha256:4d1cd35469cf12c710643d78a93448924dcd5bb1af6155846dd1e4f213af53b3
337756200 bytes
```

Regressões executadas:

```sh
PNETCDF_IMAGE=mpas-era5:metis-5.1.0 ./scripts/validate/pnetcdf.sh

PIO_IMAGE=mpas-era5:metis-5.1.0 ./scripts/validate/pio.sh
```

Ambas terminaram com código 0. Permaneceram:

- `nc-config` 4.10.1;
- `nf-config` 4.6.3;
- PnetCDF 1.15.0;
- PIO 2.7.0 com PnetCDF;
- F90/CDF-5 em quatro ranks, valores 0, 1, 2, 3;
- PIO/CDF-2 em quatro ranks, valores 1000, 1001, 1002, 1003;
- smoke PIO aprovado com OMPIO e ROMIO.

## Por que escolher 5.1.0

5.1.0 preserva o plano original e o fluxo offline que a documentação atual do
MPAS continua suportando. Ele oferece uma baseline simples e explícita para
aprender decomposição antes de adicionar particionamento online.

A decisão está no
[[../../docs/decisions/0003-metis-5.1.0-partitioning-baseline|ADR 0003]].
Adiar alternativas não significa rejeitá-las.

## Alternativa futura: METIS 5.2.1 e GKlib fixada

O repositório moderno oficial `KarypisLab/METIS` contém a release 5.2.1.
Nessa linha, GKlib é dependência externa. Uma implementação reproduzível deve
fixar explicitamente uma release ou commit de GKlib, porque usar o estado
mutável de uma branch impediria reconstruir exatamente a mesma combinação.

`gpmetis` continua sendo o executável offline de interesse. Não há evidência
neste ciclo de que 5.2.1 seja melhor para MPAS. Um experimento deve reutilizar
o mesmo grafo, número de partições e opções e medir validade, `edge cut`,
balanceamento, tempo, memória e compatibilidade com meshes MPAS.

## Alternativa futura: PT-Scotch online

PT-Scotch oferece particionamento paralelo/distribuído. A documentação atual
do MPAS registra particionamento online desde v8.4.0, requer build do MPAS com
PT-Scotch, documenta versão mínima 7.0.8 e exige compatibilidade com índices de
32 bits.

O MPAS pode gerar a partição em runtime e salvar o arquivo para reutilização.
Isso evita pré-computar manualmente `graph.info.part.N` em alguns workflows,
sobretudo quando o número de ranks muda com frequência. O fluxo offline METIS
continua suportado.

PT-Scotch foi adiado porque este ciclo não compila MPAS, não escolhe mesh e
não precisa introduzir particionamento distribuído para validar o conceito
base.

## Como desenhar um benchmark futuro justo

A comparação proposta é:

```text
METIS 5.1.0 offline
vs METIS 5.2.1 offline + GKlib fixada
vs PT-Scotch online
```

Devem permanecer constantes:

- mesh e representação do grafo;
- número de partições/ranks;
- pesos e objetivos;
- hardware, afinidade e carga concorrente;
- versão/configuração do MPAS;
- caso, entradas, duração e critérios de validação;
- repetições, warm-up e método de medição.

Métricas:

- validade e contiguidade;
- balanceamento e `edge cut`;
- tempo e memória do particionamento;
- comunicação observada;
- tempo de inicialização e de execução MPAS;
- escalabilidade;
- conveniência operacional;
- capacidade de salvar/reusar a partição;
- reprodutibilidade.

O backlog está em
[[../../docs/project/future-experiments|future-experiments.md]]. Ele não é um
roadmap aprovado nem um benchmark iniciado.

## Arquivos afetados

- `Dockerfile`: download, integridade, build, instalação e smoke upstream;
- `tests/fixtures/metis/graph.info`: entrada didática;
- `scripts/validate/metis.sh`: validação repetível;
- `README.md` e `docs/README.md`: status e navegação;
- `docs/build/scientific-stack.md`: conceitos e configuração;
- `docs/architecture/project-graph.md`: relações e novos caminhos;
- `docs/project/requirements.md` e `current-state.md`: decisão materializada e
  estado real;
- `docs/project/future-experiments.md`: backlog das alternativas;
- `docs/references/source-registry.md` e `versions.lock.md`: fontes,
  integridade e versão adotada;
- `docs/testing/validation-matrix.md`: evidência;
- `docs/decisions/README.md` e ADR 0003: decisão arquitetural;
- `learning/README.md` e esta nota: índice e aprendizado.

## O que o leitor deve aprender

Ao final, o leitor deve conseguir:

1. explicar como uma mesh vira um problema de grafo;
2. diferenciar vértice, aresta, adjacência, partição e carga;
3. relacionar balanceamento e `edge cut` com paralelismo;
4. descrever coarsening, partitioning e uncoarsening/refinement;
5. ler um `graph.info` e um `graph.info.part.N`;
6. explicar por que METIS serial prepara uma execução MPI;
7. justificar `N partições ↔ N ranks`;
8. reproduzir o build e interpretar cada validação;
9. distinguir checksum local de checksum publicado pelo upstream;
10. explicar por que 5.2.1/GKlib e PT-Scotch permanecem experimentos futuros.

## Limitações e dívida técnica

- não há mesh MPAS real validada;
- não há integração com MPAS;
- a release 5.1.0 não possui suíte formal;
- warnings do código legado permanecem;
- o banner não identifica a subversão exata;
- o digest Ubuntu, pacotes APT e checksum HDF5 continuam dívidas herdadas;
- resultados do fixture não podem ser extrapolados para performance científica.

## Revisão pré-commit executada

Os gates finais foram executados depois de todas as edições:

```sh
bash -n scripts/validate/metis.sh
git diff --check
git status --short --untracked-files=all
git diff
git rev-parse HEAD
```

`bash -n` e `git diff --check` terminaram com código 0. A busca por
whitespace ao fim das linhas não encontrou ocorrências. `git diff` foi
revisado integralmente, e `HEAD` permaneceu na base real
`7e1d672696e6b892ca36b57ec53a1b3041aeedcf`: nenhum commit ou push foi
feito.

`rg --files` confirmou que o único arquivo sob `tests/fixtures/metis/` é o
`graph.info` deliberado. Não há `graph.info.part.4`, binários, bibliotecas,
arquivos `.nc`, tarballs, logs ou datasets no worktree do ciclo.
