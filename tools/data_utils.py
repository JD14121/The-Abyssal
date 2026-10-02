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
GROUP_TYPES = {"materials": "material", "items": "item", "loot": "loot", "consumables": "consumable", "creatures": "creature", "weapons": "weapon", "medical": "medical"}
ID_PATTERN = re.compile(r"[a-z][a-z0-9_]*", re.ASCII)
COMMON_FIELDS = {"type", "id", "name"}
TYPE_FIELDS = {
    "material": {"density", "flammable"},
    "item": {"category", "mass", "materials"},
    "loot": {"rolls", "entries"},
    "consumable": {"item_id", "hunger_delta", "thirst_delta"},
    "creature": {"move_speed", "vision_range", "attack_range", "attack_interval", "max_health", "melee_damage"},
    "weapon": {"item_id", "kind", "melee_damage", "melee_range", "attack_interval", "damage", "range", "ammo_item_id", "magazine_size", "reload_time", "noise_radius", "projectile_speed"},
    "medical": {"item_id", "bleeding_reduction_per_game_hour", "infection_reduction_per_game_hour"},
}


@dataclass
class ContentResult:
    errors: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)
    files: int = 0
    definitions: dict[str, dict] = field(default_factory=lambda: {"material": {}, "item": {}, "loot": {}, "consumable": {}, "creature": {}, "weapon": {}, "medical": {}})
    sources: dict[tuple[str, str], str] = field(default_factory=dict)
    consumable_item_sources: dict[str, str] = field(default_factory=dict)
    weapon_item_sources: dict[str, str] = field(default_factory=dict)
    medical_item_sources: dict[str, str] = field(default_factory=dict)


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

    if expected_type in ("loot", "consumable", "weapon", "medical"):
        required = ("type", "id") + (("item_id",) if expected_type in ("consumable", "weapon", "medical") else ())
    else:
        required = ("type", "id", "name") + (("category",) if expected_type == "item" else ())
    for name in required:
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
    if expected_type in ("material", "item") and numeric in entry:
        value = entry[numeric]
        if type(value) not in (int, float):
            error(numeric, "expected number (not bool)")
        elif value < 0 or (isinstance(value, float) and not math.isfinite(value)):
            error(numeric, "expected finite number >= 0")
    if expected_type == "material":
        if "flammable" in entry and type(entry["flammable"]) is not bool:
            error("flammable", "expected bool")
    elif expected_type == "item" and "materials" in entry:
        if not isinstance(entry["materials"], list):
            error("materials", "expected array of material IDs")
        else:
            for material_id in entry["materials"]:
                if not isinstance(material_id, str):
                    error("materials", "expected string material ID")
                elif material_id not in result.definitions["material"]:
                    error("materials", f"unknown material ID {material_id}")
    elif expected_type == "creature":
        for field_name in ("move_speed", "vision_range", "attack_range", "attack_interval", "max_health", "melee_damage"):
            value = entry.get(field_name)
            if field_name not in entry:
                error(field_name, "missing required field")
            elif not _is_finite_number(value) or value <= 0:
                error(field_name, "expected finite number > 0")
        vision = entry.get("vision_range")
        attack = entry.get("attack_range")
        if _is_finite_number(vision) and _is_finite_number(attack) and attack > vision:
            error("attack_range", "expected <= vision_range")
    elif expected_type == "weapon":
        item_id = entry.get("item_id")
        if isinstance(item_id, str) and item_id.strip():
            if item_id not in result.definitions["item"]:
                error("item_id", f"unknown item ID {item_id}")
            if item_id in result.weapon_item_sources:
                error("item_id", f"duplicate Weapon mapping for item ID {item_id}; first defined in {result.weapon_item_sources[item_id]}")
        kind = entry.get("kind", "melee")
        if kind not in ("melee", "ranged"):
            error("kind", "expected melee or ranged")
        if kind == "melee":
            fields = ("melee_damage", "melee_range", "attack_interval")
            for field_name in fields:
                value = entry.get(field_name)
                if field_name not in entry:
                    error(field_name, "missing required field")
                elif not _is_finite_number(value) or value <= 0:
                    error(field_name, "expected finite number > 0")
        elif kind == "ranged":
            ammo_id = entry.get("ammo_item_id")
            if not isinstance(ammo_id, str) or not ammo_id.strip():
                error("ammo_item_id", "expected non-empty Item ID")
            elif ammo_id not in result.definitions["item"]:
                error("ammo_item_id", f"unknown item ID {ammo_id}")
            for field_name in ("damage", "range", "attack_interval", "reload_time", "noise_radius", "projectile_speed"):
                value = entry.get(field_name)
                if field_name not in entry:
                    error(field_name, "missing required field")
                elif not _is_finite_number(value) or value <= 0:
                    error(field_name, "expected finite number > 0")
            magazine = entry.get("magazine_size")
            if not _is_nonnegative_integer(magazine) or magazine == 0:
                error("magazine_size", "expected integer > 0")
    elif expected_type == "medical":
        item_id = entry.get("item_id")
        if isinstance(item_id, str) and item_id.strip():
            if item_id not in result.definitions["item"]:
                error("item_id", f"unknown item ID {item_id}")
            if item_id in result.medical_item_sources:
                error("item_id", f"duplicate Medical mapping for item ID {item_id}; first defined in {result.medical_item_sources[item_id]}")
        effects = [entry.get(field) for field in ("bleeding_reduction_per_game_hour", "infection_reduction_per_game_hour") if field in entry]
        for field in ("bleeding_reduction_per_game_hour", "infection_reduction_per_game_hour"):
            if field in entry and (not _is_finite_number(entry[field]) or entry[field] <= 0):
                error(field, "expected finite number > 0")
        if not any(_is_finite_number(effect) and effect > 0 for effect in effects):
            error("bleeding_reduction_per_game_hour/infection_reduction_per_game_hour", "expected at least one positive treatment effect")
    elif expected_type == "loot":
        _validate_loot(entry, context, result, error)
    elif expected_type == "consumable":
        item_id = entry.get("item_id")
        if isinstance(item_id, str) and item_id.strip():
            if item_id not in result.definitions["item"]:
                error("item_id", f"unknown item ID {item_id}")
            if item_id in result.consumable_item_sources:
                error("item_id", f"duplicate Consumable mapping for item ID {item_id}; first defined in {result.consumable_item_sources[item_id]}")
        for field_name in ("hunger_delta", "thirst_delta"):
            value = entry.get(field_name, 0.0)
            if not _is_finite_number(value):
                error(field_name, "expected finite number")
        hunger = entry.get("hunger_delta", 0.0)
        thirst = entry.get("thirst_delta", 0.0)
    common_fields = {"type", "id"} | ({"name"} if expected_type in ("material", "item", "creature") else set())
    for name in sorted(entry.keys() - common_fields - TYPE_FIELDS[expected_type]):
        result.warnings.append(f"{context} | field {name}: unknown optional field")
    if (expected_type == "consumable" and len(result.errors) == start
            and _is_finite_number(entry.get("hunger_delta", 0.0))
            and _is_finite_number(entry.get("thirst_delta", 0.0))
            and entry.get("hunger_delta", 0.0) == 0.0 and entry.get("thirst_delta", 0.0) == 0.0):
        result.warnings.append(f"{context} | fields hunger_delta/thirst_delta: Consumable has zero effect")
    return len(result.errors) == start


