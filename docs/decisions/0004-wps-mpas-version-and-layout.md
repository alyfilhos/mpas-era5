# ADR 0004 — versões e layout de WPS/MPAS

- Estado: aceito
- Data: 2026-08-05
- Responsáveis: usuário e agente Codex
- Requisitos relacionados: REQ-PRE-001, REQ-MPAS-001 e REQ-MPAS-002
- Fontes relacionadas: registros WPS e MPAS em
  [[../references/source-registry|source-registry.md]]

## Contexto

O próximo passo após a stack científica e METIS é decodificar GRIB para o
formato intermediário do WPS que o futuro `init_atmosphere` consumirá. O ciclo
não precisa instalar WRF, construir os demais programas WPS, baixar ERA5 ou
compilar MPAS.

WPS e MPAS-Model são aplicações com árvores próprias de source/build. Colocá-
las dentro de `/opt/mpas`, já usado como prefixo das bibliotecas científicas,
misturaria responsabilidades, arquivos de aplicação e ABIs compartilhadas.

A proposta inicial considerava WPS 4.6.0. Antes da implementação, a verificação
obrigatória cruzou release oficial, source da tag e histórico e encontrou a
release estável posterior 4.7.0. O ciclo parou no gate; o usuário então aprovou
explicitamente WPS 4.7.0. Para MPAS, 8.4.0 também chegou a ser considerado,
mas a mesma verificação direta confirmou a release/hotfix 8.4.1.

## Opções consideradas

### A. WPS 4.6.0

Era a escolha inicial. Foi descartada para este ciclo depois de comprovada a
existência da release estável posterior 4.7.0; não houve atualização silenciosa.

### B. WPS 4.7.0 completo

Construiria `geogrid`, `ungrib` e `metgrid`, exigindo WRF compilado para os
componentes dependentes. Isso ampliaria o escopo e instalaria WRF sem
necessidade aprovada.

### C. WPS 4.7.0 somente ungrib

Usa `--nowrf`, constrói as dependências GRIB2 internas e executa somente
`./compile ungrib`. É o menor recorte que prepara o caminho ERA5/MPAS sem
antecipar decisões de dados e modelo.

### D. Instalar aplicações sob `/opt/mpas`

Simplificaria visualmente o número de prefixos, mas confundiria bibliotecas
científicas com sources e executáveis de WPS/MPAS e poderia misturar as
bibliotecas GRIB2 privadas do WPS com zlib da stack.

### E. Prefixos versionados separados com links estáveis

Preserva identidade, permite futuras trocas explícitas por link e mantém as
dependências privadas no domínio da aplicação que as construiu.

## Decisão

Adotar:

- WPS 4.7.0, tag `v4.7.0`, commit
  `5feccecd63384381b6942371c7a837f66e4ccb84`;
- MPAS-Model 8.4.1, tag `v8.4.1`, hotfix/commit
  `91c5eac175eebeaf4206bacd5cb50c39dff3c152`;
- `/opt/mpas` reservado às bibliotecas científicas;
- WPS em `/opt/wps-4.7.0` e link `/opt/wps`;
- futuro MPAS em `/opt/mpas-model-8.4.1` e link `/opt/mpas-model`;
- configuração WPS `--nowrf --build-grib2-libs`;
- plataforma GNU/GCC/GFortran, Linux x86_64, serial;
- seleção não interativa derivada de `arch/configure.defaults`, sem número de
  menu presumido;
- somente `./compile ungrib` neste ciclo.

MPAS 8.4.1 não será adicionado ao `Dockerfile` agora. WRF não será instalado.
ERA5 não será baixado e nenhuma Vtable será escolhida como definitiva.

## Consequências

- `ungrib.exe` permanece no layout upstream do WPS e não é copiado para
  `/opt/mpas/bin`;
- zlib 1.2.11, libpng 1.6.37 e JasPer 1.900.29 internos permanecem sob
  `/opt/wps-4.7.0/grib2`, separados da stack;
- `csh` é o único pacote de sistema novo, pois `compile` usa `#!/bin/csh -f`;
- `configure.wps` vira evidência auditável de compiladores, modo serial,
  ausência de WRF/MPI e GRIB2 interno;
- `geogrid.exe` e `metgrid.exe` permanecem ausentes;
- a Vtable correta só poderá ser decidida junto das variáveis, níveis e
  codificação da amostra ERA5 aprovada;
- a validação funcional `ERA5 GRIB → ungrib → WPS intermediate` permanece um
  gate futuro;
- mudanças futuras de WPS/MPAS ou dos prefixos exigem nova decisão conforme o
  workflow.

## Evidências de validação

- build, smoke, linkagem, Vtables e regressões:
  [[../testing/validation-matrix|validation-matrix.md]];
- configuração e layout:
  [`Dockerfile`](../../Dockerfile) e
  [`scripts/validate/wps-ungrib.sh`](../../scripts/validate/wps-ungrib.sh);
- explicação didática:
  [[../../learning/commits/0005-add-wps-ungrib|learning note do ciclo 0005]].
