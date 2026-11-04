# Creature pipeline

Makes the battle sprites and card portraits for each animal, and the
arena pictures, with Blender, from code: no hand modeling, so everything
can be rebuilt or tweaked.

Each species is modeled at its real proportions, then **turned into a
cartoon of itself** (`cartoon.py`): shorter legs and body, a rounder torso,
a shorter muzzle and a much bigger head, big googly eyes, solid puffy ears,
smooth skin in brighter colors instead of hair, and a dark outline. It is
still modeled, lit and shaded in 3D. The coat is painted as on the real
animal, so markings stay where they belong. Paint noise is dropped so
color areas stay clean, unless it draws the markings
(`p.noise(..., markings=True)`, like the wild dogs' patches). A species can tune its cartoon
with `c.cartoon` (the elephant's and hippo's heads grow less; the lion's
mane grows with its face).

1. **Shape** (`sdf.py`, `anatomy.py`): an animal is a set of smooth shapes
   (round cones for legs and necks, ellipsoids for the torso and head,
   rounded triangles for ears) that melt into each other. Marching cubes
   turns them into a mesh. Each shape belongs to a body part and a bone.
2. **Paint** (`paint.py`): colors per vertex, by body part and position:
   white bib, black stockings, stripes, spots.
3. **Fur** (`fur.py`): real hair strands grown from the skin, colored by
   the paint underneath, combed back and down.
4. **Motion** (`motion.py`): idle, walk (trot, walk or gallop), attack
   (pounce-bite, bite, swipe, charge, stomp, throw) and death, as poses;
   and a fidget for every body plan (a look around and a head shake;
   upright animals scratch their head; fliers somersault; fish flop, whales
   wave their tail, snakes look about, frogs hop, seals clap, shrimp wave
   their claws); for animals with `motion["attack2"]` a second attack to
   alternate with (`slam`, `rake`, `lob`, `handstand`, `leap`,
   `tail_slap`, `ram` or any first attack); for Stun animals
   (`motion["special"]`) a big wind-up before the blow that stuns (a chest
   beat, a hiss, a roar); and, only where asked for (`motion["victory_render"]`)
   or already rendered, a looping victory. The death pose is kept for
   previews (`python strip.py <id> death`) but isn't in the sheets: the
   game's knockouts are a cartoon poof.
5. **Render** (`sprites.py`): Cycles with Freestyle outlines, an
   orthographic camera at the game's 50-degree angle, five directions (the
   game mirrors the other three). It also writes where the eyes are in
   every frame (and how big they are and the skin color around them) into
   `sheet.json`, so the game can draw blinks and cartoon faces over them,
   and the body plan. Sheets are version 3: each animation is cropped to
   its own frame size and frames are packed tightly (at most 4096 pixels on
   a side), each animation recording its frame size, anchor and where each
   frame is.
6. **Arenas** (`arena.py`): one picture per arena, from the same camera,
   with the ground stretched so tiles come out square. The ground's colors
   (grass, tile stripes, the halfway line and center ring, flowers) are
   painted with numpy; Blender adds the fence and themed scenery, into
   `game/art/arenas/`. Each arena's look is a theme at the top of the file.
7. **Dens** (`treehouse.py`, not used by the game any more): side and main
   treehouses in each team's color and their ruins. It writes into
   `game/art/towers/`, which the game no longer has.

Each animal is one file in `species/`.

Body plans: `anatomy.py` has four-legged animals (`quadruped`, which also
builds upright primates and sprawling lizards from where their joints go)
and birds (`bird`). `bodies.py` adds butterflies (`butterfly`), fish and,
with a flat tail fluke, dolphins and whales (`fish`), shrimp (`shrimp`),
bats (`bat`) and wings for a four-legged animal (`add_wings`: Pegasus,
Griffin, Dragon). Each sets `motion["body"]`, which picks its idle, walk
and death in `motion.py`: butterflies flutter, fish flop and hop on land,
dolphins and whales belly-slide, shrimp scuttle, winged animals fly with
their legs tucked. Attacks for them: `spit` (a shot from the mouth),
`snap` (a shrimp's claw), `flutter_dive` and `winged_dive`; upright animals
walk with the `biped` gait and lizards add `wiggle`.

## Running it

Needs Python 3.11 with Blender's Python module:

```bash
pip install bpy==5.0.1 scikit-image scipy pillow
```

Then, from this folder:

```bash
python preview.py red_fox fox.png        # four views, to check the shape
python strip.py red_fox walk walk.png    # one animation as a filmstrip
python sprites.py red_fox                # writes game/art/units/red_fox/
python set_import.py                     # after Godot imports the new files
```

`python sprites.py red_fox --style real` renders the real-proportioned
animal with fur instead. `python arena.py` renders the arenas (about 5
minutes each; `--only <arena>` for one).

A full animal takes about 7-15 minutes on four CPU cores (the fidget and
second attack add about half again). `--anims new` renders only the
animations a sheet doesn't have yet and repacks the rest. To redo one
animation after changing it in `motion.py`, keeping the rest of the sheet
(the eye data is written again for every animation):

```bash
python sprites.py red_fox --anims death --only sprites
```

That only works while the creature's size is unchanged since its sheet was
rendered; otherwise it stops and says to render everything.
