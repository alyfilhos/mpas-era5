# Ciclo 0011 — converter ERA5 real para WPS intermediate

## Objetivo e resultado

Este ciclo transforma os dois GRIBs ERA5 reais adquiridos no ciclo 0010 em
uma entrada meteorológica WPS intermediate validada:

```text
era5-pressure-levels.grib → ERA5_PRES:2014-09-10_00 ─┐
                                                         ├→ ERA5:2014-09-10_00
era5-single-levels.grib   → ERA5_SFC:2014-09-10_00 ──┘
```

O combined final possui 204 slabs, 847.251.168 bytes e SHA-256
`2d7a3ac93d1c904e45b3a19a9f524e6367f7fe72abab41a5263888f1a72b50f0`.
Ele é local e ignorado pelo Git. O ciclo não executa o modo meteorológico do
`init_atmosphere_model` e não gera `init.nc`.

## De GRIB1 a campos meteorológicos

GRIB é um formato de mensagens. Um arquivo pode conter muitas mensagens
concatenadas, cada uma com metadata e uma grade de valores. Os dois arquivos
desta baseline usam **GRIB Edition 1**.

O **parameter code** é um identificador numérico da grandeza dentro de uma
tabela. Por exemplo, na codificação ECMWF observada, 130 identifica
temperatura e 131/132 identificam componentes U/V. O número sozinho não basta:
seu significado depende do centro/tabela e precisa ser combinado com a
metadata da mensagem.

O **level type** informa a natureza da coordenada vertical. Nesta baseline:

- 100 significa nível isobárico; o valor 850 representa 850 hPa;
- 1 representa um campo de superfície;
- 112 representa uma camada abaixo da superfície, com limites codificados em
  `level1/level2`.

Consequentemente, a identidade relevante é o tuple parameter code + level type
+ limites/valor do nível. Contar 204 mensagens sem verificar esses tuples não
provaria que os campos necessários foram adquiridos.

## O que é uma Vtable

Uma Vtable é um mapa de metadata GRIB para nomes, unidades e descrições usados
pelo WPS. Ela diz, por exemplo, que certa combinação ECMWF deve entrar no
intermediate como `TT`, `PSFC` ou `SKINTEMP`.

A Vtable **não contém os dados meteorológicos**. Temperaturas, ventos e pressões
continuam nos GRIBs. A tabela apenas ensina o decoder a reconhecer cada
mensagem e dar a ela uma identidade WPS.

Todos os 204 tuples reais casaram uma única linha da tabela upstream:

```text
/opt/wps/ungrib/Variable_Tables/Vtable.ECMWF
```

O SHA-256 local dessa tabela é
`989bf7227ae5c822bfdd8467267dacc41396e08f2270735eac08c56a0096b335`.
Ela é usada diretamente e read-only. Não existe cópia no repositório nem ADR
novo, pois a tabela oficial funcionou exatamente para a baseline aprovada.

Casamentos que mereciam atenção especial:

- geopotencial pressure-level: parameter 129/type 100 → `GEOPT`, convertido
  pelo leitor upstream para `HGT`;
- geopotencial de superfície: 129/type 1 → `SOILGEO` → `SOILHGT`;
- skin temperature: 235/type 1 → `SKINTEMP`;
- snow depth: 141/type 1 → `SNOW_EC` → `SNOW`;
- sea ice: 31/type 1 → `SEAICE`;
- soil temperature: 139/170/183/236, type 112 → quatro `ST*`;
- soil moisture: 39/40/41/42, type 112 → quatro `SM*`.

Dew point de 2 m e temperatura de 2 m também permitem ao `rrpr.F` produzir a
umidade relativa superficial `RH` esperada.

## `g1print.exe`: inventário com o próprio WPS

`g1print.exe` percorre um GRIB1 e imprime, por mensagem, record number,
parameter code, nome curto, level type, limites do nível, data e forecast hour.
Ele foi usado nos bytes reais, não em fixture sintético.

