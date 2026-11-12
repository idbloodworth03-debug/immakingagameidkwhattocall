# Creature pipeline

> **New animal art no longer comes from here** (November 2026): the game is
> moving to bought art packs, brought in by `tools/packs/`. This pipeline
> still makes the current animals' art, the arenas and the crowd strips,
> and `sprites.py` and `scene.py` are shared with `tools/packs/render.py`.
> `tools/toys/` is a test of making our own animals in the packs' flat
> style, on this pipeline's shape kit, skeleton and motion.

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
   game's knockouts are a cartoon poof. The attacks of the animals on the
   roster of `strikes.json` are played from key poses instead (`strikes.py`:
   see "Attacks" below); the ones written here stay as the cards' poses.
5. **Render** (`sprites.py`): the card portraits and the sprite sheets (the
   game shows its animals as 3D models now, from step 8; the sheets are its
   fallback, its timing data and the source of the crowd strips; the web
   build leaves the sheets' pictures out, which keeps its download a third
   the size). Cycles
   with Freestyle outlines (one deep,
   crisp line; the game's shader no longer adds a second), an orthographic
   camera at the game's 50-degree angle, five directions (the game mirrors
   the other three). How it looks is all in `look.json`: Blender's
   Standard view transform with a contrast look (cartoon colors as
   painted), a soft key light with a warm fill (no harsh white glare), skin
   with little sheen and no subsurface haze, painted vertex colors evened
   out so color borders are clean edges rather than streaks, 32 samples
   with denoising, and the resolution (84 pixels a tile, 1.5 times the old
   56, so animals stay sharp on a phone). Sheets and portraits are saved
   lossless; the game compresses nothing in them (`set_import.py`, from
   `look.json` "import"). A sheet over 4096 pixels on a side goes onto more
   pages (`sheet_1.webp`...). It also writes where the eyes are in
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
7. **Crowd strips** (`crowd.py`), for the life round the arenas
   (`game/data/arena_life.json`): a few animations of each animal the
   arenas use, one direction each (idle and a cheer facing the field, a
   side-on run for runners), cut from its sprite sheet and shrunk to 64
   pixels a tile, into `game/art/arenas/crowd/`. Plain Python, seconds;
   run it again after re-rendering an animal. The arenas' set pieces (a
   ranger station, a jeep, an igloo...) are in the same data file and
   `arena.py` builds them into the picture, keeping the crowd's strip
   behind the far fence clear.
