# Ciclo 0010 — Adicionar aquisição ERA5 reproduzível

## O que mudou e por quê

O ciclo fixa a primeira baseline meteorológica real do projeto e transforma
uma seleção feita num portal web em um contrato auditável:

```text
2014-09-10 00 UTC, global
        ├── 5 variáveis × 37 pressure levels
        └── 19 variáveis single-level
                         ↓
                    CDS API / GRIB
                         ↓
              dados locais + manifesto
```

Requests JSON, cliente Python, container dedicado e validação de transporte
foram implementados. O `Dockerfile` científico, MPAS, WPS, mesh, geografia e
`static.nc` não mudaram.

Toda a parte offline passou. O primeiro preflight parou corretamente porque
`~/.cdsapirc` ainda não existia; depois da configuração manual segura, os dois
probes e os dois downloads globais foram concluídos. Assim, esta nota registra
separadamente a implementação, a aquisição comprovada e os checksums locais
dos bytes realmente entregues pelo CDS.

## Reanálise, análise e previsão

Uma previsão numérica parte de uma estimativa do estado presente e integra as
equações do modelo para o futuro. Seu objetivo operacional exige produzir o
resultado em tempo útil, com as observações disponíveis naquele momento.

Uma **análise** é a melhor estimativa do estado da atmosfera num instante. Ela
combina uma previsão curta anterior com observações por um sistema de
assimilação de dados. Radiossondas, estações, aeronaves, boias e satélites têm
resoluções, erros e coberturas diferentes; a assimilação pondera essas
informações junto à dinâmica do modelo para criar um estado tridimensional
coerente.

Uma **reanálise** repete esse processo para um período histórico usando um
sistema de modelo/assimilação consistente e observações reunidas depois do
tempo real. Ela não é uma simples interpolação de estações e tampouco uma
previsão antiga sem tratamento. O resultado é um registro global regular,
apropriado para inicializar, comparar e estudar eventos passados, respeitando
as limitações do sistema e das observações.

ERA5 é a quinta geração de reanálises globais do ECMWF. O CDS oferece, entre
outros produtos, valores horários em pressure levels e single levels. A data
histórica de 2014 escolhida já é consolidada e não depende do fluxo preliminar
recente ERA5T.

## Por que 2014-09-10 00 UTC

O tutorial oficial St Andrews 2025 usa esse instante no caso x1.10242. A
escolha fornece um ponto upstream para comparação sem transformar o primeiro
teste de pipeline em estudo de um evento extremo. Outros instantes continuam
possíveis em casos futuros; este é o contrato da primeira baseline.

## Pressure levels, model levels e superfície

### Pressure levels

São superfícies de pressão constante, expressas em hPa. Como a pressão em
geral diminui com a altura, 1000 hPa fica próximo à superfície e 1 hPa fica na
alta atmosfera. A altitude geométrica de uma superfície de 500 hPa varia no
espaço e no tempo.

O produto CDS aprovado fornece 37 níveis:

```text
1, 2, 3, 5, 7, 10, 20, 30, 50, 70,
100, 125, 150, 175, 200, 225, 250, 300,
350, 400, 450, 500, 550, 600, 650, 700,
750, 775, 800, 825, 850, 875, 900, 925,
950, 975, 1000 hPa
```

Usar todos os níveis evita inventar uma truncagem vertical antes de validar o
primeiro caminho e reproduz a estrutura padrão do produto.

### Model levels

Model levels são as camadas verticais internas do modelo atmosférico que
produziu o ERA5. Elas acompanham uma coordenada híbrida e não equivalem a uma
lista fixa de pressões em todos os pontos. Obter dados em model levels exige
coeficientes e tratamento vertical diferentes. Esta baseline escolhe o
produto já interpolado em pressure levels.

### Por que `config_nfglevels=38` não significa 38 pressure levels

O leitor real-data do MPAS conta os 37 níveis isobáricos e o nível especial de
superfície produzido pelo WPS. Campos 2-D como pressão à superfície, pressão
ao nível do mar e altura do solo não adicionam novos pressure levels.

```text
37 níveis isobáricos ERA5 + 1 nível WPS de superfície = 38 fg levels
```

Confundir esses números levaria a procurar um 38º nível ERA5 inexistente ou a
remover um nível válido.

## Pressure-level versus single-level datasets

O dataset pressure-level contém campos tridimensionais da atmosfera:

| Variável | Papel posterior |
|---|---|
| geopotential | WPS deriva altura geopotencial `GHT` |
| relative_humidity | umidade 3-D com `config_use_spechumd=false` |
| temperature | temperatura atmosférica `TT` |
| u component of wind | vento zonal `UU` |
| v component of wind | vento meridional `VV` |

São 5 × 37 = 185 mensagens esperadas para um instante.

