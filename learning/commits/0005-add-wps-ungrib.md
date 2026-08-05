# Ciclo 0005 — adicionar WPS 4.7.0 / ungrib

## Objetivo e limite do ciclo

Este ciclo acrescenta ao container somente a parte do WPS necessária para
decodificar GRIB: `ungrib.exe`. Ele também fixa documentalmente MPAS-Model
8.4.1 para um ciclo futuro.

Foram deliberadamente adiados:

- WRF;
- `geogrid.exe` e `metgrid.exe`;
- build de MPAS `init_atmosphere` ou `atmosphere`;
- download de ERA5;
- escolha da Vtable ERA5;
- qualquer integração com dados meteorológicos reais.

O valor educacional do recorte está em entender cada fronteira do pipeline sem
tratar “compilou” como sinônimo de “os dados científicos estão corretos”.

## WRF não é WPS

WRF é um modelo numérico de previsão do tempo. WPS é o WRF Preprocessing
System, um conjunto separado de ferramentas que transforma informações
geográficas e meteorológicas em entradas adequadas ao ecossistema WRF e, no
nosso fluxo, fornece uma etapa intermediária útil ao MPAS.

A relação histórica entre os projetos explica por que alguns componentes WPS
dependem das bibliotecas de I/O de uma compilação WRF. Isso não significa que
todo uso do WPS execute o modelo WRF. `ungrib` é a exceção útil deste ciclo: a
própria release permite construí-lo sem WRF.

## geogrid, ungrib e metgrid

Os três programas principais resolvem problemas diferentes:

1. `geogrid` descreve o domínio e interpola campos geográficos estáticos, como
   topografia e uso do solo;
2. `ungrib` lê mensagens GRIB, interpreta seus códigos com uma Vtable e grava
   registros no formato intermediário do WPS;
3. `metgrid` interpola esses campos meteorológicos para a grade definida por
   `geogrid`.

O pipeline tradicional WRF usa os três. O caminho MPAS que estudamos usa
`ungrib` como decodificador antes de `init_atmosphere`; o restante da
preparação espacial pertence ao MPAS e às ferramentas/casos que ainda serão
aprovados. Construir os três agora adicionaria WRF, decisões de domínio e
software que o objetivo não requer.

## O caminho ERA5 até MPAS

O fluxo pretendido é:

```text
ERA5
  ↓ download aprovado em GRIB
arquivos GRIB1/GRIB2
  ↓ interpretação dos códigos
Vtable apropriada
  ↓ ungrib.exe
formato intermediário WPS
  ↓ init_atmosphere
static.nc / init.nc / LBC quando aplicável
  ↓ atmosphere
simulação MPAS
```

Cada seta carrega uma responsabilidade:

- o download decide variáveis, níveis, área, período, resolução e formato;
- a Vtable traduz códigos do produto GRIB para nomes e metadados esperados;
- `ungrib` decodifica e serializa o formato intermediário;
- `init_atmosphere` combina campos meteorológicos, mesh e configuração para
  produzir entradas do modelo.

Um executável saudável não prova que a Vtable representa os campos corretos.
Por isso a integração funcional continua pendente.

## GRIB1 e GRIB2

GRIB é um formato de mensagens meteorológicas compactas. GRIB1 e GRIB2 são
edições diferentes do padrão, com estruturas e tabelas de códigos distintas.
O WPS 4.7.0 inclui leitores para ambas.

GRIB2 frequentemente usa compressão PNG ou JPEG2000. Decodificar o contêiner
não basta: o executável precisa das bibliotecas capazes de expandir essas
representações. É por isso que o build verifica `USE_PNG`, `USE_JPEG2000` e as
bibliotecas privadas associadas.

Não se deve inferir a edição somente pelo nome do dataset “ERA5”. O produto
efetivamente baixado e seus metadados serão inspecionados no ciclo de dados.

## O que é uma Vtable

