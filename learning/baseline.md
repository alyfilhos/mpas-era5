# Baseline didático da stack científica

## Objetivo e limite de evidência

Este documento explica o ambiente construído manualmente antes do ciclo 0001 e
os conceitos necessários para entendê-lo. O baseline foi reconstruído em
2026-08-04 a partir do `Dockerfile`, do README, da documentação técnica e dos
quatro commits existentes.

Há uma distinção essencial:

- o repositório **comprova a receita** de download, configuração, compilação,
  teste e instalação que está no `Dockerfile`;
- o repositório **não preserva logs históricos** dos builds nem relatórios com
  a contagem de testes executados.

Portanto, este texto explica o que cada etapa faz e registra quais comandos
estão definidos, mas não inventa mensagens de compilador, número de testes
aprovados ou resultados que não foram salvos. O estado auditável está em
[`docs/project/current-state.md`](../docs/project/current-state.md) e a lacuna
de evidências está na
[`docs/testing/validation-matrix.md`](../docs/testing/validation-matrix.md).

## Visão geral da cadeia

```text
Ubuntu 24.04
    ├── GCC / GFortran
    ├── OpenMPI
    └── ferramentas de build
            ↓
        zlib 1.3.2
            ↓
        HDF5 1.14.6
            ↓
        netCDF-C 4.10.1
            ↓
        netCDF-Fortran 4.6.3
```

PnetCDF, PIO2, METIS, WPS e MPAS ainda não fazem parte da imagem atual. A
presença de OpenMPI prepara o ambiente, mas as quatro bibliotecas já definidas
no `Dockerfile` não constituem por si só uma aplicação MPI completa.

## Linux usado no projeto

O Linux executável definido pelo projeto é **Ubuntu 24.04**, selecionado por:

```dockerfile
FROM ubuntu:24.04
```

Isso descreve o sistema de arquivos base e a distribuição dentro da imagem.
Não comprova qual distribuição roda no host do usuário. O host fornece kernel
e o runtime de containers; os utilitários, bibliotecas e compiladores usados no
build vêm da imagem Ubuntu.

O `Dockerfile` usa `apt-get` para instalar:

- `build-essential`, que reúne ferramentas centrais da compilação GNU;
- `gfortran`, o compilador GNU Fortran;
- `openmpi-bin` e `libopenmpi-dev`, executáveis, wrappers, headers e bibliotecas
  de desenvolvimento do OpenMPI;
- ferramentas como `git`, `wget`, `curl`, `make`, `cmake`, `m4`, `perl` e
  `pkg-config`.

`DEBIAN_FRONTEND=noninteractive` evita prompts interativos do gerenciador de
pacotes durante o build. Isso é necessário porque um Docker build deve poder
avançar sem uma pessoa respondendo perguntas no terminal.

O Ubuntu está fixado em 24.04, mas o digest da imagem e as versões individuais
dos pacotes APT não estão congelados. Dois builds feitos em datas diferentes
podem receber atualizações distintas do repositório Ubuntu. Esse é um limite
de reprodutibilidade conhecido, não uma autorização para mudar a base no ciclo
0001.

## Por que containerizar

A compilação científica depende de muitas relações invisíveis: versões de
compiladores, headers, módulos Fortran, bibliotecas compartilhadas, caminho de
busca, opções de configuração e ordem das dependências. Instalar tudo
diretamente no host mistura a stack do projeto com o sistema pessoal e torna
mais difícil responder “qual ambiente produziu este binário?”.

O container ajuda porque:

- expressa o ambiente como código no `Dockerfile`;
- repete a ordem de instalação;
- isola `/opt/mpas` das bibliotecas do host;
- permite reconstruir a stack sem uma lista manual de comandos;
- oferece uma unidade identificável para executar testes e o modelo;
- reduz o risco de uma biblioteca encontrada por acaso no host mascarar uma
  dependência ausente.

Containerização não garante reprodutibilidade sozinha. Downloads mutáveis,
tags sem digest, pacotes sem versão, falta de checksums e resultados não
registrados ainda podem produzir diferenças.

## Imagem e container não são a mesma coisa

Uma **imagem** é um artefato imutável em camadas. Ela contém o Ubuntu, pacotes,
arquivos instalados e metadados como variáveis de ambiente. `docker build`
interpreta o `Dockerfile` e produz a imagem.