O dataset single-level reúne quantidades na superfície, em alturas próximas
à superfície e nas quatro camadas de solo:

| Grupo | Variáveis | Papel posterior |
|---|---|---|
| 10 m | U e V | ventos próximos à superfície |
| 2 m | temperatura e dew point | temperatura e derivação de umidade próxima à superfície |
| pressão | surface pressure e mean sea-level pressure | `PSFC` e `PMSL` |
| terreno/máscara | geopotential e land-sea mask | `SOILHGT` e `LANDSEA` |
| superfície variável | skin temperature, sea-ice cover e snow depth | SST substituta, gelo e neve |
| solo | 4 temperaturas e 4 umidades volumétricas | camadas 0–7, 7–28, 28–100 e 100–289 cm |

As 19 variáveis geram 19 mensagens. Tipo de solo não é repetido: ele já está
no `static.nc`. Nuvens, precipitação, radiação e CAPE não são necessários para
esta inicialização e não foram baixados por conveniência.

## Umidade relativa versus umidade específica

Ambas podem descrever vapor d'água, mas não são a mesma variável. O
`Vtable.ECMWF` reconhece os códigos e o MPAS pode trabalhar com caminhos
diferentes. Esta baseline mantém `config_use_spechumd=false`, então seleciona
relative humidity diretamente nos pressure levels. O dew point de 2 m é usado
pelo WPS para derivar a umidade do nível especial de superfície.

Mudar para specific humidity seria uma decisão de configuração e inventário,
não uma otimização invisível do download.

## GRIB e mensagens GRIB

GRIB é um formato binário de mensagens usado em meteorologia. Um arquivo
`.grib` costuma ser a concatenação de muitas mensagens independentes. Cada
mensagem descreve um parâmetro, nível, tempo e grade, além dos dados empacotados.

O validador deste ciclo percorre o framing sem uma biblioteca científica
pesada:

1. exige a assinatura `GRIB` no início de cada mensagem;
2. lê a edição e o comprimento declarado na Section 0;
3. impede que o comprimento ultrapasse o arquivo;
4. exige o marcador final `7777`;
5. continua exatamente na próxima mensagem até EOF;
6. confere edição e contagem esperadas;
7. calcula tamanho e SHA-256.

Isso detecta arquivo vazio, página HTML, resposta JSON, archive inesperado,
truncamento e framing inconsistente. Não substitui ecCodes ou `ungrib` para
inspecionar `shortName`, level, units, time e códigos de parâmetros. Essa
validação semântica pertence ao próximo ciclo.

## Grade ERA5 e mesh MPAS

O produto de reanálise selecionado é fornecido numa grade regular
latitude/longitude de 0,25°. Linhas e colunas têm espaçamento angular regular.
A mesh x1.10242 é uma SCVT esférica não estruturada de resolução nominal
aproximada de 240 km.

As resoluções não precisam coincidir. O WPS decodifica os campos para seu
formato intermediate; o `init_atmosphere_model` interpola depois para a mesh.
Regridar durante o download acrescentaria outra transformação e outra fonte
de erro sem necessidade nesta baseline.

Também não há recorte. Um caso global precisa cobrir toda a esfera; recortar
deixaria células MPAS sem entrada meteorológica. A única `area` é a do probe
descartável de 1° × 1°, nunca a do request final.

## CDS e CDS API

O Climate Data Store é o catálogo e serviço de distribuição do Copernicus. A
CDS API permite enviar a seleção do formulário como estrutura Python e receber
o artefato resultante. Aqui, `cdsapi.Client().retrieve()` recebe:

- o nome estável do dataset;
- o objeto request lido do JSON versionado;
- um path temporário de destino.

O projeto fixa `cdsapi==0.7.7`. O container usa Python 3.12.13 slim-bookworm
por digest e fixa também a resolução transitiva observada, porque pinar apenas
o pacote direto ainda permitiria versões diferentes de suas dependências em
rebuilds futuros.

## Autenticação, termos e licença

Uma conta e um Personal Access Token identificam o usuário. A configuração
oficial fica em `~/.cdsapirc`. Separadamente, o usuário precisa abrir cada
dataset no portal e aceitar seus Terms of Use. Possuir token válido não implica
que os termos dos dois datasets tenham sido aceitos.

O wrapper verifica somente que o arquivo existe, é regular e não é symlink.
Ele não o imprime. Em runtime, o Docker monta:

```text
arquivo local → /run/secrets/cdsapirc (read-only)
CDSAPI_RC     → path interno, nunca o token
```

Não há `COPY .cdsapirc`, `ARG TOKEN`, `ENV TOKEN` ou token em argumento. Isso
evita gravar o segredo em layer, metadata, histórico de shell, processo ou Git.

