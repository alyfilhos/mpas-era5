FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    build-essential \
    gfortran \
    openmpi-bin \
    libopenmpi-dev \
    git \
    wget \
    curl \
    ca-certificates \
    make \
    cmake \
    m4 \
    perl \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Diretório da stack científica
ENV MPAS_PREFIX=/opt/mpas

ENV PATH=${MPAS_PREFIX}/bin:${PATH}
ENV LD_LIBRARY_PATH=${MPAS_PREFIX}/lib:${MPAS_PREFIX}/lib64
ENV CPPFLAGS=-I${MPAS_PREFIX}/include
ENV LDFLAGS=-L${MPAS_PREFIX}/lib

ARG BUILD_JOBS=8

# ------------------------------------------------------------
# zlib
# ------------------------------------------------------------

ARG ZLIB_VERSION=1.3.2

WORKDIR /tmp

RUN curl -fL \
    https://zlib.net/fossils/zlib-${ZLIB_VERSION}.tar.gz \
    -o zlib.tar.gz \
    && echo "bb329a0a2cd0274d05519d61c667c062e06990d72e125ee2dfa8de64f0119d16  zlib.tar.gz" \
       | sha256sum -c - \
    && tar -xzf zlib.tar.gz \
    && cd zlib-${ZLIB_VERSION} \
    && ./configure --prefix=${MPAS_PREFIX} \
    && make -j${BUILD_JOBS} \
    && make install \
    && rm -rf /tmp/zlib*

# ------------------------------------------------------------
# HDF5
# ------------------------------------------------------------

ARG HDF5_VERSION=1.14.6

WORKDIR /tmp

RUN curl -fL \
    https://github.com/HDFGroup/hdf5/releases/download/hdf5_${HDF5_VERSION}/hdf5-${HDF5_VERSION}.tar.gz \
    -o hdf5.tar.gz \
    && tar -xzf hdf5.tar.gz \
    && cd hdf5-${HDF5_VERSION} \
    && CC=gcc FC=gfortran ./configure \
        --prefix=${MPAS_PREFIX} \
        --with-zlib=${MPAS_PREFIX} \
        --enable-fortran \
        --enable-shared \
        --enable-static \
    && make -j${BUILD_JOBS} \
    && make install \
    && rm -rf /tmp/hdf5*

WORKDIR /workspace

# ------------------------------------------------------------
# netCDF-C
# ------------------------------------------------------------

ARG NETCDF_C_VERSION=4.10.1
ARG NETCDF_C_SHA256=db3b69ff4a5ee1a7d79a5c36664d2128b752c266e966369fcf7311ec5f927564

WORKDIR /tmp

RUN curl -fL \
    https://downloads.unidata.ucar.edu/netcdf-c/${NETCDF_C_VERSION}/netcdf-c-${NETCDF_C_VERSION}.tar.gz \
    -o netcdf-c.tar.gz \
    && echo "${NETCDF_C_SHA256}  netcdf-c.tar.gz" | sha256sum -c - \
    && tar -xzf netcdf-c.tar.gz \
    && cd netcdf-c-${NETCDF_C_VERSION} \
    && ./configure \
        --prefix=${MPAS_PREFIX} \
        --enable-hdf5 \
        --disable-dap \
        --disable-libxml2 \
        --disable-nczarr \
        --disable-parallel4 \
        --enable-shared \
        --enable-static \
    && make -j${BUILD_JOBS} \
    && make check \
    && make install \
    && rm -rf /tmp/netcdf-c*

WORKDIR /workspace

# ------------------------------------------------------------
# netCDF-Fortran
# ------------------------------------------------------------

ARG NETCDF_FORTRAN_VERSION=4.6.3
ARG NETCDF_FORTRAN_SHA256=f642050e90025e7bb25848cc8f818545e1d3bdeb73fe6d103a6f8dc000a1a3d6

WORKDIR /tmp

RUN curl -fL \
    https://downloads.unidata.ucar.edu/netcdf-fortran/${NETCDF_FORTRAN_VERSION}/netcdf-fortran-${NETCDF_FORTRAN_VERSION}.tar.gz \
    -o netcdf-fortran.tar.gz \
    && echo "${NETCDF_FORTRAN_SHA256}  netcdf-fortran.tar.gz" | sha256sum -c - \
    && tar -xzf netcdf-fortran.tar.gz \
    && cd netcdf-fortran-${NETCDF_FORTRAN_VERSION} \
    && CC=gcc FC=gfortran ./configure \
        --prefix=${MPAS_PREFIX} \
        --disable-zstandard-plugin \
        --enable-shared \
        --enable-static \
    && make -j${BUILD_JOBS} \
    && make check \
    && make install \
    && rm -rf /tmp/netcdf-fortran*

# Variável usada pelo sistema de build do MPAS
ENV NETCDF=${MPAS_PREFIX}

WORKDIR /workspace

# ------------------------------------------------------------
# PnetCDF
# ------------------------------------------------------------