def _validate_loot(entry, context, result, error):
    rolls = entry.get("rolls")
    if "rolls" not in entry:
        error("rolls", "missing required field")
    elif not _is_nonnegative_integer(rolls):
        error("rolls", "expected integer >= 0")
    if "entries" not in entry:
        error("entries", "missing required field")
        return
    entries = entry["entries"]
    if not isinstance(entries, list):
        error("entries", "expected array")
        return
    if _is_nonnegative_integer(rolls) and rolls > 0 and not entries:
        result.warnings.append(f"{context} | field entries: loot group has rolls but no entries")
    for index, loot_entry in enumerate(entries):
        entry_context = f"{context} | entries[{index}]"
        if not isinstance(loot_entry, dict):
            result.errors.append(f"{entry_context} | entry: expected an object")
            continue

        def entry_error(field_name, reason):
            result.errors.append(f"{entry_context} | field {field_name}: {reason}")

        item_id = loot_entry.get("item_id")
        if not isinstance(item_id, str) or not item_id.strip():
            entry_error("item_id", "expected non-empty string")
        elif item_id not in result.definitions["item"]:
            entry_error("item_id", f"unknown item ID {item_id}")
        weight = loot_entry.get("weight")
        if "weight" not in loot_entry:
            entry_error("weight", "missing required field")
        elif not _is_finite_number(weight) or weight <= 0:
            entry_error("weight", "expected finite number > 0")
        chance = loot_entry.get("chance", 1.0)
        if not _is_finite_number(chance) or not 0 <= chance <= 1:
            entry_error("chance", "expected finite number in [0.0, 1.0]")
        minimum = loot_entry.get("min_quantity", 1)
        maximum = loot_entry.get("max_quantity", minimum)
        if not _is_nonnegative_integer(minimum):
            entry_error("min_quantity", "expected integer >= 0")
        if not _is_nonnegative_integer(maximum) or (_is_nonnegative_integer(minimum) and maximum < minimum):
            entry_error("max_quantity", "expected integer >= min_quantity")
        for name in sorted(loot_entry.keys() - {"item_id", "weight", "chance", "min_quantity", "max_quantity"}):
            result.warnings.append(f"{entry_context} | field {name}: unknown optional field")


