# Ciclo 0014 — validar a primeira previsão MPAS

## O que mudou

Este ciclo não produziu uma nova previsão. Ele analisou o run canônico de uma
hora criado no ciclo 0013 e adicionou:

- critérios científicos escritos antes do código;
- imagem Python separada da imagem MPAS/WPS;
- analisador reproduzível dos quatro NetCDFs;
- validator que executa regressão funcional e análise offline/read-only;
- JSON estruturado, CSV das células `q2 < 0` e sete figuras;
- diagnóstico de massa de ar seco e inventário incompleto de água;
- documentação científica, ADR, grafo e referências.

A conclusão permitida é `scientific_sanity=PASS`. Não houve comparação com
observações ou ERA5 de 01 UTC; portanto `forecast_skill=NOT_EVALUATED`.

## Por que execução, sanity e validação não são sinônimos

Uma execução prova que o programa chegou ao fim e produziu arquivos. O ciclo
0013 já tinha essa evidência: relógio em 01 UTC, zero errors/critical e
history/diagnostics presentes.

Sanity numérico pergunta se os números ainda formam um estado utilizável:
finitude, dimensões, pressão/densidade positivas, camadas com espessura
positiva e ausência de explosão grosseira.

Sanity científico acrescenta significado: interpreta metadata, staggering,
acumulados, diagnósticos superficiais e inventários com fórmulas sustentadas
pelo source. Ainda assim, não mede acurácia.

Forecast verification exige uma verdade independente no mesmo instante:
observação, análise ou reanálise futura, além de métricas como viés, RMSE,
correlação, probabilidades ou scores. Nenhum desses dados entrou neste ciclo.

## Por que zero NaN não prova qualidade

Um campo pode ser totalmente finito e estar:

- deslocado espacialmente;
- com viés sistemático;
- excessivamente liso;
- com extremos errados;
- em unidades ou staggering interpretados incorretamente;
- fisicamente implausível, mas numericamente representável.

Zero NaN/Inf é condição necessária de integridade, não evidência suficiente
de skill. Por isso o validator separa PASS/FAIL de REPORT-ONLY e não transforma
qualquer estatística em aprovação.

## Estatística espacial

Min e max localizam extremos, mas cada um descreve apenas uma amostra.
Média e desvio-padrão mostram centro e dispersão; percentis descrevem a
distribuição sem supor normalidade.

O vento de 10 m ilustra a diferença. Em t1:

- média: 6,97 m s⁻¹;
- p95: 16,40 m s⁻¹;
- p99: 21,93 m s⁻¹;
- máximo: 85,05 m s⁻¹.

O máximo é um outlier real no array, preservado no mapa e no JSON. Ele não
deve ser escondido, mas também não deve representar sozinho as 10.242 células.
O valor permanece REPORT-ONLY porque não existe limite meteorológico aprovado
para este experimento.

## Evolução t0 para t1

Os arrays de `rho`, `theta` e `u` não são idênticos. Mudanças, percentis
de `t1-t0` e localizações de extremos mostram que houve integração real.

Mudança não significa melhora. Sem uma verdade de 01 UTC, só é possível dizer
quanto e onde o estado mudou.

## Temperatura derivada

O output fornece `theta` e `pressure`. A temperatura foi derivada por:

```text
T = theta * (pressure / 100000 Pa) ** (287.0 / 1004.5)
```

O cálculo usa arrays NumPy em float64. Em t1 o intervalo global foi
182,177–313,264 K. A fórmula, constantes e unidades ficam registradas no
summary e na figura de perfil.

## Staggering no MPAS

A mesh MPAS é não estruturada. Nem todos os campos ocupam o mesmo lugar:

- `rho`, `theta`, `pressure`, `qv` e `w` usam células, mas `w`
  está nas interfaces verticais;
- `u` é velocidade normal às arestas;
- `u10` e `v10` são diagnósticos de célula da surface layer;
- `zgrid` descreve interfaces, não centros de camada.

Logo, o máximo de `u` do log pode ser comparado ao mesmo array Python, mas
não deve ser exigido como igual ao vento de 10 m. Confundir staggering pode
criar uma validação aparentemente rigorosa e cientificamente errada.

## Volume e massa seca

O Registry define `rho` como densidade de ar seco, `areaCell` como área e
`zgrid` como interfaces geométricas. O source usa a mesma construção para
`airmass`. Portanto:

```text
V(i,k)   = areaCell(i) * (zgrid(i,k+1) - zgrid(i,k))
M_dry(t) = sum(rho(t,i,k) * V(i,k))
```

O delta relativo observado foi -1,58621045e-11. O número pode ser chamado de
dry-air mass conservation diagnostic porque a grandeza foi derivada de modo
inequívoco. Ele continua REPORT-ONLY: nenhuma fonte forneceu tolerância de
fechamento para transformar o delta em PASS/FAIL.

## Por que somar qv não é massa total de água

`qv` é mixing ratio de vapor, não massa. Para obter massa observável é
necessário multiplicar por massa de ar seco da camada.

Além disso, WSM6 contém vapor, água de nuvem, chuva, gelo, neve e graupel:
`qv/qc/qr/qi/qs/qg`. Há ainda precipitação acumulada, fluxos de superfície,
solo e termos fonte/sumidouro.

O ciclo calculou massa de cada espécie por:

```text
M_species = sum(rho_dry * volume * q_species)
```

e integrou precipitação com `1 mm = 1 kg m^-2`. Como faltam fluxos integrados
no tempo, o resultado se chama water inventory diagnostic, nunca conservação
ou orçamento fechado.

## qv negativo no estado inicial

O `init.nc` e history t0 são exatamente iguais para `qv`: seis valores
negativos e mínimo -1,05322406e-5 kg kg⁻¹. Em t1 todos são positivos e o
mínimo é 8,90079619e-8 kg kg⁻¹.

Isso demonstra o desaparecimento do overshoot no estado escrito. Os outputs
não separam as tendencies de cada parametrização e da advecção; atribuir a
correção a um esquema específico seria causalidade sem evidência.

## q2 e extrapolação da surface layer

O caminho inspecionado chega à implementação revisada
`physics_mmm/sf_sfclayrev.F90`, que calcula:

```text
R_q = psiq2 / psiq
q2  = qsfc + (qv_level1 - qsfc) * R_q
```

Essa é uma combinação afim. Se `R_q` estiver fora de `[0,1]`, ela vira
extrapolação e pode sair do intervalo entre os dois endpoints. A atribuição não
faz clamp.

As 11 células negativas representam 0,107401% da mesh, todas com `xland=1`
na Antártica e `qv_level1>0`. `qsfc`, `psiq` e `psiq2` não foram
escritos; logo, o mecanismo matemático é conhecido, mas a reconstrução exata de
cada célula não é possível.

A classificação sustentada é comportamento numérico limitado/documentado,
não bug/blocker. O source e o output não foram alterados.

## Precipitação acumulada

`config_bucket_update=none`. A precipitação de uma hora é a diferença de
`rainc + rainnc` entre t1 e t0.

O acumulado é finito, não negativo e não diminui. A mediana zero e os
percentis são mais informativos que somente o máximo de 4,762212 mm. Uma hora
em 240 km não valida a qualidade de precipitação.

## SST fixa e temperatura da pele

SST foi exatamente igual por array e checksum porque
`config_sst_update=false`. `skintemp` mudou em 3.295 células porque faz
parte do estado superficial evoluído.

Isso não prova que SST fixa seja apropriada para prazo longo. Também não
justifica criar `sfc_update.nc` neste ciclo. Uma previsão maior exigirá nova
decisão e dados adequados.

## Spin-up

Spin-up é um processo temporal. Dois snapshots separados por uma hora permitem
observar chuva inicial, hidrometeoros e mudanças do estado, mas não provar que
o ajuste terminou.

O status correto é `INSUFFICIENT_TEMPORAL_WINDOW`, que é um resultado
científico válido e mais informativo que uma afirmação sem suporte.

## Mapas em mesh não estruturada

`lonCell` e `latCell` localizam diretamente as 10.242 células. Não é
necessário rasterizar em grade regular nem adicionar Cartopy para esta
primeira visualização.

Matplotlib oferece projeção Mollweide nativa. Ela é útil para o domínio global,
mantém o workflow leve e torna explícitos os pontos da mesh. Os mapas são
scatter plots com colorbar, timestamp, unidades e resolução.

## Papéis de xarray, NumPy e Matplotlib

