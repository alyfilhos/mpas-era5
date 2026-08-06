# Ciclo 0007 — adicionar MPAS atmosphere

## Objetivo e resultado

Este ciclo acrescenta o core atmosférico do MPAS-Model 8.4.1 à mesma árvore
que já continha o core de inicialização. O resultado final contém:

- `/opt/mpas-model/atmosphere_model`;
- `/opt/mpas-model/init_atmosphere_model`, preservado;
- namelists, streams e defaults dos dois cores;
- MMM-physics e UGWP fixados por tag e commit;
- as lookup tables compatíveis do MPAS-Data fixadas por tag, commit e hashes;
- um smoke estrutural repetível, offline e com filesystem read-only.

O build e o smoke estrutural passaram. Nenhuma previsão foi executada. Testes
funcionais e científicos continuam pendentes até existirem mesh, partição,
`init.nc` e uma configuração de caso aprovada.

## O papel de atmosphere_model

O MPAS separa preparação e integração em executáveis diferentes.

`init_atmosphere_model` transforma mesh e dados de entrada em artefatos
adequados ao modelo. Dependendo do modo e do domínio, ele prepara campos
estáticos, condições iniciais e eventualmente condições laterais.

`atmosphere_model` recebe um estado inicial consistente e integra as equações
atmosféricas no tempo. É o executável que realizará a previsão ou simulação.
Ele precisa de física parametrizada, tabelas de consulta e uma configuração
científica completa que o build sozinho não fornece.

A diferença explica por que provar a existência e linkagem de
`atmosphere_model` é importante, mas ainda não demonstra que uma previsão
começa, termina ou produz campos fisicamente coerentes.

## Por que atmosphere tem dependências adicionais

O framework comum oferece Registry, decomposição, infraestrutura MPI, I/O,
temporização e utilitários. O core atmosphere acrescenta pacotes de física que
não foram necessários ao build estrutural do init.

### MMM-physics

MMM-physics reúne implementações de parametrizações físicas usadas pelo MPAS.
O source 8.4.1 declara a tag `20250616-MPASv8.3`. A receita não troca essa
tag por uma cujo nome pareça combinar melhor com 8.4.1: o contrato versionado
do próprio MPAS é a autoridade.

### UGWP

UGWP fornece componentes da parametrização de ondas de gravidade. O source
declara a tag `MPAS_20241223`, igualmente preservada sem substituição.

### Lookup tables e MPAS-Data

Várias parametrizações consultam tabelas pré-computadas em runtime ou durante
a preparação do executável. Elas não são source code comum, mas também não
podem variar silenciosamente.

O script oficial `checkout_data_files.sh` contém:

```sh
mpas_vers="8.2"
```

Esse 8.2 é deliberado no MPAS-Model 8.4.1. O ciclo verificou a tag `v8.2` do
MPAS-Data, leu `COMPATIBILITY`, confirmou compatibilidade com 8.2 e copiou os
16 arquivos esperados para `physics_wrf/files`. “Corrigir” o número para
8.4.1 sem autoridade upstream quebraria a rastreabilidade.

## Externals.cfg e manage_externals

`src/core_atmosphere/Externals.cfg` descreve repositório, caminho local e
tag dos externals. O Makefile da física chama `manage_externals` para
materializá-los antes de compilar.

Esse mecanismo é conveniente para desenvolvimento upstream, mas um build
reproduzível não deve aceitar que uma tag seja reinterpretada ou que um
checkout pré-existente aponte para outro commit. Por isso a receita:

1. resolve a tag oficial;
2. clona exatamente essa tag;
3. compara `git rev-parse HEAD` com o commit registrado;
4. exige checkout detached;
5. exige ausência de mudanças rastreadas;
6. repete as verificações depois do make.

O probe revelou que `manage_externals` possui shebang Python 3. A imagem init
não tinha `python3`, portanto a primeira tentativa falhou antes da
compilação. Python 3.12.3 foi instalado numa nova camada posterior ao init,
preservando integralmente a camada validada.

## Tag não é o mesmo que commit

Uma tag é um nome Git. Uma tag leve aponta diretamente para um commit; uma tag
anotada aponta primeiro para um objeto tag, que por sua vez referencia o
commit. Um lock reproduzível deve registrar o commit “peeled”, não apenas o
nome ou o objeto intermediário.

Pins resolvidos em 2026-08-05:

