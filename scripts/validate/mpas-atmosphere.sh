#!/usr/bin/env bash

set -euo pipefail

readonly IMAGE="${MPAS_ATMOSPHERE_IMAGE:-mpas-era5:mpas-atmosphere-8.4.1}"
readonly MPAS_PREFIX=/opt/mpas
readonly MODEL_PREFIX=/opt/mpas-model-8.4.1
readonly MPAS_COMMIT=91c5eac175eebeaf4206bacd5cb50c39dff3c152
readonly MMM_COMMIT=a4baf7f3243d1db0dbc5f63473f895bdbdc05c30
readonly UGWP_COMMIT=c1c893edcf171af5639af60e3a3a528816f6cc2b
readonly MPAS_DATA_COMMIT=c57dbc7be629802c6e848770a9e44b9bc602be41

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
        readonly mpas_commit='"${MPAS_COMMIT}"'
        readonly mmm_commit='"${MMM_COMMIT}"'
        readonly ugwp_commit='"${UGWP_COMMIT}"'
        readonly mpas_data_commit='"${MPAS_DATA_COMMIT}"'
        readonly atmosphere_executable=${model_prefix}/atmosphere_model
        readonly init_executable=${model_prefix}/init_atmosphere_model
        readonly provenance=${model_prefix}/.mpas-era5-provenance
        readonly summary=${model_prefix}/.mpas-era5-build-summary.atmosphere
        readonly build_opts=${model_prefix}/.build_opts.atmosphere
        readonly lookup_dir=${model_prefix}/src/core_atmosphere/physics/physics_wrf/files
        readonly lookup_manifest=${model_prefix}/.mpas-era5-mpas-data.sha256
        readonly mmm_path=${model_prefix}/src/core_atmosphere/physics/physics_mmm
        readonly ugwp_path=${model_prefix}/src/core_atmosphere/physics/physics_noaa/UGWP

        verify_external() {
            local path=$1
            local expected_tag=$2
            local expected_commit=$3

            test -d "${path}/.git"
            test "$(git -C "${path}" rev-parse HEAD)" = "${expected_commit}"
            test "$(git -C "${path}" describe --tags --exact-match)" = \
                 "${expected_tag}"
            test -z "$(git -C "${path}" symbolic-ref -q HEAD || true)"
            git -C "${path}" diff --quiet
            git -C "${path}" diff --cached --quiet
        }

        echo "== Versioned layout and source provenance =="
        test -d "${model_prefix}"
        test -d "${model_prefix}/.git"
        test -L /opt/mpas-model
        test "$(readlink /opt/mpas-model)" = "${model_prefix}"
        test "$(readlink -f /opt/mpas-model)" = "${model_prefix}"
        test "$(git -C "${model_prefix}" rev-parse HEAD)" = "${mpas_commit}"
        test "$(git -C "${model_prefix}" describe --tags --exact-match)" = \
             "v8.4.1"
        grep -Fx "MPAS-v8.4.1" "${model_prefix}/README.md"

        test -f "${provenance}"
        while IFS= read -r expected; do
            grep -Fx "${expected}" "${provenance}"
        done <<"EOF"
