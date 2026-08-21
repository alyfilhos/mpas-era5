# Primeiro caso global — x1.10242 / ~240 km

## Status

**Pipeline até a primeira hora do MPAS Atmosphere validado funcionalmente.**

O ciclo 0009 executou pela primeira vez o `init_atmosphere_model` 8.4.1
sobre a mesh real x1.10242 e produziu
`data/cases/first-global-240km/static/x1.10242.static.nc`. O ciclo 0010
adquiriu os dois GRIBs globais. O ciclo 0011 validou a `Vtable.ECMWF`, executou
`ungrib` separadamente e produziu o WPS intermediate combinado. O ciclo 0012
executou o init meteorológico em quatro ranks e validou `x1.10242.init.nc`.
O ciclo 0013 consumiu esse init e a `part.4`, avançou o relógio por uma hora
e validou history/diagnostics em 00 e 01 UTC.

## Baseline

| Campo | Valor |
|---|---|
| Mesh | `x1.10242` |
| Tipo | global, SCVT quasi-uniforme |
| Resolução nominal | aproximadamente 240 km |
| Células horizontais | 10.242 |
| Particionamento do init e da primeira previsão | `x1.10242.graph.info.part.4` |
| MPAS | 8.4.1, imagem `mpas-era5:mpas-atmosphere-8.4.1` |
| Etapa static | exatamente uma task MPI |
| Output static | `x1.10242.static.nc`, CDF-2 / 64-bit offset |
| Init meteorológico | 4 ranks com `part.4`; 55 níveis MPAS; topo 30 km |
| Output init | `x1.10242.init.nc`, CDF-2 / 64-bit offset |
| Primeira integração | 2014-09-10 00→01 UTC; `dt=1200 s`; 4 ranks |
| Física | `mesoscale_reference`; Noah; radiação a cada 1 hora |
| LBC / restart / SST update | `false` / `false` / `false` |
| Outputs | history e diagnostics em 00 e 01 UTC, CDF-2 |

A mesh fica em `data/meshes/x1.10242/`; os dados geográficos ficam em
`data/geog/mpas-8.4.1/`; static e init, com seus logs, ficam sob
`data/cases/first-global-240km/`. Todos são ignorados pelo Git. O
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

## Init meteorológico

O ciclo 0012 partiu dos defaults gerados pelo MPAS 8.4.1 e do source exato
`v8.4.1`. A configuração versionada está em
[`cases/first-global-240km/init/`](../../cases/first-global-240km/init/) e fixa:

| Grupo | Configuração efetiva |
|---|---|
| Caso/tempo | case 7; `2014-09-10_00:00:00` |
| Modelo vertical | 55 níveis; topo 30.000 m; grade terrain-following suavizada |
| First guess | 38 níveis = 37 isobáricos + superfície especial |
| Solo | 4 first-guess e 4 MPAS |
| Meteorologia | prefix `ERA5`; RH, não specific humidity; lapse-rate |
| Stages | vertical grid e met interp ligados; static/GWD desligados |
| Superfície | SST separado desligado; sea ice fracionário ligado |
| Noah-MP | desligado, coerente com o static existente |
| MPI/decomposição | 4 ranks e `x1.10242.graph.info.part.4` |
| Streams ativos | input static e output `initial_conds`; sem LBC/surface update |

O comando científico exato foi:

```sh
mpiexec -n 4 /opt/mpas-model-8.4.1/init_atmosphere_model
```

O container executou offline, com rootfs read-only, capabilities removidas,
`no-new-privileges`, UID/GID do host e entradas/configuração read-only. O
workspace foi o único bind writable. A segunda invocação comprovou
idempotência com `init_generation=unchanged`.

### Output e log observados

| Propriedade | Resultado |
|---|---|
| Arquivo | `data/cases/first-global-240km/init/x1.10242.init.nc` |
| Formato | CDF-2 / NetCDF 64-bit offset |
| Tamanho | 92.641.692 bytes |
| SHA-256 | `9f2625d9f93ec873a8c1f3abef24083d1b03b910a77efea2f6dbfd2e13c36c7d` |
| Tempo | 7 s no manifesto; timer MPAS 6,86265 s |
| Dimensões | `nCells=10242`, `nVertLevels=55`, `nVertLevelsP1=56`, `nSoilLevels=4`, `Time=1` |
| Tempo do estado | `xtime=initial_time=2014-09-10_00:00:00` |
| Log | 594 outputs; 0 warnings; 0 errors; 0 critical |

