#!/usr/bin/env python3
"""Mirror specific SCML animations horizontally.

For each target animation, this script transforms:
- x / scale_x
- abs_x / abs_scale_x
- angle / abs_angle (mirrored angle)

Examples:
    python mirror_scml_animation.py mon3tr_weapon.scml f_idle_down
    python mirror_scml_animation.py mon3tr_weapon.scml f_idle_down f_attack --backup
    python mirror_scml_animation.py mon3tr_weapon.scml f_idle_down --dry-run
"""

from __future__ import annotations

import argparse
import shutil
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

# SCML commonly stores numeric values as decimal strings. We keep compact output:
# integers stay as integers, other values use up to 6 decimal places.
_DECIMALS = 6


def _format_number(value: float) -> str:
    if abs(value) < 1e-12:
        value = 0.0
    if value.is_integer():
        return str(int(value))
    return f"{value:.{_DECIMALS}f}".rstrip("0").rstrip(".")


def _negate_attr(node: ET.Element, attr_name: str) -> bool:
    original = node.get(attr_name)
    if original is None:
        return False

    try:
        number = float(original)
    except ValueError:
        return False

    node.set(attr_name, _format_number(-number))
    return True


def _mirror_angle_attr(node: ET.Element, attr_name: str) -> bool:
    original = node.get(attr_name)
    if original is None:
        return False

    try:
        number = float(original)
    except ValueError:
        return False

    mirrored = (-number) % 360.0
    node.set(attr_name, _format_number(mirrored))
    return True


def mirror_animation(scml_path: Path, animation_names: set[str], make_backup: bool, dry_run: bool) -> tuple[int, list[str]]:
    tree = ET.parse(scml_path)
    root = tree.getroot()

    changed_count = 0
    changed_animations: list[str] = []

    # SCML layout: spriter_data/entity/animation
    for entity in root.findall("entity"):
        for animation in entity.findall("animation"):
            name = animation.get("name", "")
            if name not in animation_names:
                continue

            local_changes = 0
            for node in animation.iter():
                for attr_name in ("x", "scale_x", "abs_x", "abs_scale_x"):
                    if _negate_attr(node, attr_name):
                        changed_count += 1
                        local_changes += 1
                for attr_name in ("angle", "abs_angle"):
                    if _mirror_angle_attr(node, attr_name):
                        changed_count += 1
                        local_changes += 1

            if local_changes > 0:
                changed_animations.append(name)

    if changed_count == 0:
        return 0, changed_animations

    if dry_run:
        return changed_count, changed_animations

    if make_backup:
        backup_path = scml_path.with_suffix(scml_path.suffix + ".bak")
        shutil.copy2(scml_path, backup_path)

    tree.write(scml_path, encoding="utf-8", xml_declaration=True)
    return changed_count, changed_animations


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Mirror selected SCML animations on X axis.")
    parser.add_argument("scml", type=Path, help="Path to SCML file.")
    parser.add_argument("animations", nargs="+", help="One or more animation names to mirror.")
    parser.add_argument("--backup", action="store_true", help="Create a .bak backup before writing.")
    parser.add_argument("--dry-run", action="store_true", help="Only report changes without writing file.")
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    scml_path: Path = args.scml
    if not scml_path.exists():
        print(f"ERROR: SCML file not found: {scml_path}", file=sys.stderr)
        return 1

    if scml_path.suffix.lower() != ".scml":
        print(f"WARNING: file extension is not .scml: {scml_path}")

    target_names = set(args.animations)
    changed_count, changed_animations = mirror_animation(
        scml_path=scml_path,
        animation_names=target_names,
        make_backup=args.backup,
        dry_run=args.dry_run,
    )

    if not changed_animations:
        print("No matching animation changed. Check animation names.")
        return 0

    changed_animations_sorted = sorted(set(changed_animations))
    print(f"Changed attributes: {changed_count}")
    print("Changed animations: " + ", ".join(changed_animations_sorted))
    if args.dry_run:
        print("Dry-run mode: file was not modified.")
    elif args.backup:
        print("Backup created with .bak suffix.")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
