#!/usr/bin/env bash

set -euo pipefail

readonly SCIENTIFIC_IMAGE="${SCIENTIFIC_IMAGE:-mpas-era5:mpas-atmosphere-8.4.1}"
readonly ANALYSIS_IMAGE="${ANALYSIS_IMAGE:-mpas-era5:analysis-0014}"
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"

fail() { echo "error: $*" >&2; exit 1; }

require_file() {
    local path="$1"
    shift
    if [[ -f "${path}" && ! -L "${path}" ]]; then
        return 0
    fi
    echo "error: required canonical artifact is absent or unsafe: ${path}" >&2
    echo "reproduce it explicitly (this validator never downloads or regenerates it):" >&2
    printf '  %s\n' "$@" >&2
    exit 1
}

require_directory() {
    local path="$1"
    shift
    if [[ -d "${path}" && ! -L "${path}" ]]; then
        return 0
    fi
    echo "error: required canonical directory is absent or unsafe: ${path}" >&2
    echo "reproduce it explicitly (this validator never runs a forecast):" >&2
    printf '  %s\n' "$@" >&2
    exit 1
}

require_image() {
    local image="$1"
    shift
    if docker image inspect "${image}" >/dev/null 2>&1; then
        return 0
    fi
    echo "error: required Docker image is absent or inaccessible: ${image}" >&2
    printf '  %s\n' "$@" >&2
    exit 1
}

run_phase() {
    local phase="$1"
    shift
    echo
    echo "== Final project phase: ${phase} =="
    if "$@"; then
        echo "phase_${phase}=PASS"
    else
        fail "final project phase failed: ${phase}"
    fi
}

[[ "$#" -eq 0 ]] || { echo "usage: $0" >&2; exit 2; }
for command_name in docker git id python3 realpath; do
    command -v "${command_name}" >/dev/null 2>&1 || \
        fail "required host command not found: ${command_name}"
done
[[ "$(git -C "${PROJECT_ROOT}" rev-parse --show-toplevel)" = "${PROJECT_ROOT}" ]] || \
    fail "project root could not be verified"

require_image "${SCIENTIFIC_IMAGE}" \
    "docker build --progress=plain --build-arg BUILD_JOBS=8 -t ${SCIENTIFIC_IMAGE} ${PROJECT_ROOT}"
require_image "${ANALYSIS_IMAGE}" \
    "docker build --progress=plain --file docker/analysis/Dockerfile --tag ${ANALYSIS_IMAGE} ${PROJECT_ROOT}"

readonly MESH_DIR="${PROJECT_ROOT}/data/meshes/x1.10242"
require_file "${MESH_DIR}/x1.10242.grid.nc" \
    "./scripts/data/fetch-mesh.sh"
require_file "${MESH_DIR}/x1.10242.graph.info" \
    "./scripts/data/fetch-mesh.sh"
require_file "${MESH_DIR}/x1.10242.graph.info.part.4" \
    "./scripts/data/fetch-mesh.sh" \
    "./scripts/prepare/partition-mesh.sh"

readonly STATIC_DIR="${PROJECT_ROOT}/data/cases/first-global-240km/static"
require_file "${STATIC_DIR}/x1.10242.static.nc" \
    "./scripts/data/fetch-geog.sh" \
    "./scripts/run/generate-static.sh"
require_file "${STATIC_DIR}/log.init_atmosphere.0000.out" \
    "./scripts/run/generate-static.sh"

readonly ERA5_DIR="${PROJECT_ROOT}/data/era5/2014-09-10_00"
for era5_file in era5-pressure-levels.grib era5-single-levels.grib manifest.json; do
    require_file "${ERA5_DIR}/${era5_file}" \
        "./scripts/data/fetch-era5.sh build" \
        "./scripts/data/fetch-era5.sh probe" \
        "./scripts/data/fetch-era5.sh download"
done

