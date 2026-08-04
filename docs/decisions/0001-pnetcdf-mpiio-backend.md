# ADR 0001 — PnetCDF 1.15.0 com backend MPI-IO

- Estado: aceito
- Data: 2026-08-04
- Responsável pela decisão: usuário responsável pelo projeto
- Requisitos relacionados: REQ-ENV-001, REQ-STACK-005, REQ-DOC-001
- Fontes relacionadas: DOC-PNETCDF-001 a 004,
  REL-PNETCDF-001, REL-PNETCDF-NOTES-001

## Contexto

O projeto precisa adicionar I/O paralelo compatível com o futuro build do
MPAS, preservando OpenMPI e a stack científica já validada. A release PnetCDF
1.15.0, publicada em 1º de julho de 2026, introduziu GIO e passou a usá-lo como
backend padrão.

GIO agrega e redistribui operações de I/O e inclui otimizações voltadas a
sistemas paralelos como Lustre. Essas capacidades podem ser úteis em estudos
de performance, mas acrescentam uma camada conceitual antes de o projeto ter
um caso MPAS ou uma necessidade de otimização medida.

MPI-IO é a interface de I/O paralelo do MPI. Usá-la diretamente por meio do
backend tradicional do PnetCDF torna explícita a cadeia que este projeto quer
ensinar:

```text
aplicação → PnetCDF → MPI-IO → OpenMPI → sistema de arquivos
```

## Opções consideradas

### 1. PnetCDF 1.15.0 com GIO

Usaria a release atual e seu novo default. Anteciparia agregação/redistribuição
e otimizações para sistemas como Lustre, mas aumentaria a complexidade da
primeira stack e dificultaria isolar os conceitos fundamentais de MPI-IO.

### 2. PnetCDF 1.15.0 com MPI-IO

Usaria a release atual e `--disable-gio` para selecionar o backend tradicional.
Mantém a arquitetura inicial pequena, conecta diretamente PnetCDF aos
conceitos MPI-IO e preserva a possibilidade de comparar GIO depois.

### 3. PnetCDF 1.14.1

Evitaria a mudança de default introduzida em 1.15.0, mas adotaria uma release
anterior apenas para contornar uma decisão que pode ser expressa explicitamente
em 1.15.0.

## Decisão

Adotar PnetCDF 1.15.0 a partir do tarball de release oficial, com OpenMPI já
existente e a seguinte configuração:

```sh
--prefix=/opt/mpas
--disable-gio
--enable-shared
--enable-static
```

A interface Fortran permanece habilitada. O build usa `MPICC`, `MPICXX`,
`MPIF77` e `MPIF90` apontando para os wrappers OpenMPI. Não são habilitados a
integração NetCDF-4, ADIOS, subfiling, thread safety, profiling ou outros
recursos opcionais.

O ambiente exporta `PNETCDF=/opt/mpas`, preservando `NETCDF=/opt/mpas`.

## Motivação

- adotar a release oficial atual;
- começar com a arquitetura tradicional e mais simples;
- relacionar diretamente o componente aos conceitos HPC que o projeto quer
  ensinar;
- não introduzir GIO/Lustre antes de existir necessidade de performance;
- permitir um experimento futuro controlado comparando GIO e MPI-IO.

## Consequências

- GIO não faz parte desta primeira stack PnetCDF;
- MPI-IO passa a ser componente explícito da arquitetura;
- PnetCDF não precisa depender de netCDF-C/HDF5 neste desenho;
- HDF5, netCDF-C, netCDF-Fortran e OpenMPI não são reconstruídos nem
  reconfigurados;
- futuras adoção e comparação de GIO exigirão novo ciclo e novo ADR, ou um ADR
  que substitua este;
- PIO2 permanece fora do escopo e sem decisão neste ciclo.

Durante a validação, OMPIO — o componente MPI-IO selecionado por padrão pelo
OpenMPI 4.1.6 instalado — apresentou escrita coletiva incompleta. Os testes
PnetCDF selecionam `romio321` por `--mca io romio321`. ROMIO já é fornecido
pelo mesmo OpenMPI; a seleção é localizada nos comandos, não troca a
implementação MPI nem cria configuração global. Essa medida é uma consequência
operacional de validação, não uma mudança na decisão GIO versus MPI-IO.

## Evidências de validação

- `make check`: aprovado;
- `make ptest`: aprovado com 4 ranks e ROMIO;
- instalação: PnetCDF 1.15.0, Fortran, shared/static e GIO desabilitado
  confirmados por `pnetcdf_version` e `pnetcdf-config`;
- integração: programa F90 criou e releu CDF-5 com quatro partes, uma por rank;
- linkagem: `libpnetcdf.so.8` em `/opt/mpas/lib` e MPI do OpenMPI esperado.

Detalhes e limitações estão em
[[../testing/validation-matrix|validation-matrix.md]] e a explicação didática
em [[../../learning/commits/0002-add-pnetcdf|learning/commits/0002-add-pnetcdf.md]].

## Fontes oficiais

- [repositório oficial PnetCDF](https://github.com/Parallel-NetCDF/PnetCDF);
- [página oficial PnetCDF](https://parallel-netcdf.github.io/);
- [release notes 1.15.0](https://github.com/Parallel-NetCDF/Parallel-NetCDF.github.io/blob/master/Release_notes/1.15.0.md);
- `INSTALL` e `configure --help` pertencentes ao tarball oficial
  `pnetcdf-1.15.0.tar.gz`;
- [tarball oficial](https://parallel-netcdf.github.io/Release/pnetcdf-1.15.0.tar.gz).
