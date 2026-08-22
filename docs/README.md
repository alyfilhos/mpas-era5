# Documentação — MPAS-ERA5

Índice técnico e ponto de entrada compatível com Markdown/Obsidian. O
[[architecture/project-graph|grafo do projeto]] é a referência principal para
navegar entre código, dados locais, decisões e evidências.

## Projeto concluído

- [[project/completion-report|Relatório técnico de conclusão]]
- [[reproducibility/end-to-end|Guia de reprodução end-to-end]]
- [[project/requirements#Rastreabilidade final do escopo original|Auditoria dos requisitos]]
- [[portfolio/project-showcase|Material para GitHub, CV e LinkedIn]]

`PROJECT_BASE_STATUS = COMPLETE`, com
`forecast_skill=NOT_EVALUATED` e
`spinup=INSUFFICIENT_TEMPORAL_WINDOW`.

## Navegação técnica

### Arquitetura e operação

- [[architecture/project-graph|Grafo, pipeline e estrutura]]
- [[build/scientific-stack|Stack científica]]
- [[cases/first-global-240km|Primeiro caso global x1.10242]]
- [[validation/first-atmosphere-run|Validação científica da primeira hora]]
- [[testing/validation-matrix|Matriz de validação]]

### Projeto e governança

- [[project/requirements|Requisitos e rastreabilidade]]
- [[project/current-state|Estado atual e referência Git]]
- [[project/development-workflow|Workflow de desenvolvimento]]
- [[project/future-experiments|Extensões futuras]]

### Proveniência e decisões

- [[references/source-registry|Registro de fontes]]
- [[references/versions.lock|Versões congeladas]]
- [[decisions/README|Índice de ADRs]]
- [[decisions/0001-pnetcdf-mpiio-backend|ADR 0001 — PnetCDF/MPI-IO]]
- [[decisions/0002-pio2-pnetcdf-with-serial-netcdf|ADR 0002 — PIO/PnetCDF + netCDF serial]]
- [[decisions/0003-metis-5.1.0-partitioning-baseline|ADR 0003 — METIS 5.1.0]]
- [[decisions/0004-wps-mpas-version-and-layout|ADR 0004 — WPS/MPAS]]
- [[decisions/0005-first-mesh-baseline|ADR 0005 — mesh x1.10242]]
- [[decisions/0006-first-static-baseline|ADR 0006 — geografia/static]]
- [[decisions/0007-first-era5-baseline|ADR 0007 — ERA5]]
- [[decisions/0008-first-initial-condition-baseline|ADR 0008 — init]]
- [[decisions/0009-separate-analysis-container|ADR 0009 — análise separada]]

## Evidência publicada

Os artefatos científicos grandes ficam em `data/` e não entram no Git. A
evidência pequena selecionada do ciclo 0014 está em
[`assets/validation/0014/`](assets/validation/0014/):

- [`summary.json`](assets/validation/0014/summary.json);
- [`q2-negative-cells.csv`](assets/validation/0014/q2-negative-cells.csv);
- mapas e perfil vertical em PNG.

Para validar o estado local já materializado:

```sh
./scripts/validate/final-project.sh
```

## Aprendizado

- [[../learning/README|Índice de aprendizado]]
- [[../learning/baseline|Baseline didática da stack]]
- [[../learning/commits/0001-bootstrap-codex-workflow|Ciclo 0001 — governança]]
- [[../learning/commits/0002-add-pnetcdf|Ciclo 0002 — PnetCDF]]
- [[../learning/commits/0003-add-pio2|Ciclo 0003 — PIO2]]
- [[../learning/commits/0004-add-metis|Ciclo 0004 — METIS]]
- [[../learning/commits/0005-add-wps-ungrib|Ciclo 0005 — WPS/ungrib]]
- [[../learning/commits/0006-add-mpas-init-atmosphere|Ciclo 0006 — MPAS init]]
- [[../learning/commits/0007-add-mpas-atmosphere|Ciclo 0007 — MPAS atmosphere]]
- [[../learning/commits/0008-add-first-mesh|Ciclo 0008 — mesh]]
- [[../learning/commits/0009-generate-static-fields|Ciclo 0009 — static]]
- [[../learning/commits/0010-add-era5-acquisition|Ciclo 0010 — ERA5]]
- [[../learning/commits/0011-ungrib-era5|Ciclo 0011 — intermediate]]
- [[../learning/commits/0012-generate-initial-conditions|Ciclo 0012 — init]]
- [[../learning/commits/0013-first-atmosphere-run|Ciclo 0013 — primeira hora]]
- [[../learning/commits/0014-validate-first-forecast|Ciclo 0014 — sanity científico]]
- [[../learning/commits/0015-finalize-project|Ciclo 0015 — conclusão e apresentação]]

## Onde procurar

| Pergunta | Documento |
|---|---|
| Como reproduzir? | [[reproducibility/end-to-end|guia end-to-end]] |
| O projeto terminou? | [[project/completion-report|relatório final]] |
| Qual requisito prova isso? | [[project/requirements|rastreabilidade]] |
| Qual versão/origem foi usada? | [[references/versions.lock|versões]] / [[references/source-registry|fontes]] |
| Por que essa arquitetura? | [[decisions/README|ADRs]] |
| O teste realmente passou? | [[testing/validation-matrix|matriz]] |
| Onde fica um arquivo/pasta? | [[architecture/project-graph|grafo]] |
| O que ainda pode ser pesquisado? | [[project/future-experiments|extensões]] |
| Como apresentar o projeto? | [[portfolio/project-showcase|showcase]] |
