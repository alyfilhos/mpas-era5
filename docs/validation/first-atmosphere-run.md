# Plano de validação da primeira integração MPAS

## Escopo e ordem de execução

Este documento define os critérios do ciclo 0014 **antes** da nova análise
quantitativa. O objeto é o run canônico já produzido no ciclo 0013:

```text
data/cases/first-global-240km/atmosphere/run-001/
```

A análise compara somente os history e diagnostics de
2014-09-10 00 e 01 UTC. Ela não reexecuta `atmosphere_model`, não baixa ERA5
adicional e não compara a previsão com análise ou observação futura.

O vocabulário normativo é:

- **PASS/FAIL criterion**: condição sustentada por contrato de arquivo,
  configuração, definição física ou source exato e que pode reprovar a
  validação;
- **REPORT-ONLY diagnostic**: medida informativa sem tolerância quantitativa
  sustentada; deve ser registrada, mas não é convertida automaticamente em
  PASS;
- **NOT EVALUATED**: pergunta deliberadamente fora do desenho experimental;
- **INSUFFICIENT TEMPORAL WINDOW**: os dois instantes não permitem a
  conclusão temporal solicitada.

Nenhum limite será escolhido depois de observar o resultado apenas para fazer
o teste passar. O piso de `q2 >= -1e-3` usado no smoke funcional do ciclo 0013
continua pertencendo àquela regressão de corrupção grosseira; ele não será
promovido a tolerância científica neste ciclo.

## A. Critérios de integridade

| Métrica | Classe | Fundamento | Resultado exigido |
|---|---|---|---|
| Regressão `init.sh` | PASS/FAIL | entrada canônica do run | PASS |
| Regressão `atmosphere-run.sh` | PASS/FAIL | manifesto, log e outputs do ciclo 0013 | PASS |
| Inventário do run | PASS/FAIL | manifesto canônico | quatro NetCDFs, log e manifesto, sem arquivo inesperado |
| Hash e tamanho dos inputs | PASS/FAIL | `manifest.json` | correspondência byte a byte |
| Formato | PASS/FAIL | contrato observado do run | quatro arquivos CDF-2 / 64-bit offset |
| Timestamps | PASS/FAIL | configuração e nomes dos arquivos | history/diag em 00 e 01 UTC; `initial_time` em 00 UTC |
| Dimensões horizontais | PASS/FAIL | mesh x1.10242 | `nCells=10242`; dimensões de history/diag coerentes |
| Dimensões verticais | PASS/FAIL | configuração do caso | history com 55 níveis e 56 interfaces |
| Metadata | PASS/FAIL | Registry e headers reais | variáveis analisadas possuem nome, shape e unidades esperados |
| Missing/fill | PASS/FAIL | metadata NetCDF | nenhum marcador presente nos dados é tratado silenciosamente como número |
| Finitude | PASS/FAIL | requisito mínimo de integridade numérica | zero NaN e zero Inf inesperados em todas as variáveis numéricas |

Os quatro NetCDFs serão abertos explicitamente com `engine="netcdf4"`, em
modo somente leitura. O analisador não usa glob nem `open_mfdataset` para
inferir arquivos ou tempos.

## B. Critérios de estabilidade numérica

| Métrica | Classe | Fundamento | Resultado exigido |
|---|---|---|---|
| Área de célula | PASS/FAIL | `areaCell` é uma área | estritamente positiva |
| Espessura de camada | PASS/FAIL | diferença entre interfaces consecutivas de `zgrid` | estritamente positiva |
| Densidade seca | PASS/FAIL | `rho` é densidade de ar seco | estritamente positiva em t0 e t1 |
| Pressão atmosférica | PASS/FAIL | pressão absoluta | estritamente positiva em t0 e t1 |
| Pressão superficial/MSLP | PASS/FAIL | pressão absoluta | estritamente positiva quando disponível |
| Temperatura derivada | PASS/FAIL | escala termodinâmica absoluta | finita e estritamente positiva |
| Estado prognóstico | PASS/FAIL | uma integração real deve evoluir | `rho`, `theta` e `u` não podem ser arrays idênticos entre t0 e t1 |
| Espécies WSM6 finais | PASS/FAIL | mixing ratios de massa | `qv`, `qc`, `qr`, `qi`, `qs` e `qg` não negativos em t1 |
| Magnitude das mudanças | REPORT-ONLY | não há tolerância oficial para esta hora | máximo, média e percentis de `t1-t0` |
| Extremos de `u`, `w` e vento de 10 m | REPORT-ONLY | staggering e diagnósticos diferem | valores e localizações, com comparação conceitual ao log |
| Underflow/denormal | REPORT-ONLY | quatro notas do launcher sem estado não finito | presença e interpretação registradas |

