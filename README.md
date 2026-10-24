# Reincarnated as a Devourer

A survivors-like action game built in Godot 4. You were reincarnated once, and you get one
life: 20 days to grow strong enough to face the Demon King, growing by **devouring** what
you kill, at the cost of your own life.

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
| Drink the Goddess's Tears (heal) | Q |
| Pause: your build, how to play, settings | Esc / P |
| Pick a level-up | Click, 1-3, or arrows + Enter |
| New journey after the end | R |

**Testing shortcuts** (only when running from the editor, never in an exported build):

| Key | Does |
|---|---|
| F1 | Spawn an elite near you |
| F2 | Level up now |
| F3 | Skip to Day 20 (the Demon King) |
| F4 | Full heal |

Weapons attack automatically. Collect XP gems to level up and choose from three upgrades,
each showing exactly what it changes: the **Blade**, **Goddess Light**, **Aegis**,
**Devourer's Maw** (jaws that bite the nearest enemies and heal you on kills) and **Hellfire
Chains** (a burning lash where you face) weapons, or the **Guard**, **Treads**, **Stamina**, **Fury** (attack speed), **Magnet
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

### Style, traits and covenants

- **Style rank.** A Devil May Cry-style rank, D (Dull) to SSS (Soul Devourer), climbs as you
  kill and Devour, drains when you stop, and drops two ranks whenever you're hit. Higher
  ranks pay up to x1.6 gold and +25% XP, and push the music to full blast.
- **Four weapons at a time.** Of the five, you carry at most four, so each build chooses.
- **Elite traits.** From Day 5 (always from Day 10), elites can be **Swift**, **Armored**
  (half damage), **Splitting** (bursts into three) or **Vampiric** (heals when it hits you),
  named over their head. They pay double gold.
- **Covenants.** At each shrine the goddess offers two covenants; seal one, if you dare, and
  it lasts until her next shrine: **Blood** (enemies hit harder, much more gold), **the
  Horde** (more enemies, more XP and gold), **Frailty** (less max HP, more damage) or
  **Thirst** (your Tears emptied, a second blessing now).
- **Evolutions.** Each new weapon evolves at Lv 3 after Devouring 3 of an essence, like the
  Blade: the Maw with Dreadlings (Abyssal Maw), the Chains with Plaguewings (Chains of the
  Damned).

### Souls-like UI

A framed, pixel-font HUD in the corners, away from the action: HP and XP top-left, the day
top-right, the flask bottom-left, gold and the next revive price bottom-right, and the boss's
name and long bar bottom-center. Entering a place shows its name in a gothic title card,
death fades in **You Died** before the goddess offers a revive, and victory reads **Demon King
Felled**. Damage numbers pop off enemies (gold for elites and the boss). The UI is built in
code from `scripts/ui/ui_theme.gd`, which defines the palette, fonts and framed boxes.

### Look and feel

Built on what the best survivors-likes share (Vampire Survivors, Halls of Torment, Brotato,
Death Must Die): a cascade of pickups, reward ceremonies, power you can see, and mood
carried by light.

- **Dark fantasy lighting.** The world sits in dusk (forest), gloom (ruins) and blood-dark
  shadow (temple); a warm light travels with the hero and a vignette frames the screen.
  Gems, essences, chests, flashes and numbers glow through the dark. Fireflies drift in the
  forest, embers rise in the ruins, ash falls in the temple.
- **Pickup symphony.** Gems streak toward you and chime up a scale as you chain them; the
  XP bar flares with each one, and a level-up sends out a golden ring.
- **Kills that land.** Monsters burst in a white flash and leave dark ichor in their own
  color, fading after a few seconds.
- **Danger you can feel.** The screen's edges flash red when you're hit and pulse with a
  heartbeat below 30% HP.
- **Chest ceremony.** Opening a chest pauses the run: a reel of loot spins, slows and slams
  onto the reward, its name beneath (two reels for golden chests). Any key skips it.
- **The camera** pulls back as you level, so you see more of the growing horde, and pushes
  in for the Demon King's arrival and weapon evolutions. Its shake now follows smooth noise.

