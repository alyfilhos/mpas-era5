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

CMD ["bash"]