ARG PNETCDF_VERSION=1.15.0
ARG PNETCDF_SHA256=39813fe91ec901c7cfca3212731edbb5201029ebf55caeaaaa08d9e33c6bad65

WORKDIR /tmp

RUN --mount=type=cache,target=/pnetcdf-test-output,sharing=locked \
    command -v mpicc \
    && command -v mpicxx \
    && command -v mpifort \
    && command -v mpif77 \
    && mpicc --showme \
    && mpifort --showme \
    && apt-get update \
    && apt-get install -y --no-install-recommends bc \
    && rm -rf /var/lib/apt/lists/* \
    && curl -fL \
       https://parallel-netcdf.github.io/Release/pnetcdf-${PNETCDF_VERSION}.tar.gz \
       -o pnetcdf.tar.gz \
    && echo "${PNETCDF_SHA256}  pnetcdf.tar.gz" | sha256sum -c - \
    && tar -xzf pnetcdf.tar.gz \
    && cd pnetcdf-${PNETCDF_VERSION} \
    && MPICC=mpicc \
       MPICXX=mpicxx \
       MPIF77=mpif77 \
       MPIF90=mpifort \
       ./configure \
        --prefix=${MPAS_PREFIX} \
        --disable-gio \
        --enable-shared \
        --enable-static \
    && make -j${BUILD_JOBS} \
    && make check \
    && ompi_info --param io all | grep -F "MCA io: romio321" \
    && rm -rf /pnetcdf-test-output/pnetcdf-1.15.0 \
    && mkdir -p /pnetcdf-test-output/pnetcdf-1.15.0 \
    && timeout --signal=TERM --kill-after=30s 5m \
       make ptest \
       TESTMPIRUN="mpiexec --allow-run-as-root --mca io romio321 -n NP" \
       TESTOUTDIR=/pnetcdf-test-output/pnetcdf-1.15.0 \
    && rm -rf /pnetcdf-test-output/pnetcdf-1.15.0 \
    && make install \
    && which pnetcdf_version \
    && pnetcdf_version \
    && which pnetcdf-config \
    && pnetcdf-config --help \
    && pnetcdf-config --all \
    && test "$(pnetcdf-config --version)" = "PnetCDF ${PNETCDF_VERSION}" \
    && test "$(pnetcdf-config --prefix)" = "${MPAS_PREFIX}" \
    && test "$(pnetcdf-config --has-fortran)" = "yes" \
    && test "$(pnetcdf-config --gio)" = "disabled" \
    && which ncmpidump \
    && test -f "$(pnetcdf-config --libdir)/libpnetcdf.a" \
    && test -e "$(pnetcdf-config --libdir)/libpnetcdf.so" \
    && rm -rf /tmp/pnetcdf*

# Variável usada pelo sistema de build do MPAS
ENV PNETCDF=${MPAS_PREFIX}

WORKDIR /workspace

# ------------------------------------------------------------
# ParallelIO (PIO2)
# ------------------------------------------------------------

ARG PIO_VERSION=2.7.0
ARG PIO_TAG=pio2_7_0
ARG PIO_SHA256=cce83743156ae723e7890931c2b48dcfe7ea8a276962dc4429f839d8f58d4a5a
ARG CMAKE_FORTRAN_UTILS_COMMIT=05ff8d8e4c88786e94a02c853d3ff921113d785c
ARG GENF90_COMMIT=4816965ba946731352bad195b7d946a5fe682ff5

WORKDIR /tmp

RUN curl -fL \
    https://github.com/NCAR/ParallelIO/archive/refs/tags/${PIO_TAG}.tar.gz \
    -o pio.tar.gz \
    && echo "${PIO_SHA256}  pio.tar.gz" | sha256sum -c - \
    && tar -xzf pio.tar.gz \
    && mv ParallelIO-${PIO_TAG} pio-src \
    && mkdir -p pio-build \
    && git clone \
       https://github.com/CESM-Development/CMake_Fortran_utils \
       pio-build/CMake_Fortran_utils \
    && git -C pio-build/CMake_Fortran_utils \
       checkout --detach "${CMAKE_FORTRAN_UTILS_COMMIT}" \
    && test "$(git -C pio-build/CMake_Fortran_utils rev-parse HEAD)" = \
       "${CMAKE_FORTRAN_UTILS_COMMIT}" \
    && git clone https://github.com/PARALLELIO/genf90 pio-genf90 \
    && git -C pio-genf90 checkout --detach "${GENF90_COMMIT}" \
    && test "$(git -C pio-genf90 rev-parse HEAD)" = "${GENF90_COMMIT}" \
    && CC=mpicc FC=mpifort cmake \
       -S pio-src \
       -B pio-build \
       -DCMAKE_BUILD_TYPE=Release \
       -DCMAKE_INSTALL_PREFIX=${MPAS_PREFIX} \
       -DCMAKE_PREFIX_PATH=${MPAS_PREFIX} \
       -DUSER_CMAKE_MODULE_PATH=/tmp/pio-build/CMake_Fortran_utils \
       -DGENF90_PATH=/tmp/pio-genf90 \
       -DPIO_ENABLE_FORTRAN=ON \
       -DPIO_ENABLE_TIMING=OFF \
       -DPIO_ENABLE_LOGGING=OFF \
       -DPIO_ENABLE_DOC=OFF \
       -DPIO_ENABLE_EXAMPLES=ON \
       -DPIO_ENABLE_NETCDF_INTEGRATION=OFF \
       -DPIO_ENABLE_TESTS=ON \
       -DPIO_USE_GDAL=OFF \
       -DWITH_PNETCDF=ON \
       -DBUILD_SHARED_LIBS=OFF \
    && cmake --build pio-build \
       --target pioc piof \
       --parallel ${BUILD_JOBS} \
    && cmake --build pio-build \
       --target tests \
       --parallel 1 \
    && OMPI_ALLOW_RUN_AS_ROOT=1 \
       OMPI_ALLOW_RUN_AS_ROOT_CONFIRM=1 \
       OMPI_MCA_rmaps_base_oversubscribe=1 \
       ctest \
       --test-dir pio-build \
       --output-on-failure \
       --timeout 120 \
       --parallel 1 \
    && cmake --install pio-build \
    && test -f ${MPAS_PREFIX}/include/pio.h \
    && test -f ${MPAS_PREFIX}/include/pio.mod \
    && test -f ${MPAS_PREFIX}/lib/libpioc.a \
    && test -f ${MPAS_PREFIX}/lib/libpiof.a \
    && test -f ${MPAS_PREFIX}/lib/libpio.settings \
    && test -f ${MPAS_PREFIX}/lib/cmake/PIO/PIOConfig.cmake \
    && grep -F "PIO Version:" ${MPAS_PREFIX}/lib/libpio.settings \
    && grep -F "${PIO_VERSION}" ${MPAS_PREFIX}/lib/libpio.settings \
    && grep -F "PnetCDF Support:" ${MPAS_PREFIX}/lib/libpio.settings \
       | grep -F "yes" \
    && grep -F "NetCDF/HDF5 Par I/O:" ${MPAS_PREFIX}/lib/libpio.settings \
       | grep -F "no" \
    && rm -rf /tmp/pio.tar.gz /tmp/pio-src /tmp/pio-build /tmp/pio-genf90

# Variável usada pelo sistema de build do MPAS
ENV PIO=${MPAS_PREFIX}

WORKDIR /workspace

# ------------------------------------------------------------
# METIS
# ------------------------------------------------------------

ARG METIS_VERSION=5.1.0
ARG METIS_SHA256=76faebe03f6c963127dbb73c13eab58c9a3faeae48779f049066a21c087c5db2

WORKDIR /tmp

RUN curl -fL \
    https://karypis.github.io/glaros/files/sw/metis/metis-${METIS_VERSION}.tar.gz \
    -o metis.tar.gz \
    && echo "${METIS_SHA256}  metis.tar.gz" | sha256sum -c - \
    && tar -xzf metis.tar.gz \
    && cd metis-${METIS_VERSION} \
    && make config prefix=${MPAS_PREFIX} \
    && make -j${BUILD_JOBS} \
    && make install \
    && for tool in gpmetis ndmetis mpmetis m2gmetis graphchk cmpfillin; do \
         command -v "${tool}"; \
       done \
    && gpmetis -help > /tmp/gpmetis-help.txt 2>&1 \
    && grep -F -- "-minconn" /tmp/gpmetis-help.txt \
    && grep -F -- "-contig" /tmp/gpmetis-help.txt \
    && grep -F -- "-niter" /tmp/gpmetis-help.txt \
    && test -f ${MPAS_PREFIX}/include/metis.h \
    && grep -F "#define IDXTYPEWIDTH 32" ${MPAS_PREFIX}/include/metis.h \
    && grep -F "#define REALTYPEWIDTH 32" ${MPAS_PREFIX}/include/metis.h \
    && grep -F "#define METIS_VER_MAJOR         5" ${MPAS_PREFIX}/include/metis.h \
    && grep -F "#define METIS_VER_MINOR         1" ${MPAS_PREFIX}/include/metis.h \
    && grep -F "#define METIS_VER_SUBMINOR      0" ${MPAS_PREFIX}/include/metis.h \
    && test -f ${MPAS_PREFIX}/lib/libmetis.a \
    && nm ${MPAS_PREFIX}/lib/libmetis.a | grep -F "METIS_PartGraphKway" \
    && graphchk graphs/4elt.graph \
    && gpmetis -minconn -contig -niter=200 graphs/4elt.graph 4 \
       > /tmp/gpmetis-sample.txt \
    && cat /tmp/gpmetis-sample.txt \
    && grep -F "METIS 5.0" /tmp/gpmetis-sample.txt \
    && test -s graphs/4elt.graph.part.4 \
    && rm -rf /tmp/metis*

WORKDIR /workspace

# ------------------------------------------------------------
# WPS / ungrib
# ------------------------------------------------------------

ARG WPS_VERSION=4.7.0
ARG WPS_TAG=v4.7.0
ARG WPS_COMMIT=5feccecd63384381b6942371c7a837f66e4ccb84
ARG WPS_SOURCE_URL=https://github.com/wrf-model/WPS/archive/refs/tags/v4.7.0.tar.gz
ARG WPS_SHA256=5232d20d7556338391b66aba45824d4fcd6c42712ebe9325f359f3c6cf043808

ENV WPS_PREFIX=/opt/wps-${WPS_VERSION}

RUN apt-get update \
    && apt-get install -y --no-install-recommends csh \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp

RUN curl -fL "${WPS_SOURCE_URL}" -o wps.tar.gz \
    && echo "${WPS_SHA256}  wps.tar.gz" | sha256sum -c - \
    && tar -xzf wps.tar.gz \
    && mv "WPS-${WPS_VERSION}" "${WPS_PREFIX}" \
    && cd "${WPS_PREFIX}" \
    && WPS_CONFIG_OPTION="$( \
         awk ' \
             BEGIN { \
                 option = 0; \
                 matches = 0; \
                 target = "Linux x86_64, gfortran"; \
             } \
             /^#ARCH/ && index($0, "Linux") && index($0, "x86_64") { \
                 label = $0; \
                 sub(/^#ARCH[[:space:]]*/, "", label); \
                 sub(/[[:space:]]*#.*/, "", label); \
                 if (index($0, "serial")) { \
                     option++; \
                     if (label == target) { \
                         selected = option; \
                         matches++; \
                     } \
                 } \
                 if (index($0, "dmpar")) { \
                     option++; \
                 } \
             } \
             END { \
                 if (matches != 1) exit 1; \
                 print selected; \
             } \
         ' arch/configure.defaults \
       )" \
    && test -n "${WPS_CONFIG_OPTION}" \
    && printf 'Selected WPS configure option: %s\n' "${WPS_CONFIG_OPTION}" \
    && printf '%s\n' "${WPS_CONFIG_OPTION}" \
       | ./configure --nowrf --build-grib2-libs \
    && grep -E \
       '^#.*Settings for Linux x86_64, gfortran[[:space:]]+[(]serial[)]' \
       configure.wps \
    && grep -E '^SFC[[:space:]]*=[[:space:]]*gfortran[[:space:]]*$' \
       configure.wps \
    && grep -E '^SCC[[:space:]]*=[[:space:]]*gcc[[:space:]]*$' \
       configure.wps \
    && grep -E '^FC[[:space:]]*=[[:space:]]*[$][(]SFC[)]' configure.wps \
    && grep -E '^CC[[:space:]]*=[[:space:]]*[$][(]SCC[)]' configure.wps \
    && test -z "$(grep -E '^CPPFLAGS.*-D_MPI' configure.wps)" \
    && grep -E '^WRF_DIR[[:space:]]*=[[:space:]]*none[[:space:]]*$' \
       configure.wps \
    && grep -E \
       "^INTERNAL_GRIB2_PATH[[:space:]]*=[[:space:]]*${WPS_PREFIX}/grib2[[:space:]]*$" \
       configure.wps \
    && grep -F -- '-DUSE_JPEG2000 -DUSE_PNG' configure.wps \
    && ./compile ungrib \
    && test -x ungrib.exe \
    && test -x ungrib/src/ungrib.exe \
    && test -d grib2/include \
    && test -f grib2/lib/libz.a \
    && test -e grib2/lib/libpng.a \
    && test -f grib2/lib/libjasper.a \
    && test -f ungrib/Variable_Tables/Vtable.ECMWF \
    && test -f ungrib/Variable_Tables/Vtable.ECMWF_sigma \
    && test -f ungrib/Variable_Tables/Vtable.ERA-interim.ml \
    && test -f ungrib/Variable_Tables/Vtable.ERA-interim.pl \
    && grep -F "WRF Pre-Processing System Version ${WPS_VERSION}" README \
    && file -L ungrib.exe \
    && ldd ungrib.exe \
    && test -z "$(ldd ungrib.exe | grep -F 'not found')" \
    && printf '%s\n' \
       "WPS_VERSION=${WPS_VERSION}" \
       "WPS_TAG=${WPS_TAG}" \
       "WPS_COMMIT=${WPS_COMMIT}" \
       "WPS_SOURCE_URL=${WPS_SOURCE_URL}" \
       "WPS_SHA256=${WPS_SHA256}" \
       "WPS_SHA256_ORIGIN=locally calculated from two independent downloads on 2026-08-05; no upstream SHA-256 was found" \
       > .mpas-era5-provenance \
    && ln -s "${WPS_PREFIX}" /opt/wps \
    && test "$(readlink /opt/wps)" = "${WPS_PREFIX}" \
    && test "$(readlink -f /opt/wps)" = "${WPS_PREFIX}" \
    && rm -f /tmp/wps.tar.gz