"Reduce flashing" in Settings softens the red flashes, heartbeat pulse and kill flashes;
screen shake has its own slider.

### Sound and music

Metal for every stage of a journey: the forest and the ruins each have their own track, a
faster one takes over the ruins when fights peak, and the Demon King's theme opens with
his entrance and turns symphonic when he enrages. The goddess's shrine and the title screen
get calm pieces. Free tracks come as finished mixes, not stems, so the music reacts by
filtering: lulls muffle it, waves and crowds open it to full blast, and it drops to a dull
thud when you pause or die (`scripts/autoload/music.gd`).

Sound runs on three buses (Master, Music, SFX, each with a volume slider in Settings) and a
hard limiter on Master, so hundreds of hits never clip. Each weapon has its own swing or
cast and hit sounds, footsteps change with the ground, and combat sounds have their own
voice pool so a swarm can't cut off a level-up or the death toll.

### Made for first-timers

- **One-time hints** explain each thing the first time it comes up: moving, gems, elites,
  Devour, chests, the flask when you're hurt, the shrine, the boss. Turn them off or replay
  them in Settings.
- **Esc pauses** with your **build** (stats, weapons and upgrades, essences, training), a
  **how to play** card (also on the title screen), and **settings**: volume, screen shake,
  damage numbers, fullscreen, hints. Settings live in `user://settings.json`, apart from the
  journey save.
- **Edge-of-screen arrows** point to chests (gold), essences waiting to be Devoured (their
  color) and the Demon King (red).
- **Gems come to you**: a wider pickup range, and after each level-up nearby gems fly in.

### One life, one journey

A journey is 20 days, one minute each. **The goddess finds you on Days 5, 10, 15 and 19**,
the lore days of the original game. Time stops, she speaks her part of the story, grants
a free **blessing** (pick one of three upgrades), and opens her shrine:

- **Training** for the rest of the journey: Stamina, Strength, Resilience, Dexterity and
  Guts, from the original game's Train menu
- **Goddess's Tears** upgrades: Tear Vessel (+1 flask charge) and Blessed Tears (each sip
  heals more)

The **Goddess's Tears** are your flask: 3 charges that each heal 35% of your max HP over a
short, slowed sip (Q). She refills them at every shrine, so spend them freely.

When you fall, she can **pull you back for gold**: 800, then 1600, 3200 and so on, and you
return at half HP with the monsters around you cleared. Gold buys both upgrades and
revives, so every purchase is a gamble. Refuse, or run out of gold, and the journey is over;
the next one starts fresh, keeping only your records (journeys, victories, best day).

The journey **saves at every shrine**: quit any time and continue from the title screen,
at the start of the day you last met the goddess. Saves live in `user://save.json`
(on Windows: `%APPDATA%/Godot/app_userdata/Reincarnated as a Devourer`).

## Design in one paragraph

A journey is 20 in-game days of one minute each, with one life. Monsters from the original game,
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
- [x] **M5** CC0 art and sound, juice, procedural world, versioned save file
- [x] **Progression** One-life journeys: goddess shrines on the lore days, gold revives, shrine checkpoints
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

Add `cov` after the seed to make the bot seal a random covenant at every shrine. Each run
also reports the share of time spent at each style rank.

Current targets (20 full journeys, seeds 1-8; the bot visits every shrine, keeps enough
gold for its next revive, and revives whenever it can pay):

| Bot | Result |
|---|---|
| `afk` | dies in 20-40 s |
| `kite` (never Devours) | wins about 3 in 4 journeys, often with 0-2 revives, mostly at style D-B |
| `devour` (Devours when safe, keeps max HP above 80) | wins 5-6 in 8; reaches higher style ranks |
| `devour ... cov` (also seals a random covenant at every shrine) | wins a little more often: covenants pay, but hurt |
| `greedy` (Devours everything) | dies by Day 7-14 even after paying for revives |

Each run also prints the damage the bot took by source (e.g. `plague 320, Vexclaw pounce
45`), which is how the plague puddles were caught being too strong.

Devour should pay off when used carefully and kill you when used greedily, and gold
should feel tight: what you spend at a shrine is gold you won't have for a revive.

## Credits

See [CREDITS.md](CREDITS.md).
