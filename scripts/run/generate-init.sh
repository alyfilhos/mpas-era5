#!/usr/bin/env bash

set -euo pipefail

readonly IMAGE="${INIT_IMAGE:-mpas-era5:mpas-atmosphere-8.4.1}"
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
readonly MESH_DIR="${INIT_MESH_DIR:-${PROJECT_ROOT}/data/meshes/x1.10242}"
readonly STATIC_DIR="${INIT_STATIC_DIR:-${PROJECT_ROOT}/data/cases/first-global-240km/static}"
readonly WPS_DIR="${INIT_WPS_DIR:-${PROJECT_ROOT}/data/cases/first-global-240km/wps}"
readonly CONFIG_DIR="${INIT_CONFIG_DIR:-${PROJECT_ROOT}/cases/first-global-240km/init}"
readonly OUTPUT_DIR="${INIT_OUTPUT_DIR:-${PROJECT_ROOT}/data/cases/first-global-240km/init}"
readonly STATIC_FILE=x1.10242.static.nc
readonly INTERMEDIATE_FILE='ERA5:2014-09-10_00'
readonly PARTITION_FILE=x1.10242.graph.info.part.4
readonly INIT_FILE=x1.10242.init.nc
readonly LOG_FILE=log.init_atmosphere.0000.out
readonly MANIFEST_FILE=manifest.json
readonly MPI_TASKS=4
readonly EXPECTED_MPAS_COMMIT=91c5eac175eebeaf4206bacd5cb50c39dff3c152
readonly SCIENTIFIC_COMMAND='mpiexec -n 4 /opt/mpas-model-8.4.1/init_atmosphere_model'

fail() {
    echo "error: $*" >&2
    exit 1
}

if [[ "$#" -ne 0 ]]; then
    echo "usage: $0" >&2
    exit 2
fi

for command_name in awk date docker env find grep id mkdir mktemp mv python3 rmdir sha256sum wc; do
    command -v "${command_name}" >/dev/null 2>&1 || \
        fail "required command not found: ${command_name}"
done

docker image inspect "${IMAGE}" >/dev/null 2>&1 || \
    fail "Docker image not found or Docker is not accessible: ${IMAGE}"
readonly IMAGE_ID="$(docker image inspect "${IMAGE}" --format '{{.Id}}')"

for input_path in \
    "${STATIC_DIR}/${STATIC_FILE}" \
    "${WPS_DIR}/${INTERMEDIATE_FILE}" \
    "${MESH_DIR}/${PARTITION_FILE}" \
    "${CONFIG_DIR}/namelist.init_atmosphere" \
    "${CONFIG_DIR}/streams.init_atmosphere"; do
    [[ -f "${input_path}" && ! -L "${input_path}" ]] || \
        fail "required regular, non-symlink input is absent: ${input_path}"
done

echo "== Direct input regressions =="
MESH_IMAGE="${IMAGE}" "${PROJECT_ROOT}/scripts/validate/mesh.sh"
STATIC_IMAGE="${IMAGE}" "${PROJECT_ROOT}/scripts/validate/static.sh"
"${PROJECT_ROOT}/scripts/validate/era5.sh"
WPS_IMAGE="${IMAGE}" "${PROJECT_ROOT}/scripts/validate/wps-era5.sh"
MPAS_INIT_IMAGE="${IMAGE}" "${PROJECT_ROOT}/scripts/validate/mpas-init.sh"

readonly STATIC_SHA256="$(sha256sum "${STATIC_DIR}/${STATIC_FILE}" | awk '{print $1}')"
readonly INTERMEDIATE_SHA256="$(sha256sum "${WPS_DIR}/${INTERMEDIATE_FILE}" | awk '{print $1}')"
readonly PARTITION_SHA256="$(sha256sum "${MESH_DIR}/${PARTITION_FILE}" | awk '{print $1}')"
readonly NAMELIST_SHA256="$(sha256sum "${CONFIG_DIR}/namelist.init_atmosphere" | awk '{print $1}')"
readonly STREAMS_SHA256="$(sha256sum "${CONFIG_DIR}/streams.init_atmosphere" | awk '{print $1}')"

mkdir -p "${OUTPUT_DIR}"
for canonical in "${INIT_FILE}" "${LOG_FILE}" "${MANIFEST_FILE}"; do
    if [[ -L "${OUTPUT_DIR}/${canonical}" ]]; then
        fail "refusing unsafe symlink in output directory: ${OUTPUT_DIR}/${canonical}"
    fi
done

existing_count=0
for canonical in "${INIT_FILE}" "${LOG_FILE}" "${MANIFEST_FILE}"; do
    [[ -e "${OUTPUT_DIR}/${canonical}" ]] && existing_count=$((existing_count + 1))
done

