#!/usr/bin/env python3
"""Validate WPS intermediate format version 5 without loading data slabs."""

from __future__ import annotations

import argparse
import json
import math
import os
import struct
import sys
from collections import Counter
from datetime import datetime
from pathlib import Path
from typing import Any, BinaryIO


VERSION_FORMAT = ">i"
HEADER_FORMAT = ">24sf32s9s25s46sfiii"
LOGICAL_FORMAT = ">i"
RECORD_MARKER_FORMAT = ">I"
SMALL_RECORD_LIMIT = 4096

PROJECTIONS = {
    0: ("cylindrical_equidistant", ">8s5f", (
        "startloc", "startlat", "startlon", "deltalat", "deltalon",
        "earth_radius",
    )),
    1: ("mercator", ">8s6f", (
        "startloc", "startlat", "startlon", "dx", "dy", "truelat1",
        "earth_radius",
    )),
    3: ("lambert_conformal", ">8s8f", (
        "startloc", "startlat", "startlon", "dx", "dy", "xlonc",
        "truelat1", "truelat2", "earth_radius",
    )),
    4: ("gaussian", ">8s5f", (
        "startloc", "startlat", "startlon", "nlats", "deltalon",
        "earth_radius",
    )),
    5: ("polar_stereographic", ">8s7f", (
        "startloc", "startlat", "startlon", "dx", "dy", "xlonc",
        "truelat1", "earth_radius",
    )),
}


class ValidationError(Exception):
    """A structural or semantic error in an intermediate file."""


def decode_fortran_string(raw: bytes, label: str, *, allow_empty: bool = False) -> str:
    try:
        value = raw.decode("ascii").rstrip(" \x00")
    except UnicodeDecodeError as exc:
        raise ValidationError(f"{label} is not ASCII") from exc

    if not allow_empty and not value:
        raise ValidationError(f"{label} is empty")
    if any(ord(character) < 32 or ord(character) > 126 for character in value):
        raise ValidationError(f"{label} contains a non-printable character")
    return value


def read_marker(stream: BinaryIO, label: str, *, allow_eof: bool = False) -> int | None:
    raw = stream.read(struct.calcsize(RECORD_MARKER_FORMAT))
    if not raw and allow_eof:
        return None
    if len(raw) != struct.calcsize(RECORD_MARKER_FORMAT):
        raise ValidationError(f"{label}: truncated leading record marker")
    return struct.unpack(RECORD_MARKER_FORMAT, raw)[0]


def read_small_record(
    stream: BinaryIO,
    label: str,
    *,
    expected_size: int,
    leading_size: int | None = None,
) -> bytes:
    size = leading_size if leading_size is not None else read_marker(stream, label)
    if size != expected_size:
        raise ValidationError(
            f"{label}: record payload is {size} bytes, expected {expected_size}"
        )
    if size > SMALL_RECORD_LIMIT:
        raise ValidationError(f"{label}: refusing to load oversized metadata record")

    payload = stream.read(size)
    if len(payload) != size:
        raise ValidationError(f"{label}: truncated record payload")
    trailing_size = read_marker(stream, label)
    if trailing_size != size:
        raise ValidationError(
            f"{label}: record markers disagree ({size} != {trailing_size})"
        )
    return payload


def skip_slab_record(
    stream: BinaryIO,
    label: str,
    *,
    expected_size: int,
    file_size: int,
) -> int:
    size = read_marker(stream, label)
    if size != expected_size:
        raise ValidationError(
            f"{label}: slab payload is {size} bytes, expected {expected_size}"
        )

    payload_offset = stream.tell()
    trailing_offset = payload_offset + size
    if trailing_offset + struct.calcsize(RECORD_MARKER_FORMAT) > file_size:
        raise ValidationError(f"{label}: slab extends past EOF")

    stream.seek(size, os.SEEK_CUR)
    trailing_size = read_marker(stream, label)
    if trailing_size != size:
        raise ValidationError(
            f"{label}: slab record markers disagree ({size} != {trailing_size})"
        )
    return payload_offset


def validate_date(value: str, label: str) -> None:
    if len(value) != 19:
        raise ValidationError(f"{label}: date must have 19 characters: {value!r}")
    try:
        datetime.strptime(value, "%Y-%m-%d_%H:%M:%S")
    except ValueError as exc:
        raise ValidationError(f"{label}: invalid date: {value!r}") from exc


def validate_finite(value: float, label: str) -> None:
    if not math.isfinite(value):
        raise ValidationError(f"{label}: value is not finite")


