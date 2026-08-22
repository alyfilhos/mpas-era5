# Material de portfólio — MPAS-ERA5

Este documento é um kit de adaptação. Ele não publica nada automaticamente e
não deve ser copiado sem ajustar tom, idioma e links do perfil.

## A. Descrição curta para GitHub/CV

Projeto reproduzível de modelagem atmosférica que implementa o pipeline
ERA5 → WPS → MPAS-Atmosphere em Docker, com stack HPC em MPI, I/O científico
paralelo, execução global e validação numérica/científica documentada.

Alternativa mais técnica:

> Construí e validei uma stack containerizada GNU/OpenMPI +
> HDF5/netCDF/PnetCDF/PIO para inicializar o MPAS 8.4.1 com ERA5, executar
> uma simulação global em quatro ranks e auditar outputs com Python/xarray.

## B. Bullets técnicos para currículo

- Implementei um pipeline reproduzível ERA5 → GRIB → WPS intermediate →
  MPAS `static/init/atmosphere`, com versões, hashes, ADRs e testes em camadas.
- Integrei OpenMPI, PnetCDF e PIO2 para I/O científico paralelo e diagnostiquei
  o comportamento MPI-IO OMPIO versus ROMIO sem trocar a implementação MPI.
- Executei o MPAS-Atmosphere 8.4.1 numa mesh global x1.10242 (~240 km,
  10.242 células), por 1 h em 4 ranks, com 0 errors/critical e outputs CDF-2.
- Criei validação científica reproduzível em Python/xarray/NumPy, auditando
  47,6 milhões de valores, integridade, estabilidade, superfície,
  precipitação e diagnósticos de massa/água.
- Estruturei containers separados para computação científica, aquisição CDS
  e análise, mantendo credenciais e gigabytes de dados fora do Git.

## C. Post LinkedIn curto

Concluí um projeto técnico de modelagem atmosférica com MPAS e ERA5.

Construí do zero um pipeline reproduzível em Docker: stack GNU/OpenMPI,
HDF5/netCDF/PnetCDF/PIO, WPS, mesh global, aquisição ERA5, geração de
`static.nc` e `init.nc`, execução do MPAS-Atmosphere e análise dos resultados
com Python/xarray.

A primeira baseline avançou uma hora em quatro ranks MPI na mesh x1.10242
(~240 km), terminou sem erros críticos e passou nos checks funcionais,
numéricos e de sanity científico. Também documentei decisões, limitações e
casos de borda — sem confundir uma execução estável com forecast skill.

O maior aprendizado foi tratar reprodutibilidade como parte da engenharia:
fontes, versões, checksums, isolamento, dados fora do Git e evidência em cada
camada.

Tecnologias: Docker, Linux, OpenMPI, HDF5/netCDF, PnetCDF, PIO, METIS, WPS,
MPAS, ERA5/CDS e Python.

## D. Post LinkedIn técnico

Finalizei uma baseline end-to-end de MPAS-Atmosphere inicializada com ERA5,
com foco em HPC, reprodutibilidade e validação científica.

O pipeline reproduzido foi:

```text
ERA5/CDS → GRIB → WPS/ungrib → intermediate
         → MPAS init_atmosphere → static.nc + init.nc
         → atmosphere_model → history/diagnostics
         → xarray/NumPy/Matplotlib → sanity + figuras
```

A stack científica usa GNU/OpenMPI, zlib, HDF5, netCDF-C/Fortran, PnetCDF,
PIO2 e METIS. A execução baseline usa MPAS 8.4.1, WPS 4.7.0, mesh global
x1.10242 com 10.242 células (~240 km), 55 níveis, `dt=1200 s` e quatro ranks
por uma hora.

Resultados concretos:

- relógio avançou de 00 para 01 UTC;
- 0 errors e 0 critical no log;
- quatro outputs CDF-2 íntegros;
- 47.603.258 valores auditados sem NaN/Inf;
- pressão, densidade, temperatura e espessura vertical positivas;
- `scientific_sanity=PASS`.

