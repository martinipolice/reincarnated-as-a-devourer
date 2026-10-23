# Reincarnated as a Devourer

A survivors-like action roguelite built in Godot 4. You have 20 days to grow strong
enough to face the Demon King, and you grow by **devouring** what you kill, at the
cost of your own life.

It started as a turn-based terminal RPG I wrote in Python for CMSC 12, and is being rebuilt
as a real-time game.

> **Status:** prototype (Milestone 5 of 6 done). CC0 pixel art and sound; story and endings come next.

## Play / run

1. Install [Godot 4.7+](https://godotengine.org/download) (standard build, not .NET).
2. In the Project Manager choose **Import**, then select this folder's `project.godot`.
3. Press **F5**.

| Action | Keys |
|---|---|
| Move | WASD / arrow keys |
| Devour (hold on an essence) | E / Space |
| Pick a level-up | Click, 1-3, or arrows + Enter |
| Play again after a run | R |

**Testing shortcuts** (only when running from the editor, never in an exported build):

| Key | Does |
|---|---|
| F1 | Spawn an elite near you |
| F2 | Level up now |
| F3 | Skip to Day 20 (the Demon King) |
| F4 | Full heal |

Weapons attack automatically. Collect XP gems to level up and choose from three upgrades:
the **Blade**, **Goddess Light** and **Aegis** weapons, or the **Guard**, **Treads** and
**Stamina** passives. Their tier names come from the original game's shop.

Every 30 seconds a gold-ringed **elite** appears. Kill it and it leaves an essence: stand
on it and hold **E** to Devour. You're rooted while you channel. Each essence boosts a stat
(Dreadling: speed, Vexclaw: might, Plaguewing: defense) and permanently costs max HP for
the run, using the original game's formula. Devour 3 Vexclaw essences with a maxed Blade
and it evolves into **Vexclaw Rend**.

On **Day 20** the Demon King descends. Every few seconds he marks the ground under you in
red and slams it for double damage, so keep moving. Kill him to win the run.

Gold you earn is banked when a run ends. Spend it at the **Goddess's Sanctuary** on
permanent training (Stamina, Strength, Resilience, Dexterity and Guts, from the original
game's Train menu) that applies to every future run. Progress is saved automatically to
`user://save.json` (on Windows: `%APPDATA%/Godot/app_userdata/Reincarnated as a Devourer`).

## Design in one paragraph

A run is 20 in-game days (30 seconds each in the MVP). Monsters from the original game,
Dreadling, Vexclaw and Plaguewing, swarm in stronger mixes as days pass. Elites can
be **Devoured**: a one-second channel that grants an Essence (which changes your build,
and three of a kind evolves a weapon) and permanently lowers your max HP for the run.
On Day 20 you face the Demon King, and what you say to him, and how much you've devoured,
decides the ending. Full pitch: [docs/DESIGN.md](docs/DESIGN.md).

## Roadmap

- [x] **M1** Project setup, data-driven enemies and items
- [x] **M2** Movement and threat: player, chasing enemies, contact damage, death, day-based spawn director
- [x] **M3** Fun check: XP gems, level-up with 3 choices, Goddess Light and Aegis, early balance pass
- [x] **M4** Devour (elites, Essences, evolution) and the Demon King boss
- [x] **M5** CC0 art and sound, juice (shake, hit stop, particles), Goddess's Sanctuary, versioned save file
- [ ] **M6** Lore beats, Day 20 dialogue, endings, itch.io web release

## Project layout

```
data/        Game content as .tres Resources (enemies, essences, weapons, items, training).
             Tune here, not in code.
scenes/      main (run controller + HUD), player, enemy, boss, XP gem, weapons/, ui/
scripts/     GDScript; autoload/ holds Game (juice, input) and Save, data/ the Resource classes
tools/       Dev tools, not shipped: headless balance sim, sprite importer
assets/      Art and audio (see CREDITS.md for sources and licenses)
docs/        Design documents
```

**Swapping art:** sprites come from 0x72's DungeonTileset II through
`tools/import_0x72.py`, which copies the frames and writes a `sprite_frames.tres` per
character. To give a monster different art, change its entry in `ROLES` and re-run:

```
python tools/import_0x72.py path/to/0x72_DungeonTilesetII_v1.7
```

Each enemy's `.tres` points at its `sprite_frames.tres` and has a `sprite_scale`; clear
`sprite_frames` and it falls back to a colored circle. Hitboxes are sized from `radius`,
not the sprite, so new art never changes the balance. Sounds are mapped by name in
`scripts/autoload/game.gd` (`SFX`).

## Balance testing

`tools/balance_sim.gd` plays a whole run headlessly with a bot, standing still (`afk`),
dodging and collecting gems (`kite`), or also Devouring (`devour` when safe, `greedy`
always). It prints progress every other day, the boss fight's result and gold earned. It
always starts from a fresh save and never writes yours:

```
godot --headless --fixed-fps 60 --path . -s res://tools/balance_sim.gd -- kite 1
```

Current targets (12 runs, seeds 1-4):

| Bot | Result |
|---|---|
| `afk` | dies in 20-40 s |
| `kite` (never Devours) | reaches Day 20 most runs; beats the boss some of the time, in 60-100 s |
| `devour` (Devours when safe) | beats the boss most runs, in 30-60 s |
| `greedy` (Devours everything) | hits the 10 max-HP floor and dies |

Devour should pay off when used carefully and kill you when used greedily. A full run
earns about 13-15k gold (dying on Day 10: about 1.3k); mastering every Sanctuary training
costs about 40k, so roughly three full runs.

## Credits

See [CREDITS.md](CREDITS.md).
