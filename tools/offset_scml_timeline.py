#!/usr/bin/env python3
"""
Offset SCML object y values under timeline/key by a fixed value.

What it updates:
1) Only <object ... y="..." /> elements inside <timeline> -> <key>
2) y becomes y + offset

This keeps formatting mostly intact by using regex replacements on raw text.
"""

from __future__ import annotations

import argparse
from decimal import Decimal, InvalidOperation
import pathlib
import re
import sys

Y_ATTR_RE = re.compile(r'(\by=")(-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)(")')


def _format_like_original(original: str, new_value: Decimal) -> str:
    if "." in original and "e" not in original.lower():
        decimals = len(original.split(".", 1)[1])
        quantum = Decimal(1).scaleb(-decimals)
        rounded = new_value.quantize(quantum)
        s = f"{rounded:f}"
        if "." not in s:
            s += "."
        frac_len = len(s.split(".", 1)[1])
        if frac_len < decimals:
            s += "0" * (decimals - frac_len)
        return s

    if new_value == new_value.to_integral_value():
        return str(int(new_value))

    s = f"{new_value:f}"
    if "." in s:
        s = s.rstrip("0").rstrip(".")
    return s


def offset_object_y_in_timelines(text: str, offset: Decimal) -> tuple[str, int]:
    in_timeline = False
    in_key = False
    updated = 0
    out_lines: list[str] = []

    for line in text.splitlines(keepends=True):
        if "<timeline" in line:
            in_timeline = True

        if in_timeline and "<key" in line:
            in_key = True

        if in_timeline and in_key and "<object " in line:
            def repl_y(m: re.Match[str]) -> str:
                nonlocal updated
                prefix, value, suffix = m.groups()
                new_value = Decimal(value) + offset
                updated += 1
                return f"{prefix}{_format_like_original(value, new_value)}{suffix}"

            line = Y_ATTR_RE.sub(repl_y, line)

        if in_timeline and "</key>" in line:
            in_key = False

        if "</timeline>" in line:
            in_timeline = False
            in_key = False

        out_lines.append(line)

    return "".join(out_lines), updated


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Apply an offset to SCML timeline/key/object y values."
    )
    parser.add_argument("input", type=pathlib.Path, help="Input .scml file")
    parser.add_argument(
        "offset",
        help="Offset to add to y (supports integer or decimal, can be negative)",
    )
    parser.add_argument(
        "-o",
        "--output",
        type=pathlib.Path,
        help="Output file path (default: overwrite input when --in-place is set)",
    )
    parser.add_argument(
        "-i",
        "--in-place",
        action="store_true",
        help="Overwrite the input file",
    )
    parser.add_argument(
        "--encoding",
        default="utf-8",
        help="File encoding (default: utf-8)",
    )

    args = parser.parse_args()

    if not args.input.exists():
        print(f"Input file not found: {args.input}", file=sys.stderr)
        return 2

    if not args.in_place and args.output is None:
        print("Specify either --in-place or --output.", file=sys.stderr)
        return 2

    try:
        offset = Decimal(args.offset)
    except InvalidOperation:
        print(f"Invalid offset value: {args.offset}", file=sys.stderr)
        return 2

    source_text = args.input.read_text(encoding=args.encoding)
    new_text, updated = offset_object_y_in_timelines(source_text, offset)

    out_path = args.input if args.in_place else args.output
    assert out_path is not None
    out_path.write_text(new_text, encoding=args.encoding)

    print(
        "Done. "
        f"Updated object y attributes: {updated}, "
        f"offset: {offset}, "
        f"output: {out_path}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
