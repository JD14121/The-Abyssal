"""Dependency-free content discovery, validation and CLI reporting.

Keep schema changes aligned with game/scripts/data/data_validator.gd and the
shared fixture suite. The syntax-only command intentionally does no schema work.
"""

import argparse
from collections import Counter
from dataclasses import dataclass, field
import json
import math
import os
from pathlib import Path
import re


DEFAULT_DATA_ROOT = Path(__file__).resolve().parents[1] / "game/data"
GROUP_TYPES = {"materials": "material", "items": "item"}
ID_PATTERN = re.compile(r"[a-z][a-z0-9_]*", re.ASCII)
COMMON_FIELDS = {"type", "id", "name"}
TYPE_FIELDS = {"material": {"density", "flammable"}, "item": {"category", "mass", "materials"}}


@dataclass
class ContentResult:
    errors: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)
    files: int = 0
    definitions: dict[str, dict] = field(default_factory=lambda: {"material": {}, "item": {}})
    sources: dict[tuple[str, str], str] = field(default_factory=dict)


def scan_json(directory: Path, result: ContentResult) -> list[Path]:
    if not directory.is_dir():
        result.errors.append(f"{directory} | directory: cannot open")
        return []
    paths = []

    def fail(error):
        result.errors.append(f"{error.filename} | directory: {error.strerror}")

    for parent, directories, files in os.walk(directory, onerror=fail, followlinks=False):
        for name in directories[:]:
            if (Path(parent) / name).is_symlink():
                result.errors.append(f"{Path(parent) / name} | directory: symbolic links are not supported")
                directories.remove(name)
        paths.extend(Path(parent) / name for name in files if name.endswith(".json"))
    return sorted(paths, key=lambda path: path.as_posix())


def _reject_constant(value):
    raise ValueError(f"invalid JSON constant {value}")


def read_json(path: Path, result: ContentResult):
    try:
        text = path.read_text(encoding="utf-8")
        result.files += 1
        return True, json.loads(text, parse_constant=_reject_constant)
    except (OSError, UnicodeError, ValueError) as error:
        result.errors.append(f"{path} | JSON: {error}")
        return False, None


def validate_entry(entry, expected_type: str, source: str, result: ContentResult) -> bool:
    start = len(result.errors)
    if not isinstance(entry, dict):
        result.errors.append(f"{source} | definition: expected an object")
        return False
    context = f"{source} | {entry.get('type', expected_type)}:{entry.get('id', '<missing>')}"

    def error(field_name, reason):
        result.errors.append(f"{context} | field {field_name}: {reason}")

    for name in ("type", "id", "name") + (("category",) if expected_type == "item" else ()):
        if name not in entry:
            error(name, "missing required field")
        elif not isinstance(entry[name], str) or not entry[name].strip():
            error(name, "expected non-empty string")
    if entry.get("type") != expected_type:
        error("type", f"expected {expected_type}, unknown or misplaced type")
    identifier = entry.get("id")
    if isinstance(identifier, str):
        if not ID_PATTERN.fullmatch(identifier):
            error("id", "expected ASCII lowercase_snake_case")
        if identifier in result.definitions[expected_type]:
            error("id", f"duplicate ID; first defined in {result.sources[(expected_type, identifier)]}")
    numeric = "density" if expected_type == "material" else "mass"
    if numeric in entry:
        value = entry[numeric]
        if type(value) not in (int, float):
            error(numeric, "expected number (not bool)")
        elif value < 0 or (isinstance(value, float) and not math.isfinite(value)):
            error(numeric, "expected finite number >= 0")
    if expected_type == "material":
        if "flammable" in entry and type(entry["flammable"]) is not bool:
            error("flammable", "expected bool")
    elif "materials" in entry:
        if not isinstance(entry["materials"], list):
            error("materials", "expected array of material IDs")
        else:
            for material_id in entry["materials"]:
                if not isinstance(material_id, str):
                    error("materials", "expected string material ID")
                elif material_id not in result.definitions["material"]:
                    error("materials", f"unknown material ID {material_id}")
    for name in sorted(entry.keys() - COMMON_FIELDS - TYPE_FIELDS[expected_type]):
        result.warnings.append(f"{context} | field {name}: unknown optional field")
    return len(result.errors) == start


def load_content(root: Path) -> ContentResult:
    result = ContentResult()
    order_path = root / "core/load_order.json"
    ok, order = read_json(order_path, result)
    if not ok:
        return result
    if not isinstance(order, dict) or order.get("groups") != ["materials", "items"]:
        result.errors.append(f"{order_path} | field groups: expected [materials, items] in dependency order")
        return result
    for name in sorted(order.keys() - {"groups"}):
        result.warnings.append(f"{order_path} | field {name}: unknown optional field")
    for group in order["groups"]:
        expected_type = GROUP_TYPES[group]
        for path in scan_json(root / group, result):
            ok, value = read_json(path, result)
            if not ok:
                continue
            if isinstance(value, dict):
                value = [value]
            if not isinstance(value, list):
                result.errors.append(f"{path} | root: expected an object or array of objects")
                continue
            for index, entry in enumerate(value):
                source = f"{path}[{index}]"
                if validate_entry(entry, expected_type, source, result):
                    result.definitions[expected_type][entry["id"]] = entry
                    result.sources[(expected_type, entry["id"])] = source
    return result


def run_cli(command: str) -> int:
    parser = argparse.ArgumentParser(description={
        "validate_json": "Recursively check JSON syntax in the data directory.",
        "validate_ids": "Validate definition IDs and their complete schemas.",
        "validate_references": "Validate material references and their prerequisite schemas/IDs.",
        "content_report": "Report counts only after complete content validation.",
    }[command])
    parser.add_argument("--data-root", type=Path, default=DEFAULT_DATA_ROOT,
                        help="Data root containing core/, materials/ and items/.")
    root = parser.parse_args().data_root.resolve()
    if command == "validate_json":
        result = ContentResult()
        paths = scan_json(root, result)
        if not paths and not result.errors:
            result.errors.append(f"{root} | no JSON files found")
        for path in paths:
            read_json(path, result)
        print(f"JSON files checked: {result.files}")
    else:
        result = load_content(root)
    for warning in result.warnings:
        print("WARNING: " + warning)
    for error in result.errors:
        print("ERROR: " + error)
    if result.errors:
        print(f"FAIL: {len(result.errors)} error(s)")
        return 1
    if command != "validate_json":
        materials = result.definitions["material"]
        items = result.definitions["item"]
        print(f"Materials: {len(materials)}\nItems: {len(items)}")
        if command == "content_report":
            print("Item Categories:")
            for category, count in sorted(Counter(item["category"] for item in items.values()).items()):
                print(f"{category}: {count}")
            print(f"Total Definitions: {len(materials) + len(items)}")
        else:
            print("Schema / IDs / References: 0 errors")
    print("PASS")
    return 0