Não serão usados limites climatológicos estreitos. Min, max, média, desvio,
percentis e mudanças servem para detectar sinais de explosão e contextualizar
outliers; sem uma fonte para a tolerância, permanecem REPORT-ONLY.

## C. Sanity checks físicos

| Métrica | Classe | Fundamento | Resultado exigido |
|---|---|---|---|
| SST fixa | PASS/FAIL | `config_sst_update=false` | igualdade exata de array e checksum entre t0 e t1 |
| `skintemp` | REPORT-ONLY | estado superficial pode evoluir | estatísticas e quantidade de células alteradas |
| Precipitação acumulada | PASS/FAIL | `rainc`/`rainnc` são acumulados em mm | finita e não negativa; acumulado ajustado por bucket não diminui |
| Fração de gelo marinho | PASS/FAIL | fração de área | valores em `[0,1]` quando presente |
| Neve/SWE/profundidade | PASS/FAIL | quantidades não negativas | finitas e não negativas quando presentes |
| `t2m`, `q2`, `u10`, `v10` | PASS/FAIL somente para integridade | diagnósticos da surface layer | shapes corretos e finitude |
| Ranges e distribuição de superfície | REPORT-ONLY | ausência de tolerância meteorológica aprovada | estatísticas, percentis e extremos |
| Skill meteorológico | NOT EVALUATED | não existe verdade em 01 UTC neste ciclo | nenhuma conclusão de acurácia |

Um `q2` negativo não reprova por si só este plano, pois o source usado não
define clamp nem tolerância. A classificação final dependerá da localização,
das variáveis de entrada disponíveis e da implementação exata.

## D. Métricas diagnósticas

Para cada campo analisado serão registrados, em t0 e t1 quando aplicável:

- nome, long name, unidades, arquivo e dimensões;
- mínimo, máximo, média, desvio-padrão e contagem;
- percentis 1, 5, 25, 50, 75, 95 e 99;
- contagens de finitos, NaN, Inf, fill/missing e negativos;
- quantidade e fração de valores que violam um critério físico aplicável;
- mudança absoluta/relativa e localização de extremos quando significativa.

O inventário inclui `rho`, `pressure`, `theta`, temperatura derivada, `u`,
`w`, espécies de `scalars`, `surface_pressure`, `mslp`, `skintemp`, `sst`,
`t2m`, `q2`, `u10`, `v10`, precipitação, neve e gelo realmente presentes.

### Diagnóstico obrigatório de `q2`

O caminho de chamada inspecionado na imagem MPAS 8.4.1 é:

```text
mpas_atmphys_driver.F
  → driver_sfclayer
  → sfclayer_to_MPAS
  → module_sf_sfclayrev.F
  → sf_sfclayrev_pre_run
  → physics_mmm/sf_sfclayrev.F90
```

`sf_sfclayrev_pre_run` seleciona o primeiro nível do modelo e a implementação
revisada calcula:

```text
R_q = psiq2 / psiq
q2  = qsfc + (qv_level1 - qsfc) * R_q
```

Não há clamp após essa expressão. Para cada `q2 < 0` serão registrados cell
ID, índice zero-based, latitude, longitude, `xland`, classe terra/oceano,
`t2m`, `skintemp`, SST, `qv`/pressão/temperatura/altura do primeiro nível,
`surface_pressure`, vento, fluxos e demais variáveis disponíveis úteis.
`qsfc`, `psiq` e `psiq2` não foram solicitados nos streams do ciclo 0013; a
ausência será registrada e nenhuma reconstrução não sustentada será inventada.