Um **container** é uma instância em execução — ou já encerrada — daquela
imagem. Ele acrescenta uma camada gravável e estado de processo. Vários
containers podem nascer da mesma imagem e divergir durante a execução sem
alterar a imagem original.

Uma analogia útil é:

- imagem: molde/versionamento do ambiente;
- container: uma execução concreta criada a partir do molde.

Se um arquivo for criado apenas dentro de um container e não estiver em volume
ou bind mount, ele não passa automaticamente a fazer parte do Git nem de uma
nova imagem.

## Cache de camadas Docker

Cada instrução relevante do `Dockerfile` produz uma camada ou metadado de
imagem. O builder pode reutilizar o resultado quando a instrução e suas
entradas continuam equivalentes. Esse cache economiza muito tempo em uma stack
que compila bibliotecas grandes.

O efeito prático da ordem atual é cumulativo:

```text
pacotes do Ubuntu
    ↓
zlib
    ↓
HDF5
    ↓
netCDF-C
    ↓
netCDF-Fortran
```

Se a instrução de netCDF-Fortran muda, camadas anteriores podem continuar no
cache. Se zlib muda, HDF5, netCDF-C e netCDF-Fortran ficam depois do ponto
invalidado e normalmente precisam ser reconstruídos. Isso reflete a cadeia de
dependências e é uma razão para manter componentes em blocos claros.

O cache não é prova de correção. Uma camada reutilizada registra que o builder
considerou as entradas equivalentes, não que o teste científico foi refeito
naquele momento. Para forçar ou auditar rebuilds há opções do Docker, mas seu
uso deve fazer parte de um ciclo aprovado e não de uma operação destrutiva
improvisada.

Os comandos de download, extração, compilação, instalação e limpeza de cada
biblioteca estão agrupados em uma instrução `RUN`. Se qualquer parte ligada por
`&&` falha, o shell não executa as seguintes e a camada não é concluída. A
limpeza dos fontes em `/tmp` reduz o tamanho final, mas também remove logs e a
árvore de build; por isso resultados importantes devem ser resumidos em
documentação antes de depender da imagem como única evidência.

## O prefixo `/opt/mpas`

O projeto define:

```dockerfile
ENV MPAS_PREFIX=/opt/mpas
```

Um **prefixo de instalação** é a raiz sob a qual diferentes bibliotecas são
instaladas de forma coordenada. Em vez de espalhar arquivos por `/usr/local`
ou depender de pacotes do sistema, a stack do projeto converge para:

```text
/opt/mpas
├── bin
├── include
├── lib
└── lib64
```

Isso torna explícito qual stack deve ser descoberta e facilita inspecionar,
montar e testar o ambiente. O prefixo não elimina conflitos automaticamente:
as ferramentas de configuração, linkedição e runtime ainda precisam procurar
nos diretórios certos.

## Do código-fonte à instalação

As bibliotecas atuais seguem a sequência tradicional do ecossistema
Autotools/Make.

### Download, checksum e extração

`curl -fL` baixa o tarball:

- `-f` faz o comando falhar em respostas HTTP de erro;
- `-L` segue redirecionamentos.

O arquivo é salvo com nome local estável. Para zlib, netCDF-C e
netCDF-Fortran, `sha256sum -c -` compara o conteúdo baixado com o SHA-256
registrado. Um checksum correto verifica integridade e identidade do conteúdo
esperado; ele não substitui a escolha de uma fonte confiável.

HDF5 1.14.6 ainda não tem checksum no `Dockerfile`. A versão está adotada, mas
essa proteção de integridade permanece uma lacuna.

`tar -xzf` extrai um arquivo tar comprimido por gzip:

- `x`: extrair;
- `z`: descomprimir gzip;
- `f`: o próximo argumento é o arquivo.

### `configure`

`./configure` examina o ambiente e gera Makefiles adaptados à máquina e às
opções pedidas. Ele costuma verificar compiladores, headers, funções,
bibliotecas e tipos. Também registra onde instalar:

```sh
./configure --prefix=/opt/mpas
```

Uma configuração bem-sucedida prova apenas que as verificações daquele script
passaram. Ela não prova que todo o código compila, que a suite passa ou que uma
aplicação externa consegue ligar e executar.

Variáveis prefixadas no comando selecionam ferramentas para aquela execução:

```sh
CC=gcc FC=gfortran ./configure ...
```

`CC` escolhe o compilador C e `FC` o compilador Fortran. No HDF5, o build atual
habilita Fortran, zlib, bibliotecas compartilhadas e estáticas. No netCDF-C, a
configuração habilita HDF5 e desabilita DAP, libxml2, NCZarr, parallel4 e outras
funcionalidades fora do recorte atual. Não se deve extrapolar isso para uma
decisão definitiva da estratégia paralela futura.

### `make`

`make` lê os Makefiles gerados e constrói os alvos respeitando dependências.
Em termos simplificados, ele transforma fontes em objetos e depois liga esses
objetos para produzir bibliotecas, executáveis e ferramentas.

Uma compilação pode falhar por sintaxe, interface incompatível, header
ausente, opção de compilador inválida ou dependência não encontrada. Uma etapa
de link pode falhar mesmo depois de todos os fontes compilarem, por símbolo não
resolvido, ordem de bibliotecas ou caminho incorreto.

### `make -j`

`make -jN` permite até `N` tarefas concorrentes quando o grafo de dependências
permite. O projeto usa:

```dockerfile
ARG BUILD_JOBS=8
make -j${BUILD_JOBS}
```

Paralelismo reduz tempo, mas aumenta consumo de CPU e memória. Ele não cria
oito “ranks MPI”: são conceitos diferentes. Aqui são processos/tarefas de
compilação independentes coordenados pelo Make.

Algumas falhas em builds paralelos aparecem longe da primeira causa no log.
Para diagnosticar, é útil localizar a primeira mensagem de erro e, quando
necessário, repetir o alvo com menos paralelismo em um ciclo controlado. Isso é
uma técnica de diagnóstico, não evidência de que tal falha já ocorreu neste
projeto.

### `make check`

`make check` executa a suite de testes definida pelo upstream para a
configuração compilada. No `Dockerfile` atual ele aparece em netCDF-C e
netCDF-Fortran e está encadeado por `&&`; portanto uma saída diferente de zero
impede a etapa seguinte naquele build.

zlib e HDF5 não têm uma suite upstream invocada pela receita atual. Além disso,
o repositório não preserva o resumo de nenhum `make check` histórico. Assim,
é correto dizer “o teste é obrigatório na receita do netCDF”, mas não “X testes
passaram” sem um relatório real.

Uma suite upstream também não substitui smoke e integração. Ela normalmente
testa o projeto dentro de sua própria árvore; precisamos ainda provar que a
instalação em `/opt/mpas` é descobrível e interoperável.

### `make install`

`make install` copia produtos da árvore de build para o prefixo: executáveis em
`bin`, headers e módulos em `include`, bibliotecas em `lib`/`lib64` e, conforme
o projeto, metadados adicionais.

O comando não é um teste funcional. Ele pode concluir mesmo que uma aplicação
posterior encontre outro arquivo homônimo no sistema ou falhe no runtime. Por
isso a validação inclui inspeção de configuração, programa mínimo e integração
com a camada seguinte.

## GCC e GFortran

### GCC

`gcc` compila código C. O fluxo típico é:

```text
fonte .c → pré-processamento → compilação → objeto .o → link → executável/biblioteca
```

Headers fornecem declarações durante a compilação; bibliotecas fornecem as
implementações ligadas depois. Encontrar o header sem encontrar a biblioteca,
ou o contrário, ainda é uma instalação incompleta para o consumidor.

### GFortran

`gfortran` compila Fortran e entende módulos, interfaces e runtime próprios da
linguagem. Além de objetos e bibliotecas, uma biblioteca Fortran pode instalar
arquivos `.mod` necessários para compilar código que faz `use` daquele módulo.

Arquivos `.mod` são artefatos do compilador, não simples fontes portáveis. A
compatibilidade pode depender da família e versão do compilador. Esse é um dos
motivos para construir netCDF-Fortran e, futuramente, MPAS com uma toolchain
coerente.

### Interoperabilidade C/Fortran

netCDF-Fortran não substitui netCDF-C: ele se apoia na biblioteca C. Ao ligar
um programa Fortran, os flags fornecidos por `nf-config` normalmente precisam
conduzir também às dependências C corretas. A ordem de build atual — C antes de
Fortran — expressa essa dependência.

