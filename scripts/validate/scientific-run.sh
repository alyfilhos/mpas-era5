#!/usr/bin/env bash

set -euo pipefail

readonly ANALYSIS_IMAGE="${ANALYSIS_IMAGE:-mpas-era5:analysis-0014}"
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
readonly RUN_DIR="${PROJECT_ROOT}/data/cases/first-global-240km/atmosphere/run-001"
readonly INIT_FILE="${PROJECT_ROOT}/data/cases/first-global-240km/init/x1.10242.init.nc"
readonly OUTPUT_DIR_INPUT="${1:-${PROJECT_ROOT}/docs/assets/validation/0014}"
readonly OUTPUT_DIR="$(realpath -m -- "${OUTPUT_DIR_INPUT}")"
readonly SUMMARY="${OUTPUT_DIR}/summary.json"

fail() { echo "error: $*" >&2; exit 1; }

[[ "$#" -le 1 ]] || { echo "usage: $0 [OUTPUT_DIRECTORY]" >&2; exit 2; }
for command_name in docker git id python3 realpath; do
    command -v "${command_name}" >/dev/null 2>&1 || fail "required command not found: ${command_name}"
done

"${SCRIPT_DIR}/atmosphere-run.sh" "${RUN_DIR}"

[[ -d "${RUN_DIR}" && ! -L "${RUN_DIR}" ]] || fail "canonical run directory is absent or unsafe"
[[ -f "${INIT_FILE}" && ! -L "${INIT_FILE}" ]] || fail "canonical init file is absent or unsafe"
mkdir -p -- "${OUTPUT_DIR}"
[[ -d "${OUTPUT_DIR}" && ! -L "${OUTPUT_DIR}" ]] || fail "analysis output directory is unsafe"
docker image inspect "${ANALYSIS_IMAGE}" >/dev/null 2>&1 || \
    fail "analysis image not found: ${ANALYSIS_IMAGE}; build it with docker/analysis/Dockerfile"

docker_args=(
    run
    --rm
    --network none
    --read-only
    --cap-drop ALL
    --security-opt no-new-privileges
    --user "$(id -u):$(id -g)"
    --env PYTHONHASHSEED=0
    --env OMP_NUM_THREADS=1
    --env OPENBLAS_NUM_THREADS=1
    --mount "type=bind,source=${RUN_DIR},target=/input/run,readonly"
    --mount "type=bind,source=${INIT_FILE},target=/input/init.nc,readonly"
    --mount "type=bind,source=${OUTPUT_DIR},target=/output"
    --tmpfs /tmp:rw,nosuid,nodev,size=256m
)
docker "${docker_args[@]}" "${ANALYSIS_IMAGE}" \
    --run-dir /input/run \
    --init-file /input/init.nc \
    --output-dir /output

[[ -f "${SUMMARY}" && ! -L "${SUMMARY}" ]] || fail "summary was not produced"

env SUMMARY="${SUMMARY}" OUTPUT_DIR="${OUTPUT_DIR}" python3 - <<'PY'
import csv
import json
import os
import struct
from pathlib import Path

summary_path = Path(os.environ["SUMMARY"])
output_dir = Path(os.environ["OUTPUT_DIR"])
summary = json.loads(summary_path.read_text(encoding="utf-8"))

expected_top_level = {
    "schema_version",
    "analysis",
    "run",
    "statuses",
    "criteria",
    "timestamps",
    "dimensions",
    "numeric_audit",
    "fields",
    "q2_diagnostic",
    "qv_diagnostic",
    "precipitation",
    "sst",
    "surface_evolution",
    "dry_air_mass",
    "water_inventory",
    "launcher_numeric_notes",
    "figures",
    "tabular_artifacts",
    "limitations",
}
if set(summary) != expected_top_level or summary["schema_version"] != "1.0.0":
    raise SystemExit("error: summary top-level schema mismatch")

expected_statuses = {
    "functional_validation": "PASS",
    "numerical_sanity": "PASS",
    "scientific_sanity": "PASS",
    "forecast_skill": "NOT_EVALUATED",
    "spinup": "INSUFFICIENT_TEMPORAL_WINDOW",
}
if summary["statuses"] != expected_statuses:
    raise SystemExit("error: scientific status mismatch")

expected_dependencies = {
    "numpy": "2.5.2",
    "xarray": "2026.7.0",
    "netCDF4": "1.7.4",
    "matplotlib": "3.11.1",
}
if summary["analysis"].get("dependencies") != expected_dependencies:
    raise SystemExit("error: analysis dependency versions mismatch")