if [[ "${existing_count}" -ne 0 ]]; then
    [[ "${existing_count}" -eq 3 ]] || \
        fail "partial canonical output exists; preserving it for diagnosis: ${OUTPUT_DIR}"

    env STATIC_SHA256="${STATIC_SHA256}" \
    INTERMEDIATE_SHA256="${INTERMEDIATE_SHA256}" \
    PARTITION_SHA256="${PARTITION_SHA256}" \
    NAMELIST_SHA256="${NAMELIST_SHA256}" \
    STREAMS_SHA256="${STREAMS_SHA256}" \
    IMAGE_ID="${IMAGE_ID}" \
    MPI_TASKS="${MPI_TASKS}" \
    SCIENTIFIC_COMMAND="${SCIENTIFIC_COMMAND}" \
    INIT_PATH="${OUTPUT_DIR}/${INIT_FILE}" \
    MANIFEST_PATH="${OUTPUT_DIR}/${MANIFEST_FILE}" \
    python3 - <<'PY'
import hashlib
import json
import os
from pathlib import Path

manifest_path = Path(os.environ["MANIFEST_PATH"])
init_path = Path(os.environ["INIT_PATH"])
manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
expected = {
    "image_id": os.environ["IMAGE_ID"],
    "mpi_ranks": int(os.environ["MPI_TASKS"]),
    "command": os.environ["SCIENTIFIC_COMMAND"],
    "inputs": {
        "static_sha256": os.environ["STATIC_SHA256"],
        "wps_intermediate_sha256": os.environ["INTERMEDIATE_SHA256"],
        "partition_sha256": os.environ["PARTITION_SHA256"],
    },
    "config_sha256": {
        "namelist.init_atmosphere": os.environ["NAMELIST_SHA256"],
        "streams.init_atmosphere": os.environ["STREAMS_SHA256"],
    },
}
for key, value in expected.items():
    if manifest.get(key) != value:
        raise SystemExit(f"error: existing manifest differs at {key}")
digest = hashlib.sha256(init_path.read_bytes()).hexdigest()
if manifest.get("output", {}).get("sha256") != digest:
    raise SystemExit("error: existing init.nc differs from its manifest")
if manifest.get("output", {}).get("size_bytes") != init_path.stat().st_size:
    raise SystemExit("error: existing init.nc size differs from its manifest")
PY
    "${PROJECT_ROOT}/scripts/validate/init.sh" "${OUTPUT_DIR}"
    echo "init_generation=unchanged"
    exit 0
fi

if find "${OUTPUT_DIR}" -mindepth 1 -maxdepth 1 -print -quit | grep -q .; then
    fail "output directory contains non-canonical evidence; refusing to overwrite: ${OUTPUT_DIR}"
fi

workspace="$(mktemp -d "${OUTPUT_DIR}/.workspace.XXXXXX")"
completed=false
preserve_workspace() {
    if [[ "${completed}" != true ]]; then
        echo "generation_workspace_preserved=${workspace}" >&2
    fi
}
trap preserve_workspace EXIT

readonly start_epoch="$(date +%s)"
readonly started_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

printf 'image=%s\nimage_id=%s\n' "${IMAGE}" "${IMAGE_ID}"
printf 'mpi_ranks=%d\npartition=%s\n' "${MPI_TASKS}" "${PARTITION_FILE}"
printf 'network=none\nroot_filesystem=read-only\ninputs=read-only\n'
printf 'workspace=%s\n' "${workspace}"
printf 'scientific_command=%s\n' "${SCIENTIFIC_COMMAND}"

docker run --rm \
    --network none \
    --read-only \
    --cap-drop ALL \
    --security-opt no-new-privileges \
    --user "$(id -u):$(id -g)" \
    --mount "type=bind,source=${MESH_DIR},target=/inputs/mesh,readonly" \
    --mount "type=bind,source=${STATIC_DIR},target=/inputs/static,readonly" \
    --mount "type=bind,source=${WPS_DIR},target=/inputs/wps,readonly" \
    --mount "type=bind,source=${CONFIG_DIR},target=/inputs/case,readonly" \
    --mount "type=bind,source=${workspace},target=/work" \
    --tmpfs /tmp:rw,nosuid,nodev,size=128m \
    --tmpfs /run:rw,nosuid,nodev,size=16m \
    --workdir /work \
    --env "STATIC_FILE=${STATIC_FILE}" \
    --env "INTERMEDIATE_FILE=${INTERMEDIATE_FILE}" \
    --env "PARTITION_FILE=${PARTITION_FILE}" \
    --env "INIT_FILE=${INIT_FILE}" \
    --env "LOG_FILE=${LOG_FILE}" \
    --env "MPI_TASKS=${MPI_TASKS}" \
    --env "EXPECTED_MPAS_COMMIT=${EXPECTED_MPAS_COMMIT}" \
    "${IMAGE}" \
    bash -euo pipefail -c '
umask 0022

test "$(git -c safe.directory=/opt/mpas-model-8.4.1 -C /opt/mpas-model-8.4.1 rev-parse HEAD)" = "${EXPECTED_MPAS_COMMIT}"
test -x /opt/mpas-model-8.4.1/init_atmosphere_model
test ! -w /opt/mpas-model-8.4.1/init_atmosphere_model

