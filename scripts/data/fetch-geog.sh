#!/usr/bin/env bash

set -euo pipefail

readonly HIGH_URL=https://www2.mmm.ucar.edu/wrf/src/wps_files/geog_high_res_mandatory.tar.gz
readonly HIGH_SHA256=89b026b9db0a03c0c995e53b4a1d99663af1f6bda21b3b34c3c2c07386da5493
readonly HIGH_SIZE_BYTES=2772782816
readonly HIGH_ARCHIVE_NAME=geog_high_res_mandatory.tar.gz
readonly LANDUSE_URL=https://www2.mmm.ucar.edu/wrf/src/wps_files/modis_landuse_20class_30s.tar.bz2
readonly LANDUSE_SHA256=b21ca154d1038ec271abaa1be2fd38a0cd055b8a4ddfaab520719478ac48d326
readonly LANDUSE_SIZE_BYTES=32334661
readonly LANDUSE_ARCHIVE_NAME=modis_landuse_20class_30s.tar.bz2
readonly GWD_LANDUSE_URL=https://www2.mmm.ucar.edu/wrf/src/wps_files/landuse_30s.tar.bz2
readonly GWD_LANDUSE_SHA256=143cd195ae91f64011a43eae52ca00228709672c6a2ba614cb437eeb4cd41160
readonly GWD_LANDUSE_SIZE_BYTES=20988479
readonly GWD_LANDUSE_ARCHIVE_NAME=landuse_30s.tar.bz2
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
readonly DESTINATION="${GEOG_DESTINATION:-${PROJECT_ROOT}/data/geog/mpas-8.4.1}"
readonly CACHE_DIR="${GEOG_CACHE_DIR:-${PROJECT_ROOT}/data/geog/.archives}"

readonly -a HIGH_DATASETS=(
    albedo_modis
    greenfrac_fpar_modis
    maxsnowalb_modis
    soiltemp_1deg
    soiltype_top_30s
    topo_gmted2010_30s
)
readonly LANDUSE_DATASET=modis_landuse_20class_30s
readonly GWD_LANDUSE_DATASET=landuse_30s
readonly -a ALL_DATASETS=("${HIGH_DATASETS[@]}" "${LANDUSE_DATASET}" "${GWD_LANDUSE_DATASET}")

for command_name in \
    awk cmp curl du find grep install mkdir mktemp mv python3 rm sha256sum \
    sort tar wc xargs
do
    if ! command -v "${command_name}" >/dev/null 2>&1; then
        echo "error: required command not found: ${command_name}" >&2
        exit 1
    fi
done

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/mpas-era5-fetch-geog.XXXXXX")"
destination_parent="$(dirname -- "${DESTINATION}")"
mkdir -p "${destination_parent}" "${CACHE_DIR}"
stage_dir="$(mktemp -d "${destination_parent}/.mpas-geog-stage.XXXXXX")"
cleanup() {
    rm -rf -- "${work_dir}" "${stage_dir}"
}
trap cleanup EXIT

resolve_archive() {
    local label=$1
    local url=$2
    local expected_size=$3
    local expected_sha=$4
    local archive_name=$5
    local supplied_path=$6
    local archive_path
    local observed_size

    echo "== Acquire ${label} archive =="
    echo "source_url=${url}"
    if [[ -n "${supplied_path}" ]]; then
        archive_path=${supplied_path}
        echo "archive_source=caller-supplied local cache"
    else
        archive_path=${CACHE_DIR}/${archive_name}
        echo "archive_source=first-party download cache"
        if [[ ! -e "${archive_path}" ]]; then
            curl -fL --retry 5 --retry-all-errors --continue-at - \
                --output "${archive_path}.part" "${url}"
            mv -- "${archive_path}.part" "${archive_path}"
        fi
    fi

    if [[ ! -f "${archive_path}" || -L "${archive_path}" ]]; then
        echo "error: archive is not a regular file: ${archive_path}" >&2
        exit 1
    fi
    observed_size="$(wc -c < "${archive_path}")"
    if [[ "${observed_size}" -ne "${expected_size}" ]]; then
        echo "error: ${label} archive size is ${observed_size}; expected ${expected_size}" >&2
        exit 1
    fi
    printf '%s  %s\n' "${expected_sha}" "${archive_path}" | sha256sum --check -
    printf 'archive_size_bytes=%s\n' "${observed_size}"
    printf 'archive_sha256=%s\n' "${expected_sha}"
    echo "archive_sha256_origin=locally calculated from the first-party artifact; no upstream SHA-256 is published"
    RESOLVED_ARCHIVE=${archive_path}
}

