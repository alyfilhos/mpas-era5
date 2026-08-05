# ADR 0002 — PIO 2.7.0 com PnetCDF e netCDF serial

- Estado: aceito
- Data: 2026-08-04
- Responsável pela decisão: usuário responsável pelo projeto
- Requisitos relacionados: REQ-ENV-001, REQ-STACK-002 a 006,
  REQ-MPAS-001, REQ-MPAS-002, REQ-DOC-001
- Fontes relacionadas: DOC-PIO-001 a 006, DOC-MPAS-001, REL-PIO-001,
  REL-CMAKE-FORTRAN-UTILS-001, REL-GENF90-001

## Contexto

O MPAS deve ser compilado futuramente com `USE_PIO2=true`, com `NETCDF`,
`PNETCDF` e `PIO` apontando para suas instalações. A documentação oficial
do MPAS-Atmosphere recomenda PIO 2.x, `PIO_ENABLE_TIMING=OFF` e registra
`pnetcdf` como `io_type` padrão, além de aceitar `pnetcdf,cdf5`, `netcdf`
e `netcdf4`.

A stack já validada antes deste ciclo era:

| Componente | Configuração relevante |
|---|---|
| HDF5 1.14.6 | serial |
| netCDF-C 4.10.1 | `--disable-parallel4` |
| netCDF-Fortran 4.6.3 | sobre o netCDF-C existente |
| PnetCDF 1.15.0 | MPI-IO, GIO desabilitado |
| OpenMPI 4.1.6 | OMPIO e ROMIO disponíveis |

A documentação PIO contém um conflito: o `README.md` da release diz que
netCDF-C deve ter MPI/HDF5 paralelo, enquanto o `Installing.txt` da mesma
release diz que isso é ideal. Reconstruir HDF5/netCDF invalidaria camadas já
testadas, portanto a compatibilidade precisava ser resolvida pelo código
oficial e por um probe descartável antes da decisão.

## Evidência técnica

O CMake da release:

1. encontra NetCDF e PnetCDF separadamente;
2. testa NetCDF-4 em `HAVE_NETCDF4`;
3. testa `NC_HAS_PARALLEL` em `HAVE_NETCDF_PAR`;
4. não chama `nc_create_par` ou `nc_open_par` no teste de configuração;
5. não aborta quando `HAVE_NETCDF_PAR` é falso;
6. define a macro interna `_NETCDF4` somente quando
   `HAVE_NETCDF_PAR` é verdadeiro.

Os despachos de `PIO_IOTYPE_PNETCDF` e `PIO_IOTYPE_NETCDF` permanecem no
build sem `_NETCDF4`. Os despachos `PIO_IOTYPE_NETCDF4C` e
`PIO_IOTYPE_NETCDF4P` são condicionais. Assim, a consequência real desta
release sobre a stack serial é:

```text
PIO_IOTYPE_PNETCDF = disponível
PIO_IOTYPE_NETCDF  = disponível
PIO_IOTYPE_NETCDF4C = indisponível
PIO_IOTYPE_NETCDF4P = indisponível
```

O probe descartável e o build permanente confirmaram exatamente esse
resultado. PIO aceitou a stack serial, a suíte 2.7.0 passou e um programa em
quatro ranks escreveu e releu um arquivo por `PIO_IOTYPE_PNETCDF`.

## Versão considerada

`pio2_6_5` foi a candidata inicial, não uma versão pré-aprovada. Durante a
pesquisa, `pio2_7_0`, publicada em 2026-04-29, era a release estável oficial
atual. O probe 2.6.5 teve falha persistente em `pio_rearr_opts` tanto com
OMPIO quanto com ROMIO. O probe 2.7.0 passou 109/109 testes e corrigiu o
comportamento observado. Não há benefício comprovado em retroceder.

## Opções consideradas

### A. Preservar HDF5/netCDF serial e usar PnetCDF

PIO usa PnetCDF para o I/O paralelo padrão do MPAS e NetCDF clássico quando
necessário. Não há NetCDF-4 por PIO nesta configuração.

Vantagens:

- preserva todas as camadas já validadas;
- atende o `io_type=pnetcdf` padrão do primeiro caso;
- mantém explícito o caminho PIO → PnetCDF → MPI-IO;
- tem menor superfície de regressão e menor duplicação;
- passou a suíte e o smoke real.

Riscos:

- `netcdf4` não pode ser escolhido no MPAS sem novo trabalho;
- nesta release, nem `PIO_IOTYPE_NETCDF4C` fica disponível;
- um caso futuro que exija filtros, compressão HDF5 ou NetCDF-4 paralelo
  precisará reabrir a decisão.

### B. Reconstruir HDF5 e netCDF com MPI antes do PIO

HDF5 seria reconstruído com suporte paralelo; netCDF-C e netCDF-Fortran seriam
reconstruídos sobre ele.

Vantagens:

- habilitaria o caminho NetCDF-4 paralelo;
- permitiria avaliar `PIO_IOTYPE_NETCDF4P` e recursos HDF5/netCDF-4.

Riscos:

- invalida HDF5, netCDF-C e netCDF-Fortran já validados;
- amplia tempo de build, matriz de testes e risco de linkagem;
- pode afetar uso serial e dependências posteriores;
- não há necessidade comprovada para o primeiro caso PnetCDF.

