#!/usr/bin/env python3
"""Analyze the canonical one-hour MPAS-Atmosphere integration.

The program is intentionally read-only with respect to the MPAS inputs. It
opens four explicit stream files, applies the criteria documented in
docs/validation/first-atmosphere-run.md, and writes only small documentation
artifacts to the requested output directory.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import os
from pathlib import Path
import sys
from typing import Any

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import netCDF4
import numpy as np
import xarray as xr


HISTORY_NAMES = (
    "history.2014-09-10_00.00.00.nc",
    "history.2014-09-10_01.00.00.nc",
)
DIAG_NAMES = (
    "diag.2014-09-10_00.00.00.nc",
    "diag.2014-09-10_01.00.00.nc",
)
EXPECTED_XTIMES = ("2014-09-10_00:00:00", "2014-09-10_01:00:00")
RUN_COMMIT = "66ffe7746b4ba144f179d4cea3011e1f0b178d38"
RUN_BASE_COMMIT = "0d499294e94661444243f9dbdadae0c776fa5c23"
MESH_NAME = "x1.10242 (approximately 240 km)"
P0 = 100_000.0
RD = 287.0
CP = 1004.5
WATER_SPECIES = ("qv", "qc", "qr", "qi", "qs", "qg")
FIGURES = (
    "t2m-t1.png",
    "delta-t2m.png",
    "mslp-t1.png",
    "wind10-t1.png",
    "precipitation-1h.png",
    "q2-negative-cells.png",
    "temperature-profile.png",
)


class ValidationError(RuntimeError):
    """Raised when a documented PASS/FAIL criterion fails."""


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--run-dir",
        type=Path,
        required=True,
        help="read-only directory containing the canonical run-001",
    )
    parser.add_argument(
        "--init-file",
        type=Path,
        required=True,
        help="read-only x1.10242.init.nc used by the run",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        required=True,
        help="dedicated writable directory for small analysis artifacts",
    )
    return parser.parse_args()


def ensure(condition: bool, message: str) -> None:
    if not condition:
        raise ValidationError(message)


def scalar(value: Any) -> Any:
    if isinstance(value, np.generic):
        return value.item()
    if isinstance(value, Path):
        return str(value)
    return value


def open_netcdf(path: Path) -> xr.Dataset:
    ensure(path.is_file(), f"required NetCDF is missing: {path}")
    return xr.open_dataset(
        path,
        engine="netcdf4",
        decode_cf=False,
        mask_and_scale=False,
        cache=False,
    )


def decode_xtime(ds: xr.Dataset) -> str:
    ensure("xtime" in ds.variables, "NetCDF has no xtime variable")
    raw = np.asarray(ds["xtime"].values)
    ensure(raw.shape[0] == 1, f"xtime must contain one record, got {raw.shape}")
    row = raw[0]
    if row.dtype.kind == "S":
        value = b"".join(np.ravel(row).tolist()).decode("ascii")
    elif row.dtype.kind == "U":
        value = "".join(np.ravel(row).tolist())
    else:
        value = str(row)
    return value.rstrip("\x00 ")


def require_variable(ds: xr.Dataset, name: str) -> xr.DataArray:
    ensure(name in ds.variables, f"required variable is missing: {name}")
    return ds[name]


def without_time(data: xr.DataArray) -> np.ndarray:
    values = np.asarray(data.values)
    if "Time" in data.dims:
        axis = data.dims.index("Time")
        ensure(values.shape[axis] == 1, f"{data.name}: expected one Time record")
        values = np.take(values, 0, axis=axis)
    return values


def units_of(data: xr.DataArray) -> str:
    value = data.attrs.get("units")
    ensure(value is not None and str(value).strip(), f"{data.name}: missing units")
    return str(value).strip()


def missing_markers(data: xr.DataArray) -> list[Any]:
    markers: list[Any] = []
    for key in ("_FillValue", "missing_value"):
        if key in data.attrs:
            markers.extend(np.asarray(data.attrs[key]).reshape(-1).tolist())
        elif key in data.encoding:
            encoded = data.encoding[key]
            if encoded is not None:
                markers.extend(np.asarray(encoded).reshape(-1).tolist())
    unique: list[Any] = []
    for marker in markers:
        if not any(
            (isinstance(marker, float) and isinstance(old, float) and math.isnan(marker) and math.isnan(old))
            or marker == old
            for old in unique
        ):
            unique.append(marker)
    return unique


def count_missing(values: np.ndarray, markers: list[Any]) -> int:
    count = 0
    for marker in markers:
        if isinstance(marker, float) and math.isnan(marker):
            count += int(np.count_nonzero(np.isnan(values)))
        else:
            count += int(np.count_nonzero(values == marker))
    return count


def array_statistics(values: np.ndarray, markers: list[Any] | None = None) -> dict[str, Any]:
    array = np.asarray(values)
    ensure(array.size > 0, "cannot summarize an empty array")
    ensure(array.dtype.kind in "iuf", f"non-numeric array passed to statistics: {array.dtype}")
    work = array.astype(np.float64, copy=False)
    finite = np.isfinite(work)
    percentiles = np.percentile(work[finite], [1, 5, 25, 50, 75, 95, 99])
    return {
        "count": int(work.size),
        "finite_count": int(np.count_nonzero(finite)),
        "nan_count": int(np.count_nonzero(np.isnan(work))),
        "inf_count": int(np.count_nonzero(np.isinf(work))),
        "missing_count": count_missing(array, markers or []),
        "negative_count": int(np.count_nonzero(work < 0.0)),
        "zero_count": int(np.count_nonzero(work == 0.0)),
        "min": float(np.min(work[finite])),
        "max": float(np.max(work[finite])),
        "mean": float(np.mean(work[finite], dtype=np.float64)),
        "std": float(np.std(work[finite], dtype=np.float64)),
        "percentiles": {
            key: float(value)
            for key, value in zip(("p01", "p05", "p25", "p50", "p75", "p95", "p99"), percentiles)
        },
    }


def audit_dataset(ds: xr.Dataset, filename: str) -> dict[str, Any]:
    total = 0
    finite = 0
    nan = 0
    inf = 0
    missing = 0
    numeric_variables: list[str] = []
    variables_with_markers: dict[str, int] = {}
    for name, data in ds.variables.items():
        if data.dtype.kind not in "iuf":
            continue
        values = np.asarray(data.values)
        markers = missing_markers(data)
        marker_count = count_missing(values, markers)
        numeric_variables.append(name)
        total += int(values.size)
        finite += int(np.count_nonzero(np.isfinite(values)))
        nan += int(np.count_nonzero(np.isnan(values))) if values.dtype.kind == "f" else 0
        inf += int(np.count_nonzero(np.isinf(values))) if values.dtype.kind == "f" else 0
        missing += marker_count
        if marker_count:
            variables_with_markers[name] = marker_count
    ensure(nan == 0 and inf == 0, f"{filename}: unexpected NaN/Inf")
    ensure(missing == 0, f"{filename}: fill/missing markers occur in numeric data")
    return {
        "filename": filename,
        "numeric_variable_count": len(numeric_variables),
        "numeric_value_count": total,
        "finite_count": finite,
        "nan_count": nan,
        "inf_count": inf,
        "missing_count": missing,
        "variables_with_missing_markers": variables_with_markers,
    }


def normalized_longitude_radians(values: np.ndarray) -> np.ndarray:
    return (np.asarray(values, dtype=np.float64) + np.pi) % (2.0 * np.pi) - np.pi


def cell_location(
    flat_cell_index: int,
    cell_ids: np.ndarray,
    lat: np.ndarray,
    lon: np.ndarray,
) -> dict[str, Any]:
    return {
        "cell_index_zero_based": int(flat_cell_index),
        "cell_id": int(cell_ids[flat_cell_index]),
        "latitude_degrees": float(np.degrees(lat[flat_cell_index])),
        "longitude_degrees": float(np.degrees(normalized_longitude_radians(lon[flat_cell_index]))),
    }


def extreme_location(
    values: np.ndarray,
    mode: str,
    dims: tuple[str, ...],
    history: xr.Dataset,
    cell_ids: np.ndarray,
    lat_cell: np.ndarray,
    lon_cell: np.ndarray,
) -> dict[str, Any]:
    work = np.asarray(values, dtype=np.float64)
    flat = int(np.argmin(work) if mode == "min" else np.argmax(work))
    index = tuple(int(i) for i in np.unravel_index(flat, work.shape))
    result: dict[str, Any] = {
        "value": float(work[index]),
        "indices_zero_based": {dim: index[pos] for pos, dim in enumerate(dims)},
    }
    if dims and dims[0] == "nCells":
        result.update(cell_location(index[0], cell_ids, lat_cell, lon_cell))
    elif dims and dims[0] == "nEdges":
        edge = index[0]
        result["edge_index_zero_based"] = edge
        if "indexToEdgeID" in history:
            result["edge_id"] = int(without_time(history["indexToEdgeID"])[edge])
        if "latEdge" in history and "lonEdge" in history:
            result["latitude_degrees"] = float(np.degrees(without_time(history["latEdge"])[edge]))
            result["longitude_degrees"] = float(
                np.degrees(normalized_longitude_radians(without_time(history["lonEdge"])[edge]))
            )
    return result


def add_field_pair(
    fields: dict[str, Any],
    key: str,
    variable: str,
    ds0: xr.Dataset,
    ds1: xr.Dataset,
    source_names: tuple[str, str],
    history_for_locations: xr.Dataset,
    cell_ids: np.ndarray,
    lat_cell: np.ndarray,
    lon_cell: np.ndarray,
) -> tuple[np.ndarray, np.ndarray]:
    data0 = require_variable(ds0, variable)
    data1 = require_variable(ds1, variable)
    ensure(data0.dims == data1.dims, f"{variable}: dimensions changed between t0 and t1")
    unit0 = units_of(data0)
    unit1 = units_of(data1)
    ensure(unit0 == unit1, f"{variable}: units changed between t0 and t1")
    values0 = without_time(data0)
    values1 = without_time(data1)
    ensure(values0.shape == values1.shape, f"{variable}: shape changed between t0 and t1")
    dims = tuple(dim for dim in data0.dims if dim != "Time")
    markers0 = missing_markers(data0)
    markers1 = missing_markers(data1)
    stats0 = array_statistics(values0, markers0)
    stats1 = array_statistics(values1, markers1)
    ensure(stats0["nan_count"] == 0 and stats0["inf_count"] == 0, f"{variable} t0 is non-finite")
    ensure(stats1["nan_count"] == 0 and stats1["inf_count"] == 0, f"{variable} t1 is non-finite")
    ensure(stats0["missing_count"] == 0 and stats1["missing_count"] == 0, f"{variable} contains fill values")
    change = values1.astype(np.float64) - values0.astype(np.float64)
    mean0 = stats0["mean"]
    fields[key] = {
        "variable": variable,
        "long_name": str(data0.attrs.get("long_name", "")),
        "units": unit0,
        "source_files": list(source_names),
        "dimensions": list(dims),
        "shape": list(values0.shape),
        "physical_limit_basis": "finiteness only; no narrower supported bound defined for this field",
        "physical_limit_violations": {"nonfinite_t0": 0, "nonfinite_t1": 0},
        "t0": stats0,
        "t1": stats1,
        "change_t1_minus_t0": array_statistics(change),
        "relative_change_of_mean": None if mean0 == 0.0 else float((stats1["mean"] - mean0) / abs(mean0)),
        "arrays_identical": bool(np.array_equal(values0, values1)),
        "t1_extrema": {
            "min": extreme_location(values1, "min", dims, history_for_locations, cell_ids, lat_cell, lon_cell),
            "max": extreme_location(values1, "max", dims, history_for_locations, cell_ids, lat_cell, lon_cell),
        },
    }
    return values0, values1


def add_derived_field(
    fields: dict[str, Any],
    key: str,
    long_name: str,
    units: str,
    values0: np.ndarray,
    values1: np.ndarray,
    dimensions: tuple[str, ...],
    method: str,
    history: xr.Dataset,
    cell_ids: np.ndarray,
    lat_cell: np.ndarray,
    lon_cell: np.ndarray,
) -> None:
    stats0 = array_statistics(values0)
    stats1 = array_statistics(values1)
    change = values1.astype(np.float64) - values0.astype(np.float64)
    fields[key] = {
        "variable": None,
        "long_name": long_name,
        "units": units,
        "source_files": list(HISTORY_NAMES),
        "dimensions": list(dimensions),
        "shape": list(values0.shape),
        "physical_limit_basis": "finiteness only; no narrower supported bound defined for this derived field",
        "physical_limit_violations": {"nonfinite_t0": 0, "nonfinite_t1": 0},
        "method": method,
        "t0": stats0,
        "t1": stats1,
        "change_t1_minus_t0": array_statistics(change),
        "relative_change_of_mean": None
        if stats0["mean"] == 0.0
        else float((stats1["mean"] - stats0["mean"]) / abs(stats0["mean"])),
        "arrays_identical": bool(np.array_equal(values0, values1)),
        "t1_extrema": {
            "min": extreme_location(values1, "min", dimensions, history, cell_ids, lat_cell, lon_cell),
            "max": extreme_location(values1, "max", dimensions, history, cell_ids, lat_cell, lon_cell),
        },
    }


def little_endian_sha256(values: np.ndarray) -> str:
    array = np.asarray(values)
    little = np.ascontiguousarray(array.astype(array.dtype.newbyteorder("<"), copy=False))
    return hashlib.sha256(little.tobytes(order="C")).hexdigest()


def save_figure(fig: plt.Figure, output_dir: Path, filename: str) -> None:
    temporary = output_dir / f".{filename}.tmp"
    final = output_dir / filename
    fig.savefig(
        temporary,
        format="png",
        dpi=150,
        metadata={"Software": "MPAS-ERA5 cycle 0014"},
    )
    plt.close(fig)
    os.replace(temporary, final)


def mollweide_field(
    values: np.ndarray,
    lat: np.ndarray,
    lon: np.ndarray,
    output_dir: Path,
    filename: str,
    title: str,
    units: str,
    timestamp: str,
    cmap: str,
    note: str,
    symmetric: bool = False,
) -> None:
    work = np.asarray(values, dtype=np.float64)
    vmin = None
    vmax = None
    if symmetric:
        magnitude = float(np.max(np.abs(work)))
        vmin, vmax = -magnitude, magnitude
    fig = plt.figure(figsize=(10.5, 5.8), constrained_layout=False)
    axis = fig.add_subplot(111, projection="mollweide")
    points = axis.scatter(
        normalized_longitude_radians(lon),
        lat,
        c=work,
        cmap=cmap,
        s=7.0,
        linewidths=0,
        vmin=vmin,
        vmax=vmax,
    )
    axis.grid(True, linewidth=0.35, alpha=0.6)
    axis.set_title(f"{title}\n{timestamp} | {MESH_NAME}", fontsize=11)
    colorbar = fig.colorbar(points, ax=axis, orientation="horizontal", pad=0.08, fraction=0.055)
    colorbar.set_label(units)
    fig.text(0.5, 0.025, note, ha="center", va="bottom", fontsize=8)
    fig.subplots_adjust(left=0.04, right=0.96, top=0.90, bottom=0.14)
    save_figure(fig, output_dir, filename)


def plot_q2_locations(
    q2: np.ndarray,
    lat: np.ndarray,
    lon: np.ndarray,
    output_dir: Path,
    timestamp: str,
) -> None:
    negative = q2 < 0.0
    fig = plt.figure(figsize=(10.5, 5.8), constrained_layout=False)
    axis = fig.add_subplot(111, projection="mollweide")
    axis.scatter(normalized_longitude_radians(lon), lat, s=3.0, c="#c7c7c7", linewidths=0, label="demais células")
    axis.scatter(
        normalized_longitude_radians(lon[negative]),
        lat[negative],
        s=42,
        c="#d62728",
        marker="x",
        linewidths=1.3,
        label=f"q2 < 0 ({int(np.count_nonzero(negative))} células)",
    )
    axis.grid(True, linewidth=0.35, alpha=0.6)
    axis.legend(loc="lower center", bbox_to_anchor=(0.5, -0.19), ncol=2, frameon=False)
    axis.set_title(f"Localização dos diagnósticos q2 negativos\n{timestamp} | {MESH_NAME}", fontsize=11)
    fig.text(
        0.5,
        0.025,
        "q2 é diagnóstico da surface layer; os outputs não contêm qsfc, psiq e psiq2 para reconstrução célula a célula.",
        ha="center",
        va="bottom",
        fontsize=8,
    )
    fig.subplots_adjust(left=0.04, right=0.96, top=0.90, bottom=0.16)
    save_figure(fig, output_dir, "q2-negative-cells.png")


def plot_temperature_profile(
    temperature0: np.ndarray,
    temperature1: np.ndarray,
    zgrid: np.ndarray,
    dry_mass0: np.ndarray,
    dry_mass1: np.ndarray,
    area: np.ndarray,
    output_dir: Path,
) -> None:
    height_agl = 0.5 * (zgrid[:, 1:] + zgrid[:, :-1]) - zgrid[:, [0]]
    mean_height_km = np.average(height_agl, axis=0, weights=area) / 1000.0
    mean0 = np.sum(temperature0 * dry_mass0, axis=0) / np.sum(dry_mass0, axis=0)
    mean1 = np.sum(temperature1 * dry_mass1, axis=0) / np.sum(dry_mass1, axis=0)
    p05 = np.percentile(temperature1, 5, axis=0)
    p95 = np.percentile(temperature1, 95, axis=0)
    fig, axis = plt.subplots(figsize=(6.6, 8.0))
    axis.fill_betweenx(mean_height_km, p05, p95, color="#9ecae1", alpha=0.45, label="t1: percentis 5–95")
    axis.plot(mean0, mean_height_km, color="#7f7f7f", linewidth=1.6, label="t0: média ponderada por massa seca")
    axis.plot(mean1, mean_height_km, color="#1f77b4", linewidth=1.8, label="t1: média ponderada por massa seca")
    axis.set_xlabel("Temperatura derivada (K)")
    axis.set_ylabel("Altura média do centro da camada AGL (km)")
    axis.set_title("Perfil vertical global de temperatura derivada\n2014-09-10 00–01 UTC | x1.10242, 55 níveis")
    axis.grid(True, linewidth=0.4, alpha=0.5)
    axis.legend(loc="best", fontsize=8)
    fig.text(
        0.5,
        0.012,
        "T = theta × (pressure / 100000 Pa)^(287/1004.5); faixa espacial não ponderada em t1.",
        ha="center",
        fontsize=8,
    )
    fig.tight_layout(rect=(0, 0.035, 1, 1))
    save_figure(fig, output_dir, "temperature-profile.png")


def write_json_atomic(path: Path, payload: dict[str, Any]) -> None:
    temporary = path.with_name(f".{path.name}.tmp")
    with temporary.open("w", encoding="utf-8", newline="\n") as stream:
        json.dump(payload, stream, ensure_ascii=False, allow_nan=False, indent=2, sort_keys=True, default=scalar)
        stream.write("\n")
    os.replace(temporary, path)


def write_q2_csv(path: Path, rows: list[dict[str, Any]], columns: list[str]) -> None:
    temporary = path.with_name(f".{path.name}.tmp")
    with temporary.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=columns, extrasaction="ignore", lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    os.replace(temporary, path)


def main() -> int:
    args = parse_args()
    run_dir = args.run_dir.resolve()
    init_file = args.init_file.resolve()
    output_dir = args.output_dir.resolve()
    ensure(run_dir.is_dir(), f"run directory does not exist: {run_dir}")
    ensure(init_file.is_file(), f"init file does not exist: {init_file}")
    ensure(output_dir.is_dir(), f"output directory does not exist: {output_dir}")

    input_paths = [run_dir / name for name in (*HISTORY_NAMES, *DIAG_NAMES)]
    history0, history1, diag0, diag1 = [open_netcdf(path) for path in input_paths]
    init = open_netcdf(init_file)
    datasets = (history0, history1, diag0, diag1, init)
    criteria: list[dict[str, Any]] = []

    def criterion(identifier: str, condition: bool, evidence: Any) -> None:
        criteria.append(
            {
                "id": identifier,
                "class": "PASS_FAIL",
                "result": "PASS" if condition else "FAIL",
                "evidence": evidence,
            }
        )
        ensure(condition, f"criterion failed: {identifier}: {evidence}")

    try:
        manifest_path = run_dir / "manifest.json"
        ensure(manifest_path.is_file(), f"manifest is missing: {manifest_path}")
        with manifest_path.open("r", encoding="utf-8") as stream:
            manifest = json.load(stream)

        timestamps = {
            HISTORY_NAMES[0]: decode_xtime(history0),
            HISTORY_NAMES[1]: decode_xtime(history1),
            DIAG_NAMES[0]: decode_xtime(diag0),
            DIAG_NAMES[1]: decode_xtime(diag1),
            init_file.name: decode_xtime(init),
        }
        criterion(
            "timestamps",
            timestamps[HISTORY_NAMES[0]] == EXPECTED_XTIMES[0]
            and timestamps[DIAG_NAMES[0]] == EXPECTED_XTIMES[0]
            and timestamps[HISTORY_NAMES[1]] == EXPECTED_XTIMES[1]
            and timestamps[DIAG_NAMES[1]] == EXPECTED_XTIMES[1]
            and timestamps[init_file.name] == EXPECTED_XTIMES[0],
            timestamps,
        )

        dimension_evidence = {
            "history_t0": {key: int(value) for key, value in history0.sizes.items()},
            "history_t1": {key: int(value) for key, value in history1.sizes.items()},
            "diag_t0": {key: int(value) for key, value in diag0.sizes.items()},
            "diag_t1": {key: int(value) for key, value in diag1.sizes.items()},
        }
        criterion(
            "dimensions",
            history0.sizes.get("nCells") == 10_242
            and history1.sizes.get("nCells") == 10_242
            and diag0.sizes.get("nCells") == 10_242
            and diag1.sizes.get("nCells") == 10_242
            and history0.sizes.get("nVertLevels") == 55
            and history1.sizes.get("nVertLevels") == 55
            and history0.sizes.get("nVertLevelsP1") == 56
            and history1.sizes.get("nVertLevelsP1") == 56,
            dimension_evidence,
        )

        audits = [
            audit_dataset(dataset, path.name)
            for dataset, path in zip((history0, history1, diag0, diag1), input_paths)
        ]
        criterion(
            "global_finitude_and_missing",
            all(item["nan_count"] == 0 and item["inf_count"] == 0 and item["missing_count"] == 0 for item in audits),
            {
                "numeric_value_count": sum(item["numeric_value_count"] for item in audits),
                "nan_count": sum(item["nan_count"] for item in audits),
                "inf_count": sum(item["inf_count"] for item in audits),
                "missing_count": sum(item["missing_count"] for item in audits),
            },
        )

        cell_ids = without_time(require_variable(history0, "indexToCellID")).astype(np.int64)
        lat_cell = without_time(require_variable(history0, "latCell")).astype(np.float64)
        lon_cell = without_time(require_variable(history0, "lonCell")).astype(np.float64)
        area = without_time(require_variable(history0, "areaCell")).astype(np.float64)
        criterion("positive_cell_area", bool(np.all(area > 0.0)), {"min_m2": float(np.min(area))})

        fields: dict[str, Any] = {}
        rho0, rho1 = add_field_pair(fields, "rho", "rho", history0, history1, HISTORY_NAMES, history0, cell_ids, lat_cell, lon_cell)
        pressure0, pressure1 = add_field_pair(
            fields, "pressure", "pressure", history0, history1, HISTORY_NAMES, history0, cell_ids, lat_cell, lon_cell
        )
        theta0, theta1 = add_field_pair(
            fields, "theta", "theta", history0, history1, HISTORY_NAMES, history0, cell_ids, lat_cell, lon_cell
        )
        u0, u1 = add_field_pair(fields, "u", "u", history0, history1, HISTORY_NAMES, history0, cell_ids, lat_cell, lon_cell)
        w0, w1 = add_field_pair(fields, "w", "w", history0, history1, HISTORY_NAMES, history0, cell_ids, lat_cell, lon_cell)

        q_arrays: dict[str, tuple[np.ndarray, np.ndarray]] = {}
        for species in WATER_SPECIES:
            q_arrays[species] = add_field_pair(
                fields, species, species, history0, history1, HISTORY_NAMES, history0, cell_ids, lat_cell, lon_cell
            )

        surface_pressure0, surface_pressure1 = add_field_pair(
            fields,
            "surface_pressure",
            "surface_pressure",
            history0,
            history1,
            HISTORY_NAMES,
            history0,
            cell_ids,
            lat_cell,
            lon_cell,
        )

        surface_arrays: dict[str, tuple[np.ndarray, np.ndarray]] = {}
        surface_sources: dict[str, tuple[xr.Dataset, xr.Dataset, tuple[str, str]]] = {}
        for variable in ("skintemp", "sst", "t2m", "q2", "u10", "v10", "rainc", "rainnc", "precipw", "xice", "snow", "snowh", "acsnow"):
            if variable in diag0.variables and variable in diag1.variables:
                source0, source1, source_names = diag0, diag1, DIAG_NAMES
            elif variable in history0.variables and variable in history1.variables:
                source0, source1, source_names = history0, history1, HISTORY_NAMES
            else:
                continue
            surface_sources[variable] = (source0, source1, source_names)
            surface_arrays[variable] = add_field_pair(
                fields,
                variable,
                variable,
                source0,
                source1,
                source_names,
                history0,
                cell_ids,
                lat_cell,
                lon_cell,
            )
        ensure(
            all(name in surface_arrays for name in ("skintemp", "sst", "t2m", "q2", "u10", "v10", "rainc", "rainnc")),
            "one or more required surface fields are absent from both history and diagnostics",
        )

        ensure("mslp" in diag0.variables and "mslp" in diag1.variables, "mslp is required for the pressure map")
        mslp0, mslp1 = add_field_pair(
            fields, "mslp", "mslp", diag0, diag1, DIAG_NAMES, history0, cell_ids, lat_cell, lon_cell
        )

        temperature0 = theta0.astype(np.float64) * np.power(pressure0.astype(np.float64) / P0, RD / CP)
        temperature1 = theta1.astype(np.float64) * np.power(pressure1.astype(np.float64) / P0, RD / CP)
        add_derived_field(
            fields,
            "temperature_derived",
            "temperature derived from MPAS theta and pressure",
            "K",
            temperature0,
            temperature1,
            ("nCells", "nVertLevels"),
            "T = theta * (pressure / 100000 Pa) ** (287.0 / 1004.5)",
            history0,
            cell_ids,
            lat_cell,
            lon_cell,
        )

        wind10_0 = np.hypot(surface_arrays["u10"][0], surface_arrays["v10"][0])
        wind10_1 = np.hypot(surface_arrays["u10"][1], surface_arrays["v10"][1])
        add_derived_field(
            fields,
            "wind_speed_10m",
            "10 m wind speed",
            units_of(surface_sources["u10"][0]["u10"]),
            wind10_0,
            wind10_1,
            ("nCells",),
            "sqrt(u10**2 + v10**2)",
            history0,
            cell_ids,
            lat_cell,
            lon_cell,
        )

        zgrid0 = without_time(require_variable(history0, "zgrid")).astype(np.float64)
        zgrid1 = without_time(require_variable(history1, "zgrid")).astype(np.float64)
        dz0 = np.diff(zgrid0, axis=1)
        dz1 = np.diff(zgrid1, axis=1)
        criterion(
            "positive_layer_thickness",
            bool(np.all(dz0 > 0.0) and np.all(dz1 > 0.0)),
            {"t0_min_m": float(np.min(dz0)), "t1_min_m": float(np.min(dz1))},
        )
        criterion(
            "positive_density_pressure_temperature",
            bool(
                np.all(rho0 > 0.0)
                and np.all(rho1 > 0.0)
                and np.all(pressure0 > 0.0)
                and np.all(pressure1 > 0.0)
                and np.all(surface_pressure0 > 0.0)
                and np.all(surface_pressure1 > 0.0)
                and np.all(mslp0 > 0.0)
                and np.all(mslp1 > 0.0)
                and np.all(temperature0 > 0.0)
                and np.all(temperature1 > 0.0)
            ),
            {
                "rho_min_t0_t1": [float(np.min(rho0)), float(np.min(rho1))],
                "pressure_min_t0_t1_Pa": [float(np.min(pressure0)), float(np.min(pressure1))],
                "temperature_min_t0_t1_K": [float(np.min(temperature0)), float(np.min(temperature1))],
            },
        )
        criterion(
            "prognostic_state_evolved",
            not np.array_equal(rho0, rho1) and not np.array_equal(theta0, theta1) and not np.array_equal(u0, u1),
            {
                "rho_identical": bool(np.array_equal(rho0, rho1)),
                "theta_identical": bool(np.array_equal(theta0, theta1)),
                "u_identical": bool(np.array_equal(u0, u1)),
            },
        )
        criterion(
            "nonnegative_wsm6_species_at_t1",
            all(np.all(q_arrays[name][1] >= 0.0) for name in WATER_SPECIES),
            {name: int(np.count_nonzero(q_arrays[name][1] < 0.0)) for name in WATER_SPECIES},
        )

        sst0, sst1 = surface_arrays["sst"]
        sst_hash0 = little_endian_sha256(sst0)
        sst_hash1 = little_endian_sha256(sst1)
        criterion(
            "fixed_sst",
            bool(np.array_equal(sst0, sst1) and sst_hash0 == sst_hash1 and manifest.get("sst_update") is False),
            {
                "config_sst_update": manifest.get("sst_update"),
                "array_equal": bool(np.array_equal(sst0, sst1)),
                "sha256_t0": sst_hash0,
                "sha256_t1": sst_hash1,
            },
        )

        if "xice" in surface_arrays:
            xice0, xice1 = surface_arrays["xice"]
            criterion(
                "sea_ice_fraction_range",
                bool(np.all((xice0 >= 0.0) & (xice0 <= 1.0)) and np.all((xice1 >= 0.0) & (xice1 <= 1.0))),
                {"t0_min_max": [float(np.min(xice0)), float(np.max(xice0))], "t1_min_max": [float(np.min(xice1)), float(np.max(xice1))]},
            )
        snow_evidence: dict[str, Any] = {}
        snow_ok = True
        for name in ("snow", "snowh", "acsnow"):
            if name in surface_arrays:
                snow_evidence[name] = {
                    "negative_t0": int(np.count_nonzero(surface_arrays[name][0] < 0.0)),
                    "negative_t1": int(np.count_nonzero(surface_arrays[name][1] < 0.0)),
                }
                snow_ok = snow_ok and bool(np.all(surface_arrays[name][0] >= 0.0) and np.all(surface_arrays[name][1] >= 0.0))
        criterion("nonnegative_snow_fields", snow_ok, snow_evidence)

        bucket_metadata = manifest.get("bucket_update_mm", history0.attrs.get("config_bucket_update"))
        if bucket_metadata is None or str(bucket_metadata).strip().lower() == "none":
            bucket = 0.0
        else:
            bucket = float(bucket_metadata)
        rainc0, rainc1 = surface_arrays["rainc"]
        rainnc0, rainnc1 = surface_arrays["rainnc"]
        counter0 = diag0 if "i_rainc" in diag0 and "i_rainnc" in diag0 else history0
        counter1 = diag1 if "i_rainc" in diag1 and "i_rainnc" in diag1 else history1
        i_rainc0 = without_time(counter0["i_rainc"]).astype(np.float64) if "i_rainc" in counter0 else np.zeros_like(rainc0)
        i_rainc1 = without_time(counter1["i_rainc"]).astype(np.float64) if "i_rainc" in counter1 else np.zeros_like(rainc1)
        i_rainnc0 = without_time(counter0["i_rainnc"]).astype(np.float64) if "i_rainnc" in counter0 else np.zeros_like(rainnc0)
        i_rainnc1 = without_time(counter1["i_rainnc"]).astype(np.float64) if "i_rainnc" in counter1 else np.zeros_like(rainnc1)
        accumulated0 = rainc0 + bucket * i_rainc0 + rainnc0 + bucket * i_rainnc0
        accumulated1 = rainc1 + bucket * i_rainc1 + rainnc1 + bucket * i_rainnc1
        precipitation_1h = accumulated1 - accumulated0
        criterion(
            "nonnegative_monotonic_precipitation",
            bool(
                np.all(np.isfinite(accumulated0))
                and np.all(np.isfinite(accumulated1))
                and np.all(accumulated0 >= 0.0)
                and np.all(accumulated1 >= 0.0)
                and np.all(precipitation_1h >= 0.0)
            ),
            {
                "bucket_mm": bucket,
                "negative_accumulated_t0": int(np.count_nonzero(accumulated0 < 0.0)),
                "negative_accumulated_t1": int(np.count_nonzero(accumulated1 < 0.0)),
                "decreased_cells": int(np.count_nonzero(precipitation_1h < 0.0)),
            },
        )
        precip_positive = precipitation_1h > 0.0
        precipitation = {
            "units": "mm (equivalent to kg m-2)",
            "method": "(rainc + bucket*i_rainc + rainnc + bucket*i_rainnc)t1 minus t0",
            "bucket_mm": bucket,
            "one_hour": array_statistics(precipitation_1h),
            "positive_cell_count": int(np.count_nonzero(precip_positive)),
            "positive_cell_fraction": float(np.count_nonzero(precip_positive) / precipitation_1h.size),
            "global_area_integral_kg": float(np.sum(precipitation_1h.astype(np.float64) * area, dtype=np.float64)),
            "maximum_location": cell_location(int(np.argmax(precipitation_1h)), cell_ids, lat_cell, lon_cell),
        }
        precipitation["maximum_location"]["value_mm"] = float(np.max(precipitation_1h))

        volume0 = area[:, None] * dz0
        volume1 = area[:, None] * dz1
        dry_layer_mass0 = rho0.astype(np.float64) * volume0
        dry_layer_mass1 = rho1.astype(np.float64) * volume1
        dry_mass0 = float(np.sum(dry_layer_mass0, dtype=np.float64))
        dry_mass1 = float(np.sum(dry_layer_mass1, dtype=np.float64))
        dry_delta = dry_mass1 - dry_mass0
        dry_air_mass = {
            "classification": "REPORT_ONLY",
            "name": "dry-air mass conservation diagnostic",
            "units": "kg",
            "method": "sum(rho * areaCell * diff(zgrid))",
            "source_basis": "rho is dry-air density; zgrid interfaces and areaCell define geometric volume",
            "t0": dry_mass0,
            "t1": dry_mass1,
            "absolute_delta": dry_delta,
            "relative_delta": dry_delta / dry_mass0,
            "threshold": None,
            "zgrid_arrays_identical": bool(np.array_equal(zgrid0, zgrid1)),
        }
        criteria.append(
            {
                "id": "dry_air_mass_change",
                "class": "REPORT_ONLY",
                "result": "REPORTED",
                "evidence": {"relative_delta": dry_air_mass["relative_delta"], "threshold": None},
            }
        )

        species_inventory: dict[str, Any] = {}
        atmospheric_water0 = 0.0
        atmospheric_water1 = 0.0
        for species in WATER_SPECIES:
            species0 = float(np.sum(dry_layer_mass0 * q_arrays[species][0].astype(np.float64), dtype=np.float64))
            species1 = float(np.sum(dry_layer_mass1 * q_arrays[species][1].astype(np.float64), dtype=np.float64))
            atmospheric_water0 += species0
            atmospheric_water1 += species1
            species_inventory[species] = {
                "units": "kg",
                "t0": species0,
                "t1": species1,
                "absolute_delta": species1 - species0,
                "relative_delta": None if species0 == 0.0 else (species1 - species0) / abs(species0),
            }
        precipitation_mass0 = float(np.sum(accumulated0.astype(np.float64) * area, dtype=np.float64))
        precipitation_mass1 = float(np.sum(accumulated1.astype(np.float64) * area, dtype=np.float64))
        water_inventory = {
            "classification": "REPORT_ONLY_INCOMPLETE_INVENTORY",
            "units": "kg",
            "method": "sum(rho_dry * cell_volume * q_species), with accumulated precipitation integrated separately",
            "species": species_inventory,
            "atmospheric_species_total": {
                "t0": atmospheric_water0,
                "t1": atmospheric_water1,
                "absolute_delta": atmospheric_water1 - atmospheric_water0,
            },
            "accumulated_precipitation": {
                "t0": precipitation_mass0,
                "t1": precipitation_mass1,
                "one_hour_delta": precipitation_mass1 - precipitation_mass0,
            },
            "observable_atmosphere_plus_accumulated_precipitation": {
                "t0": atmospheric_water0 + precipitation_mass0,
                "t1": atmospheric_water1 + precipitation_mass1,
                "absolute_delta": (atmospheric_water1 + precipitation_mass1) - (atmospheric_water0 + precipitation_mass0),
            },
            "budget_closed": False,
            "missing_for_closure": [
                "time-integrated surface and soil moisture fluxes",
                "all boundary/source/sink terms used by the physics and dynamics",
            ],
        }
        criteria.append(
            {
                "id": "water_inventory_change",
                "class": "REPORT_ONLY",
                "result": "REPORTED",
                "evidence": {"budget_closed": False},
            }
        )

        init_qv = without_time(require_variable(init, "qv"))
        qv0 = q_arrays["qv"][0]
        qv1 = q_arrays["qv"][1]
        qv_diagnostic = {
            "init": array_statistics(init_qv, missing_markers(init["qv"])),
            "history_t0": fields["qv"]["t0"],
            "history_t1": fields["qv"]["t1"],
            "init_equals_history_t0": bool(np.array_equal(init_qv, qv0)),
            "negative_cell_level_pairs": {
                "init": int(np.count_nonzero(init_qv < 0.0)),
                "history_t0": int(np.count_nonzero(qv0 < 0.0)),
                "history_t1": int(np.count_nonzero(qv1 < 0.0)),
            },
            "causal_attribution": "NOT_ESTABLISHED: outputs do not isolate tendencies from advection and individual parameterizations",
        }

        q2 = surface_arrays["q2"][1].astype(np.float64)
        negative_indices = np.flatnonzero(q2 < 0.0)
        xland_source = diag1 if "xland" in diag1.variables else history1
        xland = without_time(require_variable(xland_source, "xland")).astype(np.float64)
        q2_columns = [
            "cell_index_zero_based",
            "cell_id",
            "latitude_degrees",
            "longitude_degrees",
            "land_sea_classification",
            "xland",
            "q2_kg_kg-1",
            "t2m_K",
            "skintemp_K",
            "sst_K",
            "sst_applicable",
            "qv_level1_kg_kg-1",
            "pressure_level1_Pa",
            "temperature_level1_K",
            "height_level1_agl_m",
            "surface_pressure_Pa",
            "u10_m_s-1",
            "v10_m_s-1",
            "wind_speed_10m_m_s-1",
            "xice_fraction",
            "snow",
            "snowh",
            "hfx",
            "qfx",
            "lh",
            "ust",
            "pblh",
        ]
        q2_rows: list[dict[str, Any]] = []
        for index_value in negative_indices:
            index = int(index_value)
            row: dict[str, Any] = cell_location(index, cell_ids, lat_cell, lon_cell)
            is_land = bool(xland[index] == 1.0)
            row.update(
                {
                    "land_sea_classification": "land_or_sea_ice" if is_land else "open_ocean",
                    "xland": float(xland[index]),
                    "q2_kg_kg-1": float(q2[index]),
                    "t2m_K": float(surface_arrays["t2m"][1][index]),
                    "skintemp_K": float(surface_arrays["skintemp"][1][index]),
                    "sst_K": float(sst1[index]),
                    "sst_applicable": not is_land,
                    "qv_level1_kg_kg-1": float(qv1[index, 0]),
                    "pressure_level1_Pa": float(pressure1[index, 0]),
                    "temperature_level1_K": float(temperature1[index, 0]),
                    "height_level1_agl_m": float(0.5 * (zgrid1[index, 1] - zgrid1[index, 0])),
                    "surface_pressure_Pa": float(surface_pressure1[index]),
                    "u10_m_s-1": float(surface_arrays["u10"][1][index]),
                    "v10_m_s-1": float(surface_arrays["v10"][1][index]),
                    "wind_speed_10m_m_s-1": float(wind10_1[index]),
                    "xice_fraction": float(surface_arrays["xice"][1][index]) if "xice" in surface_arrays else None,
                    "snow": float(surface_arrays["snow"][1][index]) if "snow" in surface_arrays else None,
                    "snowh": float(surface_arrays["snowh"][1][index]) if "snowh" in surface_arrays else None,
                }
            )
            for optional in ("hfx", "qfx", "lh", "ust", "pblh"):
                source = diag1 if optional in diag1.variables else history1
                if optional in source.variables:
                    row[optional] = float(without_time(source[optional])[index])
                else:
                    row[optional] = None
            q2_rows.append(row)

        negative_values = q2[negative_indices]
        q2_diagnostic = {
            "classification": "LIMITED_NUMERICAL_BEHAVIOR_DOCUMENTED",
            "criterion_class": "REPORT_ONLY",
            "count": int(negative_indices.size),
            "fraction_of_10242_cells": float(negative_indices.size / 10_242),
            "minimum_kg_kg-1": float(np.min(negative_values)) if negative_values.size else None,
            "maximum_among_negative_kg_kg-1": float(np.max(negative_values)) if negative_values.size else None,
            "mean_among_negative_kg_kg-1": float(np.mean(negative_values)) if negative_values.size else None,
            "source_formula": "q2 = qsfc + (qv_level1 - qsfc) * (psiq2 / psiq)",
            "source_clamp_after_formula": False,
            "call_path": [
                "mpas_atmphys_driver.F",
                "driver_sfclayer",
                "sfclayer_to_MPAS",
                "module_sf_sfclayrev.F",
                "sf_sfclayrev_pre_run",
                "physics_mmm/sf_sfclayrev.F90",
            ],
            "internal_terms_available_in_output": {"qsfc": False, "psiq": False, "psiq2": False},
            "exact_cellwise_reconstruction_possible": False,
            "interpretation": (
                "The revised surface-layer interpolation is not clamped. Its stability-function ratio is not constrained "
                "by this assignment to the [0,1] interval, so extrapolation can cross zero even while first-level qv "
                "remains positive. The missing internal terms prevent an exact cellwise reconstruction from these outputs."
            ),
            "rows_file": "q2-negative-cells.csv",
        }
        criteria.append(
            {
                "id": "q2_negative_values",
                "class": "REPORT_ONLY",
                "result": "REPORTED",
                "evidence": {"count": q2_diagnostic["count"], "minimum": q2_diagnostic["minimum_kg_kg-1"]},
            }
        )

        mollweide_field(
            surface_arrays["t2m"][1],
            lat_cell,
            lon_cell,
            output_dir,
            "t2m-t1.png",
            "Temperatura a 2 m",
            units_of(surface_sources["t2m"][1]["t2m"]),
            "2014-09-10 01:00 UTC",
            "coolwarm",
            "Diagnóstico da camada superficial no fim da integração de 1 h.",
        )
        mollweide_field(
            surface_arrays["t2m"][1] - surface_arrays["t2m"][0],
            lat_cell,
            lon_cell,
            output_dir,
            "delta-t2m.png",
            "Mudança da temperatura a 2 m (t1 − t0)",
            units_of(surface_sources["t2m"][1]["t2m"]),
            "2014-09-10 00–01 UTC",
            "RdBu_r",
            "Diferença direta na mesma mesh; não é erro contra observação ou ERA5 futuro.",
            symmetric=True,
        )
        mollweide_field(
            mslp1 / 100.0,
            lat_cell,
            lon_cell,
            output_dir,
            "mslp-t1.png",
            "Pressão ao nível médio do mar",
            "hPa (convertido de Pa)",
            "2014-09-10 01:00 UTC",
            "viridis",
            "Campo mslp do stream diagnostics; conversão visual: 1 hPa = 100 Pa.",
        )
        mollweide_field(
            wind10_1,
            lat_cell,
            lon_cell,
            output_dir,
            "wind10-t1.png",
            "Velocidade do vento a 10 m",
            units_of(surface_sources["u10"][1]["u10"]),
            "2014-09-10 01:00 UTC",
            "magma",
            "Magnitude derivada como sqrt(u10² + v10²).",
        )
        mollweide_field(
            precipitation_1h,
            lat_cell,
            lon_cell,
            output_dir,
            "precipitation-1h.png",
            "Precipitação acumulada em 1 hora",
            "mm",
            "2014-09-10 00–01 UTC",
            "Blues",
            "Diferença do acumulado rainc + rainnc, incluindo contadores de bucket quando presentes.",
        )
        plot_q2_locations(q2, lat_cell, lon_cell, output_dir, "2014-09-10 01:00 UTC")
        plot_temperature_profile(
            temperature0,
            temperature1,
            zgrid1,
            dry_layer_mass0,
            dry_layer_mass1,
            area,
            output_dir,
        )

        q2_csv_path = output_dir / "q2-negative-cells.csv"
        write_q2_csv(q2_csv_path, q2_rows, q2_columns)

        log_path = run_dir / "log.atmosphere.0000.out"
        with log_path.open("r", encoding="utf-8", errors="replace") as stream:
            log_text = stream.read()
        analyzed_variables = sorted(
            [f"history:{name}" for name in ("areaCell", "zgrid", "rho", "pressure", "theta", "u", "w", *WATER_SPECIES, "surface_pressure")]
            + [
                f"{'diagnostics' if source_names == DIAG_NAMES else 'history'}:{name}"
                for name, (_, _, source_names) in surface_sources.items()
            ]
            + ["diagnostics:mslp", "diagnostics:xland", "derived:temperature", "derived:wind_speed_10m"]
        )
        summary: dict[str, Any] = {
            "schema_version": "1.0.0",
            "analysis": {
                "name": "first-atmosphere-run",
                "criteria_document": "docs/validation/first-atmosphere-run.md",
                "python": sys.version.split()[0],
                "dependencies": {
                    "numpy": np.__version__,
                    "xarray": xr.__version__,
                    "netCDF4": netCDF4.__version__,
                    "matplotlib": matplotlib.__version__,
                },
                "input_access": "read-only (enforced by container mount)",
                "analyzed_variables": analyzed_variables,
                "statistics": "float64 accumulation; population standard deviation (ddof=0)",
            },
            "run": {
                "materialized_by_commit": RUN_COMMIT,
                "cycle_0013_base_commit": RUN_BASE_COMMIT,
                "mpas_version": manifest["mpas"]["version"],
                "mpas_source_commit": manifest["mpas"]["commit"],
                "initial_timestamp": manifest["start_time"],
                "final_timestamp": manifest["end_time"],
                "mesh": MESH_NAME,
                "nCells": 10_242,
                "nVertLevels": 55,
                "mpi_ranks": manifest["mpi_ranks"],
                "timestep_seconds": manifest["timestep_seconds"],
                "run_duration": manifest["run_duration"],
                "sst_update": manifest["sst_update"],
                "physics_suite": manifest["physics_suite"],
            },
            "statuses": {
                "functional_validation": "PASS",
                "numerical_sanity": "PASS",
                "scientific_sanity": "PASS",
                "forecast_skill": "NOT_EVALUATED",
                "spinup": "INSUFFICIENT_TEMPORAL_WINDOW",
            },
            "criteria": criteria,
            "timestamps": timestamps,
            "dimensions": dimension_evidence,
            "numeric_audit": audits,
            "fields": fields,
            "q2_diagnostic": q2_diagnostic,
            "qv_diagnostic": qv_diagnostic,
            "precipitation": precipitation,
            "sst": {
                "array_equal": bool(np.array_equal(sst0, sst1)),
                "sha256_t0": sst_hash0,
                "sha256_t1": sst_hash1,
                "t0": array_statistics(sst0),
                "t1": array_statistics(sst1),
            },
            "surface_evolution": {
                "skintemp_changed_cell_count": int(np.count_nonzero(surface_arrays["skintemp"][1] != surface_arrays["skintemp"][0])),
                "skintemp_arrays_identical": bool(np.array_equal(surface_arrays["skintemp"][0], surface_arrays["skintemp"][1])),
            },
            "dry_air_mass": dry_air_mass,
            "water_inventory": water_inventory,
            "launcher_numeric_notes": {
                "underflow_mentions_in_rank0_log": log_text.lower().count("underflow"),
                "denormal_mentions_in_rank0_log": log_text.lower().count("denormal"),
                "interpretation": "The four launcher notes recorded in cycle 0013 are REPORT-ONLY; the rank-0 model log does not preserve launcher stderr.",
            },
            "figures": list(FIGURES),
            "tabular_artifacts": ["q2-negative-cells.csv"],
            "limitations": [
                "No observation or future ERA5 field is used, so forecast skill is not evaluated.",
                "Two output times cannot establish that spin-up is complete.",
                "The water inventory lacks integrated flux terms and is not a closed conservation budget.",
                "No approved tolerance exists for the dry-air mass delta; it is report-only.",
                "Fixed SST over one hour does not demonstrate suitability for longer forecasts.",
                "qsfc, psiq and psiq2 are absent, preventing exact reconstruction of negative q2 values.",
            ],
        }
        write_json_atomic(output_dir / "summary.json", summary)

        print("functional_validation=PASS")
        print("numerical_sanity=PASS")
        print("scientific_sanity=PASS")
        print("forecast_skill=NOT_EVALUATED")
        print("spinup=INSUFFICIENT_TEMPORAL_WINDOW")
        print(f"summary={output_dir / 'summary.json'}")
        return 0
    finally:
        for dataset in datasets:
            dataset.close()


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except ValidationError as error:
        print(f"scientific_run_error={error}", file=sys.stderr)
        raise SystemExit(1) from error
