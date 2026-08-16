# Condicao inicial meteorologica do primeiro caso

Estes arquivos configuram o `init_atmosphere_model` 8.4.1 para transformar o
`x1.10242.static.nc` e o WPS intermediate
`ERA5:2014-09-10_00` em `x1.10242.init.nc`.

O namelist parte do arquivo gerado pela propria build 8.4.1. As mudancas
efetivas seguem o caso global x1.10242 do tutorial oficial St Andrews 2025:

- case real-data 7 em `2014-09-10_00:00:00`;
- 55 camadas atmosfericas MPAS e topo em 30 km;
- 38 niveis first-guess: 37 isobaricos mais o nivel especial de superficie;
- quatro camadas de solo tanto no first guess quanto no modelo;
- umidade relativa (`config_use_spechumd=false`);
- geracao da grade vertical e interpolacao meteorologica ligadas;
- static, native GWD, SST auxiliar e LBC desligados neste estagio;
- sea ice fracional ligado;
- `config_noahmp_static=false`, coerente com o static ja produzido;
- prefixo de decomposicao `x1.10242.graph.info.part.`.

Opcoes nao usadas pelo case 7, como `config_stop_time`, `config_sfc_prefix` e
os seletores de geografia, permanecem com os defaults gerados pela release.
Em particular, o valor default de `config_stop_time` nao participa da criacao
de uma unica condicao inicial; o source 8.4.1 o usa nos cases 8 e 9.

`streams.init_atmosphere` tambem preserva a estrutura default. Apenas o input
e o output foram ajustados para `x1.10242.static.nc` e
`x1.10242.init.nc`. Os streams `ugwp_oro_data`, `surface` e `lbc` permanecem
declarados, mas nao geram arquivos porque seus packages/stages nao estao
ativos. Um caso global nao requer LBC.

Execucao reproduzivel:

```sh
./scripts/run/generate-init.sh
./scripts/validate/init.sh
```

O runner exige `x1.10242.graph.info.part.4` e executa exatamente quatro ranks.
O NetCDF, o log e o manifesto ficam em
`data/cases/first-global-240km/init/`, fora do Git.
