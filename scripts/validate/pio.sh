#!/usr/bin/env bash

set -euo pipefail

readonly IMAGE="${PIO_IMAGE:-mpas-era5:pio-2.7.0}"
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
readonly SOURCE_FILE="${PROJECT_ROOT}/tests/smoke/pio_pnetcdf.c"

if ! command -v docker >/dev/null 2>&1; then
    echo "error: docker was not found in PATH" >&2
    exit 1
fi

if [[ ! -f "${SOURCE_FILE}" ]]; then
    echo "error: smoke-test source not found: ${SOURCE_FILE}" >&2
    exit 1
fi

if ! docker image inspect "${IMAGE}" >/dev/null 2>&1; then
    echo "error: Docker image not found or Docker is not accessible: ${IMAGE}" >&2
    echo "build it with:" >&2
    echo "  docker build --progress=plain --build-arg BUILD_JOBS=8 -t ${IMAGE} ${PROJECT_ROOT}" >&2
    exit 1
fi

docker run --rm \
    --mount "type=bind,source=${PROJECT_ROOT},target=/workspace,readonly" \
    --tmpfs /validation-output:rw,nosuid,nodev,size=64m \
    "${IMAGE}" \
    bash -lc '
        set -euo pipefail

        readonly source_file=/workspace/tests/smoke/pio_pnetcdf.c
        readonly output_dir=/validation-output
        readonly executable=/tmp/pio_pnetcdf
        readonly pio_prefix=/opt/mpas

        echo "== Environment and preserved dependency versions =="
        test "${PIO:-}" = "${pio_prefix}"
        test "${PNETCDF:-}" = "${pio_prefix}"
        test "${NETCDF:-}" = "${pio_prefix}"
        command -v mpicc
        command -v mpiexec
        ompi_info --param io all | grep -F "MCA io: romio321"
        case "$(nc-config --version)" in
            *4.10.1*) ;;
            *) echo "error: unexpected netCDF-C version" >&2; exit 1 ;;
        esac
        case "$(nf-config --version)" in
            *4.6.3*) ;;
            *) echo "error: unexpected netCDF-Fortran version" >&2; exit 1 ;;
        esac
        case "$(pnetcdf-config --version)" in
            *1.15.0*) ;;
            *) echo "error: unexpected PnetCDF version" >&2; exit 1 ;;
        esac

        echo "== Installed PIO configuration =="
        readonly settings="${pio_prefix}/lib/libpio.settings"
        test -f "${settings}"
        test -f "${pio_prefix}/include/pio.h"
        test -f "${pio_prefix}/include/pio.mod"
        test -f "${pio_prefix}/lib/libpioc.a"
        test -f "${pio_prefix}/lib/libpiof.a"
        test -f "${pio_prefix}/lib/cmake/PIO/PIOConfig.cmake"
        cat "${settings}"
        grep -F "2.7.0" "${settings}"
        grep -F "PnetCDF Support:" "${settings}" | grep -F "yes"
        grep -F "NetCDF/HDF5 Par I/O:" "${settings}" | grep -F "no"

        echo "== Build installed-interface C smoke test =="
        mpicc \
            -std=c99 \
            -Wall \
            -Wextra \
            -I"${pio_prefix}/include" \
            "${source_file}" \
            "${pio_prefix}/lib/libpioc.a" \
            -L"${pio_prefix}/lib" \
            -Wl,-rpath,"${pio_prefix}/lib" \
            -lpnetcdf \
            -lnetcdf \
            -o "${executable}"

        echo "== Executable symbols and dynamic linkage =="
        nm "${executable}" | grep -F "PIOc_Init_Intracomm"
        executable_ldd="$(ldd "${executable}")"
        printf "%s\n" "${executable_ldd}"
        grep -E "libpnetcdf\\.so.*=> /opt/mpas/lib/" <<<"${executable_ldd}"
        grep -E "libnetcdf\\.so.*=> /opt/mpas/lib/" <<<"${executable_ldd}"
        grep -E "libmpi\\.so" <<<"${executable_ldd}"

        echo "== Four-rank PIO + PnetCDF test with default OMPIO =="
        timeout --signal=TERM --kill-after=10s 2m \
            mpiexec --allow-run-as-root --oversubscribe -n 4 \
            "${executable}" "${output_dir}/pio-ompio.nc"

        echo "== Four-rank PIO + PnetCDF test with local ROMIO =="
        timeout --signal=TERM --kill-after=10s 2m \
            mpiexec --allow-run-as-root --oversubscribe --mca io romio321 -n 4 \
            "${executable}" "${output_dir}/pio-romio.nc"

        echo "== Generated PnetCDF CDF-2 file =="
        test "$(ncmpidump -k "${output_dir}/pio-romio.nc")" = "64-bit offset"
        ncmpidump "${output_dir}/pio-romio.nc"
    '
