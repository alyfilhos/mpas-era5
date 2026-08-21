#!/usr/bin/env bash

set -euo pipefail

readonly IMAGE="${ATMOSPHERE_IMAGE:-mpas-era5:mpas-atmosphere-8.4.1}"
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
readonly INIT_DIR="${ATMOSPHERE_INIT_DIR:-${PROJECT_ROOT}/data/cases/first-global-240km/init}"
readonly MESH_DIR="${ATMOSPHERE_MESH_DIR:-${PROJECT_ROOT}/data/meshes/x1.10242}"
readonly CONFIG_DIR="${ATMOSPHERE_CONFIG_DIR:-${PROJECT_ROOT}/cases/first-global-240km/atmosphere}"
readonly OUTPUT_PARENT="${ATMOSPHERE_OUTPUT_PARENT:-${PROJECT_ROOT}/data/cases/first-global-240km/atmosphere}"
readonly RUN_NAME="${ATMOSPHERE_RUN_NAME:-run-001}"
readonly RUN_DIR="${OUTPUT_PARENT}/${RUN_NAME}"
readonly INIT_FILE=x1.10242.init.nc
readonly PARTITION_FILE=x1.10242.graph.info.part.4
readonly LOG_FILE=log.atmosphere.0000.out
readonly MANIFEST_FILE=manifest.json
readonly MPI_TASKS=4
readonly TIMESTEP_SECONDS=1200.0
readonly RUN_DURATION=01:00:00
readonly START_TIME=2014-09-10_00:00:00
readonly END_TIME=2014-09-10_01:00:00
readonly PHYSICS_SUITE=mesoscale_reference
readonly MPAS_VERSION=8.4.1
readonly MPAS_COMMIT=91c5eac175eebeaf4206bacd5cb50c39dff3c152
readonly SCIENTIFIC_COMMAND='mpiexec -n 4 /opt/mpas-model-8.4.1/atmosphere_model'
readonly LOOKUP_SOURCE=/opt/mpas-model-8.4.1/src/core_atmosphere/physics/physics_wrf/files
readonly LOOKUP_TABLES='CAM_ABS_DATA.DBL CAM_AEROPT_DATA.DBL CCN_ACTIVATE_DATA GENPARM.TBL LANDUSE.TBL OZONE_DAT.TBL OZONE_LAT.TBL OZONE_PLEV.TBL RRTMG_LW_DATA RRTMG_LW_DATA.DBL RRTMG_SW_DATA RRTMG_SW_DATA.DBL SOILPARM.TBL VEGPARM.TBL'
readonly -a CONFIG_FILES=(
    namelist.atmosphere
    streams.atmosphere
    stream_list.atmosphere.output
    stream_list.atmosphere.diagnostics
    stream_list.atmosphere.diag_ugwp
    stream_list.atmosphere.surface
)

fail() { echo "error: $*" >&2; exit 1; }

if [[ "$#" -ne 0 ]]; then
    echo "usage: $0" >&2
    exit 2
fi

for command_name in awk date docker id mkdir mktemp mv python3 sha256sum; do
    command -v "${command_name}" >/dev/null 2>&1 || fail "required command not found: ${command_name}"
done

docker image inspect "${IMAGE}" >/dev/null 2>&1 || fail "Docker image not found: ${IMAGE}"
readonly IMAGE_ID="$(docker image inspect "${IMAGE}" --format '{{.Id}}')"

for input_path in "${INIT_DIR}/${INIT_FILE}" "${MESH_DIR}/${PARTITION_FILE}"; do
    [[ -f "${input_path}" && ! -L "${input_path}" ]] || fail "required regular, non-symlink input is absent: ${input_path}"
done
for config_file in "${CONFIG_FILES[@]}"; do
    [[ -f "${CONFIG_DIR}/${config_file}" && ! -L "${CONFIG_DIR}/${config_file}" ]] || fail "required regular, non-symlink configuration is absent: ${CONFIG_DIR}/${config_file}"
done

echo '== Direct input regressions =='
INIT_IMAGE="${IMAGE}" "${PROJECT_ROOT}/scripts/validate/init.sh"
MESH_IMAGE="${IMAGE}" "${PROJECT_ROOT}/scripts/validate/mesh.sh"

mkdir -p "${OUTPUT_PARENT}"
[[ ! -L "${RUN_DIR}" ]] || fail "refusing symlink run directory: ${RUN_DIR}"
if [[ -e "${RUN_DIR}" ]]; then
    [[ -d "${RUN_DIR}" ]] || fail "run target exists and is not a directory: ${RUN_DIR}"
    ATMOSPHERE_IMAGE="${IMAGE}" "${PROJECT_ROOT}/scripts/validate/atmosphere-run.sh" "${RUN_DIR}"
    echo "atmosphere_run=unchanged"
    exit 0