run = summary["run"]
if (
    run.get("materialized_by_commit") != "66ffe7746b4ba144f179d4cea3011e1f0b178d38"
    or run.get("cycle_0013_base_commit") != "0d499294e94661444243f9dbdadae0c776fa5c23"
    or run.get("mpas_version") != "8.4.1"
    or run.get("nCells") != 10242
    or run.get("nVertLevels") != 55
    or run.get("mpi_ranks") != 4
    or run.get("timestep_seconds") != 1200.0
):
    raise SystemExit("error: run identity mismatch in summary")

criteria = summary["criteria"]
if not isinstance(criteria, list) or not criteria:
    raise SystemExit("error: criteria inventory is empty")
for item in criteria:
    if item.get("class") == "PASS_FAIL" and item.get("result") != "PASS":
        raise SystemExit(f"error: PASS/FAIL criterion did not pass: {item.get('id')}")
    if item.get("class") == "REPORT_ONLY" and item.get("result") != "REPORTED":
        raise SystemExit(f"error: report-only diagnostic was not reported: {item.get('id')}")
    if item.get("class") not in {"PASS_FAIL", "REPORT_ONLY"}:
        raise SystemExit(f"error: unknown criterion class: {item.get('class')}")

required_fields = {
    "rho",
    "pressure",
    "theta",
    "temperature_derived",
    "u",
    "w",
    "qv",
    "qc",
    "qr",
    "qi",
    "qs",
    "qg",
    "surface_pressure",
    "mslp",
    "skintemp",
    "sst",
    "t2m",
    "q2",
    "u10",
    "v10",
    "wind_speed_10m",
    "rainc",
    "rainnc",
    "acsnow",
}
if not required_fields.issubset(summary["fields"]):
    raise SystemExit("error: required analyzed fields are missing")
for name, field in summary["fields"].items():
    for time in ("t0", "t1"):
        stats = field[time]
        if stats["nan_count"] or stats["inf_count"] or stats["missing_count"]:
            raise SystemExit(f"error: non-finite or missing value in {name} {time}")
        if stats["finite_count"] != stats["count"]:
            raise SystemExit(f"error: incomplete finite count in {name} {time}")

q2 = summary["q2_diagnostic"]
q2_csv = output_dir / q2["rows_file"]
with q2_csv.open("r", encoding="utf-8", newline="") as stream:
    rows = list(csv.DictReader(stream))
if len(rows) != q2["count"]:
    raise SystemExit("error: q2 CSV row count differs from summary")
if q2["criterion_class"] != "REPORT_ONLY" or q2["exact_cellwise_reconstruction_possible"] is not False:
    raise SystemExit("error: q2 diagnostic classification mismatch")

if summary["sst"]["array_equal"] is not True or summary["sst"]["sha256_t0"] != summary["sst"]["sha256_t1"]:
    raise SystemExit("error: fixed-SST evidence mismatch")
if summary["dry_air_mass"]["classification"] != "REPORT_ONLY" or summary["dry_air_mass"]["threshold"] is not None:
    raise SystemExit("error: dry-air mass diagnostic was incorrectly promoted to a thresholded test")
if summary["water_inventory"]["budget_closed"] is not False:
    raise SystemExit("error: incomplete water inventory was called closed")

expected_figures = [
    "t2m-t1.png",
    "delta-t2m.png",
    "mslp-t1.png",
    "wind10-t1.png",
    "precipitation-1h.png",
    "q2-negative-cells.png",
    "temperature-profile.png",
]
if summary["figures"] != expected_figures:
    raise SystemExit("error: figure inventory mismatch")
for filename in expected_figures:
    path = output_dir / filename
    if not path.is_file() or path.is_symlink() or path.stat().st_size < 1024:
        raise SystemExit(f"error: missing, unsafe, or empty figure: {filename}")
    with path.open("rb") as stream:
        signature = stream.read(8)
        length = struct.unpack(">I", stream.read(4))[0]
        chunk = stream.read(4)
        width, height = struct.unpack(">II", stream.read(8))
    if signature != b"\x89PNG\r\n\x1a\n" or length != 13 or chunk != b"IHDR" or width == 0 or height == 0:
        raise SystemExit(f"error: invalid PNG structure: {filename}")
    print(f"figure={filename} size_bytes={path.stat().st_size} dimensions={width}x{height}")

if summary_path.stat().st_size > 2 * 1024 * 1024:
    raise SystemExit("error: summary is unexpectedly large for a versioned documentation artifact")
print(f"summary_schema=PASS size_bytes={summary_path.stat().st_size}")
print(f"q2_rows={len(rows)}")
PY

echo 'functional_validation=PASS'
echo 'numerical_sanity=PASS'
echo 'scientific_sanity=PASS'
echo 'forecast_skill=NOT_EVALUATED'
echo 'spinup=INSUFFICIENT_TEMPORAL_WINDOW'
