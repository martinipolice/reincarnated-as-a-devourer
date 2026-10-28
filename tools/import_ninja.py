"""Import art from the Ninja Adventure asset pack (CC0) into the project.

Copies just the sheets this game uses into assets/ninja/ and writes a Godot
SpriteFrames .tres for each animated thing, slicing the pack's sheets with
AtlasTextures (no per-frame files). Re-run after editing the tables below to
swap any sprite; the .tres paths stay the same, so game data doesn't change.

Usage (from the project folder):
    python tools/import_ninja.py "<path to extracted 'Ninja Adventure - Asset Pack'>"

Download: https://pixel-boy.itch.io/ninja-adventure-asset-pack
"""

import shutil
import sys
from pathlib import Path

PROJECT = Path(__file__).resolve().parent.parent
OUT = PROJECT / "assets" / "ninja"
DIRS = ["down", "up", "left", "right"]  # column order in the pack's 4x4 sheets

# Actors on the pack's 64x64 "4 directions x 4 frames" sheets.
# name -> (sheet path in pack, extra animations)
DIRECTIONAL = {
    "player": "Actor/Character/Knight/SeparateAnim/Walk.png",
    "goddess": "Actor/Character/Princess/SeparateAnim/Walk.png",
    "dreadling": "Actor/Monster/Spirit/SpriteSheet.png",
    "vexclaw": "Actor/Monster/Beast/Beast.png",
    "plaguewing": "Actor/Monster/GreenOctopus/SpriteSheet.png",
    "hexeye": "Actor/Monster/Eye/Eye.png",
    "warden": "Actor/Monster/Cyclope/SpriteSheet.png",
    "acolyte": "Actor/Monster/Skull/SpriteSheet.png",
    "burrower": "Actor/Monster/Mole/Mole.png",
}
# Single strips: name -> (sheet, frame w, frame h, frames, fps, animation, loop)
STRIPS = {
    "demon_king": ("Actor/Boss/DemonCyclop/Walk.png", 50, 50, 6, 8, "run", True),
    "ruin_guardian": ("Actor/Boss/GiantRedSamurai/Walk.png", 96, 48, 6, 8, "run", True),
    "hollow_spirit": ("Actor/Boss/GiantSpirit/Idle.png", 50, 50, 5, 8, "run", True),
    "mimic": ("Items/Treasure/LittleTreasureChest.png", 16, 16, 2, 6, "run", True),
    "chest": ("Items/Treasure/BigTreasureChest.png", 16, 14, 2, 8, "open", False),
    "swoosh": ("FX/Slash/SpriteSheetCircular.png", 54, 55, 7, 28, "play", False),
    "smoke": ("FX/Smoke/Smoke/SpriteSheet.png", 32, 32, 6, 18, "play", False),
    "explosion": ("FX/Elemental/Explosion/SpriteSheet.png", 40, 40, 9, 18, "play", False),
    "spark": ("FX/Magic/Circle/SpriteSheetSpark.png", 32, 32, 6, 18, "play", False),
    "wisp": ("FX/Magic/Spirit/SpriteSheet.png", 32, 32, 5, 10, "play", True),
}
# Single images: output name -> path in pack
STATIC = {
    # level-up icons (24x24 framed skill icons)
    "icon_blade": "Ui/Skill Icon/Items & Weapon/Guard.png",
    "icon_light": "Ui/Skill Icon/Items & Weapon/Arrow.png",
    "icon_aegis": "Ui/Skill Icon/Items & Weapon/Kunai.png",
    "icon_guard": "Ui/Skill Icon/Items & Weapon/Armor.png",
    "icon_treads": "Ui/Skill Icon/Items & Weapon/Boot.png",
    "icon_stamina": "Ui/Skill Icon/Items & Weapon/Helmet.png",
    "icon_fury": "Ui/Skill Icon/Items & Weapon/Ring.png",
    "icon_magnet": "Ui/Skill Icon/Items & Weapon/Hook.png",
    "icon_vigor": "Ui/Skill Icon/Items & Weapon/Amulet.png",
    "icon_scroll": "Ui/Skill Icon/Items & Weapon/Scroll.png",
    "icon_maw": "Ui/Skill Icon/Spell/Death.png",
    "icon_chains": "Ui/Skill Icon/Spell/Fireball.png",
    "icon_covenant": "Ui/Skill Icon/Spell/BookDarkness.png",
    "icon_bell": "Ui/Skill Icon/Spell/OrbDarkness.png",
    "icon_hunger": "Ui/Skill Icon/Spell/Necromancy.png",
    # loot and pickups
    "common_potion": "Items/Potion/LifePot.png",
    "high_potion": "Items/Potion/Medipack.png",
    "rejuvenation": "Items/Potion/Heart.png",
    "attraction": "Items/Potion/WaterPot.png",
    "blessing": "Items/Potion/MilkPot.png",
    "fervor": "Items/Scroll/ScrollFire.png",
    "gold": "Items/Treasure/GoldCoin.png",
    "bomb": "Items/Projectile/Bomb.png",
    "gem_small": "Items/Resource/GemYellow.png",
    "gem_medium": "Items/Resource/GemGreen.png",
    "gem_large": "Items/Resource/GemRed.png",
    # weapons
    "sword": "Items/Weapons/Sword/Sprite.png",
    "katana": "Items/Weapons/Katana/Sprite.png",
    "arrow": "Items/Weapons/Bow/Arrow.png",
    # terrain sheets, used whole by scripts/world/chunk_world.gd
    "tiles_floor": "Backgrounds/Tilesets/TilesetFloor.png",
    "tiles_nature": "Backgrounds/Tilesets/TilesetNature.png",
    "tiles_interior_floor": "Backgrounds/Tilesets/Interior/TilesetInteriorFloor.png",
}