Os detalhes mais interessantes vieram da investigação: backend MPI-IO
OMPIO/ROMIO no PnetCDF; mudança justificada de PIO 2.6.5 para 2.7.0; dados
WPS_GEOG low-res insuficientes; validação da Vtable contra 204 GRIBs reais;
parser do formato WPS intermediate; e análise source-aware de pequenos
valores negativos de `qv`/`q2`.

Também separei três containers: científico, aquisição CDS e análise. Dados
meteorológicos e outputs volumosos ficam fora do Git; o repositório preserva
scripts, configurações, proveniência, testes, ADRs e evidência pequena.

Limites explícitos: esta baseline não mede forecast skill, spin-up ou
escalabilidade. Essas perguntas exigem outros experimentos.

## E. Principais tecnologias

- Docker e Linux;
- GCC/GFortran;
- MPI e OpenMPI;
- zlib, HDF5, netCDF-C e netCDF-Fortran;
- PnetCDF e ParallelIO/PIO;
- METIS;
- WPS/ungrib;
- MPAS-Atmosphere;
- ERA5 e Climate Data Store/CDSAPI;
- Python, xarray, NumPy e Matplotlib;
- Git, Markdown/Obsidian e ADRs.

## F. Resultados concretos

| Resultado | Evidência comunicável |
|---|---|
| pipeline | ERA5 até history/diagnostics e figuras |
| mesh | x1.10242, 10.242 células, ~240 km |
| modelo | MPAS-Model 8.4.1 / WPS 4.7.0 |
| paralelismo | 4 ranks com `part.4` |
| execução | 1 h, `dt=1200 s`, 0 errors/critical |
| estrutura | 55 níveis MPAS e 4 níveis de solo |
| auditoria | 47.603.258 valores, 0 NaN/Inf |
| ciência | `scientific_sanity=PASS` |
| limites | skill não avaliado; spin-up com janela insuficiente |

Não usar “acurácia”, “speedup”, “alta performance comprovada” ou
“forecast validado” sem um experimento novo que produza essa evidência.

## G. Imagens sugeridas

1. `t2m-t1.png` — resultado final fácil de interpretar;
2. `delta-t2m.png` — mostra que o estado evoluiu;
3. `precipitation-1h.png` — produto meteorológico reconhecível;
4. `q2-negative-cells.png` — bom para contar a história de diagnóstico;
5. diagrama compacto do pipeline no
   [[../architecture/project-graph|grafo do projeto]].

Ao publicar, incluir mesh, timestamp, duração, resolução e a frase
“sanity científico; forecast skill não avaliado”.

## H. Tópicos para entrevista

- por que HDF5/netCDF serial e PnetCDF/PIO paralelo podem coexistir;
- diferença entre MPI, MPI-IO, OMPIO, ROMIO, PnetCDF e PIO;
- como uma partição METIS se relaciona ao número de ranks;
- por que WPS intermediate precisou de parser/validação semântica;
- como validar uma Vtable contra os GRIBs reais;
- diferença entre build, smoke, integração, sanity e forecast verification;
- como investigou `qv`/`q2` sem alterar silenciosamente os outputs;
- por que separar containers de aquisição, ciência e análise;
- uso de mounts read-only, UID/GID, `network none` e secrets;
- como manter dados grandes fora do Git sem perder reprodutibilidade;
- como ADRs, source registry, versions lock e learning notes tornam decisões
  auditáveis;
- quais extensões exigiriam novo desenho experimental e novos gates.

## Links internos para adaptar

- [[../project/completion-report|relatório técnico]];
- [[../reproducibility/end-to-end|reprodução end-to-end]];
- [[../validation/first-atmosphere-run|validação científica]];
- [[../testing/validation-matrix|matriz de evidências]].
