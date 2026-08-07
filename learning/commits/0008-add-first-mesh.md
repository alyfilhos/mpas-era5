# Ciclo 0008 — primeira mesh MPAS real

## O que mudou

Este ciclo introduz a primeira entrada científica externa real do projeto:

- mesh MPAS x1.10242 oficial;
- domínio global;
- geometria quasi-uniforme;
- resolução aproximada de 240 km;
- 10.242 células horizontais;
- partição baseline em quatro partes gerada localmente com METIS 5.1.0.

Foram adicionados scripts de aquisição, particionamento e validação, uma
política de exclusão de dados no Git, o ADR da escolha e um documento evolutivo
para o primeiro caso. A mesh, o grafo e a partição existem localmente sob
`data/meshes/x1.10242/`, mas não fazem parte do commit.

## Por que esta mudança importa

Até o ciclo 0007, a stack e os executáveis estavam prontos, mas o único grafo
particionado era um fixture sintético de 16 vértices. Esse fixture ensina a
interface do METIS, porém não prova que o workflow funciona sobre uma mesh
MPAS real.

x1.10242 mantém o custo baixo e atravessa as mesmas fronteiras conceituais das
meshes maiores: arquivo NetCDF, topologia não estruturada, grafo de adjacência,
decomposição para MPI e política de proveniência de dados científicos.

## O que é uma mesh

Uma mesh é a discretização espacial sobre a qual as equações do modelo são
aproximadas. Em vez de resolver a atmosfera em infinitos pontos, o modelo
armazena e evolui valores em um conjunto finito de elementos conectados.

Uma grade regular de latitude/longitude forma linhas e colunas previsíveis.
Ela é simples de indexar, mas sofre convergência dos meridianos perto dos polos
e dificulta variar suavemente a resolução.

Uma mesh não estruturada descreve explicitamente quais elementos são vizinhos.
Os índices não precisam formar uma matriz retangular. Essa liberdade permite
cobrir a esfera sem um polo singular de grade e criar transições suaves para
regiões de maior resolução.

## Voronoi, centroidal Voronoi e SCVT

Dado um conjunto de pontos geradores, uma tesselação de Voronoi associa a cada
ponto a região que está mais próxima dele do que de qualquer outro gerador.
As fronteiras entre duas regiões tornam-se arestas, e encontros de fronteiras
tornam-se vértices.

Numa tesselação de Voronoi centroidal, cada gerador coincide com o centroide
de sua própria região segundo a métrica e a densidade escolhidas. O processo
melhora a regularidade e a qualidade geométrica dos elementos.

SCVT significa *Spherical Centroidal Voronoi Tessellation*: a construção
centroidal é feita sobre a esfera. É essa família de meshes que a página
oficial diz fornecer para MPAS-Atmosphere.

## Células, arestas e vértices no MPAS

- **célula:** região de Voronoi; quantidades escalares do C-grid são
  naturalmente associadas ao centro da célula;
- **aresta:** fronteira compartilhada por duas células; conecta a topologia e
  é um local natural para componentes normais de velocidade;
- **vértice:** encontro de arestas; também pertence à mesh dual triangular.

No arquivo observado existem:

```text
nCells    = 10242
nEdges    = 30720
nVertices = 20480
```

Variáveis como `cellsOnCell`, `edgesOnCell` e `verticesOnCell` codificam essas
relações. `nEdgesOnCell` informa quantos vizinhos válidos cada célula possui,
e `indexToCellID` relaciona o índice armazenado ao identificador da célula.

## Por que o MPAS usa mesh não estruturada

A mesh não estruturada permite ao MPAS combinar domínio global, ausência da
singularidade polar típica de latitude/longitude e resolução espacial
variável. O solver não pode deduzir vizinhos por uma fórmula simples de
linha/coluna; por isso conectividade explícita é parte essencial da entrada.

## Quasi-uniforme versus resolução variável