### C. Manter stacks serial e paralela separadas

Dois prefixos conteriam variantes diferentes de HDF5/netCDF.

Vantagens:

- isola experimentos e preserva a stack serial original;
- permite comparar comportamentos.

Riscos:

- duplica bibliotecas, configuração, documentação e testes;
- aumenta o risco de misturar headers e bibliotecas de prefixos diferentes;
- exige disciplina adicional de `PATH`, `CPPFLAGS`, `LDFLAGS` e rpath;
- não entrega valor imediato para o primeiro caso.

### D. Alterar o source PIO para liberar NetCDF4C sem NetCDF paralelo

Uma mudança local poderia desacoplar `PIO_IOTYPE_NETCDF4C` de
`HAVE_NETCDF_PAR`.

Vantagem:

- potencial acesso ao NetCDF-4 serial sem reconstruir HDF5/netCDF.

Riscos:

- cria um fork comportamental não suportado pela release;
- exige análise e cobertura específicas em muitos blocos `_NETCDF4`;
- não é necessário para o backend padrão do primeiro caso.

Esta opção não foi adotada.

## Decisão

Adotar a opção A:

- PIO 2.7.0, tag `pio2_7_0`;
- build CMake com `CC=mpicc` e `FC=mpifort`;
- instalação em `/opt/mpas`;
- interfaces C e Fortran;
- bibliotecas PIO estáticas;
- `PIO_ENABLE_TIMING=OFF`;
- `PIO_ENABLE_TESTS=ON`;
- `WITH_PNETCDF=ON`;
- HDF5, netCDF-C, netCDF-Fortran e PnetCDF preservados sem reconstrução;
- `PIO=/opt/mpas`, mantendo `NETCDF=/opt/mpas` e
  `PNETCDF=/opt/mpas`.

O futuro MPAS deverá usar `USE_PIO2=true`. Para o primeiro caso,
`io_type=pnetcdf` não precisa de `PIO_IOTYPE_NETCDF4P`. Essa conclusão se
baseia simultaneamente no default/documentação do MPAS, no despacho do
ParallelIO e no teste empírico do backend PnetCDF.

## Por que CMake

CMake foi escolhido porque:

- é suportado oficialmente pela release;
- expressa diretamente `PIO_ENABLE_TIMING=OFF`, recomendação oficial do
  MPAS;
- separa descoberta e testes de recursos;
- integra a suíte com CTest;
- permite fornecer auxiliares já fixados por `USER_CMAKE_MODULE_PATH` e
  `GENF90_PATH`, evitando clones internos mutáveis.

Autotools continua suportado upstream, mas não oferece vantagem comprovada para
esta arquitetura e não foi escolhido para o build permanente.

## Consequências

- o primeiro backend paralelo do MPAS será PnetCDF;
- `PIO_IOTYPE_NETCDF` está compilado, mas ainda requer smoke funcional
  dedicado se vier a ser usado;
- `PIO_IOTYPE_NETCDF4C` e `PIO_IOTYPE_NETCDF4P` estão indisponíveis;
- qualquer reconstrução paralela de HDF5/netCDF exige novo gate e regressão
  completa;
- os auxiliares CMake/genf90 são dependências reprodutíveis fixadas por commit;
- a suíte é construída serialmente para contornar uma corrida upstream entre
  módulos Fortran gerados, mas os 109 testes são executados;
- a integração MPAS real ainda deverá comprovar `USE_PIO2=true`,
  descoberta dos três prefixos e uma execução mínima.

## Evidências de validação

- build da imagem `mpas-era5:pio-2.7.0`: código 0;
- camadas zlib/HDF5/netCDF/PnetCDF: recuperadas do cache;
- CTest: 109/109;
- instalação C/Fortran e pacote CMake: verificados;
- IOTYPEs: `PNETCDF=1 NETCDF=1 NETCDF4C=0 NETCDF4P=0`;
- smoke PIO/PnetCDF: CDF-2 em quatro ranks, aprovado com OMPIO e ROMIO;
- regressão PnetCDF/Fortran: CDF-5 em quatro ranks, aprovada.

Detalhes e limitações estão em
[[../testing/validation-matrix|validation-matrix.md]] e a explicação didática
em [[../../learning/commits/0003-add-pio2|learning/commits/0003-add-pio2.md]].

## Fontes oficiais

- [repositório NCAR/ParallelIO](https://github.com/NCAR/ParallelIO);
- [release pio2_7_0](https://github.com/NCAR/ParallelIO/releases/tag/pio2_7_0);
- [README da tag](https://github.com/NCAR/ParallelIO/blob/pio2_7_0/README.md);
- [Installing da tag](https://github.com/NCAR/ParallelIO/blob/pio2_7_0/doc/source/Installing.txt);
- [CMakeLists da tag](https://github.com/NCAR/ParallelIO/blob/pio2_7_0/CMakeLists.txt);
- [teste de NetCDF paralelo](https://github.com/NCAR/ParallelIO/blob/pio2_7_0/cmake/TryNetCDF_PARALLEL.c);
- [MPAS-Atmosphere User's Guide 8.4.0](https://www2.mmm.ucar.edu/projects/mpas/mpas_atmosphere_users_guide_8.4.0.pdf).