| Projeto | Tag | Commit exato |
|---|---|---|
| MPAS-Model | `v8.4.1` | `91c5eac175eebeaf4206bacd5cb50c39dff3c152` |
| MMM-physics | `20250616-MPASv8.3` | `a4baf7f3243d1db0dbc5f63473f895bdbdc05c30` |
| UGWP | `MPAS_20241223` | `c1c893edcf171af5639af60e3a3a528816f6cc2b` |
| MPAS-Data | `v8.2` | `c57dbc7be629802c6e848770a9e44b9bc602be41` |

MMM-physics e MPAS-Data usam tags anotadas; UGWP usa uma tag leve. A receita
falha se qualquer checkout deixar de corresponder aos commits acima.

## Evitando downloads indiretos no make

Um build pode parecer fixado e ainda baixar conteúdo mutável em um submake.
Neste caso há duas rotas indiretas:

- `manage_externals` pode clonar os repositórios de física;
- `checkout_data_files.sh` pode buscar as tabelas por Git, SVN ou HTTP.

A receita materializa e verifica externals e dados antes do make. Para as
tabelas, ela também grava `.mpas-era5-mpas-data.sha256`. Quando
`checkout_data_files.sh` executa, encontra `COMPATIBILITY` e todos os
arquivos compatíveis e termina sem download. O smoke final roda sem rede e
repete essa verificação.

Os externals, tabelas, manifesto e metadata de auditoria ficam dentro da
imagem. Nenhum desses sources ou dados é adicionado ao Git do projeto.

## Reutilização do framework

Os cores compartilham o framework, mas cada um tem seu arquivo de opções:

- `.build_opts.framework`;
- `.build_opts.init_atmosphere`;
- `.build_opts.atmosphere`.

O Makefile remove definições específicas do core e compara as opções comuns.
Quando são incompatíveis, ele exige uma limpeza ou `AUTOCLEAN`; o ciclo não
usou nenhum dos dois automaticamente.

No probe, os três arquivos de opções foram idênticos. O hash de
`init_atmosphere_model` não mudou, e o conteúdo do archive do framework
também não mudou. O make executou `ar -ru` novamente, alterando timestamp e
reindexando/reempacotando o archive, e relinkou ferramentas geradoras. Não
houve recompilação dos objetos Fortran do framework.

A lição é que timestamp diferente não prova rebuild de conteúdo. Hashes,
opções e log de compilação precisam ser avaliados em conjunto.

## Comando e opções de build

O comando real foi:

```sh
make -j8 gnu \
    CORE=atmosphere \
    USE_PIO2=true \
    MPAS_ESMF=embedded
```

Cada parte tem uma função:

- `-j8` permite até oito jobs do make;
- `gnu` seleciona a configuração GNU através dos wrappers MPI;
- `CORE=atmosphere` seleciona o core e gera `atmosphere_model`;
- `USE_PIO2=true` documenta intenção, mas a 8.4.1 autodetecta PIO2;
- `MPAS_ESMF=embedded` usa o timekeeping ESMF incluído no source.

O resumo e os arquivos `.build_opts.*`, não apenas o comando, comprovaram:

- GNU com `mpif90`, `mpicc`, `mpicxx` e interface `mpi_f08`;
- single precision default e `-DSINGLE_PRECISION`;
- otimização `-O3` e DEBUG desligado;
- PIO 2.x e PnetCDF;
- ESMF embedded;
- OpenMP, offload OpenMP, OpenACC, MUSICA e PT-Scotch desligados.

## PIO2 e PnetCDF na linkagem

PIO abstrai decomposição e operações de I/O; PnetCDF implementa acesso
paralelo aos formatos CDF sobre MPI-IO. Nesta stack:

```text
atmosphere_model
    ↓
PIO 2.7.0 static
    ↓
PnetCDF 1.15.0 shared
    ↓
MPI-IO / OpenMPI
```

Como PIO foi instalado static, `ldd` não deve listar `libpio.so`. Isso não
significa ausência de PIO. `nm` encontrou símbolos `PIOc_*` definidos
dentro do executável. As referências `ncmpi_*` são satisfeitas pela
`libpnetcdf.so.8` vista no `ldd`. Qualquer linha `not found` falharia o
smoke.

## Arquivos alterados

- `Dockerfile`: Python, pins, checkouts, tabelas, build e auditoria;
- `scripts/validate/mpas-atmosphere.sh`: smoke estrutural versionado;
- `scripts/validate/mpas-init.sh`: permite a presença legítima do segundo
  core na imagem combinada sem enfraquecer as verificações do init;