Uma mesh quasi-uniforme tenta manter espaçamento semelhante em toda a esfera.
“Quasi” é importante: pentágonos e pequenas variações geométricas são
necessários para fechar a tesselação esférica; não se trata de hexágonos
idênticos em um plano.

Uma mesh de resolução variável concentra células menores numa região e usa
células maiores fora dela, com transição suave. Isso reduz custo quando o
interesse científico é localizado, mas introduz decisões adicionais sobre
razão de refinamento, posição, rotação e interpretação do timestep. O primeiro
caso escolhe a opção quasi-uniforme para aprender o pipeline básico.

## O significado de x1.10242

Na convenção usada pelos pacotes MPAS, `x1` identifica a classe sem aumento
local de refinamento — a mesh quasi-uniforme — e `10242` é o número de células
horizontais. O sufixo não é resolução em metros ou quilômetros.

Os “240 km” são uma resolução nominal aproximada, isto é, uma escala típica
do espaçamento horizontal. Como a mesh é esférica e quasi-uniforme, cada
distância local não é exatamente 240 km.

## O NetCDF da mesh

NetCDF é o container que guarda dimensões, variáveis, atributos e arrays. O
arquivo real foi identificado por `ncdump -k` como `64-bit offset`, também
conhecido como variante CDF-2. Isso é uma observação do artefato da mesh; não
deve ser confundido com o static file pronto, que a página descreve
separadamente como CDF-5/64-bit data.

O smoke leu o header e também os dados das variáveis fundamentais:

```text
latCell lonCell nEdgesOnCell cellsOnCell
edgesOnCell verticesOnCell indexToCellID
```

Um nome presente no header prova declaração. Fazer `ncdump -v` ler os arrays
também detecta truncamento ou falha de decodificação no conteúdo acessado.

## `graph.info` e a relação mesh ↔ grafo

Para particionamento, cada célula vira um vértice de grafo e a adjacência
entre células vira uma aresta não direcionada. O header real é:

```text
10242 30720
```

Seguem exatamente 10.242 linhas, uma por vértice, com vizinhos numerados de 1
a 10.242. O teste confere índices, duplicatas, self-edges, simetria, número de
arestas e conectividade global.

A igualdade central deste ciclo é:

```text
nCells do NetCDF = 10242 = vértices do graph.info
```

Sem essa igualdade, grid e grafo poderiam pertencer a artefatos diferentes,
mesmo que cada arquivo isoladamente fosse legível.

## METIS e a partição

METIS recebe o grafo e atribui cada vértice a uma partição. O comando aprovado
foi:

```sh
gpmetis -minconn -contig -niter=200 x1.10242.graph.info 4
```

- `-minconn` tenta reduzir a conectividade entre subdomínios;
- `-contig` exige que cada partição forme um subgrafo conectado;
- `-niter=200` aumenta o limite de iterações de refinamento;
- `4` solicita IDs de partição 0, 1, 2 e 3.

### Edge cut

Edge cut é o número de arestas cujas pontas foram atribuídas a partições
diferentes. Essas arestas são uma aproximação estrutural das fronteiras que
podem exigir comunicação entre ranks. Menor pode ser bom, mas edge cut sozinho
não prevê tempo total do MPAS.

O METIS reportou 663. O validador percorreu independentemente cada aresta uma
única vez e também obteve 663.

### Balanceamento

As contagens produzidas foram:

| Partição | Células |
|---:|---:|
| 0 | 2566 |
| 1 | 2549 |
| 2 | 2568 |
| 3 | 2559 |

A média é 2560,5. A razão simples `máximo / média` é 1,002929, equivalente a
0,292912% acima da média para a maior partição. Isso mede balanceamento por
número de células com pesos uniformes; não mede diferenças de custo de física
ou comunicação durante a simulação.

### Contiguidade

Uma partição contígua permite alcançar todas as suas células usando somente
arestas internas à própria partição. O script executa uma busca em largura
para cada ID e confirmou quatro subgrafos conectados.

## Partição não é rank MPI

O arquivo `.part.4` não executa paralelismo. Ele é uma tabela estática de
atribuição. Durante uma execução futura com quatro tasks MPI, o MPAS usará essa
tabela para distribuir células:

```text
graph.info.part.4 ↔ 4 MPI tasks
```

Um rank é um processo participante da execução MPI. A partição descreve o
conjunto de células que será associado a ele. Trocar para oito ranks exige um
arquivo `.part.8` correspondente.

Quatro ranks são a primeira baseline, não uma otimização. Escolher o melhor
número exige medir tempo, memória, comunicação, tamanho do caso e hardware.

## Dados científicos versus imagem Docker

A imagem contém programas e bibliotecas reproduzíveis. A mesh é entrada do
experimento e fica no host:

```text
Git/Docker image: código + configuração + documentação
data/:            entradas científicas reproduzivelmente adquiridas
```

Colocar dados na imagem aumentaria o acoplamento, exigiria rebuild para trocar
casos e duplicaria artefatos. Colocá-los no Git faria o histórico carregar
binários que podem ser obtidos novamente e validados por hash.

## Bind mounts e UID/GID

Um bind mount apresenta um caminho do host dentro do container. A validação
monta a mesh read-only, usa `--network none` e raiz read-only. Assim o teste
consome dados locais sem poder alterá-los ou buscar substitutos na rede.

Ao gerar a partição, o script trabalha numa cópia temporária e passa:

```sh
--user "$(id -u):$(id -g)"
```

Isso evita que a saída no host seja criada como `root`, um problema comum
quando containers escrevem em bind mounts.

## Checksums de datasets

Um checksum criptográfico identifica bytes. A página oficial não publicou um
SHA-256 para o tarball, então o ciclo fez dois downloads independentes do URL
first-party, comparou-os byte a byte e calculou:

```text
4dde31932bc45aaf467e2717d17ec8e5e54d73c3ebbeea027087bfdb8b98ab56
```

Esse é um SHA-256 calculado localmente, não um checksum publicado pela NCAR.
O script fixa o valor, baixa para caminho temporário e valida antes de extrair.
Se o servidor entregar bytes diferentes no futuro, a aquisição falha em vez de
aceitar silenciosamente outra entrada científica.

## Por que não versionar a mesh no Git

Tamanho pequeno não transforma dado científico em código-fonte. A política
precisa continuar correta quando o projeto migrar para meshes e ERA5 muito
maiores. O `.gitignore` exclui NetCDF, GRIB, grafos reais, partições, tarballs,
manifests/proveniência locais e logs de dados, sem excluir Markdown.

O procedimento reproduzível é versionado; o resultado materializado é local.

## Por que não usamos o static file pronto

A página também oferece um static file de 240 km. Usá-lo economizaria o
próximo passo, mas esconderia como datasets geográficos são interpolados para
a mesh e como `init_atmosphere_model` é configurado.

O fluxo educacional escolhido é:

```text
x1.10242.grid.nc
        ↓ init_atmosphere + datasets geográficos
x1.10242.static.nc produzido pelo projeto
```

Portanto o static file pronto não foi baixado, extraído nem validado.

## Arquivos alterados

- `.gitignore`;
- `scripts/data/fetch-mesh.sh`;
- `scripts/prepare/partition-mesh.sh`;
- `scripts/validate/mesh.sh`;
- `docs/cases/first-global-240km.md`;
- `docs/decisions/0005-first-mesh-baseline.md`;
- documentos de requisitos, estado, fontes, versões, validação e arquitetura;
- índices README do projeto, documentação, ADRs e aprendizado;
- esta learning note.

Os arquivos `.nc`, `graph.info` real e `.part.4` não são arquivos do commit.

## Comandos importantes

```sh
./scripts/data/fetch-mesh.sh
./scripts/prepare/partition-mesh.sh \
    data/meshes/x1.10242/x1.10242.graph.info 4
./scripts/validate/mesh.sh
```

O primeiro comando adquire e autentica o pacote. O segundo copia o grafo para
um diretório temporário, executa METIS na imagem atual e instala a saída sem
sobrescrever conteúdo divergente. O terceiro não usa rede, monta a entrada
read-only e executa as verificações NetCDF, grafo e partição.