A imagem publicada continha `ungrib.exe`, mas não `g1print.exe`. Como a
ferramenta era exigida para esta auditoria, o Dockerfile passou a executar
somente o alvo upstream adicional na mesma árvore WPS 4.7.0 já configurada:

```sh
./compile g1print
```

Isso não troca WPS, MPAS, compilador, bibliotecas ou arquitetura científica.
As camadas anteriores foram reutilizadas; somente o executável auxiliar e sua
proveniência foram acrescentados.

Inventário observado:

- pressure: 185 mensagens, cinco códigos em cada um dos 37 níveis, type 100;
- single-level: 19 mensagens, types 1/112 e camadas exatas;
- todos os tempos: 2014-09-10 00 UTC, forecast zero;
- todas as mensagens: GRIB1.

## `GRIBFILE.AAA` e `link_grib.csh`

O `ungrib` procura uma sequência de nomes `GRIBFILE.AAA`, `GRIBFILE.AAB`, etc.
`link_grib.csh` cria esses links para os GRIBs de entrada. O wrapper monta um
único GRIB read-only como `/input/era5.grib`, chama:

```sh
/opt/wps/link_grib.csh /input/era5.grib
```

e exige exatamente um `GRIBFILE.AAA`, apontando para essa entrada. Pressure e
single-level usam diretórios temporários diferentes, logo nenhum link da
primeira execução vaza para a segunda.

## `namelist.wps`, prefix e `ungrib`

O `namelist.wps` fornece o intervalo temporal e as opções de escrita. O recorte
mínimo da baseline usa a mesma data inicial/final, intervalo de 3600 segundos,
formato WPS e um prefix explícito:

```fortran
&share
 start_date = '2014-09-10_00:00:00',
 end_date   = '2014-09-10_00:00:00',
 interval_seconds = 3600,
/

&ungrib
 out_format = 'WPS',
 prefix = 'ERA5_PRES', ! ou ERA5_SFC
/
```

O **prefix** determina o começo do nome de saída, não o conteúdo. Separá-lo
permite provar individualmente quais slabs vieram do pressure GRIB e quais
vieram do single-level GRIB.

`ungrib.exe` decodifica as mensagens indicadas pela Vtable e escreve campos
normalizados no formato intermediário. O wrapper não considera apenas o exit
code: o log precisa conter `Successful completion of ungrib.` e deve existir
exatamente o arquivo de timestamp esperado.

## Por que pressure e surface são processados separadamente

A separação fornece isolamento e diagnóstico:

1. cada GRIB tem um inventário e uma contagem independentes;
2. cada execução começa sem `GRIBFILE.*` anterior;
3. um problema superficial não obscurece o sucesso pressure, e vice-versa;
4. os dois intermediates podem ser validados antes da combinação;
5. o manifesto preserva tamanho, hash, campos e logs por origem.

O container roda sem rede, com filesystem raiz read-only, UID/GID do host,
capabilities removidas, `no-new-privileges`, GRIB/namelist read-only e somente
o workspace temporário writable. `/opt/wps` nunca é modificado em runtime.

## Formato WPS intermediate version 5

O intermediate não é GRIB nem NetCDF. Ele é uma sequência de slabs em
**Fortran sequential unformatted records**, escritos em **big endian**.

Um registro Fortran sequencial é enquadrado por record markers. Nesta build,
cada marker é um inteiro big-endian de quatro bytes contendo o tamanho do
payload:

```text
[4 bytes: N] [N bytes de payload] [4 bytes: N]
```

Para cada slab, o formato version 5 escreve cinco records:

1. `version = 5`;
2. header geral (`hdate`, `xfcst`, source, `field`, `units`, descrição,
   `xlvl`, `nx`, `ny`, `iproj`);
3. metadata específica da projeção;
4. flag lógica de vento relativo à grade;
5. grade real de `nx * ny` valores float32.

