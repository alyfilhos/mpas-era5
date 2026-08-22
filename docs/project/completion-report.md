# Relatório técnico de conclusão

## Estado executivo

`PROJECT_BASE_STATUS = COMPLETE`

O escopo técnico original do MPAS-ERA5 foi concluído e validado. O projeto
entrega ambiente reproduzível, stack científica, WPS/MPAS, dados ERA5,
primeiro caso global, execução MPI de uma hora, validação física/numérica,
documentação operacional e material didático.

“Complete” significa que o escopo aprovado foi atendido. Não significa que a
pesquisa meteorológica terminou:

```text
functional_validation = PASS
numerical_sanity       = PASS
scientific_sanity      = PASS
forecast_skill         = NOT_EVALUATED
spinup                 = INSUFFICIENT_TEMPORAL_WINDOW
```

## Objetivo original e escopo

O objetivo era construir, documentar e validar o caminho completo:

```text
GNU/MPI → bibliotecas científicas → WPS/MPAS
        → mesh/WPS_GEOG/ERA5 → static/init
        → atmosphere → outputs → validação
```

O escopo incluiu uma primeira malha pública de baixa resolução, um caso
global rastreável, dados grandes fora do Git e aprendizado por ciclo. Não
incluiu forecast verification, previsão de cinco dias, benchmark de
escalabilidade, Noah-MP, mesh fina, GPU ou produção operacional.

