# Ciclo 0012 — Gerar a primeira condição inicial MPAS

## O que mudou

Este ciclo fechou a primeira cadeia meteorológica real do projeto:

```text
x1.10242.static.nc
        +
ERA5:2014-09-10_00
        +
x1.10242.graph.info.part.4
        ↓
init_atmosphere_model 8.4.1 / 4 ranks
        ↓
x1.10242.init.nc
```

Foram adicionados:

- namelist, streams e README do init meteorológico em
  `cases/first-global-240km/init/`;
- executor isolado e idempotente `scripts/run/generate-init.sh`;
- validador orquestrador `scripts/validate/init.sh`;
- smoke test independente netCDF-C `tests/smoke/init_netcdf.c`;
- ADR 0008 e atualização da documentação de estado, caso, grafo e testes.

O output, log e manifesto ficam em
`data/cases/first-global-240km/init/`, ignorados pelo Git. Nenhum GRIB,
intermediate, NetCDF científico ou log foi versionado.

## Por que `init.nc` existe

O `atmosphere_model` não começa diretamente com uma mesh vazia nem com campos
meteorológicos em latitude/longitude. Ele precisa de um estado inicial já
expresso na malha não estruturada e na coordenada vertical do MPAS.

`init.nc` reúne:

- geometria e campos estáticos da mesh;
- grade vertical e métricas do modelo;
- vento, densidade e estado termodinâmico;
- vapor d'água e escalares;
- pressão de superfície;
- temperatura, umidade, neve e gelo da superfície/solo;
- timestamp e atributos da configuração que o gerou.

Ele é uma condição inicial, não uma previsão.

## Quatro tipos de arquivo que não devem ser confundidos

### `grid.nc`

Descreve a topologia e geometria horizontal: células, arestas, vértices,
conectividades, áreas e coordenadas. Não contém a meteorologia do instante.

### `static.nc`

Acrescenta campos invariantes ou lentamente variáveis interpolados de
WPS_GEOG: terreno, máscara terra/água, vegetação, solo, albedo e GWD. Ele
continua sem o estado atmosférico de 2014-09-10.

### WPS intermediate

É uma sequência de slabs em grade regular latitude/longitude. Preserva os
campos ERA5 traduzidos pela Vtable: 37 níveis isobáricos e campos especiais de
superfície/solo. Ainda não está na mesh MPAS nem nos níveis verticais do
modelo.

### `init.nc`

É o resultado da união: static + meteorologia, horizontalmente interpolados
para x1.10242 e verticalmente interpolados para a grade do MPAS.

## First-guess levels não são model levels

`config_nfglevels=38` descreve a entrada first guess:

```text
37 pressure levels ERA5
        +
nível especial de superfície (level 200100)
        =
38 first-guess levels
```

Esses 38 níveis são um inventário de entrada. `config_nvertlevels=55` define o
número de camadas usadas pelo MPAS. O init não “acrescenta 17 níveis ERA5”;
ele constrói outra grade e interpola o perfil meteorológico disponível para
55 camadas.

O mesmo raciocínio vale para o solo, mas aqui as contagens coincidem:

```text
WPS: 4 camadas ST/SM
        ↓
config_nfgsoillevels=4
        ↓
config_nsoillevels=4
        ↓
MPAS: nSoilLevels=4
```

## Interpolação horizontal

Cada slab ERA5 está numa grade global regular 1440×721 de 0,25°. A mesh
x1.10242 tem 10.242 células poligonais. O real-data init localiza as células
MPAS na grade de origem e interpola os campos 3-D e 2-D. O log prova a leitura
e interpolação de GHT, TT, U, V e RH em 37 pressões, do nível especial de
superfície e dos campos PSFC, PMSL, SKINTEMP, SEAICE, SNOW, ST* e SM*.

A validação de consistência exige:

```text
mesh nCells = static nCells = init nCells = 10242
```

## Interpolação vertical e coordenada zeta

A grade vertical do MPAS é uma coordenada do modelo, independente dos níveis
isobáricos ERA5. O init primeiro constrói as interfaces geométricas `zgrid` e
depois interpola/ajusta os perfis atmosféricos.

A configuração usa:

- 55 camadas e 56 interfaces;
- topo de 30.000 m;
- terreno suavizado na geração da coordenada;
- `config_tc_vertical_grid=true`;
- `config_dzmin=0.3` e 30 passes de suavização conforme a baseline upstream;
- `config_extrap_airtemp='lapse-rate'` para valores fora do suporte vertical.

“Lapse rate” extrapola temperatura segundo uma taxa vertical, em vez de
prolongar arbitrariamente o último valor. O critério é útil perto do terreno,
onde a superfície real pode cortar níveis de pressão.

No arquivo observado, `zgrid` é finito e estritamente crescente em todas as
células. As espessuras variam de 46,8237305 a 927,277344 m e a interface
superior é exatamente 30.000 m.

## Model top