`field` é o nome WPS, como `TT` ou `HGT`. `xlvl` é o nível numérico WPS;
nos campos isobáricos observados ele aparece em Pa, por exemplo 85000.
`iproj` seleciona a estrutura do terceiro record. O ERA5 global real produziu
`iproj=0`, projeção cilíndrica equidistante, 1440×721, incrementos de 0,25°.

O parser `wps-intermediate.py` é streaming: carrega somente metadata pequena,
valida o comprimento esperado do slab e usa seek para saltar seus 4.152.960
bytes. Ele confere markers anterior/posterior, version, data, strings,
números finitos, dimensões, metadata da projeção, flag lógica, tamanho do slab
e EOF exatamente depois de um conjunto completo. Assim os 847 MB não precisam
ser carregados em RAM.

## Por que a concatenação funciona

Cada slab WPS é autocontido e termina no trailing marker de seu quinto record.
Uma sequência completa pode ser seguida por outra sequência completa. Por
isso, depois de validar os dois componentes, o projeto faz logicamente:

```sh
cat ERA5_PRES:2014-09-10_00 ERA5_SFC:2014-09-10_00 \
  > ERA5:2014-09-10_00
```

O `cat` isolado não seria evidência suficiente. O projeto também prova que:

- o tamanho combinado é a soma exata dos tamanhos;
- o SHA combinado corresponde ao stream pressure seguido de single;
- os headers aparecem exatamente nessa ordem;
- o parser chega ao EOF após o slab 204;
- o inventário funcional completo continua presente.

A promoção usa hard link atômico no mesmo filesystem e recusa sobrescrever
um canônico divergente. Reexecução byte-idêntica retorna `unchanged`.

## Inventário funcional produzido

Pressure gera `HGT`, `RH`, `TT`, `UU` e `VV` em todos os 37 níveis
isobáricos. Single-level acrescenta `PSFC`, `PMSL`, `SOILHGT`, `LANDSEA`,
`SKINTEMP`, `SEAICE`, `SNOW`, `TT/UU/VV/RH` próximos à superfície, quatro
`ST*` e quatro `SM*`.

As conversões `GEOPT→HGT`, `DEWPT→RH`, `SOILGEO→SOILHGT` e
`SNOW_EC→SNOW` substituem o campo fonte durante o processamento upstream.
Nenhum slab derivado adicional foi observado; o total permanece 204.

## GRIB, intermediate e NetCDF não são sinônimos

| Estágio | Papel nesta pipeline |
|---|---|
| GRIB1 | bytes distribuídos pelo CDS, organizados como mensagens meteorológicas codificadas |
| WPS intermediate | slabs decodificados, nomeados pela Vtable e preparados para o leitor real-data |
| NetCDF MPAS | estrutura final orientada à mesh, produzida posteriormente pelo `init_atmosphere_model` |

Ter um intermediate correto não implica que a interpolação para a mesh MPAS
foi executada. Essa última seta tem configuração, dimensões, física, logs e
validações próprias.

## Arquivos versionados

- `Dockerfile`: target incremental upstream `g1print` e proveniência;
- `cases/first-global-240km/wps/`: dois namelists e instruções;
- `scripts/run/ungrib-era5.sh`: workspaces isolados, execução e promoção;
- `scripts/validate/wps-intermediate.py`: parser estrutural streaming;
- `scripts/validate/wps-era5.py`: cruzamento GRIB/Vtable/logs/headers;
- `scripts/validate/wps-era5.sh`: orquestração do teste integrado;
- `scripts/validate/wps-ungrib.sh`: smoke estendido;
- documentos de estado, caso, stack, grafo, fontes, versões e testes;
- esta learning note.

GRIBs, intermediates, logs e manifestos permanecem sob `data/`, ignorados.

## Comandos importantes

```sh
./scripts/validate/era5.sh
./scripts/run/ungrib-era5.sh
./scripts/validate/wps-era5.sh

python3 scripts/validate/wps-intermediate.py \
  --expect-date 2014-09-10_00:00:00 \
  --expect-nx 1440 --expect-ny 721 --expect-iproj 0 \
  data/cases/first-global-240km/wps/ERA5:2014-09-10_00
```