### `qv` negativo do init

A análise contará independentemente `qv < 0` no init, history t0 e history t1.
O desaparecimento dos valores será observado como resultado. Sem uma cadeia
causal demonstrada no source e nos tendencies, nenhuma parametrização ou
advecção específica receberá o crédito causal.

## E. Métricas de conservação

### Massa seca

O Registry define `rho` como densidade de ar seco, `areaCell` como área
esférica da célula e `zgrid` como altura geométrica das interfaces. O source
8.4.1 também contém:

```fortran
rho = rho_zz * zz
airmass = rho_zz * zz * (zgrid(k+1)-zgrid(k)) * areaCell
```

Logo, o volume e a massa seca observável são inequivocamente:

```text
V(i,k)     = areaCell(i) * [zgrid(i,k+1) - zgrid(i,k)]
M_dry(t)   = sum(i,k) rho(t,i,k) * V(i,k)
```

Serão reportados valor em t0/t1, delta absoluto e delta relativo. Esta métrica
pode ser chamada de **dry-air mass conservation diagnostic**, mas é
REPORT-ONLY: o ciclo não possui tolerância oficial de fechamento.

### Inventário de água

Para WSM6, o Registry confirma `qv`, `qc`, `qr`, `qi`, `qs` e `qg` como
mixing ratios. A massa observável de cada espécie será calculada por:

```text
M_species(t) = sum(i,k) rho(t,i,k) * V(i,k) * q_species(t,i,k)
```

Precipitação acumulada será integrada horizontalmente usando
`1 mm = 1 kg m^-2`. Vapor, cada hidrometeoro e precipitação permanecem
separados no resumo.

O resultado será denominado **water inventory diagnostic**, nunca “massa
total de água” ou “conservation test”. Os outputs não contêm a integral
temporal completa de fluxos superficiais, trocas com solo e todos os termos
necessários para fechar um orçamento hídrico.

## F. Evidências visuais

As figuras determinísticas planejadas são:

1. temperatura a 2 m em t1;
2. mudança de temperatura a 2 m, t1 menos t0;
3. MSLP em t1;
4. velocidade do vento a 10 m em t1;
5. precipitação acumulada total em uma hora;
6. localização das células com `q2 < 0`;
7. perfil vertical global de temperatura derivada, com distribuição espacial.

Os mapas usarão `lonCell`/`latCell` e a projeção Mollweide nativa do
Matplotlib, sem Cartopy. Cada figura terá timestamp, unidades, mesh/resolução,
colorbar/legenda e nota metodológica quando necessária. Os PNGs selecionados,
o JSON e uma tabela pequena serão destinados a
`docs/assets/validation/0014/`.

## G. O que não pode ser concluído

Este ciclo não pode demonstrar:

- forecast skill, viés ou acurácia contra ERA5/observações em 01 UTC;
- reprodução fiel do ERA5 futuro;
- equilíbrio completo do spin-up;
- conservação de energia;
- fechamento do orçamento hídrico;
- adequação de SST fixa para previsões longas;
- estabilidade em integrações de vários dias;
- desempenho ou escalabilidade MPI.

Com somente t0 e t1, o status de spin-up será
`INSUFFICIENT_TEMPORAL_WINDOW`. O status de skill será
`NOT_EVALUATED`. É permitido concluir `scientific_sanity=PASS` apenas se os
critérios de integridade, estabilidade e sanity físico acima passarem e a
investigação de `q2` não revelar corrupção ou problema grave novo.


## Resultado observado no ciclo 0014

A aplicação dos critérios acima ao run materializado pelo commit
`66ffe7746b4ba144f179d4cea3011e1f0b178d38` produziu:

| Status | Resultado |
|---|---|
| functional validation | PASS |
| numerical sanity | PASS |
| scientific sanity | PASS |
| forecast skill | NOT_EVALUATED |
| spin-up | INSUFFICIENT_TEMPORAL_WINDOW |

