#!/usr/bin/env bash

set -euo pipefail

readonly IMAGE="${METIS_IMAGE:-mpas-era5:metis-5.1.0}"
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
readonly FIXTURE_FILE="${PROJECT_ROOT}/tests/fixtures/metis/graph.info"

if ! command -v docker >/dev/null 2>&1; then
    echo "error: docker was not found in PATH" >&2
    exit 1
fi

if [[ ! -f "${FIXTURE_FILE}" ]]; then
    echo "error: METIS fixture not found: ${FIXTURE_FILE}" >&2
    exit 1
fi

if ! docker image inspect "${IMAGE}" >/dev/null 2>&1; then
    echo "error: Docker image not found or Docker is not accessible: ${IMAGE}" >&2
    echo "build it with:" >&2
    echo "  docker build --progress=plain --build-arg BUILD_JOBS=8 -t ${IMAGE} ${PROJECT_ROOT}" >&2
    exit 1
fi

docker run --rm -i \
    --mount "type=bind,source=${PROJECT_ROOT},target=/workspace,readonly" \
    --tmpfs /validation-output:rw,nosuid,nodev,size=16m \
    "${IMAGE}" \
    bash -s <<'CONTAINER_SCRIPT'
set -euo pipefail

readonly metis_prefix=/opt/mpas
readonly source_graph=/workspace/tests/fixtures/metis/graph.info
readonly output_dir=/validation-output
readonly graph_file=${output_dir}/graph.info
readonly partition_file=${output_dir}/graph.info.part.4
readonly partition_count=4

echo "== Installed METIS 5.1.0 interface =="
for tool in gpmetis ndmetis mpmetis m2gmetis graphchk cmpfillin; do
    command -v "${tool}"
done
test "$(command -v gpmetis)" = "${metis_prefix}/bin/gpmetis"
test -f "${metis_prefix}/include/metis.h"
test -f "${metis_prefix}/lib/libmetis.a"
grep -F "#define IDXTYPEWIDTH 32" "${metis_prefix}/include/metis.h"
grep -F "#define REALTYPEWIDTH 32" "${metis_prefix}/include/metis.h"
grep -F "#define METIS_VER_MAJOR         5" "${metis_prefix}/include/metis.h"
grep -F "#define METIS_VER_MINOR         1" "${metis_prefix}/include/metis.h"
grep -F "#define METIS_VER_SUBMINOR      0" "${metis_prefix}/include/metis.h"
nm "${metis_prefix}/lib/libmetis.a" | grep -F "METIS_PartGraphKway"

help_output="$(gpmetis -help 2>&1)"
printf '%s\n' "${help_output}"
grep -F -- "-minconn" <<<"${help_output}"
grep -F -- "-contig" <<<"${help_output}"
grep -F -- "-niter" <<<"${help_output}"

echo "== Read-only fixture copied to ephemeral storage =="
cp "${source_graph}" "${graph_file}"
test ! -e "${source_graph}.part.4"
read -r vertex_count edge_count < <(
    awk '!/^%/ && NF { print $1, $2; exit }' "${graph_file}"
)
test "${vertex_count}" -eq 16
test "${edge_count}" -eq 27
graphchk "${graph_file}"

echo "== MPAS-style four-way offline partitioning =="
cd "${output_dir}"
gpmetis_output="$(
    gpmetis -minconn -contig -niter=200 graph.info "${partition_count}" 2>&1
)"
printf '%s\n' "${gpmetis_output}"
grep -F "METIS 5.0" <<<"${gpmetis_output}"
test -s "${partition_file}"

