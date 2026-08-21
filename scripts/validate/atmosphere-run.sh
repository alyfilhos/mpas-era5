#!/usr/bin/env bash

set -euo pipefail

readonly IMAGE="${ATMOSPHERE_IMAGE:-mpas-era5:mpas-atmosphere-8.4.1}"
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
readonly RUN_DIR_INPUT="${1:-${PROJECT_ROOT}/data/cases/first-global-240km/atmosphere/run-001}"
readonly RUN_DIR="$(realpath -m -- "${RUN_DIR_INPUT}")"
readonly INIT_FILE="${PROJECT_ROOT}/data/cases/first-global-240km/init/x1.10242.init.nc"
readonly PARTITION_FILE="${PROJECT_ROOT}/data/meshes/x1.10242/x1.10242.graph.info.part.4"
readonly CONFIG_DIR="${PROJECT_ROOT}/cases/first-global-240km/atmosphere"
readonly C_SOURCE="${PROJECT_ROOT}/tests/smoke/atmosphere_netcdf.c"
readonly LOG_FILE="${RUN_DIR}/log.atmosphere.0000.out"
readonly MANIFEST_FILE="${RUN_DIR}/manifest.json"
readonly HISTORY_T0="${RUN_DIR}/history.2014-09-10_00.00.00.nc"
readonly HISTORY_T1="${RUN_DIR}/history.2014-09-10_01.00.00.nc"
readonly DIAG_T0="${RUN_DIR}/diag.2014-09-10_00.00.00.nc"
readonly DIAG_T1="${RUN_DIR}/diag.2014-09-10_01.00.00.nc"
readonly COMMAND='mpiexec -n 4 /opt/mpas-model-8.4.1/atmosphere_model'
readonly MPAS_COMMIT=91c5eac175eebeaf4206bacd5cb50c39dff3c152
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
readonly -a OUTPUT_FILES=(
    "${DIAG_T0}"
    "${DIAG_T1}"
    "${HISTORY_T0}"
    "${HISTORY_T1}"
    "${LOG_FILE}"
)

fail() { echo "error: $*" >&2; exit 1; }

[[ "$#" -le 1 ]] || { echo "usage: $0 [RUN_DIRECTORY]" >&2; exit 2; }
for command_name in awk docker git grep id python3 realpath sha256sum wc; do
    command -v "${command_name}" >/dev/null 2>&1 || fail "required command not found: ${command_name}"
done
[[ ! -L "${RUN_DIR_INPUT}" && -d "${RUN_DIR}" && ! -L "${RUN_DIR}" ]] || fail "run directory is absent or unsafe: ${RUN_DIR_INPUT}"
for path in "${INIT_FILE}" "${PARTITION_FILE}" "${C_SOURCE}" "${MANIFEST_FILE}" "${OUTPUT_FILES[@]}"; do
    [[ -f "${path}" && ! -L "${path}" ]] || fail "required regular, non-symlink file is absent: ${path}"
done
for config_file in "${CONFIG_FILES[@]}"; do
    [[ -f "${CONFIG_DIR}/${config_file}" && ! -L "${CONFIG_DIR}/${config_file}" ]] || fail "required configuration is absent: ${CONFIG_DIR}/${config_file}"
done
docker image inspect "${IMAGE}" >/dev/null 2>&1 || fail "Docker image not found: ${IMAGE}"
readonly IMAGE_ID="$(docker image inspect "${IMAGE}" --format '{{.Id}}')"

[[ "$(grep -Ec '^[[:space:]]*Error messages[[:space:]]*=[[:space:]]*0' "${LOG_FILE}")" -eq 1 ]] || fail "zero error count absent or duplicated"
[[ "$(grep -Ec '^[[:space:]]*Critical error messages[[:space:]]*=[[:space:]]*0' "${LOG_FILE}")" -eq 1 ]] || fail "zero critical count absent or duplicated"
[[ "$(grep -Ec '^[[:space:]]*Warning messages[[:space:]]*=' "${LOG_FILE}")" -eq 1 ]] || fail "warning summary absent or duplicated"
[[ "$(grep -Ec '^[[:space:]]*Output messages[[:space:]]*=' "${LOG_FILE}")" -eq 1 ]] || fail "output summary absent or duplicated"
grep -Eq '^[[:space:]]*Logging complete\.' "${LOG_FILE}" || fail "normal completion marker absent"
grep -Fq -- "Setting up physics suite 'mesoscale_reference'" "${LOG_FILE}" || fail "physics suite initialization marker absent"
grep -Fq -- "Bootstrapping framework with mesh fields from input file 'x1.10242.init.nc'" "${LOG_FILE}" || fail "real init bootstrap marker absent"
grep -Fq -- "----- done reading initial state -----" "${LOG_FILE}" || fail "initial-state read completion marker absent"
grep -Fq -- "--- end initialize NOAH LSM tables" "${LOG_FILE}" || fail "Noah initialization marker absent"
grep -Fq -- "Finished running the atmosphere core" "${LOG_FILE}" || fail "atmosphere core completion marker absent"

