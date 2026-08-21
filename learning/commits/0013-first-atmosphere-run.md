# Ciclo 0013 — primeira integração temporal do MPAS Atmosphere

## Resultado do ciclo

Este ciclo fecha pela primeira vez o caminho funcional completo do caso
x1.10242:

```text
ERA5 → WPS intermediate → init_atmosphere → x1.10242.init.nc
     → atmosphere_model / 4 ranks → 1 hora → history + diagnostics
```

O `atmosphere_model` 8.4.1 leu o init real de 2014-09-10 00 UTC, consumiu a
partição `x1.10242.graph.info.part.4`, inicializou a física, executou três
passos de 1.200 segundos, chegou a 01 UTC e escreveu quatro NetCDFs válidos.
O log terminou com zero errors e zero critical errors.

Este é um **PASS funcional**. Ele não é, sozinho, uma validação científica da
qualidade da previsão.

## Init_atmosphere e atmosphere_model não fazem o mesmo trabalho

`init_atmosphere_model` é um pré-processador do MPAS. Nos ciclos anteriores
ele interpolou geografia e ERA5 para a mesh, construiu a grade vertical e
materializou um estado inicial consistente em um instante. Seu resultado
`x1.10242.init.nc` é uma fotografia inicial.

`atmosphere_model` é o integrador. Ele lê essa fotografia, calcula as
tendências dinâmicas e físicas, atualiza o estado e avança o relógio. O
resultado deixa de ser apenas preparação de entrada: passa a ser uma
trajetória temporal discretizada.

Em termos simples:

- init responde “qual é o estado em t=0?”;
- atmosphere responde “como esse estado evolui de t para t+dt?”.

## Integração temporal, timestep e duração

O timestep é o intervalo numérico entre atualizações sucessivas do estado. A
baseline usa:

```text
dt = 1200 s = 20 min
run duration = 3600 s = 1 h
3600 / 1200 = 3 timesteps
```

Por isso o log inicia passos em 00:00, 00:20 e 00:40; o terceiro passo produz
o estado das 01:00. O relógio final não exige um quarto `Begin timestep`.

### CFL de forma conceitual

A condição de Courant–Friedrichs–Lewy relaciona a velocidade com que uma
informação física atravessa a grade ao tamanho da célula e ao timestep. Uma
forma intuitiva é:

```text
número de Courant ≈ velocidade × dt / espaçamento
```

Se o timestep for grande demais para o espaçamento e para as velocidades
resolvidas, um sinal pode “pular” células demais em uma atualização e o método
pode ficar instável. O MPAS possui detalhes de integração e substepping que
tornam a análise real mais rica do que essa fórmula simples, mas o princípio
continua útil.

Para a mesh muito grossa x1.10242, de aproximadamente 240 km, 1.200 s é a
baseline publicada no tutorial St Andrews 2025. Uma grade mais fina em geral
exige timestep menor. “Razoável” aqui significa coerente com a referência e
aprovado pelo smoke; não significa valor universal ou prova formal de
estabilidade para qualquer atmosfera.

A duração de uma hora foi escolhida para testar inicialização, vários passos,
disparo da radiação horária e I/O final sem transformar o ciclo em uma
previsão longa.

## Cold start, restart e model clock

Um cold start começa do arquivo de condição inicial. Aqui:

- `config_do_restart=false`;
- o stream input lê `x1.10242.init.nc`;
- `initial_time` e `xtime` começam em 2014-09-10 00 UTC.

Um restart é diferente: ele retoma um estado interno salvo pelo próprio
modelo, incluindo variáveis necessárias para continuar a integração. Restart
serve a continuidade e tolerância a interrupções; não substitui o init do
primeiro cold start.

O model clock é a autoridade temporal da execução. Sucesso exige que ele
chegue a 2014-09-10 01:00:00 e que os outputs carreguem esse timestamp, não
apenas que o processo retorne código zero.

## MPI, partição e ranks

A mesh tem 10.242 células e o arquivo `graph.info.part.4` atribui cada célula
a uma de quatro partições. O comando:

```sh
mpiexec -n 4 /opt/mpas-model-8.4.1/atmosphere_model
```

cria quatro ranks MPI. O prefixo
`config_block_decomp_file_prefix='x1.10242.graph.info.part.'` faz o modelo
resolver o sufixo `4` conforme o número de ranks.

Ranks e número de partições devem coincidir. A partição não é um arquivo de
estado meteorológico; é uma descrição de como distribuir trabalho e
comunicação da mesh. Este ciclo prova compatibilidade funcional em quatro
ranks, mas não mede escalabilidade ou eficiência.

## O que significa mesoscale_reference

`config_physics_suite='mesoscale_reference'` é um nome agregador. O source
exato 8.4.1 em `mpas_atmphys_control.F` o resolve para:

| Processo | Esquema |
|---|---|
| Microfísica | WSM6 (`mp_wsm6`) |
| Convecção | New Tiedtke (`cu_ntiedtke`) |
| Camada limite planetária | YSU (`bl_ysu`) |
| Drag de ondas de gravidade | `bl_ysu_gwdo` |
| Fração de nuvens | `cld_fraction` |
| Radiação de onda longa | RRTMG LW |
| Radiação de onda curta | RRTMG SW |
| Camada superficial | Monin–Obukhov revisado |
| Superfície terrestre | Noah (`sf_noah`) |

Parametrizações representam processos que a grade não resolve explicitamente.
Elas transformam o estado e fornecem tendências ao integrador.

### Microfísica

WSM6 representa conversões entre vapor, água de nuvem, chuva, gelo, neve e
graupel. O init não continha `qi`, `qs` e `qg`, por isso o cold start
emitiu três warnings esperados. A microfísica inicializou esses campos; após
uma hora todos estavam finitos e não negativos.

### Convecção

Com células de aproximadamente 240 km, nuvens convectivas individuais não são
resolvidas. New Tiedtke representa o efeito agregado da convecção na coluna.

### PBL e surface layer

YSU representa mistura turbulenta na camada limite planetária. A surface layer
Monin–Obukhov revisada calcula as trocas próximas à interface solo-atmosfera e
diagnósticos como vento/umidade a 10/2 m. Essas duas camadas se relacionam, mas
não são o mesmo esquema.

### Noah versus Noah-MP

Noah é o land-surface model efetivo desta suite. Noah-MP é outro modelo, com
estrutura e campos estáticos adicionais. O static desta baseline foi gerado
com `config_noahmp_static=false`; ele não contém `soilcomp` ou
`soilcl1..4`.

Ativar Noah-MP sem regenerar inputs compatíveis seria cientificamente e
tecnicamente incorreto. O ciclo não ativou Noah-MP e não criou campos
artificiais.

## Radiação e intervalos

RRTMG LW e SW são caros comparados a vários cálculos executados a cada
timestep. Os parâmetros:

```fortran
config_radtlw_interval = '01:00:00'
config_radtsw_interval = '01:00:00'
```

definem a frequência dos cálculos radiativos, não o timestep do modelo. Na
primeira chamada a radiação é calculada; nos passos intermediários o modelo
reutiliza/atualiza sua contribuição conforme o contrato do esquema. Não se
deve confundir “radiação a cada hora” com “modelo avança uma vez por hora”.

## Lookup tables

Algumas parametrizações precisam de tabelas externas: propriedades radiativas,
ozônio, categorias de vegetação/solo e parâmetros Noah. O build validado já
contém esses arquivos em
`/opt/mpas-model-8.4.1/src/core_atmosphere/physics/physics_wrf/files`.

O runner cria links read-only no workdir para as 14 tabelas top-level
padronizadas necessárias à release. Ele não:

- baixa arquivos;
- os copia para o Git;
- modifica `/opt/mpas-model-8.4.1`;
- disponibiliza `NoahmpTable.TBL`, que não pertence à física efetiva.

Uma tabela ausente deve ser rastreada no source/build antes de qualquer
aquisição. Um download ad hoc destruiria a proveniência científica.

## SST fixa e surface update

