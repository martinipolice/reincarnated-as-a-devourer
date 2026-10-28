"""Packs the sheets of everything that crowds the battlefield (the hero and
the monsters) into one atlas, and points their SpriteFrames at it.

Why: the run y-sorts hundreds of these sprites together. In separate sheets,
almost every neighbor uses a different texture, which breaks Godot's 2D
batching into ~1 draw call per sprite. Sharing one texture lets them batch.

Run from the project folder after tools/import_ninja.py (which calls it):
    python tools/pack_atlas.py
"""
import re
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
NINJA = ROOT / "assets" / "ninja"
ATLAS = NINJA / "battlefield_atlas.png"
# folder -> top-left of its sheet in the atlas (each sheet is at most 64x64)
LAYOUT = {
    "dreadling": (0, 0),
    "vexclaw": (64, 0),
    "plaguewing": (128, 0),
    "player": (192, 0),
    "mimic": (0, 64),
    "hexeye": (64, 64),
    "warden": (128, 64),
}
SIZE = (256, 128)


def main() -> None:
    atlas = Image.new("RGBA", SIZE, (0, 0, 0, 0))
    for folder, (x, y) in LAYOUT.items():
        sheet = Image.open(NINJA / folder / "sheet.png").convert("RGBA")
        assert sheet.width <= 64 and sheet.height <= 64, folder
        atlas.paste(sheet, (x, y))
    atlas.save(ATLAS)
    atlas_res = "res://" + ATLAS.relative_to(ROOT).as_posix()
    for folder, (dx, dy) in LAYOUT.items():
        tres = NINJA / folder / "sprite_frames.tres"
        text = tres.read_text(encoding="utf-8")
        text = re.sub(r'(\[ext_resource type="Texture2D" path=")[^"]+(")', rf"\g<1>{atlas_res}\g<2>", text, count=1)

        def shift(m: re.Match) -> str:
            x, y, w, h = (float(v) for v in m.groups())
            return f"Rect2({x + dx:g}, {y + dy:g}, {w:g}, {h:g})"

        text = re.sub(r"Rect2\(([\d.]+), ([\d.]+), ([\d.]+), ([\d.]+)\)", shift, text)
        tres.write_text(text, encoding="utf-8", newline="\n")
        print(f"{folder}: now in {ATLAS.name} at {dx},{dy}")


if __name__ == "__main__":
    main()
