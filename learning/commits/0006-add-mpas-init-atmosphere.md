# Ciclo 0006 — MPAS-Model 8.4.1 / init_atmosphere

## Resultado e limite

O ciclo adicionou o source oficial MPAS-Model 8.4.1 à imagem e compilou
somente o core init_atmosphere. O resultado deve ser lido assim:

- BUILD: PASS;
- STRUCTURAL/INSTALL SMOKE: PASS;
- FUNCTIONAL, mesh → init_atmosphere: PENDENTE;
- SCIENTIFIC/REAL-DATA, mesh + dados estáticos + WPS/ERA5 → init.nc: PENDENTE.

O executável não foi rodado porque ainda não existem mesh, configuração e
entradas representativas aprovadas. Compilar e instalar corretamente não é o
mesmo que provar funcionamento científico.

## MPAS: framework e cores

MPAS significa Model for Prediction Across Scales. Ele é um framework que
compartilha infraestrutura de paralelismo, decomposição, malha, I/O, timers,
configuração e streams entre diferentes cores.

No MPAS-Atmosphere, init_atmosphere e atmosphere têm responsabilidades
distintas:

- init_atmosphere prepara campos estáticos, condições iniciais e, quando o caso
  exigir, condições laterais;
- atmosphere integra as equações atmosféricas no tempo.

Por isso eles geram executáveis separados, com registries, namelists, streams e
fluxos de dados próprios. Este ciclo construiu init_atmosphere_model.
atmosphere_model permanece ausente.

## MPI, wrappers e target GNU

O target gnu do MPAS é paralelo. Ele usa mpif90, mpicc e mpicxx. Esses wrappers
chamam os compiladores GNU subjacentes e acrescentam módulos, headers e
bibliotecas OpenMPI. Isso é mais seguro que montar manualmente o link MPI.

Não existe, nesse target, um segundo executável serial. Uma futura execução
com um rank continua sendo um programa MPI executado por um processo.

O comando real foi:

    make -j8 gnu CORE=init_atmosphere USE_PIO2=true MPAS_ESMF=embedded

As partes significam:

- -j8 permite até oito jobs de make;
- gnu seleciona GCC/GFortran por meio dos wrappers MPI;
- CORE=init_atmosphere escolhe somente o core de inicialização;
- USE_PIO2=true registra a intenção de usar PIO2;
- MPAS_ESMF=embedded seleciona o timekeeping incluído no source.

Na tag 8.4.1, USE_PIO2 é aceito por compatibilidade, mas o Makefile avisa que a
variável é ignorada como seletor. PIO2 é autodetectado por
compilação/linkagem. Logo, a prova efetiva vem do resumo, dos build options,
das bibliotecas e dos símbolos, e não apenas do texto do comando.

## NETCDF, PNETCDF, PIO e MPI-IO

A descoberta usa:

    NETCDF=/opt/mpas
    PNETCDF=/opt/mpas
    PIO=/opt/mpas

As camadas se relacionam assim:

    init_atmosphere
          ↓
    PIO 2.7.0
          ↓
    PnetCDF 1.15.0
          ↓
    MPI-IO
          ↓
    OpenMPI

PIO fornece a abstração de I/O usada pelo framework. PnetCDF implementa acesso
paralelo aos formatos CDF sobre MPI-IO. MPI-IO é a interface coletiva de
arquivos fornecida pela implementação MPI.

PIO foi instalado como biblioteca estática. Assim, ldd não precisa listar uma
libpio compartilhada: seu código está incorporado no executável. PnetCDF é
shared e aparece como libpnetcdf.so.8.

## Precisão, otimização e recursos desligados

A release 8.4.1 usa single precision por default. O ciclo preservou esse
default e não passou PRECISION=double. O resumo e -DSINGLE_PRECISION nos build
options comprovam a escolha.

A precisão não é mero detalhe de sintaxe: ela pode afetar memória, desempenho e
numerics. Mudá-la exige decisão explícita.

O build usa -O3 e DEBUG está desligado. Builds de debug são úteis para
diagnóstico porque acrescentam verificações e reduzem otimizações, mas não eram
o objetivo desta baseline.

Também ficaram desligados OpenMP, offload OpenMP, OpenACC, GPU, MUSICA e
PT-Scotch. MPI coordena processos com memória separada; OpenMP coordena threads
em memória compartilhada. Não habilitar aceleradores agora reduz variáveis do
primeiro build.

MPAS_ESMF=embedded usa a implementação de tempo/calendário incluída. SMIOL e
ezXML também vieram do source. init_atmosphere não exigiu download manual de
MMM-physics, UGWP, MUSICA, PT-Scotch ou outro externo.

## Tag, commit e git describe

O Dockerfile clona o repositório oficial na tag v8.4.1 e exige:

    git rev-parse HEAD
    91c5eac175eebeaf4206bacd5cb50c39dff3c152

Também verifica a tag exata antes de compilar. Se o commit não coincidir, o
build falha.

A metadata Git é preservada porque o Makefile chama git describe para registrar
a versão. Um archive sem .git perderia essa evidência. O trade-off é uma imagem
maior; neste ciclo, a rastreabilidade solicitada teve prioridade.

## Layout

O layout separa bibliotecas, WPS e source do modelo:

    /opt/mpas
        bibliotecas científicas

    /opt/wps-4.7.0
    /opt/wps -> /opt/wps-4.7.0

    /opt/mpas-model-8.4.1
    /opt/mpas-model -> /opt/mpas-model-8.4.1

