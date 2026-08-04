# Aprendizado do projeto MPAS-ERA5

## Finalidade

`learning/` transforma cada etapa técnica em material de estudo. A
documentação em `docs/` responde principalmente **qual é o estado, a regra ou
a arquitetura do projeto**. Este diretório responde **como compreender o que
foi feito, por que funciona, como diagnosticar falhas e o que aprender com
cada mudança**.

As duas áreas se complementam e não devem divergir. Em caso de diferença, o
estado factual precisa ser corrigido em `docs/`, e a explicação didática deve
apontar para ele.

## Conteúdo

- [`baseline.md`](baseline.md): explicação detalhada da stack construída antes
  do início dos ciclos Codex;
- [`commits/0001-bootstrap-codex-workflow.md`](commits/0001-bootstrap-codex-workflow.md):
  nota educacional do ciclo de governança 0001;
- `commits/NNNN-<descricao>.md`: uma nota por commit posterior ao bootstrap.

## O que cada nota por commit deve ensinar

Uma learning note precisa explicar:

1. o que mudou e por quê;
2. conceitos necessários para entender a mudança;
3. arquivos afetados e a relação entre eles;
4. comandos importantes e o que cada parte faz;
5. testes executados e como interpretar resultados reais;
6. falhas encontradas e o raciocínio de diagnóstico;
7. alternativas, trade-offs, decisões e dívida técnica;
8. o que o leitor deve conseguir fazer ou explicar ao final.

A nota não é um changelog ampliado. Ela deve permitir que o usuário reconstrua
o raciocínio da implementação sem depender de uma conversa efêmera.

## Regras de evidência e segurança

- não afirmar que um teste passou sem saída ou registro confiável;
- separar comando planejado, comando definido na receita e comando executado;
- não incluir CDS credentials, tokens, senhas ou dados científicos grandes;
- apontar para ADRs, fontes, versões e matriz de validação quando aplicável;
- registrar limitações e falhas, inclusive quando a conclusão é “não há
  evidência suficiente”.

## Numeração

Use quatro dígitos e um nome curto em kebab-case:

```text
learning/commits/0002-add-pnetcdf.md
```

A numeração identifica o ciclo/commit educacional e não substitui o hash Git.
Se um ciclo não resultar em commit, a nota permanece como trabalho do ciclo e
deve ser revisada antes de uma aprovação futura.