## OpenMPI e o conceito de rank

MPI é uma interface de passagem de mensagens para programas compostos por
processos que cooperam, frequentemente distribuídos por vários núcleos ou nós.
OpenMPI é uma implementação dessa interface. O projeto instala tanto comandos
de execução quanto arquivos de desenvolvimento.

Wrappers como `mpicc` e `mpifort` normalmente chamam um compilador subjacente e
adicionam include paths, bibliotecas e flags do MPI. Eles não são linguagens
novas nem necessariamente compiladores independentes.

Um **rank MPI** é o identificador de um processo dentro de um comunicador. Em
um exemplo com quatro processos, o comunicador inicial normalmente tem ranks
0, 1, 2 e 3. O rank 0 frequentemente coordena I/O ou mensagens, mas isso é uma
convenção da aplicação, não uma obrigação universal do MPI.

Rank não significa:

- thread;
- núcleo físico;
- nó de cluster;
- tarefa de `make -j`.

É possível ter vários ranks no mesmo nó e mapear ranks a núcleos de maneiras
diferentes. Uma validação futura do MPI deve provar compilação com os wrappers,
execução com múltiplos ranks e comunicação correta; imprimir quatro linhas sem
verificar conteúdo é uma evidência fraca.

O `Dockerfile` atual instala OpenMPI, mas zlib, HDF5 e netCDF existentes usam
`gcc`/`gfortran`, e netCDF-C explicita `--disable-parallel4`. Alterar a
estratégia serial/paralela é um gate de decisão, não parte deste baseline.

## zlib

zlib fornece compressão DEFLATE. Na stack, sua importância principal é servir
como dependência de compressão para HDF5, que por sua vez sustenta arquivos
netCDF-4.

O build atual:

1. fixa 1.3.2;
2. verifica SHA-256;
3. configura `--prefix=/opt/mpas`;
4. compila em paralelo;
5. instala no prefixo.

Não há `make check` nem smoke test registrado. Um smoke futuro deve ligar um
programa pequeno à zlib instalada, comprimir dados, descomprimir e comparar os
bytes. A integração seguinte deve comprovar que HDF5 encontrou essa mesma zlib,
e não outra cópia do sistema.

## HDF5

HDF5 é um formato e uma biblioteca para dados científicos hierárquicos. Ele
organiza datasets, grupos, atributos e metadados dentro de arquivos e oferece
recursos como compressão. netCDF-4 utiliza HDF5 como camada de armazenamento
para seu modelo de dados estendido.

O HDF5 1.14.6 atual é configurado com:

- `CC=gcc` e `FC=gfortran`;
- `--with-zlib=/opt/mpas`;
- interface Fortran habilitada;
- bibliotecas compartilhadas e estáticas habilitadas;
- instalação em `/opt/mpas`.

Não existe checksum registrado nem `make check` no bloco. Um teste completo
futuro precisa incluir a suite upstream apropriada à release, criação/leitura
de arquivo mínimo em C e Fortran, verificação de compressão e integração com
netCDF-C.

## netCDF como modelo e ecossistema

netCDF não é apenas uma extensão de arquivo. É um modelo de dados, APIs e
formatos para arrays multidimensionais autocontidos. Um arquivo costuma conter
dimensões, variáveis e atributos que descrevem tanto valores quanto metadados.

É útil separar:

- **netCDF-C:** implementação central e API C; fornece ferramentas como
  `nc-config` e, conforme o build, utilitários de arquivo;
- **netCDF-Fortran:** bindings e módulos Fortran construídos sobre netCDF-C;
- **netCDF-4/HDF5:** combinação do modelo netCDF-4 com armazenamento HDF5;
- **PnetCDF:** projeto distinto orientado a I/O paralelo de formatos netCDF
  clássicos, ainda não implementado aqui.

Ter “netCDF” instalado não diz sozinho quais APIs, formatos, plugins ou recursos
paralelos estão habilitados. As opções de configuração e os testes importam.

## netCDF-C

O build fixa 4.10.1, valida o tarball com SHA-256 e aponta para o prefixo por
`CPPFLAGS` e `LDFLAGS`. As opções atuais:

- habilitam HDF5;
- desabilitam DAP e libxml2;
- desabilitam NCZarr;
- desabilitam `parallel4`;
- produzem bibliotecas shared e static.