echo "== Structural validation of graph.info.part.4 =="
partition_counts="$(
    awk -v expected="${vertex_count}" -v parts="${partition_count}" '
        NF != 1 || $1 !~ /^[0-9]+$/ || $1 < 0 || $1 >= parts {
            printf "error: invalid partition ID at output line %d: %s\n", NR, $0 > "/dev/stderr"
            invalid = 1
        }
        {
            count[$1]++
        }
        END {
            if (NR != expected) {
                printf "error: expected %d assignments, found %d\n", expected, NR > "/dev/stderr"
                invalid = 1
            }
            for (part = 0; part < parts; part++) {
                if (count[part] == 0) {
                    printf "error: partition %d is empty\n", part > "/dev/stderr"
                    invalid = 1
                }
                printf "partition_%d_vertices=%d\n", part, count[part]
            }
            exit invalid
        }
    ' "${partition_file}"
)"
printf '%s\n' "${partition_counts}"

awk -v parts="${partition_count}" '
    { count[$1]++ }
    END {
        average = NR / parts
        maximum = 0
        minimum = NR
        for (part = 0; part < parts; part++) {
            if (count[part] > maximum) maximum = count[part]
            if (count[part] < minimum) minimum = count[part]
        }
        ratio = maximum / average
        printf "average_vertices_per_partition=%.3f\n", average
        printf "min_vertices_per_partition=%d\n", minimum
        printf "max_vertices_per_partition=%d\n", maximum
        printf "simple_imbalance_ratio=%.3f\n", ratio
        printf "simple_imbalance_percent=%.3f%%\n", (ratio - 1.0) * 100.0
    }
' "${partition_file}"

computed_edge_cut="$(
    awk '
        NR == FNR {
            partition[NR] = $1
            next
        }
        FNR == 1 { next }
        {
            vertex = FNR - 1
            for (field = 1; field <= NF; field++) {
                neighbor = $field
                if (neighbor > vertex && partition[neighbor] != partition[vertex]) {
                    edge_cut++
                }
            }
        }
        END { print edge_cut + 0 }
    ' "${partition_file}" "${graph_file}"
)"
reported_edge_cut="$(
    sed -n 's/.*Edgecut: *\([0-9][0-9]*\).*/\1/p' <<<"${gpmetis_output}" \
        | tail -n 1
)"
test -n "${reported_edge_cut}"
test "${reported_edge_cut}" -eq "${computed_edge_cut}"
printf 'reported_edge_cut=%d\n' "${reported_edge_cut}"
printf 'independently_computed_edge_cut=%d\n' "${computed_edge_cut}"

echo "== Connectivity of every produced partition =="
awk -v parts="${partition_count}" -v vertices="${vertex_count}" '
    NR == FNR {
        partition[NR] = $1
        partition_size[$1]++
        next
    }
    FNR == 1 { next }
    {
        vertex = FNR - 1
        for (field = 1; field <= NF; field++) {
            adjacent[vertex, $field] = 1
        }
    }
    END {
        for (part = 0; part < parts; part++) {
            start = 0
            for (vertex = 1; vertex <= vertices; vertex++) {
                if (partition[vertex] == part) {
                    start = vertex
                    break
                }
            }

            head = 1
            tail = 1
            queue[part, tail] = start
            seen[part, start] = 1
            reached = 0

            while (head <= tail) {
                vertex = queue[part, head]
                head++
                reached++
                for (neighbor = 1; neighbor <= vertices; neighbor++) {
                    if (adjacent[vertex, neighbor] &&
                        partition[neighbor] == part &&
                        !seen[part, neighbor]) {
                        tail++
                        queue[part, tail] = neighbor
                        seen[part, neighbor] = 1
                    }
                }
            }

            if (reached != partition_size[part]) {
                printf "error: partition %d is disconnected (%d of %d vertices reached)\n",
                    part, reached, partition_size[part] > "/dev/stderr"
                invalid = 1
            } else {
                printf "partition_%d_connected=yes (%d vertices)\n", part, reached
            }
        }
        exit invalid
    }
' "${partition_file}" "${graph_file}"

echo "partition_file=${partition_file}"
echo "partition_to_mpi_invariant=4_partitions_for_4_MPI_tasks"
test ! -e "${source_graph}.part.4"
CONTAINER_SCRIPT
