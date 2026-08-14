#!/usr/bin/env python3
"""Safely acquire the approved ERA5 baseline through the CDS API."""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import importlib.metadata
import json
import os
from pathlib import Path
import stat
import sys
import tempfile
from typing import Any


EXPECTED_CDSAPI_VERSION = "0.7.7"
CONFIG_FILENAMES = {
    "pressure-levels": "pressure-levels.json",
    "single-levels": "single-levels.json",
}
EXPECTED_DATASETS = {
    "pressure-levels": "reanalysis-era5-pressure-levels",
    "single-levels": "reanalysis-era5-single-levels",
}
MANIFEST_SCHEMA_VERSION = 1


class Era5Error(RuntimeError):
    """Expected validation or acquisition failure."""


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def require_regular_file(path: Path, description: str, *, nonempty: bool = True) -> None:
    try:
        metadata = path.lstat()
    except FileNotFoundError as exc:
        raise Era5Error(f"{description} not found: {path}") from exc
    if stat.S_ISLNK(metadata.st_mode) or not stat.S_ISREG(metadata.st_mode):
        raise Era5Error(f"{description} must be a regular non-symlink file: {path}")
    if nonempty and metadata.st_size == 0:
        raise Era5Error(f"{description} is empty: {path}")


def require_string_list(request: dict[str, Any], key: str) -> list[str]:
    value = request.get(key)
    if (
        not isinstance(value, list)
        or not value
        or any(not isinstance(item, str) or not item for item in value)
        or len(set(value)) != len(value)
    ):
        raise Era5Error(f"request.{key} must be a non-empty list of unique strings")
    return value


def parse_timestamp(value: Any) -> dt.datetime:
    if not isinstance(value, str):
        raise Era5Error("baseline_timestamp must be a string")
    try:
        parsed = dt.datetime.strptime(value, "%Y-%m-%dT%H:%M:%SZ")
    except ValueError as exc:
        raise Era5Error(
            "baseline_timestamp must use the format YYYY-MM-DDTHH:MM:SSZ"
        ) from exc
    return parsed.replace(tzinfo=dt.timezone.utc)


