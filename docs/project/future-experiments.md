# Experimentos técnicos futuros

## Projeto base concluído

`PROJECT_BASE_STATUS = COMPLETE`

A baseline aprovada — ERA5 → WPS → MPAS init → primeira hora → validação
científica — está concluída. Os itens abaixo são **extensões futuras**, não
requisitos faltantes. Nenhum item autoriza implementação: cada experimento
exige pesquisa oficial, proposta, decisão do usuário, ADR quando aplicável,
testes e documentação.

Os limites que permanecem ao lado do status completo são:

```text
forecast_skill = NOT_EVALUATED
spinup         = INSUFFICIENT_TEMPORAL_WINDOW
```

Eles descrevem o desenho de uma hora; não invalidam o escopo base.

## Extensões meteorológicas

### Previsão mais longa / cinco dias

**Hipótese:** avaliar estabilidade e evolução multidiária.

Exige decidir período, outputs, retenção, custo, critérios de falha e
estratégia de superfície. A baseline de uma hora não deve ser simplesmente
esticada com SST fixa sem essa decisão.

### ERA5 futuro para forecast verification

**Hipótese:** comparar a previsão com ERA5 ou outra verdade de referência.

Exige adquirir tempos futuros, definir interpolação mesh↔grade, variáveis,
métricas, baseline/climatologia e tolerâncias antes de observar os resultados.
Só esse experimento poderá mudar `forecast_skill`.

### Surface update / SST

**Hipótese:** atualizar SST, gelo marinho e campos superficiais durante
integrações mais longas.

Exige `sfc_update.nc`, cadência temporal, proveniência e teste de consumo. A
SST fixa é somente a configuração da hora concluída.

### Avaliação de spin-up

**Hipótese:** medir ajuste inicial em uma janela temporal suficiente.

Exige mais instantes, métricas e regiões/camadas definidas previamente. Só
então `spinup` pode deixar `INSUFFICIENT_TEMPORAL_WINDOW`.

### Noah-MP

**Hipótese:** avaliar outra física de superfície.

Exige gerar outro static com os campos Noah-MP; o static baseline com
`config_noahmp_static=false` não pode ser reutilizado artificialmente.

### Mesh mais fina

**Hipótese:** avaliar processos e estruturas não representados em ~240 km.

Exige nova mesh/caso, custo de WPS_GEOG/static/init/run, timestep adequado,
partições e critérios próprios. Não substitui silenciosamente x1.10242.

## Extensões HPC e particionamento

### Performance MPI, escalabilidade e mais ranks

**Hipótese:** medir strong/weak scaling e custo de I/O.

Um experimento justo fixa hardware, afinidade, carga concorrente, input,
namelist, outputs, warm-up e número de repetições. A execução de quatro ranks
prova integração, não speedup.

### METIS moderno

**Candidato:** METIS 5.2.1 com GKlib explicitamente fixada.

Comparar com 5.1.0 usando o mesmo grafo, número de partições e flags. Medir
validade, edge cut, balanceamento, contiguidade, tempo e memória. Não existe
evidência atual de superioridade.

### PT-Scotch

**Hipótese:** avaliar particionamento distribuído/online do MPAS.

Exige versão/compatibilidade aprovadas, rebuild separado e comparação com a
partição offline. A baseline METIS permanece válida.

### Apptainer/HPC

**Hipótese:** portar o ambiente para clusters onde Docker não é permitido.

Exige política do centro, MPI host/container, bind mounts, filesystem
paralelo, scheduler e validação numérica contra a baseline Docker.

### NetCDF4P / HDF5 paralelo

**Hipótese:** avaliar `PIO_IOTYPE_NETCDF4P` para casos em que o backend traga
benefício mensurável.

Exige mudar a estratégia HDF5/netCDF serial/paralela — gate protegido —,
reconstruir uma imagem alternativa e comparar correção e performance. O
caminho PnetCDF atual não é incompleto por não usar NetCDF4P.

### GPU

**Status:** somente se houver suporte aplicável, objetivo mensurável e
compatibilidade comprovada numa futura linha MPAS/física.

Não há evidência nesta baseline para prometer aceleração, portabilidade ou
benefício de GPU.

## Matriz do backlog

| Extensão | Pergunta principal | Nova entrada/decisão | Não pode alegar antes do teste |
|---|---|---|---|
| 5 dias | estabilidade multidiária | duração, superfície e outputs | estabilidade longa |
| ERA5 futuro | skill | verdade e métricas | acurácia/viés |
| surface update | evolução de SST/ice | arquivo/cadência | adequação de SST fixa |
| spin-up | tempo de ajuste | janela/métricas | spin-up concluído |
| Noah-MP | sensibilidade de superfície | novo static/física | superioridade |
| mesh fina | resolução | nova mesh/caso | maior qualidade |
| mais ranks | escalabilidade | hardware/protocolo | speedup |
| METIS 5.2.1 | particionamento | GKlib pinada | melhor partição |
| PT-Scotch | particionamento online | rebuild/ADR | menor custo |
| Apptainer | portabilidade HPC | cluster/MPI | equivalência |
| NetCDF4P | backend paralelo | HDF5/netCDF paralelo | I/O mais rápido |
| GPU | aceleração | suporte e hardware | ganho de performance |

## Regras para qualquer extensão

1. preservar a baseline concluída em outro caso/tag;
2. registrar fontes oficiais e data de verificação;
3. decidir versões e arquitetura antes de implementar;
4. definir métricas/tolerâncias antes de observar o resultado;
5. manter inputs e outputs grandes fora do Git;
6. comparar com o caso base sem reclassificar limitações retrospectivamente;
7. produzir learning note e relatório pré-commit.

O desenho do caso concluído está em
[[../cases/first-global-240km|first-global-240km.md]], e o resumo técnico em
[[completion-report|completion-report.md]].
