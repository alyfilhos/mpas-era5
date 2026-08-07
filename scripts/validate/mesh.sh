#!/usr/bin/env bash

set -euo pipefail

readonly IMAGE="${MESH_IMAGE:-mpas-era5:mpas-atmosphere-8.4.1}"
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
readonly MESH_DIR="${1:-${PROJECT_ROOT}/data/meshes/x1.10242}"
readonly PARTITION_COUNT="${2:-4}"
readonly EXPECTED_CELLS=10242
readonly GRID_FILE=x1.10242.grid.nc
readonly GRAPH_FILE=x1.10242.graph.info
readonly PARTITION_FILE=${GRAPH_FILE}.part.${PARTITION_COUNT}

if [[ "$#" -gt 2 ]]; then
    echo "usage: $0 [mesh-directory [partition-count]]" >&2
    exit 2
fi
if [[ ! "${PARTITION_COUNT}" =~ ^[1-9][0-9]*$ ]] || [[ "${PARTITION_COUNT}" -lt 2 ]]; then
    echo "error: partition-count must be an integer greater than one" >&2
    exit 2
fi
for artifact in "${GRID_FILE}" "${GRAPH_FILE}" "${PARTITION_FILE}"; do
    if [[ ! -f "${MESH_DIR}/${artifact}" || -L "${MESH_DIR}/${artifact}" ]]; then
        echo "error: required regular file not found: ${MESH_DIR}/${artifact}" >&2
        exit 1
    fi
done
if ! command -v docker >/dev/null 2>&1; then
    echo "error: docker was not found in PATH" >&2
    exit 1
fi
if ! docker image inspect "${IMAGE}" >/dev/null 2>&1; then
    echo "error: Docker image not found or Docker is not accessible: ${IMAGE}" >&2
    exit 1
fi

docker run --rm -i \
    --network none \
    --read-only \
    --user "$(id -u):$(id -g)" \
    --mount "type=bind,source=${MESH_DIR},target=/mesh,readonly" \
    --tmpfs /tmp:rw,nosuid,nodev,size=32m \
    --env "EXPECTED_CELLS=${EXPECTED_CELLS}" \
    --env "PARTITION_COUNT=${PARTITION_COUNT}" \
    --env "GRID_FILE=${GRID_FILE}" \
    --env "GRAPH_FILE=${GRAPH_FILE}" \
    --env "PARTITION_FILE=${PARTITION_FILE}" \
    "${IMAGE}" \
    bash -s <<'CONTAINER_SCRIPT'
set -euo pipefail

readonly grid=/mesh/${GRID_FILE}
readonly graph=/mesh/${GRAPH_FILE}
readonly partition=/mesh/${PARTITION_FILE}
readonly header=/tmp/mesh-header.txt

echo "== Offline/read-only MPAS mesh validation =="
echo "network=none"
echo "mesh_mount=read-only"
echo "image_tools=ncdump,graphchk"

echo "== NetCDF format, dimensions, and MPAS mesh variables =="
readonly netcdf_format="$(ncdump -k "${grid}")"
printf 'netcdf_format=%s\n' "${netcdf_format}"
ncdump -h "${grid}" > "${header}"
grep -Eq "^[[:space:]]*nCells = ${EXPECTED_CELLS} ;" "${header}"
sed -n '/dimensions:/,/variables:/p' "${header}"

for variable in \
    latCell \
    lonCell \
    nEdgesOnCell \
    cellsOnCell \
    edgesOnCell \
    verticesOnCell \
    indexToCellID; do
    if ! grep -Eq "^[[:space:]]*[[:alnum:]_]+[[:space:]]+${variable}\\(" "${header}"; then
        echo "error: required MPAS mesh variable is absent: ${variable}" >&2
        exit 1
    fi
    grep -E "^[[:space:]]*[[:alnum:]_]+[[:space:]]+${variable}\\(" "${header}"
done

ncdump -v latCell,lonCell,nEdgesOnCell,cellsOnCell,edgesOnCell,verticesOnCell,indexToCellID \
    "${grid}" >/dev/null
echo "netcdf_core_variables_readable=yes"

echo "== METIS graphchk on the real MPAS graph =="
graphchk "${graph}"

