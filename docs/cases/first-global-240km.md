# Primeiro caso global — x1.10242 / ~240 km

## Status

**Mesh, dados geográficos e campos estáticos preparados e validados.**

O ciclo 0009 executou pela primeira vez o `init_atmosphere_model` 8.4.1
sobre a mesh real x1.10242 e produziu
`data/cases/first-global-240km/static/x1.10242.static.nc`. ERA5, `init.nc`
e a previsão continuam fora deste estágio.

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
ERA5 / init.nc ⏳
```

Isto prova pela primeira vez que o init consumiu a mesh real escolhida e
interpolou campos estáticos. Não prova ERA5 → WPS intermediate → `init.nc`,
não prova compatibilidade com Noah-MP, não executa `atmosphere_model` e não
constitui validação meteorológica de uma previsão.

## Próximas decisões ainda pendentes

- data, hora, período, área, variáveis e níveis ERA5;
- Vtable e mapeamento ERA5 → WPS intermediate;
- geração e validação de `init.nc`;
- duração, timestep e configuração de physics;
- execução do `atmosphere_model` com partição compatível;
- validação científica quantitativa.
