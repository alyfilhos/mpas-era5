#!/usr/bin/env bash

set -euo pipefail

readonly IMAGE="${INIT_IMAGE:-mpas-era5:mpas-atmosphere-8.4.1}"
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
readonly INIT_DIR="${1:-${PROJECT_ROOT}/data/cases/first-global-240km/init}"
readonly STATIC_FILE="${PROJECT_ROOT}/data/cases/first-global-240km/static/x1.10242.static.nc"
readonly GRID_FILE="${PROJECT_ROOT}/data/meshes/x1.10242/x1.10242.grid.nc"
readonly PART_FILE="${PROJECT_ROOT}/data/meshes/x1.10242/x1.10242.graph.info.part.4"
readonly WPS_FILE="${PROJECT_ROOT}/data/cases/first-global-240km/wps/ERA5:2014-09-10_00"
readonly CONFIG_DIR="${PROJECT_ROOT}/cases/first-global-240km/init"
readonly INIT_FILE="${INIT_DIR}/x1.10242.init.nc"
readonly LOG_FILE="${INIT_DIR}/log.init_atmosphere.0000.out"
readonly MANIFEST_FILE="${INIT_DIR}/manifest.json"
readonly C_SOURCE="${PROJECT_ROOT}/tests/smoke/init_netcdf.c"
readonly COMMAND='mpiexec -n 4 /opt/mpas-model-8.4.1/init_atmosphere_model'

fail() { echo "error: $*" >&2; exit 1; }
[[ "$#" -le 1 ]] || { echo "usage: $0 [INIT_DIRECTORY]" >&2; exit 2; }
for name in awk docker env git grep id python3 sha256sum tail tr wc; do
    command -v "${name}" >/dev/null 2>&1 || fail "required command not found: ${name}"
done
for path in "${INIT_FILE}" "${LOG_FILE}" "${MANIFEST_FILE}" "${STATIC_FILE}" \
            "${GRID_FILE}" "${PART_FILE}" "${WPS_FILE}" \
            "${CONFIG_DIR}/namelist.init_atmosphere" \
            "${CONFIG_DIR}/streams.init_atmosphere" "${C_SOURCE}"; do
    [[ -f "${path}" && ! -L "${path}" ]] || fail "required regular, non-symlink file is absent: ${path}"
done
docker image inspect "${IMAGE}" >/dev/null 2>&1 || fail "Docker image not found: ${IMAGE}"
readonly IMAGE_ID="$(docker image inspect "${IMAGE}" --format '{{.Id}}')"

ncells() {
    docker run --rm --network none --read-only --cap-drop ALL \
        --security-opt no-new-privileges --user "$(id -u):$(id -g)" \
        --mount "type=bind,source=$1,target=/input.nc,readonly" \
        --tmpfs /tmp:rw,exec,nosuid,nodev,size=16m "${IMAGE}" \
        ncdump -h /input.nc | awk '/nCells = / {gsub(";", "", $3); print $3; exit}'
}
readonly GRID_CELLS="$(ncells "${GRID_FILE}")"
readonly STATIC_CELLS="$(ncells "${STATIC_FILE}")"

docker run --rm --network none --read-only --cap-drop ALL \
    --security-opt no-new-privileges --user "$(id -u):$(id -g)" \
    --mount "type=bind,source=${INIT_FILE},target=/input/x1.10242.init.nc,readonly" \
    --mount "type=bind,source=${C_SOURCE},target=/input/init_netcdf.c,readonly" \
    --tmpfs /tmp:rw,exec,nosuid,nodev,size=128m "${IMAGE}" bash -euo pipefail -c '
test "$(ncdump -k /input/x1.10242.init.nc)" = "64-bit offset"
cc -std=c11 -O2 -Wall -Wextra -Werror $(nc-config --cflags) \
    /input/init_netcdf.c $(nc-config --libs) -lm -o /tmp/init_netcdf
/tmp/init_netcdf /input/x1.10242.init.nc
'

readonly INIT_CELLS="$(ncells "${INIT_FILE}")"
[[ "${GRID_CELLS}" == 10242 && "${STATIC_CELLS}" == 10242 && "${INIT_CELLS}" == 10242 ]] || \
    fail "nCells mismatch: mesh=${GRID_CELLS} static=${STATIC_CELLS} init=${INIT_CELLS}"
printf 'layer_cells=mesh:%s static:%s init:%s\n' "${GRID_CELLS}" "${STATIC_CELLS}" "${INIT_CELLS}"