Uma Vtable é uma tabela de tradução. Ela relaciona identificadores e níveis de
uma mensagem GRIB aos nomes, unidades e descrições que `ungrib` escreverá no
formato intermediário.

Uma Vtable inadequada pode:

- omitir variáveis necessárias;
- confundir superfície, pressão e níveis de modelo;
- mapear nomes ou unidades incompatíveis;
- produzir saída aparentemente válida, mas cientificamente errada.

A release distribui, entre outras:

- `Vtable.ECMWF`;
- `Vtable.ECMWF_sigma`;
- `Vtable.ERA-interim.ml`;
- `Vtable.ERA-interim.pl`.

Elas foram inspecionadas e sua existência é testada. Nenhuma foi ligada como
`Vtable`. ERA-Interim e ERA5 são produtos diferentes; a semelhança de nomes
não autoriza reutilização automática.

## Por que usamos `--nowrf`

O comando real foi:

```sh
./configure --nowrf --build-grib2-libs
```

`--nowrf` informa ao configurador que não existe uma árvore WRF compilada. A
saída explica que `geogrid`, `metgrid` e `int2nc` não poderão ser construídos,
mas mantém `ungrib` disponível. O `configure.wps` final registra
`WRF_DIR=none`.

Essa flag expressa a arquitetura escolhida. Não é um truque para mascarar uma
dependência ausente: é uma interface oficial da release para o recorte
independente.

## Por que usamos `--build-grib2-libs`

Essa opção manda o WPS construir os sources que ele próprio distribui:

```text
zlib   1.2.11
libpng 1.6.37
JasPer 1.900.29
```

Eles são instalados em:

```text
/opt/wps-4.7.0/grib2/include
/opt/wps-4.7.0/grib2/lib
```

As bibliotecas são usadas estaticamente na linkagem de `ungrib.exe`. `ldd`
não precisa listá-las; ele mostra apenas as dependências dinâmicas restantes.

## Bibliotecas privadas versus stack científica

O projeto já possui zlib 1.3.2 em `/opt/mpas`. Substituí-la ou acrescentar
JasPer no mesmo prefixo apenas para satisfazer WPS alteraria a stack validada e
criaria perguntas de compatibilidade desnecessárias.

A separação é:

```text
/opt/mpas             ABI compartilhada da stack científica
/opt/wps-4.7.0/grib2  implementação privada esperada pelo WPS 4.7.0
```

“Privada” aqui significa escopo de instalação, não sigilo. Esses arquivos
continuam visíveis e auditáveis, mas não são apresentados como dependências
globais do MPAS.

## Por que `/opt/wps` não é `/opt/mpas`

`/opt/mpas` é um prefixo de instalação: `bin`, `include`, `lib` e `lib64`
contêm interfaces usadas por diversas camadas. WPS é uma árvore de source e
build que preserva Makefiles, Vtables, programas e bibliotecas internas.

O layout adotado mantém identidades claras:

```text
/opt/wps-4.7.0
/opt/wps -> /opt/wps-4.7.0

/opt/mpas-model-8.4.1  futuro
/opt/mpas-model         futuro link estável
```

O caminho versionado mostra exatamente o que está instalado. O link estável
permite comandos operacionais sem esconder a versão. `ungrib.exe` não é
copiado para `/opt/mpas/bin`, onde pareceria parte da stack científica.

## csh e o script `compile`

O arquivo `compile` começa com:

```text
#!/bin/csh -f
```

Logo, Bash não substitui csh apenas porque ambos são shells. O container
anterior não possuía `/bin/csh`; foi adicionado somente o pacote Ubuntu `csh`.
A versão observada foi `20230828-1`, mas o APT não está congelado, de modo que
esse número é evidência da imagem e não um lock reproduzível completo.

## `configure` e `configure.wps`

`configure` pesquisa o ambiente, apresenta plataformas suportadas e gera
`configure.wps`. Este segundo arquivo é a configuração concreta consumida
pelos Makefiles.

O build não confia apenas em “Configuration successful”. Ele valida no arquivo
gerado:

```text
Linux x86_64, gfortran (serial)
SFC = gfortran
SCC = gcc
FC  = $(SFC)
CC  = $(SCC)
WRF_DIR = none
INTERNAL_GRIB2_PATH = /opt/wps-4.7.0/grib2
```

Também confirma `USE_JPEG2000`, `USE_PNG` e ausência de `-D_MPI` em
`CPPFLAGS`.

## Seleção GNU serial sem número mágico

Na tag observada, GNU serial apareceu como opção 1. Escrever simplesmente:

```sh
printf '1\n' | ./configure ...
```

fixaria um número cuja semântica pode mudar se a release reordenar, adicionar
ou filtrar plataformas.

O `Dockerfile` usa `awk` sobre `arch/configure.defaults` para reproduzir a
ordem das entradas serial/dmpar aplicáveis a Linux x86_64. Ele compara o label
exato `Linux x86_64, gfortran`, exige exatamente uma correspondência e somente
então envia o índice calculado ao `configure`.

Há duas camadas de segurança:

1. derivar a opção da fonte adotada;
2. validar o `configure.wps` produzido.

Se a estrutura upstream mudar e a derivação deixar de ser válida, o build deve
falhar em vez de selecionar silenciosamente outra toolchain.

## Por que `./compile ungrib`

O script aceita targets. A inspeção da tag confirmou `ungrib` como alvo
correto. O comando permanente é exatamente:

```sh
./compile ungrib
```

Executar `./compile` sem target percorre todos os componentes. Isso violaria o
escopo, tentaria usar dependências WRF ausentes e dificultaria saber o que foi
realmente aprovado.

O build produz:

```text
/opt/wps-4.7.0/ungrib/src/ungrib.exe
/opt/wps-4.7.0/ungrib.exe -> ungrib/src/ungrib.exe
/opt/wps/ungrib.exe       -> caminho real acima
```

## Release, tag, commit e SHA-256

Esses quatro identificadores respondem perguntas diferentes:

- **release**: versão publicada e notas do mantenedor;
- **tag**: nome Git que identifica o source selecionado;
- **commit**: objeto imutável ao qual a tag foi resolvida na verificação;
- **SHA-256**: identidade dos bytes do archive realmente baixado.

Para WPS:

```text
WPS_VERSION=4.7.0
WPS_TAG=v4.7.0
WPS_COMMIT=5feccecd63384381b6942371c7a837f66e4ccb84
WPS_SOURCE_URL=https://github.com/wrf-model/WPS/archive/refs/tags/v4.7.0.tar.gz
WPS_SHA256=5232d20d7556338391b66aba45824d4fcd6c42712ebe9325f359f3c6cf043808
```

Não foi encontrado SHA-256 publicado pelo upstream. O archive oficial foi
baixado duas vezes; ambos os arquivos tinham 4.544.769 bytes e o mesmo hash.
O valor é registrado como **calculado localmente**, jamais como checksum
oficial. Antes da extração, `sha256sum -c` faz o build falhar se os bytes não
coincidirem.

A imagem guarda esses campos e a origem do hash em
`.mpas-era5-provenance` dentro do prefixo WPS.

## Como versões importantes foram verificadas

Uma página pode marcar algo como “Latest”, mas esse rótulo isolado não prova
histórico, conteúdo da tag ou commit. Foram cruzadas três evidências:

```text
release/tag oficial
        +
source da própria tag
        +
histórico oficial de releases
```

A regra mudou o curso do ciclo. WPS 4.6.0 havia sido considerado e inicialmente
aprovado, mas 4.7.0 já era uma release estável posterior. O trabalho parou no
gate e só continuou depois de o usuário aprovar 4.7.0.

Para MPAS, 8.4.0 havia sido considerado, mas a tag `v8.4.1`, seu README com
heading `MPAS-v8.4.1` e o hotfix/commit
`91c5eac175eebeaf4206bacd5cb50c39dff3c152` comprovaram 8.4.1. O histórico não
mostrou release estável posterior em 2026-08-05.