## Por que um container de aquisição separado

A imagem científica representa MPAS/WPS/HPC e já foi validada. Aquisição tem
outra responsabilidade: Python, HTTPS, credencial e interação com um serviço.
Misturar as duas faria uma alteração de cliente CDS invalidar cache e
proveniência da stack científica e aumentaria a superfície que recebe secrets.

O pequeno container de aquisição contém apenas Python e cliente. Ele executa
como UID/GID do host, com root filesystem read-only, capabilities removidas,
`no-new-privileges`, `/tmp` efêmero e mounts mínimos. A rede é desligada para
versão/config/self-test e ligada somente em probe/download.

## Requests versionadas, dados não versionados

Versionar somente o script não preservaria a seleção; variáveis poderiam ficar
espalhadas em listas Python. Por isso os dois JSON registram dataset, produto,
formato, data, hora, níveis, variáveis e expectativas de transporte.

Os GRIBs não pertencem ao Git por volume, licença operacional e custo de
histórico. O manifesto local preserva para cada entrega:

- dataset e request config;
- SHA-256 do JSON que originou a entrega;
- versão `cdsapi`;
- resultado do job;
- número de variáveis e níveis;
- bytes, SHA-256, mensagens e edição GRIB;
- instante UTC da aquisição.

Um checksum calculado localmente identifica os bytes efetivamente recebidos.
Ele não deve ser descrito como checksum publicado pelo CDS. Se o serviço
reprocessar ou empacotar a mesma seleção de outro modo, o hash pode mudar sem
que o conteúdo meteorológico tenha necessariamente mudado; a divergência deve
ser investigada, não sobrescrita.

## Download temporário e promoção atômica

O cliente nunca escreve diretamente sobre o nome canônico. Ele usa um arquivo
`.partial` no mesmo filesystem, valida toda a estrutura e só então executa
`os.replace()`. Essa promoção é atômica no filesystem local.

Se o nome final já existe, não há novo retrieve: o script recalcula estrutura,
tamanho e SHA-256 e exige igualdade com o manifesto. Arquivo divergente,
manifesto ausente ou entrada órfã causam erro. Reexecução segura significa
aceitar estado idêntico, não apagar evidência incômoda.

## Quatro níveis de validação

É importante não condensar todo o pipeline em “o download funcionou”:

1. **aquisição:** o CDS entregou bytes;
2. **transporte:** os bytes são GRIB íntegro, com tamanho, framing e checksum;
3. **integração:** Vtable + ungrib produzem os campos WPS intermediate;
4. **validação científica:** os campos, unidades, níveis, tempos e estado
   inicial são fisicamente coerentes para o experimento.

Este ciclo pretende fechar 1 e 2. O ciclo 0011 fecha ERA5 → ungrib. A geração
de `init.nc` e sua validação formam outra etapa. Um PASS anterior não pode ser
promovido automaticamente ao próximo nível.

## Arquivos alterados

- `cases/first-global-240km/era5/*.json` e `README.md`: seleção;
- `docker/cds/`: base por digest e lock Python;
- `scripts/data/fetch-era5.py`: cliente, validação e manifesto;
- `scripts/data/fetch-era5.sh`: isolamento Docker;
- `scripts/validate/era5.sh`: validação final e Git hygiene;
- `docs/decisions/0007-first-era5-baseline.md`: decisão aprovada;
- documentação de caso, estado, fontes, versões, arquitetura e testes;
- esta learning note e índices.

## Comandos importantes

```sh
./scripts/data/fetch-era5.sh build
./scripts/data/fetch-era5.sh version
./scripts/data/fetch-era5.sh self-test
./scripts/data/fetch-era5.sh config
./scripts/data/fetch-era5.sh probe
./scripts/data/fetch-era5.sh download
./scripts/validate/era5.sh
```

`build` materializa o ambiente fixado e executa `pip check`. `version` e
`config` rodam sem rede. `self-test` exercita o parser com framing mínimo e
respostas inválidas efêmeras; ele não finge integração meteorológica. `probe`
submete os dois inventários numa área pequena. `download` remove a área e
obtém o globo. `era5.sh` é offline e confere arquivos, manifesto e Git.

## Testes executados

- JSON parse com `jq`: PASS;
- sintaxe Python compilada em memória: PASS;
- `bash -n` nos dois scripts shell: PASS;
- self-test GRIB no host: PASS;
- build Python 3.12.13 + cdsapi 0.7.7: PASS;
- lock transitivo + `pip check`: PASS;
- versão dentro do container: PASS;
- self-test dentro do container offline/read-only: PASS;
- requests dentro do container offline/read-only: PASS;
- ignore de GRIBs/manifest e trackability das requests: PASS;
- imagem científica: ID e tamanho preservados;
- preflight do probe sem credencial: recusou com código 1, sem rede/dados/token;
- credencial regular, não symlink e modo `600`: PASS;
- autenticação e termos dos dois datasets: PASS por retrieve real;
- probe pressure: 185 mensagens GRIB1: PASS;
- probe single: 19 mensagens GRIB1: PASS;
- downloads globais pressure e single-level: PASS;
- validação independente de transporte e Git hygiene: PASS;
- segunda execução sem novo retrieve, ambos `unchanged`: PASS.

