# Primeiro caso global — x1.10242 / ~240 km

## Status

**Mesh, dados geográficos, campos estáticos, ERA5 bruto, Vtable e WPS intermediate validados.**

O ciclo 0009 executou pela primeira vez o `init_atmosphere_model` 8.4.1
sobre a mesh real x1.10242 e produziu
`data/cases/first-global-240km/static/x1.10242.static.nc`. O ciclo 0010
adquiriu os dois GRIBs globais. O ciclo 0011 validou a `Vtable.ECMWF`, executou
`ungrib` separadamente e produziu o WPS intermediate combinado. `init.nc` e a
previsão continuam fora deste estágio.

## Baseline

| Campo | Valor |
|---|---|
| Mesh | `x1.10242` |
| Tipo | global, SCVT quasi-uniforme |
| Resolução nominal | aproximadamente 240 km |
| Células horizontais | 10.242 |
| Particionamento do caso futuro | `x1.10242.graph.info.part.4` |
| MPAS | 8.4.1, imagem `mpas-era5:mpas-atmosphere-8.4.1` |
| Etapa static | exatamente uma task MPI |
| Output | `x1.10242.static.nc`, CDF-2 / 64-bit offset |

A mesh fica em `data/meshes/x1.10242/`; dados geográficos ficam em
`data/geog/mpas-8.4.1/`; o output e os logs ficam em
`data/cases/first-global-240km/static/`. Todos são ignorados pelo Git. O
repositório preserva somente aquisição, configuração, execução e validação.

## Baseline meteorológica ERA5

O [[../decisions/0007-first-era5-baseline|ADR 0007]] fixa:

| Campo | Seleção |
|---|---|
| Instante | `2014-09-10 00:00:00 UTC` |
| Área final | global; `area` omitida |
| Grade final | regular latitude/longitude CDS, 0,25°; `grid` omitido |
| Formato | GRIB, `download_format=unarchived` |
| Pressure dataset | `reanalysis-era5-pressure-levels` |
| Pressure levels | todos os 37 níveis, de 1000 a 1 hPa |
| Pressure variables | geopotential, RH, temperature, U e V |
| Single dataset | `reanalysis-era5-single-levels` |
| Single variables | 19 campos de superfície, pressão, solo, neve e gelo |
| Cliente | `cdsapi==0.7.7` em container Python 3.12.13 por digest |

As requests completas estão em
[`cases/first-global-240km/era5/`](../../cases/first-global-240km/era5/).
Elas omitem recorte e regrid. Um probe temporário mantém todas as 204
mensagens esperadas — 185 pressure e 19 single-level — numa área de 1° × 1°,
validando a API e o transporte antes do download global.

O cliente dedicado é separado da imagem
`mpas-era5:mpas-atmosphere-8.4.1`. A credencial é montada read-only em
`/run/secrets/cdsapirc`, sem `ARG`, `ENV`, cópia ou log do token. O destino
local observado é:

```text
data/era5/2014-09-10_00/
├── era5-pressure-levels.grib
├── era5-single-levels.grib
└── manifest.json
```

Build, `pip check`, versão, requests e self-test do framing GRIB passaram. O
preflight inicialmente recusou com segurança a ausência de `~/.cdsapirc`;
depois que a credencial regular com modo `600` e os termos foram
disponibilizados, os dois probes autenticados passaram:

| Probe | Bytes | Mensagens | Edição | SHA-256 local |
|---|---:|---:|---:|---|
| pressure levels | 29.230 | 185 | GRIB1 | `ee199692c9cee1a1c6983be1f90a523f903889a1b06d58fefeb7d0a98b60f341` |
| single levels | 3.118 | 19 | GRIB1 | `b18bee89bcca223af1be15e4ecbd97a3b46556e651d51c945d9e221d2c928420` |

Os probes foram descartados depois da validação. Os arquivos globais
promovidos atomicamente e registrados no manifesto local são:

