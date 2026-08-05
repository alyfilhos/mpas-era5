# Experimentos técnicos futuros

Este documento é um backlog de hipóteses que podem merecer ciclos próprios.
Ele não é um roadmap aprovado, não altera as versões adotadas e não autoriza
implementação. Cada experimento continua sujeito a pesquisa, decisão do usuário,
ADR quando aplicável e validação reproduzível.

## Graph partitioning

### METIS 5.2.1 + pinned GKlib

**Status:** futuro / não implementado

**Hipótese:** avaliar se a linha moderna do METIS traz benefício mensurável sem
comprometer a compatibilidade com as malhas e o workflow do MPAS.

A release oficial METIS 5.2.1 existe no repositório moderno
`KarypisLab/METIS`. Diferentemente do tarball 5.1.0 adotado como baseline, ela
espera a GKlib como dependência externa. Um experimento deverá fixar
explicitamente uma release ou commit da GKlib, registrar a compatibilidade entre
as duas revisões e verificar a integridade de ambos os artefatos. `gpmetis`
continua sendo o executável offline de interesse.

Não há evidência neste ciclo de que 5.2.1 seja melhor para MPAS. A comparação
deve usar exatamente o mesmo `graph.info`, número de partições, opções, hardware
e método de medição usados com 5.1.0. Deve comparar pelo menos:

- validade estrutural da partição;
- `edge cut`;
- balanceamento e contiguidade;
- tempo e, quando viável, memória do particionamento;
- compatibilidade com grafos derivados de meshes MPAS.

### PT-Scotch online partitioning

**Status:** futuro / não implementado

**Hipótese:** avaliar o valor do particionamento distribuído/online para
workflows que variam frequentemente o número de ranks.

A documentação atual do MPAS registra particionamento online desde MPAS v8.4.0.
Ele requer que o MPAS seja construído com PT-Scotch, atualmente documentado com
versão mínima 7.0.8 e compatibilidade com índices de 32 bits. O particionamento
pode ser criado em runtime e salvo para reutilização. Isso pode evitar a etapa
manual de pré-computar `graph.info.part.N` em alguns workflows; o fluxo offline
com METIS continua suportado.

Este ciclo não instala PT-Scotch, não compila MPAS e não mede particionamento
online. A hipótese só poderá ser testada depois que existirem uma mesh e uma
configuração MPAS aprovadas.

### Comparative experiment

Comparação futura proposta, ainda não aprovada para execução:

```text
METIS 5.1.0 offline
vs METIS 5.2.1 offline + GKlib fixada
vs PT-Scotch online
```

Para uma comparação justa, devem permanecer constantes:

- a mesma mesh e a mesma representação `graph.info` quando o método a usar;
- o mesmo número de partições/ranks e os mesmos critérios de contiguidade;
- a mesma definição de peso de vértices e arestas;
- a mesma plataforma, recursos, afinidade e carga concorrente;
- a mesma versão e configuração do MPAS para medições integradas;
- entradas, namelists, duração do caso e critérios de validação;
- número de repetições, warm-up e método de coleta das métricas.

Métricas candidatas:

- tempo e memória do particionamento;
- validade, balanceamento e `edge cut` da partição;
- comunicação inferida e depois observada entre ranks;
- tempo total de inicialização e de execução do MPAS;
- escalabilidade com o número de ranks;
- conveniência operacional e capacidade de reutilização;
- reprodutibilidade da partição e do procedimento.

O resultado do fixture artificial do ciclo 0004 não deve ser usado para
concluir desempenho em uma mesh MPAS real.
