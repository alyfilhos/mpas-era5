#!/usr/bin/env bash

set -euo pipefail

IMAGE="${WPS_IMAGE:-mpas-era5:mpas-atmosphere-8.4.1}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

cd "${PROJECT_ROOT}"

command -v docker >/dev/null
docker image inspect "${IMAGE}" >/dev/null

docker run --rm \
    --network none \
    --read-only \
    --tmpfs /tmp \
    "${IMAGE}" \
    bash -euo pipefail -c '
        wps_prefix=/opt/wps-4.7.0
        provenance=${wps_prefix}/.mpas-era5-provenance

        test -d "${wps_prefix}"
        test -L /opt/wps
        test "$(readlink /opt/wps)" = "${wps_prefix}"
        test "$(readlink -f /opt/wps)" = "${wps_prefix}"

        test -x "${wps_prefix}/ungrib.exe"
        test -x /opt/wps/ungrib.exe
        test "$(readlink "${wps_prefix}/ungrib.exe")" = \
             "ungrib/src/ungrib.exe"
        test "$(readlink -f /opt/wps/ungrib.exe)" = \
             "${wps_prefix}/ungrib/src/ungrib.exe"

        test -x "${wps_prefix}/g1print.exe"
        test -x /opt/wps/g1print.exe
        test -x "${wps_prefix}/util/g1print.exe"
        test "$(readlink "${wps_prefix}/g1print.exe")" = \
             "ungrib/src/g1print.exe"
        test "$(readlink "${wps_prefix}/util/g1print.exe")" = \
             "../ungrib/src/g1print.exe"
        test "$(readlink -f /opt/wps/g1print.exe)" = \
             "${wps_prefix}/ungrib/src/g1print.exe"
        test -x "${wps_prefix}/link_grib.csh"
        file -L /opt/wps/g1print.exe \
            | grep -F "ELF 64-bit LSB pie executable, x86-64"
        ldd /opt/wps/g1print.exe
        ldd /opt/wps/g1print.exe | grep -F "libgfortran.so"
        test -z "$(ldd /opt/wps/g1print.exe | grep -F "not found")"

        file -L /opt/wps/ungrib.exe \
            | grep -F "ELF 64-bit LSB pie executable, x86-64"
        file -L /opt/wps/ungrib.exe | grep -F "dynamically linked"
        ldd /opt/wps/ungrib.exe
        ldd /opt/wps/ungrib.exe | grep -F "libgfortran.so"
        test -z "$(ldd /opt/wps/ungrib.exe | grep -F "not found")"

        test -f "${provenance}"
        grep -Fx "WPS_VERSION=4.7.0" "${provenance}"
        grep -Fx "WPS_TAG=v4.7.0" "${provenance}"
        grep -Fx \
            "WPS_COMMIT=5feccecd63384381b6942371c7a837f66e4ccb84" \
            "${provenance}"
        grep -Fx \
            "WPS_SOURCE_URL=https://github.com/wrf-model/WPS/archive/refs/tags/v4.7.0.tar.gz" \
            "${provenance}"
        grep -Fx \
            "WPS_SHA256=5232d20d7556338391b66aba45824d4fcd6c42712ebe9325f359f3c6cf043808" \
            "${provenance}"
        grep -F \
            "WPS_SHA256_ORIGIN=locally calculated from two independent downloads on 2026-08-05; no upstream SHA-256 was found" \
            "${provenance}"
        grep -Fx "WPS_G1PRINT_BUILD_COMMAND=./compile g1print" \
            "${provenance}"
        grep -Fx "WPS_G1PRINT_EXECUTABLE=g1print.exe" \
            "${provenance}"
        grep -F "WRF Pre-Processing System Version 4.7.0" \
            "${wps_prefix}/README"
        grep -F "echo Version 4.7.0" "${wps_prefix}/compile"

        configure_wps=${wps_prefix}/configure.wps
        test -f "${configure_wps}"
        grep -E \
            "^#.*Settings for Linux x86_64, gfortran[[:space:]]+[(]serial[)]" \
            "${configure_wps}"
        grep -E "^SFC[[:space:]]*=[[:space:]]*gfortran[[:space:]]*$" \
            "${configure_wps}"
        grep -E "^SCC[[:space:]]*=[[:space:]]*gcc[[:space:]]*$" \
            "${configure_wps}"
        grep -E "^FC[[:space:]]*=[[:space:]]*[$][(]SFC[)]" \
            "${configure_wps}"
        grep -E "^CC[[:space:]]*=[[:space:]]*[$][(]SCC[)]" \
            "${configure_wps}"
        grep -E "^WRF_DIR[[:space:]]*=[[:space:]]*none[[:space:]]*$" \
            "${configure_wps}"
        grep -E \
            "^INTERNAL_GRIB2_PATH[[:space:]]*=[[:space:]]*${wps_prefix}/grib2[[:space:]]*$" \
            "${configure_wps}"
        grep -F -- "-DUSE_JPEG2000 -DUSE_PNG" "${configure_wps}"
        test -z "$(grep -E "^CPPFLAGS.*-D_MPI" "${configure_wps}")"
        test -x /bin/csh

        test -d "${wps_prefix}/grib2/include"
        test -f "${wps_prefix}/grib2/include/zlib.h"
        test -f "${wps_prefix}/grib2/include/png.h"
        test -f "${wps_prefix}/grib2/include/jasper/jasper.h"
        test -f "${wps_prefix}/grib2/lib/libz.a"
        test -e "${wps_prefix}/grib2/lib/libpng.a"
        test -f "${wps_prefix}/grib2/lib/libjasper.a"
        test ! -e /opt/mpas/lib/libjasper.a
        test ! -e /opt/mpas/bin/ungrib.exe

        table_dir=${wps_prefix}/ungrib/Variable_Tables
        test -f "${table_dir}/Vtable.ECMWF"
        test -f "${table_dir}/Vtable.ECMWF_sigma"
        test -f "${table_dir}/Vtable.ERA-interim.ml"
        test -f "${table_dir}/Vtable.ERA-interim.pl"
        grep -F "link correct Vtable" "${wps_prefix}/README"
        test ! -e "${wps_prefix}/Vtable"

        test ! -e "${wps_prefix}/geogrid.exe"
        test ! -e "${wps_prefix}/metgrid.exe"

        printf "%s\n" \
            "BUILD: configure + compile ungrib + incremental compile g1print: PASS" \
            "SMOKE: ungrib/g1print/link_grib, links, ldd, config, provenance, GRIB2 and Vtables: PASS" \
            "FUNCTIONAL INTEGRATION: run scripts/validate/wps-era5.sh"
    '
