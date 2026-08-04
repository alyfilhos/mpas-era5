# Grafo do Projeto

## Fluxo principal

```text
Dockerfile
    │
    ▼
Stack científica
    │
    ├── zlib
    │     ↓
    ├── HDF5
    │     ↓
    ├── netCDF-C
    │     ↓
    ├── netCDF-Fortran
    │     ↓
    ├── PnetCDF
    │     ↓
    ├── PIO2
    │     ↓
    └── METIS
          │
          ▼
       MPAS build

## Stack científica

Dockerfile
→ zlib
→ HDF5
→ netCDF-C
→ netCDF-Fortran
→ PnetCDF
→ PIO2
→ METIS
→ MPAS

## Estrutura do repositório

### Dockerfile

Responsável pela construção do ambiente e da stack científica.

### docs/

Documentação técnica, decisões, conceitos e registro do desenvolvimento.

### scripts/

Scripts de automação, download e processamento.

### data/

Dados de entrada do projeto, como ERA5 e arquivos auxiliares.

Arquivos grandes não devem ser versionados diretamente no Git.

### cases/

Configurações dos experimentos e execuções do MPAS.

## Documentos relacionados

- [[../README|Índice da documentação]]
- [[../build/scientific-stack|Stack científica]]
