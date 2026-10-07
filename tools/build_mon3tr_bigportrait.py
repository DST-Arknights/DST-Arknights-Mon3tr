"""Prepare aligned portrait PNGs and SCML; packaging uses an external compiler.

Painter-editable 490x654 character PNGs are copied without resizing.
Padding, scale and placement are stored in SCML for direct frame replacement.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import shutil
import xml.etree.ElementTree as ET

from PIL import Image

BANK = "mon3tr_bigportrait"
DEFAULT_ANIMATION = "idle_winter_forest"
PROJECT = Path(__file__).resolve().parents[1]
SOURCE = PROJECT / "animSource" / BANK
OLD_SCENE_SIZE = (490, 655)
OLD_CHARACTER_SCALE = 0.923
RAW_CHARACTER_SIZE = (490, 654)
SCENES = (
    {"name": "winter_forest", "label": "冬季雪林", "animation": DEFAULT_ANIMATION, "file": "background_0.png"},
    {"name": "pine_campfire", "label": "松林营火", "animation": "idle_pine_campfire", "file": "background_1.png"},
    {"name": "autumn_birchnut", "label": "秋日桦林", "animation": "idle_autumn_birchnut", "file": "background_2.png"},
    {"name": "cave_glow", "label": "洞穴荧光", "animation": "idle_cave_glow", "file": "background_3.png"},
)


def source_timing() -> dict | None:
    path = SOURCE / (BANK + ".scml")
    if not path.exists():
        return None
    animation = ET.parse(path).find(f"entity/animation[@name='{DEFAULT_ANIMATION}']")
    if animation is None:
        return None
    return {"length": int(animation.get("length")), "interval": int(animation.get("interval", "42")),
            "times": [int(key.get("time", "0")) for key in animation.findall("mainline/key")]}


def template_layout(template: Path) -> dict:
    with Image.open(template) as image:
        canvas = image.size
        alpha = image.convert("RGBA").getchannel("A")
        bounds = alpha.point(lambda value: 255 if value >= 128 else 0).getbbox()
        faint_bounds = alpha.getbbox()
    if bounds is None:
        raise ValueError("The base portrait has no visible background.")
    top, bottom = bounds[1], bounds[3]
    # Apply the same scene scale in both axes; the full canvas keeps its padding.
    scene_scale = (bottom - top) / OLD_SCENE_SIZE[1]
    target_size = (round(OLD_SCENE_SIZE[0] * scene_scale), bottom - top)
    target_left = (canvas[0] - target_size[0]) // 2
    character_scale = OLD_CHARACTER_SCALE * scene_scale
    precise_display_size = tuple(value * character_scale for value in RAW_CHARACTER_SIZE)
    display_size = tuple(round(value) for value in precise_display_size)
    left = (canvas[0] - display_size[0]) / 2
    position = (0, canvas[1] / 2 - top - precise_display_size[1] / 2)
    return {"canvas": canvas, "alpha_threshold": 128, "template_main_bounds": bounds,
            "template_faint_bounds": faint_bounds, "target_rect": (target_left, top, *target_size),
            "padding_top": top, "padding_bottom": canvas[1] - bottom,
            "scene_scale": scene_scale, "scaling": "uniform",
            "character_display_size": display_size, "character_top_left": (left, top),
            "character_display_size_exact": precise_display_size,
            "character_scale": (character_scale, character_scale),
            "character_scml_position": position}


def prepare_backgrounds(paths: list[Path], layout: dict) -> None:
    for scene, original in zip(SCENES, (paths[2], paths[0], paths[1], paths[3])):
        with Image.open(original) as image:
            fitted = image.convert("RGBA").resize(tuple(layout["target_rect"][2:]), Image.Resampling.LANCZOS)
        canvas = Image.new("RGBA", tuple(layout["canvas"]), (0, 0, 0, 0))
        canvas.paste(fitted, tuple(layout["target_rect"][:2]))
        canvas.save(SOURCE / "background" / scene["file"])


def prepare_frames(directory: Path, previous: dict | None, manifest: dict) -> list[Path]:
    frames = sorted(directory.glob("mon3tr_*.png"))
    omitted = manifest.get("duplicate_endpoint_omitted", "mon3tr_0092.png")
    if frames and frames[-1].name == omitted and previous and len(frames) == len(previous["times"]) + 1:
        frames.pop()
    for frame in frames:
        destination = SOURCE / "character" / frame.name
        if frame.resolve() != destination.resolve():
            shutil.copy2(frame, destination)
    return [SOURCE / "character" / frame.name for frame in frames]


def write_scml(frames: list[Path], timing: dict, layout: dict) -> Path:
    canvas = tuple(layout["canvas"])
    root = ET.Element("spriter_data", {"scml_version": "1.0", "generator": "Mon3tr aligned portrait sources", "generator_version": "2"})
    backgrounds = ET.SubElement(root, "folder", {"id": "0", "name": "background"})
    for index, scene in enumerate(SCENES):
        ET.SubElement(backgrounds, "file", {"id": str(index), "name": "background/" + scene["file"],
            "width": str(canvas[0]), "height": str(canvas[1]), "pivot_x": "0.5", "pivot_y": "0.5"})
    characters = ET.SubElement(root, "folder", {"id": "1", "name": "character"})
    for index, frame in enumerate(frames):
        ET.SubElement(characters, "file", {"id": str(index), "name": frame.relative_to(SOURCE).as_posix(),
            "width": str(RAW_CHARACTER_SIZE[0]), "height": str(RAW_CHARACTER_SIZE[1]), "pivot_x": "0.5", "pivot_y": "0.5"})
    entity = ET.SubElement(root, "entity", {"id": "0", "name": BANK})
    x, y = layout["character_scml_position"]
    sx, sy = layout["character_scale"]
    for scene_id, scene in enumerate(SCENES):
        animation = ET.SubElement(entity, "animation", {"id": str(scene_id), "name": scene["animation"],
            "length": str(timing["length"]), "interval": str(timing["interval"]), "looping": "true"})
        mainline = ET.SubElement(animation, "mainline")
        bg = ET.SubElement(animation, "timeline", {"id": "0", "name": "background", "object_type": "sprite"})
        key = ET.SubElement(bg, "key", {"id": "0", "time": "0", "spin": "0", "curve_type": "instant"})
        ET.SubElement(key, "object", {"folder": "0", "file": str(scene_id), "x": "0", "y": "0", "angle": "0"})
        character = ET.SubElement(animation, "timeline", {"id": "1", "name": "character", "object_type": "sprite"})
        for index, time in enumerate(timing["times"]):
            key = ET.SubElement(mainline, "key", {"id": str(index), "time": str(time)})
            ET.SubElement(key, "object_ref", {"id": "0", "timeline": "0", "key": "0", "z_index": "0"})
            ET.SubElement(key, "object_ref", {"id": "1", "timeline": "1", "key": str(index), "z_index": "1"})
            key = ET.SubElement(character, "key", {"id": str(index), "time": str(time), "spin": "0", "curve_type": "instant"})
            ET.SubElement(key, "object", {"folder": "1", "file": str(index), "x": f"{x:.12g}", "y": f"{y:.12g}",
                "scale_x": f"{sx:.12g}", "scale_y": f"{sy:.12g}", "angle": "0"})
    output = SOURCE / (BANK + ".scml")
    ET.indent(root)
    ET.ElementTree(root).write(output, encoding="utf-8", xml_declaration=True)
    return output


def write_static_portraits(first_frame: Path, layout: dict) -> list[str]:
    with Image.open(first_frame) as character:
        fitted = character.convert("RGBA").resize(tuple(layout["character_display_size"]), Image.Resampling.LANCZOS)
    position = tuple(round(value) for value in layout["character_top_left"])
    outputs = []
    for scene in SCENES:
        with Image.open(SOURCE / "background" / scene["file"]) as background:
            portrait = background.convert("RGBA")
        portrait.alpha_composite(fitted, position)
        output = SOURCE / "static" / ("mon3tr_" + scene["name"] + ".png")
        portrait.save(output)
        outputs.append(output.relative_to(PROJECT).as_posix())
        if scene["animation"] == DEFAULT_ANIMATION:
            default = PROJECT / "imagesSource" / "bigportraits" / "mon3tr" / "mon3tr.png"
            default.parent.mkdir(parents=True, exist_ok=True)
            portrait.save(default)
    return outputs


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--template", type=Path, help="Capture the restored native background as the permanent alignment reference.")
    parser.add_argument("--backgrounds", nargs=4, type=Path, metavar="PNG", help="Original backgrounds in pine, autumn, winter, cave order.")
    parser.add_argument("--frames", type=Path, help="Import original 490x654 mon3tr_*.png files without resizing.")
    parser.add_argument("--fps", type=float, help="Optional retiming; otherwise retain the existing SCML timeline.")
    args = parser.parse_args()
    for folder in ("layout", "background", "character", "static"):
        (SOURCE / folder).mkdir(parents=True, exist_ok=True)
    manifest_path = SOURCE / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8")) if manifest_path.exists() else {}
    previous = source_timing()
    template = SOURCE / "layout" / "base_portrait.png"
    if args.template and args.template.resolve() != template.resolve():
        shutil.copy2(args.template, template)
    layout = template_layout(template)
    if args.backgrounds:
        prepare_backgrounds(args.backgrounds, layout)
        manifest["background_sources"] = [str(path.resolve()) for path in args.backgrounds]
    if args.frames:
        frames = prepare_frames(args.frames, previous, manifest)
        manifest["character_source"] = str(args.frames.resolve())
    else:
        frames = sorted((SOURCE / "character").glob("mon3tr_*.png"))
        omitted = manifest.get("duplicate_endpoint_omitted")
        if omitted:
            frames = [frame for frame in frames if frame.name != omitted]
    if not frames:
        raise ValueError("Import the 490x654 cutout sequence with --frames.")
    fps = args.fps if args.fps is not None else manifest.get("source_fps", 24)
    if args.fps is None and previous and len(previous["times"]) == len(frames):
        timing = previous
    else:
        if fps <= 0:
            raise ValueError("FPS must be positive.")
        timing = {"length": round(len(frames) * 1000 / fps), "interval": round(1000 / fps),
                  "times": [round(index * 1000 / fps) for index in range(len(frames))]}
    scml = write_scml(frames, timing, layout)
    static_outputs = write_static_portraits(frames[0], layout)
    for old_key in ("background_source", "compiled_bytes", "compiled_sha256", "compiler_fps",
                    "character_size", "character_top_left", "layers", "animation", "pivot"):
        manifest.pop(old_key, None)
    manifest.update({"purpose": "Aligned four-background portrait sources; replace cutouts and package with the advanced compiler.",
        "stage": "scml-only", "bank": BANK, "build": BANK, "asset": "anim/mon3tr_bigportrait.zip",
        "default_animation": DEFAULT_ANIMATION, "backgrounds": SCENES, "layout": layout,
        "canvas": layout["canvas"], "character_source_canvas": RAW_CHARACTER_SIZE,
        "character_frame_count": len(frames), "source_fps": fps, "scml_duration_ms": timing["length"],
        "scml": scml.relative_to(PROJECT).as_posix(), "static_outputs": static_outputs,
        "template_source": template.relative_to(PROJECT).as_posix(),
        "static_source": "imagesSource/bigportraits/mon3tr/mon3tr.png",
        "packaging": "User-supplied advanced compiler; no runtime resource regenerated by this tool."})
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"scml": str(scml), "canvas": layout["canvas"], "target_rect": layout["target_rect"],
        "padding_top": layout["padding_top"], "padding_bottom": layout["padding_bottom"],
        "character_display_size": layout["character_display_size"], "character_scml_position": layout["character_scml_position"],
        "character_frames": len(frames), "animations": [scene["animation"] for scene in SCENES], "duration_ms": timing["length"]}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()