def res(path: Path) -> str:
    return "res://" + path.relative_to(PROJECT).as_posix()


def write_frames(target: Path, sheet: Path, animations: list) -> None:
    """animations: [(name, [(x, y, w, h), ...], fps, loop)]"""
    subs, anims, n = [], [], 0
    for name, rects, fps, loop in animations:
        refs = []
        for x, y, w, h in rects:
            n += 1
            subs.append(f'[sub_resource type="AtlasTexture" id="f{n}"]\natlas = ExtResource("1")\n'
                        f'region = Rect2({x}, {y}, {w}, {h})\n')
            refs.append(f'{{"duration": 1.0, "texture": SubResource("f{n}")}}')
        anims.append('{\n"frames": [' + ", ".join(refs) + f'],\n"loop": {"true" if loop else "false"},\n'
                     f'"name": &"{name}",\n"speed": {float(fps)}\n}}')
    text = (f'[gd_resource type="SpriteFrames" format=3]\n\n'
            f'[ext_resource type="Texture2D" path="{res(sheet)}" id="1"]\n\n'
            + "\n".join(subs) + "\n[resource]\nanimations = [" + ", ".join(anims) + "]\n")
    target.write_text(text, encoding="utf-8", newline="\n")


def copy(pack: Path, rel: str, dest: Path) -> Path:
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(pack / rel, dest)
    return dest


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    pack = Path(sys.argv[1])
    for name, rel in DIRECTIONAL.items():
        folder = OUT / name
        sheet = copy(pack, rel, folder / "sheet.png")
        anims = []
        for col, facing in enumerate(DIRS):
            walk = [(col * 16, row * 16, 16, 16) for row in range(4)]
            anims.append((f"run_{facing}", walk, 8, True))
            anims.append((f"idle_{facing}", walk[:1], 1, True))
        anims.append(("run", [(0, row * 16, 16, 16) for row in range(4)], 8, True))
        write_frames(folder / "sprite_frames.tres", sheet, anims)
        print(f"assets/ninja/{name}: 4 directions")
    for name, (rel, w, h, count, fps, anim, loop) in STRIPS.items():
        folder = OUT / name
        sheet = copy(pack, rel, folder / "sheet.png")
        write_frames(folder / "sprite_frames.tres", sheet,
                     [(anim, [(i * w, 0, w, h) for i in range(count)], fps, loop)])
        print(f"assets/ninja/{name}: {count} frames")
    for name, rel in STATIC.items():
        copy(pack, rel, OUT / "images" / f"{name}.png")
    print(f"assets/ninja/images: {len(STATIC)} images")
    copy(pack, "LICENSE.txt", OUT / "LICENSE.txt")
    # The hero and monsters share one texture so crowds batch (see pack_atlas.py).
    import pack_atlas
    pack_atlas.main()


if __name__ == "__main__":
    main()