def parse_projection(payload: bytes, iproj: int, label: str) -> tuple[str, dict[str, Any]]:
    if iproj not in PROJECTIONS:
        raise ValidationError(f"{label}: unsupported iproj={iproj}")
    projection_name, projection_format, projection_keys = PROJECTIONS[iproj]
    expected_size = struct.calcsize(projection_format)
    if len(payload) != expected_size:
        raise ValidationError(
            f"{label}: projection record is {len(payload)} bytes, expected {expected_size}"
        )

    raw_values = struct.unpack(projection_format, payload)
    startloc = decode_fortran_string(raw_values[0], f"{label} startloc")
    if startloc not in {"SWCORNER", "CENTER"}:
        raise ValidationError(f"{label}: invalid startloc={startloc!r}")

    metadata: dict[str, Any] = {"startloc": startloc}
    for key, value in zip(projection_keys[1:], raw_values[1:]):
        validate_finite(value, f"{label} {key}")
        metadata[key] = value

    startlat = metadata["startlat"]
    startlon = metadata["startlon"]
    if not -90.001 <= startlat <= 90.001:
        raise ValidationError(f"{label}: startlat={startlat} outside [-90, 90]")
    if not -360.0 <= startlon <= 360.0:
        raise ValidationError(f"{label}: startlon={startlon} outside [-360, 360]")
    if not 6000.0 <= metadata["earth_radius"] <= 7000.0:
        raise ValidationError(f"{label}: implausible earth_radius in km")

    if iproj == 0:
        if metadata["deltalat"] == 0.0 or metadata["deltalon"] == 0.0:
            raise ValidationError(f"{label}: lat/lon increments must be non-zero")
        if abs(metadata["deltalat"]) > 180.0 or abs(metadata["deltalon"]) > 360.0:
            raise ValidationError(f"{label}: implausible lat/lon increment")
    elif iproj == 4:
        if metadata["nlats"] <= 0.0 or metadata["deltalon"] == 0.0:
            raise ValidationError(f"{label}: invalid Gaussian grid metadata")
    else:
        if metadata["dx"] <= 0.0 or metadata["dy"] <= 0.0:
            raise ValidationError(f"{label}: projected grid spacing must be positive")

    return projection_name, metadata


def parse_file(path: Path) -> dict[str, Any]:
    if not path.is_file():
        raise ValidationError(f"not a regular file: {path}")
    file_size = path.stat().st_size
    if file_size == 0:
        raise ValidationError(f"empty file: {path}")

    records: list[dict[str, Any]] = []
    with path.open("rb") as stream:
        while True:
            record_offset = stream.tell()
            leading_size = read_marker(
                stream,
                f"{path}: version record",
                allow_eof=True,
            )
            if leading_size is None:
                break

            record_number = len(records) + 1
            prefix = f"{path}: slab {record_number}"
            version_payload = read_small_record(
                stream,
                f"{prefix} version",
                expected_size=struct.calcsize(VERSION_FORMAT),
                leading_size=leading_size,
            )
            version = struct.unpack(VERSION_FORMAT, version_payload)[0]
            if version != 5:
                raise ValidationError(f"{prefix}: version={version}, expected 5")

            header_payload = read_small_record(
                stream,
                f"{prefix} header",
                expected_size=struct.calcsize(HEADER_FORMAT),
            )
            (
                raw_hdate,
                xfcst,
                raw_map_source,
                raw_field,
                raw_units,
                raw_desc,
                xlvl,
                nx,
                ny,
                iproj,
            ) = struct.unpack(HEADER_FORMAT, header_payload)

            hdate = decode_fortran_string(raw_hdate, f"{prefix} hdate")
            validate_date(hdate, prefix)
            map_source = decode_fortran_string(raw_map_source, f"{prefix} map_source")
            field = decode_fortran_string(raw_field, f"{prefix} field")
            units = decode_fortran_string(raw_units, f"{prefix} units")
            desc = decode_fortran_string(raw_desc, f"{prefix} desc", allow_empty=True)
            validate_finite(xfcst, f"{prefix} xfcst")
            validate_finite(xlvl, f"{prefix} xlvl")
            if xlvl <= 0.0:
                raise ValidationError(f"{prefix}: xlvl must be positive")
            if nx <= 0 or ny <= 0:
                raise ValidationError(f"{prefix}: nx and ny must be positive")
            if nx > 1_000_000 or ny > 1_000_000:
                raise ValidationError(f"{prefix}: implausibly large dimensions")

            if iproj not in PROJECTIONS:
                raise ValidationError(f"{prefix}: unsupported iproj={iproj}")
            projection_format = PROJECTIONS[iproj][1]
            projection_payload = read_small_record(
                stream,
                f"{prefix} projection",
                expected_size=struct.calcsize(projection_format),
            )
            projection_name, projection = parse_projection(
                projection_payload,
                iproj,
                prefix,
            )

            wind_payload = read_small_record(
                stream,
                f"{prefix} wind flag",
                expected_size=struct.calcsize(LOGICAL_FORMAT),
            )
            wind_value = struct.unpack(LOGICAL_FORMAT, wind_payload)[0]
            if wind_value not in {0, 1}:
                raise ValidationError(
                    f"{prefix}: logical wind flag is {wind_value}, expected 0 or 1"
                )

            slab_bytes = nx * ny * struct.calcsize(">f")
            slab_offset = skip_slab_record(
                stream,
                f"{prefix} data",
                expected_size=slab_bytes,
                file_size=file_size,
            )

            records.append({
                "index": record_number,
                "offset": record_offset,
                "version": version,
                "hdate": hdate,
                "xfcst": xfcst,
                "map_source": map_source,
                "field": field,
                "units": units,
                "desc": desc,
                "xlvl": xlvl,
                "nx": nx,
                "ny": ny,
                "iproj": iproj,
                "projection_name": projection_name,
                "projection": projection,
                "is_wind_grid_rel": bool(wind_value),
                "slab_bytes": slab_bytes,
                "slab_offset": slab_offset,
            })

        if stream.tell() != file_size:
            raise ValidationError(
                f"{path}: parser stopped at {stream.tell()}, file size is {file_size}"
            )

    if not records:
        raise ValidationError(f"{path}: no complete WPS intermediate slabs")

    return {
        "path": str(path),
        "size_bytes": file_size,
        "record_count": len(records),
        "records": records,
    }


