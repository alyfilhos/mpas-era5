#!/usr/bin/env bash

set -euo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
readonly CONFIG_DIR="${PROJECT_ROOT}/cases/first-global-240km/era5"
readonly OUTPUT_ROOT="${PROJECT_ROOT}/data/era5"
readonly BASELINE_RELATIVE=data/era5/2014-09-10_00
readonly BASELINE_DIR=${PROJECT_ROOT}/${BASELINE_RELATIVE}

if [[ "$#" -ne 0 ]]; then
    echo "usage: $0" >&2
    exit 2
fi

for command_name in python3 git sha256sum; do
    if ! command -v "${command_name}" >/dev/null 2>&1; then
        echo "error: required command not found: ${command_name}" >&2
        exit 1
    fi
done

echo "== Validate versioned ERA5 requests and local GRIB transport =="
python3 "${PROJECT_ROOT}/scripts/data/fetch-era5.py" validate \
    --config-dir "${CONFIG_DIR}" \
    --output-root "${OUTPUT_ROOT}"

echo "== Confirm local scientific data are ignored and untracked =="
for artifact in \
    "${BASELINE_RELATIVE}/era5-pressure-levels.grib" \
    "${BASELINE_RELATIVE}/era5-single-levels.grib" \
    "${BASELINE_RELATIVE}/manifest.json"; do
    if ! git -C "${PROJECT_ROOT}" check-ignore -q -- "${artifact}"; then
        echo "error: local ERA5 artifact is not ignored by Git: ${artifact}" >&2
        exit 1
    fi
    if git -C "${PROJECT_ROOT}" ls-files --error-unmatch -- "${artifact}" >/dev/null 2>&1; then
        echo "error: local ERA5 artifact is tracked by Git: ${artifact}" >&2
        exit 1
    fi
done

echo "== Confirm request configurations remain trackable =="
for request in \
    cases/first-global-240km/era5/pressure-levels.json \
    cases/first-global-240km/era5/single-levels.json \
    cases/first-global-240km/era5/README.md; do
    if git -C "${PROJECT_ROOT}" check-ignore -q -- "${request}"; then
        echo "error: versioned ERA5 request is unexpectedly ignored: ${request}" >&2
        exit 1
    fi
done

if git -C "${PROJECT_ROOT}" ls-files --error-unmatch -- .cdsapirc >/dev/null 2>&1; then
    echo "error: .cdsapirc must never be tracked" >&2
    exit 1
fi

sha256sum \
    "${BASELINE_DIR}/era5-pressure-levels.grib" \
    "${BASELINE_DIR}/era5-single-levels.grib"
echo "era5_git_hygiene=PASS"
echo "era5_validation=PASS"