echo "== Independent graph structure and connectivity =="
awk -v expected="${EXPECTED_CELLS}" '
    function report_error(message) {
        print "error: " message > "/dev/stderr"
        invalid = 1
    }
    /^%/ || NF == 0 { next }
    {
        record++
        if (record == 1) {
            if (NF < 2 || $1 !~ /^[0-9]+$/ || $2 !~ /^[0-9]+$/) {
                report_error("invalid graph header")
                next
            }
            vertices = $1
            edges = $2
            if (vertices != expected) {
                report_error("expected " expected " graph vertices, found " vertices)
            }
            next
        }

        vertex = record - 1
        if (vertex > vertices) {
            report_error("extra vertex line " vertex)
        }
        for (field = 1; field <= NF; field++) {
            neighbor = $field
            if (neighbor !~ /^[0-9]+$/ || neighbor < 1 || neighbor > vertices) {
                report_error("out-of-range neighbor at vertex " vertex ": " neighbor)
                continue
            }
            if (neighbor == vertex) {
                report_error("self-edge at vertex " vertex)
            }
            key = vertex SUBSEP neighbor
            if (adjacent[key]) {
                report_error("duplicate neighbor " neighbor " at vertex " vertex)
            }
            adjacent[key] = 1
            degree[vertex]++
            neighbors[vertex, degree[vertex]] = neighbor
            directed_edges++
        }
    }
    END {
        vertex_lines = record - 1
        if (vertex_lines != vertices) {
            report_error("header declares " vertices " vertices but found " vertex_lines " vertex lines")
        }
        if (directed_edges != 2 * edges) {
            report_error("header declares " edges " edges but adjacency lists encode " directed_edges / 2)
        }
        for (key in adjacent) {
            split(key, endpoints, SUBSEP)
            reverse = endpoints[2] SUBSEP endpoints[1]
            if (!adjacent[reverse]) {
                report_error("asymmetric adjacency " endpoints[1] " -> " endpoints[2])
            }
        }

        if (vertices > 0) {
            head = 1
            tail = 1
            queue[tail] = 1
            seen[1] = 1
            reached = 0
            while (head <= tail) {
                vertex = queue[head++]
                reached++
                for (i = 1; i <= degree[vertex]; i++) {
                    neighbor = neighbors[vertex, i]
                    if (!seen[neighbor]) {
                        seen[neighbor] = 1
                        queue[++tail] = neighbor
                    }
                }
            }
            if (reached != vertices) {
                report_error("graph is disconnected: reached " reached " of " vertices " vertices")
            }
        }

        printf "graph_header_vertices=%d\n", vertices
        printf "graph_header_edges=%d\n", edges
        printf "graph_vertex_lines=%d\n", vertex_lines
        printf "graph_connected=%s (%d vertices)\n", reached == vertices ? "yes" : "no", reached
        exit invalid
    }
' "${graph}"

echo "nCells_graph_vertices_match=yes (${EXPECTED_CELLS})"

echo "== Partition assignments, coverage, and balance =="
awk -v expected="${EXPECTED_CELLS}" -v parts="${PARTITION_COUNT}" '
    NF != 1 || $1 !~ /^[0-9]+$/ || $1 < 0 || $1 >= parts {
        printf "error: invalid partition assignment at line %d: %s\n", NR, $0 > "/dev/stderr"
        invalid = 1
    }
    { count[$1]++ }
    END {
        if (NR != expected) {
            printf "error: expected %d assignments, found %d\n", expected, NR > "/dev/stderr"
            invalid = 1
        }
        average = expected / parts
        minimum = expected
        maximum = 0
        for (part = 0; part < parts; part++) {
            if (count[part] == 0) {
                printf "error: partition %d is empty\n", part > "/dev/stderr"
                invalid = 1
            }
            if (count[part] < minimum) minimum = count[part]
            if (count[part] > maximum) maximum = count[part]
            printf "partition_%d_cells=%d\n", part, count[part]
        }
        ratio = maximum / average
        printf "partition_assignment_lines=%d\n", NR
        printf "average_cells_per_partition=%.3f\n", average
        printf "min_cells_per_partition=%d\n", minimum
        printf "max_cells_per_partition=%d\n", maximum
        printf "simple_imbalance_ratio=%.6f\n", ratio
        printf "simple_imbalance_percent=%.6f%%\n", (ratio - 1.0) * 100.0
        exit invalid
    }
' "${partition}"

echo "== Independent edge cut and per-partition connectivity =="
awk -v expected="${EXPECTED_CELLS}" -v parts="${PARTITION_COUNT}" '
    NR == FNR {
        assignment[NR] = $1
        partition_size[$1]++
        next
    }
    /^%/ || NF == 0 { next }
    {
        graph_record++
        if (graph_record == 1) next
        vertex = graph_record - 1
        for (field = 1; field <= NF; field++) {
            neighbor = $field
            degree[vertex]++
            neighbors[vertex, degree[vertex]] = neighbor
            if (neighbor > vertex && assignment[neighbor] != assignment[vertex]) {
                edge_cut++
            }
        }
    }
    END {
        for (part = 0; part < parts; part++) {
            start = 0
            for (vertex = 1; vertex <= expected; vertex++) {
                if (assignment[vertex] == part) {
                    start = vertex
                    break
                }
            }

            delete queue
            delete seen
            head = 1
            tail = 1
            queue[tail] = start
            seen[start] = 1
            reached = 0
            while (head <= tail) {
                vertex = queue[head++]
                reached++
                for (i = 1; i <= degree[vertex]; i++) {
                    neighbor = neighbors[vertex, i]
                    if (assignment[neighbor] == part && !seen[neighbor]) {
                        seen[neighbor] = 1
                        queue[++tail] = neighbor
                    }
                }
            }

            if (reached != partition_size[part]) {
                printf "error: partition %d is disconnected (%d of %d cells reached)\n",
                    part, reached, partition_size[part] > "/dev/stderr"
                invalid = 1
            } else {
                printf "partition_%d_connected=yes (%d cells)\n", part, reached
            }
        }
        printf "independently_computed_edge_cut=%d\n", edge_cut
        exit invalid
    }
' "${partition}" "${graph}"

echo "partition_to_mpi_invariant=${PARTITION_COUNT}_partitions_for_${PARTITION_COUNT}_MPI_tasks"
echo "mesh_smoke=PASS"
CONTAINER_SCRIPT