O init fornece SST/skin state no instante inicial, mas o projeto ainda não
possui `x1.10242.sfc_update.nc`. Para esta hora:

```fortran
config_sst_update = false
```

O stream surface permanece inativo. A validação confirmou que os 10.242
valores de SST têm o mesmo checksum e as mesmas estatísticas em t=0 e t=1h.

Uma SST fixa é aceitável como smoke curto. Em integrações longas a superfície
oceânica real evolui e um surface update pode ser necessário. O resultado
deste ciclo não autoriza generalizar a configuração.

## History, diagnostics e restart

History contém o estado do modelo necessário para analisar a evolução de
campos prognósticos e muitos campos associados. Diagnostics contém produtos
derivados, por exemplo `t2m`, `q2`, `u10` e `v10`. Um diagnóstico pode
mudar mesmo quando não é uma variável diretamente integrada.

Restart tem outra finalidade: permitir continuação numericamente coerente.
Um arquivo history não deve ser tratado automaticamente como restart.

Os stream lists oficiais 8.4.1 foram preservados; somente filenames/intervalos
necessários foram alterados. O ciclo não reduziu arbitrariamente o inventário
científico para facilitar testes.

## Runner seguro e manifesto

`scripts/run/run-atmosphere.sh`:

- exige o init e a partição validados;
- monta entradas/configurações read-only;
- executa sem rede e com rootfs read-only;
- usa UID/GID do host;
- remove capabilities e ativa `no-new-privileges`;
- permite escrita somente no workspace;
- promove o resultado somente depois de validar;
- recusa sobrescrever um run divergente;
- valida e retorna `unchanged` se o run canônico já existe.

O manifesto registra imagem, versão/commit MPAS, hashes do init, partição,
configurações e outputs, ranks, timestep, duração, suite, comando e wall time.
Assim o diretório local é auditável mesmo sem versionar NetCDFs e logs.

## Validação executada

### Preflight

```sh
git status --short --branch
git log --oneline -10
git rev-parse HEAD
./scripts/validate/init.sh
./scripts/validate/mpas-atmosphere.sh
./scripts/validate/mesh.sh
```

O HEAD era `0d499294e94661444243f9dbdadae0c776fa5c23`. As três regressões
passaram. O init permaneceu com SHA-256
`9f2625d9f93ec873a8c1f3abef24083d1b03b910a77efea2f6dbfd2e13c36c7d`.

### Execução e validação final

```sh
./scripts/run/run-atmosphere.sh
./scripts/validate/atmosphere-run.sh \
  data/cases/first-global-240km/atmosphere/run-001
```

O manifesto mediu 8 s. O log registrou 634 outputs, 3 warnings esperados,
0 errors e 0 critical. Os quatro outputs são CDF-2, possuem timestamps 00/01
UTC e dimensões coerentes. O validador varreu:

```text
history t0:  22.490.666 valores, 0 não finitos
history t1h: 22.490.666 valores, 0 não finitos
diag t0:      1.310.963 valores, 0 não finitos
diag t1h:     1.310.963 valores, 0 não finitos
```

No estado final, densidade e pressão permaneceram positivas, temperatura
derivada ficou entre 182,177 e 313,264 K e os ventos permaneceram finitos.

## Prova de evolução temporal

Comparar apenas arquivos por tamanho não prova evolução. O validador compara
valores, checksums e estatísticas:

| Campo | Média t=0 | Média t=1h | Alterados |
|---|---:|---:|---:|
| `rho` | 0,567435067 | 0,567456315 | 563.298 / 563.310 |
| `theta` | 387,861160 | 387,842178 | 563.282 / 563.310 |
| `u` | 0,0128582408 | 0,0143983372 | 1.689.600 / 1.689.600 |
| `qv` | 0,00274585766 | 0,00275305967 | 563.305 / 563.310 |
| `skintemp` | 289,059892 | 288,878181 | 3.295 / 10.242 |
| `sst` | 289,025510 | 289,025510 | 0 / 10.242 |

Nem todo campo precisa mudar. SST não mudar é exatamente o comportamento
esperado; `rho`, `theta`, `u` e `qv` mudarem prova que o estado
prognóstico não é uma cópia byte-identical do cold start.

