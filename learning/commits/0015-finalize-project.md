# Ciclo 0015 — Consolidar e finalizar o projeto

## O que mudou

O ciclo transformou uma pipeline tecnicamente funcional em um projeto
concluído, navegável, reproduzível, auditável e apresentável:

- auditou todos os requisitos originais;
- fechou smokes baratos da stack instalada;
- criou um validador final único;
- escreveu o guia operacional end-to-end;
- consolidou README, grafo, relatório técnico e portfólio;
- auditou fontes, versões, links, Git e arquivos grandes;
- separou explicitamente projeto base de extensões futuras.

Nenhum dado meteorológico novo foi adquirido e nenhum forecast foi
reexecutado.

## Quando um projeto está “concluído”?

“Concluído” não significa “sem limitações” nem “todas as perguntas possíveis
respondidas”. Um projeto termina quando:

1. o escopo aprovado está explícito;
2. cada requisito tem evidência ou classificação justificada;
3. entradas, comandos e outputs podem ser reconstruídos;
4. testes cobrem as camadas relevantes;
5. limitações não são escondidas;
6. outra pessoa consegue navegar, executar, estudar e avaliar;
7. extensões futuras não são confundidas com dívida do escopo base.

Neste projeto, `PROJECT_BASE_STATUS = COMPLETE` coexiste corretamente com:

```text
forecast_skill = NOT_EVALUATED
spinup         = INSUFFICIENT_TEMPORAL_WINDOW
```

A primeira frase responde ao contrato do projeto. As outras respondem a
perguntas científicas que o desenho de uma hora não avaliou.

## Requisito não é experimento futuro

Um requisito é uma obrigação do escopo. Uma extensão é uma nova hipótese.

Exemplos:

- gerar `init.nc` é requisito e possui evidência no ciclo 0012;
- executar o caso aprovado é requisito e possui evidência no ciclo 0013;
- validar sanity físico é requisito e possui evidência no ciclo 0014;
- prever cinco dias é extensão;
- medir speedup MPI é extensão;
- usar Noah-MP ou mesh fina é extensão;
- avaliar skill requer um experimento futuro com verdade de referência.

Chamar extensões de “pendências” faria o projeto parecer eternamente
inacabado. Chamar requisito sem evidência de “concluído” produziria o erro
oposto.

## Rastreabilidade

Rastreabilidade liga:

```text
requisito → decisão → implementação → teste → evidência → limitação
```

A tabela final em `docs/project/requirements.md` usa seis colunas:

- ID;
- requisito;
- status;
- evidência;
- limitação;
- ciclo que o satisfez.

Os status evitam ambiguidades:

- `SATISFIED`;
- `SATISFIED_WITH_LIMITATION`;
- `NOT_APPLICABLE`;
- `FUTURE_EXTENSION`.

`REQ-CASE-003` é um bom exemplo: LBC é obrigatório somente quando aplicável.
O caso aprovado é global; portanto `NOT_APPLICABLE` é mais correto do que
“não implementado” ou uma condição lateral artificial.

## Reprodutibilidade e provenance

Reprodutibilidade responde “como refazer?”. Provenance responde “de onde veio
e qual byte/versão foi usado?”. Uma depende da outra.

O projeto preserva:

- URLs e classes de fonte;
- tags, commits e versões;
- checksums upstream ou explicitamente locais;
- requests ERA5;
- namelists/streams;
- comandos e número de ranks;
- hashes de artefatos locais nos manifestos;
- imagens e dependências separadas;
- validações e limitações.

O guia `docs/reproducibility/end-to-end.md` organiza esses contratos em
fases. Ele não copia learning notes inteiras; aponta para o aprofundamento.

## Validação em camadas

Uma aplicação científica possui várias classes de correção:

1. **build:** compilou;
2. **instalação:** headers, módulos, bibliotecas e executáveis existem;
3. **smoke:** a interface instalada executa um caso mínimo;
4. **integração:** a camada troca dados com sua dependência/consumidor;
5. **funcional:** o programa completa o caso;
6. **numérica:** outputs não estão corrompidos ou explosivos;
7. **científica:** checks físicos sustentados passam;
8. **skill:** forecast é comparado a uma verdade adequada.

