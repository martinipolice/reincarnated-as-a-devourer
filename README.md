# Reincarnated as a Devourer

A survivors-like action roguelite built in Godot 4. You have 20 days to grow strong
enough to face the Demon King, and you grow by **devouring** what you kill, at the
cost of your own life.

It started as a turn-based terminal RPG I wrote in Python for CMSC 12, and is being rebuilt
as a real-time game.

> **Status:** early prototype (Milestone 3 of 6 done). Placeholder shapes, no art yet.

## Play / run

1. Install [Godot 4.7+](https://godotengine.org/download) (standard build, not .NET).
2. In the Project Manager choose **Import**, then select this folder's `project.godot`.
3. Press **F5**.

| Action | Keys |
|---|---|
| Move | WASD / arrow keys |
| Pick a level-up | Click, 1-3, or arrows + Enter |
| Restart after a run | R |

Weapons attack automatically. Collect XP gems to level up and choose from three upgrades:
the **Blade**, **Goddess Light** and **Aegis** weapons, or the **Guard**, **Treads** and
**Stamina** passives. Their tier names come from the original game's shop.

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
- [ ] **M4** Devour (elites, Essences, evolution) and the Demon King boss
- [ ] **M5** Meta progression (Goddess's Sanctuary), save file, juice, free-asset art pass
- [ ] **M6** Lore beats, Day 20 dialogue, endings, itch.io web release

## Project layout

```
data/        Game content as .tres Resources (enemies, weapons, items). Tune here, not in code.
scenes/      main (run controller + HUD), player, enemy, XP gem, weapons/, ui/
scripts/     GDScript; data/ holds the Resource class definitions, weapons/ the Weapon subclasses
tools/       Dev tools, not shipped (headless balance sim)
assets/      Art and audio (see CREDITS.md for sources and licenses)
docs/        Design documents
```

**Swapping art:** every enemy's `sprite_frames` field in `data/enemies/*.tres` is empty, so
it draws a colored circle. Assign a `SpriteFrames` from an asset pack and the circle is
replaced. Hitboxes are sized from `radius`, not the sprite, so new art never changes
the balance.

## Balance testing

`tools/balance_sim.gd` plays a whole run headlessly with a bot, either standing still
(`afk`) or dodging and collecting gems (`kite`), and prints progress every other day:

```
godot --headless --fixed-fps 60 --path . -s res://tools/balance_sim.gd -- kite 1
```

Current targets: first level-up around 15 s, all upgrades maxed around Day 13-15, an
active bot dying between Day 12 and Day 20, and standing still lasting 20-40 s.

## Credits

See [CREDITS.md](CREDITS.md).