resolve_archive \
    high-resolution-mandatory \
    "${HIGH_URL}" "${HIGH_SIZE_BYTES}" "${HIGH_SHA256}" \
    "${HIGH_ARCHIVE_NAME}" "${GEOG_HIGH_ARCHIVE:-}"
readonly high_archive=${RESOLVED_ARCHIVE}

resolve_archive \
    legacy-20-category-landuse \
    "${LANDUSE_URL}" "${LANDUSE_SIZE_BYTES}" "${LANDUSE_SHA256}" \
    "${LANDUSE_ARCHIVE_NAME}" "${GEOG_LANDUSE_ARCHIVE:-}"
readonly landuse_archive=${RESOLVED_ARCHIVE}

resolve_archive \
    legacy-gwd-landuse \
    "${GWD_LANDUSE_URL}" "${GWD_LANDUSE_SIZE_BYTES}" \
    "${GWD_LANDUSE_SHA256}" "${GWD_LANDUSE_ARCHIVE_NAME}" \
    "${GEOG_GWD_LANDUSE_ARCHIVE:-}"
readonly gwd_landuse_archive=${RESOLVED_ARCHIVE}

readonly high_listing=${work_dir}/high.list
readonly landuse_tar=${work_dir}/landuse.tar
readonly landuse_listing=${work_dir}/landuse.list
readonly gwd_landuse_tar=${work_dir}/gwd-landuse.tar
readonly gwd_landuse_listing=${work_dir}/gwd-landuse.list

echo "== Validate all archives before extraction =="
tar -tzf "${high_archive}" > "${high_listing}"
python3 - "${landuse_archive}" "${landuse_tar}" <<'PYTHON'
import bz2
import shutil
import sys

source, destination = sys.argv[1:]
with bz2.open(source, "rb") as compressed, open(destination, "wb") as expanded:
    shutil.copyfileobj(compressed, expanded, length=8 * 1024 * 1024)
PYTHON
tar -tf "${landuse_tar}" > "${landuse_listing}"
python3 - "${gwd_landuse_archive}" "${gwd_landuse_tar}" <<'PYTHON'
import bz2
import shutil
import sys

source, destination = sys.argv[1:]
with bz2.open(source, "rb") as compressed, open(destination, "wb") as expanded:
    shutil.copyfileobj(compressed, expanded, length=8 * 1024 * 1024)
PYTHON
tar -tf "${gwd_landuse_tar}" > "${gwd_landuse_listing}"

for listing in "${high_listing}" "${landuse_listing}" "${gwd_landuse_listing}"; do
    if awk '$0 ~ /^\// || $0 ~ /(^|\/)\.\.(\/|$)/ { bad = 1 } END { exit bad }' "${listing}"; then
        :
    else
        echo "error: unsafe path found in archive listing: ${listing}" >&2
        exit 1
    fi
done

for dataset in "${HIGH_DATASETS[@]}"; do
    expected_entry=WPS_GEOG/${dataset}/index
    entry_count="$(awk -v expected="${expected_entry}" '$0 == expected { count++ } END { print count + 0 }' "${high_listing}")"
    if [[ "${entry_count}" -ne 1 ]]; then
        echo "error: expected one ${expected_entry}; found ${entry_count}" >&2
        exit 1
    fi
done
landuse_index_entry=${LANDUSE_DATASET}/index
landuse_entry_count="$(awk -v expected="${landuse_index_entry}" '$0 == expected { count++ } END { print count + 0 }' "${landuse_listing}")"
if [[ "${landuse_entry_count}" -ne 1 ]]; then
    echo "error: expected one ${landuse_index_entry}; found ${landuse_entry_count}" >&2
    exit 1