| Arquivo | Bytes | Mensagens | Edição | SHA-256 local |
|---|---:|---:|---:|---|
| `era5-pressure-levels.grib` | 384.168.780 | 185 | GRIB1 | `11a0a10a5727a19f64c529179af8b9e5fc4f92cdb60eb32ac90c68926b2e06ac` |
| `era5-single-levels.grib` | 41.995.970 | 19 | GRIB1 | `5d0c6aeeef07c5109f044428266d822928c2cf4ccda1ccbb430c916f0b5b693b` |

Uma segunda execução reconheceu ambos como `unchanged` e não submeteu novo
retrieve. O sucesso dos dois datasets confirma autenticação e termos sem
expor o token; os checksums identificam os bytes recebidos e não são hashes
publicados pelo CDS.

## WPS intermediate ERA5

O ciclo 0011 usou `g1print.exe` da própria tag WPS 4.7.0 para provar edição,
tempo, parameter code, level type e níveis de cada GRIB. As 185 mensagens
pressure e 19 single-level casaram, uma a uma, a `Vtable.ECMWF` upstream; não
foi necessário copiar ou modificar a tabela.

Pressure e single-level foram processados em workspaces isolados e limpos,
com prefixes `ERA5_PRES` e `ERA5_SFC`. Ambos os logs registram sucesso
explícito. Somente depois da validação estrutural individual os arquivos foram
concatenados e promovidos:

| Arquivo local | Bytes | SHA-256 | Slabs |
|---|---:|---|---:|
| `ERA5_PRES:2014-09-10_00` | 768.340.520 | `f0a47a4eee5fb29ae37e6cbe8ffc19fbb68a394d8a7e14bd7e57c714cecdae8b` | 185 |
| `ERA5_SFC:2014-09-10_00` | 78.910.648 | `e1ea9841ee7a2b085e204e111d3747af87a746b4fd7c5eca2f2894d4d3a8400e` | 19 |
| `ERA5:2014-09-10_00` | 847.251.168 | `2d7a3ac93d1c904e45b3a19a9f524e6367f7fe72abab41a5263888f1a72b50f0` | 204 |

O parser versionado confirmou formato WPS intermediate version 5 em registros
Fortran sequential big-endian, grade cilíndrica equidistante 1440×721,
0,25°, cobertura global e timestamp correto. O inventário final fornece
`HGT/RH/TT/UU/VV` nos 37 níveis, pressões e terreno superficiais, vento e
termometria próximos à superfície, neve, gelo, skin temperature e quatro
camadas de temperatura/umidade do solo.

Configuração, execução e validação:

```sh
./scripts/validate/era5.sh
./scripts/run/ungrib-era5.sh
./scripts/validate/wps-era5.sh
```

Os três intermediates, dois logs e manifesto ficam em
`data/cases/first-global-240km/wps/`, ignorados pelo Git.

## Dados geográficos adotados

A primeira opção pesquisada foi o pacote first-party
`geog_low_res_mandatory.tar.gz`, recomendado pelo WPS para model testing e
uso educacional. O archive observado possui 149.872.777 bytes e SHA-256 local
`cbdbcc43554d946a38cbce658b7d563afd7a2889f2c0735b8aa3f2206c7256e7`.
A inspeção do conteúdo real mostrou que ele não contém os diretórios de
30 arc-seconds exigidos pelas seleções desta baseline, portanto ele não foi
adotado nem combinado silenciosamente com dados arbitrários.

A composição final usa exclusivamente três artefatos indicados pela página
oficial WPS Geographic Static Data:

| Artefato oficial | Uso | Bytes comprimidos | SHA-256 local |
|---|---|---:|---|
| `geog_high_res_mandatory.tar.gz` | topo, solo, temperatura do solo, vegetação, albedo e snow albedo | 2.772.782.816 | `89b026b9db0a03c0c995e53b4a1d99663af1f6bda21b3b34c3c2c07386da5493` |
| `modis_landuse_20class_30s.tar.bz2` | land use exato `MODIFIED_IGBP_MODIS_NOAH` | 32.334.661 | `b21ca154d1038ec271abaa1be2fd38a0cd055b8a4ddfaab520719478ac48d326` |
| `landuse_30s.tar.bz2` | land use USGS de 24 categorias lido diretamente pelo código de GWD | 20.988.479 | `143cd195ae91f64011a43eae52ca00228709672c6a2ba614cb437eeb4cd41160` |