def _is_nonnegative_integer(value):
    if type(value) is int:
        return value >= 0
    return type(value) is float and math.isfinite(value) and value >= 0 and value.is_integer()


def _is_finite_number(value):
    if type(value) not in (int, float):
        return False
    try:
        return math.isfinite(float(value))
    except OverflowError:
        return False


def load_content(root: Path) -> ContentResult:
    result = ContentResult()
    order_path = root / "core/load_order.json"
    ok, order = read_json(order_path, result)
    if not ok:
        return result
    valid_orders = (["materials", "items", "loot"], ["materials", "items", "loot", "consumables"],
                    ["materials", "items", "loot", "consumables", "creatures"],
                    ["materials", "items", "loot", "consumables", "creatures", "weapons"],
                    ["materials", "items", "loot", "consumables", "creatures", "weapons", "medical"])
    if not isinstance(order, dict) or order.get("groups") not in valid_orders:
        result.errors.append(f"{order_path} | field groups: expected a supported ordered prefix from materials, items, loot, consumables, creatures, weapons, medical")
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
                    if expected_type == "consumable":
                        result.consumable_item_sources[entry["item_id"]] = source
                    elif expected_type == "weapon":
                        result.weapon_item_sources[entry["item_id"]] = source
                    elif expected_type == "medical":
                        result.medical_item_sources[entry["item_id"]] = source
    _validate_world_layout(root, result)
    return result