fi
gwd_landuse_index_entry=${GWD_LANDUSE_DATASET}/index
gwd_landuse_entry_count="$(awk -v expected="${gwd_landuse_index_entry}" '$0 == expected { count++ } END { print count + 0 }' "${gwd_landuse_listing}")"
if [[ "${gwd_landuse_entry_count}" -ne 1 ]]; then
    echo "error: expected one ${gwd_landuse_index_entry}; found ${gwd_landuse_entry_count}" >&2
    exit 1
fi

echo "== Extract only the MPAS 8.4.1 datasets selected by this case =="
high_members=()
for dataset in "${HIGH_DATASETS[@]}"; do
    high_members+=("WPS_GEOG/${dataset}")
done
tar -xzf "${high_archive}" \
    --directory "${stage_dir}" \
    --strip-components=1 \
    --no-same-owner \
    --no-same-permissions \
    -- "${high_members[@]}"
tar -xf "${landuse_tar}" \
    --directory "${stage_dir}" \
    --no-same-owner \
    --no-same-permissions \
    -- "${LANDUSE_DATASET}"
tar -xf "${gwd_landuse_tar}" \
    --directory "${stage_dir}" \
    --no-same-owner \
    --no-same-permissions \
    -- "${GWD_LANDUSE_DATASET}"

for dataset in "${ALL_DATASETS[@]}"; do
    dataset_dir=${stage_dir}/${dataset}
    if [[ ! -d "${dataset_dir}" || -L "${dataset_dir}" ]]; then
        echo "error: extracted dataset is not a directory: ${dataset}" >&2
        exit 1
    fi
    if [[ ! -f "${dataset_dir}/index" || -L "${dataset_dir}/index" ]]; then
        echo "error: dataset index is absent or unsafe: ${dataset}/index" >&2
        exit 1
    fi
    if [[ -n "$(find "${dataset_dir}" -type l -print -quit)" ]]; then
        echo "error: symbolic link found in extracted dataset: ${dataset}" >&2
        exit 1
    fi
    printf 'dataset=%s files=%s\n' \
        "${dataset}" \
        "$(find "${dataset_dir}" -type f | wc -l)"
done

grep -Fxq 'mminlu="MODIFIED_IGBP_MODIS_NOAH"' "${stage_dir}/${LANDUSE_DATASET}/index"
grep -Fxq 'category_max=20' "${stage_dir}/${LANDUSE_DATASET}/index"
grep -Fxq 'iswater=17' "${stage_dir}/${LANDUSE_DATASET}/index"

generate_manifest() {
    local root=$1
    local output=$2
    (
        cd -- "${root}"
        find . -type f ! -name .mpas-era5-manifest.sha256 -print0 \
            | LC_ALL=C sort -z \
            | xargs -0 sha256sum
    ) > "${output}"
}

readonly staged_manifest=${work_dir}/staged.sha256
generate_manifest "${stage_dir}" "${staged_manifest}"
install -m 0644 "${staged_manifest}" "${stage_dir}/.mpas-era5-manifest.sha256"

echo "== Install without overwriting divergent local data =="
if [[ -e "${DESTINATION}" || -L "${DESTINATION}" ]]; then
    if [[ ! -d "${DESTINATION}" || -L "${DESTINATION}" ]]; then
        echo "error: destination exists and is not a directory: ${DESTINATION}" >&2
        exit 1
    fi
    readonly existing_manifest=${work_dir}/existing.sha256
    generate_manifest "${DESTINATION}" "${existing_manifest}"
    if ! cmp -s "${staged_manifest}" "${existing_manifest}"; then
        echo "error: existing geographic data differ from the verified source: ${DESTINATION}" >&2
        exit 1
    fi
    echo "unchanged=${DESTINATION}"
else
    mv -- "${stage_dir}" "${DESTINATION}"
    echo "installed=${DESTINATION}"
fi

printf 'geog_size_bytes=%s\n' "$(du -sb "${DESTINATION}" | awk '{ print $1 }')"
echo "geog_directory=${DESTINATION}"
echo "geog_fetch=PASS"

