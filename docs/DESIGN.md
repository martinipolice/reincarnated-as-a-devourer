# Reincarnated as a Devourer: design pitch

**Genre:** survivors-like action roguelite | **Platform:** PC + web (itch.io) | **Players:** 1

## Hook
You have 20 days to kill the Demon King, and you get stronger by eating what you kill.
But every monster you Devour takes some of your life, and the goddess who sent you isn't
telling you everything. How much you Devour decides how the run, and the story, ends.

## Core loop
- **Every few seconds:** move, dodge, collect XP, watch auto-weapons fire.
- **Every 30-60 seconds:** pick 1 of 3 level-up options, or risk Devouring an elite.
- **One run:** 20 days that get harder → lore beats on Days 5/10/15/19 → Day 20 dialogue → Demon King.
- **Between runs:** spend gold at the Goddess's Sanctuary (permanent upgrades, new starting weapons).

## Translating the terminal game

| Original | Survivors-like version |
|---|---|
| 20 days | One run; 1 day = 30 s (MVP) or 1 min (full game) |
| Train | Permanent upgrades between runs, paid with gold |
| Shop tiers (blade / shield / boots) | Level-up items, one tier per level |
| Potions | Rare healing drops; Panacea only from elites |
| Explore spawn weights | Spawn director that adjusts by day (`scripts/main.gd`) |
| Devour, 60% chance | Hold to channel for 1 s, open to attack. Grants an Essence; costs max HP for the run. No dice roll. |
| Defend | Optional "Brace" active with a cooldown (post-MVP) |
| Demon King charge every 5 turns | Telegraphed double-damage slam every ~25 s |
| `ATK - DEF` damage | `ATK * 100 / (100 + DEF)` so damage never hits zero |

## Story delivery
- One or two goddess lines when a day changes; full the first time, a toast after that.
- Day 15 ruins become a carving in the world you walk up to and read.
- The four Day 20 replies change the boss fight and the ending:
  - *"She sent me to end you":* standard fight.
  - *"Here of my own will":* harder fight, better reward.
  - *"I won't kill you":* mercy ending: survive 3 minutes without hurting him.
  - *Silence:* hidden route.
- Idea to check against the lore doc: Devour past a threshold and you become the next
  Demon King ("the cycle remains unbroken"); the true ending is the one time you may
  Devour a boss, taking his sorrow rather than his power. The hospital epilogue is the reward.

## MVP scope
1 hero · 3 weapons (Blade, Goddess Light, Aegis orbit) · 3 passives (Treads, Guard,
Stamina) · 3 enemies + elites · Devour with 3 Essences, 1 evolution · 10-minute run ·
Demon King · win/lose screen.

**Cut until after MVP:** meta shop, save file, endings, art, music, second hero, Brace.

## Risks
- Scope creep (3D, more heroes, endings before the core is fun). Hold the MVP line.
- Flat feel. Hit flash, knockback, gem magnet and sounds matter more than content count.
- Story that gets in the way. Lines under 2 sentences, skippable, at most one per day.