fi

workspace="$(mktemp -d "${OUTPUT_PARENT}/.${RUN_NAME}.workspace.XXXXXX")"
completed=false
preserve_workspace() {
    if [[ "${completed}" != true ]]; then
        echo "atmosphere_workspace_preserved=${workspace}" >&2
    fi
}
trap preserve_workspace EXIT

readonly started_epoch="$(date +%s)"
readonly started_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

printf 'image=%s\nimage_id=%s\n' "${IMAGE}" "${IMAGE_ID}"
printf 'mpi_ranks=%d\npartition=%s\n' "${MPI_TASKS}" "${PARTITION_FILE}"
printf 'timestep_seconds=%s\nrun_duration=%s\nphysics_suite=%s\n' "${TIMESTEP_SECONDS}" "${RUN_DURATION}" "${PHYSICS_SUITE}"
printf 'sst_update=false\nnetwork=none\nroot_filesystem=read-only\ninputs=read-only\n'
printf 'workspace=%s\nscientific_command=%s\n' "${workspace}" "${SCIENTIFIC_COMMAND}"

docker_args=(
    run
    --rm
    --network none
    --read-only
    --cap-drop ALL
    --security-opt no-new-privileges
    --user "$(id -u):$(id -g)"
    --mount "type=bind,source=${INIT_DIR},target=/inputs/init,readonly"
    --mount "type=bind,source=${MESH_DIR},target=/inputs/mesh,readonly"
    --mount "type=bind,source=${CONFIG_DIR},target=/inputs/case,readonly"
    --mount "type=bind,source=${workspace},target=/work"
    --tmpfs /tmp:rw,nosuid,nodev,size=128m
    --tmpfs /run:rw,nosuid,nodev,size=16m
    --workdir /work
    --env "INIT_FILE=${INIT_FILE}"
    --env "PARTITION_FILE=${PARTITION_FILE}"
    --env "LOG_FILE=${LOG_FILE}"
    --env "MPI_TASKS=${MPI_TASKS}"
    --env "MPAS_COMMIT=${MPAS_COMMIT}"
    --env "LOOKUP_SOURCE=${LOOKUP_SOURCE}"
    --env "LOOKUP_TABLES=${LOOKUP_TABLES}"
)
docker "${docker_args[@]}" "${IMAGE}" bash -euo pipefail -c '
umask 0022

test "$(git -c safe.directory=/opt/mpas-model-8.4.1 -C /opt/mpas-model-8.4.1 rev-parse HEAD)" = "${MPAS_COMMIT}"
test -x /opt/mpas-model-8.4.1/atmosphere_model
test ! -w /opt/mpas-model-8.4.1/atmosphere_model

ln -s "/inputs/init/${INIT_FILE}" "/work/${INIT_FILE}"
ln -s "/inputs/mesh/${PARTITION_FILE}" "/work/${PARTITION_FILE}"
for config_file in namelist.atmosphere streams.atmosphere stream_list.atmosphere.output stream_list.atmosphere.diagnostics stream_list.atmosphere.diag_ugwp stream_list.atmosphere.surface; do
    ln -s "/inputs/case/${config_file}" "/work/${config_file}"
done
for table in ${LOOKUP_TABLES}; do
    test -f "${LOOKUP_SOURCE}/${table}"
    test ! -w "${LOOKUP_SOURCE}/${table}"
    ln -s "${LOOKUP_SOURCE}/${table}" "/work/${table}"
done

mpiexec -n "${MPI_TASKS}" /opt/mpas-model-8.4.1/atmosphere_model

test -s "/work/${LOG_FILE}"
grep -Eq "^[[:space:]]*Error messages[[:space:]]*=[[:space:]]*0" "/work/${LOG_FILE}"
grep -Eq "^[[:space:]]*Critical error messages[[:space:]]*=[[:space:]]*0" "/work/${LOG_FILE}"
grep -Eq "^[[:space:]]*Logging complete\." "/work/${LOG_FILE}"
grep -Fq -- "Setting up physics suite '\''mesoscale_reference'\''" "/work/${LOG_FILE}"
grep -Eq "config_lsm_scheme[[:space:]]*=[[:space:]]*sf_noah([[:space:]]*)$" "/work/${LOG_FILE}"

for output_file in history.2014-09-10_00.00.00.nc history.2014-09-10_01.00.00.nc diag.2014-09-10_00.00.00.nc diag.2014-09-10_01.00.00.nc; do
    test -s "/work/${output_file}"
    ncdump -h "/work/${output_file}" >/dev/null
done

