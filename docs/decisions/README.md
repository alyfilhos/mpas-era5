# Registros de Decisão Arquitetural (ADRs)

## Por que registrar decisões

Um ADR preserva o contexto de uma decisão que afeta arquitetura,
compatibilidade, ciência, reprodutibilidade ou manutenção. O diff mostra o que
mudou; o ADR explica por que a opção foi escolhida, quais alternativas foram
consideradas e quais consequências foram aceitas.

Nenhuma decisão arquitetural anterior ao workflow foi reconstruída sem
evidência. Decisões novas são listadas abaixo.

## Índice

- [[0001-pnetcdf-mpiio-backend|ADR 0001 — PnetCDF 1.15.0 com backend MPI-IO]]
  — aceito em 2026-08-04.
- [[0002-pio2-pnetcdf-with-serial-netcdf|ADR 0002 — PIO 2.7.0 com PnetCDF e netCDF serial]]
  — aceito em 2026-08-04.
- [[0003-metis-5.1.0-partitioning-baseline|ADR 0003 — METIS 5.1.0 como baseline de particionamento]]
  — aceito em 2026-08-05.
- [[0004-wps-mpas-version-and-layout|ADR 0004 — versões e layout de WPS/MPAS]]
  — aceito em 2026-08-05.
- [[0005-first-mesh-baseline|ADR 0005 — primeira mesh e part.4]]
  — aceito em 2026-08-06.
- [[0006-first-static-baseline|ADR 0006 — baseline geográfica e static]]
  — aceito em 2026-08-14.
- [[0007-first-era5-baseline|ADR 0007 — baseline ERA5 do primeiro caso global]]
  — aceito em 2026-08-14.
- [[0008-first-initial-condition-baseline|ADR 0008 — primeira baseline de condição inicial MPAS]]
  — aceito em 2026-08-16.

## Quando criar um ADR

Criar um ADR, por exemplo, para:

- estratégia HDF5 serial ou paralela;
- implementação MPI;
- versões de MPAS e WPS;
- seleção de PnetCDF, PIO2 ou METIS com impacto de compatibilidade;
- estratégia global ou de área limitada;
- primeira malha/caso;
- desenho do pipeline ERA5;
- mudança relevante na arquitetura de build ou validação.

Uma correção local sem alternativa arquitetural relevante normalmente não
precisa de ADR, mas ainda precisa de documentação e learning note.

## Convenção

Nome do arquivo:

```text
NNNN-titulo-curto-em-kebab-case.md
```

Estados permitidos:

- `proposto`;
- `aceito`;
- `rejeitado`;
- `substituído`.

ADRs aceitos não devem ser reescritos para esconder o histórico. Uma decisão
nova que altera outra deve criar um novo ADR e apontar qual foi substituído.

## Template mínimo

```markdown
# ADR NNNN — Título

- Estado: proposto
- Data: AAAA-MM-DD
- Responsáveis: ...
- Requisitos relacionados: ...
- Fontes relacionadas: ...

## Contexto

Qual problema exige decisão e quais restrições já existem?

## Opções consideradas

Quais alternativas razoáveis foram pesquisadas?

## Decisão

Qual opção o usuário aprovou?

## Consequências

Benefícios, custos, riscos, testes e trabalho futuro.

## Evidências de validação

Links para a matriz, relatórios e learning note.
```

## Fluxo de aprovação

Um ADR pode ser preparado como `proposto`, mas somente a decisão explícita do
usuário permite marcá-lo `aceito` e implementar a escolha. O ADR não substitui
o relatório pré-commit nem a aprovação para commit/push.
