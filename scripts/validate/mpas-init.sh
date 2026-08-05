#!/usr/bin/env bash

set -euo pipefail

readonly IMAGE="${MPAS_INIT_IMAGE:-mpas-era5:mpas-init-8.4.1}"
readonly MPAS_PREFIX=/opt/mpas
readonly MODEL_PREFIX=/opt/mpas-model-8.4.1
readonly EXPECTED_COMMIT=91c5eac175eebeaf4206bacd5cb50c39dff3c152

if ! command -v docker >/dev/null 2>&1; then
    echo "error: docker was not found in PATH" >&2
    exit 1
fi

if ! docker image inspect "${IMAGE}" >/dev/null 2>&1; then
    echo "error: Docker image not found or Docker is not accessible: ${IMAGE}" >&2
    echo "build it with:" >&2
    echo "  docker build --progress=plain --build-arg BUILD_JOBS=8 -t ${IMAGE} ." >&2
    exit 1
fi

docker run --rm \
    --network none \
    --read-only \
    --tmpfs /tmp:rw,nosuid,nodev,size=16m \
    "${IMAGE}" \
    bash -euo pipefail -c '
        readonly mpas_prefix='"${MPAS_PREFIX}"'
        readonly model_prefix='"${MODEL_PREFIX}"'
        readonly expected_commit='"${EXPECTED_COMMIT}"'
        readonly executable=${model_prefix}/init_atmosphere_model
        readonly provenance=${model_prefix}/.mpas-era5-provenance
        readonly summary=${model_prefix}/.mpas-era5-build-summary
        readonly build_opts=${model_prefix}/.build_opts.init_atmosphere

        echo "== Versioned layout and source provenance =="
        test -d "${model_prefix}"
        test -d "${model_prefix}/.git"
        test -L /opt/mpas-model
        test "$(readlink /opt/mpas-model)" = "${model_prefix}"
        test "$(readlink -f /opt/mpas-model)" = "${model_prefix}"
        test "$(git -C "${model_prefix}" rev-parse HEAD)" = \
             "${expected_commit}"
        test "$(git -C "${model_prefix}" describe --tags --exact-match)" = \
             "v8.4.1"
        grep -Fx "MPAS-v8.4.1" "${model_prefix}/README.md"

        test -f "${provenance}"
        grep -Fx "MPAS_VERSION=8.4.1" "${provenance}"
        grep -Fx "MPAS_TAG=v8.4.1" "${provenance}"
        grep -Fx "MPAS_COMMIT=${expected_commit}" "${provenance}"
        grep -Fx \
            "MPAS_SOURCE_URL=https://github.com/MPAS-Dev/MPAS-Model.git" \
            "${provenance}"
        grep -Fx \
            "MPAS_SOURCE_METHOD=git clone --branch v8.4.1 --single-branch; commit verified before build" \
            "${provenance}"
        grep -Fx \
            "MPAS_BUILD_COMMAND=make -j8 gnu CORE=init_atmosphere USE_PIO2=true MPAS_ESMF=embedded" \
            "${provenance}"
        grep -Fx "MPAS_BUILD_TARGET=gnu" "${provenance}"
        grep -Fx "MPAS_CORE=init_atmosphere" "${provenance}"
        grep -Fx "MPAS_PRECISION=single (release default)" "${provenance}"
        grep -Fx "MPAS_ESMF=embedded" "${provenance}"

        echo "== Built core and generated defaults =="
        test -x "${executable}"
        test -x /opt/mpas-model/init_atmosphere_model
        test ! -e "${model_prefix}/atmosphere_model"
        test ! -e "${model_prefix}/namelist.atmosphere"
        test ! -e "${model_prefix}/streams.atmosphere"

        for generated in namelist.init_atmosphere streams.init_atmosphere; do
            test -s "${model_prefix}/${generated}"
            test -s "${model_prefix}/default_inputs/${generated}"
            cmp "${model_prefix}/${generated}" \
                "${model_prefix}/default_inputs/${generated}"
        done
        grep -F "config_init_case" \
            "${model_prefix}/namelist.init_atmosphere"
        grep -F "<streams>" "${model_prefix}/streams.init_atmosphere"

        echo "== Compiler, precision, MPI and feature configuration =="
        test -f "${build_opts}"
        test -f "${model_prefix}/.build_opts.framework"
        cmp "${build_opts}" "${model_prefix}/.build_opts.framework"
        grep -Fx "FC=mpif90" "${build_opts}"
        grep -Fx "CC=mpicc" "${build_opts}"
        grep -Fx "CXX=mpicxx" "${build_opts}"
        grep -Fx "SFC=gfortran" "${build_opts}"
        grep -Fx "SCC=gcc" "${build_opts}"
        grep -F -- "-O3" "${build_opts}"
        grep -F -- "-DSINGLE_PRECISION" "${build_opts}"
        grep -F -- "-D_MPI" "${build_opts}"
        grep -F -- "-DMPAS_BUILD_TARGET=gnu" "${build_opts}"
        grep -F -- "-DMPAS_PIO_SUPPORT" "${build_opts}"
        grep -F -- "-lpiof -lpioc" "${build_opts}"
        grep -F -- "-lnetcdff -lnetcdf" "${build_opts}"
        grep -F -- "-lpnetcdf" "${build_opts}"
        grep -Fx "OPENMP=" "${build_opts}"
        grep -Fx "OPENMP_OFFLOAD=" "${build_opts}"
        grep -Fx "OPENACC=" "${build_opts}"
        test -z "$(
            grep -E \
                "(^|[[:space:]])-fopenmp([[:space:]]|$)|-DMPAS_OPENMP|-DMPAS_OPENACC|-DMPAS_OPENMP_OFFLOAD|-DMPAS_USE_MUSICA|-DMPAS_SCOTCH|-fdefault-real-8|-fdefault-double-8" \
                "${build_opts}"
        )"

        test -s "${summary}"
        while IFS= read -r expected; do
            grep -Fx "${expected}" "${summary}"
        done <<"EOF"