# ------------------------------------------------------------
# MPAS-Model / init_atmosphere
# ------------------------------------------------------------

ARG MPAS_VERSION=8.4.1
ARG MPAS_TAG=v8.4.1
ARG MPAS_COMMIT=91c5eac175eebeaf4206bacd5cb50c39dff3c152
ARG MPAS_SOURCE_URL=https://github.com/MPAS-Dev/MPAS-Model.git

ENV MPAS_MODEL_PREFIX=/opt/mpas-model-${MPAS_VERSION}

WORKDIR /opt

RUN git clone --branch "${MPAS_TAG}" --single-branch \
       "${MPAS_SOURCE_URL}" "${MPAS_MODEL_PREFIX}" \
    && cd "${MPAS_MODEL_PREFIX}" \
    && test "$(git rev-parse HEAD)" = "${MPAS_COMMIT}" \
    && test "$(git describe --tags --exact-match)" = "${MPAS_TAG}" \
    && grep -Fx "MPAS-v${MPAS_VERSION}" README.md \
    && bash -o pipefail -c \
       'make -j"${BUILD_JOBS}" gnu \
          CORE=init_atmosphere \
          USE_PIO2=true \
          MPAS_ESMF=embedded \
          2>&1 | tee /tmp/mpas-init-build.log' \
    && grep -Fx \
       "MPAS was built with default single-precision reals." \
       /tmp/mpas-init-build.log \
    && grep -Fx "Debugging is off." /tmp/mpas-init-build.log \
    && grep -Fx "Parallel version is on." /tmp/mpas-init-build.log \
    && grep -Fx "Using the mpi_f08 module." /tmp/mpas-init-build.log \
    && grep -Fx \
       "MPAS was built without OpenMP support." \
       /tmp/mpas-init-build.log \
    && grep -Fx \
       "MPAS was built without OpenMP-offload GPU support." \
       /tmp/mpas-init-build.log \
    && grep -Fx \
       "MPAS was built without OpenACC accelerator support." \
       /tmp/mpas-init-build.log \
    && grep -Fx \
       "MPAS was not linked with the MUSICA-Fortran library." \
       /tmp/mpas-init-build.log \
    && grep -Fx \
       "MPAS was NOT linked with the Scotch graph partitioning library." \
       /tmp/mpas-init-build.log \
    && grep -Fx "Using the PIO 2.x library." /tmp/mpas-init-build.log \
    && grep -Fx \
       "MPAS was built with the embedded ESMF timekeeping library." \
       /tmp/mpas-init-build.log \
    && awk ' \
         /^MPAS was built with default/ { capture = 1 } \
         capture { print } \
         capture && /^[*]+$/ { exit } \
       ' /tmp/mpas-init-build.log > .mpas-era5-build-summary \
    && test -x init_atmosphere_model \
    && test ! -e atmosphere_model \
    && test -f namelist.init_atmosphere \
    && test -f streams.init_atmosphere \
    && test -f default_inputs/namelist.init_atmosphere \
    && test -f default_inputs/streams.init_atmosphere \
    && cmp namelist.init_atmosphere \
       default_inputs/namelist.init_atmosphere \
    && cmp streams.init_atmosphere \
       default_inputs/streams.init_atmosphere \
    && test -f .build_opts.framework \
    && test -f .build_opts.init_atmosphere \
    && cmp .build_opts.framework .build_opts.init_atmosphere \
    && grep -Fx "FC=mpif90" .build_opts.init_atmosphere \
    && grep -Fx "CC=mpicc" .build_opts.init_atmosphere \
    && grep -Fx "CXX=mpicxx" .build_opts.init_atmosphere \
    && grep -F -- "-DSINGLE_PRECISION" .build_opts.init_atmosphere \
    && grep -F -- "-DMPAS_BUILD_TARGET=gnu" \
       .build_opts.init_atmosphere \
    && grep -F -- "-DMPAS_PIO_SUPPORT" .build_opts.init_atmosphere \
    && grep -F -- "-lpiof -lpioc" .build_opts.init_atmosphere \
    && grep -F -- "-lpnetcdf" .build_opts.init_atmosphere \
    && test -z "$( \
         grep -E \
           '(^|[[:space:]])-fopenmp([[:space:]]|$)|-DMPAS_OPENMP|-DMPAS_OPENACC|-DMPAS_OPENMP_OFFLOAD|-DMPAS_USE_MUSICA|-DMPAS_SCOTCH' \
           .build_opts.init_atmosphere \
       )" \
    && file init_atmosphere_model \
    && ldd init_atmosphere_model \
    && test -z "$(ldd init_atmosphere_model | grep -F 'not found')" \
    && nm init_atmosphere_model | grep -F "PIOc_Init_Intracomm" \
    && nm init_atmosphere_model | grep -F "ncmpi_create" \
    && printf '%s\n' \
       "MPAS_VERSION=${MPAS_VERSION}" \
       "MPAS_TAG=${MPAS_TAG}" \
       "MPAS_COMMIT=${MPAS_COMMIT}" \
       "MPAS_SOURCE_URL=${MPAS_SOURCE_URL}" \
       "MPAS_SOURCE_METHOD=git clone --branch ${MPAS_TAG} --single-branch; commit verified before build" \
       "MPAS_BUILD_COMMAND=make -j${BUILD_JOBS} gnu CORE=init_atmosphere USE_PIO2=true MPAS_ESMF=embedded" \
       "MPAS_BUILD_TARGET=gnu" \
       "MPAS_CORE=init_atmosphere" \
       "MPAS_PRECISION=single (release default)" \
       "MPAS_PIO_SELECTION=PIO 2.x auto-detected; USE_PIO2=true retained but deprecated and ignored by v8.4.1" \
       "MPAS_ESMF=embedded" \
       > .mpas-era5-provenance \
    && ln -s "${MPAS_MODEL_PREFIX}" /opt/mpas-model \
    && test "$(readlink /opt/mpas-model)" = "${MPAS_MODEL_PREFIX}" \
    && test "$(readlink -f /opt/mpas-model)" = "${MPAS_MODEL_PREFIX}" \
    && rm -f /tmp/mpas-init-build.log