Não foram encontrados SHA-256 publicados pelo upstream. O archive high foi
montado e verificado a partir de ranges HTTP independentes, com tamanho
esperado, `gzip -t` e listagem completa `tar`; os dois suplementos menores
foram baixados duas vezes, comparados byte a byte e produziram o mesmo hash.
A página WPS informa aproximadamente 29 GB descomprimidos para o pacote high;
a extração seletiva realmente instalada ocupa 16.563.576.021 bytes. Nenhum
dado entra na imagem Docker.

Mapeamento confirmado no source MPAS 8.4.1 e nos arquivos `index` reais:

| Seleção/uso MPAS | Diretório local |
|---|---|
| `config_landuse_data='MODIFIED_IGBP_MODIS_NOAH'` | `modis_landuse_20class_30s/` |
| `config_topo_data='GMTED2010'` | `topo_gmted2010_30s/` |
| `config_soilcat_data='STATSGO'` | `soiltype_top_30s/` |
| temperatura do solo | `soiltemp_1deg/` |
| `config_vegfrac_data='MODIS'` | `greenfrac_fpar_modis/` |
| `config_albedo_data='MODIS'` | `albedo_modis/` |
| `config_maxsnowalbedo_data='MODIS'` | `maxsnowalb_modis/` |
| `config_native_gwd_static=true` | `topo_gmted2010_30s/` e `landuse_30s/` |

O pacote high atual traz `modis_landuse_20class_30s_with_lakes`, mas não o
diretório legado sem lakes que o MPAS 8.4.1 seleciona. Nenhum alias foi
inventado: o suplemento WPSv3 exato foi usado. A primeira tentativa científica
também revelou no source a leitura literal de `landuse_30s/` por GWD; o
suplemento oficial correspondente corrigiu a ausência.

## Configuração static

Os arquivos em `cases/first-global-240km/static/` partem dos defaults
gerados pela própria release 8.4.1. As opções efetivas principais são:

```fortran
&nhyd_model
    config_init_case = 7
/
&dimensions
    config_nvertlevels = 1
    config_nsoillevels = 1
    config_nfglevels = 1
    config_nfgsoillevels = 1
/
&data_sources
    config_geog_data_path = '/geog/'
    config_landuse_data = 'MODIFIED_IGBP_MODIS_NOAH'
    config_soilcat_data = 'STATSGO'
    config_topo_data = 'GMTED2010'
    config_vegfrac_data = 'MODIS'
    config_albedo_data = 'MODIS'
    config_maxsnowalbedo_data = 'MODIS'
    config_supersample_factor = 1
    config_lu_supersample_factor = 1
    config_30s_supersample_factor = 1
    config_noahmp_static = false
/
&preproc_stages
    config_static_interp = true
    config_native_gwd_static = true
    config_native_gwd_gsl_static = false
    config_vertical_grid = false
    config_met_interp = false
    config_input_sst = false
    config_frac_seaice = false
/
```

O User Guide recomenda supersampling 1 para static e explica que fatores
maiores são especialmente relevantes em meshes abaixo de aproximadamente
6 km. Para esta mesh de ~240 km, fator 1 evita amostragem redundante. Isso
difere tanto do default 3 no `Registry.xml` 8.4.1 quanto do tutorial St
Andrews, que deixa o default 3 implícito; a escolha aqui é deliberada.

`config_noahmp_static=false` é uma restrição deste primeiro caso educacional,
coerente com o exemplo x1.10242 do tutorial St Andrews 2025. Não é regra geral
do projeto. O arquivo gerado não contém `soilcomp` nem `soilcl1..soilcl4`
e não deve ser usado com uma física futura que exija campos Noah-MP. Tal
experimento deverá gerar outro static em outro caso, sem sobrescrever esta
baseline.

## Streams e execução

`streams.init_atmosphere` preserva a estrutura e os streams gerados pela
release. Somente o stream `input` lê `x1.10242.grid.nc` e `output`
escreve `x1.10242.static.nc`. Os streams `surface`, `lbc` e `ugwp_oro`
permanecem no arquivo, mas são ignorados porque seus preproc stages estão
desligados.

