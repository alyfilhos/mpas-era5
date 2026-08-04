# Registro de fontes

## Finalidade

Este registro documenta de onde vêm requisitos, fatos técnicos, versões e
orientações de troubleshooting. Uma fonte deve ser classificada antes de ser
usada; autoridade e utilidade não são a mesma coisa.

Última revisão deste registro: **2026-08-04**.

## Classes de fonte

| Classe | Uso permitido | Limite |
|---|---|---|
| Requisito original | definir objetivo, restrições e entregáveis do projeto | não prova compatibilidade técnica nem informa necessariamente uma versão |
| Documentação oficial | definir interfaces, opções de build, requisitos e procedimentos mantidos pelo projeto upstream | conferir se a página corresponde à versão adotada |
| Release oficial | fixar artefato, versão, checksum e notas de release | não substitui a documentação de uso e compatibilidade |
| Fonte secundária | fornecer contexto, comparação ou explicação | não é autoridade primária para arquitetura ou versões |
| Fórum/issue para troubleshooting | investigar sintomas e hipóteses de falha | não deve decidir arquitetura ou versão; a solução precisa ser validada localmente e, se possível, confirmada em fonte oficial |

## Fontes registradas

### Requisitos originais

| ID | Fonte | Escopo | Verificação |
|---|---|---|---|
| REQ-001 | briefing técnico do responsável pelo projeto, transcrito em [[../project/requirements|requirements.md]] | plano completo GNU/MPI → stack → MPAS/WPS → ERA5 → primeiro caso → validação/documentação | conferido durante o ciclo 0001 em 2026-08-04; não possui URL pública |
| REQ-002 | [`README.md`](../../README.md) no histórico Git | objetivo educacional, primeiro caso global de baixa resolução e roadmap inicial | arquivo e histórico completo conferidos em 2026-08-04 |
| REQ-003 | [`AGENTS.md`](../../AGENTS.md) | governança, gates de decisão, testes, documentação, commit e segurança | arquivo local conferido integralmente em 2026-08-04 |

### Documentação oficial

Nenhuma URL de documentação oficial foi necessária nem verificada externamente
no ciclo 0001, pois nenhuma dependência foi introduzida ou atualizada. A
primeira pesquisa técnica de cada componente deverá adicionar aqui a página
oficial específica da versão consultada, sua finalidade e a data de acesso.

### Releases e artefatos usados pela implementação atual

As URLs abaixo são reproduzidas literalmente do [`Dockerfile`](../../Dockerfile),
portanto não são URLs inferidas. Elas foram verificadas **no repositório**, mas
não revalidadas pela rede neste ciclo de governança.

| ID | Componente | Release/artefato registrado | Integridade no build | Estado da verificação |
|---|---|---|---|---|
| REL-UBUNTU-001 | Ubuntu | imagem `ubuntu:24.04` | tag sem digest fixado | referência confirmada no `Dockerfile`; origem/digest devem ser verificados antes de uma mudança de base |
| REL-ZLIB-001 | zlib 1.3.2 | `https://zlib.net/fossils/zlib-1.3.2.tar.gz` | SHA-256 `bb329a0a2cd0274d05519d61c667c062e06990d72e125ee2dfa8de64f0119d16` | URL e hash confirmados no `Dockerfile`; autoridade externa não revalidada neste ciclo |
| REL-HDF5-001 | HDF5 1.14.6 | `https://github.com/HDFGroup/hdf5/releases/download/hdf5_1.14.6/hdf5-1.14.6.tar.gz` | nenhum SHA-256 registrado | URL confirmada no `Dockerfile`; checksum e release oficial precisam de verificação futura |
| REL-NETCDF-C-001 | netCDF-C 4.10.1 | `https://downloads.unidata.ucar.edu/netcdf-c/4.10.1/netcdf-c-4.10.1.tar.gz` | SHA-256 `db3b69ff4a5ee1a7d79a5c36664d2128b752c266e966369fcf7311ec5f927564` | URL e hash confirmados no `Dockerfile`; autoridade externa não revalidada neste ciclo |
| REL-NETCDF-F-001 | netCDF-Fortran 4.6.3 | `https://downloads.unidata.ucar.edu/netcdf-fortran/4.6.3/netcdf-fortran-4.6.3.tar.gz` | SHA-256 `f642050e90025e7bb25848cc8f818545e1d3bdeb73fe6d103a6f8dc000a1a3d6` | URL e hash confirmados no `Dockerfile`; autoridade externa não revalidada neste ciclo |

Registrar uma URL aqui não autoriza download novo, mudança de versão ou
alteração da stack. Para isso, a fonte deve ser consultada conforme o workflow,
a compatibilidade deve ser avaliada e o usuário deve aprovar a proposta.

### Fontes secundárias

Nenhuma fonte secundária está registrada até o ciclo 0001.

### Fóruns e issues para troubleshooting

Nenhum fórum ou issue está registrado até o ciclo 0001. Quando houver, cada
entrada deve registrar sintoma investigado, hipótese aproveitada, versão à qual
se aplica e validação local; ela nunca será tratada como decisão de arquitetura.

## Campos obrigatórios para novas entradas

Toda nova fonte deve registrar:

1. identificador estável;
2. classe de fonte;
3. componente e versão aplicável;
4. título ou descrição;
5. URL exata, quando houver;
6. finalidade da consulta;
7. data de verificação;
8. resultado da verificação;
9. decisão, ADR ou teste que a utiliza.

URLs não abertas ou não presentes em uma fonte já rastreada devem permanecer
fora do registro até verificação. Em caso de conflito entre fontes oficiais, o
ciclo deve parar e apresentar o conflito ao usuário.