O log confirma 38 first-guess levels, constrói a grade vertical, interpola os
37 níveis de GHT/TT/U/V/RH e o nível especial de superfície, usa SKINTEMP para
inicializar SST e processa SEAICE, SNOW e quatro camadas ST/SM. O caso global
não entra no caminho de LBC.

Mensagens informativas, embora não contem como warnings do MPAS:

- pequenos `Bad sm_fg` foram corrigidos pela checagem de consistência; o solo
  final não possui valor negativo, missing ou não finito;
- o arquivo opcional `SEAICE_FRACTIONAL` não existe, mas `SEAICE` da entrada
  principal gerou `xice/seaice` válidos entre 0 e 1;
- OMLD não foi fornecido nem exigido pela baseline;
- QNWFA/QNIFA mensal não foi encontrado e os aerossóis foram inicializados em
  zero; a adequação para a futura física permanece uma pendência do forecast;
- os quatro ranks sinalizaram underflow/denormal ao launcher após a conclusão,
  sem NaN/Inf ou incremento dos contadores do log.

### Validação estrutural e física

O smoke netCDF-C deriva nomes/shapes do Registry/package `initial_conds`. Todos
os campos varridos têm zero fill/missing e zero NaN/Inf. A grade vertical é
estritamente crescente, com espessuras de 46,8237305 a 927,277344 m e topo de
30.000 m.

| Campo | Mínimo | Máximo |
|---|---:|---:|
| `rho` | 0,0110501181 | 1,50876665 kg/m³ |
| `theta` | 230,88118 | 899,896301 K |
| pressão derivada por EOS | 675,040744 | 103.881,919 Pa |
| temperatura derivada por EOS | 181,985102 | 314,156535 K |
| `u` | -115,570831 | 114,740211 m/s |
| `w` | -0,146966845 | 0,179505661 m/s |
| `surface_pressure` | 52.894,9805 | 104.173,656 Pa |
| `skintemp` | 207,381104 | 316,890839 K |
| `sst` | 207,650192 | 318,184326 K |
| `t2m` | 208,159317 | 311,030151 K |
| `q2` | 5,16655018e-06 | 0,0245520175 kg/kg |
| `tslb` | 212,806412 | 316,811157 K |
| `smois` | 6,41365614e-06 | 1 |
| `sh2o` | 0 | 1 |
| `dzs` | 0,1 | 1 m |
| `zs` | 0,05 | 1,5 m |

O source 8.4.1 converte RH diretamente sem clamp inferior. Seis dos 563.310
valores de `qv` apresentam overshoot negativo pequeno, mínimo
`-1,05322406e-05 kg/kg`; dois valores de RH chegam a `-0,152862608%`. O
arquivo MPAS não foi pós-processado. O validador conta e limita explicitamente
essa tolerância (`qv >= -2e-5`, `RH >= -0,2%`); valores além disso falham. A
preparação do forecast deve reavaliar essa dívida.

`soilcomp` e `soilcl1..4` estão ausentes, como exige
`config_noahmp_static=false`, e não por falha de inicialização.

## Primeira integração temporal

O ciclo 0013 parte dos defaults e stream lists gerados pela build MPAS 8.4.1.
A configuração versionada em `cases/first-global-240km/atmosphere/` altera
somente o necessário para este caso:

```fortran
&nhyd_model
    config_dt = 1200.0
    config_start_time = '2014-09-10_00:00:00'
    config_run_duration = '01:00:00'
/
&limited_area
    config_apply_lbcs = false
/
&decomposition
    config_block_decomp_file_prefix = 'x1.10242.graph.info.part.'
/
&restart
    config_do_restart = false
/
&printout
    config_print_global_minmax_vel = true
    config_print_detailed_minmax_vel = false
/
&physics
    config_sst_update = false
    config_radtlw_interval = '01:00:00'
    config_radtsw_interval = '01:00:00'
    config_physics_suite = 'mesoscale_reference'
/
```

Os streams `input`, `output` e `diagnostics` leem
`x1.10242.init.nc` e escrevem intervalos de uma hora. O stream `surface`
continua inativo: não há `x1.10242.sfc_update.nc` e a SST permanece igual à
condição inicial durante este smoke curto. Isso não deve ser generalizado
automaticamente para previsões longas.

### Física resolvida no source 8.4.1

`mpas_atmphys_control.F` resolve a suite sem depender de nomes presumidos:

