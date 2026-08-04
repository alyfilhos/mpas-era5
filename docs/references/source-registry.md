# Registro de fontes

## Finalidade

Este registro documenta de onde vêm requisitos, fatos técnicos, versões e
orientações de troubleshooting. Uma fonte deve ser classificada antes de ser
usada; autoridade e utilidade não são a mesma coisa.

Última revisão deste registro: **2026-08-04**.

## Classes de fonte

| Classe | Uso permitido | Limite |
|---|---|---|
| Requisito original | definir objetivo, restrições e entregáveis do projeto | não prova compatibilidade técnica nem informa necessariamente uma versão |
| Documentação oficial | definir interfaces, opções de build, requisitos e procedimentos mantidos pelo projeto upstream | conferir se a página corresponde à versão adotada |
| Release oficial | fixar artefato, versão, checksum e notas de release | não substitui a documentação de uso e compatibilidade |
| Fonte secundária | fornecer contexto, comparação ou explicação | não é autoridade primária para arquitetura ou versões |
| Fórum/issue para troubleshooting | investigar sintomas e hipóteses de falha | não deve decidir arquitetura ou versão; a solução precisa ser validada localmente e, se possível, confirmada em fonte oficial |

## Fontes registradas

### Requisitos originais

| ID | Fonte | Escopo | Verificação |
|---|---|---|---|
| REQ-001 | briefing técnico do responsável pelo projeto, transcrito em [[../project/requirements|requirements.md]] | plano completo GNU/MPI → stack → MPAS/WPS → ERA5 → primeiro caso → validação/documentação | conferido durante o ciclo 0001 em 2026-08-04; não possui URL pública |
| REQ-002 | [`README.md`](../../README.md) no histórico Git | objetivo educacional, primeiro caso global de baixa resolução e roadmap inicial | arquivo e histórico completo conferidos em 2026-08-04 |
| REQ-003 | [`AGENTS.md`](../../AGENTS.md) | governança, gates de decisão, testes, documentação, commit e segurança | arquivo local conferido integralmente em 2026-08-04 |

### Documentação oficial

