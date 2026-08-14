# ADR 0007 — Baseline ERA5 do primeiro caso global

- Estado: aceito
- Data: 2026-08-14
- Responsáveis: usuário e agente Codex
- Requisitos relacionados: REQ-DATA-001, REQ-CASE-002
- Fontes relacionadas: entradas CDS, ERA5, WPS e MPAS em
  [[../references/source-registry|source-registry.md]]

## Contexto

O primeiro caso global x1.10242 já possui mesh, `part.4`, dados geográficos e
`static.nc`. A próxima entrada é um estado meteorológico real que, em ciclos
separados, percorrerá:

```text
CDS ERA5 → GRIB → WPS ungrib → WPS intermediate
         → MPAS init_atmosphere → init.nc
```

Este ADR fixa a fonte, o instante, o inventário e a arquitetura de aquisição.
Ele não escolhe definitivamente uma Vtable e não autoriza executar
`ungrib.exe` no ciclo 0010.

O inventário foi derivado do `Vtable.ECMWF` do WPS 4.7.0, do leitor real-data
e `Registry.xml` do MPAS-Model 8.4.1, dos nomes atuais do catálogo CDS e do
caso x1.10242 do tutorial oficial St Andrews 2025.

## Opções consideradas

### A. Usar 2014-09-10 00 UTC, instante do tutorial x1.10242

Selecionada. É histórica, estável, não depende de ERA5T e permite comparar o
primeiro pipeline com um caso educacional upstream conhecido.

### B. Escolher um evento meteorológico extremo ou data recente

Rejeitada para a primeira baseline. Acrescentaria objetivos científicos e,
no caso recente, possível dependência de ERA5T antes de provar o pipeline.

### C. Recortar a área ou alterar a grade

Rejeitada para o download final porque o primeiro caso MPAS é global. Os
requests finais omitem `area` e `grid`, preservando a grade regular global de
0,25° fornecida pelo produto CDS. Somente o probe temporário usa uma área de
1° × 1° para reduzir transporte.

### D. Migrar para ERA5 NetCDF e `era5_to_int`

Não selecionada. Essa é a rota usada pelo tutorial recente para dados do NCAR
RDA, mas os datasets atuais do CDS continuam oferecendo GRIB. A arquitetura
aprovada permanece CDS GRIB → WPS 4.7.0; incompatibilidade empírica no probe
deve interromper o ciclo, não provocar migração silenciosa.

### E. Cliente em venv local ou dentro da imagem científica

Rejeitadas. Um venv seria menor em número de arquivos, mas dependeria mais do
Python do host. Incluir `cdsapi` na imagem MPAS/WPS misturaria aquisição via
rede e credenciais com a stack científica já validada.

### F. Container dedicado ao CDS

Selecionada. Usa Python 3.12.13 slim-bookworm por digest, `cdsapi==0.7.7` e
lock completo das dependências Python observadas. Não contém MPAS, WPS, MPI,
credencial ou dados científicos.

## Decisão

Adotar a seguinte baseline:

- instante: `2014-09-10 00:00:00 UTC`;
- domínio: global;
- produto: reanálise determinística horária;
- formato: GRIB desarquivado;
- grade: regular latitude/longitude padrão do CDS, 0,25°, sem regrid;
- pressure dataset: `reanalysis-era5-pressure-levels`;
- single-level dataset: `reanalysis-era5-single-levels`.

### Pressure levels

Usar todos os 37 níveis do produto:

```text
1, 2, 3, 5, 7, 10, 20, 30, 50, 70,
100, 125, 150, 175, 200, 225, 250, 300,
350, 400, 450, 500, 550, 600, 650, 700,
750, 775, 800, 825, 850, 875, 900, 925,
950, 975, 1000 hPa
```

Variáveis:

- `geopotential`;
- `relative_humidity`;
- `temperature`;
- `u_component_of_wind`;
- `v_component_of_wind`.

A baseline mantém `config_use_spechumd=false`, por isso escolhe umidade
relativa diretamente. Os 37 níveis isobáricos mais o nível especial de
superfície criado pelo WPS resultam em `config_nfglevels=38`; não existem 38
pressure levels neste produto.

### Single levels

Usar exatamente:

- ventos de 10 m: `10m_u_component_of_wind`,
  `10m_v_component_of_wind`;
- estado de 2 m: `2m_temperature`, `2m_dewpoint_temperature`;
- pressão e geopotencial: `surface_pressure`,
  `mean_sea_level_pressure`, `geopotential`;
- superfície: `land_sea_mask`, `skin_temperature`, `sea_ice_cover`,
  `snow_depth`;
- solo: `soil_temperature_level_1..4` e
  `volumetric_soil_water_layer_1..4`.

O WPS deriva umidade próxima à superfície do dew point, converte geopotencial
de superfície em altura do solo e converte o snow depth ECMWF para seu campo
`SNOW`. O MPAS 8.4.1 usa `SKINTEMP` como SST quando um campo SST separado não
está presente. Tipo de solo permanece responsabilidade do `static.nc`.

### Aquisição e segurança

Preservar as requests em `cases/first-global-240km/era5/` e os bytes somente
em `data/era5/2014-09-10_00/`. O container de `docker/cds/` recebe:

- requests read-only;
- `.cdsapirc` como secret file read-only em runtime;
- somente `data/era5/` como volume gravável no download;
- rede somente durante probe/download;
- UID/GID do usuário, root filesystem read-only, capabilities removidas e
  `no-new-privileges`.

O script baixa para arquivo temporário, confere framing/mensagens/edição GRIB,
tamanho e SHA-256 e promove atomicamente. Reexecução aceita apenas arquivos
iguais ao manifesto local. O probe executa os mesmos inventários numa área
reduzida e seus binários são descartados.

## Consequências

- a seleção meteorológica deixa de ser uma pendência e passa a ser contrato
  versionado;
- o download final é maior que um recorte, coerentemente com o domínio global;
- 185 mensagens pressure e 19 single-level são esperadas para um instante;
- credenciais, GRIBs e manifesto local permanecem fora do Git e da imagem;
- aceitar os termos de cada dataset continua sendo ação manual no portal;
- o checksum local prova identidade dos bytes recebidos, não que o CDS
  publique esse checksum;
- aquisição/estrutura GRIB não provam mapeamento campo a campo, unidades,
  compatibilidade definitiva da Vtable ou adequação científica;
- ciclo 0011 deve inspecionar o inventário com ferramenta GRIB confiável,
  escolher/validar a Vtable e então executar `ungrib.exe`.

## Evidências de validação

- requests: [`era5/`](../../cases/first-global-240km/era5/);
- container: [`docker/cds/`](../../docker/cds/);
- aquisição: [`fetch-era5.py`](../../scripts/data/fetch-era5.py) e
  [`fetch-era5.sh`](../../scripts/data/fetch-era5.sh);
- validação: [`era5.sh`](../../scripts/validate/era5.sh);
- resultados: [[../testing/validation-matrix|validation-matrix.md]];
- caso: [[../cases/first-global-240km|first-global-240km.md]];
- aprendizado:
  [[../../learning/commits/0010-add-era5-acquisition|ciclo 0010]].