| Processo | Esquema efetivo |
|---|---|
| Microfísica | `mp_wsm6` |
| Convecção | `cu_ntiedtke` |
| Camada limite | `bl_ysu` |
| Gravity-wave drag | `bl_ysu_gwdo` |
| Fração de nuvem | `cld_fraction` |
| Radiação LW / SW | `rrtmg_lw` / `rrtmg_sw` |
| Surface layer | `sf_monin_obukhov_rev` |
| Land-surface model | `sf_noah` |

`sf_noahmp` não é selecionado, coerente com o static sem campos Noah-MP.
O runner liga read-only no workdir as 14 tabelas top-level padronizadas da
árvore `physics_wrf/files` já existente na imagem. Não baixa, copia para o
repositório nem modifica `/opt/mpas-model-8.4.1`; `NoahmpTable.TBL` não é
disponibilizada porque esta suite não a usa.

### Execução e manifesto

O comando científico foi:

```sh
mpiexec -n 4 /opt/mpas-model-8.4.1/atmosphere_model
```

`scripts/run/run-atmosphere.sh` executa sem rede, como UID/GID do host, com
rootfs read-only, `cap-drop ALL`, `no-new-privileges` e escrita limitada ao
workspace. O run canônico foi promovido atomicamente para
`data/cases/first-global-240km/atmosphere/run-001/`; uma segunda chamada
validou o conteúdo existente e retornou `unchanged`, sem sobrescrever bytes.
O manifesto registra 2026-08-21T15:43:28Z–15:43:36Z, wall time de 8 s, imagem
`sha256:9c9479db0bae4db1e8d827bf522caab312ad097217aba962cb399f18b74e93a8`,
commit MPAS `91c5eac175eebeaf4206bacd5cb50c39dff3c152`, hashes de entradas,
configurações e outputs.

| Arquivo | Bytes | SHA-256 |
|---|---:|---|
| `diag.2014-09-10_00.00.00.nc` | 5.268.556 | `be0f450bcccb763be327e3df69f784c2aca7337edc97642cf4fda579f7df1ff2` |
| `diag.2014-09-10_01.00.00.nc` | 5.268.556 | `e3cc0f3374a596c04fa8638a75b1448add06401a09c92643d2f65958acddc3de` |
| `history.2014-09-10_00.00.00.nc` | 89.983.848 | `07f93a016ca9c06cb4da8fa5c23426fe30d36f6e8c78ee0a410a2183b6ed029b` |
| `history.2014-09-10_01.00.00.nc` | 89.983.848 | `0369fe24eefd2e88de2016c15070abb2797128d987a5ab025de73e111e39c93b` |
| `log.atmosphere.0000.out` | 36.238 | `2e9628802bb75c94bbd43e6e9f6a3bd9eae32713a366b17a09fee6ea66367828` |

O log comprova leitura do init real, inicialização da suite e das tabelas
Noah, três timesteps iniciados em 00:00, 00:20 e 00:40, escrita do estado das
01:00 e término normal. O resumo tem 634 outputs, 3 warnings, 0 errors e
0 critical. Os warnings esperados informam que `qi`, `qs` e `qg` não
existem no cold-start; WSM6 os inicializa, e todos terminam finitos e
não negativos. Após a conclusão, cada rank também reportou ao launcher a
presença de underflow/denormal floating-point, sem incrementar os contadores
do log e sem NaN/Inf.

Os extremos globais impressos evoluíram:

| Início do timestep | `w` min/max (m/s) | `u` min/max (m/s) |
|---|---|---|
| 00:00 | -0,813270 / 0,455260 | -113,981 / 114,371 |
| 00:20 | -0,863554 / 0,547135 | -113,828 / 114,083 |
| 00:40 | -0,574540 / 0,634551 | -113,970 / 114,307 |

### Validação NetCDF e evolução

Os quatro outputs são CDF-2 legíveis e não truncados. History possui
`nCells=10242`, `nVertLevels=55`, `nVertLevelsP1=56` e
`nSoilLevels=4`; diagnostics possui 10.242 células. Os timestamps são
exatamente 00 e 01 UTC. O validador varreu 47.603.258 valores numéricos sem
encontrar NaN/Inf.

No estado final, `rho` fica em 0,0110501–1,50688 kg/m³, pressão derivada em
674,071–103.879,531 Pa, temperatura derivada em 182,177–313,264 K, `u` em
-113,970–114,307 m/s e `w` em -0,574540–0,634551 m/s. Superfície, solo e
umidade permanecem finitos; `smois`/`sh2o` ficam entre 0,02 e 1.

