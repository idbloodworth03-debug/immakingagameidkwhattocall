# Creature pipeline

Makes the battle sprites and card portraits for each animal with Blender,
from code: no hand modeling, so every animal can be rebuilt or tweaked.

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
5. **Render** (`sprites.py`): Cycles, an orthographic camera at the game's
   50-degree angle, five directions (the game mirrors the other three).

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

A full animal takes about 7-10 minutes on four CPU cores.