- `README.md` e documentos de build, estado, fontes, versões, testes e
  arquitetura: status e evidência do ciclo;
- `learning/commits/0007-add-mpas-atmosphere.md`: esta nota;
- índices em `docs/README.md` e `learning/README.md`.

Nenhum ADR novo foi criado. O ADR 0004 já cobre versão e layout; os pins de
externals implementam os contratos explícitos do source upstream, sem escolha
arquitetural nova.

## Testes executados

### Probe

- regressão init na imagem base: PASS;
- primeira tentativa atmosphere: falha esperada pela ausência de `python3`;
- segunda tentativa com Python 3.12.3: build PASS;
- integridade init: hash inalterado;
- compatibilidade do framework: opções e conteúdo inalterados;
- um primeiro script diagnóstico terminou com código 1 por uma expressão de
  inspeção rígida depois do build; a repetição detalhada separou essa falha do
  make e comprovou o build com código 0.

### Imagem final

Comando:

```sh
docker build --progress=plain \
    --build-arg BUILD_JOBS=8 \
    -t mpas-era5:mpas-atmosphere-8.4.1 .
```

Resultado: código 0. As 27 etapas até o init foram `CACHED`. A imagem final
tem ID local
`sha256:54281c60db053982692d21bef27cf522293e8e2568be748cf4a83f2d5f0e4c93`
e tamanho local de 466.941.565 bytes.

### Smokes e regressões

- `scripts/validate/mpas-atmosphere.sh`: PASS, código 0, offline/read-only;
- `MPAS_INIT_IMAGE=mpas-era5:mpas-atmosphere-8.4.1
  ./scripts/validate/mpas-init.sh`: PASS, código 0;
- regressão PIO: PASS, quatro ranks, OMPIO e ROMIO, CDF-2, valores 1000–1003;
- regressão PnetCDF: PASS, quatro ranks, ROMIO, CDF-5, valores 0–3;
- WPS e METIS não foram reexecutados: nenhuma camada ou interface deles mudou,
  e suas etapas apareceram em cache.

`file`, `ldd` e `nm` confirmaram arquitetura, resolução das bibliotecas e
símbolos estáticos. Os avisos de statement functions Fortran obsolescentes e
de receitas make/`ar` upstream não foram erros.

## Como interpretar os resultados

BUILD PASS significa que source, externals, tabelas, compiladores e bibliotecas
produziram o executável.

STRUCTURAL SMOKE PASS significa que instalação, defaults, pins, compatibilidade
dos dados, opções e linkagem correspondem ao contrato documentado.

FUNCTIONAL PENDENTE significa que o modelo ainda não leu `init.nc`, mesh e
partição nem avançou um timestep.

SCIENTIFIC PENDENTE significa que nenhuma saída foi avaliada quanto a
conservação, estabilidade, unidades, extremos ou coerência física.

Essas classificações não são etapas burocráticas: elas evitam transformar um
ELF bem ligado em uma alegação científica sem evidência.

## Trade-offs e dívida técnica

- manter `.git` e externals na imagem aumenta seu tamanho, mas permite
  auditoria com `git describe` e `git rev-parse`;
- Python foi instalado por APT depois do init; sua versão observada é 3.12.3,
  mas os índices/pacotes Ubuntu não estão totalmente fixados;
- as tabelas recebem hashes por arquivo, porém o clone MPAS-Data temporário não
  fica na imagem; tag, commit, COMPATIBILITY e manifesto preservam a origem;
- o Makefile ainda executa passos de `ar` e geradores sobre infraestrutura
  compatível; os hashes demonstram preservação de conteúdo;
- avisos de código Fortran legado continuam como dívida upstream;
- uma validação funcional não pode avançar antes das decisões sobre mesh,
  ERA5, Vtable, configuração e primeiro caso.

## O que aprender deste ciclo

Ao final desta nota, o leitor deve conseguir:

1. explicar a diferença entre preparar o estado com init e integrá-lo com
   atmosphere;
2. localizar onde MPAS declara dependências de física e dados;
3. explicar por que tag e commit precisam ser registrados juntos;
4. reconhecer o risco de downloads iniciados indiretamente por submakes;
5. validar lookup tables por compatibilidade, lista e hashes;
6. distinguir reutilização de framework de rebuild apenas por timestamps;
7. provar PIO static e PnetCDF shared com `nm` e `ldd`;
8. separar build, smoke estrutural, teste funcional e validação científica;
9. justificar por que este ciclo termina antes de executar uma previsão.