## MPAS 8.4.1 foi fixado, não compilado

O ciclo registra:

```text
MPAS_VERSION=8.4.1
MPAS_TAG=v8.4.1
MPAS_COMMIT=91c5eac175eebeaf4206bacd5cb50c39dff3c152
```

Esses valores aparecem na documentação e no ADR. Eles não aparecem como uma
etapa de download no `Dockerfile`, porque o modelo ainda precisa de pesquisa
de build, configuração dos cores e testes próprios. “Versão fixada” reduz
ambiguidade; não equivale a “software instalado”.

## O que `file`, `ldd` e `readlink` provam

`file -L /opt/wps/ungrib.exe` seguiu os links e confirmou:

```text
ELF 64-bit LSB pie executable, x86-64, dynamically linked
```

Isso prova arquitetura e natureza do binário, não correção meteorológica.

`ldd` mostrou as bibliotecas dinâmicas resolvidas:

```text
libgfortran.so.5
libm.so.6
libgcc_s.so.1
libc.so.6
```

Nenhuma linha continha `not found`. zlib/libpng/JasPer não aparecem porque
foram ligadas estaticamente.

`readlink` verifica o link imediato, enquanto `readlink -f` resolve toda a
cadeia. Usar ambos distingue:

```text
/opt/wps -> /opt/wps-4.7.0
```

de:

```text
/opt/wps/ungrib.exe
→ /opt/wps-4.7.0/ungrib/src/ungrib.exe
```

## Probe descartável

Antes de editar permanentemente o `Dockerfile`, o archive foi extraído em
`/tmp` e montado em um container da imagem METIS validada. O probe:

- instalou `csh` apenas no container efêmero;
- reconstruiu o menu e selecionou GNU serial;
- executou `configure --nowrf --build-grib2-libs`;
- validou `configure.wps`;
- executou somente `./compile ungrib`;
- inspecionou executável, links, bibliotecas e Vtables.

O probe final terminou com código 0. O diretório temporário não foi
versionado e a imagem base não foi modificada.

## Build, smoke e integração funcional são categorias distintas

### BUILD

```text
configure --nowrf --build-grib2-libs
./compile ungrib
```

Resultado: código 0 e `ungrib.exe` produzido.

### SMOKE

`scripts/validate/wps-ungrib.sh` executa a imagem final com rede desabilitada,
raiz read-only e `/tmp` em tmpfs. Ele confere:

- prefixo e symlinks;
- executável e ausência de geogrid/metgrid;
- `file` e `ldd` sem dependência ausente;
- versão/proveniência;
- GNU serial em `configure.wps`;
- `/bin/csh`;
- headers e bibliotecas GRIB2 internas;
- separação de `/opt/mpas`;
- Vtables ECMWF/ERA distribuídas;
- ausência de uma Vtable escolhida no topo do WPS.

Resultado final: código 0.

### INTEGRAÇÃO FUNCIONAL

```text
ERA5 GRIB → ungrib → WPS intermediate
```

Resultado: **PENDENTE**. O teste depende de uma amostra ERA5 aprovada e de uma
Vtable cuja cobertura seja validada. Um GRIB falso demonstraria somente que o
teste consegue fabricar algo; um dataset aleatório expandiria o escopo e não
provaria o caso científico pretendido.

## Falhas e avisos encontrados

O probe teve duas tentativas de asserção/quoting antes da execução final:

- uma expressão esperava espaçamento mais rígido no comentário de
  `configure.wps`;
- outra deixou o shell interpretar `$(SFC)` durante a construção do comando.

As verificações finais usam padrões tolerantes somente a whitespace e
representam `$(` de forma literal.