O ciclo fechou a evidência barata que faltava:

```text
zlib compress/uncompress
  ↓
HDF5 dataset + DEFLATE
  ↓
netCDF-C NetCDF-4 + deflate
  ↓
netCDF-Fortran module + netCDF-C/HDF5/zlib
```

Isso não reescreve o passado: suites upstream zlib/HDF5 não foram executadas,
logs históricos de `make check` netCDF não foram preservados e o checksum
HDF5 continua ausente. A interface instalada está comprovada; a dívida
histórica permanece documentada.

## Ciência versus correção de software

`atmosphere_model` terminar com código zero não prova um forecast bom.

O projeto separa:

- `functional_validation=PASS`: o pipeline e o relógio funcionaram;
- `numerical_sanity=PASS`: arquivos/finitude/estado mínimo estão íntegros;
- `scientific_sanity=PASS`: critérios físicos definidos passaram;
- `forecast_skill=NOT_EVALUATED`: não havia ERA5/observação em 01 UTC;
- `spinup=INSUFFICIENT_TEMPORAL_WINDOW`: dois instantes não medem ajuste.

Massa seca de ~`-1,6e-11` relativa é report-only porque nenhuma tolerância
oficial foi definida. `q2` negativo é report-only e source-aware. Escolher um
threshold depois de ver o resultado apenas para declarar PASS seria
retrospective validation.

## Documentação executiva versus operacional

Documentos diferentes servem a públicos diferentes:

- `README.md`: explica o projeto em poucos minutos;
- `completion-report.md`: sustenta tecnicamente a conclusão;
- `end-to-end.md`: diz exatamente como reproduzir;
- `project-graph.md`: diz onde encontrar cada responsabilidade;
- `validation-matrix.md`: prova quais testes passaram;
- ADRs: explicam por que decisões foram tomadas;
- learning notes: ensinam conceitos, falhas e raciocínio;
- `project-showcase.md`: adapta o resultado para portfólio/entrevista.

Misturar tudo num único README o tornaria ruim para todos os públicos.

## Por que dados grandes ficam fora do Git

Git é excelente para mudanças textuais e objetos pequenos; é inadequado para
gigabytes de GRIB, WPS_GEOG e NetCDF que mudam como blobs completos.

O padrão adotado é:

```text
Git: script + request + configuração + checksum + documentação
storage local: dados baixados + intermediates + outputs + logs
```

Isso preserva revisão, clone e história sem perder reprodutibilidade. O
arquivo `.gitignore` é uma barreira, não a única defesa: validadores também
checavam `git check-ignore` e `git ls-files`.

## Docker: aprendizado transferível

### Imagem e container

A imagem guarda o ambiente. O container é uma execução descartável dessa
imagem. Reusar uma imagem validada preserva a baseline; recriar containers é
barato e esperado.

### Layers e cache

Layers evitam recompilar a stack inteira. Porém uma linha `CACHED` não prova
que uma interface continua funcional; os smokes instalados fornecem essa
evidência.

### Separação de responsabilidades

Um container “faz tudo” misturaria credencial CDS, compiladores, MPAS e stack
Python. O projeto usa:

- científico;
- aquisição;
- análise.

Essa separação reduz dependências, superfície de risco e acoplamento.

### Mounts, UID/GID e runtime restrito

Bind mounts colocam dados fora da imagem. Inputs read-only impedem mutação.
UID/GID do host evita outputs root-owned. `--read-only`, `--network none`,
`--cap-drop ALL` e `no-new-privileges` tornam o contrato observável.

Secrets entram por mount read-only somente em runtime. Dados científicos
grandes não pertencem à imagem e não invalidam cache de build.

## Arquivos criados e modificados

Principais criações:

- `scripts/validate/core-libraries.sh`;
- `scripts/validate/final-project.sh`;
- quatro fontes em `tests/smoke/`;
- `docs/reproducibility/end-to-end.md`;
- `docs/project/completion-report.md`;
- `docs/portfolio/project-showcase.md`;
- esta learning note.

Principais consolidações:

- `README.md`;
- `docs/README.md`;
- `docs/architecture/project-graph.md`;
- requisitos, estado, matriz, fontes, versões e backlog futuro.