[[ "$(grep -Ec '^[[:space:]]*Error messages[[:space:]]*=[[:space:]]*0' "${LOG_FILE}")" -eq 1 ]] || fail "zero error count absent or duplicated"
[[ "$(grep -Ec '^[[:space:]]*Critical error messages[[:space:]]*=[[:space:]]*0' "${LOG_FILE}")" -eq 1 ]] || fail "zero critical count absent or duplicated"
grep -Eq '^[[:space:]]*Logging complete\.' "${LOG_FILE}" || fail "completion marker absent"
printf 'log_summary=%s\n' "$(grep -E 'Error messages|Critical error messages' "${LOG_FILE}" | tail -n 2 | tr '\n' ' ')"
[[ "$(grep -Ec '^[[:space:]]*Warning messages[[:space:]]*=[[:space:]]*0' "${LOG_FILE}")" -eq 1 ]] || fail "zero warning count absent or duplicated"
printf 'warning_messages=0\n'

readonly STATIC_SHA="$(sha256sum "${STATIC_FILE}" | awk '{print $1}')"
readonly WPS_SHA="$(sha256sum "${WPS_FILE}" | awk '{print $1}')"
readonly PART_SHA="$(sha256sum "${PART_FILE}" | awk '{print $1}')"
readonly NAMELIST_SHA="$(sha256sum "${CONFIG_DIR}/namelist.init_atmosphere" | awk '{print $1}')"
readonly STREAMS_SHA="$(sha256sum "${CONFIG_DIR}/streams.init_atmosphere" | awk '{print $1}')"
readonly INIT_SHA="$(sha256sum "${INIT_FILE}" | awk '{print $1}')"
readonly INIT_SIZE="$(wc -c < "${INIT_FILE}")"

env IMAGE="${IMAGE}" IMAGE_ID="${IMAGE_ID}" COMMAND="${COMMAND}" STATIC_SHA="${STATIC_SHA}" \
    WPS_SHA="${WPS_SHA}" PART_SHA="${PART_SHA}" NAMELIST_SHA="${NAMELIST_SHA}" \
    STREAMS_SHA="${STREAMS_SHA}" INIT_SHA="${INIT_SHA}" INIT_SIZE="${INIT_SIZE}" \
    MANIFEST_FILE="${MANIFEST_FILE}" python3 - <<'PY'
import json
import os
from datetime import datetime
from pathlib import Path

manifest = json.loads(Path(os.environ["MANIFEST_FILE"]).read_text(encoding="utf-8"))
expected = {
    "schema_version": 1,
    "image": os.environ["IMAGE"],
    "image_id": os.environ["IMAGE_ID"],
    "mpi_ranks": 4,
    "command": os.environ["COMMAND"],
    "inputs": {
        "static_sha256": os.environ["STATIC_SHA"],
        "wps_intermediate_sha256": os.environ["WPS_SHA"],
        "partition_sha256": os.environ["PART_SHA"],
    },
    "config_sha256": {
        "namelist.init_atmosphere": os.environ["NAMELIST_SHA"],
        "streams.init_atmosphere": os.environ["STREAMS_SHA"],
    },
    "output": {
        "filename": "x1.10242.init.nc",
        "size_bytes": int(os.environ["INIT_SIZE"]),
        "sha256": os.environ["INIT_SHA"],
    },
}
for key, value in expected.items():
    if manifest.get(key) != value:
        raise SystemExit(f"error: manifest mismatch at {key}")
started = datetime.fromisoformat(manifest["started_at"].replace("Z", "+00:00"))
finished = datetime.fromisoformat(manifest["finished_at"].replace("Z", "+00:00"))
if not isinstance(manifest.get("elapsed_seconds"), int) or manifest["elapsed_seconds"] < 0 or finished < started:
    raise SystemExit("error: invalid manifest timestamps")
print(f"manifest_execution={manifest['started_at']}..{manifest['finished_at']} elapsed_seconds={manifest['elapsed_seconds']}")
PY

for generated in "${INIT_FILE}" "${LOG_FILE}" "${MANIFEST_FILE}"; do
    git -C "${PROJECT_ROOT}" check-ignore -q "${generated}" || fail "generated artifact is not ignored: ${generated}"
    if git -C "${PROJECT_ROOT}" ls-files --error-unmatch "${generated}" >/dev/null 2>&1; then
        fail "generated init artifact is tracked: ${generated}"
    fi
done
printf 'init_size_bytes=%s\ninit_sha256=%s\n' "${INIT_SIZE}" "${INIT_SHA}"
echo 'first_guess_levels=37_pressure+1_surface=38'
echo 'soil_levels=WPS:4 MPAS:4'
echo 'init_validation=PASS'
