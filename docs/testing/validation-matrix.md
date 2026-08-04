# Matriz de validação

## Como interpretar

Esta matriz separa quatro perguntas:

1. a suite do projeto upstream passou?
2. a instalação funciona em um caso mínimo?
3. o componente integra com a camada anterior?
4. onde está a evidência persistida do resultado?

**Planejado** não significa executado. **Definido no Dockerfile** significa que
o comando faz parte da receita e deverá falhar o build se retornar erro, mas
não prova que a execução ocorreu nesta máquina nem preserva o resultado. Um
componente só poderá receber status validado quando comando, resultado e
evidência estiverem registrados.

Última revisão: **2026-08-04**.

## Ambiente e stack existente

| Componente | Upstream test | Smoke test | Integration test | Status | Evidência |
|---|---|---|---|---|---|
| Ubuntu 24.04 + GNU | Não se aplica como suite única; validar os pacotes instalados | Planejado: registrar versões de `gcc`, `gfortran`, `make` e ferramentas essenciais | Planejado: compilar e executar programas mínimos C e Fortran dentro da imagem | Ambiente definido; resultado persistido ausente | [`Dockerfile`](../../Dockerfile) e [`current-state.md`](../project/current-state.md) |
| OpenMPI | Planejado: usar os testes oficiais aplicáveis à versão de pacote adotada | Planejado: consultar versão e executar Hello World com mais de um rank | Planejado: compilar com wrappers MPI e ligar contra a stack aprovada | Implementação definida; versão/testes não fixados | pacotes no [`Dockerfile`](../../Dockerfile); nenhum relatório histórico |
| zlib 1.3.2 | Não executado no `Dockerfile`; identificar e executar a suite oficial da release | Planejado: compilar/rodar compressão e descompressão mínima contra `/opt/mpas` | Planejado: confirmar que o HDF5 usa a zlib do prefixo | Build definido; validação incompleta | download, hash, build e install no [`Dockerfile`](../../Dockerfile); sem log de resultado |
| HDF5 1.14.6 | Não executado no `Dockerfile`; confirmar o comando upstream da release antes de executar | Planejado: consultar wrappers/configuração e criar/ler arquivo HDF5 mínimo em C e Fortran | Planejado: verificar zlib e fornecer HDF5 ao netCDF-C | Build definido; validação incompleta | configuração e install no [`Dockerfile`](../../Dockerfile); sem checksum ou relatório |
| netCDF-C 4.10.1 | `make check` está definido; resultado histórico não preservado | Planejado: `nc-config` e programa C que cria e relê um arquivo mínimo | Planejado: verificar linkagem com HDF5/zlib do prefixo | Teste exigido pela receita; smoke/integração e evidência ausentes | [`Dockerfile`](../../Dockerfile); nenhum relatório versionado |
| netCDF-Fortran 4.6.3 | `make check` está definido; resultado histórico não preservado | Planejado: `nf-config` e programa Fortran que cria e relê um arquivo mínimo | Planejado: verificar módulos, linkagem com netCDF-C e runtime do prefixo | Teste exigido pela receita; smoke/integração e evidência ausentes | [`Dockerfile`](../../Dockerfile); nenhum relatório versionado |

## Componentes futuros