## Comandos importantes

### Smoke das bibliotecas-base

```sh
./scripts/validate/core-libraries.sh
```

O script monta o repositório read-only, usa tmpfs para compilação/outputs,
desliga rede e compila C/Fortran contra `/opt/mpas`. Os arquivos gerados são
efêmeros.

### Validação final

```sh
./scripts/validate/final-project.sh
```

O preflight confirma imagens e artefatos canônicos. Em seguida, reusa
validadores existentes; não duplica regras de mesh/static/ERA5/WPS/init/run.
Ele falha com instrução de reprodução quando uma entrada local está ausente.

### Auditorias

```sh
git diff --check
git status --short --branch
git status --ignored --short
git ls-files
```

Esses comandos detectam whitespace, escopo do diff, dados ignorados e
conteúdo efetivamente rastreado.

## Testes executados e interpretação

- `bash -n` nos novos scripts: sintaxe shell válida;
- `core-libraries.sh`: ambiente/zlib/HDF5/netCDF-C/Fortran PASS;
- PnetCDF e PIO no contexto da imagem final: PASS;
- mesh/static/ERA5/WPS/init/atmosphere: PASS;
- análise científica: PASS, skill/spin-up preservados;
- `final-project.sh`: `project_validation=PASS`;
- auditoria de links, órfãos, grandes arquivos, extensões científicas e
  secrets: executada no fechamento do ciclo;
- `git diff --check`: deve permanecer limpo no relatório pré-commit.

Um PASS do validador final significa que o estado local materializado é
coerente com a baseline. Não significa que alguém possa clonar sem baixar os
dados externos; para isso existe o guia end-to-end.

## Falhas encontradas

O primeiro smoke tentou compilar no mount `/workspace` read-only. A correção
foi mudar o working directory para o tmpfs `/validation-output`, preservando
o isolamento.

A chamada Fortran `nf90_def_var_deflate` foi inicialmente escrita com
argumentos lógicos. A interface 4.6.3 instalada exige inteiros 0/1. Depois da
correção, `-Werror` detectou uma variável não usada; ela foi removida em vez
de relaxar o compilador. O passe final aprovou todas as interfaces.

Essas falhas pertenciam aos novos testes, não à stack científica.

## Trade-offs e decisões

- não reconstruir a stack evitou reabrir uma arquitetura validada;
- smokes pequenos fecharam evidência barata sem fingir uma suíte upstream;
- o validador final prioriza artefatos existentes e não downloads;
- três figuras no README contam a história sem transformar a página em
  galeria;
- o relatório técnico retém detalhes; o README oferece navegação;
- o status COMPLETE preserva as limitações ao lado, não em nota de rodapé.

Nenhum novo ADR foi necessário: não houve nova decisão arquitetural, versão,
física, mesh, período ou estratégia de I/O.

## Transformar trabalho técnico em portfólio

Um bom portfólio comunica:

1. problema;
2. arquitetura;
3. decisões difíceis;
4. resultado concreto;
5. evidência;
6. limites;
7. competências transferíveis.

Evite números inexistentes. O projeto não mede speedup nem forecast accuracy.
Ele demonstra HPC, I/O científico, containerização, paralelismo, análise de
bugs/edge cases, meteorologia numérica e documentação reproduzível.

## Competências transferíveis para outros projetos HPC

- build e pinning de bibliotecas científicas;
- diagnóstico de linkagem/runtime;
- MPI e MPI-IO por backend;
- formatos científicos e validação de dados;
- particionamento de grafos;
- isolamento e segurança em containers;
- provenance e manifests;
- desenho de smoke/integration/scientific tests;
- separação entre correção numérica e validade científica;
- documentação por público;
- governança de decisões e Git history auditável.

## O que o leitor deve aprender

Ao final, o leitor deve conseguir:

- explicar por que o projeto está concluído apesar de ter extensões futuras;
- auditar um requisito até sua evidência;
- distinguir reproducibility de provenance;
- desenhar validação em camadas;
- separar software correctness de scientific skill;
- manter dados grandes fora do Git;
- apresentar um projeto HPC sem exagerar conclusões.