O model top limita o domínio vertical. A escolha de 30 km é suficiente para a
baseline inicial e coincide com o tutorial adotado. Ela não é universal:
experimentos com outra dinâmica, física ou fenômeno podem exigir topo e
resolução vertical diferentes. Mudar o topo altera a grade e exige nova
condição inicial.

## Umidade relativa versus umidade específica

`config_use_spechumd=false` manda o source 8.4.1 usar RH. Para cada ponto ele
calcula a razão de mistura de saturação e então:

```text
qv = 0.01 × rs × RH
```

Depois, RH abaixo do congelamento é recomputada em relação ao gelo. A entrada
não contém um campo de specific humidity adotado pela baseline, portanto não
se deve trocar o boolean apenas porque outra representação parece mais comum.

A conversão upstream não aplica clamp inferior. Foram observados seis valores
negativos muito pequenos em 563.310 valores de `qv`, mínimo
`-1,05322406e-05 kg/kg`, e dois de RH, mínimo `-0,152862608%`. O arquivo não
foi alterado. O validador conta os casos, aceita somente `qv >= -2e-5` e
`RH >= -0,2%` e falha além desses limites. Esta é uma tolerância numérica
explícita e uma dívida para o ciclo do forecast, não uma licença para umidade
negativa arbitrária.

## Skin temperature, SST e sea ice

A entrada possui `SKINTEMP`, mas não um arquivo SST separado. Com
`config_input_sst=false`, o source registra `Setting SST from SKINTEMP` e não
abre o stream surface. No resultado, `skintemp` e `sst` estão presentes,
finitos e entre aproximadamente 207 e 318 K.

`SEAICE` vem do WPS intermediate principal. `config_frac_seaice=true` preserva
fração em `xice`, enquanto `seaice` representa flag. Ambos ficaram entre 0 e
1. O leitor também procura opcionalmente `SEAICE_FRACTIONAL`; sua ausência não
é um missing obrigatório porque o ERA5 principal já forneceu SEAICE.

Não foi criado SST update. Isso será outra série temporal e outro estágio,
não parte da condição inicial única.

## Solo, neve e Noah-MP

Quatro temperaturas e quatro umidades de solo são interpoladas. O log executa
uma checagem de consistência e corrige pequenos valores de origem marcados como
`Bad sm_fg`. No output final:

- `tslb`: 212,806412–316,811157 K;
- `smois`: 6,41365614e-06–1;
- `sh2o`: 0–1;
- `dzs`: 0,1–1 m;
- `zs`: 0,05–1,5 m;
- todos finitos, sem fill/missing e com quatro camadas.

`config_noahmp_static=false` significa que o static e o init não carregam
`soilcomp` nem `soilcl1..4`. A ausência foi validada contra o Registry e é
coerente com esta baseline. Ela seria erro somente se uma física escolhida no
forecast exigisse Noah-MP.

## Decomposição e MPI

`part.4` associa cada uma das 10.242 células a um dos quatro blocos. O MPAS
precisa executar com a mesma cardinalidade:

```text
part.4 ↔ mpiexec -n 4
```

Os quatro ranks dividem cálculo e I/O; não dizem que quatro é o ótimo. O
particionamento tem 2.549–2.568 células por rank, imbalance simples de
0,292912%, edge cut 663 e cada partição é conexa.

## PIO e PnetCDF no output

O init escreve um NetCDF CDF-2 por PIO 2.7.0 sobre PnetCDF 1.15.0 e MPI-IO.
PIO abstrai a decomposição e coordena a escrita paralela; PnetCDF implementa o
acesso coletivo ao arquivo clássico de 64-bit offset. Nenhuma flag ROMIO foi
forçada. A escrita padrão completou em quatro ranks.

## Package `initial_conds`

O stream output usa `packages="initial_conds"`. Packages ativam conjuntos de
variáveis definidos no Registry sem duplicar listas no XML do caso. O package
produziu as variáveis exigidas pela condição inicial; streams `lbc`, `surface`
e `ugwp_oro_data` foram preservados nos defaults, mas seus packages/stages não
foram ativados.

Caso global não precisa de LBC. Lateral boundary conditions existem para uma
área limitada que recebe informação pelas bordas.

## Validação estrutural versus física

Validação estrutural pergunta se:

- o arquivo abre com netCDF-C;
- formato, dimensões, shapes e timestamp são corretos;
- variáveis Registry/package existem;
- não há fill, missing, NaN ou Inf;
- o manifesto identifica entradas, config e output.

Validação física pergunta se:

- densidade e pressão são positivas;
- temperaturas têm ranges amplos mas plausíveis;
- ventos são finitos;
- grade vertical é monotônica e tem espessura positiva;
- umidade, solo, neve e gelo respeitam seus domínios, incluindo tolerâncias
  numéricas justificadas;
- a equação de estado aplicada a `rho`, `theta` e `qv` resulta em pressão e
  temperatura coerentes.