readonly -a TIMESTEPS=(
    '2014-09-10_00:00:00'
    '2014-09-10_00:20:00'
    '2014-09-10_00:40:00'
)
[[ "$(grep -Ec '^[[:space:]]*Begin timestep ' "${LOG_FILE}")" -eq 3 ]] || fail "unexpected timestep count"
for timestep in "${TIMESTEPS[@]}"; do
    [[ "$(grep -Fc "Begin timestep ${timestep}" "${LOG_FILE}")" -eq 1 ]] || fail "missing or duplicated timestep: ${timestep}"
done

readonly -a COLD_START_WARNINGS=(qi qs qg)
[[ "$(grep -Ec '^WARNING: ' "${LOG_FILE}")" -eq 3 ]] || fail "unexpected warning inventory"
for variable in "${COLD_START_WARNINGS[@]}"; do
    [[ "$(grep -Fc "WARNING: Variable ${variable} not in input file." "${LOG_FILE}")" -eq 1 ]] || fail "expected cold-start warning missing: ${variable}"
done

readonly -a PHYSICS_SCHEMES=(
    'config_microp_scheme       = mp_wsm6'
    'config_convection_scheme   = cu_ntiedtke'
    'config_pbl_scheme          = bl_ysu'
    'config_gwdo_scheme         = bl_ysu_gwdo'
    'config_radt_cld_scheme     = cld_fraction'
    'config_radt_lw_scheme      = rrtmg_lw'
    'config_radt_sw_scheme      = rrtmg_sw'
    'config_sfclayer_scheme     = sf_monin_obukhov_rev'
    'config_lsm_scheme          = sf_noah'
)
for scheme in "${PHYSICS_SCHEMES[@]}"; do
    grep -Fq "${scheme}" "${LOG_FILE}" || fail "resolved physics scheme missing from log: ${scheme}"
done
printf 'physics_suite_resolved=%s\n' "${PHYSICS_SCHEMES[*]}"
printf 'log_summary=%s\n' "$(grep -E 'Output messages|Warning messages|Error messages|Critical error messages' "${LOG_FILE}" | tr '\n' ' ')"
printf 'warnings=%s\n' "$(grep -E '^WARNING: ' "${LOG_FILE}" | tr '\n' ' ')"
printf 'velocity_minmax=%s\n' "$(grep -E 'global min, max [wu] ' "${LOG_FILE}" | tr '\n' ' ')"
[[ "$(grep -Ec 'global min, max w ' "${LOG_FILE}")" -eq 3 ]] || fail "unexpected vertical-velocity min/max count"
[[ "$(grep -Ec 'global min, max u ' "${LOG_FILE}")" -eq 3 ]] || fail "unexpected horizontal-velocity min/max count"

readonly INIT_SHA256="$(sha256sum "${INIT_FILE}" | awk '{print $1}')"
readonly PARTITION_SHA256="$(sha256sum "${PARTITION_FILE}" | awk '{print $1}')"
export IMAGE IMAGE_ID COMMAND MPAS_COMMIT LOOKUP_SOURCE LOOKUP_TABLES
export INIT_SHA256 PARTITION_SHA256 CONFIG_DIR RUN_DIR MANIFEST_FILE
python3 - <<'PY'
import hashlib
import json
import os
from datetime import datetime
from pathlib import Path

run_dir = Path(os.environ["RUN_DIR"])
manifest_path = Path(os.environ["MANIFEST_FILE"])
manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
config_dir = Path(os.environ["CONFIG_DIR"])
config_names = [
    "namelist.atmosphere",
    "streams.atmosphere",
    "stream_list.atmosphere.output",
    "stream_list.atmosphere.diagnostics",
    "stream_list.atmosphere.diag_ugwp",
    "stream_list.atmosphere.surface",
]
output_names = [
    "diag.2014-09-10_00.00.00.nc",
    "diag.2014-09-10_01.00.00.nc",
    "history.2014-09-10_00.00.00.nc",
    "history.2014-09-10_01.00.00.nc",
    "log.atmosphere.0000.out",
]

