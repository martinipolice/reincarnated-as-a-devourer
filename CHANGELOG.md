# Changelog

## Unreleased

### New
- **Devouring is a decision:** each essence offers its classic boost or a mutation, and the
  Hunger rises with every Devour (Sated, Hungry, Ravenous, Insatiable): more damage, but
  Devours heal less, elites come more often, monsters hit harder, and the goddess gives less.
- **Level-up control:** reroll, banish and skip, with more sold at the shrine.
- **Branching weapons:** every weapon chooses one of two branches at Lv 3 and grows to Lv 5.
- **Two new monsters:** the Necro-acolyte raises the freshly fallen unless you kill it
  first; the Burrower moves underground, cracks the ground under you and erupts.
- **Landmarks:** cursed altars (survive a surge for a reward), bloody wells (HP for gold),
  iron cages (a strong elite) and fallen heroes' graves (a gift), from Day 2.
- **A three-phase Demon King:** fury at two thirds of his HP, then he wears your hunger,
  turning the essence you Devoured most against you. His phases can't be skipped, he grows
  tougher with every Devour you took, and pillars stop his orbs until his slams break them.
- **Title screen:** the game's forest at night drifts behind a crest, with fireflies and fog.
- **Sound:** warning cues for pounces, hexes, globs, charges, raising and burrowing, and
  ambient beds under the music (forest night, ruins wind, temple drone), all synthesized
  for this game.
- Text is ready for translation (`locale/messages.pot`), and a trailer can be recorded with
  `tools/trailer.gd`.

### Fixed
- A risen Mimic no longer drops a second golden chest: Necro-acolytes can't raise Mimics.
- Landmarks crumble when the Demon King arrives, so an altar can't start a surge in the duel.
- A level-up and a Devour choice finishing at the same moment no longer open on top of each
  other; the second waits its turn.
- Underground Burrowers show as dirt mounds made from their own sprite, which keeps sprite
  batching intact (the drawn trail cost about 1.5 ms a frame with 500 enemies).
- "You Died", "Your Journey Ends" and the HUD's revive price use a brighter red that meets
  WCAG AA contrast (was 2.4:1).
- Landmark names stay hidden while an area title is on screen.

### Balance
- Essences: a third and later essence of one kind give 70%, 50%, then 40%; Vexclaw +22%
  might (was +30%), Plaguewing +20 defense (was +25).
- Warden shield 120 (was 180); Hunger (the passive) is only offered once you've Devoured.
- Devourer's Maw: damage 48/68/92 (was 36/50/68), 1/2/3 bites (was 1/1/2), evolved 115
  damage and 4 bites. Aegis: damage 24/34/46 (was 14/20/28), evolved 60 (was 36).
- Monsters grow 23% tougher each day (was 20%).
- Plague puddles dry up as they age and overlapping ones hurt once per tick.
- Bot results (balance sim): never Devouring wins 5 in 8, Devouring up to 3 essences 6 in 8,
  Devouring whenever safe 7 in 12; Demon King fights mostly last 40-110 s.

### Under the hood
- The run controller is split into smaller pieces; a headless test suite (63 tests) covers
  saves, combat, choices, threats, landmarks, the Demon King and the menus, and GitHub
  Actions runs it on every push.

## 0.2.0

New content and a full menu overhaul.

- **New monsters:** the Hexeye (fires telegraphed hexes from range) and the Warden (a shield
  that soaks hits). A spawn table by day decides who comes.
- **Mini-bosses:** the Ruin Guardian on Day 10 (charges) and the Hollow Spirit on Day 15
  (blinks). Each drops gold, a golden chest and an essence.
- **Doom Bell**, a sixth weapon that tolls, blasts and slows; it evolves into the Death
  Knell. **Hunger**, a passive for faster Devouring that heals more.
- **Resonances:** five essence pairs that awaken a lasting bonus.
- **Starting weapons** to unlock across journeys, picked from cards.
- **Menus rebuilt** in a souls frame with Hades-style choice cards: title screen, level-up,
  the goddess's shrine, pause, revive, and confirm dialogs. Scene fades.
- **New screens:** results with damage per weapon, the Codex, and credits.
- Plaguewing retune: a landing marker for each glob, smaller and shorter puddles, less
  damage.

## 0.1.0 (first public build)

The first playable release: a complete 20-day journey, from the Whispering Forest to the
Demon King, with two endings.

- **One life, one journey.** 20 one-minute days; the goddess's shrines on Days 5, 10, 15
  and 19 save the journey, grant a blessing, and sell training and flask upgrades. Revives
  cost gold, doubling each time.
- **Five weapons, all evolving:** Blade, Goddess Light, Aegis, Devourer's Maw, Hellfire
  Chains (carry four). Seven passives. Devour elites' essences for lasting power.
- **Style rank** D to SSS, **elite traits** from Day 5, **shrine covenants**.
- **Two endings:** spare the Demon King, or Devour him.
- Souls-like pixel UI, a metal soundtrack that reacts to the fight, dark-fantasy lighting.
- Keyboard, mouse and controller (with rumble and matching prompts); beginner hints,
  pause menu, settings.
- Holds about 90-110 fps with 500 enemies on a desktop PC.