A auditoria requisito por requisito está em
[[requirements#Rastreabilidade final do escopo original|requirements.md]].
Resultado: 13 `SATISFIED`, 5 `SATISFIED_WITH_LIMITATION`, 1
`NOT_APPLICABLE` e nenhum blocker.

## Arquitetura final

### Containers por responsabilidade

| Container | Responsabilidade | Rede/runtime | Escrita |
|---|---|---|---|
| científico | GNU/OpenMPI, bibliotecas, METIS, WPS e MPAS | fases científicas offline | somente workspace/output montado |
| aquisição | Python/CDSAPI e requests ERA5 | rede apenas na aquisição | `data/era5/` |
| análise | NumPy/xarray/netCDF4/Matplotlib | `--network none` | somente artefatos documentais |

A separação impede que credenciais e dependências Python de análise
contaminem a imagem científica. O caminho de I/O paralelo é:

```text
MPAS → PIO 2.7.0 → PnetCDF 1.15.0 → MPI-IO → OpenMPI
```

HDF5/netCDF permanecem seriais; `PIO_IOTYPE_NETCDF4P` não pertence a esta
baseline. A partição é calculada offline:

```text
graph.info → METIS 5.1.0 → graph.info.part.4 → MPAS com 4 ranks
```

### Fluxo científico

```text
CDS ERA5
   ↓
GRIB
   ↓
WPS/ungrib
   ↓
WPS intermediate
   ↓
MPAS init_atmosphere
   ├── WPS_GEOG → static.nc
   └── static + ERA5 → init.nc
                           ↓
                    atmosphere_model
                           ↓
                    history / diag
                           ↓
                  analysis container
                           ↓
                 sanity + figures
```

## Versões principais

| Componente | Baseline |
|---|---|
| Ubuntu | 24.04 |
| GNU | GCC/GFortran 13.3.0 observados |
| MPI | OpenMPI 4.1.6 observado |
| zlib | 1.3.2 |
| HDF5 | 1.14.6, serial |
| netCDF-C / Fortran | 4.10.1 / 4.6.3, serial |
| PnetCDF | 1.15.0, MPI-IO, GIO desabilitado |
| PIO | 2.7.0, PnetCDF habilitado |
| METIS | 5.1.0, índices/reais 32 bits |
| WPS | 4.7.0, `ungrib` e `g1print` |
| MPAS-Model | 8.4.1 |
| análise | Python 3.12.13, NumPy 2.5.2, xarray 2026.7.0, netCDF4 1.7.4, Matplotlib 3.11.1 |

Origens, commits, hashes e limites do pinning estão em
[[../references/versions.lock|versions.lock.md]] e
[[../references/source-registry|source-registry.md]].

## Decisões arquiteturais

Os nove ADRs aceitos registram:

1. PnetCDF 1.15.0 com MPI-IO e GIO desabilitado;
2. PIO 2.7.0 sobre PnetCDF com netCDF/HDF5 serial;
3. METIS 5.1.0 como particionador offline;
4. WPS 4.7.0, MPAS 8.4.1 e prefixos separados;
5. x1.10242 e `part.4` como primeira mesh;
6. baseline WPS_GEOG/static sem Noah-MP;
7. ERA5 global em 2014-09-10 00 UTC;
8. condição inicial com 55 níveis e quatro ranks;
9. container separado para análise científica.

O índice e as consequências estão em [[../decisions/README|ADRs]].

## Baseline do primeiro caso

| Parâmetro | Valor |
|---|---|
| Mesh | x1.10242, SCVT global quasi-uniforme |
| Células / resolução | 10.242 / ~240 km |
| Tempo inicial | ERA5 2014-09-10 00 UTC |
| ERA5 pressure | 5 variáveis × 37 níveis = 185 mensagens |
| ERA5 single-level | 19 mensagens |
| WPS intermediate | version 5, 204 slabs, 1440×721, 0,25° |
| Static | CDF-2, 18.201.336 bytes |
| Init | CDF-2, 92.641.692 bytes, 55 níveis MPAS, 4 solo |
| Atmosphere | 4 ranks, `part.4`, `dt=1200 s`, 1 hora |
| Física | `mesoscale_reference`, Noah, WSM6, RRTMG |
| LBC / restart / SST update | false / false / false |
| Outputs | history e diagnostics em 00 e 01 UTC |

## Resultados e validações

### Execução funcional

- comando: `mpiexec -n 4 /opt/mpas-model-8.4.1/atmosphere_model`;
- três timesteps iniciados em 00:00, 00:20 e 00:40;
- estado final em 01:00 UTC;
- 634 mensagens de output, 3 warnings cold-start esperados;
- 0 errors e 0 critical errors;
- quatro NetCDFs CDF-2 válidos;
- 47.603.258 valores numéricos varridos, 0 NaN/Inf;
- `rho`, `theta`, `u` e `qv` evoluíram;
- SST permaneceu idêntica por configuração.

### Sanity científico

Pressão, densidade, temperatura absoluta, pressão superficial e espessura de
camada permaneceram positivas. As seis espécies WSM6 finais ficaram finitas
e não negativas. A precipitação de uma hora foi finita, não negativa e não
decrescente, com máximo 4,762212 mm e 4.246 células positivas.

O `scientific_sanity=PASS` detecta ausência de corrupção/instabilidade
e coerência básica da primeira hora. Não mede acurácia meteorológica.

### Métricas report-only

- massa de ar seco: `M(t0)=5,052763066588878e18 kg`,
  `M(t1)=5,052763066508730e18 kg` e delta relativo
  `-1,58621045e-11`; diagnóstico sem threshold, portanto `REPORT-ONLY`;
- água: espécies WSM6 e precipitação inventariadas, mas fluxos necessários
  estão ausentes; orçamento não fechado e `REPORT-ONLY`;
- `q2`: 11 células negativas (0,107401%), mínimo
  `-4,71175474e-4 kg kg⁻¹`, todas sobre terra na Antártica; comportamento
  limitado/documentado, sem clamp no source;
- `qv` do init: seis overshoots pequenos, mínimo `-1,05322406e-5 kg kg⁻¹`;
  em 1 h não havia valor negativo.

## Validação em camadas

| Camada | Evidência final |
|---|---|
| ambiente | versões GNU/OpenMPI e compilação C/Fortran |
| zlib | compressão/descompressão instalada |
| HDF5 | dataset comprimido DEFLATE escrito e relido |
| netCDF-C | NetCDF-4/deflate escrito e relido sobre HDF5/zlib |
| netCDF-Fortran | módulo Fortran escreveu/releu NetCDF-4/deflate |
| PnetCDF | CDF-5 coletivo em 4 ranks via ROMIO |
| PIO | PnetCDF/CDF-2 em 4 ranks com OMPIO e ROMIO |
| mesh/static/ERA5/WPS/init/run | validadores específicos sobre artefatos canônicos |
| ciência | critérios PASS/FAIL, report-only, summary e figuras |

`./scripts/validate/final-project.sh` executou todas essas camadas sobre o
estado local materializado, sem download, rebuild da stack ou nova previsão,
e terminou `project_validation=PASS`.

As suítes históricas upstream de zlib/HDF5 não foram reexecutadas. Os logs
históricos de `make check` netCDF não foram preservados. A dívida barata de
interface instalada foi fechada; essa limitação de evidência histórica não é
reescrita como se os logs existissem.

## Problemas investigados e aprendizado técnico

### MPI-IO: OMPIO versus ROMIO

O smoke PnetCDF mostrou escrita incompleta no caminho OMPIO do OpenMPI 4.1.6.
A investigação separou implementação MPI de backend MPI-IO: ROMIO já estava
instalado no mesmo OpenMPI. Selecionar `--mca io romio321` fez a suite e o
smoke PnetCDF passarem, sem trocar OpenMPI. Depois, o PIO 2.7.0 passou com
OMPIO e ROMIO; os resultados foram preservados sem generalização indevida.

### PIO 2.6.5 para 2.7.0

PIO 2.6.5 era candidato, mas o probe deixou falha em `pio_rearr_opts`.
PIO 2.7.0 executou 109/109 testes e compatibilizou o caminho PnetCDF com a
stack serial existente. A decisão não foi uma atualização por novidade; foi
uma escolha validada e aprovada.

### WPS_GEOG low-res insuficiente

O archive low-resolution foi inspecionado e não continha as seleções 30s
exigidas. O projeto adotou extração seletiva do high mandatory mais os dois
suplementos first-party exatos. O native GWD revelou ainda a leitura literal
de `landuse_30s/`; o output parcial não foi promovido até a entrada correta
estar presente.

### GRIB, `g1print` e Vtable

A imagem WPS inicial não continha `g1print.exe`. O alvo upstream da mesma tag
foi acrescentado sem mudar WPS/MPAS. O inventário real dos 204 registros
GRIB1 foi cruzado com requests e `Vtable.ECMWF`; cada registro casou uma
entrada única. O formato WPS intermediate recebeu parser streaming próprio,
evitando tratar “ungrib terminou” como evidência semântica suficiente.

### Umidade pequena negativa

O `qv` pequeno negativo do init foi rastreado à conversão direta de RH no
source 8.4.1 e recebeu tolerância explícita source-aware. O `q2` negativo
foi localizado na Antártica e rastreado à extrapolação afim da surface layer
revisada sem clamp. Em ambos os casos, os NetCDFs não foram corrigidos
silenciosamente: evidência e limites foram documentados.

### Dados grandes fora do Git

Mesh, WPS_GEOG, GRIB, intermediates e NetCDFs somam muitos gigabytes e não
pertencem ao histórico. Scripts, requests, pins, manifests locais, checksums
e validações tornam os bytes reproduzíveis/auditáveis sem transformar Git em
storage científico.

## Lições Docker transferíveis

- imagem é o ambiente imutável; container é uma execução descartável;
- layers/cache preservam builds caros, mas cache não é evidência de teste;
- aquisição, ciência e análise têm dependências e superfícies de risco
  distintas;
- bind mounts permitem manter dados grandes fora da imagem;
- inputs read-only, UID/GID do host e output limitado evitam arquivos
  root-owned e mutações acidentais;
- `--read-only`, `--network none`, `--cap-drop ALL` e
  `no-new-privileges` reduzem o runtime ao necessário;
- secrets devem entrar somente por mount read-only em runtime;
- pinning e checksums aumentam reprodutibilidade, mas pins APT/digest Ubuntu
  ainda são limitações conhecidas.

## Limitações

- somente uma hora e dois instantes;
- sem verdade futura para skill;
- janela insuficiente para spin-up;
- SST fixa, adequada apenas ao desenho curto desta baseline;
- mesh grossa de ~240 km;
- somente quatro ranks, sem performance/escalabilidade;
- static sem campos Noah-MP;
- HDF5/netCDF serial;
- digest Ubuntu, versões APT e checksum HDF5 não estão totalmente fixados;
- Vtable validada para esta baseline ERA5, não para qualquer produto ECMWF;
- `q2` e massa/água permanecem diagnósticos corretamente classificados.

## Requisitos atendidos e conclusão

Todos os requisitos originais têm evidência ou uma classificação condicional
justificada. `REQ-CASE-003` é `NOT_APPLICABLE` porque o caso aprovado é
global e não usa LBC. As limitações de testes históricos e de alcance
científico são explícitas; nenhuma delas bloqueia o entregável original.

Portanto, **sim: o escopo original do projeto foi concluído**, requisito por
requisito conforme a tabela em [[requirements|requirements.md]].

## Extensões futuras

Previsão de cinco dias, ERA5 futuro para verification, atualização de
superfície/SST, spin-up, Noah-MP, mesh fina, performance/escalabilidade MPI,
mais ranks, METIS moderno, PT-Scotch, Apptainer/HPC, NetCDF4P/HDF5 paralelo e
eventual GPU são hipóteses futuras. Não reduzem o status da baseline.

Backlog e gates: [[future-experiments|future-experiments.md]].
Reprodução: [[../reproducibility/end-to-end|end-to-end.md]].
Material de apresentação: [[../portfolio/project-showcase|project-showcase.md]].
