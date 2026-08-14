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
- [`commits/0002-add-pnetcdf.md`](commits/0002-add-pnetcdf.md): nota
  educacional do build e da validação PnetCDF/MPI-IO;
- [`commits/0003-add-pio2.md`](commits/0003-add-pio2.md): nota educacional
  da seleção, build e validação PIO2 sobre PnetCDF;
- [`commits/0004-add-metis.md`](commits/0004-add-metis.md): nota educacional
  sobre grafos e o particionamento offline com METIS 5.1.0;
- [`commits/0005-add-wps-ungrib.md`](commits/0005-add-wps-ungrib.md): nota
  educacional sobre WPS, GRIB, Vtables e o build isolado do `ungrib`;
- [`commits/0006-add-mpas-init-atmosphere.md`](commits/0006-add-mpas-init-atmosphere.md):
  nota educacional sobre o framework MPAS, o core `init_atmosphere`, MPI,
  PIO2 e os limites da validação sem mesh;
- [`commits/0007-add-mpas-atmosphere.md`](commits/0007-add-mpas-atmosphere.md):
  nota educacional sobre o core `atmosphere`, física, externals fixados,
  lookup tables e reutilização segura do framework;
- [`commits/0008-add-first-mesh.md`](commits/0008-add-first-mesh.md): nota
  educacional sobre SCVT, NetCDF de mesh, grafo, METIS e política de dados;
- [`commits/0009-generate-static-fields.md`](commits/0009-generate-static-fields.md):
  nota educacional sobre WPS_GEOG, interpolação, static, GWD, Noah-MP e
  validação física básica;
- [`commits/0010-add-era5-acquisition.md`](commits/0010-add-era5-acquisition.md):
  nota educacional sobre reanálise, ERA5, pressure/single levels, GRIB, CDS,
  credenciais, requests e validação de transporte;
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
