#!/usr/bin/env bash

set -euo pipefail

readonly MESH_NAME=x1.10242
readonly SOURCE_URL=https://www2.mmm.ucar.edu/projects/mpas/atmosphere_meshes/x1.10242.tar.gz
readonly ARCHIVE_SHA256=4dde31932bc45aaf467e2717d17ec8e5e54d73c3ebbeea027087bfdb8b98ab56
readonly EXPECTED_CELLS=10242
readonly GRID_FILE=${MESH_NAME}.grid.nc
readonly GRAPH_FILE=${MESH_NAME}.graph.info
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
readonly DESTINATION=${PROJECT_ROOT}/data/meshes/${MESH_NAME}

for command_name in curl sha256sum tar awk cmp install mktemp; do
    if ! command -v "${command_name}" >/dev/null 2>&1; then
        echo "error: required command not found: ${command_name}" >&2
        exit 1
    fi
done

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/mpas-era5-fetch-mesh.XXXXXX")"
cleanup() {
    rm -rf -- "${work_dir}"
}
trap cleanup EXIT

readonly archive=${work_dir}/${MESH_NAME}.tar.gz
readonly archive_listing=${work_dir}/archive.list
readonly extract_dir=${work_dir}/extract
mkdir -p "${extract_dir}"

echo "== Download official MPAS mesh archive =="
echo "source_url=${SOURCE_URL}"
curl -fL --retry 3 --output "${archive}" "${SOURCE_URL}"

echo "== Verify archive integrity before extraction =="
printf '%s  %s\n' "${ARCHIVE_SHA256}" "${archive}" | sha256sum --check -
printf 'archive_size_bytes=%s\n' "$(wc -c < "${archive}")"
printf 'archive_sha256=%s\n' "${ARCHIVE_SHA256}"
echo "archive_sha256_origin=locally calculated from two independent first-party downloads"

echo "== Archive contents (listed before extraction) =="
tar -tzvf "${archive}"
tar -tzf "${archive}" > "${archive_listing}"

for expected_file in "${GRID_FILE}" "${GRAPH_FILE}"; do
    entry_count="$({
        awk -v expected="${expected_file}" '$0 == expected { count++ } END { print count + 0 }' \
            "${archive_listing}"
    })"
    if [[ "${entry_count}" -ne 1 ]]; then
        echo "error: expected exactly one archive entry named ${expected_file}; found ${entry_count}" >&2
        exit 1
    fi
done

echo "== Extract only the canonical mesh and graph artifacts =="
tar -xzf "${archive}" \
    --directory "${extract_dir}" \
    --no-same-owner \
    --no-same-permissions \
    -- "${GRID_FILE}" "${GRAPH_FILE}"

for expected_file in "${GRID_FILE}" "${GRAPH_FILE}"; do
    extracted_file=${extract_dir}/${expected_file}
    if [[ ! -f "${extracted_file}" || -L "${extracted_file}" || ! -s "${extracted_file}" ]]; then
        echo "error: extracted artifact is not a non-empty regular file: ${expected_file}" >&2
        exit 1
    fi
done

read -r graph_vertices graph_edges < <(
    awk '!/^%/ && NF { print $1, $2; exit }' "${extract_dir}/${GRAPH_FILE}"
)
if [[ "${graph_vertices}" -ne "${EXPECTED_CELLS}" || "${graph_edges}" -le 0 ]]; then
    echo "error: unexpected graph header: ${graph_vertices} ${graph_edges}" >&2
    exit 1
fi

vertex_lines="$({
    awk '!/^%/ && NF { records++ } END { print records - 1 }' \
        "${extract_dir}/${GRAPH_FILE}"
})"
if [[ "${vertex_lines}" -ne "${EXPECTED_CELLS}" ]]; then
    echo "error: expected ${EXPECTED_CELLS} graph vertex lines; found ${vertex_lines}" >&2
    exit 1
fi

mkdir -p "${DESTINATION}"
for expected_file in "${GRID_FILE}" "${GRAPH_FILE}"; do
    extracted_file=${extract_dir}/${expected_file}
    destination_file=${DESTINATION}/${expected_file}

    if [[ -e "${destination_file}" || -L "${destination_file}" ]]; then
        if [[ ! -f "${destination_file}" || -L "${destination_file}" ]]; then
            echo "error: existing destination is not a regular file: ${destination_file}" >&2
            exit 1
        fi
        if ! cmp -s "${extracted_file}" "${destination_file}"; then
            echo "error: existing destination has unexpected content: ${destination_file}" >&2
            exit 1
        fi
        echo "unchanged=${destination_file}"
    else
        install -m 0644 "${extracted_file}" "${destination_file}"
        echo "installed=${destination_file}"
    fi
done

echo "== Local canonical artifacts =="
sha256sum "${DESTINATION}/${GRID_FILE}" "${DESTINATION}/${GRAPH_FILE}"
echo "mesh_directory=${DESTINATION}"

