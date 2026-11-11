# Toys: our own animals in the packs' flat style

Builds an animal of our own, by code, in the style of the art packs we
tried (`tools/packs`): a toy made of a few big round shapes, flat colors in
bold patches with crisp edges, stick legs, button eyes that blink, and a
dark outline. It is a **test** (November 2026): one animal, the Red Fox, to
see whether models we make ourselves can stand next to a pack's.

The packs are the reference for the *style* only. No pack mesh is copied,
traced or reshaped: every shape of an animal is written out in its own
design file. (A style can't be owned; a pack's files can, see
`CREDITS.md`.)

| File | What it does |
| --- | --- |
| `animals/<id>.py` | One animal's design: where its joints are, the round shapes that make its body, its colors, its color patches (each a little function saying where on the body the patch is), its eyes and nose, and how it moves (which of our gaits, attacks and personas: `tools/creatures/motion.py`). |
| `toy.py` | The kit: melts the shapes into one smooth body (`tools/creatures/sdf.py`), cuts it down to a few thousand triangles, cuts each patch's edge into the mesh so the color ends exactly on it, adds the eyes with their blendshapes, rigs it to our usual skeleton and bakes our animations. |
| `build.py` | Writes `art_sources/own/<Name>_LOD0.glb` (the 3D viewer and the renders) and `_LOD1.glb` (fights). A few seconds an animal. |

    python tools/toys/build.py red_fox
    python tools/packs/convert.py own_fox
    python tools/packs/render.py own_fox

(Blender's Python, as for `tools/creatures`.) From `art_sources/own/` a toy
comes into the game exactly as a pack animal does: `tools/packs/packs.json`
has a pack `own` and an animal `own_fox`, and `game/data/art_tests.json`
shows it next to the animal it plays as (the website opened with
`?arttest=1`).

## What a toy keeps from our own pipeline

* **The skeleton and every animation** (`tools/creatures`: `anatomy.py`,
  `motion.py`): the same 23 bones, the same trot, pounce and bite, and the
  fox persona's idle, fidget and victory. A pack's clips are generic; ours
  are made for each animal's fighting style, and a toy plays them as they
  are, so its swings land on the game's hit moments with nothing retimed.
* **The shape kit** (`sdf.py`): round cones, ellipsoids and rounded
  triangles that melt into each other, meshed by marching cubes.

## What is new

* **Toy proportions, written directly.** Our older animals were built to
  the real animal's anatomy and then squashed into a cartoon, with fur on
  top. A toy is designed as a toy from the start: a bean of a body, a big
  simple head, sticks for legs, one or two big features (a fox's ears and
  tail).
* **Crisp color patches.** Each patch is a function over the body's surface
  that is above 0 inside the patch. The mesh is refined where the patch's
  edge runs and then cut along it (`toy.refine`, `toy.cut`), so a color ends
  on mesh edges: sharp at any size, with no texture. Patches are painted in
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

Copy `animals/red_fox.py`. Four-legged animals use
`anatomy.quadruped_skeleton(J)`: give the joints, then the shapes (each
with the body part it belongs to and the bone that moves it), the colors
and the patches. `python tools/toys/build.py <id>` builds it; then add it
to `tools/packs/packs.json` (pack `own`) and `game/data/art_tests.json`,
and run the packs' steps (`tools/packs/README.md`).