8. **3D models** (`export_gltf.py`), for the game's 3D animal viewer: the
   same cartoon animal as one smooth mesh (the body cut down to about
   16,000 triangles, ears, eyes, nose and claws joined on), its vertex
   colors (sRGB-encoded: the game keeps them in 8 bits), its skeleton, and
   idle, fidget, attack, victory (and a Stun animal's special) baked at 30
   keys a second. The big cartoon eyes carry their eyeball coordinates in
   their UVs, so the game draws the pupils crisply at any zoom. About 0.9 MB
   and 10-20 seconds per animal, into `game/art/models/<id>.glb`. Settings:
   `look.json` "model".
9. **Dens** (`treehouse.py`, not used by the game any more): side and main
   treehouses in each team's color and their ruins. It writes into
   `game/art/towers/`, which the game no longer has.

10. **Materials and studio lights** (`materials.py`), for the
   animated-movie pass (the style guide is in `docs/ART_DIRECTION.md`):
   the shared material library every animal is built from (short, long
   and fluffy fur as real groomed strands; feathers as overlapping cards;
   scales; shell; skin; horn, tusk and claw; eyes with a glossy cornea for
   the catchlight) and the standard studio lights (a soft warm key, a cool
   fill, a rim light and a soft sky). All their numbers are in `look.json`
   "materials" and "studio". `python material_sheet.py out.png [samples]`
   renders one sample of each under those lights (`--quick` for a half-size,
   thin-haired check in a minute or two).

11. **The movie look** (`movie.py`, `movie.json`), the animated-movie pass
   itself, one design per animal that has moved to it (the Yeti, the
   Komodo Dragon and the Peregrine Falcon first): the
   cartoon shape with its own proportions, eyes set under a brow with an
   iris, a bare face with a muzzle, nose and grin, fingers and toes with
   nails, horns, and a coat in the bold palette with a deeper shade between
   the clumps. Hero art (`sprites.py --only portrait`, `preview.py`) grows
   real strands and uses the material library and studio lights, with no
   outline. The real-time models (`export_gltf.py`) get the same coat as
   sculpted fur locks (fine for the viewer, chunky for the battle), or as
   feather cards (`surface: feathers`), or scaly skin the game's shader
   draws the cells on (`surface: scales`), or bare leathery skin
   (`surface: skin`, wrinkles bumped into the hero render) or a turtle's
   plated shell over scales (`surface: shell`), named `<id>_movie` so the
   game draws them with their own shader. The website opened with
   `?viewer=<id>` (dev tools on) goes straight to that animal's viewer
   (`&pose=attack:0.6` holds a pose), and with `?showcase=<id>&slow=1` to
   its attack showcase, slowed down. Every number
   is in `movie.json`; `cartoon.load(id)` gives any listed animal the movie
   look. A coat's `length` is its longest part's (the parts in `lengths`
   are shares of it: a lion's mane 3.2 means the coat is a third of the
   mane); the locks' `contrast` says how much shorter the short parts come
   out in the real-time models. Markings stay crisp with `paint_smoothing`
   (rounds, instead of look.json's) and `stripes: {edge, width}` (harder
   edges and wider bands than the species draws). `FRAME=head FUR=0 python preview.py yeti head.png` checks a face
   fast (`FUR=0`: no strands; `FRAME=head`: a close-up). Its animations
   can be its own too (`movie.json` "motion"): a persona in `motion.py`
   PERSONAS gives it its own idle, fidget and victory (the Yeti breathes
   heavily and sways, shakes snow off and yawns, beats its chest and
   roars), and an attack built for it (`pound`: fists hauled overhead with
   a beat of hang time, then slammed down with the whole body, squashing
   low and settling), on the animation principles in
   docs/ART_DIRECTION.md: anticipation, weight, follow-through, arcs,
   squash and stretch. `STYLE=movie python strip.py yeti attack out.png`
   shows one as a filmstrip.

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

## Attacks

An attack has to read in a fight: from the game's camera, which looks down
on an animal from behind (your own) or from the front (the enemy's), on a
phone, in a crowd. The attacks written as curves in `motion.py` didn't: a
paw lifted and came down, and from the game's camera the animal's outline
hardly changed.

**What we measured** (November 2026; `strike_check.py` does it). For a
clip, seen from behind and from the front as the game sees it: how much of
the animal's outline is newly covered or uncovered against how it stood
(a share of the outline's area), at the wind-up and from the wind-up into
the blow.

| Clips | Outline change from behind |
| --- | --- |
| Our attacks as they were: Bear swipe, Wolf bite, Cobra spit | 0.23, 0.18, 0.18 |
| A toy-style pack's attacks (Quirky Series free sample: snake, monkey, bird, squid, deer, muskrat, gecko) | 0.24 to 0.85, half of them over 0.4 |
| A low-poly pack's attacks (Quaternius, CC0: wolf, fox, yeti, dragon) | 0.29 to 0.68 |

The packs' clips are reference only: watched frame by frame and measured,
nothing of theirs is in ours. What the good ones share:

* **The wind-up goes the other way first, with the whole body**: it rears
  or pulls back, the head and the striking limb with it, and holds for a
  beat.
* **The strike takes a frame or two** and carries the whole body through
  where it stood: low and long where the wind-up was tall and gathered.
* **Loose parts trail and overshoot**: the tail flips up after the body
  has stopped, ears lay back and spring up.
* **From above, sideways and turning motion shows; motion toward the
  target hardly does.** A paw flung out to the side, a body twisting, wings
  opening, a hood spreading, a jump: these change the outline. A paw
  brought straight down in front of the chest is hidden by the body.

**How an attack is written** (`strikes.json`, played by `strikes.py`). A
style is a short list of keys, each a moment and a pose and how the pose
is arrived at:

    "keys": [[0.0, "rest"], ["hit-0.24", "windup", "out"], ["hit-0.09", "coiled", "linear"],
             ["hit", "strike", "in"], ["hit+0.07", "follow", "out"], ["hit+0.24", "recoil", "inout"], [1.0, "rest", "inout"]]

Moments are shares of the clip, or the clip's hit moment plus or minus one
(`motion.HIT_AT`, unchanged: the game lands its hits on it, and a clip's
length is unchanged too). `out` brakes into a pose (a wind-up settling),
`in` speeds into it (a blow landing at full speed), `linear` creeps (the
held beat: "coiled" is the wind-up a little further).

A pose is turns in radians on top of the animal's stance: of the whole
body (`rear` nose-up on the hind feet, `dip` nose-down on the front feet,
`pitch`, `turn`, `roll`), `move` [right, forward, up] in shoulder heights
(field tiles for a flier), `squash`, `stretch` and `swell` of the whole
body, `bones` {bone: [x, y, z]}, and shorthands for `legs`, `wings`,
`tail`, `trunk` and `ears`. `scale` resizes a bone (a paw grown for the
blow, a hood spread wide, a short toy arm stretched so it shows) and
`shift` slides one along itself (a head thrust out on its neck): these
are new with the key poses, and go through the bake (`export_gltf.bake`),
the pack converter and the game as bone sizes and positions. `lag` lets a
tail or the ears run a little behind the body, `wobble` springs them to a
stop after the hit, `shiver` trembles them through the held beat (a
rattling tail). A `stance` is the pose the clip starts and ends in where
that isn't the rest pose (the Squirrel sits up to throw, as it idles).
`bodies` holds a body plan's own version of a style (a snake's spit) and
`animals` an animal's own changes on top.

**The reach rule** (`strikes.py`). In a fight a melee animal stands its
reach from its target (`bodies.json`: a quarter of its length, typically),
and the game's own lunge carries it part of the way. So a clip may bring
the animal's front (its nose, a paw) forward by at most `reach_at_hit` of
its reach at the hit and `reach_most` at any time (`strikes.json`
"limits"; a shooter and a flier have their own allowance), and its back
end back by at most `back_tiles`. A clip that asks for more has its own
steps forward and its bones' slides scaled down to fit; a lunge (`fill`)
has them let out instead, as far as the reach allows, so a low-slung
animal lunges as far as a tall one. Where a pose still passes the mark (a
long arm, a head bowing), the body is held there as if it met a wall while
the pose carries on. Write poses whose limbs reach only a little past the
nose and put the lunge in `move`: the rule then fits the same style to
every animal's reach. (It reads `bodies.json` and the battle models'
scale, so an animal whose reach or size changes wants its clips built
again.)

**The standard** (`strikes.json` "standard"; `strike_check.py` marks a
clip under it "low"): from behind and from the front, the wind-up changes
the outline by at least 0.4 and the blow changes it from the wind-up by at
least 0.5; the tallest moment stays within `bodies.json` "limits"
pose_allowance of how it stands (the camera makes room for no more).

    python ../toys/build.py brown_bear        # the model, with its clips
    python strike_check.py brown_bear         # the numbers
    python strike_check.py                    # everyone on the roster

**The roster** (`strikes.json` "roster"): the animals whose attacks are
played from key poses. The sample was the Bear (swipe, slam), the Wolf
(bite, pounce), the Squirrel (throw, lob), the Falcon (dive, rake) and
the Cobra (spit); the Tanks followed (the Elephant's stomp, the Rhino's
charge, the Panda's swipe, the Hippo's bite, the Turtle's bite and charge,
the Yeti's pound); the other classes follow.

An animal gets its own version of a style where its build asks for one:
the Hippo's bite is a yawn thrown open to the sky and brought down, the
Turtle's a neck shot out of the shell, the Elephant's stomp keeps its
trunk from reaching past its feet.

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
python crowd.py                          # the arenas' crowd strips
python export_gltf.py red_fox            # writes game/art/models/red_fox.glb
python export_gltf.py --all              # every animal in data/animals.json
python set_import.py                     # after Godot imports the new files
```

`python sprites.py red_fox --style real` renders the real-proportioned
animal with fur instead. `python arena.py` renders the arenas at 64
pixels a tile, saved lossless (about 6-12 minutes each; `--only <arena>`
for one).

A full animal takes about 12-30 minutes on four CPU cores at 84 pixels a
tile (the Red Fox: 15 minutes; big animals and ones with more animations
take longer); all 35 about 12-15 hours. `--anims new` renders only the
animations a sheet doesn't have yet and repacks the rest. To redo one
animation after changing it in `motion.py`, keeping the rest of the sheet
(the eye data is written again for every animation):

```bash
python sprites.py red_fox --anims death --only sprites
```

That only works while the creature's size is unchanged since its sheet was
rendered; otherwise it stops and says to render everything.
