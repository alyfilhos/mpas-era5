# Ciclo 0009 — Gerar campos estáticos com a mesh real

## O que mudou e por quê

O ciclo produziu o primeiro `x1.10242.static.nc` do projeto em vez de baixar
um static pronto. Para isso, ele acrescentou aquisição verificável dos dados
geográficos WPS, uma configuração versionada do `init_atmosphere_model`,
execução científica isolada e uma validação NetCDF independente.

O objetivo didático é enxergar e provar a transformação:

```text
x1.10242.grid.nc + WPS_GEOG
              ↓
       init_atmosphere_model
              ↓
       x1.10242.static.nc
```

O Dockerfile e as versões de software não mudaram. Archives, dados extraídos,
logs e NetCDF ficam fora do Git.

## Três arquivos que não são equivalentes

### `grid.nc`

Representa a geometria e a topologia da mesh: centros de células, vértices,
arestas, vizinhança e métricas. Ele diz **onde** o modelo calcula, mas não diz
que tipo de solo ou vegetação há em cada célula.

### `static.nc`

Acrescenta propriedades da superfície que dependem da localização e da mesh,
mas não da data meteorológica: terreno, land use, categorias de solo,
vegetação, albedo e estatísticas orográficas para gravity-wave drag.

### `init.nc`

Será o estado meteorológico inicial em uma data: temperatura, vento, pressão,
umidade e outros campos tridimensionais. Ele exigirá ERA5 convertido para
WPS intermediate e não foi criado neste ciclo.

Portanto, `static.nc` não vem do ERA5. ERA5 descreve a atmosfera e superfícies
variáveis no tempo; WPS_GEOG fornece climatologias, categorias e topografia
estáticas.

## O que é WPS_GEOG

WPS_GEOG é uma coleção de rasters geográficos globais acompanhados de arquivos
`index`. O índice informa projeção, resolução, tiling, tipo de dados,
categorias e metadados como `mminlu`, água e gelo.

O MPAS lê esses tiles no mesmo formato usado pelo geogrid do WPS, mas interpola
diretamente para uma mesh não estruturada. Não é necessário executar
`geogrid.exe` para este caso.

A inspeção antes da extração foi essencial. O pacote
`geog_low_res_mandatory.tar.gz`, apesar de oficial e apropriado a muitos
testes educacionais WRF/WPS, não contém os diretórios de 30 arc-seconds
selecionados por esta configuração MPAS. O pacote high mandatory fornece seis
deles, mas não os dois diretórios legados exatos de land use. A solução usa
somente artefatos ligados pela página oficial WPS:

- high mandatory: topo, solo, temperatura do solo, vegetation fraction,
  albedo e maximum snow albedo;
- suplemento `modis_landuse_20class_30s`: land use MODIS sem lakes;
- suplemento `landuse_30s`: raster USGS usado pelo native GWD.

Não se renomeou `with_lakes` para parecer outro dataset. Um nome compatível
não transforma um produto em outro.

## Dados categóricos e contínuos

Dados contínuos representam uma quantidade numérica: elevação, fração de
vegetação ou albedo. Eles podem ser combinados por média/interpolação, dentro
da regra de cada campo.

Dados categóricos são IDs: floresta, água, urbano, classe de solo. A média de
“categoria 3” e “categoria 7” não cria uma categoria física 5. O algoritmo
contabiliza cobertura e escolhe a categoria dominante, preservando a tabela
`mminlu` e seus IDs válidos.

A validação, por isso, não trata todos os campos do mesmo modo: categorias
devem ser inteiras e estar em limites definidos; campos contínuos precisam de
faixas plausíveis, ausência de NaN/Inf e missing inesperado.

## Campos produzidos

### Topografia

`ter` representa altura da superfície interpolada. A faixa observada foi
-27 a 5.112,52686 m. Valores ligeiramente negativos são possíveis em regiões
terrestres abaixo do nível do mar ou pela representação do dataset.

### Land use e land mask

`ivgtyp` contém a classe dominante
`MODIFIED_IGBP_MODIS_NOAH`; `landmask` distingue água e terra. O arquivo
também registra `mminlu`, `isice_lu=15` e `iswater_lu=17`.

### Categorias de solo

`isltyp` usa STATSGO e ficou no intervalo inteiro 1..16. Esses números são
chaves de uma tabela física, não porcentagens.

### Vegetation fraction

`greenfrac` tem 12 meses. `shdmin` e `shdmax` resumem o mínimo e máximo
anual. A validação confirmou `shdmin <= shdmax` em todas as células.

### Albedo e maximum snow albedo

`albedo12m` fornece a climatologia mensal de refletância; `snoalb` fornece
o máximo associado à neve. O Registry e o próprio arquivo determinam os nomes
reais, evitando inventar variáveis por memória.

### Gravity-wave drag

Montanhas subgrid perturbam o escoamento e geram ondas de gravidade que a
mesh de 240 km não resolve explicitamente. `var2d`, `con`, `oa1..oa4` e
`ol1..ol4` descrevem variância, convexidade e anisotropia/orientação
orográfica para parametrização de drag.

