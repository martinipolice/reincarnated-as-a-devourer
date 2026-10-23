"""Import sprites from 0x72's 16x16 DungeonTileset II (CC0) into the project.

Copies the animation frames this game uses into assets/ and writes a Godot
SpriteFrames .tres for each character, plus a tiled floor texture. Re-run it
after changing ROLES to swap a monster's art; the .tres paths stay the same,
so the enemy data files don't need editing.

Usage (from the project folder):
    python tools/import_0x72.py <path to extracted 0x72_DungeonTilesetII_v1.7>

Download: https://0x72.itch.io/dungeontileset-ii
"""

import random
import shutil
import sys
from pathlib import Path

from PIL import Image

PROJECT = Path(__file__).resolve().parent.parent

# role -> (assets subfolder, {animation: (frame prefix, fps)})
ROLES = {
    "player": ("characters/player", {
        "idle": ("knight_m_idle_anim", 6),
        "run": ("knight_m_run_anim", 10),
        "hit": ("knight_m_hit_anim", 6),  # one frame, held ~0.17 s
    }),
    "dreadling": ("enemies/dreadling", {"run": ("imp_run_anim", 10)}),
    "vexclaw": ("enemies/vexclaw", {"run": ("chort_run_anim", 10)}),
    "plaguewing": ("enemies/plaguewing", {"run": ("swampy_anim", 8)}),
    "demon_king": ("enemies/demon_king", {"run": ("big_demon_run_anim", 8)}),
    "goddess": ("characters/goddess", {"idle": ("angel_idle_anim", 6)}),
}
# assets subfolder -> single-frame sprites copied as-is
STATIC = {
    "weapons": ["weapon_golden_sword", "weapon_arrow"],  # Aegis blades, Goddess Light bolts
}
FLOOR_VARIANTS = [f"floor_{i}" for i in range(1, 9)]
# floor_1 is the plain tile; the rest are cracks and details, so use them sparingly.
FLOOR_WEIGHTS = [88] + [12 / 7] * 7
FLOOR_TILES = 16  # the generated floor texture is 16x16 tiles


def frames_for(src: Path, prefix: str) -> list[Path]:
    frames = sorted(src.glob(f"{prefix}_f*.png"), key=lambda p: int(p.stem.rsplit("_f", 1)[1]))
    if not frames:
        sys.exit(f"No frames found for {prefix} in {src}")
    return frames


def write_sprite_frames(folder: Path, res_folder: str, animations: dict) -> None:
    ext_lines = []
    anim_blocks = []
    next_id = 1
    for name, (frames, fps) in animations.items():
        refs = []
        for frame in frames:
            ext_lines.append(
                f'[ext_resource type="Texture2D" path="res://assets/{res_folder}/{frame.name}" id="{next_id}"]')
            refs.append(f'{{"duration": 1.0, "texture": ExtResource("{next_id}")}}')
            next_id += 1
        loop = "false" if name == "hit" else "true"
        anim_blocks.append(
            '{\n"frames": [' + ", ".join(refs) + f'],\n"loop": {loop},\n"name": &"{name}",\n"speed": {float(fps)}\n}}')
    text = ('[gd_resource type="SpriteFrames" format=3]\n\n' + "\n".join(ext_lines)
            + "\n\n[resource]\nanimations = [" + ", ".join(anim_blocks) + "]\n")
    (folder / "sprite_frames.tres").write_text(text, newline="\n")


def make_floor(src: Path) -> None:
    rng = random.Random(72)
    tiles = [Image.open(src / f"{name}.png").convert("RGBA") for name in FLOOR_VARIANTS]
    floor = Image.new("RGBA", (16 * FLOOR_TILES, 16 * FLOOR_TILES))
    for y in range(FLOOR_TILES):
        for x in range(FLOOR_TILES):
            floor.paste(rng.choices(tiles, FLOOR_WEIGHTS)[0], (x * 16, y * 16))
    out = PROJECT / "assets" / "environment"
    out.mkdir(parents=True, exist_ok=True)
    floor.save(out / "floor.png")


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    pack = Path(sys.argv[1])
    src = pack / "frames"
    for folder_name, animations in ROLES.values():
        folder = PROJECT / "assets" / folder_name
        folder.mkdir(parents=True, exist_ok=True)
        resolved = {}
        for anim, (prefix, fps) in animations.items():
            frames = frames_for(src, prefix)
            for frame in frames:
                shutil.copy2(frame, folder / frame.name)
            resolved[anim] = (frames, fps)
        write_sprite_frames(folder, folder_name, resolved)
        print(f"assets/{folder_name}: {sum(len(f) for f, _ in resolved.values())} frames")
    for folder_name, names in STATIC.items():
        folder = PROJECT / "assets" / folder_name
        folder.mkdir(parents=True, exist_ok=True)
        for name in names:
            shutil.copy2(src / f"{name}.png", folder / f"{name}.png")
        print(f"assets/{folder_name}: {len(names)} sprites")
    make_floor(src)
    print("assets/environment/floor.png")


if __name__ == "__main__":
    main()
