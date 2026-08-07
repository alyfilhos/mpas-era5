# Primeiro caso global — x1.10242 / ~240 km

## Status

**Mesh preparada; restante pendente.**

Este documento crescerá junto com o primeiro experimento. O estado atual
registra somente decisões e evidências já materializadas; não antecipa
parâmetros meteorológicos ou físicos ainda não aprovados.

## Baseline aprovada

| Campo | Valor |
|---|---|
| Mesh | `x1.10242` |
| Tipo | global, SCVT quasi-uniforme |
| Resolução nominal | aproximadamente 240 km |
| Células horizontais | 10.242 |
| Particionamento baseline | 4 |
| Arquivo | `x1.10242.graph.info.part.4` |
| Relação operacional futura | quatro partições ↔ quatro tasks MPI |

Os artefatos locais ficam em `data/meshes/x1.10242/` e são ignorados pelo
Git. A mesh é adquirida por `scripts/data/fetch-mesh.sh`; a partição é gerada
por `scripts/prepare/partition-mesh.sh` com METIS 5.1.0 e validada por
`scripts/validate/mesh.sh`.

## Decisão sobre campos estáticos

O static file pronto oferecido pela página oficial não é usado. O próximo
ciclo obterá os datasets geográficos aprovados e executará o
`init_atmosphere_model` para produzir e compreender nosso próprio
`static.nc`.

## Pendente

- datasets geográficos e sua proveniência;
- geração e validação de `static.nc`;
- data e hora do caso;
- período, área e demais seleções ERA5;
- variáveis e níveis ERA5;
- Vtable e mapeamento ERA5 → WPS intermediate;
- geração e validação de `init.nc`;
- duração da simulação;
- timestep;
- configuração de physics;
- execução com quatro ranks MPI;
- validação científica e critérios quantitativos.

## Limite da evidência atual

A estrutura NetCDF, o grafo e a partição foram validados. Ainda não foi
executado `init_atmosphere_model`; portanto, não se afirma que o MPAS aceitou
a mesh nem que o primeiro caso está executável.