- xarray abre cada arquivo explicitamente com nomes/dimensões/atributos;
- `decode_cf=False` e `mask_and_scale=False` evitam substituir fill values
  silenciosamente;
- NumPy calcula finitude, estatísticas, percentis, volumes e inventários;
- Matplotlib/Agg produz PNGs sem interface gráfica;
- netCDF4-python é o backend compatível com os CDF-2 observados.

Nenhum pacote altera os NetCDFs. O modo de abertura e os bind mounts são
read-only.

## Container científico versus container de análise

A imagem científica compila e executa MPI, WPS e MPAS. A imagem de análise lê
outputs e produz relatórios. Misturar as duas responsabilidades aumentaria o
tamanho e acoplaria mudanças de visualização a uma stack científica validada.

`docker/analysis/` fixa base por digest e todas as distribuições por versão e
hash. Depois do build, a execução usa rede desligada, root filesystem somente
leitura, capabilities removidas e apenas o diretório de artefatos gravável.

Jupyter e Cartopy foram excluídos porque não são necessários para o objetivo.

## Artefatos reproduzíveis

O script produz somente:

- sete PNGs selecionados;
- `summary.json`;
- `q2-negative-cells.csv`.

Não produz cache versionável, NetCDF derivado, array intermediário ou centenas
de figuras. O validator confere schema, classes de critério, número de linhas,
assinatura/dimensões dos PNGs e tamanho do summary.

## Arquivos importantes

- `docker/analysis/Dockerfile`;
- `docker/analysis/requirements.lock`;
- `scripts/analyze/first-atmosphere-run.py`;
- `scripts/validate/scientific-run.sh`;
- `docs/validation/first-atmosphere-run.md`;
- `docs/assets/validation/0014/`;
- `docs/decisions/0009-separate-analysis-container.md`;
- documentos de estado, requisitos, caso, grafo, fontes e testes.

## Comandos importantes

```sh
./scripts/validate/init.sh
./scripts/validate/atmosphere-run.sh

docker build --progress=plain \
  --file docker/analysis/Dockerfile \
  --tag mpas-era5:analysis-0014 .

./scripts/validate/scientific-run.sh
```

Os dois primeiros comandos regridem entradas e run existentes; não executam
nova integração. O build verifica hashes, dependências e imports. O último
comando regride o run, analisa offline e valida os artefatos.

## Testes e interpretação

Passaram:

- build da imagem com `pip --require-hashes` e `pip check`;
- regressões `init.sh` e `atmosphere-run.sh`;
- análise de 47.603.258 números dos quatro NetCDFs;
- todos os critérios PASS/FAIL definidos antes do código;
- schema JSON, 11 linhas q2 e sete PNGs não vazios;
- inspeção visual das sete figuras.

A saída final distingue sanity de skill:

```text
functional_validation=PASS
numerical_sanity=PASS
scientific_sanity=PASS
forecast_skill=NOT_EVALUATED
spinup=INSUFFICIENT_TEMPORAL_WINDOW
```

## Falhas encontradas

A primeira execução do analisador assumiu `sst` no stream diagnostics. O
campo real estava em history. A correção passou a selecionar explicitamente o
stream que contém cada variável e registrar os arquivos de origem.

A segunda execução tentou converter `config_bucket_update` para número, mas
a metadata real era `none`. A correção interpretou isso como ausência de
bucket, sem inventar 100 mm.

Essas falhas mostram por que metadata real e abertura explícita são parte da
validação, não detalhes cosméticos.

## Trade-offs e trabalho futuro

- Mollweide/scatter é leve, mas não substitui mapas com fronteiras quando elas
  forem cientificamente necessárias.
- O delta de massa seca é útil, mas não recebe threshold sem fonte.
- O inventário de água é informativo, mas incompleto.
- Os termos internos de q2 exigiriam novo stream/run para reconstrução exata;
  não houve justificativa para reexecutar neste ciclo.
- Verificação meteorológica exigirá verdade futura, métricas e novo desenho.
- Previsões longas exigirão decisão explícita sobre surface update e janela
  suficiente para estudar spin-up/estabilidade.

## O que aprender

A lição central é que validação científica começa por dar nomes corretos às
perguntas. Integridade, sanity, conservação, inventário, spin-up e skill têm
evidências e limites diferentes. Um pipeline reproduzível deve preservar essas
distinções tanto no código quanto no vocabulário dos resultados.