def _validate_world_layout(root: Path, result: ContentResult) -> None:
    path = root / "world/demo_town.json"
    if not path.exists():
        return
    ok, layout = read_json(path, result)
    if not ok:
        return

    def error(field_name, message):
        result.errors.append(f"{path} | field {field_name}: {message}")

    if not isinstance(layout, dict) or layout.get("version") != 1:
        error("version", "expected world layout version 1")
        return
    bounds = layout.get("bounds")
    if (not isinstance(bounds, list) or len(bounds) != 2
            or not all(_is_finite_number(value) and value >= 900 for value in bounds)):
        error("bounds", "expected finite [width, height], each >= 900")
        return
    for field_name, minimum_count in (("building_sites", 3), ("zombie_spawn_sites", 1)):
        points = layout.get(field_name)
        if not isinstance(points, list) or len(points) < minimum_count:
            error(field_name, f"expected array with at least {minimum_count} sites")
            continue
        for index, point in enumerate(points):
            if (not isinstance(point, list) or len(point) != 2
                    or not all(_is_finite_number(value) for value in point)):
                error(field_name, f"[{index}] expected finite [x, y]")
            elif not (0 <= point[0] <= bounds[0] and 0 <= point[1] <= bounds[1]):
                error(field_name, f"[{index}] falls outside world bounds")
    extraction = layout.get("extraction")
    if (not isinstance(extraction, list) or len(extraction) != 2
            or not all(_is_finite_number(value) for value in extraction)):
        error("extraction", "expected finite [x, y]")
    elif not (0 <= extraction[0] <= bounds[0] and 0 <= extraction[1] <= bounds[1]):
        error("extraction", "position falls outside world bounds")
    rooms = layout.get("room_definitions")
    if not isinstance(rooms, list) or not rooms:
        error("room_definitions", "expected non-empty array")
        return
    room_ids = set()
    furniture_ids = set()
    for index, room in enumerate(rooms):
        if not isinstance(room, dict):
            error("room_definitions", f"[{index}] expected object")
            continue
        room_id = room.get("id")
        if not isinstance(room_id, str) or not ID_PATTERN.fullmatch(room_id) or room_id in room_ids:
            error(f"room_definitions[{index}].id", "expected unique lowercase_snake_case ID")
        else:
            room_ids.add(room_id)
        if not isinstance(room.get("name"), str) or not room["name"].strip():
            error(f"room_definitions[{index}].name", "expected non-empty string")
        furniture = room.get("furniture")
        if not isinstance(furniture, list) or not furniture:
            error(f"room_definitions[{index}].furniture", "expected non-empty array")
            continue
        for furniture_index, entry in enumerate(furniture):
            field_name = f"room_definitions[{index}].furniture[{furniture_index}]"
            if not isinstance(entry, dict):
                error(field_name, "expected object")
                continue
            furniture_id = entry.get("id")
            if not isinstance(furniture_id, str) or not ID_PATTERN.fullmatch(furniture_id):
                error(field_name + ".id", "expected lowercase_snake_case ID")
            elif furniture_id in furniture_ids:
                error(field_name + ".id", f"duplicate furniture ID {furniture_id}")
            else:
                furniture_ids.add(furniture_id)
            position = entry.get("position")
            if (not isinstance(position, list) or len(position) != 2
                    or not all(_is_finite_number(value) for value in position)):
                error(field_name + ".position", "expected finite [x, y]")
            loot_id = entry.get("loot_profile_id")
            if not isinstance(loot_id, str) or loot_id not in result.definitions["loot"]:
                error(field_name + ".loot_profile_id", f"unknown loot profile {loot_id}")


def run_cli(command: str) -> int:
    parser = argparse.ArgumentParser(description={
        "validate_json": "Recursively check JSON syntax in the data directory.",
        "validate_ids": "Validate definition IDs and their complete schemas.",
        "validate_references": "Validate material references and their prerequisite schemas/IDs.",
        "content_report": "Report counts only after complete content validation.",
    }[command])
    parser.add_argument("--data-root", type=Path, default=DEFAULT_DATA_ROOT,
        help="Data root containing core/, materials/, items/, loot/, consumables/, creatures/, weapons/ and medical/.")
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
        loot = result.definitions["loot"]
        consumables = result.definitions["consumable"]
        creatures = result.definitions["creature"]
        weapons = result.definitions["weapon"]
        medical = result.definitions["medical"]
        loot_entries = sum(len(group["entries"]) for group in loot.values())
        print(f"Materials: {len(materials)}\nItems: {len(items)}\nLoot Groups: {len(loot)}\nLoot Entries: {loot_entries}\nConsumables: {len(consumables)}\nCreatures: {len(creatures)}\nWeapons: {len(weapons)}\nMedical: {len(medical)}")
        if command == "content_report":
            print("Item Categories:")
            for category, count in sorted(Counter(item["category"] for item in items.values()).items()):
                print(f"{category}: {count}")
            print(f"Total Definitions: {len(materials) + len(items) + len(loot) + len(consumables) + len(creatures) + len(weapons) + len(medical)}")
        else:
            print("Schema / IDs / References: 0 errors")
    print("PASS")
    return 0