MPAS_VERSION=8.4.1
MPAS_TAG=v8.4.1
MPAS_COMMIT=91c5eac175eebeaf4206bacd5cb50c39dff3c152
MPAS_ATMOSPHERE_BUILD_COMMAND=make -j8 gnu CORE=atmosphere USE_PIO2=true MPAS_ESMF=embedded
MPAS_ATMOSPHERE_CORE=atmosphere
MPAS_ATMOSPHERE_EXECUTABLE=atmosphere_model
MPAS_ATMOSPHERE_FRAMEWORK_REUSE=compatible build options; framework archive content unchanged
MMM_PHYSICS_REPO_URL=https://github.com/NCAR/MMM-physics.git
MMM_PHYSICS_TAG=20250616-MPASv8.3
MMM_PHYSICS_COMMIT=a4baf7f3243d1db0dbc5f63473f895bdbdc05c30
MMM_PHYSICS_VERIFIED_ON=2026-08-05
UGWP_REPO_URL=https://github.com/NOAA-GSL/UGWP.git
UGWP_TAG=MPAS_20241223
UGWP_COMMIT=c1c893edcf171af5639af60e3a3a528816f6cc2b
UGWP_VERIFIED_ON=2026-08-05
MPAS_DATA_REPO_URL=https://github.com/MPAS-Dev/MPAS-Data.git
MPAS_DATA_TAG=v8.2
MPAS_DATA_COMMIT=c57dbc7be629802c6e848770a9e44b9bc602be41
MPAS_DATA_VERIFIED_ON=2026-08-05
MPAS_DATA_REQUIRED_COMPATIBILITY=8.2
MPAS_DATA_FILE_COUNT=16
MPAS_DATA_MANIFEST=.mpas-era5-mpas-data.sha256
MPAS_LOOKUP_TABLES=pre-fetched from pinned MPAS-Data; upstream checkout script confirmed compatibility and skipped download
EOF

        echo "== Atmosphere and preserved init artifacts =="
        test -x "${atmosphere_executable}"
        test -x /opt/mpas-model/atmosphere_model
        test -x "${init_executable}"
        test -x /opt/mpas-model/init_atmosphere_model

        for generated in namelist.atmosphere streams.atmosphere; do
            test -s "${model_prefix}/${generated}"
            test -s "${model_prefix}/default_inputs/${generated}"
            cmp "${model_prefix}/${generated}" \
                "${model_prefix}/default_inputs/${generated}"
        done
        for generated in \
            namelist.init_atmosphere streams.init_atmosphere; do
            test -s "${model_prefix}/${generated}"
            test -s "${model_prefix}/default_inputs/${generated}"
            cmp "${model_prefix}/${generated}" \
                "${model_prefix}/default_inputs/${generated}"
        done
        grep -F "config_dt" "${model_prefix}/namelist.atmosphere"
        grep -F "<streams>" "${model_prefix}/streams.atmosphere"
        grep -F "config_init_case" \
            "${model_prefix}/namelist.init_atmosphere"

        echo "== Compiler, core, precision, MPI and feature configuration =="
        test -s "${summary}"
        grep -Fx "CORE=atmosphere" "${summary}"
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

        test -f "${build_opts}"
        test -f "${model_prefix}/.build_opts.framework"
        test -f "${model_prefix}/.build_opts.init_atmosphere"
        cmp "${build_opts}" "${model_prefix}/.build_opts.framework"
        cmp "${build_opts}" "${model_prefix}/.build_opts.init_atmosphere"
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

        echo "== Pinned atmosphere externals =="
        verify_external "${mmm_path}" "20250616-MPASv8.3" "${mmm_commit}"
        verify_external "${ugwp_path}" "MPAS_20241223" "${ugwp_commit}"

        echo "== Pinned and compatible physics lookup tables =="
        test -d "${lookup_dir}"
        test -s "${lookup_manifest}"
        test "$(find "${lookup_dir}" -maxdepth 1 -type f | wc -l)" -eq 16
        for lookup_file in \
            CAM_ABS_DATA.DBL \
            CAM_AEROPT_DATA.DBL \
            CCN_ACTIVATE_DATA \
            COMPATIBILITY \
            GENPARM.TBL \
            LANDUSE.TBL \
            OZONE_DAT.TBL \
            OZONE_LAT.TBL \
            OZONE_PLEV.TBL \
            RRTMG_LW_DATA \
            RRTMG_LW_DATA.DBL \
            RRTMG_SW_DATA \
            RRTMG_SW_DATA.DBL \
            SOILPARM.TBL \
            VEGPARM.TBL \
            VERSION; do
            test -s "${lookup_dir}/${lookup_file}"
        done
        grep -Fx "8.2" "${lookup_dir}/COMPATIBILITY"
        (
            cd "${lookup_dir}"
            sha256sum -c "${lookup_manifest}"
        )
        lookup_output=$(
            cd "${model_prefix}/src/core_atmosphere/physics"
            ./checkout_data_files.sh
        )
        printf "%s\n" "${lookup_output}"
        grep -F \
            "Compatible versions of WRF physics tables appear to already exist" \
            <<<"${lookup_output}"
        test "${mpas_data_commit}" = \
             "c57dbc7be629802c6e848770a9e44b9bc602be41"

        echo "== Executable format and dynamic linkage =="
        file_output=$(file "${atmosphere_executable}")
        printf "%s\n" "${file_output}"
        grep -F "ELF 64-bit LSB pie executable, x86-64" \
            <<<"${file_output}"
        grep -F "dynamically linked" <<<"${file_output}"

        ldd_output=$(ldd "${atmosphere_executable}")
        printf "%s\n" "${ldd_output}"
        test -z "$(grep -F "not found" <<<"${ldd_output}")"
        grep -F "libnetcdf.so" <<<"${ldd_output}" \
            | grep -F "${mpas_prefix}/lib/"
        grep -F "libpnetcdf.so" <<<"${ldd_output}" \
            | grep -F "${mpas_prefix}/lib/"
        grep -F "libmpi_usempif08.so" <<<"${ldd_output}"
        grep -F "libmpi.so" <<<"${ldd_output}"
        grep -F "libgfortran.so" <<<"${ldd_output}"
        test -z "$(grep -F "libgomp.so" <<<"${ldd_output}")"

        echo "== Static PIO2 and PnetCDF evidence =="
        nm_output=$(nm "${atmosphere_executable}")
        grep -E "[[:space:]]T[[:space:]]PIOc_Init_Intracomm$" \
            <<<"${nm_output}"
        grep -E "[[:space:]]T[[:space:]]PIOc_(createfile|openfile)$" \
            <<<"${nm_output}"
        grep -E "[[:space:]]U[[:space:]]ncmpi_(create|open)$" \
            <<<"${nm_output}"

        echo "== Scientific-stack interfaces consumed by atmosphere =="
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
        test -f \
            "${model_prefix}/src/external/esmf_time_f90/libesmf_time.a"

        printf "%s\n" \
            "BUILD: MPAS-Model 8.4.1 atmosphere, GNU/MPI, single precision, PIO2, embedded ESMF: PASS" \
            "STRUCTURAL/INSTALL SMOKE: provenance, defaults, externals, lookup tables, build options, file, ldd and interfaces: PASS" \
            "FUNCTIONAL: init.nc + mesh + partition -> atmosphere_model: PENDING" \
            "SCIENTIFIC: first forecast and field evaluation: PENDING"
    '