Resultados dos probes descartáveis:

| Probe | Bytes | Mensagens | Edição | SHA-256 local |
|---|---:|---:|---:|---|
| pressure | 29.230 | 185 | GRIB1 | `ee199692c9cee1a1c6983be1f90a523f903889a1b06d58fefeb7d0a98b60f341` |
| single | 3.118 | 19 | GRIB1 | `b18bee89bcca223af1be15e4ecbd97a3b46556e651d51c945d9e221d2c928420` |

Resultados globais preservados localmente:

| Arquivo | Bytes | Mensagens | Edição | SHA-256 local |
|---|---:|---:|---:|---|
| `era5-pressure-levels.grib` | 384.168.780 | 185 | GRIB1 | `11a0a10a5727a19f64c529179af8b9e5fc4f92cdb60eb32ac90c68926b2e06ac` |
| `era5-single-levels.grib` | 41.995.970 | 19 | GRIB1 | `5d0c6aeeef07c5109f044428266d822928c2cf4ccda1ccbb430c916f0b5b693b` |

`file` também identificou ambos como GRIB versão 1. O manifesto associa esses
bytes aos dois hashes de request versionados. Esses SHA-256 são evidência
local da entrega, não checksums publicados pelo CDS.

## Falhas encontradas e diagnóstico

### Ausência de `.cdsapirc`

Foi a falha esperada de ambiente externo. O wrapper informou a ação manual e
parou antes de construir request autenticado ou criar `data/era5/`. Não há
fallback para variável de token nem credencial fictícia. Depois que o usuário
criou o arquivo com modo `600` e aceitou os termos, o mesmo comando passou sem
alteração de código; isso separa corretamente segredo local de implementação.

### Interrupções durante a transferência pressure-level

A conexão HTTP sofreu duas `IncompleteRead` depois que o job do CDS já estava
`successful`. O cliente oficial esperou e retomou a partir dos bytes parciais,
em vez de promover um arquivo truncado ou submeter outro job. A transferência
terminou com 384.168.780 bytes; framing completo, 185 mensagens e SHA-256
passaram. Isso demonstra recuperação de transporte, mas não autoriza tratar
qualquer arquivo parcial como válido: a promoção atômica continuou dependente
da validação integral.

### Dependências transitivas inicialmente abertas

Instalar apenas `cdsapi==0.7.7` produziu um cliente correto, mas o log mostrou
que suas dependências ainda eram resolvidas por ranges. A resolução efetiva foi
registrada integralmente em `requirements.txt` e o build repetido com
`pip check`. Isso reduz drift sem mudar a versão aprovada do cliente.

### Isolamento do executor local

Algumas inspeções do ambiente de desenvolvimento falharam antes do comando por
restrição de loopback do sandbox. As mesmas operações somente-leitura foram
executadas com a permissão já concedida. Isso não foi falha do Docker, CDS,
Python ou ERA5 e não deve ser confundido com resultado científico.

## Trade-offs e dívida

- O container acrescenta uma receita e um lock, mas separa responsabilidades
  e reduz exposição de secrets.
- Fixar dependências melhora repetibilidade; ainda dependemos da disponibilidade
  futura dos wheels no índice, pois seus hashes não foram incorporados.
- O parser leve valida transporte sem ecCodes; metadata campo a campo fica
  deliberadamente para o ciclo 0011.
- Todos os 37 níveis aumentam o volume, mas evitam uma truncagem vertical
  específica prematura.
- `skin_temperature` é usada como SST pelo caminho MPAS 8.4.1 aprovado; uma
  física/configuração futura pode exigir decisão diferente.
- O probe com área reduzida prova parâmetros e framing, não o tamanho ou a
  cobertura global do arquivo final.

## Próximo passo

No ciclo 0011, inspecionar o inventário real com ferramenta GRIB confiável,
escolher e validar a Vtable, usar `link_grib.csh`, executar `ungrib.exe` e
conferir os arquivos `ERA5:YYYY-MM-DD_HH` antes de aproximar o MPAS.

Ao final, o leitor deve conseguir explicar reanálise, níveis e mensagens GRIB,
reproduzir a seleção sem copiar secrets, distinguir checksum local de
proveniência upstream e reconhecer por que download não prova integração nem
validade científica.
