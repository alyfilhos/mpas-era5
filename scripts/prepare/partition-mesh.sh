#!/usr/bin/env bash

set -euo pipefail

readonly IMAGE="${MESH_IMAGE:-mpas-era5:mpas-atmosphere-8.4.1}"
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
readonly DEFAULT_GRAPH=${PROJECT_ROOT}/data/meshes/x1.10242/x1.10242.graph.info

usage() {
    echo "usage: $0 [graph.info [partition-count]]" >&2
}

if [[ "$#" -gt 2 ]]; then
    usage
    exit 2
fi

readonly GRAPH_FILE="${1:-${DEFAULT_GRAPH}}"
readonly PARTITION_COUNT="${2:-4}"

if [[ ! "${PARTITION_COUNT}" =~ ^[1-9][0-9]*$ ]] || [[ "${PARTITION_COUNT}" -lt 2 ]]; then
    echo "error: partition-count must be an integer greater than one" >&2
    exit 2
fi
if [[ ! -f "${GRAPH_FILE}" || -L "${GRAPH_FILE}" || ! -s "${GRAPH_FILE}" ]]; then
    echo "error: graph is not a non-empty regular file: ${GRAPH_FILE}" >&2
    exit 1
fi
if ! command -v docker >/dev/null 2>&1; then
    echo "error: docker was not found in PATH" >&2
    exit 1
fi
if ! docker image inspect "${IMAGE}" >/dev/null 2>&1; then
    echo "error: Docker image not found or Docker is not accessible: ${IMAGE}" >&2
    exit 1
fi

readonly GRAPH_BASENAME="$(basename -- "${GRAPH_FILE}")"
readonly OUTPUT_FILE=${GRAPH_FILE}.part.${PARTITION_COUNT}
if [[ -e "${OUTPUT_FILE}" || -L "${OUTPUT_FILE}" ]]; then
    if [[ ! -f "${OUTPUT_FILE}" || -L "${OUTPUT_FILE}" ]]; then
        echo "error: existing partition is not a regular file: ${OUTPUT_FILE}" >&2
        exit 1
    fi
fi

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/mpas-era5-partition-mesh.XXXXXX")"
cleanup() {
    rm -rf -- "${work_dir}"
}
trap cleanup EXIT

cp -- "${GRAPH_FILE}" "${work_dir}/${GRAPH_BASENAME}"

echo "== METIS 5.1.0 mesh partitioning =="
echo "image=${IMAGE}"
echo "command=gpmetis -minconn -contig -niter=200 ${GRAPH_BASENAME} ${PARTITION_COUNT}"
docker run --rm \
    --network none \
    --read-only \
    --user "$(id -u):$(id -g)" \
    --mount "type=bind,source=${work_dir},target=/work" \
    --tmpfs /tmp:rw,nosuid,nodev,size=16m \
    --workdir /work \
    "${IMAGE}" \
    gpmetis -minconn -contig -niter=200 "${GRAPH_BASENAME}" "${PARTITION_COUNT}"

readonly generated_file=${work_dir}/${GRAPH_BASENAME}.part.${PARTITION_COUNT}
if [[ ! -f "${generated_file}" || -L "${generated_file}" || ! -s "${generated_file}" ]]; then
    echo "error: gpmetis did not produce the expected partition file" >&2
    exit 1
fi

if [[ -e "${OUTPUT_FILE}" ]]; then
    if ! cmp -s "${generated_file}" "${OUTPUT_FILE}"; then
        echo "error: existing partition has unexpected content: ${OUTPUT_FILE}" >&2
        exit 1
    fi
    echo "unchanged=${OUTPUT_FILE}"
else
    install -m 0644 "${generated_file}" "${OUTPUT_FILE}"
    echo "installed=${OUTPUT_FILE}"
fi

sha256sum "${OUTPUT_FILE}"
echo "partition_to_mpi_invariant=${PARTITION_COUNT}_partitions_for_${PARTITION_COUNT}_MPI_tasks"

