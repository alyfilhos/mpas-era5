#!/usr/bin/env bash

set -euo pipefail

readonly IMAGE="${WPS_IMAGE:-mpas-era5:mpas-atmosphere-8.4.1}"
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
readonly CONFIG_ROOT="${PROJECT_ROOT}/cases/first-global-240km/wps"
readonly INPUT_ROOT="${PROJECT_ROOT}/data/era5/2014-09-10_00"
readonly OUTPUT_ROOT="${PROJECT_ROOT}/data/cases/first-global-240km/wps"
readonly TIMESTAMP=2014-09-10_00
readonly HOST_UID="$(id -u)"
readonly HOST_GID="$(id -g)"

declare -a WORKSPACES=()

usage() {
    echo "usage: $0" >&2
}

cleanup() {
    local workspace
    for workspace in "${WORKSPACES[@]}"; do
        if [[ -d "${workspace}" ]]; then
            rm -rf -- "${workspace}"
        elif [[ -e "${workspace}" ]]; then
            rm -f -- "${workspace}"
        fi
    done
}

fail() {
    echo "error: $*" >&2
    exit 1
}

promote_exact() {
    local source_path="$1"
    local destination_path="$2"

    [[ -f "${source_path}" ]] || fail "promotion source is absent: ${source_path}"

    if [[ -e "${destination_path}" ]]; then
        [[ -f "${destination_path}" ]] || \
            fail "canonical destination is not a regular file: ${destination_path}"
        if cmp -s -- "${source_path}" "${destination_path}"; then
            echo "unchanged=$(basename -- "${destination_path}")"
            return
        fi
        fail "refusing to overwrite divergent canonical artifact: ${destination_path}"
    fi

    chmod 0644 "${source_path}"
    if ln -- "${source_path}" "${destination_path}" 2>/dev/null; then
        echo "promoted=$(basename -- "${destination_path}")"
        return
    fi

    if [[ -f "${destination_path}" ]] && \
       cmp -s -- "${source_path}" "${destination_path}"; then
        echo "unchanged=$(basename -- "${destination_path}")"
        return
    fi

    fail "atomic promotion collided with divergent content: ${destination_path}"
}

preserve_success_log() {
    local source_path="$1"
    local destination_path="$2"

    if [[ -e "${destination_path}" ]]; then
        [[ -f "${destination_path}" ]] || \
            fail "canonical log is not a regular file: ${destination_path}"
        grep -Fq "Successful completion of ungrib." "${source_path}" || \
            fail "new ungrib log lacks explicit success: ${source_path}"
        grep -Fq "Successful completion of ungrib." "${destination_path}" || \
            fail "canonical ungrib log lacks explicit success: ${destination_path}"
        echo "preserved=$(basename -- "${destination_path}")"
        return
    fi

    promote_exact "${source_path}" "${destination_path}"
}

run_ungrib() {
    local kind="$1"
    local prefix="$2"
    local input_name="$3"
    local config_path="$4"
    local output_name="${prefix}:${TIMESTAMP}"
    local log_name="ungrib-${kind}.log"
    local workspace

    [[ -f "${INPUT_ROOT}/${input_name}" ]] || fail "missing ERA5 GRIB: ${input_name}"
    [[ -f "${config_path}" ]] || fail "missing namelist: ${config_path}"

    workspace="$(mktemp -d "${OUTPUT_ROOT}/.ungrib-${kind}.XXXXXX")"
    WORKSPACES+=("${workspace}")

    echo "== ungrib ${kind}: ${input_name} -> ${output_name} =="
    docker run --rm \
        --network none \
        --read-only \
        --tmpfs /tmp \
        --user "${HOST_UID}:${HOST_GID}" \
        --cap-drop all \
        --security-opt no-new-privileges \
        --env "EXPECTED_OUTPUT=${output_name}" \
        --env "EXPECTED_PREFIX=${prefix}" \
        --mount \
            "type=bind,src=${INPUT_ROOT}/${input_name},dst=/input/era5.grib,readonly" \
        --mount \
            "type=bind,src=${config_path},dst=/config/namelist.wps,readonly" \
        --mount \
            "type=bind,src=${workspace},dst=/work" \
        "${IMAGE}" \
        bash -euo pipefail -c '
            cd /work
            cp /config/namelist.wps ./namelist.wps
            ln -s /opt/wps/ungrib/Variable_Tables/Vtable.ECMWF Vtable
            /opt/wps/link_grib.csh /input/era5.grib

            test -L GRIBFILE.AAA
            test "$(readlink GRIBFILE.AAA)" = /input/era5.grib
            grib_link_count=0
            for grib_link in GRIBFILE.???; do
                test -e "${grib_link}" || continue
                grib_link_count=$((grib_link_count + 1))
            done
            test "${grib_link_count}" -eq 1

            /opt/wps/ungrib.exe > ungrib.log 2>&1
            grep -Fq "Successful completion of ungrib." ungrib.log
            test -f "${EXPECTED_OUTPUT}"

            output_count=0
            for output_path in "${EXPECTED_PREFIX}:"*; do
                test -e "${output_path}" || continue
                output_count=$((output_count + 1))
                test "${output_path}" = "${EXPECTED_OUTPUT}"
            done
            test "${output_count}" -eq 1
        '

    python3 "${PROJECT_ROOT}/scripts/validate/wps-intermediate.py" \
        --expect-date 2014-09-10_00:00:00 \
        --expect-nx 1440 \
        --expect-ny 721 \
        --expect-iproj 0 \
        "${workspace}/${output_name}"

    promote_exact "${workspace}/${output_name}" "${OUTPUT_ROOT}/${output_name}"
    preserve_success_log "${workspace}/ungrib.log" "${OUTPUT_ROOT}/${log_name}"
}

if [[ "$#" -ne 0 ]]; then
    usage
    exit 2
fi

for command_name in docker python3 mktemp cmp chmod ln rm cat grep id; do
    command -v "${command_name}" >/dev/null 2>&1 || \
        fail "required command not found: ${command_name}"
done

trap cleanup EXIT
mkdir -p -- "${OUTPUT_ROOT}"
docker image inspect "${IMAGE}" >/dev/null

run_ungrib pressure ERA5_PRES era5-pressure-levels.grib \
    "${CONFIG_ROOT}/pressure/namelist.wps"
run_ungrib single ERA5_SFC era5-single-levels.grib \
    "${CONFIG_ROOT}/single/namelist.wps"

readonly PRESSURE_OUTPUT="${OUTPUT_ROOT}/ERA5_PRES:${TIMESTAMP}"
readonly SINGLE_OUTPUT="${OUTPUT_ROOT}/ERA5_SFC:${TIMESTAMP}"
readonly COMBINED_OUTPUT="${OUTPUT_ROOT}/ERA5:${TIMESTAMP}"
combined_stage="$(mktemp "${OUTPUT_ROOT}/.ERA5-combined.XXXXXX")"
WORKSPACES+=("${combined_stage}")

cat -- "${PRESSURE_OUTPUT}" "${SINGLE_OUTPUT}" > "${combined_stage}"
python3 "${PROJECT_ROOT}/scripts/validate/wps-intermediate.py" \
    --expect-date 2014-09-10_00:00:00 \
    --expect-nx 1440 \
    --expect-ny 721 \
    --expect-iproj 0 \
    "${combined_stage}"
promote_exact "${combined_stage}" "${COMBINED_OUTPUT}"

sha256sum -- "${PRESSURE_OUTPUT}" "${SINGLE_OUTPUT}" "${COMBINED_OUTPUT}"
echo "ungrib_era5=PASS"
