# MPAS-ERA5 — Agent Instructions

## Mission

Implement the MPAS + ERA5 project incrementally while preserving:

1. scientific correctness;
2. reproducibility;
3. educational value;
4. clear Git history;
5. traceable technical decisions.

Never sacrifice learning or validation merely to finish faster.

## Sources of truth

Before every development cycle, read:

1. docs/project/requirements.md
2. docs/project/current-state.md
3. docs/project/development-workflow.md
4. docs/architecture/project-graph.md
5. docs/references/source-registry.md
6. docs/references/versions.lock.md
7. docs/testing/validation-matrix.md
8. the relevant existing technical documentation in docs/

Also inspect:

git status
git log --oneline -10

Never assume the repository is in the state described by an old conversation.

## External research

Before introducing or upgrading a dependency:

1. consult the original project requirements;
2. consult the official project documentation;
3. consult the official release/download source;
4. verify compatibility with the existing stack;
5. record the source and verification date.

Prefer official sources.

Community forums/issues may be used for troubleshooting, but not as the
primary authority for architecture or versions.

If official sources conflict, stop and present the conflict to the user.

## Decision gates

Do NOT decide without user approval:

- dependency versions when multiple reasonable choices exist;
- replacing an existing dependency;
- rebuilding an already validated layer differently;
- changing serial/parallel HDF5 strategy;
- changing MPI implementation;
- changing MPAS or WPS release;
- changing the first mesh/case strategy;
- changing ERA5 period/area/variables;
- changing global versus limited-area simulation;
- destructive Docker operations;
- rewriting Git history;
- merging or pushing major changes.

Research the options and recommend one, but ask the user to decide.

## Allowed autonomous work

After the user approves a technical direction, you may:

- edit project files;
- create scripts;
- build Docker images;
- run non-destructive tests;
- diagnose build failures;
- update documentation;
- update the project graph;
- create learning documentation;
- perform code review.

Do not silently expand scope.

## Development cycle

Every technical cycle follows:

RESEARCH
→ PROPOSAL
→ USER DECISION
→ IMPLEMENTATION
→ TESTS
→ REVIEW
→ DOCUMENTATION
→ LEARNING NOTE
→ PRE-COMMIT REPORT
→ USER APPROVAL
→ COMMIT/PUSH

Never skip a stage.

## Testing

A dependency is not considered installed merely because compilation succeeds.

Each component requires:

1. upstream test suite when available;
2. executable/configuration check;
3. minimal functional smoke test;
4. dependency/link verification when applicable;
5. integration test with the preceding layer.

Record validation results in docs/testing/.

## Documentation

Update only documents affected by the change.

README.md:
update when project-visible status or usage changes.

docs/build/:
update when the scientific stack changes.

docs/architecture/project-graph.md:
update when directories, components, or relationships change.

docs/references/:
update whenever new sources or versions are used.

docs/decisions/:
create an ADR for meaningful architecture decisions.

docs/project/current-state.md:
update every successful development cycle.

## Learning documentation

Every commit after the Codex bootstrap must include one educational note:

learning/commits/NNNN-<short-description>.md

The note must explain:

- what changed;
- why it changed;
- concepts required to understand it;
- files changed;
- important commands;
- how the commands work;
- tests executed;
- how to interpret their results;
- failures encountered;
- trade-offs and decisions;
- what the user should learn from the commit.

Do not merely reproduce the diff.

## Commit policy

Use small semantic commits.

Examples:

build:
feat:
fix:
test:
docs:
chore:
ci:
refactor:

A commit must not be created until its required tests pass.

Before committing, show the user:

- changed files;
- test results;
- documentation changes;
- learning note;
- proposed commit message;
- unresolved warnings or technical debt.

Wait for approval.

## Safety

Never commit:

- CDS credentials;
- API keys;
- tokens;
- passwords;
- large ERA5 datasets;
- generated MPAS output unless explicitly intended.

Never use force push unless explicitly authorized.

Never remove containers, images, volumes, datasets, or Git history merely
to fix a development problem.