# ------------------------------------------------------------
# MPAS-Model / atmosphere
# ------------------------------------------------------------

ARG MMM_PHYSICS_REPO_URL=https://github.com/NCAR/MMM-physics.git
ARG MMM_PHYSICS_TAG=20250616-MPASv8.3
ARG MMM_PHYSICS_COMMIT=a4baf7f3243d1db0dbc5f63473f895bdbdc05c30
ARG UGWP_REPO_URL=https://github.com/NOAA-GSL/UGWP.git
ARG UGWP_TAG=MPAS_20241223
ARG UGWP_COMMIT=c1c893edcf171af5639af60e3a3a528816f6cc2b
ARG MPAS_DATA_REPO_URL=https://github.com/MPAS-Dev/MPAS-Data.git
ARG MPAS_DATA_TAG=v8.2
ARG MPAS_DATA_COMMIT=c57dbc7be629802c6e848770a9e44b9bc602be41
ARG MPAS_DATA_REQUIRED_COMPATIBILITY=8.2

# manage_externals is a Python 3 program. Installing it here preserves all
# previously validated scientific and init_atmosphere layers in Docker cache.
RUN apt-get update \
    && apt-get install -y --no-install-recommends python3 \
    && python3 --version \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt

RUN cd "${MPAS_MODEL_PREFIX}" \
    && INIT_SHA256_BEFORE="$(sha256sum init_atmosphere_model \
         | awk '{print $1}')" \
    && FRAMEWORK_SHA256_BEFORE="$(sha256sum src/framework/libframework.a \
         | awk '{print $1}')" \
    && cmp .build_opts.framework .build_opts.init_atmosphere \
    && test ! -e atmosphere_model \
    && git clone --depth 1 --branch "${MMM_PHYSICS_TAG}" --single-branch \
       "${MMM_PHYSICS_REPO_URL}" \
       src/core_atmosphere/physics/physics_mmm \
    && test "$(git -C src/core_atmosphere/physics/physics_mmm \
         rev-parse HEAD)" = "${MMM_PHYSICS_COMMIT}" \
    && test "$(git -C src/core_atmosphere/physics/physics_mmm \
         describe --tags --exact-match)" = "${MMM_PHYSICS_TAG}" \
    && test -z "$(git -C src/core_atmosphere/physics/physics_mmm \
         symbolic-ref -q HEAD || true)" \
    && git -C src/core_atmosphere/physics/physics_mmm diff --quiet \
    && git -C src/core_atmosphere/physics/physics_mmm \
       diff --cached --quiet \
    && git clone --depth 1 --branch "${UGWP_TAG}" --single-branch \
       "${UGWP_REPO_URL}" \
       src/core_atmosphere/physics/physics_noaa/UGWP \
    && test "$(git -C src/core_atmosphere/physics/physics_noaa/UGWP \
         rev-parse HEAD)" = "${UGWP_COMMIT}" \
    && test "$(git -C src/core_atmosphere/physics/physics_noaa/UGWP \
         describe --tags --exact-match)" = "${UGWP_TAG}" \
    && test -z "$(git -C src/core_atmosphere/physics/physics_noaa/UGWP \
         symbolic-ref -q HEAD || true)" \
    && git -C src/core_atmosphere/physics/physics_noaa/UGWP diff --quiet \
    && git -C src/core_atmosphere/physics/physics_noaa/UGWP \
       diff --cached --quiet \
    && git clone --depth 1 --branch "${MPAS_DATA_TAG}" --single-branch \
       "${MPAS_DATA_REPO_URL}" /tmp/mpas-data \
    && test "$(git -C /tmp/mpas-data rev-parse HEAD)" = \
       "${MPAS_DATA_COMMIT}" \
    && test "$(git -C /tmp/mpas-data describe --tags --exact-match)" = \
       "${MPAS_DATA_TAG}" \
    && test -z "$(git -C /tmp/mpas-data symbolic-ref -q HEAD || true)" \
    && grep -Fx "${MPAS_DATA_REQUIRED_COMPATIBILITY}" \
       /tmp/mpas-data/atmosphere/physics_wrf/files/COMPATIBILITY \
    && mkdir -p src/core_atmosphere/physics/physics_wrf/files \
    && cp -a /tmp/mpas-data/atmosphere/physics_wrf/files/. \
       src/core_atmosphere/physics/physics_wrf/files/ \
    && test "$(find src/core_atmosphere/physics/physics_wrf/files \
         -maxdepth 1 -type f | wc -l)" -eq 16 \
    && ( \
         cd src/core_atmosphere/physics/physics_wrf/files \
         && sha256sum * | LC_ALL=C sort \
       ) > .mpas-era5-mpas-data.sha256 \
    && ( \
         cd src/core_atmosphere/physics \
         && ./checkout_data_files.sh \
       ) 2>&1 | tee /tmp/mpas-lookup-tables.log \
    && grep -F \
       "Compatible versions of WRF physics tables appear to already exist" \
       /tmp/mpas-lookup-tables.log \
    && bash -o pipefail -c \
       'make -j"${BUILD_JOBS}" gnu \
          CORE=atmosphere \
          USE_PIO2=true \
          MPAS_ESMF=embedded \
          2>&1 | tee /tmp/mpas-atmosphere-build.log' \
    && make --no-print-directory -s \
       -C src/core_atmosphere \
       -f build_options.mk \
       report_builds \
       > .mpas-era5-build-summary.atmosphere \
    && grep -Fx "CORE=atmosphere" \
       .mpas-era5-build-summary.atmosphere \
    && awk ' \
         /^MPAS was built with default/ { capture = 1 } \
         capture { print } \
         capture && /^[*]+$/ { exit } \
       ' /tmp/mpas-atmosphere-build.log \
       >> .mpas-era5-build-summary.atmosphere \
    && grep -Fx \
       "MPAS was built with default single-precision reals." \
       .mpas-era5-build-summary.atmosphere \
    && grep -Fx "Debugging is off." \
       .mpas-era5-build-summary.atmosphere \
    && grep -Fx "Parallel version is on." \
       .mpas-era5-build-summary.atmosphere \
    && grep -Fx "Using the mpi_f08 module." \
       .mpas-era5-build-summary.atmosphere \
    && grep -Fx \
       "MPAS was built without OpenMP support." \
       .mpas-era5-build-summary.atmosphere \
    && grep -Fx \
       "MPAS was built without OpenMP-offload GPU support." \
       .mpas-era5-build-summary.atmosphere \
    && grep -Fx \
       "MPAS was built without OpenACC accelerator support." \
       .mpas-era5-build-summary.atmosphere \
    && grep -Fx \
       "MPAS was not linked with the MUSICA-Fortran library." \
       .mpas-era5-build-summary.atmosphere \
    && grep -Fx \
       "MPAS was NOT linked with the Scotch graph partitioning library." \
       .mpas-era5-build-summary.atmosphere \
    && grep -Fx "Using the PIO 2.x library." \
       .mpas-era5-build-summary.atmosphere \
    && grep -Fx \
       "MPAS was built with the embedded ESMF timekeeping library." \
       .mpas-era5-build-summary.atmosphere \
    && test -x atmosphere_model \
    && test -x init_atmosphere_model \
    && for generated in namelist.atmosphere streams.atmosphere; do \
         test -s "${generated}"; \
         test -s "default_inputs/${generated}"; \
         cmp "${generated}" "default_inputs/${generated}"; \
       done \
    && for generated in \
         namelist.init_atmosphere streams.init_atmosphere; do \
         test -s "${generated}"; \
         test -s "default_inputs/${generated}"; \
         cmp "${generated}" "default_inputs/${generated}"; \
       done \
    && test -f .build_opts.framework \
    && test -f .build_opts.init_atmosphere \
    && test -f .build_opts.atmosphere \
    && cmp .build_opts.framework .build_opts.init_atmosphere \
    && cmp .build_opts.framework .build_opts.atmosphere \
    && grep -Fx "FC=mpif90" .build_opts.atmosphere \
    && grep -Fx "CC=mpicc" .build_opts.atmosphere \
    && grep -Fx "CXX=mpicxx" .build_opts.atmosphere \
    && grep -F -- "-O3" .build_opts.atmosphere \
    && grep -F -- "-DSINGLE_PRECISION" .build_opts.atmosphere \
    && grep -F -- "-D_MPI" .build_opts.atmosphere \
    && grep -F -- "-DMPAS_BUILD_TARGET=gnu" .build_opts.atmosphere \
    && grep -F -- "-DMPAS_PIO_SUPPORT" .build_opts.atmosphere \
    && grep -F -- "-lpiof -lpioc" .build_opts.atmosphere \
    && grep -F -- "-lpnetcdf" .build_opts.atmosphere \
    && test -z "$( \
         grep -E \
           '(^|[[:space:]])-fopenmp([[:space:]]|$)|-DMPAS_OPENMP|-DMPAS_OPENACC|-DMPAS_OPENMP_OFFLOAD|-DMPAS_USE_MUSICA|-DMPAS_SCOTCH|-fdefault-real-8|-fdefault-double-8' \
           .build_opts.atmosphere \
       )" \
    && test "$(sha256sum init_atmosphere_model | awk '{print $1}')" = \
       "${INIT_SHA256_BEFORE}" \
    && test "$(sha256sum src/framework/libframework.a | awk '{print $1}')" = \
       "${FRAMEWORK_SHA256_BEFORE}" \
    && test "$(git -C src/core_atmosphere/physics/physics_mmm \
         rev-parse HEAD)" = "${MMM_PHYSICS_COMMIT}" \
    && test "$(git -C src/core_atmosphere/physics/physics_noaa/UGWP \
         rev-parse HEAD)" = "${UGWP_COMMIT}" \
    && git -C src/core_atmosphere/physics/physics_mmm diff --quiet \
    && git -C src/core_atmosphere/physics/physics_mmm \
       diff --cached --quiet \
    && git -C src/core_atmosphere/physics/physics_noaa/UGWP diff --quiet \
    && git -C src/core_atmosphere/physics/physics_noaa/UGWP \
       diff --cached --quiet \
    && ( \
         cd src/core_atmosphere/physics/physics_wrf/files \
         && sha256sum -c "${MPAS_MODEL_PREFIX}/.mpas-era5-mpas-data.sha256" \
       ) \
    && file atmosphere_model \
    && ldd atmosphere_model \
    && test -z "$(ldd atmosphere_model | grep -F 'not found')" \
    && nm atmosphere_model | grep -F "PIOc_Init_Intracomm" \
    && nm atmosphere_model | grep -F "ncmpi_create" \
    && printf '%s\n' \
       "MPAS_ATMOSPHERE_BUILD_COMMAND=make -j${BUILD_JOBS} gnu CORE=atmosphere USE_PIO2=true MPAS_ESMF=embedded" \
       "MPAS_ATMOSPHERE_CORE=atmosphere" \
       "MPAS_ATMOSPHERE_EXECUTABLE=atmosphere_model" \
       "MPAS_ATMOSPHERE_FRAMEWORK_REUSE=compatible build options; framework archive content unchanged" \
       "MMM_PHYSICS_REPO_URL=${MMM_PHYSICS_REPO_URL}" \
       "MMM_PHYSICS_TAG=${MMM_PHYSICS_TAG}" \
       "MMM_PHYSICS_COMMIT=${MMM_PHYSICS_COMMIT}" \
       "MMM_PHYSICS_VERIFIED_ON=2026-08-05" \
       "UGWP_REPO_URL=${UGWP_REPO_URL}" \
       "UGWP_TAG=${UGWP_TAG}" \
       "UGWP_COMMIT=${UGWP_COMMIT}" \
       "UGWP_VERIFIED_ON=2026-08-05" \
       "MPAS_DATA_REPO_URL=${MPAS_DATA_REPO_URL}" \
       "MPAS_DATA_TAG=${MPAS_DATA_TAG}" \
       "MPAS_DATA_COMMIT=${MPAS_DATA_COMMIT}" \
       "MPAS_DATA_VERIFIED_ON=2026-08-05" \
       "MPAS_DATA_REQUIRED_COMPATIBILITY=${MPAS_DATA_REQUIRED_COMPATIBILITY}" \
       "MPAS_DATA_FILE_COUNT=16" \
       "MPAS_DATA_MANIFEST=.mpas-era5-mpas-data.sha256" \
       "MPAS_LOOKUP_TABLES=pre-fetched from pinned MPAS-Data; upstream checkout script confirmed compatibility and skipped download" \
       >> .mpas-era5-provenance \
    && rm -rf \
       /tmp/mpas-data \
       /tmp/mpas-atmosphere-build.log \
       /tmp/mpas-lookup-tables.log

WORKDIR /workspace

# Build the upstream GRIB1 inventory utility required to validate real ERA5
# messages. Keeping this as the final layer preserves the already validated
# WPS/ungrib and MPAS build layers in Docker cache.
RUN cd "${WPS_PREFIX}" \
    && ./compile g1print \
    && test -x ungrib/src/g1print.exe \
    && test -L util/g1print.exe \
    && test "$(readlink util/g1print.exe)" = \
       "../ungrib/src/g1print.exe" \
    && ln -s ungrib/src/g1print.exe g1print.exe \
    && test -x g1print.exe \
    && test "$(readlink g1print.exe)" = \
       "ungrib/src/g1print.exe" \
    && file -L g1print.exe \
    && ldd g1print.exe \
    && test -z "$(ldd g1print.exe | grep -F 'not found')" \
    && printf '%s\n' \
       "WPS_G1PRINT_BUILD_COMMAND=./compile g1print" \
       "WPS_G1PRINT_EXECUTABLE=g1print.exe" \
       >> .mpas-era5-provenance

CMD ["bash"]
