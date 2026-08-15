#!/usr/bin/env python3
"""Cross-check ERA5 GRIB1, Vtable.ECMWF, ungrib logs, and WPS headers."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import re
import subprocess
import sys
import tempfile
from collections import Counter, defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable


G1PRINT_LINE = re.compile(
    r"^\s*(?P<record>\d+)\s+"
    r"(?P<parameter>\d+)\s+"
    r"(?P<name>\S+)\s+"
    r"(?P<level_type>\d+)\s+"
    r"(?P<level1>\d+)\s+"
    r"(?P<level2>\d+)\s+"
    r"(?P<date>\d{4}-\d{2}-\d{2}_\d{2}:\d{2})\s+"
    r"\+\s+(?P<forecast>\d+)$"
)

SURFACE_LEVEL = 200100.0
EXPECTED_NX = 1440
EXPECTED_NY = 721
EXPECTED_IPROJ = 0
EXPECTED_RESOLUTION_DEGREES = 0.25

# Baseline contract between CDS request names and the GRIB1 identities published
# by ECMWF and observed by the WPS g1print utility. Final WPS field names are
# deliberately not encoded here; they continue to be derived from Vtable.ECMWF.
CDS_VARIABLE_TO_GRIB1 = {
    "pressure": {
        "geopotential": (129, "Z", 100, None, 0),
        "relative_humidity": (157, "R", 100, None, 0),
        "temperature": (130, "T", 100, None, 0),
        "u_component_of_wind": (131, "U", 100, None, 0),
        "v_component_of_wind": (132, "V", 100, None, 0),
    },
    "single": {
        "10m_u_component_of_wind": (165, "10U", 1, 0, 0),
        "10m_v_component_of_wind": (166, "10V", 1, 0, 0),
        "2m_temperature": (167, "2T", 1, 0, 0),
        "2m_dewpoint_temperature": (168, "2D", 1, 0, 0),
        "geopotential": (129, "Z", 1, 0, 0),
        "land_sea_mask": (172, "LSM", 1, 0, 0),
        "mean_sea_level_pressure": (151, "MSL", 1, 0, 0),
        "sea_ice_cover": (31, "CI", 1, 0, 0),
        "skin_temperature": (235, "SKT", 1, 0, 0),
        "snow_depth": (141, "SD", 1, 0, 0),
        "soil_temperature_level_1": (139, "STL1", 112, 0, 7),
        "soil_temperature_level_2": (170, "STL2", 112, 7, 28),
        "soil_temperature_level_3": (183, "STL3", 112, 28, 100),
        "soil_temperature_level_4": (236, "STL4", 112, 100, 255),
        "surface_pressure": (134, "SP", 1, 0, 0),
        "volumetric_soil_water_layer_1": (39, "SWVL1", 112, 0, 7),
        "volumetric_soil_water_layer_2": (40, "SWVL2", 112, 7, 28),
        "volumetric_soil_water_layer_3": (41, "SWVL3", 112, 28, 100),
        "volumetric_soil_water_layer_4": (42, "SWVL4", 112, 100, 255),
    },
}

class ValidationError(Exception):
    """A cross-layer ERA5/WPS validation error."""


@dataclass(frozen=True)
class GribMessage:
    record: int
    parameter: int
    name: str
    level_type: int
    level1: int
    level2: int
    date: str
    forecast: int


@dataclass(frozen=True)
class VtableRow:
    parameter: int | None
    level_type: int
    level1: str
    level2: str
    field: str
    units: str
    description: str

    def matches(self, message: GribMessage) -> bool:
        if self.parameter is None or self.parameter != message.parameter:
            return False
        if self.level_type != message.level_type:
            return False
        if self.level1 not in {"", "*"} and int(self.level1) != message.level1:
            return False
        if self.level2 not in {"", "*"} and int(self.level2) != message.level2:
            return False
        return True


def fail(message: str) -> None:
    raise ValidationError(message)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def sha256_concatenation(paths: Iterable[Path]) -> str:
    digest = hashlib.sha256()
    for path in paths:
        with path.open("rb") as stream:
            for block in iter(lambda: stream.read(1024 * 1024), b""):
                digest.update(block)
    return digest.hexdigest()


def load_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        fail(f"cannot read JSON {path}: {exc}")
    if not isinstance(value, dict):
        fail(f"JSON root is not an object: {path}")
    return value


def validate_grib1_framing(path: Path) -> tuple[int, set[int]]:
    if not path.is_file() or path.stat().st_size == 0:
        fail(f"GRIB is missing or empty: {path}")

    file_size = path.stat().st_size
    offset = 0
    message_count = 0
    editions: set[int] = set()
    with path.open("rb") as stream:
        while offset < file_size:
            stream.seek(offset)
            header = stream.read(8)
            if len(header) != 8 or header[:4] != b"GRIB":
                fail(f"{path}: invalid GRIB header at byte {offset}")
            message_size = int.from_bytes(header[4:7], byteorder="big")
            edition = header[7]
            if message_size < 12 or offset + message_size > file_size:
                fail(f"{path}: invalid message size {message_size} at byte {offset}")
            stream.seek(offset + message_size - 4)
            if stream.read(4) != b"7777":
                fail(f"{path}: missing GRIB end marker at byte {offset}")
            editions.add(edition)
            message_count += 1
            offset += message_size

    if offset != file_size:
        fail(f"{path}: GRIB framing ended at {offset}, file size is {file_size}")
    if editions != {1}:
        fail(f"{path}: expected only GRIB Edition 1, observed {sorted(editions)}")
    return message_count, editions


def parse_g1print(path: Path) -> list[GribMessage]:
    messages: list[GribMessage] = []
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError as exc:
        fail(f"cannot read g1print inventory {path}: {exc}")

    for line in lines:
        match = G1PRINT_LINE.match(line)
        if not match:
            continue
        values = match.groupdict()
        messages.append(GribMessage(
            record=int(values["record"]),
            parameter=int(values["parameter"]),
            name=values["name"],
            level_type=int(values["level_type"]),
            level1=int(values["level1"]),
            level2=int(values["level2"]),
            date=values["date"],
            forecast=int(values["forecast"]),
        ))

    if not messages:
        fail(f"no messages parsed from g1print inventory: {path}")
    expected_records = list(range(1, len(messages) + 1))
    if [message.record for message in messages] != expected_records:
        fail(f"g1print record numbers are not consecutive in {path}")
    return messages


def parse_vtable(path: Path) -> list[VtableRow]:
    rows: list[VtableRow] = []
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError as exc:
        fail(f"cannot read Vtable {path}: {exc}")

    for line in lines:
        if not line.strip() or line.lstrip().startswith("#") or "|" not in line:
            continue
        columns = [column.strip() for column in line.split("|")]
        if len(columns) < 7 or not columns[1].isdigit():
            continue
        parameter = int(columns[0]) if columns[0].isdigit() else None
        rows.append(VtableRow(
            parameter=parameter,
            level_type=int(columns[1]),
            level1=columns[2],
            level2=columns[3],
            field=columns[4],
            units=columns[5],
            description=columns[6],
        ))

    if not rows:
        fail(f"no GRIB1 rows parsed from Vtable: {path}")
    return rows


def map_messages(
    label: str,
    messages: list[GribMessage],
    vtable_rows: list[VtableRow],
) -> list[VtableRow]:
    mappings: list[VtableRow] = []
    for message in messages:
        matches = [row for row in vtable_rows if row.matches(message)]
        if len(matches) != 1:
            fail(
                f"{label} record {message.record}: expected exactly one Vtable match for "
                f"parameter={message.parameter}, level_type={message.level_type}, "
                f"levels={message.level1}/{message.level2}; found {len(matches)}"
            )
        mappings.append(matches[0])
    return mappings


def validate_request_and_inventory(
    label: str,
    request: dict[str, Any],
    messages: list[GribMessage],
    raw_message_count: int,
) -> None:
    expected_count = request.get("expected_message_count")
    if not isinstance(expected_count, int) or expected_count != len(messages):
        fail(f"{label}: request count does not match g1print count")
    if raw_message_count != len(messages):
        fail(f"{label}: GRIB framing count does not match g1print count")

    baseline = request.get("baseline_timestamp")
    if not isinstance(baseline, str) or not baseline.endswith("Z"):
        fail(f"{label}: invalid baseline_timestamp in request")
    expected_g1_date = baseline.removesuffix("Z").replace("T", "_")[:16]
    if {message.date for message in messages} != {expected_g1_date}:
        fail(f"{label}: g1print timestamp differs from request baseline")
    if {message.forecast for message in messages} != {0}:
        fail(f"{label}: expected analysis forecast hour 0")

    request_body = request.get("request")
    if not isinstance(request_body, dict):
        fail(f"{label}: request body is absent")
    variables = request_body.get("variable")
    if not isinstance(variables, list):
        fail(f"{label}: request variables are absent")
    try:
        requested_grib1 = [CDS_VARIABLE_TO_GRIB1[label][variable] for variable in variables]
    except KeyError as exc:
        fail(f"{label}: no audited GRIB1 identity for request variable {exc.args[0]!r}")

    if label == "pressure":
        expected_identities = {
            (parameter, short_name, level_type)
            for parameter, short_name, level_type, _, _ in requested_grib1
        }
        observed_identities = {
            (message.parameter, message.name, message.level_type)
            for message in messages
        }
        if observed_identities != expected_identities:
            fail(
                "pressure: g1print parameter/name/level-type identities differ "
                "from the CDS request"
            )
        requested_levels = request_body.get("pressure_level")
        if not isinstance(requested_levels, list):
            fail("pressure: requested levels are absent")
        expected_levels = {int(level) for level in requested_levels}
        by_parameter: dict[int, list[GribMessage]] = defaultdict(list)
        for message in messages:
            by_parameter[message.parameter].append(message)
        if len(by_parameter) != len(variables):
            fail("pressure: unique parameter count differs from request variable count")
        for parameter, parameter_messages in by_parameter.items():
            if {message.level_type for message in parameter_messages} != {100}:
                fail(f"pressure parameter {parameter}: level type is not isobaric 100")
            if {message.level2 for message in parameter_messages} != {0}:
                fail(f"pressure parameter {parameter}: unexpected second level value")
            levels = [message.level1 for message in parameter_messages]
            if set(levels) != expected_levels or len(levels) != len(expected_levels):
                fail(f"pressure parameter {parameter}: levels differ from request")
    else:
        if len(messages) != len(variables):
            fail("single: message count differs from request variable count")
        expected_semantics = set(requested_grib1)
        observed_semantics = {
            (message.parameter, message.name, message.level_type,
             message.level1, message.level2)
            for message in messages
        }
        if observed_semantics != expected_semantics:
            missing = sorted(expected_semantics - observed_semantics, key=repr)
            unexpected = sorted(observed_semantics - expected_semantics, key=repr)
            fail(
                "single: g1print semantic identities differ from the CDS request; "
                f"missing={missing}, unexpected={unexpected}"
            )
        if len(observed_semantics) != len(messages):
            fail("single: duplicate GRIB semantic tuple")


def run_intermediate_parser(parser: Path, paths: list[Path]) -> list[dict[str, Any]]:
    command = [
        sys.executable,
        str(parser),
        "--json",
        "--expect-date", "2014-09-10_00:00:00",
        "--expect-nx", str(EXPECTED_NX),
        "--expect-ny", str(EXPECTED_NY),
        "--expect-iproj", str(EXPECTED_IPROJ),
        *(str(path) for path in paths),
    ]
    completed = subprocess.run(
        command,
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if completed.returncode != 0:
        fail(f"WPS intermediate parser failed: {completed.stderr.strip()}")
    try:
        payload = json.loads(completed.stdout)
    except json.JSONDecodeError as exc:
        fail(f"WPS intermediate parser returned invalid JSON: {exc}")
    files = payload.get("files")
    if not isinstance(files, list) or len(files) != len(paths):
        fail("WPS intermediate parser returned an unexpected file inventory")
    return files


def close(value: float, expected: float, tolerance: float = 1.0e-5) -> bool:
    return math.isclose(value, expected, rel_tol=0.0, abs_tol=tolerance)


def validate_grid(records: list[dict[str, Any]]) -> dict[str, Any]:
    if not records:
        fail("intermediate inventory is empty")
    for record in records:
        if (record["nx"], record["ny"], record["iproj"]) != (
            EXPECTED_NX, EXPECTED_NY, EXPECTED_IPROJ
        ):
            fail("intermediate grid dimensions/projection differ from the ERA5 baseline")
        projection = record["projection"]
        if not close(abs(projection["deltalat"]), EXPECTED_RESOLUTION_DEGREES):
            fail("ERA5 latitude resolution is not 0.25 degrees")
        if not close(abs(projection["deltalon"]), EXPECTED_RESOLUTION_DEGREES):
            fail("ERA5 longitude resolution is not 0.25 degrees")
        if not close(abs(projection["startlat"]), 90.0):
            fail("ERA5 grid does not start at a pole")
        if not close(abs(projection["deltalat"]) * (record["ny"] - 1), 180.0):
            fail("ERA5 latitude grid does not span pole to pole")
        if not close(abs(projection["deltalon"]) * record["nx"], 360.0):
            fail("ERA5 longitude grid does not span 360 degrees")

    first = records[0]
    return {
        "nx": first["nx"],
        "ny": first["ny"],
        "iproj": first["iproj"],
        "projection": first["projection_name"],
        "startloc": first["projection"]["startloc"],
        "startlat": first["projection"]["startlat"],
        "startlon": first["projection"]["startlon"],
        "deltalat": first["projection"]["deltalat"],
        "deltalon": first["projection"]["deltalon"],
        "earth_radius_km": first["projection"]["earth_radius"],
    }


def actual_counter(records: list[dict[str, Any]]) -> Counter[str]:
    return Counter(record["field"] for record in records)


def expected_source_counter(mappings: list[VtableRow]) -> Counter[str]:
    return Counter(row.field for row in mappings)


def expected_source_units(mappings: list[VtableRow]) -> dict[str, set[str]]:
    units: dict[str, set[str]] = defaultdict(set)
    for row in mappings:
        units[row.field].add(row.units)
    return units


def replace_derived_units(
    units: dict[str, set[str]],
    source_field: str,
    target_field: str,
    vtable_rows: list[VtableRow],
) -> None:
    units.pop(source_field, None)
    target_units = {
        row.units for row in vtable_rows if row.field == target_field
    }
    if len(target_units) != 1:
        fail(
            f"Vtable derived field {target_field} does not have exactly one unit: "
            f"{sorted(target_units)}"
        )
    units[target_field] = target_units


def validate_field_units(
    label: str,
    records: list[dict[str, Any]],
    expected: dict[str, set[str]],
) -> None:
    actual: dict[str, set[str]] = defaultdict(set)
    for record in records:
        actual[record["field"]].add(record["units"])
    for field, expected_units in expected.items():
        if actual[field] != expected_units:
            fail(
                f"{label} field {field}: units {sorted(actual[field])} differ from "
                f"Vtable-derived units {sorted(expected_units)}"
            )


def require_counter_at_least(
    label: str,
    actual: Counter[str],
    expected: Counter[str],
) -> Counter[str]:
    missing = expected - actual
    if missing:
        fail(f"{label}: missing expected intermediate fields/counts: {dict(missing)}")
    return actual - expected


def pressure_levels(records: list[dict[str, Any]], field: str) -> set[int]:
    return {round(record["xlvl"]) for record in records if record["field"] == field}


def require_level(records: list[dict[str, Any]], field: str, level: float) -> None:
    if not any(record["field"] == field and close(record["xlvl"], level, 0.5)
               for record in records):
        fail(f"field {field} is absent at WPS level {level:g}")


def find_mapped_field(
    rows: Iterable[VtableRow],
    *,
    description_fragment: str,
    level_type: int,
) -> str:
    matches = {
        row.field for row in rows
        if row.level_type == level_type and description_fragment in row.description
    }
    if len(matches) != 1:
        fail(
            f"cannot derive one field for description {description_fragment!r} "
            f"and level type {level_type}"
        )
    return next(iter(matches))


def validate_pressure_headers(
    request: dict[str, Any],
    mappings: list[VtableRow],
    vtable_rows: list[VtableRow],
    records: list[dict[str, Any]],
) -> tuple[Counter[str], Counter[str], dict[str, str]]:
    source_expected = expected_source_counter(mappings)
    expected = source_expected.copy()
    expected_units = expected_source_units(mappings)
    if source_expected["GEOPT"]:
        if not any(row.field == "HGT" for row in vtable_rows):
            fail("Vtable lacks HGT target used by rrpr.F for GEOPT conversion")
        geopt_count = expected.pop("GEOPT")
        expected["HGT"] += geopt_count
        replace_derived_units(expected_units, "GEOPT", "HGT", vtable_rows)

    actual = actual_counter(records)
    additions = require_counter_at_least("pressure intermediate", actual, expected)
    validate_field_units("pressure intermediate", records, expected_units)

    requested_levels = {
        int(level) * 100 for level in request["request"]["pressure_level"]
    }
    for field in set(expected):
        if pressure_levels(records, field) != requested_levels:
            fail(f"pressure field {field}: intermediate levels differ from request")

    roles = {
        "temperature_3d": find_mapped_field(
            mappings, description_fragment="Temperature", level_type=100
        ),
        "u_wind_3d": find_mapped_field(
            mappings, description_fragment="U", level_type=100
        ),
        "v_wind_3d": find_mapped_field(
            mappings, description_fragment="V", level_type=100
        ),
        "relative_humidity_3d": find_mapped_field(
            mappings, description_fragment="Relative Humidity", level_type=100
        ),
        "geopotential_height_3d": "HGT",
    }
    for role, field in roles.items():
        if pressure_levels(records, field) != requested_levels:
            fail(f"functional role {role} lacks 37 isobaric levels")
    return expected, additions, roles


def validate_single_headers(
    request: dict[str, Any],
    mappings: list[VtableRow],
    vtable_rows: list[VtableRow],
    records: list[dict[str, Any]],
) -> tuple[Counter[str], Counter[str], dict[str, Any]]:
    source_expected = expected_source_counter(mappings)
    expected = source_expected.copy()
    expected_units = expected_source_units(mappings)
    if source_expected["DEWPT"] and source_expected["TT"]:
        if not any(row.parameter is None and row.field == "RH" for row in vtable_rows):
            fail("Vtable lacks the derived surface RH row")
        dewpt_count = expected.pop("DEWPT")
        expected["RH"] += dewpt_count
        replace_derived_units(expected_units, "DEWPT", "RH", vtable_rows)
    if source_expected["SOILGEO"]:
        if not any(row.field == "SOILHGT" for row in vtable_rows):
            fail("Vtable lacks SOILHGT used by rrpr.F")
        soilgeo_count = expected.pop("SOILGEO")
        expected["SOILHGT"] += soilgeo_count
        replace_derived_units(expected_units, "SOILGEO", "SOILHGT", vtable_rows)
    if source_expected["SNOW_EC"]:
        if not any(row.parameter is None and row.field == "SNOW" for row in vtable_rows):
            fail("Vtable lacks the derived SNOW row")
        snow_count = expected.pop("SNOW_EC")
        expected["SNOW"] += snow_count
        replace_derived_units(expected_units, "SNOW_EC", "SNOW", vtable_rows)

    actual = actual_counter(records)
    additions = require_counter_at_least("single intermediate", actual, expected)
    validate_field_units("single intermediate", records, expected_units)

    mapped_rows = list(mappings)
    psfc = find_mapped_field(
        mapped_rows, description_fragment="Surface Pressure", level_type=1
    )
    pmsl = find_mapped_field(
        mapped_rows, description_fragment="Sea-level Pressure", level_type=1
    )
    skin = {
        row.field for row in mapped_rows
        if row.level_type == 1 and row.field == "SKINTEMP"
    }
    seaice = {
        row.field for row in mapped_rows
        if row.level_type == 1 and "Sea-Ice" in row.description
    }
    if skin != {"SKINTEMP"} or seaice != {"SEAICE"}:
        fail("cannot derive skin-temperature/sea-ice fields from matched Vtable rows")

    near_surface_rows = [
        row for row in mapped_rows
        if row.level_type == 1 and ("At 10 m" in row.description or "At  2 m" in row.description)
    ]
    near_surface_fields = {row.field for row in near_surface_rows}
    if near_surface_fields != {"UU", "VV", "TT"}:
        fail("matched Vtable does not yield U/V 10 m and T 2 m fields")

    soil_rows = [row for row in mapped_rows if row.level_type == 112]
    soil_temperature_fields = sorted({row.field for row in soil_rows if row.units == "K"})
    soil_moisture_fields = sorted({row.field for row in soil_rows if row.units == "fraction"})
    request_variables = request["request"]["variable"]
    requested_soil_t = sum(name.startswith("soil_temperature_level_") for name in request_variables)
    requested_soil_m = sum(
        name.startswith("volumetric_soil_water_layer_") for name in request_variables
    )
    if len(soil_temperature_fields) != requested_soil_t or requested_soil_t != 4:
        fail("Vtable/intermediate does not provide four requested soil temperatures")
    if len(soil_moisture_fields) != requested_soil_m or requested_soil_m != 4:
        fail("Vtable/intermediate does not provide four requested soil moistures")

    for field in {
        psfc, "SOILHGT", "UU", "VV", "TT", "RH", "SNOW", "SEAICE",
        "SKINTEMP", *soil_temperature_fields, *soil_moisture_fields,
    }:
        require_level(records, field, SURFACE_LEVEL)
    require_level(records, pmsl, SURFACE_LEVEL)

    roles: dict[str, Any] = {
        "surface_pressure": psfc,
        "mean_sea_level_pressure": pmsl,
        "terrain_height": "SOILHGT",
        "near_surface_u": "UU",
        "near_surface_v": "VV",
        "near_surface_temperature": "TT",
        "near_surface_relative_humidity": "RH",
        "snow_water_equivalent": "SNOW",
        "sea_ice": "SEAICE",
        "skin_temperature_sst_input": "SKINTEMP",
        "soil_temperature_fields": soil_temperature_fields,
        "soil_moisture_fields": soil_moisture_fields,
    }
    return expected, additions, roles


def normalized_records(records: list[dict[str, Any]]) -> list[dict[str, Any]]:
    ignored = {"index", "offset", "slab_offset"}
    return [
        {key: value for key, value in record.items() if key not in ignored}
        for record in records
    ]


def validate_log(path: Path, label: str) -> dict[str, Any]:
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError as exc:
        fail(f"cannot read {label} log: {exc}")
    success = "Successful completion of ungrib."
    if success not in text:
        fail(f"{label} log lacks explicit successful completion")
    return {
        "path": path.name,
        "size_bytes": path.stat().st_size,
        "sha256": sha256_file(path),
        "successful_completion": True,
    }


def field_inventory(records: list[dict[str, Any]]) -> list[dict[str, Any]]:
    grouped: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for record in records:
        grouped[record["field"]].append(record)
    inventory = []
    for field in sorted(grouped):
        field_records = grouped[field]
        inventory.append({
            "field": field,
            "count": len(field_records),
            "units": sorted({record["units"] for record in field_records}),
            "levels": sorted({record["xlvl"] for record in field_records}),
        })
    return inventory


def mapping_summary(
    label: str,
    messages: list[GribMessage],
    mappings: list[VtableRow],
) -> list[dict[str, Any]]:
    groups: dict[tuple[Any, ...], list[GribMessage]] = defaultdict(list)
    rows: dict[tuple[Any, ...], VtableRow] = {}
    for message, row in zip(messages, mappings):
        key = (
            message.parameter,
            message.level_type,
            row.level1,
            row.level2,
            row.field,
            row.units,
            row.description,
        )
        groups[key].append(message)
        rows[key] = row

    summaries = []
    for key in sorted(groups, key=lambda item: (item[0], item[1], item[4])):
        group = groups[key]
        row = rows[key]
        levels = sorted({
            message.level1 if message.level_type == 100
            else (message.level1, message.level2)
            for message in group
        }, key=repr)
        summary = {
            "source": label,
            "parameter": key[0],
            "level_type": key[1],
            "vtable_from": row.level1,
            "vtable_to": row.level2,
            "field": row.field,
            "units": row.units,
            "description": row.description,
            "message_count": len(group),
            "observed_levels": levels,
        }
        summaries.append(summary)
        print(
            "grib_vtable_mapping="
            f"source={label},parameter={summary['parameter']},"
            f"level_type={summary['level_type']},messages={summary['message_count']},"
            f"field={summary['field']},units={summary['units']},"
            f"levels={summary['observed_levels']}"
        )
    return summaries


def write_manifest_atomic(path: Path, manifest: dict[str, Any]) -> str:
    payload = (json.dumps(manifest, indent=2, sort_keys=True) + "\n").encode("utf-8")
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        if not path.is_file():
            fail(f"manifest destination is not a regular file: {path}")
        if path.read_bytes() == payload:
            return "unchanged"
        fail(f"refusing to overwrite divergent manifest: {path}")

    temporary_name: str | None = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="wb",
            prefix=f".{path.name}.",
            dir=path.parent,
            delete=False,
        ) as stream:
            temporary_name = stream.name
            stream.write(payload)
            stream.flush()
            os.fsync(stream.fileno())
        os.chmod(temporary_name, 0o644)
        try:
            os.link(temporary_name, path)
        except FileExistsError:
            if path.is_file() and path.read_bytes() == payload:
                return "unchanged"
            fail(f"manifest promotion collided with divergent content: {path}")
        return "promoted"
    finally:
        if temporary_name is not None:
            try:
                os.unlink(temporary_name)
            except FileNotFoundError:
                pass


def artifact_summary(path: Path, parsed: dict[str, Any]) -> dict[str, Any]:
    return {
        "path": path.name,
        "size_bytes": path.stat().st_size,
        "sha256": sha256_file(path),
        "record_count": parsed["record_count"],
        "fields": field_inventory(parsed["records"]),
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--parser", required=True, type=Path)
    parser.add_argument("--pressure-request", required=True, type=Path)
    parser.add_argument("--single-request", required=True, type=Path)
    parser.add_argument("--pressure-grib", required=True, type=Path)
    parser.add_argument("--single-grib", required=True, type=Path)
    parser.add_argument("--pressure-g1print", required=True, type=Path)
    parser.add_argument("--single-g1print", required=True, type=Path)
    parser.add_argument("--vtable", required=True, type=Path)
    parser.add_argument("--pressure-log", required=True, type=Path)
    parser.add_argument("--single-log", required=True, type=Path)
    parser.add_argument("--pressure-intermediate", required=True, type=Path)
    parser.add_argument("--single-intermediate", required=True, type=Path)
    parser.add_argument("--combined-intermediate", required=True, type=Path)
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--image", required=True)
    parser.add_argument("--image-id", required=True)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        pressure_request = load_json(args.pressure_request)
        single_request = load_json(args.single_request)

        pressure_raw_count, pressure_editions = validate_grib1_framing(
            args.pressure_grib
        )
        single_raw_count, single_editions = validate_grib1_framing(args.single_grib)
        pressure_messages = parse_g1print(args.pressure_g1print)
        single_messages = parse_g1print(args.single_g1print)
        validate_request_and_inventory(
            "pressure", pressure_request, pressure_messages, pressure_raw_count
        )
        validate_request_and_inventory(
            "single", single_request, single_messages, single_raw_count
        )

        vtable_rows = parse_vtable(args.vtable)
        pressure_mappings = map_messages("pressure", pressure_messages, vtable_rows)
        single_mappings = map_messages("single", single_messages, vtable_rows)
        pressure_mapping_summary = mapping_summary(
            "pressure", pressure_messages, pressure_mappings
        )
        single_mapping_summary = mapping_summary(
            "single", single_messages, single_mappings
        )

        pressure_parsed, single_parsed, combined_parsed = run_intermediate_parser(
            args.parser,
            [
                args.pressure_intermediate,
                args.single_intermediate,
                args.combined_intermediate,
            ],
        )
        pressure_records = pressure_parsed["records"]
        single_records = single_parsed["records"]
        combined_records = combined_parsed["records"]

        pressure_grid = validate_grid(pressure_records)
        single_grid = validate_grid(single_records)
        combined_grid = validate_grid(combined_records)
        if pressure_grid != single_grid or pressure_grid != combined_grid:
            fail("pressure, single, and combined files do not share one ERA5 grid")

        pressure_expected, pressure_additions, pressure_roles = \
            validate_pressure_headers(
                pressure_request,
                pressure_mappings,
                vtable_rows,
                pressure_records,
            )
        single_expected, single_additions, single_roles = validate_single_headers(
            single_request,
            single_mappings,
            vtable_rows,
            single_records,
        )

        expected_combined_records = normalized_records(pressure_records) + \
            normalized_records(single_records)
        if normalized_records(combined_records) != expected_combined_records:
            fail("combined headers are not pressure headers followed by single headers")
        if args.combined_intermediate.stat().st_size != (
            args.pressure_intermediate.stat().st_size
            + args.single_intermediate.stat().st_size
        ):
            fail("combined byte size is not the sum of both component files")
        if sha256_file(args.combined_intermediate) != sha256_concatenation([
            args.pressure_intermediate,
            args.single_intermediate,
        ]):
            fail("combined bytes are not the exact concatenation of both components")

        pressure_log = validate_log(args.pressure_log, "pressure")
        single_log = validate_log(args.single_log, "single")

        baseline = pressure_request["baseline_timestamp"]
        if single_request["baseline_timestamp"] != baseline:
            fail("pressure and single requests use different timestamps")
        manifest = {
            "schema_version": 1,
            "baseline_timestamp": baseline,
            "image": {
                "name": args.image,
                "id": args.image_id,
                "wps_version": "4.7.0",
                "g1print_build_command": "./compile g1print",
            },
            "vtable": {
                "selection": "/opt/wps/ungrib/Variable_Tables/Vtable.ECMWF",
                "policy": "upstream WPS 4.7.0 table used directly; no repository copy",
                "sha256": sha256_file(args.vtable),
            },
            "grib": {
                "pressure": {
                    "path": args.pressure_grib.name,
                    "size_bytes": args.pressure_grib.stat().st_size,
                    "sha256": sha256_file(args.pressure_grib),
                    "message_count": pressure_raw_count,
                    "editions": sorted(pressure_editions),
                    "mapping": pressure_mapping_summary,
                },
                "single": {
                    "path": args.single_grib.name,
                    "size_bytes": args.single_grib.stat().st_size,
                    "sha256": sha256_file(args.single_grib),
                    "message_count": single_raw_count,
                    "editions": sorted(single_editions),
                    "mapping": single_mapping_summary,
                },
            },
            "ungrib_logs": {
                "pressure": pressure_log,
                "single": single_log,
            },
            "grid": pressure_grid,
            "artifacts": {
                "pressure": artifact_summary(
                    args.pressure_intermediate, pressure_parsed
                ),
                "single": artifact_summary(args.single_intermediate, single_parsed),
                "combined": artifact_summary(
                    args.combined_intermediate, combined_parsed
                ),
            },
            "derived_fields": {
                "pressure": {
                    "expected_from_rrpr": {"HGT": pressure_expected["HGT"]},
                    "additional_observed": dict(pressure_additions),
                },
                "single": {
                    "expected_from_vtable_and_rrpr": {
                        "RH": 1,
                        "SOILHGT": 1,
                        "SNOW": 1,
                    },
                    "additional_observed": dict(single_additions),
                },
            },
            "functional_roles": {
                **pressure_roles,
                **single_roles,
            },
            "validation": {
                "grib_framing": "PASS",
                "g1print_inventory": "PASS",
                "grib_to_vtable_mapping": "PASS",
                "ungrib_success": "PASS",
                "wps_intermediate_v5_structure": "PASS",
                "combined_exact_concatenation": "PASS",
                "required_era5_fields": "PASS",
                "init_nc": "NOT_RUN",
            },
        }
        manifest_state = write_manifest_atomic(args.manifest, manifest)

        print(f"pressure_grib_messages={pressure_raw_count}")
        print(f"single_grib_messages={single_raw_count}")
        print(f"total_grib_messages={pressure_raw_count + single_raw_count}")
        print(f"pressure_intermediate_records={pressure_parsed['record_count']}")
        print(f"single_intermediate_records={single_parsed['record_count']}")
        print(f"combined_intermediate_records={combined_parsed['record_count']}")
        print(f"grid={EXPECTED_NX}x{EXPECTED_NY},iproj={EXPECTED_IPROJ},resolution=0.25deg")
        print(f"pressure_additional_fields={dict(pressure_additions)}")
        print(f"single_additional_fields={dict(single_additions)}")
        print(f"manifest={manifest_state}")
        print("wps_era5_validation=PASS")
        return 0
    except (OSError, ValidationError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
