# Reprodução end-to-end

Este é o guia operacional para responder: “clonei o repositório; como
reproduzo o projeto?”. Ele reconstrói a baseline publicada, não um novo
experimento. Para entender decisões e resultados, use o
[[../architecture/project-graph|grafo]], o
[[../cases/first-global-240km|documento do caso]] e o
[[../project/completion-report|relatório final]].

## Contrato da reprodução

- baseline: MPAS-Model 8.4.1, WPS 4.7.0 e mesh x1.10242;
- instante: ERA5 2014-09-10 00 UTC;
- domínio: global;
- execução: 1 hora, `dt=1200 s`, 4 ranks e `part.4`;
- dados grandes: sempre em `data/`, ignorados pelo Git;
- credencial CDS: arquivo local `~/.cdsapirc`, nunca copiado para a imagem;
- nenhuma fase deve sobrescrever silenciosamente um artefato divergente.

## Fase 0 — host, Docker e espaço

### Pré-requisitos

- host Linux x86-64 com Git, Bash, Python 3 e Docker Engine;
- usuário capaz de acessar o daemon Docker;
- acesso à internet nas fases de build/aquisição;
- credencial CDS com modo `600` e termos aceitos para os dois datasets ERA5;
- espaço livre suficiente em filesystem e armazenamento Docker.

Os dados geográficos instalados ocuparam 16.563.576.021 bytes; os archives
somam 2.826.105.956 bytes. ERA5 bruto ocupa 426.164.750 bytes, os três WPS
intermediates 1.694.502.336 bytes, e static/init/run acrescentam cerca de
301 MB. Reserve margem acima desses valores e do armazenamento das imagens
Docker; 25–30 GB livres é uma estimativa operacional prudente, não uma
garantia para todo backend Docker.

```sh
git clone <URL-DO-REPOSITORIO>
cd mpas-era5
docker version
df -h .
git status --short --branch
```

Nada produzido nessa fase entra no Git além do clone. Consulte
[[../project/requirements|requisitos]] e
[[../references/versions.lock|versões congeladas]] antes de alterar qualquer
baseline.

## Fase 1 — imagem científica

| Item | Valor |
|---|---|
| Entrada | `Dockerfile` e fontes/releases fixadas |
| Comando | abaixo |
| Saída | `mpas-era5:mpas-atmosphere-8.4.1` |
| Git | Dockerfile é versionado; imagem/cache não |
| Tempo observado | não preservado como métrica normativa |
| Validação | smokes instalados e PnetCDF/PIO no validador final |

```sh
docker build --progress=plain \
  --build-arg BUILD_JOBS=8 \
  --tag mpas-era5:mpas-atmosphere-8.4.1 .
./scripts/validate/core-libraries.sh
```

A imagem contém GNU/OpenMPI, zlib/HDF5/netCDF, PnetCDF/PIO, METIS, WPS e
MPAS. O build da imagem de aquisição e o da imagem de análise são separados.
Detalhes: [[../build/scientific-stack|stack científica]].

## Fase 2 — mesh x1.10242 e partição

| Item | Valor |
|---|---|
| Pré-requisito | imagem científica |
| Entrada | pacote first-party x1.10242 |
| Output | grid, `graph.info` e `graph.info.part.4` |
| Local | `data/meshes/x1.10242/` |
| Git | tudo local/ignorado |
| Tamanho observado | grid: 14.014.372 bytes; archive: 6.321.104 bytes |
| Validação | 10.242 células; grafo válido/conectado; edge cut 663 |

```sh
./scripts/data/fetch-mesh.sh
./scripts/prepare/partition-mesh.sh
./scripts/validate/mesh.sh
```

O fetch valida tamanho e SHA-256 local fixado antes de extrair. A partição é
gerada com METIS 5.1.0; o número 4 deve corresponder aos quatro ranks.
Detalhes: [[../decisions/0005-first-mesh-baseline|ADR 0005]].

## Fase 3 — dados geográficos WPS

| Item | Valor |
|---|---|
| Pré-requisito | internet e ~20 GB de margem |
| Entrada | high mandatory + MODIS 30s + USGS landuse 30s |
| Output | oito datasets seletivos |
| Local | `data/geog/mpas-8.4.1/` |
| Git | archives, extração e manifesto ignorados |
| Tamanho observado | 2.826.105.956 bytes comprimidos; 16.563.576.021 extraídos |
| Validação | hashes locais, integridade dos archives, paths/indexes e manifesto |

```sh
./scripts/data/fetch-geog.sh
```

O pacote low-resolution foi inspecionado e não atende às seleções 30s do
caso. Não crie aliases entre datasets. Detalhes:
[[../decisions/0006-first-static-baseline|ADR 0006]].

## Fase 4 — `static.nc`

| Item | Valor |
|---|---|
| Pré-requisito | mesh e WPS_GEOG |
| Entrada | grid x1.10242, geografia e configuração em `cases/.../static/` |
| Comando | abaixo |
| Output | `x1.10242.static.nc` e log |
| Local | `data/cases/first-global-240km/static/` |
| Git | output/log ignorados; namelist/streams versionados |
| Tempo/tamanho observado | 1.042 s; 18.201.336 bytes |
| Validação | CDF-2, 10.242 células, campos/ranges/finitude e log |

```sh
./scripts/run/generate-static.sh
./scripts/validate/static.sh
```

O static usa uma task MPI, supersampling 1, native GWD e
`config_noahmp_static=false`.

## Fase 5 — ERA5 bruto

