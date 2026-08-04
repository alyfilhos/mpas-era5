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

#Diretório da stack científica
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

CMD ["bash"]