Ranges amplos detectam corrupção; não impõem uma climatologia ao ERA5.

## Resultado observado

| Item | Resultado |
|---|---|
| Comando | `mpiexec -n 4 /opt/mpas-model-8.4.1/init_atmosphere_model` |
| Timer MPAS | 6,86265 s |
| Tempo no manifesto | 7 s |
| Formato | NetCDF CDF-2 / 64-bit offset |
| Tamanho | 92.641.692 bytes |
| SHA-256 | `9f2625d9f93ec873a8c1f3abef24083d1b03b910a77efea2f6dbfd2e13c36c7d` |
| Dimensões | nCells 10242; nVertLevels 55; nVertLevelsP1 56; nSoilLevels 4; Time 1 |
| Timestamp | `2014-09-10_00:00:00` |
| Log | 594 outputs; 0 warnings; 0 errors; 0 critical |
| Densidade | 0,0110501181–1,50876665 kg/m³ |
| Theta | 230,88118–899,896301 K |
| Pressão derivada | 675,040744–103.881,919 Pa |
| Temperatura derivada | 181,985102–314,156535 K |
| Vento horizontal `u` | -115,570831–114,740211 m/s |
| Pressão de superfície | 52.894,9805–104.173,656 Pa |
| NaN/Inf/missing | zero em todos os campos varridos |

## Comandos importantes

```sh
./scripts/validate/mesh.sh
./scripts/validate/static.sh
./scripts/validate/era5.sh
./scripts/validate/wps-era5.sh
./scripts/validate/mpas-init.sh
./scripts/run/generate-init.sh
./scripts/validate/init.sh
```

O runner repete somente as regressões diretamente consumidas, monta entradas
read-only, usa rootfs read-only, remove capabilities, desabilita rede, preserva
UID/GID, cria workspace controlado e recusa sobrescrever output divergente. O
manifesto guarda imagem, ranks, comando, hashes, timestamps, tamanho e hash do
init. Nova execução coerente retorna `init_generation=unchanged`.

O validador compila o smoke C dentro da imagem contra o netCDF-C já adotado,
confere log/manifesto e prova a igualdade mesh/static/init. Isso evita uma nova
dependência Python científica; Python padrão é usado somente para JSON.

## Falhas encontradas e diagnóstico

### Git `dubious ownership`

A primeira tentativa parou antes do MPAS porque o source em `/opt` pertence a
outro UID. A checagem foi corrigida com uma opção somente daquela invocação:

```sh
git -c safe.directory=/opt/mpas-model-8.4.1 -C /opt/mpas-model-8.4.1 rev-parse HEAD
```

Nenhum config global e nenhum arquivo em `/opt` foram modificados.

### Binário temporário em tmpfs sem execução

A execução científica seguinte concluiu, mas o validador não pôde executar o
C compilado porque o tmpfs estava `noexec`. A opção `exec` foi habilitada
somente no tmpfs efêmero do validador. O init já gerado foi preservado e não
foi repetido.

### Flags de ponto flutuante

Os quatro ranks emitiram ao launcher notas `IEEE_UNDERFLOW_FLAG` e
`IEEE_DENORMAL` após o término. O log MPAS registrou zero warnings/errors e o
arquivo não contém NaN/Inf. O fato é mantido como observação, não convertido
em flag ou workaround permanente.

### Entradas opcionais ausentes

O log informa ausência de `SEAICE_FRACTIONAL`, OMLD e climatologia mensal de
aerossóis QNWFA/QNIFA. Sea ice veio da entrada principal, OMLD não é requisito
desta baseline e aerossóis foram inicializados em zero. Não houve warning MPAS,
mas uma futura configuração de física deve decidir se esses campos continuam
adequados.

## Por que ainda não há previsão comprovada

Um `init.nc` válido prova que os dados atravessaram ERA5, WPS e o
`init_atmosphere`. Não prova que:

- o `atmosphere_model` aceita toda a configuração de physics;
- timestep e duração são estáveis;
- tabelas e campos opcionais são suficientes para o forecast;
- massa, energia e água se comportam adequadamente no tempo;
- a solução tem qualidade meteorológica.

O ciclo 0013 deve configurar, executar e validar o atmosphere separadamente.
Executá-lo aqui “só para ver se abre” misturaria dois gates científicos e
apagaria a fronteira didática entre condição inicial e previsão.

## O que o leitor deve aprender

Ao final, o leitor deve conseguir explicar:

1. por que mesh, static, WPS intermediate e init são artefatos diferentes;
2. por que 38 first-guess levels podem inicializar 55 model levels;
3. como interpolação horizontal e vertical mudam a representação dos dados;
4. como topo, zeta, soil layers, RH, SST e sea ice entram no caso;
5. por que part.4 e quatro ranks formam um contrato;
6. como PIO/PnetCDF escreve o output paralelo;
7. por que validação estrutural não substitui validação física;
8. por que um init válido ainda não é uma previsão.
