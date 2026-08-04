# Ciclo 0001 — bootstrap do workflow Codex

## Objetivo do ciclo

O ciclo 0001 cria a infraestrutura de governança, rastreabilidade,
documentação e aprendizado necessária para desenvolver o MPAS-ERA5 em etapas
auditáveis. Ele não adiciona PnetCDF, não altera versões, não reconstrói a
stack científica e não autoriza commit ou push.

Esse bootstrap resolve um problema anterior ao próximo componente técnico:
sem uma fonte clara de requisitos, versões, decisões e evidências, é fácil
compilar uma biblioteca e depois não saber exatamente por que aquela opção foi
escolhida, quais testes passaram ou como repetir o resultado.

## Estado encontrado antes da mudança

A inspeção de 2026-08-04 encontrou:

- branch `main` em `0f5fed1`, alinhada com `origin/main`;
- quatro commits no histórico completo disponível;
- zlib, HDF5, netCDF-C e netCDF-Fortran definidos no `Dockerfile`;
- documentação inicial curta em `README.md` e `docs/`;
- `AGENTS.md` e `.codex/config.toml` já existentes como arquivos locais não
  rastreados;
- ausência dos diretórios de governança e aprendizado criados por este ciclo;
- ausência de relatórios históricos de teste.

Essa distinção importa: `AGENTS.md` e `.codex/config.toml` integram o
bootstrap pretendido, mas não foram criados nem modificados neste ciclo. Eles
foram preservados como trabalho preexistente do usuário.

## Por que `AGENTS.md` existe

`AGENTS.md` é o contrato operacional entre o projeto, o usuário e agentes de
desenvolvimento. Ele transforma preferências importantes em regras
reexecutáveis:

- missão científica e educacional;
- fontes que devem ser lidas antes de cada ciclo;
- prioridade de fontes oficiais;
- decisões que exigem aprovação;
- definição mínima de validação;
- documentos que cada tipo de mudança afeta;
- obrigação de learning note;
- relatório pré-commit e gates de commit/push;
- proibição de credenciais, dados grandes e operações destrutivas.

Sem esse arquivo, as mesmas regras dependeriam da memória de uma conversa. Uma
conversa pode ficar indisponível, ser resumida ou não acompanhar outro agente.
Um arquivo versionado viaja com o repositório e pode ser revisado como qualquer
outro artefato.

`AGENTS.md` não substitui decisão humana. Ele diz quando parar, pesquisar e
pedir aprovação; não concede ao agente autoridade para escolher versões ou
estratégias científicas.

## Por que `.codex/config.toml` existe

O arquivo local configura como Codex interage com este workspace:

- `approval_policy = "on-request"` permite solicitar aprovação quando uma
  ação ultrapassa permissões normais;
- `sandbox_mode = "workspace-write"` restringe escrita ao workspace
  autorizado;
- `web_search = "live"` permite pesquisa atual quando ela for necessária;
- `ignore_default_excludes = false` preserva exclusões padrão do ambiente de
  shell.

O arquivo trata de **mecanismo e segurança de execução**. `AGENTS.md` trata de
**processo, ciência e governança do projeto**. Um não substitui o outro.

No ciclo 0001, a configuração já existia e foi apenas lida para explicar seu
papel. Nenhuma permissão foi ampliada no arquivo.

## Por que separar `docs/` e `learning/`

`docs/` registra o sistema:

- requisitos;
- estado atual;
- workflow;
- arquitetura e localização de arquivos;
- fontes e versões;
- decisões;
- testes e evidências.

`learning/` registra a compreensão:

- conceitos necessários;
- explicação dos comandos;
- raciocínio de diagnóstico;
- interpretação de testes;
- trade-offs;
- o que o usuário deve aprender por mudança.

Misturar os dois objetivos tende a criar um documento que é longo demais para
consultar como referência e curto demais para ensinar. A separação permite que
`current-state.md` continue factual e conciso enquanto `baseline.md`
explica em profundidade Docker, compilação, MPI e a cadeia netCDF.

A separação não autoriza divergência: learning notes devem apontar para o
estado, fontes, ADRs e matriz que sustentam suas afirmações.

## Por que usar ADR

Um Architectural Decision Record preserva:

- o contexto que tornou uma decisão necessária;
- alternativas razoáveis;
- a opção aprovada;
- consequências e riscos;
- evidências de validação;
- relação com requisitos e fontes.

Por exemplo, o diff de um futuro `Dockerfile` pode mostrar
`--enable-parallel`, mas não mostra por que a estratégia paralela foi
preferida, quais opções foram descartadas nem qual impacto ela tem sobre MPI e
netCDF. O ADR mantém esse raciocínio disponível.

Este ciclo cria somente a política e o template em
`docs/decisions/README.md`. Nenhum ADR científico foi inventado
retroativamente, porque o histórico não contém evidência suficiente para
reconstruir todas as decisões anteriores.

## Por que criar uma matriz de validação

“Compilou” cobre apenas uma parte do risco. Um componente pode:

