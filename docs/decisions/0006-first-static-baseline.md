# ADR 0006 — Baseline geográfica e static do primeiro caso

- Estado: aceito
- Data: 2026-08-14
- Responsáveis: usuário e agente Codex
- Requisitos relacionados: REQ-CASE-001
- Fontes relacionadas: entradas MPAS/WPS em
  [[../references/source-registry|source-registry.md]]

## Contexto

O primeiro caso precisava gerar seu próprio `x1.10242.static.nc` com
`init_atmosphere_model` 8.4.1 e dados geográficos oficiais. A baseline
aprovada seleciona GMTED2010, MODIS, STATSGO, native GWD, uma task MPI e exclui
Noah-MP.

A inspeção do pacote educacional `geog_low_res_mandatory.tar.gz` mostrou que
ele não contém os datasets de 30 arc-seconds exigidos. O pacote
`geog_high_res_mandatory.tar.gz` contém seis datasets corretos, mas sua
versão atual oferece land use MODIS apenas na variante `with_lakes` e não
contém o `landuse_30s/` acessado literalmente pelo source GWD 8.4.1.

## Opções consideradas

### A. Usar somente o pacote low-resolution

Rejeitada porque o conteúdo real não satisfaz as seleções aprovadas.

### B. Renomear ou criar aliases para datasets parecidos do pacote high

Rejeitada porque esconderia uma diferença semântica entre datasets e quebraria
a rastreabilidade científica.

### C. Usar todo o pacote completo WPS

Tecnicamente possível, porém baixa dezenas de gigabytes não necessários a
esta configuração e amplia custo sem melhorar a baseline x1.10242.

### D. Extrair os datasets exatos de artefatos first-party WPS

Selecionada: seis diretórios vêm do pacote high mandatory e os dois diretórios
legados exatos vêm dos suplementos WPSv3 ligados pela mesma página oficial.

## Decisão

Adotar, fora da imagem e do Git:

- `geog_high_res_mandatory.tar.gz` para `albedo_modis/`,
  `greenfrac_fpar_modis/`, `maxsnowalb_modis/`, `soiltemp_1deg/`,
  `soiltype_top_30s/` e `topo_gmted2010_30s/`;
- `modis_landuse_20class_30s.tar.bz2` para o land use selecionado;
- `landuse_30s.tar.bz2` para native GWD;
- hashes SHA-256 locais fixos, com origem explicitamente local;
- instalação seletiva em `data/geog/mpas-8.4.1/`.

Configurar o static do primeiro caso com:

- `config_init_case=7`;
- static interpolation e native GWD ligados;
- GWD GSL e etapas meteorológicas desligados;
- supersampling 1 para a mesh de ~240 km;
- exatamente uma task MPI;
- `config_noahmp_static=false`.

## Consequências

- a aquisição é maior que o pacote low-resolution, mas contém os datasets
  exatos exigidos pelo source;
- não há aliases, sobreposição silenciosa ou download de terceiros;
- dados geográficos, archives, logs e NetCDF permanecem locais e ignorados;
- o static pode ser reutilizado com a mesma mesh/configuração geográfica
  porque independe da data meteorológica;
- este static não contém os cinco campos Noah-MP e não pode ser promovido como
  input universal;
- um experimento futuro com Noah-MP deve gerar outro static sob outro caso,
  sem sobrescrever a baseline educacional;
- uma task é a baseline conservadora, não uma afirmação de ausência de
  paralelismo em static interpolation.

## Evidências

- aquisição: [`fetch-geog.sh`](../../scripts/data/fetch-geog.sh);
- configuração: [`static/`](../../cases/first-global-240km/static/);
- execução: [`generate-static.sh`](../../scripts/run/generate-static.sh);
- validação: [`static.sh`](../../scripts/validate/static.sh);
- resultados: [[../testing/validation-matrix|validation-matrix.md]];
- caso: [[../cases/first-global-240km|first-global-240km.md]];
- aprendizado:
  [[../../learning/commits/0009-generate-static-fields|ciclo 0009]].