| Item | Valor |
|---|---|
| Pré-requisito | `~/.cdsapirc` modo 600 e termos CDS aceitos |
| Entrada | requests JSON versionadas pressure/single |
| Container | `mpas-era5:cdsapi-0.7.7` |
| Output | dois GRIBs e manifesto |
| Local | `data/era5/2014-09-10_00/` |
| Git | GRIB/manifesto/credencial ignorados; requests versionadas |
| Tamanho observado | 384.168.780 + 41.995.970 = 426.164.750 bytes |
| Validação | 185 + 19 mensagens GRIB1, hashes e framing |

```sh
./scripts/data/fetch-era5.sh build
./scripts/data/fetch-era5.sh probe
./scripts/data/fetch-era5.sh download
./scripts/validate/era5.sh
```

`probe` usa uma área temporária pequena antes do download global. O tempo do
download depende do CDS/rede e não é apresentado como benchmark. Detalhes:
[[../decisions/0007-first-era5-baseline|ADR 0007]].

## Fase 6 — WPS/ungrib e formato intermediate

| Item | Valor |
|---|---|
| Pré-requisito | ERA5 bruto e imagem científica |
| Entrada | dois GRIBs, namelists e `Vtable.ECMWF` upstream |
| Output | pressure, surface e combined intermediate; logs/manifesto |
| Local | `data/cases/first-global-240km/wps/` |
| Git | outputs/logs ignorados; configs e parser versionados |
| Tamanho observado | 768.340.520 + 78.910.648 + 847.251.168 bytes |
| Validação | 204 slabs, version 5, 1440×721, 0,25°, timestamp correto |

```sh
./scripts/validate/era5.sh
./scripts/run/ungrib-era5.sh
./scripts/validate/wps-era5.sh
```

O wrapper executa pressure e single em workspaces separados e só então
concatena os bytes validados. Detalhes:
[[../cases/first-global-240km#WPS intermediate ERA5|caso]].

## Fase 7 — condição inicial

| Item | Valor |
|---|---|
| Pré-requisito | mesh/part.4, static e WPS intermediate |
| Entrada | configuração `cases/.../init/` |
| Output | `x1.10242.init.nc`, log e manifesto |
| Local | `data/cases/first-global-240km/init/` |
| Git | outputs ignorados; configuração versionada |
| Tempo/tamanho observado | 7 s; 92.641.692 bytes |
| Validação | CDF-2, 55 níveis, 4 soil, estado físico e proveniência |

```sh
./scripts/run/generate-init.sh
./scripts/validate/init.sh
```

O comando científico interno é
`mpiexec -n 4 /opt/mpas-model-8.4.1/init_atmosphere_model`.
Detalhes: [[../decisions/0008-first-initial-condition-baseline|ADR 0008]].

## Fase 8 — primeira hora do atmosphere

| Item | Valor |
|---|---|
| Pré-requisito | init, part.4, física/lookup tables na imagem |
| Entrada | configuração `cases/.../atmosphere/` |
| Output | dois history, dois diagnostics, log e manifesto |
| Local | `data/cases/first-global-240km/atmosphere/run-001/` |
| Git | outputs/log/manifesto ignorados; configuração versionada |
| Tempo/tamanho observado | 8 s; ~190,5 MB de NetCDFs + log |
| Validação | relógio 00→01, 0 errors/critical, finitude e evolução |

```sh
./scripts/run/run-atmosphere.sh
./scripts/validate/atmosphere-run.sh
```

O comando interno é
`mpiexec -n 4 /opt/mpas-model-8.4.1/atmosphere_model`. A execução é
global, cold start, Noah, `mesoscale_reference`, sem LBC/restart/SST update.

## Fase 9 — análise científica e figuras

| Item | Valor |
|---|---|
| Pré-requisito | run-001, init e imagem de análise |
| Entrada | quatro NetCDFs e init, todos read-only |
| Output | summary JSON, CSV de `q2` e sete PNGs |
| Local | `docs/assets/validation/0014/` |
| Git | evidência pequena selecionada é versionada |
| Tamanho observado | summary 105.907 bytes; figuras ~4,8 MB |
| Validação | schema, critérios, CSV e PNGs |

```sh
docker build --progress=plain \
  --file docker/analysis/Dockerfile \
  --tag mpas-era5:analysis-0014 .
./scripts/validate/scientific-run.sh
```

O runtime de análise usa `--network none`, rootfs read-only e mounts de input
read-only. Resultados normativos:

```text
functional_validation=PASS
numerical_sanity=PASS
scientific_sanity=PASS
forecast_skill=NOT_EVALUATED
spinup=INSUFFICIENT_TEMPORAL_WINDOW
```

Detalhes: [[../validation/first-atmosphere-run|validação científica]] e
[[../decisions/0009-separate-analysis-container|ADR 0009]].

## Fase 10 — auditoria final local

Depois que todas as fases caras já estiverem materializadas:

```sh
./scripts/validate/final-project.sh
```

O script valida os artefatos canônicos, não baixa dados, não regenera static
ou init e não executa uma nova previsão. Ausências falham com instrução
explícita de reprodução. O resultado esperado termina com:

```text
PROJECT_BASE_STATUS=COMPLETE
project_validation=PASS
```

## O que deve e não deve ir para o Git

Versione configurações, scripts, fontes dos smokes, documentação, ADRs,
locks, requests ERA5, summary/CSV pequenos e as figuras selecionadas. Não
versione `.cdsapirc`, tokens, GRIB, NetCDF, WPS_GEOG, archives, logs de
execução, partições geradas, outputs MPAS, cache Python ou imagens Docker.

Em caso de dúvida, consulte `.gitignore`, execute `git status --ignored --short`
e use o [[../architecture/project-graph|grafo do projeto]] para localizar o
contrato correto.