O primeiro comando protege a entrada adquirida. O segundo materializa os dois
intermediates e o combined. O terceiro refaz `g1print` e cruza toda a cadeia.
O último permite inspecionar isoladamente a estrutura do combined.

## Testes e como interpretar os resultados

- `scripts/validate/era5.sh`: `PASS` significa que requests, framing, edição,
  contagens, tamanhos, hashes e manifesto bruto continuam coerentes;
- `scripts/validate/wps-ungrib.sh`: `PASS` confirma instalação, links,
  executáveis, dependências e proveniência WPS;
- `scripts/validate/wps-era5.sh`: `PASS` exige 185 + 19 mensagens, mapeamento
  único completo, dois logs bem-sucedidos, parser version 5, concatenação exata,
  grade global e papéis funcionais completos;
- `git diff --check`: ausência de whitespace errors nos arquivos versionados;
- `git status --ignored --short`: outputs grandes aparecem como ignorados, não
  como arquivos prontos para commit.

## Falhas encontradas e diagnóstico

A primeira validação estrutural esperava tamanhos incorretos para records de
projeção. O source 4.7.0 mostrou que `iproj=0` escreve uma string de oito bytes
mais cinco floats, total 28 bytes, não 32. Os formatos de todas as projeções
suportadas foram corrigidos a partir do layout upstream.

Depois, a leitura encontrou `startlat=90.00000762939453`. Esse pequeno excesso
é arredondamento float32, não uma grade além do polo. O parser passou a aceitar
uma tolerância estrutural estreita, enquanto a validação semântica continua
exigindo proximidade de 90° e cobertura exata dentro da tolerância.

Uma reexecução inicialmente recusou logs divergentes porque timestamps de
wall clock tornam cada log diferente mesmo com output científico idêntico. A
política final preserva o log canônico se ambos contêm sucesso explícito e o
intermediate é byte-idêntico. Artefato científico divergente continua sendo
recusado.

Na revisão final, a nova checagem de unidades supôs primeiro que cada
campo-alvo derivado estaria em uma linha da Vtable sem parameter code. `HGT`
mostrou que essa suposição era falsa. A busca foi corrigida para reunir as
unidades de todas as linhas do campo-alvo e exigir um resultado único; a
integração voltou a PASS. Essa falha ocorreu apenas no validador, depois que os
artefatos canônicos já estavam protegidos.

Nenhuma falha parcial foi promovida. Nenhum download CDS foi repetido.

## Trade-offs e decisões

A Vtable upstream evita uma fonte paralela que poderia divergir da versão WPS.
Isso é correto porque o inventário real demonstrou compatibilidade integral;
se uma mensagem não casasse, o ciclo teria parado antes de criar uma tabela
custom.

Concatenar mantém o fluxo simples e reproduz o plano do projeto. A segurança
vem da validação completa de records antes/depois, não do `cat` em si.

O parser Python evita dependências pesadas e uso excessivo de RAM. Ele valida
estrutura e metadata, mas deliberadamente não faz estatística física sobre
todos os valores do slab; a validação física do estado interpolado pertence ao
ciclo de `init.nc`.

## O que este ciclo comprovou — e o que não comprovou

Comprovou:

```text
ERA5 GRIB real
      ↓
inventário semântico completo
      ↓
Vtable.ECMWF upstream compatível
      ↓
WPS 4.7.0 ungrib
      ↓
ERA5:2014-09-10_00 v5, estrutural e funcionalmente validado ✅
```

Não comprovou:

```text
WPS intermediate → MPAS init_atmosphere → init.nc
```

Ao final, o leitor deve conseguir explicar por que parameter code exige level
type, como uma Vtable guia o decoder sem conter dados, como records Fortran
sequenciais delimitam cada slab, por que a concatenação é legítima e por que
um WPS intermediate validado ainda não é um `init.nc` validado.
