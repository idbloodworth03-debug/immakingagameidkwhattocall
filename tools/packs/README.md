# Art packs

Brings animals from a bought (or free) art pack into the game, in the same
formats `tools/creatures` makes, so the game needs nothing new to show them:
3D models for the viewer and for fights, a card portrait and battle sprite
sheets. The game's own rules and numbers stay as they are: an animal from a
pack takes the place of one of ours and only its drawing changes.

Two kinds of pack are read (`packs.json` "format"):

* **fbx** (Quirky Series): a mesh per level of detail with facial
  blendshapes, the clips in their own file, colors from a tiny palette
  picture.
* **gltf** (Quaternius): one file per animal with its mesh, rig and clips,
  colors from flat materials or a color atlas, no blendshapes. Our own
  toy-style animals (`tools/toys`, the pack `own`) come in this way too:
  a file per level of detail (`{lod}` in the pack's file name), with eye
  blendshapes and smooth normals of their own (`smooth_normals`).

Each pack's files are in its own folder (`packs.json` "folder") under one
root. A **CC0** pack's files are in this repository, under `art_sources/`
(Quaternius: anyone may use, change and share them), and so are our own
(`art_sources/own/`, built by `tools/toys/build.py`). A pack under a **store
license** stays on your computer (most don't allow handing the files on;
`.gitignore` keeps anything else under `art_sources/` out): put it in a
folder of packs and name that root with `--pack <root>` (or
`PACK_ROOT=<root>`), e.g. `~/packs/quirky/` and `~/packs/quaternius/`.

| File | What it does |
| --- | --- |
| `packs.json` | Every pack (where it keeps its meshes, clips and palette) and every animal taken from one: which pack animal, which of ours it plays as, its body plan and attack styles, which of the pack's clips make each of our animations, its hero pose for the card, and how the renders look. |
| `pack.py` | Shared: loads a pack animal into Blender (mesh, rig, clips, facial blendshapes), bakes its palette into vertex colors, splits its face off, builds our animations from its clips. |
| `convert.py` | The 3D models: `game/art/models/<id>.glb` (viewer) and `game/art/models/battle/<id>.glb` (fights), with `battle/models.json`. About a second an animal. |
| `render.py` | The card portrait (`game/art/units/<id>/portrait.webp`, hero pose) and the sprite sheets (`sheet.webp`, `sheet.json`). About 30 seconds for a portrait, 15-20 minutes for the sheets. |
| `sizes.py` | Writes each animal's drawn size and tallest pose into `game/data/art_tests.json` from the game's own measurement (`tests/art_test_report.tscn`). |

    python tools/packs/convert.py test_fox test_yeti          # CC0 packs: straight from art_sources/
    python tools/toys/build.py red_fox && python tools/packs/convert.py own_fox   # our own
    python tools/packs/convert.py --all --pack ~/packs
    python tools/packs/render.py --all --pack ~/packs
    godot --headless --path game --import
    python tools/creatures/set_import.py && godot --headless --path game --import
    godot --headless --path game res://tests/art_test_report.tscn | python3 tools/packs/sizes.py
    python tools/packs/convert.py --all --pack ~/packs --lod battle   # after a size change

(Run the Python with Blender's Python, as for `tools/creatures`.)

## What changes on the way in

* **Colors:** a pack colors its animals from a tiny palette picture or a
  color atlas through their UVs, or from flat materials. They become vertex
  colors (no texture to filter or bleed), which the game's shaders already
  draw. `recolor` in `packs.json` swaps colors.
* **Face:** where a pack has facial blendshapes (Quirky), the eyes and the
  tear and sweat drops they move become a small second mesh,
  `<id>_toon_face`, so the body carries none. The viewer's model keeps all
  of them; the battle model keeps the ten the game's faces use (blink,
  happy, angry, sleepy, wide, squint, dead and the three spinning-eye
  frames). A pack without them (Quaternius) keeps the face its mesh has.
* **Facing and scale:** the animal is turned to face +Y and the rig's own
  scale is baked in, so the game measures it like its other models. A
  rig's handle bones (IK and pole targets) are left out.
* **Animations:** each of our animations (idle, walk, attack, attack2,
  special, fidget, victory) is made from one or more of the pack's clips
  (`packs.json` "clips"), eased through the pack's frames. A swing is timed
  exactly like the animal it plays as (`sheet.json` frames, fps and hit
  moment), with its strike (`strike`: where in the clip the blow lands;
  found by itself for a simple lunge) on the game's hit moment. An idle,
  walk, fidget or victory may keep the pack's own length (`frames`, `fps`).
  Quirky's clips are all 0.42-second loops; Quaternius's run 0.4 to 4
  seconds and some play once (`once`).
* **Look:** the meshes are named `<id>_toon`, so the game draws them with its
  flat-color shader (`game/scripts/fx/model_toon.gdshader`, values in
  `game/data/viewer.json` "toon_look"): two soft cartoon tones, a little
  darker underneath, a rim of light, bolder color and a bolder dark outline.
  A faceted low-poly pack (`packs.json` "faceted": its meshes are named
  `<id>_toonflat`) is lit face by face, its own look; its mesh's split
  edges are still joined and its normals smoothed (`weld`), because the
  outline is the mesh pushed out along them and would tear at every edge.
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
  plays as, pack by pack; tap one for its 3D viewer; each pack's "Test
  fight" pits its animals against ours.
* `?viewer=test_colobus`: straight to one in the 3D viewer.
* `?fight=7&herds=test_colobus,test_taipan,test_sparrow|brown_bear,king_cobra,peregrine_falcon`:
  a fight of theirs against ours, played by the computer
  (`test_fox,test_wolf,test_yeti,test_dragon|red_fox,wolf_pack,yeti,dragon`
  for the Quaternius four; `own_fox|red_fox` for our own Toy Fox).

(Dev tools on: `game/data/testing.json` "show_dev_tools".)