def check_expectations(result: dict[str, Any], args: argparse.Namespace) -> None:
    for record in result["records"]:
        label = f"{result['path']}: slab {record['index']}"
        if args.expect_date is not None and record["hdate"] != args.expect_date:
            raise ValidationError(
                f"{label}: hdate={record['hdate']!r}, expected {args.expect_date!r}"
            )
        if args.expect_nx is not None and record["nx"] != args.expect_nx:
            raise ValidationError(f"{label}: nx={record['nx']}, expected {args.expect_nx}")
        if args.expect_ny is not None and record["ny"] != args.expect_ny:
            raise ValidationError(f"{label}: ny={record['ny']}, expected {args.expect_ny}")
        if args.expect_iproj is not None and record["iproj"] != args.expect_iproj:
            raise ValidationError(
                f"{label}: iproj={record['iproj']}, expected {args.expect_iproj}"
            )


def print_human(result: dict[str, Any]) -> None:
    records = result["records"]
    field_counts = Counter(record["field"] for record in records)
    dates = sorted({record["hdate"] for record in records})
    grid_keys = sorted({
        (
            record["nx"],
            record["ny"],
            record["iproj"],
            record["projection_name"],
            tuple(sorted(record["projection"].items())),
        )
        for record in records
    }, key=repr)

    print(f"file={result['path']}")
    print(f"size_bytes={result['size_bytes']}")
    print(f"record_count={result['record_count']}")
    print("versions=5")
    print(f"dates={','.join(dates)}")
    for index, (nx, ny, iproj, name, metadata) in enumerate(grid_keys, start=1):
        metadata_text = ",".join(f"{key}={value}" for key, value in metadata)
        print(
            f"grid_{index}=nx={nx},ny={ny},iproj={iproj},projection={name},"
            f"{metadata_text}"
        )
    print("field_counts=" + ",".join(
        f"{field}:{count}" for field, count in sorted(field_counts.items())
    ))
    print("wps_intermediate_validation=PASS")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate big-endian Fortran sequential WPS intermediate v5 files."
    )
    parser.add_argument("--json", action="store_true", help="emit full JSON inventory")
    parser.add_argument("--expect-date")
    parser.add_argument("--expect-nx", type=int)
    parser.add_argument("--expect-ny", type=int)
    parser.add_argument("--expect-iproj", type=int)
    parser.add_argument("files", nargs="+", type=Path)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        results = []
        for path in args.files:
            result = parse_file(path)
            check_expectations(result, args)
            results.append(result)
    except (OSError, ValidationError, struct.error) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    if args.json:
        print(json.dumps({"files": results}, indent=2, sort_keys=True))
    else:
        for index, result in enumerate(results):
            if index:
                print()
            print_human(result)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