O primeiro smoke final esperava um texto `WPS VERSION` inexistente no script
`compile`. A tag contém `echo Version 4.7.0`; a asserção foi corrigida para o
conteúdo real. A execução seguinte supunha que o README nomeava as Vtables
ECMWF/ERA individualmente. Ele ensina a ligação genérica da Vtable; os nomes
específicos pertencem ao diretório distribuído. O teste final valida a
instrução real do README e a existência individual dos quatro arquivos.

Avisos do build incluem:

- possível overflow de `sprintf` e macro BSD deprecada em libpng;
- uso de `tmpnam`, possível uso após `realloc` e avisos de arrays em JasPer;
- incompatibilidades legadas de tipo/rank em Fortran;
- receitas make sobrescritas e modificador `ar u` ignorado;
- linker alertando sobre `tmpnam`.

Nenhum aviso virou erro; linkagem e smoke passaram. Eles permanecem dívida
técnica, especialmente porque JasPer 1.900.29 é código legado empacotado pelo
WPS.

## Regressões da stack

A nova camada foi colocada depois de METIS. No build final, todas as etapas de
zlib até METIS apareceram como `CACHED`.

Foram executados na imagem `mpas-era5:wps-4.7.0`:

```sh
PNETCDF_IMAGE=mpas-era5:wps-4.7.0 ./scripts/validate/pnetcdf.sh
PIO_IMAGE=mpas-era5:wps-4.7.0 ./scripts/validate/pio.sh
METIS_IMAGE=mpas-era5:wps-4.7.0 ./scripts/validate/metis.sh
```

Todos retornaram código 0. Permaneceram:

- netCDF-C 4.10.1;
- netCDF-Fortran 4.6.3;
- PnetCDF 1.15.0 com F90/CDF-5 em quatro ranks;
- PIO 2.7.0/PnetCDF com CDF-2 em OMPIO e ROMIO;
- METIS 5.1.0 com quatro partições conectadas, imbalance 1.000 e edge cut 3.

A imagem final observada foi:

```text
mpas-era5:wps-4.7.0
sha256:437fb5d327aaeb1a2d79d4b2c9c0024a471f123f9416fa8e3bf1762d3b07267a
359179447 bytes
```

## Arquivos afetados

- `Dockerfile`: pacote csh, download/hash, seleção, configuração, build,
  smoke de build, proveniência e layout WPS;
- `scripts/validate/wps-ungrib.sh`: smoke instalado offline;
- `README.md`: status público e próximo pipeline;
- `docs/build/scientific-stack.md`: arquitetura e configuração WPS;
- `docs/project/requirements.md` e `current-state.md`: decisões materializadas
  e evidência do ciclo;
- `docs/references/source-registry.md` e `versions.lock.md`: fontes, tags,
  commits e SHA-256;
- `docs/testing/validation-matrix.md`: classificação e resultados;
- `docs/architecture/project-graph.md`: prefixos e relações;
- `docs/decisions/0004-wps-mpas-version-and-layout.md`: decisão aceita;
- índices em `docs/README.md`, `docs/decisions/README.md` e
  `learning/README.md`;
- esta learning note.

## O que aprender deste ciclo

Ao final, o leitor deve conseguir explicar:

1. por que WRF e WPS não são o mesmo software;
2. onde geogrid, ungrib e metgrid entram no pré-processamento;
3. como GRIB, Vtable e formato intermediário se relacionam;
4. por que `--nowrf` e `--build-grib2-libs` correspondem ao recorte aprovado;
5. por que dependências privadas do WPS não alteram `/opt/mpas`;
6. como derivar uma escolha interativa sem confiar em número mágico;
7. por que build, smoke e integração científica são evidências diferentes;
8. como tag, source da tag, commit, archive e SHA-256 se complementam;
9. por que MPAS 8.4.1 está decidido, mas ainda não instalado;
10. por que uma release importante deve ser verificada por tag, conteúdo e
    histórico, não apenas por um selo “Latest”.

O ADR está em
[[../../docs/decisions/0004-wps-mpas-version-and-layout|ADR 0004]] e a evidência
contável em [[../../docs/testing/validation-matrix|validation-matrix.md]].
