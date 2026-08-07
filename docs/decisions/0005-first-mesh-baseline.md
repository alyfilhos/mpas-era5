# ADR 0005 — x1.10242 e part.4 como baseline do primeiro caso

- Estado: aceito
- Data: 2026-08-06
- Responsáveis: usuário e agente Codex
- Requisitos relacionados: REQ-MESH-001
- Fontes relacionadas: entradas MPAS mesh em
  [[../references/source-registry|source-registry.md]]

## Contexto

O projeto precisava substituir o fixture sintético do ciclo 0004 por uma
mesh MPAS pública real, ainda barata o suficiente para ensinar e validar o
pipeline em recursos modestos. A página oficial do MPAS-Atmosphere oferece
meshes SCVT quasi-uniformes em várias resoluções e fornece, em cada pacote, a
mesh, `graph.info` e algumas partições pré-computadas.

A primeira escolha de mesh, domínio e estratégia do caso é protegida por gate
de decisão. O usuário aprovou explicitamente x1.10242, domínio global,
resolução aproximada de 240 km, 10.242 células e uma partição baseline em
quatro partes.

## Opções consideradas

### A. x1.2562 / ~480 km

Menor custo, porém geometria muito mais grosseira e menos representativa dos
tutoriais usados como referência do pipeline.

### B. x1.4002 / ~384 km

Também econômica, mas com menos recorrência que x1.10242 nos materiais
didáticos do MPAS.

### C. x1.10242 / ~240 km

Mesh oficial global quasi-uniforme com 10.242 células. Mantém custo baixo,
aparece recorrentemente em tutoriais e já é grande o suficiente para exercitar
NetCDF, conectividade e particionamento reais.

### D. x1.40962 / ~120 km

Oferece maior resolução, mas eleva custo de armazenamento, pré-processamento e
execução sem benefício necessário para aprender o primeiro pipeline.

### E. Mesh de resolução variável

É importante para aplicações futuras, mas adiciona decisões sobre região de
refinamento, rotação e transições de resolução antes de validar o fluxo básico.

## Decisão

Adotar como primeira mesh:

- `x1.10242`;
- global;
- SCVT quasi-uniforme;
- resolução aproximada de 240 km;
- 10.242 células horizontais.

Adotar `x1.10242.graph.info.part.4` como decomposição baseline inicial, gerada
localmente com:

```sh
gpmetis -minconn -contig -niter=200 x1.10242.graph.info 4
```

Quatro partições correspondem a quatro tasks MPI quando o arquivo for
consumido pelo MPAS. Essa escolha é uma baseline didática e funcional, não uma
afirmação de configuração ótima de performance.

## Justificativa

- baixa resolução e custo computacional reduzido;
- disponibilização direta pela fonte oficial do MPAS-Atmosphere;
- uso recorrente em tutoriais MPAS;
- suficiente para aprender o pipeline completo;
- mais representativa que um fixture sintético;
- permite aumentar a resolução mais tarde sem mudar a arquitetura do workflow.

## Política de dados e static file

A mesh e suas partições são dados científicos de entrada. Permanecem sob
`data/meshes/x1.10242/`, fora do Git e fora da imagem Docker, e são obtidas ou
produzidas por scripts versionados.

Embora a página oficial ofereça um static file pronto de 240 km, ele não é
baixado. O projeto produzirá seu próprio `static.nc` a partir da mesh com
`init_atmosphere_model` e datasets geográficos em um ciclo posterior, para
preservar o valor educacional e a rastreabilidade do pré-processamento.

## Consequências

- o tarball first-party e seu SHA-256 local ficam pinados no workflow;
- apenas `x1.10242.grid.nc` e `x1.10242.graph.info` são adquiridos como
  artefatos canônicos;
- partições fornecidas no archive não substituem a prova local do METIS;
- a validação estrutural da mesh não equivale à aceitação pelo
  `init_atmosphere_model`;
- trocar mesh, domínio ou baseline de particionamento exige novo gate de
  decisão e atualização deste ADR ou um ADR substituto.

## Evidências

- aquisição: [`fetch-mesh.sh`](../../scripts/data/fetch-mesh.sh);
- particionamento: [`partition-mesh.sh`](../../scripts/prepare/partition-mesh.sh);
- smoke offline: [`mesh.sh`](../../scripts/validate/mesh.sh);
- resultados: [[../testing/validation-matrix|validation-matrix.md]];
- caso evolutivo: [[../cases/first-global-240km|first-global-240km.md]].
