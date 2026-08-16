# ADR 0008 — Primeira baseline de condição inicial MPAS

- Estado: aceito
- Data: 2026-08-16
- Decisão aprovada pelo usuário no ciclo 0012

## Contexto

A mesh global x1.10242, sua partição em quatro blocos, o arquivo estático e o
WPS intermediate ERA5 já estavam validados. Faltava executar pela primeira vez
a etapa meteorológica real do `init_atmosphere_model` 8.4.1 e produzir a
condição inicial consumível futuramente pelo `atmosphere_model`.

As autoridades usadas para materializar a configuração foram, nesta ordem:

1. source exato MPAS-Model `v8.4.1`, commit
   `91c5eac175eebeaf4206bacd5cb50c39dff3c152`;
2. defaults gerados pela própria build;
3. tutorial oficial MPAS-Atmosphere St Andrews 2025;
4. decisões anteriores do primeiro caso, especialmente os ADRs 0005–0007.

O source confirmou que o caso real global é `config_init_case=7`, lê um único
intermediate `prefix:YYYY-MM-DD_HH`, converte RH em mixing ratio quando
`config_use_spechumd=false`, aceita `SKINTEMP` como base para SST quando não há
SST separado, trata `SEAICE` da entrada principal e não requer LBC. O static
existente não contém os cinco campos exclusivos de Noah-MP.

## Decisão

A primeira condição inicial usa a seguinte baseline imutável de experimento:

| Parâmetro | Baseline |
|---|---|
| Instante | 2014-09-10 00:00:00 UTC |
| Domínio | global |
| Mesh | x1.10242, 10.242 células, aproximadamente 240 km |
| Static | `x1.10242.static.nc` já produzido |
| Entrada meteorológica | `ERA5:2014-09-10_00` já validado |
| Níveis first guess | 38: 37 níveis isobáricos + nível especial de superfície |
| Níveis verticais MPAS | 55 |
| Topo do modelo | 30.000 m |
| Camadas de solo | 4 na entrada e 4 no MPAS |
| Umidade | relativa na entrada; `config_use_spechumd=false` |
| Static Noah-MP | desligado; `config_noahmp_static=false` |
| Extrapolação de temperatura | `lapse-rate` |
| MPI | 4 ranks |
| Decomposição | `x1.10242.graph.info.part.4` |
| LBC | não gerada nem requerida para o caso global |
| SST update | não gerado neste estágio |
| SST de inicialização | `config_input_sst=false`; comportamento interno baseado em SKINTEMP |
| Sea ice | `config_frac_seaice=true`; campo ERA5 principal consumido |

A grade vertical e a interpolação meteorológica são executadas; static e GWD
não são regenerados. O output é o package `initial_conds`, escrito como
`x1.10242.init.nc`.

A relação entre decomposição e execução é um contrato do caso:

```text
x1.10242.graph.info.part.4 ↔ mpiexec -n 4
```

Os quatro ranks são uma baseline funcional local, não uma conclusão sobre
performance. Os 55 níveis e o topo de 30 km são a baseline do primeiro
experimento, não uma recomendação universal.

## Consequências

- O pipeline real `ERA5 → WPS intermediate → MPAS init` passa a ter evidência
  funcional e fisicamente auditada.
- O arquivo local gerado é CDF-2, tem `nCells=10242`, `nVertLevels=55`,
  `nSoilLevels=4`, `Time=1` e timestamp correto.
- Mesh, static e init possuem exatamente 10.242 células.
- Os campos Noah-MP `soilcomp` e `soilcl1..4` permanecem ausentes por decisão;
  física futura que os exija precisa de outro static/caso.
- `SEAICE_FRACTIONAL`, OMLD e climatologia mensal de aerossóis são entradas
  opcionais neste estágio. A ausência observada não incrementou os contadores
  de warning/error/critical do MPAS; os aerossóis correspondentes foram
  inicializados em zero.
- A conversão direta de RH do source 8.4.1 preservou seis pequenos overshoots
  negativos de `qv`, mínimo `-1,05322406e-05 kg kg-1`, e dois de RH, mínimo
  `-0,152862608%`. O arquivo não foi pós-processado. O validador aceita apenas
  limites estreitos (`qv >= -2e-5`, `RH >= -0,2%`), conta e reporta os casos.
  Esta tolerância numérica é dívida explícita para a preparação do forecast.
- Nenhum workaround ROMIO foi necessário. PIO/PnetCDF escreveu o output com a
  configuração padrão da build.
- O `atmosphere_model` não foi executado. Um init estrutural e fisicamente
  coerente ainda não prova estabilidade, conservação ou qualidade de uma
  previsão.

## Alternativas não adotadas neste ciclo

- otimizar o número de ranks;
- trocar níveis MPAS, model top ou inventário ERA5;
- usar specific humidity;
- gerar um static Noah-MP;
- criar LBC para um domínio limitado;
- adicionar SST update ou OMLD;
- pós-processar/clamp manualmente a umidade do `init.nc`;
- forçar backend ou flags MPI-IO preventivamente;
- executar o `atmosphere_model` apenas como teste de abertura.

Cada alternativa muda o experimento ou a arquitetura e pertence a um ciclo
futuro com decisão própria.

## Evidência

- configuração: `cases/first-global-240km/init/`;
- executor: `scripts/run/generate-init.sh`;
- validador: `scripts/validate/init.sh` e `tests/smoke/init_netcdf.c`;
- output local ignorado:
  `data/cases/first-global-240km/init/x1.10242.init.nc`;
- 92.641.692 bytes;
- SHA-256
  `9f2625d9f93ec873a8c1f3abef24083d1b03b910a77efea2f6dbfd2e13c36c7d`;
- timer total MPAS: 6,86265 s; wrapper: 7 s;
- log: 594 outputs, 0 warnings, 0 errors e 0 critical errors.