Os quatro NetCDFs CDF-2 mantiveram os timestamps, as dimensões
`nCells=10242`, 55 níveis/56 interfaces e 47.603.258 valores numéricos
finitos, sem NaN, Inf ou marcador missing/fill presente. `rho`, `theta` e
`u` evoluíram e pressão, densidade, espessura de camada e temperatura
derivada permaneceram estritamente positivas.

### Estatísticas espaciais principais

O desvio-padrão é populacional (`ddof=0`). A tabela é deliberadamente
compacta; percentis 1/5/25/50/75/95/99, contagens e localizações de extremos
estão em
[`summary.json`](../assets/validation/0014/summary.json).

| Campo | Unidades | t0 min / max | t0 média ± std | t1 min / max | t1 média ± std |
|---|---:|---:|---:|---:|---:|
| rho | kg m⁻³ | 0,011050 / 1,508767 | 0,567435 ± 0,410107 | 0,011050 / 1,506877 | 0,567456 ± 0,410134 |
| pressure | Pa | 675,041 / 103880,430 | 44100,294 ± 34797,417 | 674,071 / 103879,531 | 44098,367 ± 34797,344 |
| theta | K | 230,881 / 899,896 | 387,861 ± 136,190 | 231,175 / 900,141 | 387,842 ± 136,196 |
| temperatura derivada | K | 181,985 / 314,155 | 247,578 ± 32,002 | 182,177 / 313,264 | 247,554 ± 31,988 |
| surface pressure | Pa | 52894,980 / 104173,656 | 98498,117 ± 6501,523 | 53028,621 / 104170,297 | 98496,454 ± 6494,156 |
| MSLP | Pa | 92572,688 / 104171,117 | 101090,032 ± 1223,901 | 92661,562 / 104169,766 | 101091,742 ± 1221,409 |
| t2m | K | 208,159 / 311,030 | 288,527 ± 14,379 | 208,395 / 307,622 | 288,368 ± 14,169 |
| skintemp | K | 207,381 / 316,891 | 289,060 ± 14,797 | 202,633 / 327,546 | 288,878 ± 15,229 |
| qv | kg kg⁻¹ | -1,0532e-5 / 0,025113 | 0,00274586 ± 0,00450752 | 8,9008e-8 / 0,024883 | 0,00275306 ± 0,00452770 |
| q2 | kg kg⁻¹ | 5,1666e-6 / 0,024552 | 0,0105016 ± 0,0059932 | -4,7118e-4 / 0,024684 | 0,0106414 ± 0,0060060 |
| u normal às arestas | m s⁻¹ | -115,571 / 114,740 | 0,0129 ± 14,1203 | -113,970 / 114,307 | 0,0144 ± 14,1349 |
| w nas interfaces | m s⁻¹ | -0,1470 / 0,1795 | 2,8076e-5 ± 0,004451 | -0,5745 / 0,6346 | 5,2005e-4 ± 0,018662 |
| vento 10 m | m s⁻¹ | 0,038 / 23,420 | 6,303 ± 3,926 | 0,023 / 85,049 | 6,970 ± 5,064 |

O máximo final do vento de 10 m ocorre na célula 7850
(69,446°S, 82,714°E). É um outlier visível: p95=16,40 e p99=21,93 m s⁻¹,
enquanto o máximo é 85,05 m s⁻¹. Ele permanece REPORT-ONLY. Os extremos finais
de `u` e `w` reproduzem os valores impressos no log na precisão exibida;
`u` é normal à aresta e não deve ser igualado a `u10`/vento de célula.

### Diagnóstico de q2 negativo

Foram encontrados exatamente 11 valores negativos, ou
`11/10242 = 0,00107401` (0,107401%). Todos têm `xland=1`, ficam entre
75,483°S e 83,296°S na Antártica e possuem `qv` do primeiro nível positivo.
Dez têm `xice=0`; uma célula tem `xice=0,8331604`. Os valores negativos
têm:

- mínimo: -4,71175474e-4 kg kg⁻¹;
- máximo entre os negativos: -8,30017962e-6 kg kg⁻¹;
- média: -1,14089029e-4 kg kg⁻¹.

A implementação exata calcula a combinação afim

`q2 = qsfc + (qv_level1 - qsfc) × (psiq2 / psiq)`.

