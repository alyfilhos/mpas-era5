# Documentação — MPAS ERA5

Este diretório centraliza a documentação técnica e científica do projeto.

## Navegação

- [[architecture/project-graph|Grafo do projeto]]
- [[build/scientific-stack|Stack científica]]

### Projeto e governança

- [[project/requirements|Requisitos do projeto]]
- [[project/current-state|Estado atual]]
- [[project/development-workflow|Workflow de desenvolvimento]]
- [[project/future-experiments|Experimentos técnicos futuros]]

### Rastreabilidade

- [[references/source-registry|Registro de fontes]]
- [[references/versions.lock|Versões adotadas e pendentes]]
- [[decisions/README|Registros de Decisão Arquitetural (ADRs)]]
- [[decisions/0001-pnetcdf-mpiio-backend|ADR 0001 — PnetCDF com MPI-IO]]
- [[decisions/0002-pio2-pnetcdf-with-serial-netcdf|ADR 0002 — PIO2 com PnetCDF e netCDF serial]]
- [[decisions/0003-metis-5.1.0-partitioning-baseline|ADR 0003 — METIS 5.1.0 como baseline de particionamento]]
- [[decisions/0004-wps-mpas-version-and-layout|ADR 0004 — versões e layout de WPS/MPAS]]
- [[decisions/0005-first-mesh-baseline|ADR 0005 — primeira mesh e part.4]]
- [[decisions/0006-first-static-baseline|ADR 0006 — primeira baseline static]]
- [[decisions/0007-first-era5-baseline|ADR 0007 — primeira baseline ERA5]]
- [[testing/validation-matrix|Matriz de validação]]
- [[cases/first-global-240km|Primeiro caso global de ~240 km]]

### Aprendizado

- [[../learning/README|Índice de aprendizado]]
- [[../learning/baseline|Baseline didático da stack]]
- [[../learning/commits/0001-bootstrap-codex-workflow|Ciclo 0001 — bootstrap do workflow Codex]]
- [[../learning/commits/0002-add-pnetcdf|Ciclo 0002 — adicionar PnetCDF]]
- [[../learning/commits/0003-add-pio2|Ciclo 0003 — adicionar PIO2]]
- [[../learning/commits/0004-add-metis|Ciclo 0004 — adicionar METIS]]
- [[../learning/commits/0005-add-wps-ungrib|Ciclo 0005 — adicionar WPS/ungrib]]
- [[../learning/commits/0006-add-mpas-init-atmosphere|Ciclo 0006 — adicionar MPAS init_atmosphere]]
- [[../learning/commits/0007-add-mpas-atmosphere|Ciclo 0007 — adicionar MPAS atmosphere]]
- [[../learning/commits/0008-add-first-mesh|Ciclo 0008 — adicionar a primeira mesh real]]
- [[../learning/commits/0009-generate-static-fields|Ciclo 0009 — gerar campos estáticos]]
- [[../learning/commits/0010-add-era5-acquisition|Ciclo 0010 — adquirir ERA5 reproduzivelmente]]

## Blocos do projeto

1. Ambiente e containerização
2. Compilação da stack científica
3. Compilação do MPAS e WPS
4. Aquisição e preparação do ERA5
5. Preparação da malha
6. Primeira execução
7. Validação e visualização

## Regra de localização

O [[architecture/project-graph|grafo do projeto]] é a referência para localizar
diretórios, documentos e relações entre as partes do repositório.
