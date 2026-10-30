# Creature pipeline

Makes the battle sprites and card portraits for each animal, and the
treehouse dens, with Blender, from code: no hand modeling, so everything
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
   (pounce-bite, bite, swipe, charge, stomp, throw) and death, as poses.
5. **Render** (`sprites.py`): Cycles with Freestyle outlines, an
   orthographic camera at the game's 50-degree angle, five directions (the
   game mirrors the other three).
6. **Dens** (`treehouse.py`): the side and main treehouses in each team's
   color and their ruins, from the same camera, into `game/art/towers/`.

Each animal is one file in `species/`.

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
animal with fur instead. `python treehouse.py` renders the dens.

A full animal takes about 7-15 minutes on four CPU cores. To redo one
animation after changing it in `motion.py`, keeping the rest of the sheet:

```bash
python sprites.py red_fox --anims death --only sprites
```

That only works while the creature's size is unchanged since its sheet was
rendered; otherwise it stops and says to render everything.
