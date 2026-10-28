# Changelog

## Unreleased

- Balance: the Warden's shield is 120 (was 180), and Hunger is only offered once you've
  Devoured. Bots: not Devouring wins about 4 runs in 8 again, Devouring about 7 in 8.
- Title screen: the game's forest at night drifts behind a crest (the name with an ember
  glow and a sweeping shine), with fireflies and fog.
- Sound: warning cues when a Vexclaw crouches, a Hexeye aims, a Plaguewing lobs, and a
  guardian winds up a charge; ambient beds under the music (forest night, ruins wind,
  temple drone). All synthesized for this game.
- Text is ready for translation (`locale/messages.pot`), and a trailer can be recorded with
  `tools/trailer.gd`.
- Under the hood: the run controller is split into smaller pieces, a headless test suite
  covers saves, combat, the run and the menus, and GitHub Actions runs it on every push.

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
