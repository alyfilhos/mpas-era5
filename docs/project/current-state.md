# Estado atual do projeto

## Referência da inspeção

Estado levantado em **2026-08-04**, no início do ciclo 0001, a partir do
worktree, do histórico Git completo disponível e dos arquivos do repositório.

- branch: `main`;
- `HEAD`: `0f5fed1` (`build: add netCDF-Fortran support`);
- relação observada: `main` alinhada com `origin/main`;
- histórico disponível: quatro commits, cobrindo zlib/HDF5, netCDF-C,
  netCDF-Fortran e documentação inicial;
- estado inicial não limpo: `AGENTS.md` e `.codex/` já existiam como itens não
  rastreados antes das alterações deste ciclo.

O ciclo 0001 acrescenta a infraestrutura documental descrita neste arquivo,
mas ela permanece no worktree até aprovação explícita de commit.

## Ambiente definido no repositório

O [`Dockerfile`](../../Dockerfile) define:

- imagem base Ubuntu 24.04;
- toolchain GNU por `build-essential` e `gfortran`;
- OpenMPI por `openmpi-bin` e `libopenmpi-dev`;
- prefixo científico `/opt/mpas`;
- `PATH`, `LD_LIBRARY_PATH`, `CPPFLAGS` e `LDFLAGS` apontando para o prefixo;
- `NETCDF=/opt/mpas` para descoberta posterior pelo build do MPAS.

As versões exatas dos pacotes instalados por `apt-get` não estão fixadas. O
repositório fixa a release Ubuntu, mas não um digest da imagem base nem as
versões de GCC, GFortran, OpenMPI e demais pacotes do sistema.

## Stack científica implementada

| Componente | Versão | O que existe no repositório | Limite da evidência persistida |
|---|---:|---|---|
| zlib | 1.3.2 | download, SHA-256, `configure`, compilação e instalação no `Dockerfile` | não há execução de suite upstream, smoke test ou log de resultado versionado |
| HDF5 | 1.14.6 | build com GCC/GFortran, zlib, interfaces Fortran e bibliotecas shared/static | não há SHA-256, suite upstream, smoke test ou log de resultado versionado |
| netCDF-C | 4.10.1 | download com SHA-256, configuração com HDF5, `make check` e instalação | o build exige `make check`, mas seu resultado não foi preservado em relatório no repositório |
| netCDF-Fortran | 4.6.3 | download com SHA-256, configuração contra netCDF-C, `make check` e instalação | o build exige `make check`, mas seu resultado não foi preservado em relatório no repositório |

Essas quatro versões são as versões **adotadas pela implementação atual**. O
README anterior ao ciclo as marca como concluídas, e o histórico mostra sua
introdução. Ainda assim, configuração de um teste no `Dockerfile` não equivale
a um relatório persistido de execução. A matriz em
[[../testing/validation-matrix|validation-matrix.md]] mantém essa diferença
explícita.

## Componentes ainda não implementados

- PnetCDF;
- PIO2;
- METIS;
- WPS/ungrib;
- MPAS `init_atmosphere`;
- MPAS `atmosphere`;
- aquisição e preparação ERA5;
- seleção e preparação da primeira malha;
- geração de `static.nc`, `init.nc` e, quando aplicável, LBC;
- primeira execução MPAS;
- validação física do caso.

Nenhum desses itens deve ser interpretado como instalado, compilado, testado
ou decidido.

## Infraestrutura documental do ciclo 0001

O worktree passa a conter:

- requisitos, estado e workflow em `docs/project/`;
- registro de fontes e lock documental em `docs/references/`;
- política de ADR em `docs/decisions/`;
- matriz de validação em `docs/testing/`;
- baseline didático e notas por commit em `learning/`;
- diretórios reservados para validações e automações Codex em
  `scripts/validate/` e `scripts/codex/`.

Os dois diretórios de scripts estão vazios neste ciclo. Git não rastreia
diretórios vazios; eles só se tornarão parte de um commit quando receberem um
arquivo aprovado em um ciclo futuro.

## Lacunas comprovadas

- não existem relatórios históricos de teste em `docs/testing/` anteriores ao
  ciclo 0001;
- não existem logs de build versionados que permitam reproduzir os resultados
  numéricos das suites já configuradas;
- a inspeção de imagens e containers locais falhou por falta de permissão na
  API Docker (`/var/run/docker.sock`), portanto não foi usada como evidência;
- HDF5 não possui checksum registrado no `Dockerfile` atual;
- pacotes do sistema e digest da imagem Ubuntu não estão totalmente fixados;
- não existem ADRs de decisões científicas ou arquiteturais anteriores.

Essas lacunas são rastreabilidade/dívida técnica; não autorizam reconstruir a
stack nem escolher novas versões sem a decisão do usuário.