O User Guide atual orienta uma task MPI para Static Fields; o tutorial St
Andrews 2025 demonstra execução paralela. Isso não significa que static seja
intrinsecamente serial. A baseline conservadora local usa exatamente uma task,
ainda com o executável MPI:

```sh
./scripts/data/fetch-geog.sh
./scripts/validate/mesh.sh
./scripts/run/generate-static.sh
./scripts/validate/static.sh
```

Dentro do container, o comando científico exato é:

```sh
mpiexec -n 1 /opt/mpas-model-8.4.1/init_atmosphere_model
```

A execução usa `--network none`, usuário com UID/GID do host, filesystem
read-only, mesh/geografia/configuração read-only e somente o diretório de
output writable. Nada é modificado em `/opt/mpas-model`.

## Resultado observado

| Propriedade | Resultado |
|---|---|
| Tempo | 1.042 s no wrapper; timer MPAS 1.041,84729 s |
| Arquivo | `data/cases/first-global-240km/static/x1.10242.static.nc` |
| Tamanho | 18.201.336 bytes |
| SHA-256 | `36e50a8f8d0233327b6505f74e2f909aaaa6c7cee03499affabadd5cc11a144f` |
| Formato | NetCDF CDF-2, 64-bit offset |
| Dimensões centrais | `nCells=10242`, `nEdges=30720`, `nVertices=20480`, `nMonths=12`, `Time=1` |
| Log | 3.016 outputs, 6 warnings, 0 errors, 0 critical errors |

Os seis warnings dizem respeito a metadados opcionais ausentes na mesh:
`parent_id`, três `bdyMask*` e `xtime` não seekable. A execução forçou o
primeiro registro e completou; não houve erro ou critical error.

A validação independente derivada do Registry/source confirmou os campos
`ter`, `landmask`, `ivgtyp`, `isltyp`, `snoalb`, `soiltemp`,
`greenfrac`, `shdmin`, `shdmax`, `albedo12m`, `var2d`, `con`,
`oa1..oa4` e `ol1..ol4`. Todos tiveram zero missing inesperado e zero
NaN/Inf. Faixas observadas principais:

| Campo | Mínimo | Máximo |
|---|---:|---:|
| `ter` | -27,0 m | 5.112,52686 m |
| `landmask` | 0 | 1 |
| `ivgtyp` | 1 | 19 |
| `isltyp` | 1 | 16 |
| `snoalb` | 0 | 0,839999974 |
| `soiltemp` | 0 | 305,01825 K |
| `greenfrac` | 0 | 90,0664444 |
| `albedo12m` | 6,29671335 | 70 |
| `var2d` | 0 | 2.023,71582 |
| `con` | 0 | 232,8871 |
| `oa1..oa4` | -1 | 1 |
| `ol1..ol4` | 0 | 1 |

As categorias são inteiras e permanecem nos limites dos arquivos `index`.
O zero em `soiltemp` ocorre sobre água. O limite de convexidade GWD foi
derivado da fórmula do source 8.4.1, não de uma suposição de normalização.

## O que este estágio prova

```text
x1.10242.grid.nc ✅
        +
dados geográficos oficiais WPS ✅
        ↓
init_atmosphere_model 8.4.1, 1 task MPI
        ↓
x1.10242.static.nc ✅
        ↓
ERA5 pressure + single-level GRIB ✅
        ↓
Vtable.ECMWF + WPS 4.7.0 ungrib ✅
        ↓
ERA5:2014-09-10_00 ✅
        ↓
init.nc ⏳
```

Isto prova a geração dos campos estáticos e, separadamente, o caminho
ERA5 real → WPS intermediate combinado. Não prova WPS intermediate →
`init.nc`, não prova compatibilidade com Noah-MP, não executa
`atmosphere_model` e não constitui validação meteorológica de uma previsão.

## Próximas decisões ainda pendentes

- geração e validação de `init.nc`;
- duração, timestep e configuração de physics;
- execução do `atmosphere_model` com partição compatível;
- validação científica quantitativa.
