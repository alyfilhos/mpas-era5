#!/usr/bin/env bash

set -euo pipefail

readonly IMAGE="${STATIC_IMAGE:-mpas-era5:mpas-atmosphere-8.4.1}"
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
readonly STATIC_DIR="${1:-${PROJECT_ROOT}/data/cases/first-global-240km/static}"
readonly STATIC_FILE=x1.10242.static.nc
readonly LOG_FILE=log.init_atmosphere.0000.out
readonly VALIDATOR_SOURCE=tests/smoke/static_netcdf.c

if [[ "$#" -gt 1 ]]; then
    echo "usage: $0 [static-directory]" >&2
    exit 2
fi
for command_name in awk docker grep id sha256sum wc; do
    if ! command -v "${command_name}" >/dev/null 2>&1; then
        echo "error: required command not found: ${command_name}" >&2
        exit 1
    fi
done
for artifact in "${STATIC_FILE}" "${LOG_FILE}"; do
    if [[ ! -f "${STATIC_DIR}/${artifact}" || -L "${STATIC_DIR}/${artifact}" ]]; then
        echo "error: required regular file not found: ${STATIC_DIR}/${artifact}" >&2
        exit 1
    fi
done
if [[ ! -f "${PROJECT_ROOT}/${VALIDATOR_SOURCE}" ]]; then
    echo "error: validator source is absent: ${PROJECT_ROOT}/${VALIDATOR_SOURCE}" >&2
    exit 1
fi
if ! docker image inspect "${IMAGE}" >/dev/null 2>&1; then
    echo "error: Docker image not found or Docker is not accessible: ${IMAGE}" >&2
    exit 1
fi

echo "== Offline/read-only NetCDF and physical-field validation =="
docker run --rm -i \
    --network none \
    --read-only \
    --cap-drop ALL \
    --security-opt no-new-privileges \
    --user "$(id -u):$(id -g)" \
    --mount "type=bind,source=${STATIC_DIR},target=/static,readonly" \
    --mount "type=bind,source=${PROJECT_ROOT},target=/source,readonly" \
    --tmpfs /tmp:rw,exec,nosuid,nodev,size=128m \
    --env "STATIC_FILE=${STATIC_FILE}" \
    --env "VALIDATOR_SOURCE=${VALIDATOR_SOURCE}" \
    "${IMAGE}" \
    bash -s <<'CONTAINER_SCRIPT'
set -euo pipefail

readonly static_path=/static/${STATIC_FILE}
readonly header=/tmp/static-header.txt
readonly validator=/tmp/static_netcdf

printf 'netcdf_format=%s\n' "$(ncdump -k "${static_path}")"
ncdump -h "${static_path}" > "${header}"
grep -Eq '^[[:space:]]*Time = UNLIMITED ; // \(1 currently\)' "${header}"
grep -Eq '^[[:space:]]*nCells = 10242 ;' "${header}"
grep -Eq '^[[:space:]]*nMonths = 12 ;' "${header}"

read -r -a netcdf_cflags <<< "$(nc-config --cflags)"
read -r -a netcdf_libs <<< "$(nc-config --libs)"
cc -std=c11 -O2 -Wall -Wextra -Werror \
    "${netcdf_cflags[@]}" \
    "/source/${VALIDATOR_SOURCE}" \
    "${netcdf_libs[@]}" \
    -lm -o "${validator}"
"${validator}" "${static_path}"
CONTAINER_SCRIPT

read -r error_count error_records < <(
    awk '
        $1 == "Error" && $2 == "messages" && $3 == "=" {
            value = $4
            records++
        }
        END { print value + 0, records + 0 }
    ' "${STATIC_DIR}/${LOG_FILE}"
)
read -r critical_count critical_records < <(
    awk '
        $1 == "Critical" && $2 == "error" && $3 == "messages" && $4 == "=" {
            value = $5
            records++
        }
        END { print value + 0, records + 0 }
    ' "${STATIC_DIR}/${LOG_FILE}"
)
read -r warning_count warning_records < <(
    awk '
        $1 == "Warning" && $2 == "messages" && $3 == "=" {
            value = $4
            records++
        }
        END { print value + 0, records + 0 }
    ' "${STATIC_DIR}/${LOG_FILE}"
)

if [[ "${error_records}" -ne 1 || "${critical_records}" -ne 1 ||
      "${warning_records}" -ne 1 ]]; then
    echo "error: log summary counters are absent or duplicated" >&2
    exit 1
fi
if [[ "${error_count}" -ne 0 || "${critical_count}" -ne 0 ]]; then
    echo "error: MPAS reported error or critical messages" >&2
    exit 1
fi
if ! grep -Eq '^[[:space:]]*Logging complete\.' "${STATIC_DIR}/${LOG_FILE}"; then
    echo "error: MPAS log does not contain its completion marker" >&2
    exit 1
fi

echo "== Artifact identity and MPAS log summary =="
printf 'static_size_bytes=%s\n' "$(wc -c < "${STATIC_DIR}/${STATIC_FILE}")"
sha256sum "${STATIC_DIR}/${STATIC_FILE}"
printf 'warning_messages=%d\n' "${warning_count}"
printf 'error_messages=%d\n' "${error_count}"
printf 'critical_error_messages=%d\n' "${critical_count}"
echo "static_validation=PASS"