## Testes executados e interpretação

### Proveniência e integridade

- página oficial conferida: 240 km, 10.242 células, quasi-uniforme, SCVT,
  `graph.info` e partições;
- URL do pacote resolvida diretamente dessa página;
- dois downloads de 6.321.104 bytes produziram o mesmo SHA-256 e `cmp` passou;
- conteúdo do archive listado antes de qualquer extração;
- reexecução do fetch retornou `unchanged` para grid e grafo.

Interpretação: a origem, os bytes e o comportamento idempotente estão
controlados. O hash continua local porque não há SHA-256 upstream encontrado.

### NetCDF e grafo

- `ncdump -k`, `ncdump -h` e leitura das variáveis fundamentais passaram;
- `graphchk` declarou o formato correto;
- o verificador independente confirmou header, linhas, intervalos, simetria,
  arestas e conectividade;
- `nCells` coincidiu com o número de vértices.

Interpretação: os dois artefatos são estruturalmente coerentes entre si. Isso
não substitui a execução do MPAS.

### Partição real

- `gpmetis` retornou código 0, edge cut 663, balanceamento 1.003 e
  contiguidade;
- a validação independente confirmou 10.242 atribuições, IDs 0..3, quatro
  partições não vazias, contiguidade, contagens, imbalance e edge cut 663;
- a reexecução produziu bytes idênticos e retornou `unchanged`.

Interpretação: `graph.info.part.4` é estrutural e matematicamente válido para
uma futura execução de quatro tasks. Não é necessário coincidir byte a byte
com a partição fornecida no archive.

### Regressão proporcional ao risco

- a imagem `mpas-era5:mpas-atmosphere-8.4.1` permaneceu acessível;
- `scripts/validate/mpas-init.sh` e `scripts/validate/mpas-atmosphere.sh`
  continuam executáveis;
- o Dockerfile e as versões de software não mudaram;
- os smokes MPAS não foram repetidos porque nenhum binário, biblioteca ou
  camada da imagem foi alterado.

## Falhas e correções durante o ciclo

A primeira execução do novo validador terminou sem evidência porque faltava
`-i` no `docker run`: o heredoc não era conectado ao stdin do container. Essa
execução vazia foi rejeitada, o script foi corrigido e o smoke completo foi
executado novamente com saída e asserções reais.

Também houve falha recorrente do sandbox local ao configurar loopback. As
operações necessárias foram repetidas pelo caminho autorizado fora desse
sandbox; isso não alterou a rede desabilitada dentro dos containers de
validação.

## Trade-offs e decisões

- x1.10242 custa mais que 480/384 km, mas é mais representativa e comum em
  tutoriais; custa muito menos que 120 km e meshes refinadas;
- part.4 favorece aprendizado e recursos modestos, não performance ótima;
- o workflow ignora partições upstream para provar nosso METIS real;
- dados ficam fora de Git/imagem, enquanto URL, hash e scripts ficam
  versionados;
- a validação é estrutural e matemática; não promove o resultado a validação
  funcional ou científica.

## O que ainda não foi provado

- que `init_atmosphere_model` aceita e consome a mesh/part.4;
- que datasets geográficos selecionados são compatíveis;
- que nosso `static.nc` pode ser gerado e possui campos plausíveis;
- que ERA5, Vtable e WPS intermediate cobrem o primeiro caso;
- que `init.nc` pode ser gerado;
- que `atmosphere_model` executa com quatro ranks;
- que a configuração é estável, eficiente ou cientificamente válida.

## Próximo passo

O próximo ciclo deve pesquisar e adquirir os datasets geográficos oficiais,
configurar `init_atmosphere_model` e gerar nosso próprio `static.nc` a partir
de x1.10242. A validação deverá conferir não apenas a existência do arquivo,
mas dimensões, variáveis, valores ausentes, faixas plausíveis e integração com
a etapa seguinte.