/opt/mpas não é o source MPAS. /opt/mpas-model identifica a árvore do modelo e
o link estável evita codificar a versão em comandos de uso.

## Namelist e streams

O build gerou:

    init_atmosphere_model
    namelist.init_atmosphere
    streams.init_atmosphere
    default_inputs/namelist.init_atmosphere
    default_inputs/streams.init_atmosphere

O namelist contém opções de execução agrupadas no formato Fortran. Streams
descreve fluxos de entrada/saída, campos, intervalos e nomes de arquivos. A
presença dos defaults prova o resultado esperado do build, não uma
configuração científica completa.

## Probe descartável

Antes do Dockerfile definitivo, a imagem validada do WPS confirmou:

- NETCDF, PNETCDF e PIO sob /opt/mpas;
- mpif90, mpicc, mpicxx, gfortran, gcc e g++;
- headers, módulos e bibliotecas da stack;
- o comando aprovado sem flags extras.

A primeira tentativa encontrou a proteção Git “dubious ownership”: o source
bind-mounted tinha UID do host dentro do container root. Como o Makefile chama
git describe, o Git recusou a árvore. Apenas no probe descartável, aquele
caminho foi marcado como safe directory. O clone permanente é root-owned e não
precisou dessa exceção.

## file, ldd e símbolos

file classificou init_atmosphere_model como ELF 64-bit PIE x86-64, dinâmico e
não stripped.

ldd mostrou netCDF, PnetCDF, MPI, GFortran, HDF5, zlib e bibliotecas de sistema,
sem not found. ldd enxerga dependências shared, mas não prova bibliotecas
incorporadas estaticamente.

Por isso nm complementou a evidência. O binário define:

    PIOc_Init_Intracomm
    PIOc_createfile
    PIOc_openfile

As chamadas ncmpi_create e ncmpi_open aparecem como referências resolvidas pela
PnetCDF compartilhada. Resumo, build options, ldd e símbolos juntos provam a
arquitetura de I/O.

## Testes e interpretação

O build definitivo foi:

    docker build --progress=plain --build-arg BUILD_JOBS=8 -t mpas-era5:mpas-init-8.4.1 .

Todas as etapas até WPS apareceram como CACHED. A nova camada foi acrescentada
depois da stack existente, sem reconstruir as versões anteriores.

O smoke foi:

    ./scripts/validate/mpas-init.sh

Ele executa sem rede, com raiz read-only e tmpfs, e valida proveniência, layout,
defaults, opções, interfaces, file, ldd e símbolos. Código zero prova essas
asserções estruturais.

As regressões foram:

    PNETCDF_IMAGE=mpas-era5:mpas-init-8.4.1 ./scripts/validate/pnetcdf.sh
    PIO_IMAGE=mpas-era5:mpas-init-8.4.1 ./scripts/validate/pio.sh
    WPS_IMAGE=mpas-era5:mpas-init-8.4.1 ./scripts/validate/wps-ungrib.sh

PnetCDF preservou F90/CDF-5 em quatro ranks e valores 0–3. PIO preservou
CDF-2/PnetCDF em quatro ranks com OMPIO e ROMIO e valores 1000–1003. WPS
preservou instalação, configuração GNU serial, suporte GRIB2 e Vtables.

METIS não foi reexecutado porque a mudança não tocou sua camada ou o fluxo de
particionamento. O Docker build mostrou essa etapa recuperada do cache.

## Suíte upstream, falhas e avisos

A tag não contém suíte autocontida de init_atmosphere que rode sem mesh,
configuração e entradas. Helpers upstream de setup não fornecem esses dados
sozinhos. Inventar entradas só para obter código zero não produziria evidência
científica.

Além do problema de ownership exclusivo do probe, o compilador emitiu avisos de
código legado no ESMF embedded e nas ferramentas de Registry, incluindo tabs
não conformes e possível truncamento em snprintf. Make também avisou sobre
regras antigas. Não houve erro de compilação ou linkagem. Esses avisos são
dívida técnica a observar, não falhas científicas já demonstradas.

## Arquivos alterados

- Dockerfile: clone verificado, build, validações e layout;
- scripts/validate/mpas-init.sh: smoke versionado;
- README.md: estado público;
- docs/build/scientific-stack.md: arquitetura e build;
- docs/project/current-state.md: estado real;
- docs/references/source-registry.md: fontes oficiais;
- docs/references/versions.lock.md: status parcial do MPAS;
- docs/testing/validation-matrix.md: evidências e limites;
- docs/architecture/project-graph.md: relações e novos artefatos;
- docs/README.md e learning/README.md: índices;
- esta nota de aprendizado.

Nenhum ADR novo foi necessário: o ADR 0004 já cobre versão, layout e separação
entre a stack científica e o source MPAS.

## Próximo passo e aprendizado esperado

Ainda faltam escolher uma mesh real, preparar configuração e dados estáticos,
definir Vtable/campos ERA5, produzir e validar static.nc/init.nc/LBC quando
aplicável, compilar atmosphere em ciclo próprio e executar um primeiro caso.

Ao final desta nota, o leitor deve conseguir explicar por que o build é MPI,
como PIO/PnetCDF entram na linkagem, por que ldd não basta para biblioteca
static, como tag/commit/git describe sustentam proveniência e por que smoke
estrutural não substitui execução com mesh e dados reais.