Se `R_q=psiq2/psiq` estivesse restrito a `[0,1]`, o resultado ficaria entre
`qsfc` e `qv_level1`. A atribuição não impõe essa restrição nem aplica clamp;
sob as funções de estabilidade, ela pode atuar como extrapolação e cruzar
zero. `qsfc`, `psiq` e `psiq2` não estão nos streams deste run, portanto
não é possível reconstruir numericamente cada linha sem inventar termos.

A tabela
[`q2-negative-cells.csv`](../assets/validation/0014/q2-negative-cells.csv)
registra cell ID, coordenadas, terra/mar, temperaturas, SST, primeiro nível,
pressões, vento, neve/gelo e fluxos disponíveis. Diante da localização
limitada, da finitude do restante do estado, de `qv_level1>0` e da fórmula
sem clamp, a classificação é **comportamento numérico limitado/documentado**,
não bug/blocker. A ausência dos três termos internos permanece limitação da
explicação célula a célula.

### qv, precipitação e superfície

O `init.nc` e o history t0 são exatamente iguais para `qv`: seis pares
célula/nível negativos, mínimo -1,05322406e-5 kg kg⁻¹. Em t1 não resta valor
negativo e o mínimo é 8,90079619e-8 kg kg⁻¹. O resultado observa a remoção do
overshoot; os outputs não isolam tendencies suficientes para atribuí-la a uma
parametrização ou à advecção específica.

`config_bucket_update=none`. A precipitação de uma hora foi calculada como
a diferença de `rainc+rainnc`: mínimo 0, máximo 4,762212 mm, média
0,0184338 mm, p95 0,0541670 mm, p99 0,419283 mm e 4.246 células positivas
(41,4567%). A mediana é zero. O máximo ocorre na célula 7694
(8,494°N, 20,625°W). Isso é sanity de acumulado, não valida qualidade de
precipitação em mesh de 240 km.

O acumulado de neve `acsnow` também foi analisado: partiu de zero, permaneceu
não negativo, atingiu 0,179898 kg m⁻² e ficou positivo em 772 células.
`precipw` é água precipitável, não chuva acumulada; permaneceu positiva e sua
média mudou de 25,4785 para 25,2917 kg m⁻².

A SST é idêntica bit a bit em t0/t1, com SHA-256 de array
`888c9574961395fc8bb4ca10a2cdf56d217275c8f9aef76543b758add632c6df`;
min/max/média são 207,650/318,184/289,026 K. `skintemp` mudou em 3.295
células e não é igual à SST. SST fixa é configuração deste experimento de uma
hora, não recomendação para integrações longas.

### Massa seca e inventário de água

O diagnóstico sustentado por Registry/source resultou em:

- `M_dry(t0)=5,052763066588878e18 kg`;
- `M_dry(t1)=5,052763066508730e18 kg`;
- delta absoluto `-8,0147456e7 kg`;
- delta relativo `-1,58621045e-11`.

Esse é um **dry-air mass conservation diagnostic**, REPORT-ONLY e sem threshold
de aprovação. Ele não deve ser convertido retrospectivamente em teste PASS.

O inventário atmosférico observável das seis espécies WSM6 aumentou de
`1,3011358191468084e16` para `1,304709260326242e16 kg`; a precipitação
integrada adicionou `9,414861525281283e12 kg`. A soma observável
atmosfera+precipitação variou `4,5149273319618e13 kg`. Como faltam integrais
temporais de fluxos de superfície/solo e todos os termos fonte/sumidouro, isso
é **water inventory diagnostic**, não conservação de água.

### Conclusão científica permitida

Não há sinal de NaN/Inf, pressão/densidade negativa, espessura inválida,
explosão global ou corrupção dos arquivos. O estado prognóstico evoluiu e os
diagnósticos permaneceram coerentes com o log. Assim,
`scientific_sanity=PASS` é sustentado para esta primeira hora.

Não foram avaliados skill, viés, erro contra ERA5/observações futuras,
adequação de SST fixa em prazo longo, fechamento energético/hídrico nem
estabilidade multidiária. Nenhum `sfc_update.nc` foi gerado e nenhum dado
ERA5 adicional foi baixado.
