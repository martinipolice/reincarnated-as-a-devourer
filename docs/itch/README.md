# itch.io release kit (v0.3.0)

Everything for the game's itch.io page. The builds are not in git: export them first
(below), or use the zips already in `build/release/` if they're there.

## Files

| File | Use |
|---|---|
| `cover.png` (630×500) | Cover image |
| `gameplay.gif` (640×360, 4 s) | First screenshot / the page's eye-catcher |
| `1_title.png` … `6_ending.png` (1280×720) | Screenshots |
| `build/release/ReincarnatedAsADevourer-0.3.0-web.zip` | Upload: the browser version |
| `build/release/ReincarnatedAsADevourer-0.3.0-windows.zip` | Upload: the Windows download |

To rebuild them: in Godot, **Project → Export → Export All** (presets for Windows Desktop and
Web are in `export_presets.cfg`), then zip `build/web/` (with `index.html` at the zip's root)
and `build/windows/`.

## Page settings

- **Title:** Reincarnated as a Devourer
- **Project URL:** reincarnated-as-a-devourer
- **Short description / tagline:** 20 days. One life. Devour or be devoured.
- **Classification:** Game · **Kind of project:** HTML (the Windows zip is added as a download too)
- **Release status:** Released (or "In development" if you'd rather signal early)
- **Pricing:** No payments (free)
- **Genre:** Action · **Tags:** roguelite, survivors-like, bullet-heaven, pixel-art,
  souls-like, dark-fantasy, metal, top-down, singleplayer, godot
- **AI generation disclosure:** itch asks this on the page; answer it truthfully for how the
  game was made.

### Uploads

1. Upload `…-web.zip`, tick **This file will be played in the browser**.
2. Upload `…-windows.zip`, set it to **Windows**.

### Embed options (for the web upload)

- **Viewport dimensions:** 1280 × 720
- **Automatically start on page load:** off (a click-to-play button is friendlier)
- **Fullscreen button:** on
- **Mobile friendly:** off (it needs a keyboard or a controller)
- **SharedArrayBuffer support:** off. The web build is single-threaded and doesn't need it.

## Description (paste into the page's description)

> **You were a hero from another world. You died. Now you have twenty days, and only one
> life, to face the Demon King.**
>
> *Reincarnated as a Devourer* is a survivors-like with a souls-like heart. Your weapons fire
> on their own; your job is to survive the horde, grow, and choose: every elite you kill
> leaves an essence you can **Devour** for lasting power, at the cost of your own life. Every
> Devour also feeds your **Hunger**: more power, weaker heals, and predators that smell it.
>
> **The goddess finds you on Days 5, 10, 15 and 19.** She saves your journey, grants a
> blessing, sells training, and offers covenants: curses that pay. When you fall, she can
> pull you back for gold, and her price doubles every time.
>
> - Six weapons that all evolve and branch at Lv 3, eight passives, seven Devourable
>   essences, each with a mutation to choose instead, and essence pairs that resonate
> - Reroll, banish or skip at level-ups
> - Monsters that each fight their own way, from pouncing Vexclaws to Necro-acolytes that
>   raise the fallen and Burrowers that erupt under your feet; mini-bosses on Days 10 and 15
> - Landmarks to seek out: cursed altars, bloody wells, caged elites, fallen heroes' graves
> - A three-phase Demon King who, at the end, turns your own hunger against you
> - A style rank from D (Dull) to SSS (Soul Devourer), elite traits, shrine covenants,
>   chests and Mimics
> - Two endings: spare him, or Devour him
> - A metal soundtrack that swells with the fight; dark-fantasy pixel art
> - Keyboard or controller, beginner hints you can switch off, and reduce-flashing / screen
>   shake settings
>
> **Play in the browser**, or download for Windows for the smoothest big fights.
>
> Controls: WASD / arrows or the left stick to move, E / Space or A to Devour, Q or X to drink
> the Goddess's Tears, Esc or Start to pause.
>
> Made with Godot 4.7 from a Python terminal RPG I wrote for a university course (CMSC 12).
> Art: Ninja Adventure (Pixel-Boy and AAA, CC0). Sound: Kenney (CC0), plus warning cues and
> ambience synthesized for the game. Music: MintoDog, nene,
> Brandon Morris, isaiah658 (CC0, via OpenGameArt). Fonts: Jacquard 12 and Jersey 10 by
> Sarah Cadigan-Fried (SIL OFL). Full credits in the game's repository.

## Notes

- Performance: the v0.3.0 Windows build holds about 107 fps with 500 enemies (99th
  percentile frame 16 ms, measured on an RTX 4050 laptop). The browser build is
  single-threaded WebAssembly; its v0.1.0 numbers were about 64-74 fps in real play on an
  Intel UHD laptop GPU. v0.3.0 hasn't been measured in a browser yet. Hence the "Windows for
  the smoothest big fights" line.
- The browser build's title screen fills in its forest over the first few seconds while
  the world loads.
- Saves (web): the browser keeps them in the page's local storage, per browser.
