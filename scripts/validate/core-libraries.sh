#!/usr/bin/env bash

set -euo pipefail

readonly IMAGE="${SCIENTIFIC_IMAGE:-mpas-era5:mpas-atmosphere-8.4.1}"
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
readonly -a SOURCES=(
    tests/smoke/zlib_roundtrip.c
    tests/smoke/hdf5_roundtrip.c
    tests/smoke/netcdf_c_roundtrip.c
    tests/smoke/netcdf_fortran_roundtrip.f90
)

fail() { echo "error: $*" >&2; exit 1; }

[[ "$#" -eq 0 ]] || { echo "usage: $0" >&2; exit 2; }
for command_name in docker id; do
    command -v "${command_name}" >/dev/null 2>&1 || \
        fail "required command not found: ${command_name}"
done
for source_file in "${SOURCES[@]}"; do
    [[ -f "${PROJECT_ROOT}/${source_file}" && ! -L "${PROJECT_ROOT}/${source_file}" ]] || \
        fail "smoke-test source is absent or unsafe: ${PROJECT_ROOT}/${source_file}"
done
docker image inspect "${IMAGE}" >/dev/null 2>&1 || \
    fail "scientific image not found: ${IMAGE}; build it with: docker build --progress=plain --build-arg BUILD_JOBS=8 -t ${IMAGE} ${PROJECT_ROOT}"

docker run --rm \
    --network none \
    --read-only \
    --cap-drop ALL \
    --security-opt no-new-privileges \
    --user "$(id -u):$(id -g)" \
    --mount "type=bind,source=${PROJECT_ROOT},target=/workspace,readonly" \
    --tmpfs /validation-output:rw,exec,nosuid,nodev,size=128m \
    "${IMAGE}" \
    bash -euo pipefail -c '
        readonly prefix=/opt/mpas
        readonly source_root=/workspace/tests/smoke
        readonly output_root=/validation-output
        cd "${output_root}"

        echo "== GNU/OpenMPI environment =="
        gcc --version | head -n 1
        gfortran --version | head -n 1
        make --version | head -n 1
        mpiexec --version | head -n 1
        test "${MPAS_PREFIX:-}" = "${prefix}"
        test "${NETCDF:-}" = "${prefix}"

        echo "== Installed library configuration =="
        h5cc -showconfig | grep -F "HDF5 Version: 1.14.6"
        test "$(nc-config --version)" = "netCDF 4.10.1"
        test "$(nf-config --version)" = "netCDF-Fortran 4.6.3"
        test "$(nc-config --has-nc4)" = "yes"
        nc-config --all
        nf-config --all

        echo "== zlib installed-interface round trip =="
        gcc -std=c11 -O2 -Wall -Wextra -Werror \
            -I"${prefix}/include" "${source_root}/zlib_roundtrip.c" \
            -L"${prefix}/lib" -Wl,-rpath,"${prefix}/lib" -lz \
            -o "${output_root}/zlib_roundtrip"
        ldd "${output_root}/zlib_roundtrip" | grep -E "libz\\.so.*=> /opt/mpas/lib/"
        "${output_root}/zlib_roundtrip"

        echo "== HDF5 + zlib compressed dataset round trip =="
        h5cc -shlib -std=c11 -O2 -Wall -Wextra -Werror \
            "${source_root}/hdf5_roundtrip.c" \
            -o "${output_root}/hdf5_roundtrip"
        ldd "${output_root}/hdf5_roundtrip" | grep -E "libhdf5\\.so.*=> /opt/mpas/lib/"
        ldd "${prefix}/lib/libhdf5.so" | grep -E "libz\\.so.*=> /opt/mpas/lib/"
        "${output_root}/hdf5_roundtrip" "${output_root}/hdf5-smoke.h5"
        h5dump -H -p "${output_root}/hdf5-smoke.h5" | grep -F "COMPRESSION DEFLATE { LEVEL 6 }"

        echo "== netCDF-C + HDF5 + zlib round trip =="
        read -r -a nc_cflags <<< "$(nc-config --cflags)"
        read -r -a nc_libs <<< "$(nc-config --libs)"
        gcc -std=c11 -O2 -Wall -Wextra -Werror \
            "${nc_cflags[@]}" "${source_root}/netcdf_c_roundtrip.c" \
            "${nc_libs[@]}" -Wl,-rpath,"${prefix}/lib" \
            -o "${output_root}/netcdf_c_roundtrip"
        ldd "${output_root}/netcdf_c_roundtrip" | grep -E "libnetcdf\\.so.*=> /opt/mpas/lib/"
        ldd "${prefix}/lib/libnetcdf.so" | grep -E "libhdf5(_hl)?\\.so.*=> /opt/mpas/lib/"
        "${output_root}/netcdf_c_roundtrip" "${output_root}/netcdf-c-smoke.nc"
        test "$(ncdump -k "${output_root}/netcdf-c-smoke.nc")" = "netCDF-4"
        ncdump -v value "${output_root}/netcdf-c-smoke.nc"

        echo "== netCDF-Fortran -> netCDF-C -> HDF5/zlib round trip =="
        read -r -a nf_fflags <<< "$(nf-config --fflags)"
        read -r -a nf_flibs <<< "$(nf-config --flibs)"
        gfortran -std=f2008 -O2 -Wall -Wextra -Werror \
            "${nf_fflags[@]}" "${source_root}/netcdf_fortran_roundtrip.f90" \
            "${nf_flibs[@]}" -Wl,-rpath,"${prefix}/lib" \
            -o "${output_root}/netcdf_fortran_roundtrip"
        ldd "${output_root}/netcdf_fortran_roundtrip" | grep -E "libnetcdff\\.so.*=> /opt/mpas/lib/"
        ldd "${output_root}/netcdf_fortran_roundtrip" | grep -E "libnetcdf\\.so.*=> /opt/mpas/lib/"
        "${output_root}/netcdf_fortran_roundtrip" "${output_root}/netcdf-fortran-smoke.nc"
        test "$(ncdump -k "${output_root}/netcdf-fortran-smoke.nc")" = "netCDF-4"
        ncdump -v value "${output_root}/netcdf-fortran-smoke.nc"

        echo "environment_smoke=PASS"
        echo "zlib_smoke=PASS"
        echo "hdf5_smoke=PASS"
        echo "netcdf_c_smoke=PASS"
        echo "netcdf_fortran_smoke=PASS"
        echo "core_libraries_validation=PASS"
    '