| ID | Projeto/versão | Fonte oficial | Finalidade e resultado | Verificação |
|---|---|---|---|---|
| DOC-PNETCDF-001 | PnetCDF | [repositório oficial](https://github.com/Parallel-NetCDF/PnetCDF) | identidade do projeto, release atual, formatos e interfaces | consultado em 2026-08-04 |
| DOC-PNETCDF-002 | PnetCDF | [página oficial](https://parallel-netcdf.github.io/) | relação entre PnetCDF, CDF e MPI-IO | consultada em 2026-08-04 |
| DOC-PNETCDF-003 | PnetCDF 1.15.0 | `INSTALL` dentro do tarball oficial `pnetcdf-1.15.0.tar.gz` | requisitos MPI/m4, wrappers, defaults Fortran, `make check`, `make ptest`, `make ptests` e `TESTMPIRUN` | 381 linhas lidas integralmente em 2026-08-04; corresponde ao artefato, não à branch master |
| DOC-PNETCDF-004 | PnetCDF 1.15.0 | `./configure --help` gerado pelo tarball oficial | flags disponíveis e recursos opcionais; confirmou `--disable-gio`, shared/static e ausência de flags redundantes | executado em 2026-08-04 |
| DOC-OPENMPI-001 | OpenMPI | [Modular Component Architecture](https://docs.open-mpi.org/en/main/mca.html) | mecanismo `--mca framework component` para selecionar componentes em runtime | consultado em 2026-08-04; disponibilidade local confirmada por `ompi_info` 4.1.6 |

### Releases e artefatos usados pela implementação atual

As URLs abaixo são reproduzidas literalmente do [`Dockerfile`](../../Dockerfile),
portanto não são URLs inferidas. Elas foram verificadas **no repositório**, mas
não revalidadas pela rede neste ciclo de governança.

| ID | Componente | Release/artefato registrado | Integridade no build | Estado da verificação |
|---|---|---|---|---|
| REL-UBUNTU-001 | Ubuntu | imagem `ubuntu:24.04` | tag sem digest fixado | referência confirmada no `Dockerfile`; origem/digest devem ser verificados antes de uma mudança de base |
| REL-ZLIB-001 | zlib 1.3.2 | `https://zlib.net/fossils/zlib-1.3.2.tar.gz` | SHA-256 `bb329a0a2cd0274d05519d61c667c062e06990d72e125ee2dfa8de64f0119d16` | URL e hash confirmados no `Dockerfile`; autoridade externa não revalidada neste ciclo |
| REL-HDF5-001 | HDF5 1.14.6 | `https://github.com/HDFGroup/hdf5/releases/download/hdf5_1.14.6/hdf5-1.14.6.tar.gz` | nenhum SHA-256 registrado | URL confirmada no `Dockerfile`; checksum e release oficial precisam de verificação futura |
| REL-NETCDF-C-001 | netCDF-C 4.10.1 | `https://downloads.unidata.ucar.edu/netcdf-c/4.10.1/netcdf-c-4.10.1.tar.gz` | SHA-256 `db3b69ff4a5ee1a7d79a5c36664d2128b752c266e966369fcf7311ec5f927564` | URL e hash confirmados no `Dockerfile`; autoridade externa não revalidada neste ciclo |
| REL-NETCDF-F-001 | netCDF-Fortran 4.6.3 | `https://downloads.unidata.ucar.edu/netcdf-fortran/4.6.3/netcdf-fortran-4.6.3.tar.gz` | SHA-256 `f642050e90025e7bb25848cc8f818545e1d3bdeb73fe6d103a6f8dc000a1a3d6` | URL e hash confirmados no `Dockerfile`; autoridade externa não revalidada neste ciclo |
| REL-PNETCDF-001 | PnetCDF 1.15.0 | [tarball oficial `pnetcdf-1.15.0.tar.gz`](https://parallel-netcdf.github.io/Release/pnetcdf-1.15.0.tar.gz) | SHA-256 `39813fe91ec901c7cfca3212731edbb5201029ebf55caeaaaa08d9e33c6bad65` | baixado duas vezes e calculado localmente com o mesmo resultado em 2026-08-04; o upstream não publica SHA-256 |

### Release PnetCDF 1.15.0

| ID | Fonte oficial | Informação verificada | Verificação |
|---|---|---|---|
| REL-PNETCDF-NOTES-001 | [release notes 1.15.0](https://github.com/Parallel-NetCDF/Parallel-NetCDF.github.io/blob/master/Release_notes/1.15.0.md) | release de 1º de julho de 2026; introdução de GIO e mudança do backend padrão | consultada em 2026-08-04; sustenta [[../decisions/0001-pnetcdf-mpiio-backend|ADR 0001]] |
| REL-PNETCDF-DOWNLOAD-001 | [Download oficial](https://parallel-netcdf.github.io/wiki/Download.html) | lista 1.15.0 e publica SHA-1 `fec63e5d1cdb4de4f3fd85f11be45294d4a8ed66` | consultada em 2026-08-04; o SHA-1 local coincidiu |

Foi investigada a possível defasagem da página Download: na consulta ao vivo
de 2026-08-04 ela **já listava 1.15.0**. Portanto não existe divergência atual
entre a página, o repositório e as release notes quanto à release estável. A
limitação real é de integridade: a página publica SHA-1, mas não SHA-256. O
SHA-256 usado no `Dockerfile` não é atribuído ao upstream; ele foi calculado
localmente duas vezes a partir do artefato oficial.

Há uma inconsistência dentro do próprio artefato: o `INSTALL` informa shared
desabilitado e static habilitado por padrão, enquanto o `configure --help`
gerado pela release 1.15.0 exibiu shared e static habilitados por padrão. A
decisão já aprovada usa `--enable-shared --enable-static` explicitamente, o que
torna o build determinístico sem escolher um dos defaults conflitantes.

Registrar uma URL aqui não autoriza download novo, mudança de versão ou
alteração da stack. Para isso, a fonte deve ser consultada conforme o workflow,
a compatibilidade deve ser avaliada e o usuário deve aprovar a proposta.

### Fontes secundárias

Nenhuma fonte secundária está registrada até o ciclo 0001.

### Fóruns e issues para troubleshooting

| ID | Fonte | Sintoma/hipótese aproveitada | Validação local |
|---|---|---|---|
| TROUBLE-OPENMPI-001 | [issue oficial OpenMPI #10297](https://github.com/open-mpi/ompi/issues/10297) | falha aberta no caminho `mca_io_ompio_file_write_at_all()` durante escrita paralela PnetCDF, marcada para OpenMPI 4.1.x | OMPIO 4.1.6 produziu valores ausentes/incompletos; `ompi_info` mostrou ROMIO 4.1.6 disponível e `--mca io romio321` fez `make ptest` e a integração passarem |

A issue foi usada somente para troubleshooting. A arquitetura MPI-IO/GIO e a
versão PnetCDF já haviam sido decididas por fontes primárias e pelo usuário.
ROMIO é um componente do OpenMPI instalado, não uma troca de implementação MPI.

## Campos obrigatórios para novas entradas

Toda nova fonte deve registrar:

1. identificador estável;
2. classe de fonte;
3. componente e versão aplicável;
4. título ou descrição;
5. URL exata, quando houver;
6. finalidade da consulta;
7. data de verificação;
8. resultado da verificação;
9. decisão, ADR ou teste que a utiliza.

URLs não abertas ou não presentes em uma fonte já rastreada devem permanecer
fora do registro até verificação. Em caso de conflito entre fontes oficiais, o
ciclo deve parar e apresentar o conflito ao usuário.