readonly WPS_DIR="${PROJECT_ROOT}/data/cases/first-global-240km/wps"
for wps_file in \
    'ERA5_PRES:2014-09-10_00' \
    'ERA5_SFC:2014-09-10_00' \
    'ERA5:2014-09-10_00' \
    ungrib-pressure.log \
    ungrib-single.log \
    manifest.json; do
    require_file "${WPS_DIR}/${wps_file}" \
        "./scripts/validate/era5.sh" \
        "./scripts/run/ungrib-era5.sh"
done

readonly INIT_DIR="${PROJECT_ROOT}/data/cases/first-global-240km/init"
for init_file in x1.10242.init.nc log.init_atmosphere.0000.out manifest.json; do
    require_file "${INIT_DIR}/${init_file}" \
        "./scripts/run/generate-init.sh"
done

readonly RUN_DIR="${PROJECT_ROOT}/data/cases/first-global-240km/atmosphere/run-001"
require_directory "${RUN_DIR}" "./scripts/run/run-atmosphere.sh"
for run_file in \
    diag.2014-09-10_00.00.00.nc \
    diag.2014-09-10_01.00.00.nc \
    history.2014-09-10_00.00.00.nc \
    history.2014-09-10_01.00.00.nc \
    log.atmosphere.0000.out \
    manifest.json; do
    require_file "${RUN_DIR}/${run_file}" \
        "./scripts/run/run-atmosphere.sh"
done

echo "Final validation is offline and read-only for canonical scientific inputs."
echo "scientific_image=${SCIENTIFIC_IMAGE}"
echo "analysis_image=${ANALYSIS_IMAGE}"

run_phase environment_and_core_libraries \
    env SCIENTIFIC_IMAGE="${SCIENTIFIC_IMAGE}" \
    "${SCRIPT_DIR}/core-libraries.sh"
run_phase pnetcdf \
    env PNETCDF_IMAGE="${SCIENTIFIC_IMAGE}" \
    "${SCRIPT_DIR}/pnetcdf.sh"
run_phase pio \
    env PIO_IMAGE="${SCIENTIFIC_IMAGE}" \
    "${SCRIPT_DIR}/pio.sh"
run_phase mesh \
    env MESH_IMAGE="${SCIENTIFIC_IMAGE}" \
    "${SCRIPT_DIR}/mesh.sh"
run_phase static \
    env STATIC_IMAGE="${SCIENTIFIC_IMAGE}" \
    "${SCRIPT_DIR}/static.sh"
run_phase era5_raw "${SCRIPT_DIR}/era5.sh"
run_phase wps_intermediate \
    env WPS_IMAGE="${SCIENTIFIC_IMAGE}" \
    "${SCRIPT_DIR}/wps-era5.sh"
run_phase initial_conditions \
    env INIT_IMAGE="${SCIENTIFIC_IMAGE}" \
    "${SCRIPT_DIR}/init.sh"
run_phase atmosphere_integration \
    env ATMOSPHERE_IMAGE="${SCIENTIFIC_IMAGE}" \
    "${SCRIPT_DIR}/atmosphere-run.sh"
run_phase scientific_sanity \
    env ANALYSIS_IMAGE="${ANALYSIS_IMAGE}" \
        ATMOSPHERE_IMAGE="${SCIENTIFIC_IMAGE}" \
    "${SCRIPT_DIR}/scientific-run.sh"

echo
echo "== Final project summary =="
echo "environment=PASS"
echo "scientific_stack=PASS"
echo "mesh=PASS"
echo "static=PASS"
echo "era5_raw=PASS"
echo "wps_intermediate=PASS"
echo "initial_conditions=PASS"
echo "atmosphere_integration=PASS"
echo "scientific_sanity=PASS"
echo "forecast_skill=NOT_EVALUATED"
echo "spinup=INSUFFICIENT_TEMPORAL_WINDOW"
echo "PROJECT_BASE_STATUS=COMPLETE"
echo "project_validation=PASS"