def digest(path: Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            value.update(chunk)
    return value.hexdigest()

expected = {
    "schema_version": 1,
    "image": os.environ["IMAGE"],
    "image_id": os.environ["IMAGE_ID"],
    "mpas": {"version": "8.4.1", "commit": os.environ["MPAS_COMMIT"]},
    "command": os.environ["COMMAND"],
    "mpi_ranks": 4,
    "partition": "x1.10242.graph.info.part.4",
    "timestep_seconds": 1200.0,
    "run_duration": "01:00:00",
    "start_time": "2014-09-10_00:00:00",
    "end_time": "2014-09-10_01:00:00",
    "domain": "global",
    "apply_lbcs": False,
    "do_restart": False,
    "physics_suite": "mesoscale_reference",
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
}
for key, value in expected.items():
    if manifest.get(key) != value:
        raise SystemExit(f"error: manifest mismatch at {key}")

records = manifest.get("outputs")
if not isinstance(records, list) or [item.get("filename") for item in records] != output_names:
    raise SystemExit("error: manifest output inventory mismatch")
for item in records:
    path = run_dir / item["filename"]
    if not path.is_file() or path.is_symlink() or path.stat().st_size <= 0:
        raise SystemExit(f"error: unsafe or empty output: {path}")
    if item.get("size_bytes") != path.stat().st_size or item.get("sha256") != digest(path):
        raise SystemExit(f"error: output differs from manifest: {path.name}")
    print(f"output={path.name} size_bytes={path.stat().st_size} sha256={item['sha256']}")

actual_names = sorted(path.name for path in run_dir.iterdir() if path.name != "manifest.json")
if actual_names != output_names:
    raise SystemExit(f"error: unexpected files in run directory: {actual_names}")
started = datetime.fromisoformat(manifest["started_at"].replace("Z", "+00:00"))
finished = datetime.fromisoformat(manifest["finished_at"].replace("Z", "+00:00"))
if not isinstance(manifest.get("elapsed_seconds"), int) or manifest["elapsed_seconds"] < 0 or finished < started:
    raise SystemExit("error: invalid manifest timing")
print(
    f"manifest_execution={manifest['started_at']}..{manifest['finished_at']} "
    f"elapsed_seconds={manifest['elapsed_seconds']}"
)
PY

docker_args=(
    run
    --rm
    --network none
    --read-only
    --cap-drop ALL
    --security-opt no-new-privileges
    --user "$(id -u):$(id -g)"
    --mount "type=bind,source=${INIT_FILE},target=/input/x1.10242.init.nc,readonly"
    --mount "type=bind,source=${RUN_DIR},target=/run-data,readonly"
    --mount "type=bind,source=${C_SOURCE},target=/input/atmosphere_netcdf.c,readonly"
    --tmpfs /tmp:rw,exec,nosuid,nodev,size=256m
)
docker "${docker_args[@]}" "${IMAGE}" bash -euo pipefail -c '
cc -std=c11 -O2 -Wall -Wextra -Werror $(nc-config --cflags) /input/atmosphere_netcdf.c $(nc-config --libs) -lm -o /tmp/atmosphere_netcdf
/tmp/atmosphere_netcdf /input/x1.10242.init.nc /run-data/history.2014-09-10_00.00.00.nc /run-data/history.2014-09-10_01.00.00.nc /run-data/diag.2014-09-10_00.00.00.nc /run-data/diag.2014-09-10_01.00.00.nc
'

for generated in "${OUTPUT_FILES[@]}" "${MANIFEST_FILE}"; do
    git -C "${PROJECT_ROOT}" check-ignore -q "${generated}" || fail "generated artifact is not ignored: ${generated}"
    if git -C "${PROJECT_ROOT}" ls-files --error-unmatch "${generated}" >/dev/null 2>&1; then
        fail "generated atmosphere artifact is tracked: ${generated}"
    fi
done

echo 'model_clock_final=2014-09-10_01:00:00'
echo 'nan_inf_unexpected=0'
echo 'atmosphere_run_validation=PASS'