rm -f -- "/work/${INIT_FILE}" "/work/${PARTITION_FILE}" /work/namelist.atmosphere /work/streams.atmosphere /work/stream_list.atmosphere.output /work/stream_list.atmosphere.diagnostics /work/stream_list.atmosphere.diag_ugwp /work/stream_list.atmosphere.surface
for table in ${LOOKUP_TABLES}; do
    rm -f -- "/work/${table}"
done
'

readonly finished_epoch="$(date +%s)"
readonly elapsed_seconds="$((finished_epoch - started_epoch))"
readonly finished_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
readonly INIT_SHA256="$(sha256sum "${INIT_DIR}/${INIT_FILE}" | awk '{print $1}')"
readonly PARTITION_SHA256="$(sha256sum "${MESH_DIR}/${PARTITION_FILE}" | awk '{print $1}')"

export IMAGE IMAGE_ID MPAS_VERSION MPAS_COMMIT MPI_TASKS TIMESTEP_SECONDS RUN_DURATION
export START_TIME END_TIME PHYSICS_SUITE SCIENTIFIC_COMMAND LOOKUP_SOURCE LOOKUP_TABLES
export INIT_SHA256 PARTITION_SHA256 CONFIG_DIR workspace started_at finished_at elapsed_seconds MANIFEST_FILE
python3 - <<'PY'
import hashlib
import json
import os
from pathlib import Path

workspace = Path(os.environ["workspace"])
expected_outputs = {
    "diag.2014-09-10_00.00.00.nc",
    "diag.2014-09-10_01.00.00.nc",
    "history.2014-09-10_00.00.00.nc",
    "history.2014-09-10_01.00.00.nc",
    "log.atmosphere.0000.out",
}
actual_outputs = {path.name for path in workspace.iterdir() if path.is_file()}
if actual_outputs != expected_outputs:
    raise SystemExit(
        f"error: unexpected run artifacts: expected={sorted(expected_outputs)} actual={sorted(actual_outputs)}"
    )

def digest(path: Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            value.update(chunk)
    return value.hexdigest()

config_dir = Path(os.environ["CONFIG_DIR"])
config_names = [
    "namelist.atmosphere",
    "streams.atmosphere",
    "stream_list.atmosphere.output",
    "stream_list.atmosphere.diagnostics",
    "stream_list.atmosphere.diag_ugwp",
    "stream_list.atmosphere.surface",
]
outputs = [
    {
        "filename": name,
        "size_bytes": (workspace / name).stat().st_size,
        "sha256": digest(workspace / name),
    }
    for name in sorted(expected_outputs)
]
manifest = {
    "schema_version": 1,
    "image": os.environ["IMAGE"],
    "image_id": os.environ["IMAGE_ID"],
    "mpas": {
        "version": os.environ["MPAS_VERSION"],
        "commit": os.environ["MPAS_COMMIT"],
    },
    "command": os.environ["SCIENTIFIC_COMMAND"],
    "mpi_ranks": int(os.environ["MPI_TASKS"]),
    "partition": "x1.10242.graph.info.part.4",
    "timestep_seconds": float(os.environ["TIMESTEP_SECONDS"]),
    "run_duration": os.environ["RUN_DURATION"],
    "start_time": os.environ["START_TIME"],
    "end_time": os.environ["END_TIME"],
    "domain": "global",
    "apply_lbcs": False,
    "do_restart": False,
    "physics_suite": os.environ["PHYSICS_SUITE"],
    "land_surface_scheme": "sf_noah",
    "sst_update": False,
    "radiation_intervals": {"longwave": "01:00:00", "shortwave": "01:00:00"},
    "inputs": {
        "init_filename": "x1.10242.init.nc",
        "init_sha256": os.environ["INIT_SHA256"],
        "partition_sha256": os.environ["PARTITION_SHA256"],
    },
    "config_sha256": {name: digest(config_dir / name) for name in config_names},
    "lookup_source": os.environ["LOOKUP_SOURCE"],
    "lookup_tables": os.environ["LOOKUP_TABLES"].split(),
    "outputs": outputs,
    "started_at": os.environ["started_at"],
    "finished_at": os.environ["finished_at"],
    "elapsed_seconds": int(os.environ["elapsed_seconds"]),
}
(workspace / os.environ["MANIFEST_FILE"]).write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
PY

ATMOSPHERE_IMAGE="${IMAGE}" "${PROJECT_ROOT}/scripts/validate/atmosphere-run.sh" "${workspace}"

[[ ! -e "${RUN_DIR}" ]] || fail "run target appeared during execution; preserving workspace"
mv --no-clobber "${workspace}" "${RUN_DIR}"
completed=true
trap - EXIT

printf 'elapsed_seconds=%s\nrun_directory=%s\nmanifest=%s\n' "${elapsed_seconds}" "${RUN_DIR}" "${RUN_DIR}/${MANIFEST_FILE}"
echo 'atmosphere_run=PASS'