| Campo | Média t=0 | Média t=1h | Valores alterados | Máx. diferença absoluta |
|---|---:|---:|---:|---:|
| `rho` | 0,567435067 | 0,567456315 | 563.298 / 563.310 | 0,0238621 |
| `theta` | 387,861160 | 387,842178 | 563.282 / 563.310 | 18,1399 |
| `u` | 0,0128582 | 0,0143983 | 1.689.600 / 1.689.600 | 69,1453 |
| `qv` | 0,00274585766 | 0,00275305967 | 563.305 / 563.310 | 0,00363855 |
| `skintemp` | — | — | 3.295 / 10.242 | 20,2635 K |
| `sst` | — | — | 0 / 10.242 | 0 |

A umidade negativa conhecida do init não foi clamped: `qv` passou de mínimo
`-1,05322406e-05` com seis negativos para `8,90079619e-08 kg/kg` com zero
negativos. O diagnóstico `q2`, por outro lado, terminou com mínimo
`-4,71175474e-04 kg/kg` e 11 pontos negativos. A fórmula da surface layer
revisada no source 8.4.1 extrapola `q2` sem clamp; o validador registra e
limita essa ocorrência, mas ela permanece dívida para investigação
meteorológica. Não houve crescimento absurdo, NaN/Inf ou instabilidade.

## O que este estágio prova

```text
x1.10242.static.nc ✅
        +
ERA5:2014-09-10_00 ✅
        +
x1.10242.graph.info.part.4 ✅
        ↓
init_atmosphere_model 8.4.1 / 4 ranks ✅
        ↓
x1.10242.init.nc ✅
        ↓
atmosphere_model 8.4.1 / 4 ranks ✅
        ↓
primeira hora ✅
        ↓
history / diagnostics ✅
        ↓
validação científica ampla ⏳
```

Isto prova o pipeline funcional `ERA5 → WPS → MPAS init → MPAS atmosphere`,
inclusive I/O PIO/PnetCDF, a partição real em quatro ranks, a inicialização da
física, o avanço temporal e a escrita dos outputs. Não prova conservação
quantitativa, skill, equilíbrio do spin-up ou qualidade meteorológica.

## Próximos trabalhos ainda pendentes

- investigar o `q2` diagnóstico negativo sem modificar a baseline aprovada;
- definir métricas de conservação, equilíbrio/spin-up e qualidade
  meteorológica;
- avaliar surface update antes de previsões mais longas;
- decidir duração e produtos de um experimento científico posterior;
- manter esta hora como smoke funcional, não como validação final.

## Validação científica e visual da primeira hora

O ciclo 0014 analisou exatamente o `run-001` produzido pelo ciclo 0013, sem
nova chamada a `atmosphere_model`. Os history/diagnostics de 00 e 01 UTC
foram abertos explicitamente e read-only no container de análise.

O resultado é `scientific_sanity=PASS`: não há corrupção, NaN/Inf, pressão ou
densidade negativa, espessura inválida ou explosão global. `rho`, `theta`
e `u` mudaram; a temperatura derivada permaneceu entre 182,177 e 313,264 K
em t1; MSLP entre 926,616 e 1041,698 hPa.

Os 11 valores `q2 < 0` estão todos em `xland=1` na Antártica. A surface
layer revisada usa `q2=qsfc+(qv1-qsfc)*(psiq2/psiq)` sem clamp. Como
`qsfc/psiq/psiq2` não foram escritos, a reconstrução exata por célula não é
possível; a evidência sustenta comportamento numérico limitado/documentado,
não alteração do source ou do output.

A precipitação de uma hora tem máximo 4,762212 mm, média 0,0184338 mm,
mediana zero e 41,4567% das células com valor positivo. Esses números não
medem skill de precipitação numa mesh de 240 km.

A SST permaneceu idêntica por configuração. `skintemp` evoluiu. Não foi
gerado `sfc_update.nc`: uma integração mais longa deverá decidir
explicitamente a atualização superficial, e esta hora não mede o erro de
manter SST fixa.

Reprodução:

```sh
docker build --file docker/analysis/Dockerfile \
  --tag mpas-era5:analysis-0014 .
./scripts/validate/scientific-run.sh
```

Resultados: [[../validation/first-atmosphere-run|documento científico]],
[`summary.json`](../assets/validation/0014/summary.json) e
[`figuras selecionadas`](../assets/validation/0014/). Forecast skill continua
`NOT_EVALUATED`; spin-up continua `INSUFFICIENT_TEMPORAL_WINDOW`.
