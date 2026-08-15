#!/usr/bin/env bash

set -euo pipefail

readonly IMAGE="${WPS_IMAGE:-mpas-era5:mpas-atmosphere-8.4.1}"
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
readonly ERA5_ROOT="${PROJECT_ROOT}/data/era5/2014-09-10_00"
readonly OUTPUT_ROOT="${PROJECT_ROOT}/data/cases/first-global-240km/wps"
readonly CONFIG_ROOT="${PROJECT_ROOT}/cases/first-global-240km"
readonly HOST_UID="$(id -u)"
readonly HOST_GID="$(id -g)"

fail() {
    echo "error: $*" >&2
    exit 1
}

if [[ "$#" -ne 0 ]]; then
    echo "usage: $0" >&2
    exit 2
fi

for command_name in docker python3 git mktemp id; do
    command -v "${command_name}" >/dev/null 2>&1 || \
        fail "required command not found: ${command_name}"
done

readonly PRESSURE_GRIB="${ERA5_ROOT}/era5-pressure-levels.grib"
readonly SINGLE_GRIB="${ERA5_ROOT}/era5-single-levels.grib"
readonly PRESSURE_INTERMEDIATE="${OUTPUT_ROOT}/ERA5_PRES:2014-09-10_00"
readonly SINGLE_INTERMEDIATE="${OUTPUT_ROOT}/ERA5_SFC:2014-09-10_00"
readonly COMBINED_INTERMEDIATE="${OUTPUT_ROOT}/ERA5:2014-09-10_00"
readonly PRESSURE_LOG="${OUTPUT_ROOT}/ungrib-pressure.log"
readonly SINGLE_LOG="${OUTPUT_ROOT}/ungrib-single.log"
readonly MANIFEST="${OUTPUT_ROOT}/manifest.json"

for input_path in \
    "${PRESSURE_GRIB}" \
    "${SINGLE_GRIB}" \
    "${PRESSURE_INTERMEDIATE}" \
    "${SINGLE_INTERMEDIATE}" \
    "${COMBINED_INTERMEDIATE}" \
    "${PRESSURE_LOG}" \
    "${SINGLE_LOG}"; do
    [[ -f "${input_path}" ]] || fail "required local artifact is absent: ${input_path}"
done

echo "== ERA5 raw-data regression =="
"${PROJECT_ROOT}/scripts/validate/era5.sh"

docker image inspect "${IMAGE}" >/dev/null
readonly IMAGE_ID="$(docker image inspect "${IMAGE}" --format '{{.Id}}')"
audit_workspace="$(mktemp -d /tmp/mpas-era5-wps-audit.XXXXXX)"
trap 'rm -rf -- "${audit_workspace}"' EXIT

echo "== WPS tools, g1print inventories, and upstream Vtable =="
docker run --rm \
    --network none \
    --read-only \
    --tmpfs /tmp \
    --user "${HOST_UID}:${HOST_GID}" \
    --cap-drop all \
    --security-opt no-new-privileges \
    --mount \
        "type=bind,src=${PRESSURE_GRIB},dst=/input/pressure.grib,readonly" \
    --mount \
        "type=bind,src=${SINGLE_GRIB},dst=/input/single.grib,readonly" \
    --mount \
        "type=bind,src=${audit_workspace},dst=/audit" \
    "${IMAGE}" \
    bash -euo pipefail -c '
        test -x /opt/wps/ungrib.exe
        test -x /opt/wps/g1print.exe
        test -x /opt/wps/link_grib.csh
        test -f /opt/wps/ungrib/Variable_Tables/Vtable.ECMWF
        test ! -w /opt/wps/ungrib/Variable_Tables/Vtable.ECMWF

        cp /opt/wps/ungrib/Variable_Tables/Vtable.ECMWF /audit/Vtable.ECMWF
        /opt/wps/g1print.exe /input/pressure.grib > /audit/pressure.g1print
        /opt/wps/g1print.exe /input/single.grib > /audit/single.g1print
    '

echo "== Cross GRIB -> Vtable -> ungrib log -> WPS intermediate =="
python3 "${PROJECT_ROOT}/scripts/validate/wps-era5.py" \
    --parser "${PROJECT_ROOT}/scripts/validate/wps-intermediate.py" \
    --pressure-request "${CONFIG_ROOT}/era5/pressure-levels.json" \
    --single-request "${CONFIG_ROOT}/era5/single-levels.json" \
    --pressure-grib "${PRESSURE_GRIB}" \
    --single-grib "${SINGLE_GRIB}" \
    --pressure-g1print "${audit_workspace}/pressure.g1print" \
    --single-g1print "${audit_workspace}/single.g1print" \
    --vtable "${audit_workspace}/Vtable.ECMWF" \
    --pressure-log "${PRESSURE_LOG}" \
    --single-log "${SINGLE_LOG}" \
    --pressure-intermediate "${PRESSURE_INTERMEDIATE}" \
    --single-intermediate "${SINGLE_INTERMEDIATE}" \
    --combined-intermediate "${COMBINED_INTERMEDIATE}" \
    --manifest "${MANIFEST}" \
    --image "${IMAGE}" \
    --image-id "${IMAGE_ID}"

echo "== Confirm generated artifacts remain ignored and untracked =="
for artifact in \
    data/cases/first-global-240km/wps/ERA5_PRES:2014-09-10_00 \
    data/cases/first-global-240km/wps/ERA5_SFC:2014-09-10_00 \
    data/cases/first-global-240km/wps/ERA5:2014-09-10_00 \
    data/cases/first-global-240km/wps/ungrib-pressure.log \
    data/cases/first-global-240km/wps/ungrib-single.log \
    data/cases/first-global-240km/wps/manifest.json; do
    git -C "${PROJECT_ROOT}" check-ignore -q -- "${artifact}" || \
        fail "generated artifact is not ignored by Git: ${artifact}"
    if git -C "${PROJECT_ROOT}" ls-files --error-unmatch -- "${artifact}" \
            >/dev/null 2>&1; then
        fail "generated artifact is tracked by Git: ${artifact}"
    fi
done

echo "wps_era5_git_hygiene=PASS"
echo "wps_era5_integration=PASS"