ln -s "/inputs/static/${STATIC_FILE}" "/work/${STATIC_FILE}"
ln -s "/inputs/wps/${INTERMEDIATE_FILE}" "/work/${INTERMEDIATE_FILE}"
ln -s "/inputs/mesh/${PARTITION_FILE}" "/work/${PARTITION_FILE}"
ln -s /inputs/case/namelist.init_atmosphere /work/namelist.init_atmosphere
ln -s /inputs/case/streams.init_atmosphere /work/streams.init_atmosphere

mpiexec -n "${MPI_TASKS}" /opt/mpas-model-8.4.1/init_atmosphere_model

test -s "/work/${INIT_FILE}"
test -s "/work/${LOG_FILE}"
grep -Eq "Error messages[[:space:]]*=[[:space:]]*0" "/work/${LOG_FILE}"
grep -Eq "Critical error messages[[:space:]]*=[[:space:]]*0" "/work/${LOG_FILE}"
grep -Eq "^[[:space:]]*Logging complete\." "/work/${LOG_FILE}"
ncdump -h "/work/${INIT_FILE}" >/dev/null

rm -f -- \
    "/work/${STATIC_FILE}" \
    "/work/${INTERMEDIATE_FILE}" \
    "/work/${PARTITION_FILE}" \
    /work/namelist.init_atmosphere \
    /work/streams.init_atmosphere
'

readonly end_epoch="$(date +%s)"
readonly elapsed_seconds="$((end_epoch - start_epoch))"
readonly finished_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
readonly INIT_SIZE="$(wc -c < "${workspace}/${INIT_FILE}")"
readonly INIT_SHA256="$(sha256sum "${workspace}/${INIT_FILE}" | awk '{print $1}')"

env IMAGE="${IMAGE}" \
IMAGE_ID="${IMAGE_ID}" \
MPI_TASKS="${MPI_TASKS}" \
SCIENTIFIC_COMMAND="${SCIENTIFIC_COMMAND}" \
STATIC_SHA256="${STATIC_SHA256}" \
INTERMEDIATE_SHA256="${INTERMEDIATE_SHA256}" \
PARTITION_SHA256="${PARTITION_SHA256}" \
NAMELIST_SHA256="${NAMELIST_SHA256}" \
STREAMS_SHA256="${STREAMS_SHA256}" \
INIT_SIZE="${INIT_SIZE}" \
INIT_SHA256="${INIT_SHA256}" \
STARTED_AT="${started_at}" \
FINISHED_AT="${finished_at}" \
ELAPSED_SECONDS="${elapsed_seconds}" \
MANIFEST_PATH="${workspace}/${MANIFEST_FILE}" \
python3 - <<'PY'
import json
import os
from pathlib import Path

manifest = {
    "schema_version": 1,
    "image": os.environ["IMAGE"],
    "image_id": os.environ["IMAGE_ID"],
    "mpi_ranks": int(os.environ["MPI_TASKS"]),
    "command": os.environ["SCIENTIFIC_COMMAND"],
    "inputs": {
        "static_sha256": os.environ["STATIC_SHA256"],
        "wps_intermediate_sha256": os.environ["INTERMEDIATE_SHA256"],
        "partition_sha256": os.environ["PARTITION_SHA256"],
    },
    "config_sha256": {
        "namelist.init_atmosphere": os.environ["NAMELIST_SHA256"],
        "streams.init_atmosphere": os.environ["STREAMS_SHA256"],
    },
    "output": {
        "filename": "x1.10242.init.nc",
        "size_bytes": int(os.environ["INIT_SIZE"]),
        "sha256": os.environ["INIT_SHA256"],
    },
    "started_at": os.environ["STARTED_AT"],
    "finished_at": os.environ["FINISHED_AT"],
    "elapsed_seconds": int(os.environ["ELAPSED_SECONDS"]),
}
Path(os.environ["MANIFEST_PATH"]).write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
PY

for canonical in "${INIT_FILE}" "${LOG_FILE}" "${MANIFEST_FILE}"; do
    [[ ! -e "${OUTPUT_DIR}/${canonical}" ]] || \
        fail "canonical output appeared during generation; preserving workspace"
done
mv --no-clobber "${workspace}/${INIT_FILE}" "${OUTPUT_DIR}/${INIT_FILE}"
mv --no-clobber "${workspace}/${LOG_FILE}" "${OUTPUT_DIR}/${LOG_FILE}"
mv --no-clobber "${workspace}/${MANIFEST_FILE}" "${OUTPUT_DIR}/${MANIFEST_FILE}"
rmdir "${workspace}"
completed=true
trap - EXIT

"${PROJECT_ROOT}/scripts/validate/init.sh" "${OUTPUT_DIR}"

printf 'elapsed_seconds=%s\n' "${elapsed_seconds}"
printf 'init_file=%s\n' "${OUTPUT_DIR}/${INIT_FILE}"
printf 'init_size_bytes=%s\n' "${INIT_SIZE}"
printf 'init_sha256=%s\n' "${INIT_SHA256}"
printf 'manifest=%s\n' "${OUTPUT_DIR}/${MANIFEST_FILE}"
echo "init_generation=PASS"
