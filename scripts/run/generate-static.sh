#!/usr/bin/env bash

set -euo pipefail

readonly IMAGE="${STATIC_IMAGE:-mpas-era5:mpas-atmosphere-8.4.1}"
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
readonly MESH_DIR="${STATIC_MESH_DIR:-${PROJECT_ROOT}/data/meshes/x1.10242}"
readonly GEOG_DIR="${STATIC_GEOG_DIR:-${PROJECT_ROOT}/data/geog/mpas-8.4.1}"
readonly CONFIG_DIR="${STATIC_CONFIG_DIR:-${PROJECT_ROOT}/cases/first-global-240km/static}"
readonly OUTPUT_DIR="${STATIC_OUTPUT_DIR:-${PROJECT_ROOT}/data/cases/first-global-240km/static}"
readonly GRID_FILE=x1.10242.grid.nc
readonly STATIC_FILE=x1.10242.static.nc
readonly MPI_TASKS=1
readonly -a REQUIRED_DATASETS=(
    albedo_modis
    greenfrac_fpar_modis
    maxsnowalb_modis
    landuse_30s
    modis_landuse_20class_30s
    soiltemp_1deg
    soiltype_top_30s
    topo_gmted2010_30s
)

if [[ "$#" -ne 0 ]]; then
    echo "usage: $0" >&2
    exit 2
fi
for command_name in date docker find id mkdir sha256sum wc; do
    if ! command -v "${command_name}" >/dev/null 2>&1; then
        echo "error: required command not found: ${command_name}" >&2
        exit 1
    fi
done
if ! docker image inspect "${IMAGE}" >/dev/null 2>&1; then
    echo "error: Docker image not found or Docker is not accessible: ${IMAGE}" >&2
    exit 1
fi
if [[ ! -f "${MESH_DIR}/${GRID_FILE}" || -L "${MESH_DIR}/${GRID_FILE}" ]]; then
    echo "error: mesh is absent or unsafe: ${MESH_DIR}/${GRID_FILE}" >&2
    exit 1
fi
for config_file in namelist.init_atmosphere streams.init_atmosphere; do
    if [[ ! -f "${CONFIG_DIR}/${config_file}" || -L "${CONFIG_DIR}/${config_file}" ]]; then
        echo "error: case configuration is absent or unsafe: ${CONFIG_DIR}/${config_file}" >&2
        exit 1
    fi
done
for dataset in "${REQUIRED_DATASETS[@]}"; do
    if [[ ! -f "${GEOG_DIR}/${dataset}/index" || -L "${GEOG_DIR}/${dataset}/index" ]]; then
        echo "error: geographic dataset is absent or unsafe: ${GEOG_DIR}/${dataset}" >&2
        exit 1
    fi
done
readonly geog_manifest=${GEOG_DIR}/.mpas-era5-manifest.sha256
if [[ ! -f "${geog_manifest}" || -L "${geog_manifest}" ]]; then
    echo "error: geographic-data manifest is absent or unsafe: ${geog_manifest}" >&2
    exit 1
fi
if ! (
    cd -- "${GEOG_DIR}"
    sha256sum --check --quiet .mpas-era5-manifest.sha256
); then
    echo "error: geographic data do not match their installed manifest" >&2
    exit 1
fi

mkdir -p "${OUTPUT_DIR}"
if [[ -n "$(find "${OUTPUT_DIR}" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
    echo "error: output directory is not empty; refusing to overwrite runtime evidence: ${OUTPUT_DIR}" >&2
    exit 1
fi

readonly start_epoch="$(date +%s)"
printf 'image=%s\n' "${IMAGE}"
printf 'mpi_tasks=%d\n' "${MPI_TASKS}"
printf 'network=none\nmesh_mount=read-only\ngeog_mount=read-only\nconfig_mount=read-only\n'
printf 'output_directory=%s\n' "${OUTPUT_DIR}"

docker run --rm \
    --network none \
    --read-only \
    --cap-drop ALL \
    --security-opt no-new-privileges \
    --user "$(id -u):$(id -g)" \
    --mount "type=bind,source=${MESH_DIR},target=/mesh,readonly" \
    --mount "type=bind,source=${GEOG_DIR},target=/geog,readonly" \
    --mount "type=bind,source=${CONFIG_DIR},target=/case,readonly" \
    --mount "type=bind,source=${OUTPUT_DIR},target=/work" \
    --tmpfs /tmp:rw,nosuid,nodev,size=128m \
    --tmpfs /run:rw,nosuid,nodev,size=16m \
    --workdir /work \
    --env "GRID_FILE=${GRID_FILE}" \
    --env "STATIC_FILE=${STATIC_FILE}" \
    --env "MPI_TASKS=${MPI_TASKS}" \
    "${IMAGE}" \
    bash -c '
set -euo pipefail
umask 0022

cleanup_runtime_inputs() {
    rm -f -- /work/namelist.init_atmosphere /work/streams.init_atmosphere "/work/${GRID_FILE}"
}
trap cleanup_runtime_inputs EXIT

cp /case/namelist.init_atmosphere /work/namelist.init_atmosphere
cp /case/streams.init_atmosphere /work/streams.init_atmosphere
ln -s "/mesh/${GRID_FILE}" "/work/${GRID_FILE}"

echo "scientific_command=mpiexec -n ${MPI_TASKS} /opt/mpas-model-8.4.1/init_atmosphere_model"
mpiexec -n "${MPI_TASKS}" /opt/mpas-model-8.4.1/init_atmosphere_model

test -s "/work/${STATIC_FILE}"
readonly log_file=/work/log.init_atmosphere.0000.out
test -s "${log_file}"
grep -Eq "Error messages[[:space:]]*=[[:space:]]*0" "${log_file}"
grep -Eq "Critical error messages[[:space:]]*=[[:space:]]*0" "${log_file}"
ncdump -h "/work/${STATIC_FILE}" >/dev/null
echo "static_generation=PASS"
'

readonly end_epoch="$(date +%s)"
printf 'elapsed_seconds=%d\n' "$((end_epoch - start_epoch))"
printf 'static_file=%s\n' "${OUTPUT_DIR}/${STATIC_FILE}"
printf 'static_size_bytes=%s\n' "$(wc -c < "${OUTPUT_DIR}/${STATIC_FILE}")"
