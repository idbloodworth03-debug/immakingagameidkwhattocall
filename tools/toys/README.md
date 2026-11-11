# Toys: our own animals in a flat toy style

Builds the game's animals by code as toys: a few big round shapes melted
into one body, flat colors in bold patches with crisp edges, stick legs,
button eyes that blink, and a dark outline. The art packs we tried
(`tools/packs`) were the reference for the *style* only: no pack mesh is
copied, traced or reshaped, and every shape of an animal is written out in
its own design file. (A style can't be owned; a pack's files can, see
`CREDITS.md`.)

The roster is moving to toys class by class (November 2026). A toy replaces
an animal's art only: it keeps the animal's skeleton, its animations and
its place in the game, and stands exactly as tall on screen as the model it
replaces.

| File | What it does |
| --- | --- |
| `animals/<id>.py` | One animal's design: its shapes (each on the bone that moves it), its colors, its color patches, its eyes and nose. Sizes are proportions of the animal's own height, so a design's numbers carry from one animal to another. |
| `kit.py` | Shortcuts for a design: the usual parts of a four-legged animal placed on its joints (body, head, muzzle, neck, legs, tail, ears, a jaw that opens), one limb at a time for an upright one (arms that hang, big hands and feet), a bird's (stubby wings as flat lobes along the wing bones, feathers at their tips, a tail fan, a hooked beak, trailing legs), and the patch functions (a body part, above or below a place, inside an ellipsoid, facing a way, stripes). |
| `toy.py` | Melts the shapes into one smooth body (`tools/creatures/sdf.py`), cuts it down to a few thousand triangles, cuts each patch's edge into the mesh so the color ends exactly on it, adds the eyes with their blendshapes, rigs it and bakes the animal's animations (`tools/creatures/motion.py`). |
| `skeletons.json` | Every animal's skeleton and motion settings as the game has them (joints, bones, gait, attacks, persona), frozen from its old model by `skeletons.py`: a toy starts from these, so its animations are the ones the game already plays. |
| `build.py` | Writes `art_sources/own/<id>_LOD0.glb` (the 3D viewer and the renders) and `_LOD1.glb` (fights), and the animal's entry in `tools/packs/packs.json` (pack `own`). A few seconds an animal. |
| `stands.json`, `sizes.py` | How tall each animal stood and how long it was on the ground before it became a toy, and the tool that gives each toy the drawn size at which it stands exactly as tall (`game/data/bodies.json` size and pose_up), from the game's own measurement (`game/tests/stand_report.tscn`). |

    python tools/toys/build.py red_fox wolf_pack
    python tools/packs/convert.py red_fox wolf_pack
    godot --headless --path game --import
    python tools/creatures/set_import.py && godot --headless --path game --import
    godot --headless --path game res://tests/stand_report.tscn | python3 tools/toys/sizes.py
    python tools/packs/convert.py red_fox wolf_pack --lod battle     # after a size change
    python tools/packs/render.py red_fox wolf_pack                   # portrait and sprite sheets

(Blender's Python, as for `tools/creatures`.) From `art_sources/own/` a toy
comes into the game exactly as a pack animal does (`tools/packs/README.md`),
under the animal's own id, so its models, portrait and sheets take the
place of the old ones.

## What a toy keeps

* **The skeleton and every animation**: the same bones, the same walk and
  attacks, and its persona's idle, fidget and victory. A pack's clips are
  generic; ours are made for each animal's fighting style, and a toy plays
  them as they are, so its swings land on the game's hit moments with
  nothing retimed.
* **Its card pose** (the "hero" clip its portrait is rendered from): the
  old model's, unless that hides what the toy is known by; then its design
  gives its own (`kit.card_pose`: a moment of its attack, turned and
  tipped as wanted: `d.toy(hero=card_pose(...))`).
* **Its height on screen**: `sizes.py` draws it as tall as the model it
  replaces. Its body's room in a fight (`bodies.json` footprint, width,
  reach) is gameplay and doesn't change, so a toy is designed compact: about
  as long on the ground as the old model (`sizes.py` says how much longer).

## How a toy is made

* **Toy proportions, written directly.** The older animals were built to
  the real animal's anatomy, squashed into a cartoon and given fur. A toy
  is designed as a toy: a bean of a body, a big simple head, sticks for
  legs, and one or two big features (a fox's ears and tail, a lion's mane,
  a tiger's stripes).
* **Crisp color patches.** A patch is a function over the body's surface
  that is above 0 inside it. The mesh is refined where the patch's edge
  runs and then cut along it (`toy.refine`, `toy.cut`), so a color ends on
  mesh edges: sharp at any size, with no texture. Patches are painted in
  order; a later one covers an earlier one.
* **Button eyes with blendshapes**, named as the first pack's
  (`eyes.blink`, `eyes.happy`, `eyes.annoyed`, `eyes.sleep`, `eyes.shrink`,
  `eyes.spin-1..3`), so the game's faces (blink, squint, happy, drowsy,
  wide, dizzy: `game/data/viewer.json` "toon_look") work as they do for a
  pack animal.
* **Its own smooth normals.** The body is lit by the round shapes' own
  surface, not by the triangles it was cut down to, so a light model has
  no dents and the two sides of a color's edge face the same way (the
  game's outline is the mesh pushed out along its normals and must not
  tear there).

## Adding an animal

Copy a design like its own kind (`animals/wolf_pack.py` for a four-legged
animal, `yeti.py` for an upright one, `barn_owl.py` for a bird,
`king_cobra.py` for a snake, `dragon.py` for wings on four legs). Start from its skeleton (`Design("<id>", colors, base)`), give it
its shapes, patches, eyes and nose, and preview it. Then run the steps
above; `sizes.py` tells you if it has grown too long on the ground.
