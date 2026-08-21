# ADR 0009 — Container separado para análise científica

- Estado: aceito
- Data: 2026-08-21
- Responsáveis: usuário e Codex
- Requisitos relacionados: REQ-VAL-001, REQ-REP-001, REQ-DOC-001
- Fontes relacionadas: Python Official Image, NumPy, xarray, netCDF4-python e Matplotlib

## Contexto

A imagem científica reúne compiladores, MPI, WPS e MPAS. A validação da
primeira previsão requer uma responsabilidade diferente: ler NetCDFs já
produzidos, calcular estatísticas e gerar figuras. Adicionar a stack Python de
visualização à imagem MPAS aumentaria seu acoplamento e invalidaria uma camada
científica já testada.

O ciclo também exige execução offline, root filesystem somente leitura,
inputs montados read-only e somente um diretório de artefatos gravável.

## Opções consideradas

1. Instalar NumPy/xarray/Matplotlib na imagem científica.
2. Usar um ambiente Python do host.
3. Criar uma imagem de análise pequena e independente, com base e dependências
   fixadas.

## Decisão

Foi aprovada a terceira opção. `docker/analysis/` parte de
`python:3.12.13-slim-bookworm` por digest e instala por lock com hashes NumPy
2.5.2, xarray 2026.7.0, netCDF4 1.7.4, Matplotlib 3.11.1 e suas dependências
transitivas.

O container contém o analisador, roda sem rede e com filesystem raiz somente
leitura. `run-001` e `init.nc` entram como bind mounts read-only; somente
`docs/assets/validation/0014/` é gravável. Jupyter e Cartopy não fazem parte
desta baseline.

## Consequências

- a imagem MPAS/WPS e suas versões permanecem inalteradas;
- análise e simulação podem evoluir e ser validadas independentemente;
- o lock Python é específico de CPython 3.12 em Linux x86-64;
- reconstruir a imagem pela primeira vez requer acesso aos wheels do PyPI;
- depois do build, a análise é completamente offline;
- projeções que exijam Cartopy permanecem trabalho futuro e precisam demonstrar
  necessidade técnica.

## Evidências de validação

- [`Dockerfile`](../../docker/analysis/Dockerfile) e
  [`requirements.lock`](../../docker/analysis/requirements.lock);
- [`scientific-run.sh`](../../scripts/validate/scientific-run.sh);
- [[../validation/first-atmosphere-run|plano e resultado científico]];
- [[../testing/validation-matrix|matriz de validação]];
- [[../../learning/commits/0014-validate-first-forecast|learning note do ciclo 0014]].