O source 8.4.1 mostrou que native GWD lê `landuse_30s/` literalmente, além de
topografia. A convexidade `con` é uma razão de momentos e não está limitada
a 1 ou 10; seu máximo observado 232,8871 é compatível com a fórmula do source.
Derivar o teste do algoritmo evitou um falso positivo.

## Interpolação para uma mesh não estruturada

Os dados WPS estão numa grade latitude/longitude regular e tiled. A x1.10242
é uma malha de Voronoi esférica com células de forma e área variáveis. Para
cada célula MPAS, o init localiza pixels geográficos relevantes, agrega
contínuos ou calcula cobertura categórica e escreve o resultado no índice da
célula.

É por isso que o static depende da mesh. Trocar x1.10242 por outra mesh muda
centros, footprints e amostragem, portanto exige outro static.

## Supersampling

Supersampling avalia múltiplas subamostras dentro da célula/pixel de destino
para representar melhor heterogeneidade e fronteiras. Aumentar o fator aumenta
custo e pode ajudar quando a mesh é fina em relação ao dado fonte.

Há três referências diferentes:

- o User Guide atual recomenda fator 1 para Static Fields e destaca benefício
  em meshes abaixo de aproximadamente 6 km;
- o `Registry.xml` exato 8.4.1 tem default 3;
- o tutorial St Andrews não sobrescreve o default 3.

A x1.10242 tem aproximadamente 240 km. Esta baseline fixa explicitamente
`config_supersample_factor=1`, `config_lu_supersample_factor=1` e
`config_30s_supersample_factor=1`. A decisão reduz trabalho redundante e
não depende de um default implícito.

## `config_noahmp_static`

Noah-MP exige campos adicionais de composição do solo. O tutorial oficial do
primeiro caso x1.10242 usa `config_noahmp_static=false`, e esta baseline
educacional repete conscientemente essa restrição.

A validação confirma a ausência de `soilcomp` e `soilcl1..soilcl4`. Logo:

- o static é válido para a baseline que não exige Noah-MP;
- ele não é um static universal;
- um caso futuro com Noah-MP deve produzir outro arquivo em outro diretório;
- não se deve sobrescrever esta evidência para mudar silenciosamente sua
  semântica.

## Por que static independe da data e pode ser reutilizado

A mesh e os mapas de topografia/categoria/climatologia não mudam quando a data
de inicialização muda. Um static pode, portanto, ser reutilizado para vários
`init.nc` que usem a mesma mesh, seleções geográficas e compatibilidade de
física.

“Reutilizável” não significa eterno: mudar dataset, versão/algoritmo,
supersampling, Noah-MP ou mesh altera a proveniência e pode exigir regeneração.

## MPI com uma task

`init_atmosphere_model` continua sendo um binário MPI. O comando foi:

```sh
mpiexec -n 1 /opt/mpas-model-8.4.1/init_atmosphere_model
```

Uma task é a recomendação conservadora do User Guide para Static Fields e é
suficiente para 10.242 células. O tutorial St Andrews demonstra static em
paralelo, portanto a evidência não sustenta dizer que interpolação estática
“não suporta paralelismo”. Ela apenas fixa uma baseline portátil.

## Bind mounts e isolamento

`scripts/run/generate-static.sh` executa sem rede e com:

- imagem e root filesystem read-only;
- mesh, geografia e configuração montadas read-only;
- somente o diretório de output writable;
- UID/GID do host, evitando arquivos root-owned;
- capabilities removidas e `no-new-privileges`;
- workdir controlado, sem alterar `/opt/mpas-model`.

Bind mounts conectam arquivos do host a caminhos previsíveis do container:
`/mesh`, `/geog`, `/config` e `/output`. O namelist usa `/geog/`, um
caminho absoluto válido dentro do container, sem incorporar o caminho pessoal
do host.

## Aquisição e integridade

`scripts/data/fetch-geog.sh`:

1. usa URLs first-party;
2. confere tamanho e SHA-256 antes de ler;
3. testa compressão e lista o archive;
4. rejeita paths absolutos, traversal e links;
5. extrai somente os diretórios aprovados;
6. valida índices e a semântica MODIS;
7. grava um manifesto SHA-256 de todos os arquivos;
8. na reexecução, aceita somente conteúdo idêntico e recusa divergência.

Não há SHA-256 upstream para esses arquivos. O documento não atribui os hashes
à NCAR: registra que foram calculados localmente. Os dois suplementos foram
baixados duas vezes; o high passou por ranges independentes e checks de
archive, uma compensação explícita ao custo de repetir mais 2,77 GB.

## Validação física básica

`scripts/validate/static.sh` compila
`tests/smoke/static_netcdf.c` contra netCDF-C da imagem final. O programa
abre o NetCDF, confere formato/dimensões/atributos/campos, percorre todos os
valores e contabiliza missing, NaN, Inf, não-inteiros e violações de ranges.

O resultado final confirmou:

- CDF-2 legível, `nCells=10242`, `nMonths=12`, `Time=1`;
- todos os campos esperados pelo Registry/source presentes;
- cinco campos Noah-MP deliberadamente ausentes;
- zero missing inesperado e zero NaN/Inf;
- categorias integrais e em faixas plausíveis;
- `shdmin <= shdmax`;
- GWD presente e finito;
- log com 0 errors e 0 critical errors.

O validador não demonstra que toda célula representa perfeitamente a verdade
geográfica. Ele detecta corrupção, incompatibilidade estrutural e anomalias
físicas grosseiras.

## Falhas encontradas e diagnóstico

### Pacote low-resolution incompatível

A listagem real contradisse a expectativa inicial. O processo parou antes de
adotar o arquivo, conforme a regra do ciclo, e continuou somente depois da
autorização explícita para completar a baseline com fontes oficiais exatas.

### MODIS sem lakes ausente do pacote high

O archive high atual oferece `modis_landuse_20class_30s_with_lakes`. Usar um
alias teria feito o namelist dizer uma coisa e os bytes representarem outra.
O suplemento oficial legado fornece exatamente o índice selecionado.

### Primeira execução sem `landuse_30s`

O init completou vários estágios e falhou no native GWD com
“Error reading global 30-arc-sec landuse for GWD statistics”. A leitura do
source `mpas_init_atm_gwd.F` confirmou o path literal. O output parcial foi
isolado e não promovido; logs ficam localmente em
`static-attempt-1-missing-landuse/`. Depois da aquisição do suplemento exato,
a segunda execução terminou com zero erros.

### Build do validador

O primeiro compile não encontrou headers netCDF. A correção usa
`nc-config --cflags --libs`, que deriva include/library flags da instalação
real em vez de fixar paths duplicados.

### Tmpfs não executável

O primeiro runtime do smoke encontrou tmpfs sem permissão de execução. O mount
foi tornado explicitamente `exec`; os inputs permanecem read-only e o
artefato compilado continua efêmero.

### Range de convexidade GWD

Um limite inicial estreito para `con` não era sustentado pelo source. A fórmula
de quarto momento permite valores maiores; o teste foi corrigido para uma
faixa de sanidade ampla e documentada, preservando a detecção de NaN/Inf e
valores absurdos.

## Arquivos alterados

- `.gitignore`: exclusão de `data/geog/`;
- `scripts/data/fetch-geog.sh`: aquisição e instalação;
- `cases/first-global-240km/static/*`: namelist e streams;
- `scripts/run/generate-static.sh`: execução científica;
- `scripts/validate/static.sh` e `tests/smoke/static_netcdf.c`: validação;
- documentação de caso, estado, fontes, versões, arquitetura e testes;
- ADR 0006 e esta learning note.

## Comandos importantes

```sh
./scripts/data/fetch-geog.sh
./scripts/validate/mesh.sh
./scripts/run/generate-static.sh
./scripts/validate/static.sh
git diff --check
git status --short
git status --ignored --short
```

`fetch-geog` materializa entradas. `mesh.sh` protege a regressão da entrada.
`generate-static` cria o output uma única vez e recusa sobrescrita.
`static.sh` faz validação independente. Os comandos Git verificam whitespace,
escopo versionável e se dados gerados permanecem ignorados.

## Resultado real

- base: `7555a96a7c706ea9e719f23ff27eaf29498ffe05`;
- geografia instalada: 16.563.576.021 bytes;
- execução: 1 task MPI, 1.042 segundos;
- output: 18.201.336 bytes, CDF-2;
- SHA-256:
  `36e50a8f8d0233327b6505f74e2f909aaaa6c7cee03499affabadd5cc11a144f`;
- log: 3.016 outputs, 6 warnings de metadata opcional, 0 errors e 0 critical;
- validação static: PASS;
- regressão mesh: PASS.

## Trade-offs e dívida

A extração seletiva economiza espaço em relação ao pacote high completo, mas
o archive comprimido de 2,77 GB ainda precisa ser adquirido. O high não foi
baixado integralmente duas vezes; ranges independentes, tamanho, hash, gzip e
tar fornecem a evidência registrada. Os hashes são locais porque o upstream
não publica SHA-256.

Os seis warnings da mesh são mantidos visíveis. Eles não impediram static, mas
um ciclo que necessite boundary masks ou semântica temporal deve reavaliá-los.
Noah-MP, ERA5, `init.nc` e previsão continuam trabalho futuro.

## Limite do que o ciclo prova

O PASS prova:

```text
mesh real + geografia oficial → init_atmosphere static → static.nc válido
```

Ele não prova:

- ERA5 ou CDS API;
- Vtable/ungrib/WPS intermediate funcionais;
- `init.nc`;
- SST update ou sea ice temporal;
- escolha de physics;
- execução ou qualidade científica do `atmosphere_model`.

Ao final, o leitor deve conseguir distinguir grid/static/init, explicar por que
geografia e ERA5 são entradas diferentes, reproduzir o static, interpretar os
checks básicos e reconhecer quando ele não pode ser reutilizado.