| Componente | Upstream test | Smoke test | Integration test | Status | Evidência |
|---|---|---|---|---|---|
| PnetCDF | Planejado: suite oficial da versão que vier a ser aprovada | Planejado: consulta de configuração e I/O paralelo mínimo | Planejado: MPI + PnetCDF usando compiladores e bibliotecas do ambiente | Não implementado; versão a decidir | [[../references/versions.lock|versions.lock.md]] |
| PIO2 | Planejado: suite oficial da versão aprovada | Planejado: exemplo mínimo do upstream | Planejado: MPI + backend(s) aprovado(s), incluindo PnetCDF/netCDF quando aplicável | Não implementado; versão a decidir | [[../references/versions.lock|versions.lock.md]] |
| METIS | Planejado: suite ou testes oficiais disponíveis para a release | Planejado: executar particionamento mínimo de um grafo conhecido | Planejado: verificar consumo pelo build/fluxo do MPAS aprovado | Não implementado; versão a decidir | [[../references/versions.lock|versions.lock.md]] |
| WPS/ungrib | Planejado: testes oficiais disponíveis para a release | Planejado: executar `ungrib` sobre amostra pequena e controlada | Planejado: transformar campos ERA5 aprovados para o formato consumido pelo `init_atmosphere` | Não implementado; versão a decidir | [[../project/requirements|REQ-PRE-001]] |
| MPAS `init_atmosphere` | Planejado: testes upstream disponíveis para a release | Planejado: validar inicialização mínima na mesh aprovada | Planejado: WPS/ERA5 + mesh → `static.nc`, `init.nc` e LBC quando aplicável | Não implementado; versão a decidir | [[../project/requirements|REQ-MPAS-001]] |
| MPAS `atmosphere` | Planejado: testes upstream disponíveis para a release | Planejado: integração curta e determinística do caso aprovado | Planejado: ler artefatos do `init_atmosphere` e produzir saída MPAS | Não implementado; versão a decidir | [[../project/requirements|REQ-MPAS-002]] |
| ERA5 | Não se aplica como suite de software única; validar cliente e esquema segundo fontes oficiais | Planejado: baixar uma amostra mínima sem registrar credenciais e conferir metadados/unidades | Planejado: amostra ERA5 → `ungrib` → `init_atmosphere` | Período/área/variáveis a decidir | [[../project/requirements|REQ-DATA-001]] |
| Mesh pública inicial | Validar com ferramentas/recomendações oficiais da release MPAS escolhida | Planejado: conferir dimensões, conectividade e metadados da mesh | Planejado: mesh aceita pelo `init_atmosphere` e pelo caso curto | Mesh a decidir | [[../project/requirements|REQ-MESH-001]] |
| `static.nc` | Não se aplica | Planejado: inspecionar dimensões, variáveis, atributos, valores ausentes e faixas plausíveis | Planejado: arquivo aceito na geração do estado inicial | Não gerado | [[../project/requirements|REQ-CASE-001]] |
| `init.nc` | Não se aplica | Planejado: verificar estrutura, completude, tempo e faixas físicas iniciais | Planejado: arquivo aceito por `atmosphere` em execução curta | Não gerado | [[../project/requirements|REQ-CASE-002]] |
| LBC | Não se aplica | Planejado somente para área limitada: verificar sequência temporal, cobertura e continuidade | Planejado somente quando aplicável: execução curta consome todos os contornos | Condicional; estratégia do caso a decidir | [[../project/requirements|REQ-CASE-003]] |
| Primeira execução | Não se aplica | Planejado: execução curta termina sem erro e produz logs/saídas esperados | Planejado: pipeline completo reproduz a execução a partir das entradas registradas | Não executada | [[../project/requirements|REQ-RUN-001]] |
| Validação física | Não se aplica | Planejado: checagens de sanidade, conservação, extremos, NaN/Inf e coerência temporal/espacial | Planejado: comparar entradas, estado inicial e evolução conforme critérios aprovados | Critérios quantitativos a decidir | [[../project/requirements|REQ-VAL-001]] |

## Evidência mínima de um resultado futuro

Cada atualização de status deve registrar:

- componente e versão;
- imagem/commit usado;
- comando completo;
- data e ambiente;
- código de saída;
- resumo contável (`passed`, `failed`, `skipped`) quando fornecido;
- artefato ou log pequeno e seguro;
- interpretação do resultado e limitações;
- teste de integração associado.

Não versionar credenciais, ERA5 volumoso, saídas MPAS grandes ou logs com
segredos. Resultados resumidos devem ser suficientes para auditar o teste e
indicar onde artefatos externos controlados podem ser encontrados.