def load_config(path: Path, expected_kind: str) -> dict[str, Any]:
    require_regular_file(path, "ERA5 request configuration")
    try:
        config = json.loads(path.read_text(encoding="utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise Era5Error(f"invalid JSON configuration: {path}") from exc
    if not isinstance(config, dict):
        raise Era5Error(f"configuration root must be an object: {path}")

    required_keys = {
        "schema_version",
        "kind",
        "dataset",
        "baseline_timestamp",
        "output_filename",
        "probe_area",
        "expected_message_count",
        "expected_grib_editions",
        "minimum_final_size_bytes",
        "request",
    }
    if set(config) != required_keys:
        missing = sorted(required_keys - set(config))
        extra = sorted(set(config) - required_keys)
        raise Era5Error(
            f"unexpected configuration keys in {path}; missing={missing}, extra={extra}"
        )
    if config["schema_version"] != 1:
        raise Era5Error(f"unsupported configuration schema in {path}")
    if config["kind"] != expected_kind:
        raise Era5Error(f"expected kind={expected_kind} in {path}")
    if config["dataset"] != EXPECTED_DATASETS[expected_kind]:
        raise Era5Error(f"unexpected CDS dataset for {expected_kind}: {config['dataset']}")

    output_filename = config["output_filename"]
    if (
        not isinstance(output_filename, str)
        or Path(output_filename).name != output_filename
        or not output_filename.endswith(".grib")
    ):
        raise Era5Error(f"unsafe output_filename in {path}")

    probe_area = config["probe_area"]
    if (
        not isinstance(probe_area, list)
        or len(probe_area) != 4
        or any(not isinstance(value, (int, float)) for value in probe_area)
    ):
        raise Era5Error(f"probe_area must be [north, west, south, east] in {path}")
    north, west, south, east = probe_area
    if not (-90 <= south < north <= 90 and -180 <= west < east <= 180):
        raise Era5Error(f"invalid probe_area bounds in {path}")

    message_count = config["expected_message_count"]
    minimum_size = config["minimum_final_size_bytes"]
    editions = config["expected_grib_editions"]
    if not isinstance(message_count, int) or message_count < 1:
        raise Era5Error(f"expected_message_count must be positive in {path}")
    if not isinstance(minimum_size, int) or minimum_size < 1:
        raise Era5Error(f"minimum_final_size_bytes must be positive in {path}")
    if (
        not isinstance(editions, list)
        or not editions
        or any(edition not in (1, 2) for edition in editions)
        or len(set(editions)) != len(editions)
    ):
        raise Era5Error(f"expected_grib_editions must contain unique editions 1/2 in {path}")

    request = config["request"]
    if not isinstance(request, dict):
        raise Era5Error(f"request must be an object in {path}")
    required_request_keys = {
        "product_type",
        "variable",
        "year",
        "month",
        "day",
        "time",
        "data_format",
        "download_format",
    }
    if expected_kind == "pressure-levels":
        required_request_keys.add("pressure_level")
    if set(request) != required_request_keys:
        missing = sorted(required_request_keys - set(request))
        extra = sorted(set(request) - required_request_keys)
        raise Era5Error(
            f"unexpected request keys in {path}; missing={missing}, extra={extra}"
        )
    if request.get("product_type") != ["reanalysis"]:
        raise Era5Error(f"product_type must be exactly ['reanalysis'] in {path}")
    if request.get("data_format") != "grib":
        raise Era5Error(f"data_format must be grib in {path}")
    if request.get("download_format") != "unarchived":
        raise Era5Error(f"download_format must be unarchived in {path}")
    if "area" in request or "grid" in request:
        raise Era5Error(f"final global request must omit area and grid in {path}")

    variables = require_string_list(request, "variable")
    timestamp = parse_timestamp(config["baseline_timestamp"])
    selectors = {
        "year": timestamp.strftime("%Y"),
        "month": timestamp.strftime("%m"),
        "day": timestamp.strftime("%d"),
        "time": timestamp.strftime("%H:%M"),
    }
    for key, expected_value in selectors.items():
        if request.get(key) != [expected_value]:
            raise Era5Error(
                f"request.{key} must match baseline_timestamp in {path}: {expected_value}"
            )

    if expected_kind == "pressure-levels":
        levels = require_string_list(request, "pressure_level")
        calculated_count = len(variables) * len(levels)
    else:
        calculated_count = len(variables)
    if calculated_count != message_count:
        raise Era5Error(
            f"expected_message_count={message_count} but selection implies "
            f"{calculated_count} messages in {path}"
        )

    config["_path"] = path
    config["_timestamp"] = timestamp
    return config


def load_configs(config_dir: Path, selection: str) -> list[dict[str, Any]]:
    kinds = list(CONFIG_FILENAMES) if selection == "all" else [selection]
    configs = [
        load_config(config_dir / CONFIG_FILENAMES[kind], kind) for kind in kinds
    ]
    timestamps = {config["baseline_timestamp"] for config in configs}
    probe_areas = {tuple(config["probe_area"]) for config in configs}
    if len(timestamps) != 1:
        raise Era5Error("ERA5 configurations do not share one baseline timestamp")
    if len(probe_areas) != 1:
        raise Era5Error("ERA5 configurations do not share one probe area")
    return configs


def baseline_subdirectory(config: dict[str, Any]) -> str:
    timestamp: dt.datetime = config["_timestamp"]
    return timestamp.strftime("%Y-%m-%d_%H")


def scan_grib(path: Path) -> dict[str, Any]:
    require_regular_file(path, "GRIB artifact")
    size = path.stat().st_size
    editions: set[int] = set()
    messages = 0
    offset = 0

    with path.open("rb") as stream:
        while offset < size:
            stream.seek(offset)
            header = stream.read(16)
            if len(header) < 8 or header[:4] != b"GRIB":
                stream.seek(offset)
                prefix = stream.read(64).lstrip().lower()
                if prefix.startswith((b"<html", b"<!doctype", b"{", b"[")):
                    classification = "HTML/JSON response"
                else:
                    classification = "non-GRIB bytes"
                raise Era5Error(
                    f"{classification} at byte offset {offset} in {path.name}"
                )

            edition = header[7]
            if edition == 1:
                message_size = int.from_bytes(header[4:7], "big")
                minimum_message_size = 12
            elif edition == 2:
                if len(header) < 16:
                    raise Era5Error(f"truncated GRIB2 header in {path.name}")
                message_size = int.from_bytes(header[8:16], "big")
                minimum_message_size = 20
            else:
                raise Era5Error(
                    f"unsupported GRIB edition {edition} at byte offset {offset}"
                )

            if message_size < minimum_message_size or offset + message_size > size:
                raise Era5Error(
                    f"invalid GRIB message length {message_size} at byte offset {offset}"
                )
            stream.seek(offset + message_size - 4)
            if stream.read(4) != b"7777":
                raise Era5Error(
                    f"missing GRIB end marker at byte offset {offset + message_size - 4}"
                )
            editions.add(edition)
            messages += 1
            offset += message_size

    if offset != size or messages == 0:
        raise Era5Error(f"invalid GRIB framing in {path.name}")
    return {
        "size_bytes": size,
        "sha256": sha256_file(path),
        "message_count": messages,
        "grib_editions": sorted(editions),
    }


def validate_grib(
    path: Path,
    config: dict[str, Any],
    *,
    enforce_final_size: bool,
) -> dict[str, Any]:
    result = scan_grib(path)
    if result["message_count"] != config["expected_message_count"]:
        raise Era5Error(
            f"{path.name}: expected {config['expected_message_count']} GRIB messages, "
            f"found {result['message_count']}"
        )
    if result["grib_editions"] != sorted(config["expected_grib_editions"]):
        raise Era5Error(
            f"{path.name}: expected GRIB editions {config['expected_grib_editions']}, "
            f"found {result['grib_editions']}"
        )
    if enforce_final_size and result["size_bytes"] < config["minimum_final_size_bytes"]:
        raise Era5Error(
            f"{path.name}: size {result['size_bytes']} is below the configured global "
            f"minimum {config['minimum_final_size_bytes']}"
        )
    return result


def safe_manifest(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {
            "schema_version": MANIFEST_SCHEMA_VERSION,
            "baseline_timestamp": None,
            "files": {},
        }
    require_regular_file(path, "ERA5 manifest")
    try:
        manifest = json.loads(path.read_text(encoding="utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise Era5Error(f"invalid ERA5 manifest: {path}") from exc
    if (
        not isinstance(manifest, dict)
        or manifest.get("schema_version") != MANIFEST_SCHEMA_VERSION
        or not isinstance(manifest.get("files"), dict)
    ):
        raise Era5Error(f"unsupported ERA5 manifest structure: {path}")
    return manifest


def write_manifest(path: Path, manifest: dict[str, Any]) -> None:
    payload = json.dumps(manifest, indent=2, sort_keys=True) + "\n"
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{path.name}.", suffix=".tmp", dir=path.parent
    )
    temporary_path = Path(temporary_name)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as stream:
            stream.write(payload)
            stream.flush()
            os.fsync(stream.fileno())
        os.chmod(temporary_path, 0o644)
        os.replace(temporary_path, path)
    finally:
        temporary_path.unlink(missing_ok=True)


def config_sha256(config: dict[str, Any]) -> str:
    path: Path = config["_path"]
    return sha256_file(path)


def validate_manifest_entry(
    manifest: dict[str, Any], config: dict[str, Any], result: dict[str, Any]
) -> None:
    if manifest.get("baseline_timestamp") != config["baseline_timestamp"]:
        raise Era5Error("manifest baseline timestamp does not match versioned request")
    entry = manifest["files"].get(config["output_filename"])
    if not isinstance(entry, dict):
        raise Era5Error(f"manifest has no entry for {config['output_filename']}")
    expected = {
        "dataset": config["dataset"],
        "request_config": config["_path"].name,
        "request_sha256": config_sha256(config),
        "size_bytes": result["size_bytes"],
        "sha256": result["sha256"],
        "message_count": result["message_count"],
        "grib_editions": result["grib_editions"],
    }
    for key, expected_value in expected.items():
        if entry.get(key) != expected_value:
            raise Era5Error(
                f"manifest mismatch for {config['output_filename']} field {key}"
            )


def print_result(prefix: str, config: dict[str, Any], result: dict[str, Any]) -> None:
    print(f"{prefix}_kind={config['kind']}")
    print(f"{prefix}_dataset={config['dataset']}")
    print(f"{prefix}_file={config['output_filename']}")
    print(f"{prefix}_size_bytes={result['size_bytes']}")
    print(f"{prefix}_sha256={result['sha256']}")
    print(f"{prefix}_message_count={result['message_count']}")
    print(
        f"{prefix}_grib_editions="
        + ",".join(str(value) for value in result["grib_editions"])
    )


def cdsapi_version() -> str:
    try:
        version = importlib.metadata.version("cdsapi")
    except importlib.metadata.PackageNotFoundError as exc:
        raise Era5Error("cdsapi is not installed; use the dedicated acquisition image") from exc
    if version != EXPECTED_CDSAPI_VERSION:
        raise Era5Error(
            f"expected cdsapi {EXPECTED_CDSAPI_VERSION}, found {version}"
        )
    return version


def require_credentials() -> Path:
    configured = os.environ.get("CDSAPI_RC")
    path = Path(configured) if configured else Path.home() / ".cdsapirc"
    require_regular_file(path, "CDS API credential file")
    return path


def make_client() -> Any:
    cdsapi_version()
    require_credentials()
    try:
        import cdsapi

        return cdsapi.Client()
    except Exception as exc:
        raise Era5Error(
            "could not initialize the CDS client; verify the credential format without "
            f"printing it (failure type: {type(exc).__name__})"
        ) from exc


def retrieve(client: Any, dataset: str, request: dict[str, Any], target: Path) -> None:
    try:
        client.retrieve(dataset, request, str(target))
    except Exception as exc:
        message = str(exc).lower()
        if "term" in message or "licence" in message or "license" in message:
            reason = "accept the Terms of Use for this dataset in the CDS portal"
        elif "unauthor" in message or "forbidden" in message or "auth" in message:
            reason = "verify the CDS account and Personal Access Token"
        else:
            reason = "check CDS service status, authentication, terms, and request validity"
        raise Era5Error(
            f"CDS retrieval failed; {reason} (failure type: {type(exc).__name__})"
        ) from exc


def command_config(configs: list[dict[str, Any]]) -> None:
    for config in configs:
        variables = config["request"]["variable"]
        levels = config["request"].get("pressure_level", [])
        print(f"kind={config['kind']}")
        print(f"dataset={config['dataset']}")
        print(f"baseline_timestamp={config['baseline_timestamp']}")
        print("final_area=global (area omitted)")
        print("final_grid=CDS default (grid omitted)")
        print(f"variable_count={len(variables)}")
        print(f"pressure_level_count={len(levels)}")
        print(f"expected_message_count={config['expected_message_count']}")
        print(f"request_sha256={config_sha256(config)}")


def command_probe(configs: list[dict[str, Any]]) -> None:
    client = make_client()
    with tempfile.TemporaryDirectory(prefix="mpas-era5-cds-probe.") as directory:
        probe_dir = Path(directory)
        for config in configs:
            request = dict(config["request"])
            request["area"] = config["probe_area"]
            target = probe_dir / config["output_filename"]
            print(f"probe_kind={config['kind']}")
            print("probe_area=" + ",".join(str(value) for value in request["area"]))
            retrieve(client, config["dataset"], request, target)
            result = validate_grib(target, config, enforce_final_size=False)
            print_result("probe", config, result)
    print("probe_status=PASS")


def command_download(configs: list[dict[str, Any]], output_root: Path) -> None:
    client: Any | None = None
    output_subdirectories = {baseline_subdirectory(config) for config in configs}
    if len(output_subdirectories) != 1:
        raise Era5Error("selected requests do not map to one output directory")
    output_dir = output_root / output_subdirectories.pop()
    output_dir.mkdir(parents=True, exist_ok=True)
    if output_dir.is_symlink() or not output_dir.is_dir():
        raise Era5Error(f"output path must be a non-symlink directory: {output_dir}")
    manifest_path = output_dir / "manifest.json"

    for config in configs:
        final_path = output_dir / config["output_filename"]
        if final_path.exists() or final_path.is_symlink():
            result = validate_grib(final_path, config, enforce_final_size=True)
            manifest = safe_manifest(manifest_path)
            validate_manifest_entry(manifest, config, result)
            print_result("unchanged", config, result)
            continue

        manifest = safe_manifest(manifest_path)
        if manifest["baseline_timestamp"] not in (
            None,
            config["baseline_timestamp"],
        ):
            raise Era5Error("existing manifest belongs to another baseline timestamp")
        if config["output_filename"] in manifest["files"]:
            raise Era5Error(
                f"manifest records {config['output_filename']}, but the file is absent"
            )

        if client is None:
            client = make_client()
        descriptor, temporary_name = tempfile.mkstemp(
            prefix=f".{config['output_filename']}.",
            suffix=".partial",
            dir=output_dir,
        )
        os.close(descriptor)
        temporary_path = Path(temporary_name)
        try:
            retrieve(client, config["dataset"], config["request"], temporary_path)
            result = validate_grib(temporary_path, config, enforce_final_size=True)
            os.chmod(temporary_path, 0o644)
            os.replace(temporary_path, final_path)

            manifest["baseline_timestamp"] = config["baseline_timestamp"]
            manifest["cdsapi_version"] = cdsapi_version()
            manifest["acquisition_architecture"] = "dedicated Docker client"
            manifest["final_area"] = "global (area omitted)"
            manifest["final_grid"] = "CDS default regular latitude/longitude"
            manifest["files"][config["output_filename"]] = {
                "acquired_at_utc": dt.datetime.now(dt.timezone.utc)
                .replace(microsecond=0)
                .isoformat()
                .replace("+00:00", "Z"),
                "dataset": config["dataset"],
                "request_config": config["_path"].name,
                "request_sha256": config_sha256(config),
                "job_result": "completed",
                "variable_count": len(config["request"]["variable"]),
                "pressure_level_count": len(
                    config["request"].get("pressure_level", [])
                ),
                **result,
            }
            write_manifest(manifest_path, manifest)
            print_result("download", config, result)
        finally:
            temporary_path.unlink(missing_ok=True)
    print(f"era5_directory={output_dir}")
    print("download_status=PASS")


def command_validate(configs: list[dict[str, Any]], output_root: Path) -> None:
    output_subdirectories = {baseline_subdirectory(config) for config in configs}
    if len(output_subdirectories) != 1:
        raise Era5Error("selected requests do not map to one output directory")
    output_dir = output_root / output_subdirectories.pop()
    if output_dir.is_symlink() or not output_dir.is_dir():
        raise Era5Error(f"ERA5 output directory not found: {output_dir}")
    manifest = safe_manifest(output_dir / "manifest.json")
    for config in configs:
        path = output_dir / config["output_filename"]
        result = validate_grib(path, config, enforce_final_size=True)
        validate_manifest_entry(manifest, config, result)
        print_result("validated", config, result)
    if manifest.get("cdsapi_version") != EXPECTED_CDSAPI_VERSION:
        raise Era5Error("manifest does not record the approved cdsapi version")
    print("era5_transport_validation=PASS")


def make_grib1(payload: bytes = b"") -> bytes:
    size = 12 + len(payload)
    return b"GRIB" + size.to_bytes(3, "big") + b"\x01" + payload + b"7777"


def make_grib2(payload: bytes = b"") -> bytes:
    size = 20 + len(payload)
    return b"GRIB\x00\x00\x00\x02" + size.to_bytes(8, "big") + payload + b"7777"


def command_self_test() -> None:
    with tempfile.TemporaryDirectory(prefix="mpas-era5-grib-self-test.") as directory:
        root = Path(directory)
        valid = root / "valid.grib"
        valid.write_bytes(make_grib1() + make_grib1(b"abcd"))
        result = scan_grib(valid)
        if result["message_count"] != 2 or result["grib_editions"] != [1]:
            raise Era5Error("GRIB1 scanner self-test failed")

        valid2 = root / "valid2.grib"
        valid2.write_bytes(make_grib2())
        result2 = scan_grib(valid2)
        if result2["message_count"] != 1 or result2["grib_editions"] != [2]:
            raise Era5Error("GRIB2 scanner self-test failed")

        invalid_samples = {
            "empty.grib": b"",
            "html.grib": b"<!doctype html><title>error</title>",
            "json.grib": b'{"error": "denied"}',
            "truncated.grib": make_grib1()[:-1],
        }
        for name, payload in invalid_samples.items():
            candidate = root / name
            candidate.write_bytes(payload)
            try:
                scan_grib(candidate)
            except Era5Error:
                continue
            raise Era5Error(f"GRIB scanner accepted invalid self-test sample: {name}")

        request_path = root / "request.json"
        request_path.write_text("{}\n", encoding="utf-8")
        validation_config = {
            "kind": "pressure-levels",
            "dataset": EXPECTED_DATASETS["pressure-levels"],
            "baseline_timestamp": "2014-09-10T00:00:00Z",
            "output_filename": valid.name,
            "expected_message_count": 2,
            "expected_grib_editions": [1],
            "minimum_final_size_bytes": 1,
            "_path": request_path,
        }
        validated = validate_grib(valid, validation_config, enforce_final_size=True)
        manifest_path = root / "manifest.json"
        manifest = {
            "schema_version": MANIFEST_SCHEMA_VERSION,
            "baseline_timestamp": validation_config["baseline_timestamp"],
            "cdsapi_version": EXPECTED_CDSAPI_VERSION,
            "files": {
                valid.name: {
                    "dataset": validation_config["dataset"],
                    "request_config": request_path.name,
                    "request_sha256": sha256_file(request_path),
                    **validated,
                }
            },
        }
        write_manifest(manifest_path, manifest)
        loaded_manifest = safe_manifest(manifest_path)
        validate_manifest_entry(loaded_manifest, validation_config, validated)
        loaded_manifest["files"][valid.name]["sha256"] = "0" * 64
        try:
            validate_manifest_entry(loaded_manifest, validation_config, validated)
        except Era5Error:
            pass
        else:
            raise Era5Error("manifest self-test accepted a divergent checksum")
    print("grib_scanner_self_test=PASS")
    print("era5_manifest_self_test=PASS")


def parser() -> argparse.ArgumentParser:
    argument_parser = argparse.ArgumentParser(description=__doc__)
    argument_parser.add_argument(
        "command",
        choices=("config", "probe", "download", "validate", "self-test", "version"),
    )
    argument_parser.add_argument(
        "--config-dir",
        type=Path,
        default=Path("cases/first-global-240km/era5"),
    )
    argument_parser.add_argument(
        "--output-root", type=Path, default=Path("data/era5")
    )
    argument_parser.add_argument(
        "--select",
        choices=("all", "pressure-levels", "single-levels"),
        default="all",
    )
    return argument_parser


def main() -> int:
    args = parser().parse_args()
    try:
        if args.command == "version":
            print(f"python_version={sys.version.split()[0]}")
            print(f"cdsapi_version={cdsapi_version()}")
            return 0
        if args.command == "self-test":
            command_self_test()
            return 0

        configs = load_configs(args.config_dir, args.select)
        if args.command == "config":
            command_config(configs)
        elif args.command == "probe":
            command_probe(configs)
        elif args.command == "download":
            command_download(configs, args.output_root)
        elif args.command == "validate":
            command_validate(configs, args.output_root)
        else:
            raise Era5Error(f"unsupported command: {args.command}")
        return 0
    except Era5Error as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