Depois de `make -j`, a receita exige `make check` e só então instala. Ainda
faltam evidências persistidas e um smoke test contra a instalação. Um bom smoke
deve consultar `nc-config`, compilar código C com os flags fornecidos, criar um
arquivo pequeno, fechar, reabrir e conferir valores e metadados.

## netCDF-Fortran

O build fixa 4.6.3, valida SHA-256 e usa `CC=gcc FC=gfortran`. Ele desabilita o
plugin Zstandard e habilita bibliotecas shared/static. A configuração depende
de encontrar netCDF-C já instalado no mesmo prefixo.

A receita também executa `make check` antes de `make install`. Um smoke futuro
deve usar `nf-config` para compilar um programa com `use netcdf`, criar e reler
um arquivo, verificando tanto o módulo `.mod` quanto bibliotecas C/Fortran no
runtime.

## Headers C e módulos `.mod` de Fortran

Um **header C** (`.h`) contém declarações, macros e tipos que permitem ao
compilador verificar chamadas. Para netCDF-C, o consumidor precisa localizar o
header apropriado em `/opt/mpas/include` e depois ligar a biblioteca correta.

Um **módulo Fortran compilado** (`.mod`) descreve a interface de um módulo para
outros fontes Fortran. `use netcdf` exige que o compilador encontre o módulo
instalado. O include path usado pelo compilador Fortran precisa apontar para o
diretório correto, e a biblioteca netCDF-Fortran precisa ser ligada junto das
dependências.

Erros típicos — não afirmados como históricos sem log — ajudam a distinguir as
fases:

- “header não encontrado”: problema de include path ou instalação do
  desenvolvimento;
- “cannot open module file”: `.mod` ausente, caminho errado ou
  incompatibilidade de compilador;
- “undefined reference”: compilação encontrou declarações, mas a linkedição
  não recebeu biblioteca/ordem correta;
- biblioteca compartilhada não encontrada ao executar: link ocorreu, porém o
  loader de runtime não encontrou o `.so`.

## `nc-config` e `nf-config`

Esses scripts são interfaces de descoberta instaladas pelas bibliotecas:

- `nc-config` descreve o netCDF-C;
- `nf-config` descreve o netCDF-Fortran.

Eles podem informar versão, prefixo, recursos e flags de compilação/link. Sua
utilidade é evitar adivinhar uma lista incompleta de `-I`, `-L` e `-l`.

Como `/opt/mpas/bin` é colocado antes no `PATH`, o objetivo é que a chamada
encontre as ferramentas da stack do projeto. Uma validação deve conferir não
apenas a saída, mas também que o executável selecionado pertence ao prefixo
esperado. O repositório ainda não contém essa evidência.

## Variáveis de compilação e execução

### `CPPFLAGS`

O projeto define:

```sh
CPPFLAGS=-I/opt/mpas/include
```

`CPPFLAGS` alimenta flags do pré-processador C/C++ em muitos scripts
`configure`. `-I` acrescenta um diretório de busca de headers. Projetos Fortran
podem também aproveitar `-I` para módulos/includes, mas o comportamento final
depende do sistema de build.

### `LDFLAGS`

```sh
LDFLAGS=-L/opt/mpas/lib
```

`LDFLAGS` orienta a fase de link. `-L` adiciona um diretório no qual o linker
procura bibliotecas solicitadas, por exemplo por `-lnetcdf`. No ambiente há
também `/opt/mpas/lib64`; se uma biblioteca for instalada ali, a configuração
e os metadados específicos precisam conduzir o linker corretamente.

### `LD_LIBRARY_PATH`

```sh
LD_LIBRARY_PATH=/opt/mpas/lib:/opt/mpas/lib64
```

Essa variável é usada pelo loader dinâmico no runtime para localizar
bibliotecas compartilhadas. Ela resolve uma fase diferente de `LDFLAGS`:

- `LDFLAGS`: criação do executável/biblioteca;
- `LD_LIBRARY_PATH`: carregamento dos `.so` quando o programa inicia.

Um programa pode linkar com sucesso durante o build e ainda falhar ao executar
se a biblioteca compartilhada não estiver em um caminho conhecido ou gravado
no binário.

### `PATH`

```sh
PATH=/opt/mpas/bin:<PATH anterior>
```

