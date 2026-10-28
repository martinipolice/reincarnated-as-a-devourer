# Credits

Design and programming: Charles Santos

## Third-party assets

The art, sound effects and music are CC0 (public domain): credit isn't required, but it's given here gladly.
The fonts are under the SIL Open Font License. The license text for each pack sits next to its files.

| Asset | Author | Source | License | Used for |
|---|---|---|---|---|
| Ninja Adventure Asset Pack | Pixel-Boy and AAA | [itch.io](https://pixel-boy.itch.io/ninja-adventure-asset-pack) | CC0 ([LICENSE.txt](assets/ninja/LICENSE.txt)) | All art: player (`Knight`), goddess (`Princess`), Dreadling (`Spirit`), Vexclaw (`Beast`), Plaguewing (`GreenOctopus`), Mimic (`LittleTreasureChest`), Hexeye (`Eye`), Warden (`Cyclope`), Ruin Guardian (`GiantRedSamurai`), Hollow Spirit (`GiantSpirit`), Demon King (`DemonCyclop`), terrain tilesets (floor, nature, interior floor), level-up skill icons (including Devourer's Maw, Hellfire Chains, Doom Bell, Hunger and covenants), potions, gems, coins, bomb, chests, weapons, and effects (circular slash, smoke, explosion, sparks, spirit wisp) |
| RPG Audio | Kenney | [kenney.nl](https://kenney.nl/assets/rpg-audio) | CC0 ([License.txt](assets/audio/kenney_rpg/License.txt)) | Blade swing, coins, chest opening |
| Impact Sounds | Kenney | [kenney.nl](https://kenney.nl/assets/impact-sounds) | CC0 ([License.txt](assets/audio/kenney_impact/License.txt)) | Hits, Aegis clangs, Doom Bell tolls, deaths, player hurt, boss slam, bombs |
| Interface Sounds | Kenney | [kenney.nl](https://kenney.nl/assets/interface-sounds) | CC0 ([License.txt](assets/audio/kenney_interface/License.txt)) | XP gems, menu clicks |
| Jacquard 12 | Sarah Cadigan-Fried | [Google Fonts](https://fonts.google.com/specimen/Jacquard+12) | OFL 1.1 ([Jacquard12-OFL.txt](assets/fonts/Jacquard12-OFL.txt)) | Gothic titles: day counter, area names, You Died, boss name, menus |
| Jersey 10 | Sarah Cadigan-Fried | [Google Fonts](https://fonts.google.com/specimen/Jersey+10) | OFL 1.1 ([Jersey10-OFL.txt](assets/fonts/Jersey10-OFL.txt)) | All other text |
| Digital Audio | Kenney | [kenney.nl](https://kenney.nl/assets/digital-audio) | CC0 ([License.txt](assets/audio/kenney_digital/License.txt)) | Level up, loot, Devour, evolution, boss warning and volley, victory/defeat |

Art is copied and sliced into Godot animations by `tools/import_ninja.py`. Earlier
versions used 0x72's 16x16 DungeonTileset II (CC0); it's no longer in the project.

## Synthesized sounds

The enemy warning cues (Vexclaw pounce, Hexeye aim, Plaguewing lob, guardian charge) and
the ambient beds (forest night, ruins wind, temple drone) are made for this game from noise
and sine waves by `tools/synth_audio.py`, so they're part of the project itself.

## Engine

Made with [Godot Engine](https://godotengine.org) (MIT license).

## Music

All from [OpenGameArt](https://opengameart.org), all CC0. Converted to OGG and renamed in
`assets/audio/music/`; levels are matched in `scripts/autoload/music.gd`.

| Track | Author | Source | License | Used for |
|---|---|---|---|---|
| Evil temple Ambiance loop | Brandon Morris | [OpenGameArt](https://opengameart.org/content/evil-temple-ambiance-loop) | CC0 (also OGA-BY 3.0) | Title screen |
| Heavy Battle 2 | MintoDog | [OpenGameArt](https://opengameart.org/node/183145) | CC0 | The Whispering Forest (Days 1-9) |
| Heavy Dungeon | MintoDog | [OpenGameArt](https://opengameart.org/node/181405) | CC0 | The Fallen Ruins (Days 10-19) |
| Heavy Boss Battle 1 | MintoDog | [OpenGameArt](https://opengameart.org/node/183631) | CC0 | The Fallen Ruins at peak intensity |
| Boss Battle #9 [Metal] | nene | [OpenGameArt](https://opengameart.org/node/151361) | CC0 | The Demon King: entrance (opening) and duel (loop) |
| Boss Battle #2 [Symphonic Metal] | nene | [OpenGameArt](https://opengameart.org/node/84428) | CC0 | The Demon King enraged (loop) |
| Heavenly Loop | isaiah658 | [OpenGameArt](https://opengameart.org/content/heavenly-loop) | CC0 | The goddess's shrine |