MPAS was built with default single-precision reals.
Debugging is off.
Parallel version is on.
Using the mpi_f08 module.
Papi libraries are off.
TAU Hooks are off.
MPAS was built without OpenMP support.
MPAS was built without OpenMP-offload GPU support.
MPAS was built without OpenACC accelerator support.
MPAS was not linked with the MUSICA-Fortran library.
MPAS was NOT linked with the Scotch graph partitioning library.
Position-dependent code was generated.
MPAS was built with .F files.
The native timer interface is being used
Using the PIO 2.x library.
MPAS was built with the embedded ESMF timekeeping library.
EOF

        echo "== Executable format and dynamic linkage =="
        file_output=$(file "${executable}")
        printf "%s\n" "${file_output}"
        grep -F "ELF 64-bit LSB pie executable, x86-64" <<<"${file_output}"
        grep -F "dynamically linked" <<<"${file_output}"

        ldd_output=$(ldd "${executable}")
        printf "%s\n" "${ldd_output}"
        test -z "$(grep -F "not found" <<<"${ldd_output}")"
        grep -F "libnetcdf.so" <<<"${ldd_output}" | grep -F "${mpas_prefix}/lib/"
        grep -F "libpnetcdf.so" <<<"${ldd_output}" | grep -F "${mpas_prefix}/lib/"
        grep -F "libmpi_usempif08.so" <<<"${ldd_output}"
        grep -F "libmpi.so" <<<"${ldd_output}"
        grep -F "libgfortran.so" <<<"${ldd_output}"
        test -z "$(grep -F "libgomp.so" <<<"${ldd_output}")"

        echo "== Static PIO2 and PnetCDF evidence =="
        nm_output=$(nm "${executable}")
        grep -E "[[:space:]]T[[:space:]]PIOc_Init_Intracomm$" \
            <<<"${nm_output}"
        grep -E "[[:space:]]T[[:space:]]PIOc_(createfile|openfile)$" \
            <<<"${nm_output}"
        grep -E "[[:space:]]U[[:space:]]ncmpi_(create|open)$" \
            <<<"${nm_output}"

        echo "== Scientific-stack interfaces consumed by MPAS =="
        test "${NETCDF:-}" = "${mpas_prefix}"
        test "${PNETCDF:-}" = "${mpas_prefix}"
        test "${PIO:-}" = "${mpas_prefix}"
        for interface in \
            include/netcdf.h \
            include/netcdf.mod \
            include/pnetcdf.h \
            include/pnetcdf.mod \
            include/pio.h \
            include/pio.mod \
            lib/libnetcdf.so \
            lib/libnetcdff.so \
            lib/libpnetcdf.so \
            lib/libpioc.a \
            lib/libpiof.a \
            lib/libpio.settings; do
            test -e "${mpas_prefix}/${interface}"
        done
        grep -F "PIO Version:" "${mpas_prefix}/lib/libpio.settings" \
            | grep -F "2.7.0"
        grep -F "PnetCDF Support:" "${mpas_prefix}/lib/libpio.settings" \
            | grep -F "yes"
        test -f "${model_prefix}/src/external/esmf_time_f90/libesmf_time.a"

        printf "%s\n" \
            "BUILD: MPAS-Model 8.4.1 init_atmosphere, GNU/MPI, single precision, PIO2, embedded ESMF: PASS" \
            "STRUCTURAL/INSTALL SMOKE: provenance, defaults, build options, file, ldd and interfaces: PASS" \
            "FUNCTIONAL: mesh -> init_atmosphere: PENDING" \
            "SCIENTIFIC/REAL-DATA: mesh + static data + WPS/ERA5 -> init.nc: PENDING"
    '
