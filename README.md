# Reincarnated as a Devourer

A survivors-like action roguelite built in Godot 4. You have 20 days to grow strong
enough to face the Demon King, and you grow by **devouring** what you kill, at the
cost of your own life.

It started as a turn-based terminal RPG I wrote in Python for CMSC 12, and is being rebuilt
as a real-time game.

> **Status:** prototype (Milestone 5 of 6 done). CC0 pixel art (Ninja Adventure) and sound;
> story and endings come next.

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

Weapons attack automatically. Collect XP gems to level up and choose from three upgrades,
each showing exactly what it changes: the **Blade**, **Goddess Light** and **Aegis**
weapons, or the **Guard**, **Treads**, **Stamina**, **Fury** (attack speed), **Magnet
Charm** (pickup range) and **Vigor** (HP regen) passives. Tier names come from the original
game's shop.

Every 30 seconds a **treasure chest** appears nearby; a gold arrow at the screen edge points
to it. Walk into it for a random reward: the original game's Common and High Potions or
Flask of Rejuvenation, a gold pouch, a bomb that blasts everything nearby, a Flask of
Attraction that pulls in all XP, Goddess's Fervor (weapons 50% faster for 15 s), or a rare
Goddess's Blessing (free level-up). Brighter **golden chests** hold two rewards. From Day 3
some chests are **Mimics**: they bite back, and killing one drops a golden chest.

Every monster fights its own way, and every attack is telegraphed:

| Monster | Behavior |
|---|---|
| Dreadling | Swarms: each one approaches from its own angle, so the pack surrounds you |
| Vexclaw | Hunts: closes in, crouches with a red aim line, then pounces where you're heading |
| Plaguewing | Spits: creeps in slowly, lobbing plague globs that leave poison puddles |
| Mimic | Pounces like a Vexclaw |

Spawning comes in waves that build up and then ease off, new monsters appear mostly
ahead of where you're running, and from Day 3 announced events strike: an encircling ring
of Dreadlings, a Vexclaw pack from one side, and later a plague tide.

Monsters grow tougher every day, so you need to keep growing too. Devouring an essence
also heals 25% of your max HP.

Every 30 seconds a gold-ringed **elite** appears. Kill it and it leaves an essence: stand
on it and hold **E** to Devour. You're rooted while you channel. Each essence boosts a stat
(Dreadling: speed, Vexclaw: might, Plaguewing: defense) and permanently costs max HP for
the run, using the original game's formula. Devour 3 Vexclaw essences with a maxed Blade
and it evolves into **Vexclaw Rend**.

On **Day 20** the horde scatters and the Demon King descends for a duel. He alternates a
red slam marked on the ground under you with a ring of dark orbs (watch for the purple
glow), and summons a few minions now and then. Below half HP he enrages: faster, wider
slams and double rings. Kill him to win the run.

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
tools/       Dev tools, not shipped: headless balance sim, art importer
assets/      Art and audio (see CREDITS.md for sources and licenses)
docs/        Design documents
```

**The world** is generated in 512 px chunks around you from a per-run seed
(`scripts/world/chunk_world.gd`), so every run's map is different and walking back finds
things where you left them. It's a forest of trees, stumps, bushes and flowers until
Day 10, then crumbles into ruins of dead trees and boulders, and on Day 20 a temple arena of
dark stone, ringed by pillars with four openings, rises around you for the Demon King.
Trees, rocks and pillars block movement; monsters slide around them.

**Swapping art:** all art comes from the Ninja Adventure pack through
`tools/import_ninja.py`, which copies the sheets and writes a `sprite_frames.tres` per
character and effect. To give something different art, change its entry in the tables
at the top and re-run:

```
python tools/import_ninja.py "path/to/Ninja Adventure - Asset Pack"
```

Each enemy's `.tres` points at its `sprite_frames.tres` and has a `sprite_scale`; clear
`sprite_frames` and it falls back to a colored circle. Terrain tiles and props are listed
in tables at the top of `chunk_world.gd`. Hitboxes are sized from `radius`,
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
| `kite` (never Devours) | wins about half or more of runs; boss fights 45-75 s |
| `devour` (Devours when safe, keeps max HP above 80) | wins about 40%; its lower max HP makes the boss slam dangerous |
| `greedy` (Devours everything) | usually dies before Day 20, at or near the 10 max-HP floor |

Each run also prints the damage the bot took by source (e.g. `plague 320, Vexclaw pounce
45`), which is how the plague puddles were caught being too strong.

Devour should pay off when used carefully and kill you when used greedily. A full run
earns about 13-15k gold (dying on Day 10: about 1.3k); mastering every Sanctuary training
costs about 40k, so roughly three full runs.

## Credits

See [CREDITS.md](CREDITS.md).
