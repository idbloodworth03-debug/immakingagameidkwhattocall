# Art packs

Brings animals from a bought (or free) art pack into the game, in the same
formats `tools/creatures` makes, so the game needs nothing new to show them:
3D models for the viewer and for fights, a card portrait and battle sprite
sheets. The game's own rules and numbers stay as they are: an animal from a
pack takes the place of one of ours and only its drawing changes.

The pack's own files are never part of this repository (most asset licenses
don't allow handing them on). Keep them on your computer and say where they
are with `--pack <folder>` (or `PACK_DIR=<folder>`).

| File | What it does |
| --- | --- |
| `packs.json` | Every pack (where it keeps its meshes, clips and palette) and every animal taken from one: which pack animal, which of ours it plays as, its body plan and attack styles, which of the pack's clips make each of our animations, its hero pose for the card, and how the renders look. |
| `pack.py` | Shared: loads a pack animal into Blender (mesh, rig, clips, facial blendshapes), bakes its palette into vertex colors, splits its face off, builds our animations from its clips. |
| `convert.py` | The 3D models: `game/art/models/<id>.glb` (viewer) and `game/art/models/battle/<id>.glb` (fights), with `battle/models.json`. About a second an animal. |
| `render.py` | The card portrait (`game/art/units/<id>/portrait.webp`, hero pose) and the sprite sheets (`sheet.webp`, `sheet.json`). About 30 seconds for a portrait, 15-20 minutes for the sheets. |
| `sizes.py` | Writes each animal's drawn size and tallest pose into `game/data/art_tests.json` from the game's own measurement (`tests/art_test_report.tscn`). |

    python tools/packs/convert.py --all --pack ~/packs/quirky
    python tools/packs/render.py --all --pack ~/packs/quirky
    godot --headless --path game --import
    python tools/creatures/set_import.py && godot --headless --path game --import
    godot --headless --path game res://tests/art_test_report.tscn | python3 tools/packs/sizes.py
    python tools/packs/convert.py --all --pack ~/packs/quirky --lod battle   # after a size change

(Run the Python with Blender's Python, as for `tools/creatures`.)

## What changes on the way in

* **Colors:** the pack colors each animal from a tiny palette picture
  through its UVs. They become vertex colors (no texture to filter or bleed),
  which the game's shaders already draw.
* **Face:** the eyes and the tear and sweat drops (all the blendshapes move)
  become a small second mesh, `<id>_toon_face`, so the body carries no
  blendshapes. The viewer's model keeps all of them; the battle model keeps
  the ten the game's faces use (blink, happy, angry, sleepy, wide, squint,
  dead and the three spinning-eye frames).
* **Facing and scale:** the animal is turned to face +Y and the rig's own
  scale is baked in, so the game measures it like its other models.
* **Animations:** the pack's clips are all short loops (11 frames, 0.42 s).
  Each of our animations (idle, walk, attack, attack2, special, fidget,
  victory) is made from one or more of them (`packs.json` "clips"), eased
  through the pack's frames, and timed exactly like the animal it plays as
  (`sheet.json` frames, fps and hit moment), with an attack's strike (where
  the animal reaches furthest forward) landing on the game's hit moment.
* **Look:** the meshes are named `<id>_toon`, so the game draws them with its
  flat-color shader (`game/scripts/fx/model_toon.gdshader`, values in
  `game/data/viewer.json` "toon_look"): two soft cartoon tones, a little
  darker underneath, a rim of light, bolder color and a bolder dark outline.
  The renders (portrait, sprites) use a cel-shaded material in two soft
  tones with part of the color unlit, a big soft key light and the same
  dark line (`packs.json` "look").

## Trying them in the game

An animal from a pack goes into `game/data/art_tests.json` first: an *art
test*, not in the roster, that exists only when a dev link asks for it, as a
copy of the animal it plays as (stats, class, ability, attack style,
footprint, reach and level). `tests/test_art_tests.gd` checks that a fight
with it is the same, tick for tick, as with the animal it replaces.

* `?arttest=1`: every art test's card beside the card of the animal it
  plays as; tap one for its 3D viewer; "Test fight" pits them against ours.
* `?viewer=test_colobus`: straight to one in the 3D viewer.
* `?fight=7&herds=test_colobus,test_taipan,test_sparrow|brown_bear,king_cobra,peregrine_falcon`:
  a fight of theirs against ours, played by the computer.

(Dev tools on: `game/data/testing.json` "show_dev_tools".)