Colocar o prefixo primeiro prioriza `nc-config`, `nf-config` e executáveis da
stack local. Isso precisa ser auditado para evitar que uma ferramenta homônima
do sistema seja selecionada.

### `NETCDF`

```sh
NETCDF=/opt/mpas
```

Essa variável é adicionada no commit mais recente com o comentário de que é
usada pelo sistema de build do MPAS. Ela comunica a raiz da instalação netCDF,
onde o consumidor poderá derivar `include`, `lib` e `bin`.

`NETCDF` não substitui todos os flags nem valida compatibilidade. É uma
convenção esperada pelo build consumidor. O histórico prova que a variável foi
adicionada; não registra uma mensagem de erro específica que tenha motivado a
correção.

## Bibliotecas compartilhadas e estáticas

Os builds atuais habilitam os dois tipos quando as opções aparecem:

- biblioteca **estática** (`.a`): código é incorporado na linkedição;
- biblioteca **compartilhada** (`.so`): o executável referencia um artefato
  carregado no runtime.

Static pode simplificar certos aspectos de distribuição, mas pode aumentar
binários e exigir todas as dependências na linkedição. Shared reduz duplicação
e permite atualização centralizada, mas depende de caminhos/runtime e
compatibilidade ABI. A presença dos dois formatos não decide automaticamente
qual o MPAS usará.

## Como diagnosticar sem adivinhar

Uma falha deve ser localizada por fase:

```text
download
  → integridade
    → configure
      → compile
        → link
          → upstream test
            → install
              → runtime
                → integração
                  → validação física
```

Perguntas úteis:

1. o artefato veio da URL e checksum registrados?
2. qual compilador e qual versão foram selecionados?
3. `configure` encontrou a dependência no prefixo ou no sistema?
4. o erro surgiu ao compilar ou ao resolver símbolos na linkedição?
5. a suite testa a árvore de build ou a instalação final?
6. `nc-config`/`nf-config` apontam para `/opt/mpas`?
7. o binário carrega bibliotecas de `/opt/mpas` no runtime?
8. um programa mínimo reproduz a falha sem a complexidade do MPAS?
9. a integração falha por formato/interface ou por conteúdo físico?

Separar essas fases evita “corrigir” um problema de runtime alterando versão,
ou mascarar uma biblioteca ausente ao instalar pacotes aleatórios no sistema.

## Erros e correções que a evidência permite registrar

Não existem logs versionados dos builds manuais. Portanto, mensagens exatas,
tentativas intermediárias e contagens de testes anteriores não podem ser
reconstruídas honestamente. O histórico Git permite afirmar apenas:

1. o bloco netCDF-C entrou inicialmente com indentação inconsistente e foi
   normalizado no commit mais recente; isso melhora legibilidade, mas o diff
   sozinho não prova que a indentação causou uma falha de build;
2. `NETCDF=/opt/mpas` foi acrescentado depois das bibliotecas netCDF para dar ao
   futuro build do MPAS uma raiz de descoberta; não há log que associe a
   mudança a uma mensagem específica;
3. checksums existem para zlib e os dois netCDF, mas não para HDF5;
4. `make check` existe para netCDF-C e netCDF-Fortran, mas não para zlib/HDF5,
   e nenhum resumo de resultado foi salvo;
5. durante a auditoria do ciclo 0001, consultas somente leitura à API Docker
   falharam com permissão negada em `/var/run/docker.sock`. A resposta correta
   foi não alterar permissões nem executar operação destrutiva e não usar
   imagens/containers locais como evidência.

Essas limitações ensinam uma regra central: quando a evidência acaba, o
diagnóstico deve declarar a incerteza. Uma hipótese técnica pode orientar um
teste futuro, mas não deve virar história fictícia do projeto.

## O que já se pode aprender e o que ainda falta provar

O baseline já ensina a ordem de dependências, o papel do prefixo, o pipeline de
compilação, a separação C/Fortran, fundamentos MPI e descoberta de bibliotecas.
Ele também torna explícito que o próximo avanço não deve começar por adicionar
mais uma biblioteca sem antes melhorar a evidência da camada atual conforme a
matriz.

Para transformar implementação em validação auditável, ciclos futuros devem
registrar suites upstream, programas mínimos, linkagem real, integração entre
camadas e resultados interpretáveis. A decisão sobre como e quando fazer isso
pertence ao workflow e aos gates do projeto.
