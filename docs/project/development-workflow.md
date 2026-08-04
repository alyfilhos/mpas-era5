# Workflow de desenvolvimento assistido

## Princípio

Cada ciclo deve produzir uma mudança pequena, verificável, ensinável e
rastreável. Compilar não é sinônimo de instalar corretamente, e instalar não é
sinônimo de integrar ou validar cientificamente.

## Sequência obrigatória

```text
inspection
    ↓
requirements
    ↓
official research
    ↓
proposal
    ↓
user decision
    ↓
implementation
    ↓
upstream test
    ↓
smoke test
    ↓
integration test
    ↓
review
    ↓
documentation
    ↓
learning note
    ↓
pre-commit report
    ↓
user approval
    ↓
commit
    ↓
push
```

Nenhuma seta pode ser omitida. Quando uma etapa não se aplica, o relatório do
ciclo deve dizer por que ela não se aplica, em vez de simplesmente escondê-la.

## Entradas obrigatórias de todo ciclo

Antes de editar:

1. executar `git status` e `git log --oneline -10`;
2. ler `AGENTS.md`;
3. ler os três documentos de `docs/project/`;
4. ler `docs/architecture/project-graph.md`;
5. ler `docs/references/source-registry.md` e `versions.lock.md`;
6. ler `docs/testing/validation-matrix.md`;
7. ler a documentação técnica relacionada à mudança;
8. inspecionar o diff e arquivos locais preexistentes para não sobrescrever
   trabalho do usuário.

## Saída esperada por etapa

### 1. Inspection

Estabelecer o estado real do repositório, branch, histórico, mudanças locais,
arquivos relevantes e evidências já existentes. Conversas antigas não são
fonte suficiente.

### 2. Requirements

Mapear a mudança a requisitos existentes. Se o pedido criar ou alterar um
requisito, registrar a proposta sem confundi-la com decisão aprovada.

### 3. Official research

Para dependências, versões e comportamento técnico, consultar primeiro os
requisitos e depois documentação e releases oficiais. Registrar fonte, tipo,
finalidade e data em `docs/references/`. Fóruns e issues servem apenas para
troubleshooting e devem ser rotulados como tal.

### 4. Proposal

Apresentar opção recomendada, compatibilidade, testes necessários, impactos,
riscos e alternativas razoáveis. Conflitos entre fontes oficiais devem ser
expostos ao usuário.

### 5. User decision

Obter aprovação antes de decisões protegidas pelo `AGENTS.md`, incluindo
versões, troca de dependências, MPI, HDF5 serial/paralelo, MPAS/WPS, primeira
malha/caso, recorte ERA5 e domínio global/limitado.

### 6. Implementation

Alterar apenas o escopo aprovado. Preservar mudanças locais não relacionadas e
nunca incluir credenciais, grandes datasets ou saídas científicas sem intenção
explícita.

### 7. Upstream test

Executar a suite fornecida pelo projeto upstream, quando disponível. Registrar
comando, versão, resultado e evidência. Se não existir suite, documentar a
ausência com fonte oficial.

### 8. Smoke test

Provar o funcionamento mínimo: consultar configuração/versão, compilar e
executar um programa pequeno ou verificar um executável/arquivo essencial. O
teste deve exercitar a instalação, não apenas a árvore de build.

### 9. Integration test

Provar a ligação com a camada anterior e, quando pertinente, com o primeiro
consumidor posterior. Verificar headers, módulos Fortran, bibliotecas,
linkagem/runtime e troca mínima de dados.

### 10. Review

Revisar o diff completo, correção técnica, segurança, compatibilidade,
legibilidade, escopo e cobertura de teste. Confirmar que nenhum arquivo
científico foi alterado por acidente.

### 11. Documentation

Atualizar somente os documentos afetados: estado, stack, referências, versões,
matriz, grafo, ADR e README conforme o impacto real.

### 12. Learning note

Criar `learning/commits/NNNN-<descricao>.md` explicando mudança, motivação,
conceitos, arquivos, comandos, testes, interpretação, falhas, trade-offs e o
aprendizado esperado. A nota não deve apenas narrar o diff.

### 13. Pre-commit report

Apresentar ao usuário:

- arquivos criados e modificados;
- testes e validações, com resultados reais;
- documentação e learning note;
- warnings, lacunas e dívida técnica;
- mensagem de commit semântica proposta.

### 14. User approval

Parar e aguardar autorização explícita. Aprovação para implementar não é
aprovação automática para commit ou push.

### 15. Commit

Depois da aprovação, criar um commit pequeno e semântico. Os testes obrigatórios
devem ter passado, e o escopo apresentado deve coincidir com o commit.

### 16. Push

Executar somente quando autorizado. Não fazer force push e não reescrever o
histórico.

## Registro de testes

Cada componente deve ter, no mínimo:

1. suite upstream, quando disponível;
2. verificação de executável ou configuração;
3. smoke test funcional;
4. verificação de dependências e linkagem;
5. integração com a camada precedente.

Resultados pertencem a `docs/testing/`. Uma linha de comando planejada ou
presente no `Dockerfile` não pode ser registrada como resultado aprovado sem
evidência da execução.

## Critério de encerramento do ciclo

O trabalho técnico termina no relatório pré-commit. Commit e push são etapas
posteriores e dependem de aprovações distintas quando solicitado pelo usuário.
