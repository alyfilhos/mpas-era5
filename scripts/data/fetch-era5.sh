#!/usr/bin/env bash

set -euo pipefail

readonly IMAGE="${CDS_IMAGE:-mpas-era5:cdsapi-0.7.7}"
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
readonly CONFIG_DIR="${PROJECT_ROOT}/cases/first-global-240km/era5"
readonly OUTPUT_ROOT="${PROJECT_ROOT}/data/era5"
readonly CREDENTIAL_FILE="${CDSAPI_RC_FILE:-${HOME}/.cdsapirc}"

usage() {
    echo "usage: $0 {build|version|self-test|config|probe|download} [all|pressure-levels|single-levels]" >&2
}

if [[ "$#" -lt 1 || "$#" -gt 2 ]]; then
    usage
    exit 2
fi

readonly COMMAND=$1
readonly SELECTION=${2:-all}
case "${SELECTION}" in
    all|pressure-levels|single-levels) ;;
    *)
        usage
        exit 2
        ;;
esac

if ! command -v docker >/dev/null 2>&1; then
    echo "error: docker was not found in PATH" >&2
    exit 1
fi

build_image() {
    docker build \
        --pull \
        --file "${PROJECT_ROOT}/docker/cds/Dockerfile" \
        --tag "${IMAGE}" \
        "${PROJECT_ROOT}"
}

require_image() {
    if ! docker image inspect "${IMAGE}" >/dev/null 2>&1; then
        echo "error: acquisition image not found: ${IMAGE}" >&2
        echo "action: run $0 build" >&2
        exit 1
    fi
}

readonly -a ISOLATION_ARGS=(
    --rm
    --read-only
    --cap-drop ALL
    --security-opt no-new-privileges:true
    --user "$(id -u):$(id -g)"
    --tmpfs /tmp:rw,nosuid,nodev,size=256m
)

run_offline() {
    docker run "${ISOLATION_ARGS[@]}" \
        --network none \
        --mount "type=bind,source=${CONFIG_DIR},target=/config,readonly" \
        "${IMAGE}" \
        "$@" --config-dir /config --select "${SELECTION}"
}

require_credentials() {
    if [[ ! -f "${CREDENTIAL_FILE}" || -L "${CREDENTIAL_FILE}" ]]; then
        echo "error: CDS credential must be a regular non-symlink file: ${CREDENTIAL_FILE}" >&2
        echo "action: create it according to the official CDS API documentation" >&2
        echo "action: accept the Terms of Use for both ERA5 datasets in the CDS portal" >&2
        exit 1
    fi
}

run_online() {
    local command=$1
    shift
    require_credentials
    local -a output_args=()
    if [[ "${command}" == download ]]; then
        output_args+=(
            --mount "type=bind,source=${OUTPUT_ROOT},target=/data"
        )
    fi
    docker run "${ISOLATION_ARGS[@]}" \
        --network bridge \
        --mount "type=bind,source=${CONFIG_DIR},target=/config,readonly" \
        --mount "type=bind,source=${CREDENTIAL_FILE},target=/run/secrets/cdsapirc,readonly" \
        "${output_args[@]}" \
        --env CDSAPI_RC=/run/secrets/cdsapirc \
        "${IMAGE}" \
        "${command}" --config-dir /config --select "${SELECTION}" "$@"
}

case "${COMMAND}" in
    build)
        if [[ "$#" -ne 1 ]]; then
            usage
            exit 2
        fi
        build_image
        ;;
    version)
        require_image
        docker run "${ISOLATION_ARGS[@]}" --network none "${IMAGE}" version
        ;;
    self-test)
        require_image
        docker run "${ISOLATION_ARGS[@]}" --network none "${IMAGE}" self-test
        ;;
    config)
        require_image
        run_offline config
        ;;
    probe)
        require_image
        run_online probe
        ;;
    download)
        require_image
        require_credentials
        mkdir -p "${OUTPUT_ROOT}"
        run_online download --output-root /data
        ;;
    *)
        usage
        exit 2
        ;;
esac