- compilar e falhar na suite upstream;
- passar a suite na árvore de build e instalar arquivos incompletos;
- instalar e não ser descoberto por uma aplicação;
- ligar e carregar uma biblioteca diferente no runtime;
- executar sem produzir resultado fisicamente coerente.

A matriz separa:

1. upstream test;
2. smoke test;
3. integration test;
4. status;
5. evidência.

Ela também impede um erro de documentação: tratar `make check` escrito no
`Dockerfile` como se fosse um relatório de uma execução comprovada. Para
netCDF-C e netCDF-Fortran, o comando está na receita, mas os logs históricos não
estão no Git. O status registra exatamente essa diferença.

Para componentes futuros, a matriz registra testes planejados sem marcar
nenhum deles como executado.

## Por que registrar versões e fontes

Uma versão isolada não garante reprodução. Também precisamos saber:

- de qual fonte veio o artefato;
- quando a fonte foi verificada;
- qual checksum identifica o conteúdo;
- qual stack deve ser compatível;
- se a versão foi aprovada ou ainda está a decidir.

`versions.lock.md` é um lock documental: fixa o que o repositório realmente
adotou e deixa PnetCDF, PIO2, METIS, WPS e MPAS como `a decidir`.
`source-registry.md` classifica requisitos, documentação oficial, releases,
fontes secundárias e troubleshooting.

As URLs de releases existentes foram copiadas literalmente do `Dockerfile` e
marcadas como não revalidadas externamente neste ciclo. Nenhuma URL nova foi
inventada. Como nenhuma dependência foi introduzida ou atualizada, não houve
pesquisa de versão que pudesse ultrapassar o escopo aprovado.

## Arquivos adicionados neste ciclo

- `docs/project/requirements.md`;
- `docs/project/current-state.md`;
- `docs/project/development-workflow.md`;
- `docs/references/source-registry.md`;
- `docs/references/versions.lock.md`;
- `docs/decisions/README.md`;
- `docs/testing/validation-matrix.md`;
- `learning/README.md`;
- `learning/baseline.md`;
- `learning/commits/0001-bootstrap-codex-workflow.md`.

Diretórios também criados:

- `docs/project/`;
- `docs/references/`;
- `docs/decisions/`;
- `docs/testing/`;
- `learning/commits/`;
- `scripts/validate/`;
- `scripts/codex/`.

`scripts/validate/` e `scripts/codex/` permanecem vazios. Git não rastreia
diretórios vazios; eles existem no worktree, mas só entrarão em um commit
quando um futuro ciclo criar arquivos aprovados.

## Arquivos modificados neste ciclo

- `docs/README.md`: links Obsidian para os novos documentos;
- `docs/architecture/project-graph.md`: estrutura, responsabilidades e fluxo
  de governança; o fence de código que estava aberto também foi fechado;
- `README.md`: link público mínimo para `learning/`.

`Dockerfile` e `docs/build/scientific-stack.md` foram lidos, mas não
alterados.

## Comandos importantes e como funcionam

### Inspeção Git

```sh
git status --short --branch
git log --oneline -10
git log --reverse -p --format=fuller
git branch -vv
```

- `status` mostra branch e mudanças locais que devem ser preservadas;
- `log --oneline -10` fornece orientação rápida;
- `log --reverse -p` percorre todos os quatro commits na ordem histórica e
  mostra patches, permitindo distinguir o que foi realmente construído;
- `branch -vv` mostra o commit atual e a relação com a branch remota.

### Inventário e leitura

```sh
rg --files
find . -path ./.git -prune -o -maxdepth 4 -printf '...'
sed -n '1,260p' ARQUIVO
```

- `rg --files` lista rapidamente arquivos relevantes;
- `find` inclui diretórios vazios e tamanhos, ignorando o conteúdo interno de
  `.git`;
- `sed -n` imprime o intervalo solicitado sem modificar o arquivo.

### Criação e edição

```sh
mkdir -p docs/project ... scripts/codex
apply_patch
```

- `mkdir -p` cria a árvore solicitada e não falha quando uma parte já existe;
- `apply_patch` aplica mudanças explícitas e revisáveis, evitando regravar
  silenciosamente arquivos inteiros já existentes.

### Revisão e validação

```sh
git diff -- README.md docs/README.md docs/architecture/project-graph.md
git diff --exit-code -- Dockerfile docs/build/scientific-stack.md
rg -n "[[:blank:]]+$" README.md docs learning AGENTS.md .codex/config.toml Dockerfile
git diff --check
git status
```

- o primeiro `git diff` permite revisar somente arquivos rastreados
  modificados;
- `--exit-code` retorna zero quando os arquivos científicos selecionados
  permanecem idênticos ao `HEAD`;
- a busca por whitespace final complementa `git diff --check` para arquivos
  ainda não rastreados;
- `git diff --check` detecta erros de whitespace no diff rastreado;
- o `status` final define exatamente o escopo que seria submetido.

## Validações executadas

Resultados finais do ciclo:

- inspeção integral dos arquivos exigidos: concluída;
- inspeção do histórico completo de quatro commits: concluída;
- inventário de arquivos, diretórios vazios e tamanhos: concluído;
- revisão do diff de `README.md`, `docs/README.md` e
  `project-graph.md`: concluída;
- confirmação por `git diff --exit-code` de que `Dockerfile` e
  `docs/build/scientific-stack.md` não mudaram: aprovada;
- existência de todos os caminhos solicitados: aprovada;
- links relativos Markdown e Obsidian importantes: aprovados;
- pares de fences Markdown nos arquivos novos/modificados: aprovados;
- busca por whitespace final, incluindo arquivos ainda não rastreados: nenhuma
  ocorrência;
- `git diff --check`: aprovado, sem saída;
- varredura heurística por padrões fortes de segredos: nenhuma ocorrência;
- busca por arquivos maiores que 1 MiB, dados netCDF/GRIB e arquivos sensíveis
  comuns: nenhuma ocorrência;
- `git status --short --branch`: executado e compatível com o escopo
  documental esperado.

O verificador identificou um fence preexistente sem fechamento em
`docs/build/scientific-stack.md`. O arquivo é idêntico ao `HEAD` e ficou
deliberadamente fora deste ciclo; a ocorrência é dívida técnica, não falha
introduzida pelos novos documentos.

Nenhuma suite científica, build Docker ou teste de dependência foi executado:
este ciclo não altera a stack e não deve fabricar novos resultados científicos.

## Falhas e limitações encontradas

### Inicialização do sandbox

Os primeiros comandos somente leitura falharam porque o helper de sandbox não
conseguiu configurar loopback (`RTM_NEWADDR: Operation not permitted`). As
mesmas inspeções foram executadas fora do sandbox somente após aprovação,
mantendo o escopo de leitura ou de escrita dentro do workspace.

### Verificador auxiliar indisponível

A primeira versão da checagem de links foi escrita para Ruby, mas o executável
`ruby` não existe no host. Nenhum pacote foi instalado apenas para essa
validação. A mesma lógica foi refeita com o Perl já disponível e passou depois
de ignorar corretamente exemplos dentro de blocos de código.

### API Docker sem permissão

`docker image ls` e `docker container ls -a` falharam com permissão negada
em `/var/run/docker.sock`. Não foram alteradas permissões, grupos, containers
ou imagens. Como consequência, o estado local do Docker não foi usado como
evidência de validação.

### Evidência histórica insuficiente

O `Dockerfile` contém `make check` para as duas bibliotecas netCDF, mas o
repositório não guarda a saída desses testes. zlib/HDF5 também não invocam
suite upstream na receita. A matriz registra a lacuna sem reexecutar ou
reconstruir a stack neste ciclo.

### Fence preexistente em documentação científica

`docs/build/scientific-stack.md` contém um fence de abertura de bloco textual
sem fechamento desde o commit atual. Como o documento científico não foi afetado pela
implementação de governança, ele não foi modificado silenciosamente. A correção
deve entrar em um ciclo documental pequeno e explícito.

### Diretórios vazios

Os dois novos diretórios de scripts não aparecem em `git status`, porque Git
rastreia arquivos, não diretórios. Adicionar `.gitkeep` ou arquivos vazios
apenas para forçar rastreamento aumentaria o escopo sem valor didático. O
trade-off foi documentar a limitação e aguardar scripts reais.

## Trade-offs e decisões do ciclo

- Os requisitos receberam IDs estáveis, enquanto escolhas de implementação
  foram colocadas em seção separada.
- O lock registra versões já materializadas, mas não chama de “validado” o que
  não tem evidência de teste.
- Não foi criado ADR retroativo; a ausência de contexto histórico foi
  preservada como lacuna.
- O README raiz recebeu somente um link para aprendizado, porque a nova área é
  parte visível da missão educacional.
- O documento da stack científica não mudou, pois nenhuma camada científica
  mudou.
- O registro de fontes distingue URL presente no build de URL revalidada
  externamente.

## Como a estrutura melhora reprodutibilidade

Antes de um ciclo técnico, o agente agora pode reconstruir:

```text
requisito
  → fonte oficial
    → versão aprovada
      → ADR, se necessário
        → implementação
          → matriz/evidência
            → estado atual
              → explicação de aprendizado
```

Isso reduz decisões implícitas, impede que trabalho futuro seja marcado como
concluído e oferece um caminho para auditar por que um artefato existe.

## O que o usuário deve aprender

Ao final deste ciclo, o usuário deve conseguir explicar:

1. a diferença entre requisito e decisão;
2. por que versão adotada e componente validado são estados diferentes;
3. por que uma fonte precisa de classe, finalidade e data;
4. quando uma decisão merece ADR;
5. por que upstream, smoke e integração respondem perguntas diferentes;
6. como `docs/` e `learning/` se complementam;
7. por que commit e push continuam atrás de aprovação mesmo após testes.

## Mensagem de commit proposta

```text
docs: bootstrap Codex governance workflow
```

Essa mensagem é apenas proposta. O ciclo deve parar no relatório pré-commit e
aguardar aprovação explícita.
