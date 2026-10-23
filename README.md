# Reincarnated as a Devourer

A survivors-like action roguelite built in Godot 4. You have 20 days to grow strong
enough to face the Demon King, and you grow by **devouring** what you kill, at the
cost of your own life.

It started as a turn-based terminal RPG I wrote in Python for CMSC 12, and is being rebuilt
as a real-time game.

> **Status:** early prototype (Milestone 4 of 6 done). Placeholder shapes, no art yet.

## Play / run

1. Install [Godot 4.7+](https://godotengine.org/download) (standard build, not .NET).
2. In the Project Manager choose **Import**, then select this folder's `project.godot`.
3. Press **F5**.

| Action | Keys |
|---|---|
| Move | WASD / arrow keys |
| Devour (hold on an essence) | E / Space |
| Pick a level-up | Click, 1-3, or arrows + Enter |
| Restart after a run | R |

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

`tools/balance_sim.gd` plays a whole run headlessly with a bot, standing still (`afk`),
dodging and collecting gems (`kite`), or also Devouring every elite (`devour`). It prints
progress every other day and the boss fight's result:

```
godot --headless --fixed-fps 60 --path . -s res://tools/balance_sim.gd -- kite 1
```

Current targets (12 runs, seeds 1-4):

| Bot | Result |
|---|---|
| `afk` | dies in 20-40 s |
| `kite` (never Devours) | usually dies Day 17-20; beats the boss about 1 in 4, in ~100 s |
| `devour` (Devours when safe) | beats the boss most runs, in 30-60 s |
| `greedy` (Devours everything) | hits the 10 max-HP floor and dies |

Devour should pay off when used carefully and kill you when used greedily.

## Credits

See [CREDITS.md](CREDITS.md).