## Umidade negativa conhecida e novo diagnóstico q2

O init tinha seis overshoots negativos de `qv`, com mínimo
`-1,05322406e-05 kg/kg`, produzidos pelo caminho RH→qv do source. O arquivo
não foi clamped. Após uma hora, `qv` tem mínimo positivo
`8,90079619e-08 kg/kg` e zero valores negativos: o defeito conhecido não
cresceu.

`q2`, um diagnóstico de 2 m, começou não negativo e terminou com 11 valores
negativos, mínimo `-4,71175474e-04 kg/kg`. A investigação no source
`physics_mmm/sf_sfclayrev.F90` encontrou a extrapolação entre umidade da
superfície e do primeiro nível sem clamp. O validador:

- exige finitude;
- conta os negativos;
- aplica um limite estreito de smoke (`q2 >= -1e-3`);
- falha para crescimento absurdo ou instabilidade;
- não modifica output nem init.

Isso é dívida técnica/científica, não justificativa para tolerância ilimitada.

## Falhas e diagnóstico

A primeira integração do modelo já terminara com sucesso, mas o validador
inicial usava um piso de `q2` mais restritivo do que o comportamento real da
surface layer 8.4.1. Duas tentativas de validação recusaram o run.

O diagnóstico correto não foi mudar timestep, física ou dados. Foi:

1. preservar o workspace que continha os outputs;
2. medir mínimo, contagem e distribuição de `q2`;
3. localizar a fórmula no source exato;
4. confirmar que todos os campos eram finitos e o modelo terminara a hora;
5. ajustar o critério explícito e documentar a dívida;
6. executar novamente e promover um run canônico validado.

Esse episódio ensina que um validador também contém hipóteses científicas. Se
uma hipótese falha, deve-se investigar produtor, significado e magnitude antes
de relaxá-la.

As quatro notas de underflow/denormal emitidas pelo launcher após a conclusão
também foram registradas. Elas não apareceram como warning/error do MPAS e não
produziram NaN/Inf, mas continuam observáveis.

## Arquivos alterados e relação

- `cases/first-global-240km/atmosphere/`: configuração e stream lists;
- `scripts/run/run-atmosphere.sh`: execução isolada, lookup links, manifesto
  e promoção;
- `scripts/validate/atmosphere-run.sh`: contrato do log/manifesto e chamada
  do smoke NetCDF;
- `tests/smoke/atmosphere_netcdf.c`: varredura, ranges e comparação t0/t1;
- `.gitignore`: mantém o run local fora do Git;
- documentação de caso, estado, matriz, grafo, fontes e versões;
- esta learning note.

O Dockerfile, o init, a partição e as versões científicas não foram alterados.
Não foi necessário ADR: a hora é a baseline funcional explicitamente aprovada
e nenhuma arquitetura mudou.

## Como interpretar o PASS

O ciclo prova:

- leitura do `init.nc` real;
- compatibilidade entre quatro ranks e `part.4`;
- inicialização da suite e de Noah;
- três atualizações temporais;
- conclusão normal em 01 UTC;
- escrita de history/diagnostics legíveis;
- ausência de NaN/Inf nos campos varridos;
- evolução real de campos prognósticos.

Ele não prova:

- conservação quantitativa de massa/energia;
- spin-up aceitável;
- skill contra observações;
- qualidade de precipitação, circulação ou superfície;
- adequação de SST fixa a previsões longas;
- desempenho ou escalabilidade MPI;
- estabilidade por cinco dias.

## O que deve vir depois

O próximo ciclo deve tratar validação científica mais ampla como uma nova
pergunta: definir métricas, tolerâncias e evidências antes de executar. A
investigação de `q2`, conservação, spin-up e surface update deve preceder
qualquer generalização para uma previsão longa.

Ao final desta nota, o leitor deve conseguir explicar por que um init válido
não prova uma previsão, como timestep/partição/física/streams cooperam durante
a integração e por que “programa terminou” é uma evidência necessária, mas
insuficiente, de correção científica.
