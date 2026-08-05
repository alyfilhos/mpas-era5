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

WORKDIR /workspace

CMD ["bash"]
