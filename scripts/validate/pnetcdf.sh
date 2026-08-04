#!/usr/bin/env bash

set -euo pipefail

readonly IMAGE="${PNETCDF_IMAGE:-mpas-era5:pnetcdf-1.15.0}"
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
readonly SOURCE_FILE="${PROJECT_ROOT}/tests/smoke/pnetcdf_mpi.f90"

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

        readonly source_file=/workspace/tests/smoke/pnetcdf_mpi.f90
        readonly temp_dir=/validation-output
        readonly executable=/tmp/pnetcdf_mpi

        echo "== Environment and MPI wrappers =="
        test "${PNETCDF:-}" = "/opt/mpas"
        for tool in mpicc mpicxx mpifort mpif77; do
            command -v "${tool}"
        done
        mpicc --showme
        mpifort --showme
        ompi_info --param io all
        ompi_info --param io all | grep -F "MCA io: romio321"

        echo "== Installed PnetCDF utilities and configuration =="
        for tool in pnetcdf_version pnetcdf-config ncmpidump; do
            command -v "${tool}"
        done
        pnetcdf_version
        pnetcdf-config --help
        pnetcdf-config --all

        case "$(pnetcdf-config --version)" in
            *1.15.0*) ;;
            *) echo "error: unexpected PnetCDF version" >&2; exit 1 ;;
        esac
        test "$(pnetcdf-config --prefix)" = "/opt/mpas"
        test "$(pnetcdf-config --has-fortran)" = "yes"
        test "$(pnetcdf-config --gio)" = "disabled"
        test -f "$(pnetcdf-config --libdir)/libpnetcdf.a"
        test -e "$(pnetcdf-config --libdir)/libpnetcdf.so"

        echo "== netCDF regression checks =="
        command -v nc-config
        command -v nf-config
        nc-config --version
        nf-config --version
        case "$(nc-config --version)" in
            *4.10.1*) ;;
            *) echo "error: unexpected netCDF-C version" >&2; exit 1 ;;
        esac
        case "$(nf-config --version)" in
            *4.6.3*) ;;
            *) echo "error: unexpected netCDF-Fortran version" >&2; exit 1 ;;
        esac

        echo "== Build installed-interface Fortran smoke test =="
        mpifort \
            -I"$(pnetcdf-config --includedir)" \
            "${source_file}" \
            -L"$(pnetcdf-config --libdir)" \
            -Wl,-rpath,"$(pnetcdf-config --libdir)" \
            -lpnetcdf \
            -o "${executable}"

        echo "== Executable and library linkage =="
        executable_ldd="$(ldd "${executable}")"
        printf "%s\n" "${executable_ldd}"
        grep -E "libpnetcdf\\.so.*=> /opt/mpas/lib/" <<<"${executable_ldd}"
        grep -E "libmpi(_usempif08|_mpifh)?\\.so" <<<"${executable_ldd}"

        library_ldd="$(ldd "$(pnetcdf-config --libdir)/libpnetcdf.so")"
        printf "%s\n" "${library_ldd}"
        grep -E "libmpi\\.so" <<<"${library_ldd}"

        echo "== Four-rank MPI + PnetCDF Fortran integration test =="
        timeout --signal=TERM --kill-after=10s 2m \
            mpirun --allow-run-as-root --oversubscribe --mca io romio321 -np 4 \
            "${executable}" "${temp_dir}/pnetcdf_mpi.nc"

        echo "== Generated CDF file =="
        ncmpidump -k "${temp_dir}/pnetcdf_mpi.nc"
        ncmpidump "${temp_dir}/pnetcdf_mpi.nc"
    '
