# Art, Sound and Name

## Style guide: the animated-movie pass

Where the animals are going: the craftsmanship of a modern animated movie
with our goofy cartoon personality and our bold, saturated palette. The
quality target is the reference Yeti (a big, simple, appealing shape with
rich, touchable surface detail on top). We take its **craft**, not its
pale, washed-out colors. Numbers live in `tools/creatures/look.json`
("studio", "materials"); the shared materials are
`tools/creatures/materials.py`; `material_sheet.py` renders them all.

### 1. Shape language

Big simple shapes first, detail second: every animal must read as one
appealing shape when filled in solid black. Proportions are pushed about
1.3 to 1.5 times past real life, with contrast between big and small parts
(a huge torso against short legs, a big head against a small muzzle) and
between straight and curved lines. Heads stay a quarter to a third of the
body's height, so faces read on a card.

| Class | Shape | Silhouette | Examples |
|---|---|---|---|
| **Tanks** | Huge chunky bodies: the torso over half the height, thick forearms, short sturdy legs, the head sunk into big shoulders. Slow, heavy, planted. | A boulder or a rounded triangle, wide at the bottom. | Brown Bear, Hippo, Elephant, Black Rhino, Turtle, Panda, Yeti |
| **Tank Destroyers** | Lean and powerful: a deep chest, a narrow waist, long limbs, leaning forward, big jaws or tusks. | A wedge pointing at the enemy. | Lion, Tiger, Wild Boar, Wolf Pack, Honey Badger, Komodo, Cerberus |
| **Ranged** | Smaller and nimble: a light body, a big head and big hands or paws (what they throw or shoot with), big alert eyes, perky ears and tails. | Small, upright, a clear head and hands. | Squirrel, Raccoon, Skunk, Cobra, Orangutan, Camel, Unicorn |
| **Air** | Elegant wings at least twice the body's width, long primary feathers in clean S-curves, a small light body. | A V or an arrow in flight, a teardrop at rest. | Falcon, Owl, Harpy Eagle, Macaw, Condor, Dragon |
| **Specialists** | Distinctive and quirky: one exaggerated signature feature. | That feature, first. | The Fox's huge tail, the Pangolin's plates, the Sloth's long arms, the Eel's zigzag, the Gorilla's chest, the Seal's round belly, the Red Panda's ringed tail, the Kraken's tentacles |
| **Mythics** | Grand and impressive: a heroic upright posture, the biggest presence on the field, and one magical element that glows. | Tall and crowned. | Yeti's frost horns, Cerberus's three heads with ember eyes, Unicorn's rainbow mane and horn, Dragon's wings and glowing throat, Kraken's glowing suckers |

### 2. Material library

![The material library under the studio lights](art/material_library.jpg)
(`tools/creatures/material_sheet.py`: front row short, long and fluffy fur,
feathers, scales; back row shell, skin, horn and claw, eye, nose.)

Every animal is built from the same materials, each starting from a color
in our palette and adding the craftsmanship: shading from root to tip,
grooves, gloss. Never a pale or gray-washed version of the color.

- **Fur** (short, long, fluffy): real strands for hero art, groomed into
  clumps (child strands gathered round each guide), combed down and back,
  darker at the root and lighter at the tip, each strand a shade
  different. Short: a fox's sleek coat. Long: a yeti's or bear's shaggy
  coat that hangs. Fluffy: soft, slightly curly down (a panda's, a
  chick's). The skin under the fur is a deeper shade of it, so the gaps
  between clumps read as soft shadow.
- **Feathers:** overlapping cards laid along the body like shingles, each
  bending to follow the body, darker at the base with a pale edge, a stiff
  pale shaft and fine barbs, with a soft sheen.
- **Scales:** small domed cells with deep grooves between, each a slightly
  different shade, a light waxy coat.
- **Shell:** big plates with grooves and growth rings, a glossy coat.
- **Skin** (faces, hands, noses, bellies): soft and a little translucent,
  faint mottling, a soft sheen. Noses darker and glossier.
- **Horns, tusks, claws:** horn and tusks ivory to a darker tip with fine
  ridges and a satin shine; claws and nails dark and glossy.
- **Eyes:** see 4.

### 3. Lighting

One studio setup for every hero render, so every animal belongs to the
same game (look.json "studio"):
- A big **soft key light** from the front-left above, warm white: gentle
  shadows, no harsh white glare.
- A soft **cool fill** from the right, so shadows keep their color.
- A **rim light** from behind that traces the silhouette (this, not an
  outline, separates the animal from the background in hero art).
- A soft **sky** all round that fills creases and the gaps between fur
  clumps with soft occlusion.
- A soft **contact shadow** under the feet.

The battlefield matches it: the same key direction (top-left on screen),
the same warm-key and cool-fill split, and a soft shadow under every
animal.

### 4. Eyes and faces

- Eyes have a colored iris (each species its own), a big pupil and a
  glossy cornea, so the key light puts a crisp **catchlight** in the upper
  left of every eye. Whites are a warm off-white. No more flat white
  googly circles: eyes are smaller than today's, set into the face, with
  lids.
- Every face has readable features at card size: a clear muzzle shape, a
  mouth line with corners that can smile, and brows (a ridge or a fur
  tuft) that carry the expression.
- An expression set every animal shares: friendly (idle), determined
  (wind-up), ouch (hit), proud (victory), dizzy (defeat). The goofiness
  stays in the expressions and reactions, cleanly drawn.
- Heads turn three-quarters toward the camera in portraits.

### 5. Outlines

- **Hero art** (card portraits, the 3D viewer, cage reveals, the VS
  screen): **no drawn outline**, like the reference. The rim light and the
  contact shadow separate the animal from its background.
- **Battlefield:** keeps the bold team-colored band and a dark inner line,
  for reading who's who in a big army.
- UI icons and badges keep their outlines.

### 6. Two levels of detail

- **Hero art:** full detail (strands, feather cards, grooves), rendered in
  Cycles at 512 pixels or more.
- **Battlefield models:** the same design and colors, simplified for the
  size they're seen at (about 60 to 110 points tall on an iPhone): fur as
  a few big, chunky sculpted clumps in the mesh instead of strands,
  feathers as a few big layered shapes, scales and shell as painted
  pattern, and the soft occlusion between clumps baked into the model's
  colors. Shading is soft and smooth, lit like the hero art. No detail
  smaller than a few screen pixels, so nothing shimmers. Only the animals
  in a match are loaded (as now).

### 7. Animation and effects (for the later steps)

- Animation: anticipation (a clear wind-up before every attack), timing
  and weight by size, follow-through and overlap (fur, ears, tails,
  bellies settle after the motion), arcs, controlled squash and stretch,
  and personality in every idle, attack, hit, victory and defeat.
- Effects: every one in three phases (build-up, impact, fade), layered (a
  bright core, a softer glow, particles, a shockwave for big hits), one
  look per element (ice, fire, rainbow light, lightning, venom, ink, dust),
  strong clear shapes, the Mythics' the biggest, all bright and solid and
  60 fps on an iPhone with big armies.

## Readability: chibi proportions, a tilted camera, hero cards

The best mobile games in this genre (Clash Royale's Merge Tactics, Clash
Mini, Squad Busters, Brawl Stars) make every character readable at a glance
on a phone. The rules (pipeline test on the Brown Bear, Peregrine Falcon and
King Cobra first, then every animal):

- **Chibi proportions**: about 2-3 heads tall, a big round head, a short
  body, big expressive eyes and face, the animal's real features and
  personality exaggerated. `tools/creatures/movie.json` shape: head (size),
  head_lift and head_forward (the big head sits up on the shoulders, where a
  tilted camera sees the face), neck, skull_round (a round head), jaw (a small
  chin), legs, length; ear_shape (round ears), muzzle (a muzzle in its own
  paint, a bear's tan snout), nose, mouth; species (the animal's own joints
  and sizes for its design only: a falcon's plumper body and stubbier wings,
  a cobra's shorter coil and bigger hood).
- **Silhouette, colors and one signature feature**: filled in solid black,
  the animal is still recognizable; 2-3 main colors and one exaggerated
  signature (the bear's round head and ears, the falcon's dark helmet and
  yellow eye rings on a blue-gray back, the cobra's hood).
- **A tilted battle camera**: `game/data/feel.json` camera tilt_degrees (how
  far it leans from straight down: 52, so it looks down 38 degrees from
  level and sees fronts and faces, not backs). The arenas, sprites and the
  game's 3D models all use it (`sprites.py` ELEVATION reads it).
- **Bigger animals**: `game/data/bodies.json` limits: a typical animal
  stands about average_target_pct (8%) of the phone screen's height, the
  biggest Tanks unit_max_pct (11%) and a Mythic hero hero_max_pct (12%); an
  attack or a celebration may rise pose_allowance (1.4) above that for a
  moment. Once the armies are at war the camera frames where the fighting
  is (feel.json army camera_fight_*). The camera stops zooming in when the
  tallest animal on the field reaches its limit, so the drawn sizes
  (bodies.json size) are set by class from each animal's standing height
  (its outline as the size limit measures it, ModelStage natural_box up):
  a Tank 1.0, a Mythic about 1.06, a Tank Destroyer, Ranged animal or
  Specialist 0.86-0.96 and a flier 0.84 of a Tank's (a flier's wings
  spread out wide besides), growing a long, flat animal at most 1.45
  times and never past twice its footprint. No Specialist or archer then
  stands taller than the Tanks and holds the camera back for everyone:
  the feel report's small fights average 7.6% of the screen's height,
  big ones 6.2% (6.9% at war; the line-up frames the whole army). The
  camera stops bodies.json limits camera_margin_pct (7.5%) short of the
  limit, for the squash and stretch and a flier's wingbeat on top.
- **Hero cards**: every card portrait from the same camera (look.json
  hero_portrait: a three-quarter front view, the same lens and framing), the
  same studio lights, the animal facing us with an expression in a
  signature pose showing its attack style (motion.py hero_*: the bear
  reared up mid-swipe roaring, the falcon diving at us, the cobra hissing
  with its hood up; a bird or the Dragon swoops at us with its wings
  raised in a V over its back, `_wings_up`, so a wide wingspan doesn't
  shrink it on the card), filling about 70-80% of the card. The Mythics
  get the most dramatic poses.

All 35 animals are on these rules now (rolled out in batches after the
pipeline test). Where a signature didn't read on a chibi body, its species
module grew a design switch, set in `movie.json` species R (the defaults
draw the animal as before): the camel's humps (hump, hump_at, hump_z), the
harpy eagle's crest (crest_k, crest_lift, crest_fan), the barn owl's white
heart face (face_heart, face_k, face_lobes), the dragon's horns and wings
(horn_k, wing_k), Cerberus's heads (side_spread, side_snout_k, side_ear_k),
the lion's mane ruff (mane_k), the wild boar's tusks (tusk_k), the skunk's
stripes (stripe_k), the macaw's slimmer beak (beak, jaw) and the kraken's
tentacles raised beside its head (arm_lift). A card pose built from a bite
uses the lunge, not the full gape (head on, wide-open jaws look like a
tube); side-on poses show a tail, a shell or stripes; some come from the
animal's own celebration (the gorilla's roar, the pangolin popping up).

## Where the look is now

**The Yeti is the first animal on the animated-movie look** (the style
guide above). It is built by `tools/creatures/movie.py` from its design in
`tools/creatures/movie.json`: the cartoon's shape with gentler proportions,
a bare blue face with a muzzle, a nose and a grin, eyes set under a brow
with a blue iris and a catchlight, fingers and toes with dark glossy nails,
horns swept back, and a shaggy white coat with icy-blue shadows. Its card
portrait grows real groomed fur strands and uses the material library and
the studio lights, with no outline. Its real-time models carry the same
coat as sculpted locks in the mesh: about 560 fine ones for the 3D viewer
(33,000 triangles, 1.5 MB, from 21,000 and 0.9 MB) and 70 chunky ones for
the battlefield (5,400 triangles, 318 KB, from 3,400 and 227 KB), drawn by
their own shader (`game/scripts/fx/model_movie.gdshader`, values in
`game/data/viewer.json` "movie_look") with the studio lighting, strand
detail that fades out before it can shimmer, and eyes with an iris. In
battle it keeps the dark line and team band, drawn round the animal's
edge and not round every lock.

**The Komodo Dragon and the Peregrine Falcon followed** (the scales and
feathers of the material library). The Komodo is scaly all over: bold
green with a sandy belly and orange flecks, an amber eye under a brow, a
grin and a pink forked tongue, bigger claws; its portrait uses the domed
scales material and its real-time models' shader draws the scale cells
from the model's own shape (no extra geometry or memory: 21k triangles and
0.9 MB in the viewer, from 24k and 1.0 MB). The Falcon keeps its own markings in the
bold palette (a navy helmet, a steel-blue back, a cream barred breast,
yellow feet), with feather cards laid over its body like shingles: 650
small ones in the portrait, 240 bigger ones in the viewer (20k triangles
and 0.9 MB, from 18k and 0.75 MB) and 40 chunky ones in battle (3.1k
triangles and 205 KB, from 2.9k and 182 KB), each shaded darker at the
base with a pale edge and shaft by the shader.

**The Yeti moves and strikes like a movie character** (step 4; the
principles in section 7 of the style guide). Its animations are its own
(`tools/creatures/motion.py`, a "persona" picked in `movie.json` "motion"):
an idle of slow deep breaths that lift the shoulders, a sway from foot to
foot with the long arms swinging a beat behind, and a slow look about; a
fidget that shakes the snow off and then stretches and yawns; a victory
that beats its chest and flings both arms up with a roar and a hop. Its
pound is built on anticipation and weight: it rocks back and hauls both
fists overhead, slowing into a beat of hang time, then pitches forward and
slams both fists down, squashing low, the head and shoulders overshooting
and bouncing back before it settles. Its ability effect has three phases
(`game/scripts/fx/fx_layer.gd` "ice_blast", numbers in `game/data/feel.json`
"styles"): the build-up, frost gathering onto its fists during the wind-up
before a pound; the impact, a white core flash, an icy glow, a shockwave
ring racing out, ice shards bursting up out of the ground round it, frost
cracks across the ground, snow thrown up and a shake; and the fade, the
shards melting back as the frost patch it leaves settles in. An enemy
frozen on the frost gets a smaller burst of the same.

**The Tanks followed** (the first rollout batch): the Brown Bear in a
shaggy warm-brown coat with grizzled tips, clawed toes and a grin; the
Giant Panda in fluffy white and black with its eye patches; the Hippo,
Elephant and Rhino in bold leathery skin (surface "skin": wrinkle folds
bumped into the hero renders, ivory tusks and horns, toenails); the
Snapping Turtle with a mossy plated shell (the shell material on the
shell's faces, the painted scute lines kept) over scaly skin. All keep
their own markings, re-colored into the bold palette (movie.json "paint":
"species" with a palette swap). Their models carry fur locks only where
there is fur (the Bear and Panda: about 1,000 fine overlapping locks, 51k
triangles in the viewer and 6.4k in battle, from 21k and 3.3k; the
viewer shows one animal at a time, so that is the one place the budget
is spent); the skin animals grew only by their toes and tusks (4.2k in
battle, from 3.3k) and the Turtle not at all. The lock tips brighten in
their own hue, never toward white: on a brown or black coat, white-mixed
tips read as pale flecks, and short sparse locks read as bumps; a coat
reads as fur when the locks are long, flat, overlapping and dense. The
other animals keep the flat cartoon look below until they move over.

**The Tank Destroyers followed** (batch 2): the Lion in a golden coat
with a deeper, shaggier mane; the Tiger with bold black stripes over
orange and a white chin; the Wild Boar in a coarse grizzled coat with a
dark bristle crest, tusks and a pink snout; the Wolf Pack in a thick
blue-gray coat with a cream chest; the Honey Badger black with its silver
cape; and Cerberus, brown with three heads and a glowing red collar. Three
things learned here, all settings in `movie.json`: a coat's "length" is
the length of its *longest* part (parts are shares of it, so a lion's
mane sets the number and its coat is a third of it; the real-time locks
follow with "contrast"); markings stay crisp with fewer rounds of paint
smoothing ("paint_smoothing") and harder stripe edges ("stripes":
{"edge", "width"}); and dark coats need a little less shine than light
ones. Every Tank Destroyer carries the dense lock set (about 1,000 in the
viewer, 110 in battle), so their models cost about what the Bear's does.

**The Ranged animals followed** (batch 3): the Gray Squirrel in blue-gray
with a brown wash and a huge fluffy tail; the Raccoon in a violet-gray
coat with its black mask, white brows and ringed tail; the Striped Skunk
glossy black with the white stripe splitting over its back and tail; the
King Cobra, the first snake on the look, in olive-green scales with
yellow bands and a cream hood (surface "scales"); the Wild Bactrian Camel
golden with shaggy darker humps, neck and legs; the Sumatran Orangutan in
a long bright-orange coat with a gray face, cheek pads, beard, fingers
and toes; and the Unicorn, a sleek white horse with a pastel-rainbow fur
mane and tail, a golden horn and hooves. Every fur animal carries the
dense lock set; the Cobra, like the Komodo Dragon, carries none.

**The Air animals followed** (batch 4, after the Peregrine Falcon): the
Barn Owl in white and golden tan with its heart face; the Harpy Eagle
slate black and white with its gray crest and yellow feet; the Hyacinth
Macaw in bold cobalt with the yellow eye ring and a black beak; the
California Condor black with the white wing triangles, a bare pink-orange
head and an ivory beak; and the Dragon in emerald scales with a golden
belly, orange spikes, golden horns and glassy pale-green wings. The birds
wear feather cards sized to each bird (an eagle's twice a falcon's); the
Dragon, like the Komodo Dragon, is scales and carries no locks.

**The Specialists closed the rollout** (batch 5): the Electric Eel in
smooth slate-blue skin with an orange throat; the Harbor Seal in smooth
spotted blue-gray with a pale belly; the Red Fox in a bold orange-red
coat with a white ruff and a big brushy tail; the Mountain Gorilla in
long near-black fur with the silver saddle, a bare face, chest and hands
with fingers; the Red Panda fluffy rust-orange with its white face
markings and ringed tail; the Pygmy Three-toed Sloth in shaggy tan fur
tinted moss green, with its smiling face and long claws; the Sunda
Pangolin in big overlapping golden-brown scales (surface "scales" with
large cells); and the Kraken, a smooth coral-red octopus with huge eyes
and pale suckers. Every animal in the roster is now on the movie look.

**The effects pass** (step 6): every attack and ability effect is built
from the same three phases and the same layers, in an element's look
(`game/data/feel.json` "elements"; `fx_layer.gd` "blast" and "linger",
`battle_field.gd` `_blast`, `style_look.gd` `_gather`). The build-up is on
the animal: the element's particles drawn in from all round onto its
fists, horn or mouth with a glow swelling there (the Yeti's frost, the
Lion's gold breath before a roar, the Unicorn's light at its horn, the
Kraken's water, the Gorilla's dust). The impact is layered: a white-hot
core flash, the element's glow swelling and thinning, a shockwave ring
racing out, and the element's bits flying out of it (ice shards, flames,
leaves, rocks, drops, stars, wisps, wind streaks, lightning bolts,
sparks), each kind moving its own way (rocks and drops arc and fall,
flames and wisps rise, leaves drift, shards and stars spin), with its
particles. The fade is a stain of the glow on the ground with a few bits
settled in it, flickering out. Every attack style has its element
(fire for Cerberus and the Tiger's pounce, frost for the Yeti, light for
the Lion's roar and the Unicorn's beam, water for the Kraken and the
Seal, lightning for the Eel and the Macaw's crack, earth for the charges,
slams and digs, nature for the Panda and the Turtle, venom, wind for the
birds' strikes, dark for the Condor's feast and the Kraken's ink, stink
for the Skunk), and plain hits get a small "impact" burst. A Mythic's
burst is the big one: two shockwave rings, twice the bits, longer, and a
shake; a slam, a charge's end and a flip get the big one too. In a crowded
fight the bits are halved. Numbers: `feel.json` "elements".

**Personas, class by class** (after the effects pass; `motion.py`
PERSONAS, picked in `movie.json` "motion"): each animal gets its own idle,
fidget and victory on the animation principles in section 7, the Yeti's
being the model. The Tanks first. The Brown Bear hangs its head low and
swings it, sniffing the air at the top of each swing; sits back on its
haunches to scratch its belly in lazy circles; and rears up to its full
height roaring and boxing the air before thumping back down. The Giant
Panda sways dozily and chews; plops onto its bottom, rubs its tummy and
rolls onto its back kicking; and sits up clapping its paws over its head.
The Hippo breathes slow and heavy with its ears and tail flicking; yawns
the famous yawn, held a long beat and snapped shut with a head shake; and
stamps and roars with its bottom wiggling. The Elephant shifts its weight
with its ears flapping and trunk swinging; trumpets with the trunk curled
back over its forehead and a stamp; and rears with the trunk straight up
and the ears flared. The Rhino holds its horn low and scrapes a hoof;
paws the ground three times, snorts twice and shakes its head; and hops
with its horn tossed up and its tail straight up. The Snapping Turtle's
head creeps out of its shell and back; it pulls right in and shoots out
with a snap and a hop; and stands tall on straight legs snapping at the
air. Each idle loops, each fidget starts and ends on the idle, and each
victory loops, so the game can play them whenever it likes.

The Tank Destroyers next. The Lion stands tall and surveys the field,
its mane settling with a shake; does a cat stretch with a huge yawn and
shakes out its mane; and rears with a paw raised to roar with its head
thrown back, then sits proudly. The Tiger stands coiled and low, scanning,
its tail lashing; sits to lick a paw and wipe its face; and pounces on the
spot, claws out and jaws wide. The Wild Boar snuffles along the ground
rooting with a hoof; digs with its snout and tosses its head up with a
snort; and bucks, hind legs kicked high, squealing. The Wolf stands alert,
ears pricked, checking one way then the other; sits and howls, muzzle
straight up; and howls in triumph, then prances. The Honey Badger shifts
restlessly, nose twitching, head jerking about; sits and scratches behind
its ear with a hind leg; and hops with both paws up in a cocky strut.
Cerberus's heads swing and pant, never agreeing; they squabble, the neck
whipping and the jaws clacking; and it rears with all three heads thrown
back howling fire, forelegs pawing the air.

The Ranged animals. The Gray Squirrel sits up twitchy with its paws held
together and its tail curled over its back; nibbles a nut with its jaw
racing, then drops to all fours and flicks its tail; and bounces on its
hind legs with its paws flung up. The Raccoon hunches, rubbing its paws
together and peering about; washes, rubbing its paws over each other and
over its face; and rubs its paws with glee, hopping, bottom wiggling. The
Striped Skunk holds its tail high like a plume and sniffs along; gives
the warning, stamping its front feet and spinning round to hoist its
tail straight up; and twirls on the spot, tail up like a flag. The King
Cobra sways hypnotically with its hood spread, tongue flicking; draws
back and rises for a mock strike with a hiss; and dances, the whole
raised body weaving. The Camel chews the cud, jaw grinding round, head
bobbing; works up a spit, cheeks drawn back, and lets fly, then grumbles;
and prances with its knees high, nodding. The Orangutan rocks easily with
its long arms swinging a beat behind, lips pursing; scratches its head
with one long arm and its side with the other, then stretches both up
with a yawn; and dances with both arms waving overhead, hooting. The
Unicorn carries its head high on an arched neck, pawing the ground, tail
sweeping; rears and paws the air, then tosses its head with a whinny; and
prances in a proud high-step, horn up, with a little rear.

The Air animals, in the air. The Peregrine Falcon beats quick and crisp,
its head snapping to scan; barrel-rolls and shakes out its wings; and
screws upward in a spiralling climb. The Barn Owl beats slow and silent
with its head swivelling far round; turns its head almost right round to
look behind, snaps it back and ruffles every feather; and loops slowly
with its wings spread wide, hooting at the top. The Harpy Eagle beats
powerfully with a glide between, head proud; screeches with its head
thrown back, wings flung up and talons clenching; and hangs with its
wings held high, screeching skyward. The Hyacinth Macaw beats perkily
with its head bobbing and cocking, squawking; loop-the-loops; and does
the parrot dance, head bobbing up and down and side to side in time.
The California Condor soars on flat wide wings, tilting into slow turns;
banks hard one way and the other and stretches both wings high; and
circles wide, banked into the turn. The Dragon beats steadily with its
tail swishing and a sniff of smoke; has a fire hiccup, rearing back and
bursting out with a jolt, then shaking its head; and loop-the-loops
roaring fire with a happy wiggle. Birds' card portraits are hero poses
like everyone's (see Readability above): swooping at us, wings raised.

The Specialists close the set. The Electric Eel runs slow waves down its
body and lifts its flat head to peer; charges up with a crackling shiver
and lets go with a jolt; and rears its front up and whips side to side.
The Harbor Seal lolls on its belly, rolling a little; claps its flippers
barking, then rolls onto its back wriggling; and bounces on its belly
clapping. The Red Fox stands light on its toes, head cocking, ears
swivelling; does the mouse pounce, nose-first with its paws together;
and bounds in a circle after its own brush. The Mountain Gorilla breathes
slow and heavy, sizing things up; picks at its ear, sniffs the finger,
scratches and yawns; and beats its chest, then roars with its arms flung
wide. The Red Panda bounces curiously with its tail curling; stands up
with its paws raised to look big (the famous threat); and bounces round
in a circle on its back legs. The Sloth takes a whole loop over one
breath; stretches and yawns slower than anything; and celebrates in slow
motion, one arm up, then the other. The Pangolin shuffles shyly with a
scale-rattling shiver; curls into a ball, rocks and peeks out; and spins
as a ball, then pops open with its claws up. The Kraken bobs its big
head with its tentacles curling; blows a bubble that swells and pops;
and spins in a tentacle dance. With these, every one of the 35 moves
like itself.

**Animals are 3D cartoons.** Like Clash Royale, the game is 2D but its
characters are 3D models rendered into sprites, so they look solid and
lit. They are cartoons of the real animals: big heads with big googly
eyes, short chunky legs, round bodies, smooth bright skin and a dark
outline, while keeping each species' shape and markings. Every animal is
built, painted, rigged, animated and rendered by our own Blender pipeline
in `tools/creatures/` (how it works:
[tools/creatures/README.md](../tools/creatures/README.md)). Nothing is hand
modeled, so any animal can be rebuilt or tweaked by editing its file in
`tools/creatures/species/`, and the whole cartoon look is tuned in one
place (`tools/creatures/cartoon.py`).

- **Real markings:** each species starts from real measurements
  (shoulder height, body and tail length) and keeps its real coat: the
  fox's black stockings and white tail tip, the tiger's tapering stripes, the leopard's
  broken rosettes, the cheetah's tear lines, the wild dogs' painted patches,
  the raccoon's mask, the condor's bare head and white underwing.
- **Cartoon faces:** big round white eyes with black pupils and a shine,
  mouths that open on a bite (with fangs or tusks for the cats and hippo).
- **Animations:** idle, walk (trot, walk or gallop), attack and death. Attacks
  fit the animal: pounce and bite (fox, cats), bite (wolves, rats, hippo),
  swipe (bears, raccoon, red panda), charge (boar, bison, rhino), stomp with
  the trunk raised (elephant), sit up and throw (squirrel), stoop and strike
  (falcon, condor).
- **In battle:** sprites from 8 directions (5 rendered, 3 mirrored), 56
  pixels per tile, a soft shadow under each animal, a team-colored ring at
  its feet. A played animal drops onto its spot with a puff of dust. The
  game times each attack so the hit lands on the strike frame, with a hit
  effect that fits it (claw slashes, a bite, dust from a charge or stomp,
  feathers from a strike). A fallen animal topples over and lies still for
  a moment before fading.
- **Cards:** a rendered three-quarter portrait of each animal, framed so
  the whole animal fits.

**Arenas are rendered too** (`tools/creatures/arena.py`), one picture per
arena: an open grass field with faint tile stripes, a worn halfway line and
center ring, a low fence all the way around, and themed scenery outside it
(pines in the Whispering Woods, cacti and red rocks in the canyon, snowy
pines in the tundra, palms on the coast...). They use the same 50-degree
camera as the animals, with the ground stretched so tiles still land
exactly where the game puts them. The menus show a window onto your arena
with two animals from it squaring up on each side.

(The old mode's treehouse dens, `tools/creatures/treehouse.py`, are no longer
in the game; the script is kept in case dens come back as scenery.)

**In the game, the animals get a fake-3D finish and smooth motion** on top
of their rendered frames (`game/scripts/fx/`):
- A shader on every animal (`unit.gdshader`): a warm highlight on the edge facing the light (always top-left on screen, even for mirrored sprites), a cool rim light on the far edge, soft volume shading across the body, outlines recolored to a dark shade of the animal's own colors and thickened a pixel, a little extra color punch, and a pure white flash when hit.
- Motion (`unit_view.gd`): breathing and bobbing, walking hops with squash and stretch, a lean into the run, a wind-up and a lunge on every attack, a springy squash and knockback when hit, an elastic pop-in, hops when moved, and cartoon defeats (a hop, a spin and a poof cloud with stars).
- Size: how big each animal is drawn in battle is `game/data/bodies.json` (its longest side in field tiles, a bird's wingspan), chosen so that on a phone a typical animal stands about 8% of the screen's height in a normal fight, the biggest Tanks at most 11% and a Mythic hero 12% (bodies.json limits). Heights are the animal's real outline on the screen as posed (its mesh skinned to its skeleton, `model_stage.gd model_height_units`; a bounding box would add a fifth or so). The camera never zooms in past those limits for any animal's tallest fight pose (bodies.json pose_up, measured from its animations) whatever the fight (`battle_field.gd _size_zoom_cap`); on a 3D model the cartoon squash and stretch is only a touch on top of its own animation (`feel.json` acting model_squash_share), so its height doesn't pump with every step. The feel report measures them (SIZE: the average, the biggest Tank, the hero, by class, the share of animal-frames over a limit, and the camera's zoom) and `tests/test_sizes.gd` fails if an animal stands over its limit at the closest zoom or gets over it in any frame of a real fight.
- Movement on screen is separate from the fight: an animal is drawn where the fight has it (its place between two fight ticks), followed by a spring so it eases into and out of a run, the same at any frame rate; nudged apart from animals it would cover (`battle_field.gd`); facing where it walks or what it fights, turning at a cartoon pace and never turned by a push; walking only when it moves on its own, with its legs in step with the ground (each animal's own stride, a marching army's too). Mid-swing it holds its ground until the strike is done and catches up after, so it never slides while hitting. Numbers in `feel.json` "movement".
- Bodies never clip into each other: every animal has a footprint (its true size on the ground) and a reach (how far its strike extends) in `game/data/bodies.json`. The fight's room for it is its footprint at all times (spacing, engagement slots, knockbacks, a line in a formation), a melee animal hits from its reach and stands at its slot that far from its target's body, and its lunge never carries the body past the target's footprint (`feel.json` combat lunge_gap_share): a strike reaches with jaws and paws. A shooter's range is measured body to body (its shot flies from its body to the target's, aimed at the body's middle, in the air for a flier), so card ranges mean what they did. Fliers fly at a real height (`feel.json` acting air_height_tiles) so they pass over the animals under them and sort rightly in depth (every model is in one 3D scene, so depth is true depth), and keep clear of each other wingtip to wingtip; a body going down keeps the living nudged clear (`battle_rules.json` spacing body_down_seconds); a Burrow animal underground shows only its mound. Long bodies are a row of circles along their length (`battle_sim.gd` spine), across the body for fliers' wings and upright animals' spread arms (`bodies.json` across), and a melee animal's reach is measured from its front (its nose, or its chest for an upright one). The feel report's BODIES line measures overlaps of drawn bodies, all the time and during strikes, and its PER ANIMAL table gives each animal's size, overlap while striking, sliding while hitting and unread hits; `tests/test_bodies.gd` fails over 1% of striking frames.
- Animation changes are never hard cuts: a 3D model cross-fades into its next animation over `feel.json` "acting" blend_seconds (idle to walk, walk to attack, attack to hit reaction), with the playhead held where the choreography wants it (`model_stage.gd`). A swing always plays at its own pace, every one the same, and plays to its end: a hit dealt while it plays lands in it, never starting another over it; how often an animal hits is the pause between swings (`unit_view.gd time_to_strike`; the class and trait wind-up stretches are 1). Through a swing the body plants its feet where it is drawn: it stands still in the fight for it (`battle_rules.json` swing windup_seconds and recovery_seconds), the crowd can't shove it for the whole drawn swing (firm_before_seconds and firm_after_seconds, covering the longest wind-up and follow-through of any animal), and its walking waits until the swing is done. The feel report's Animation lines measure all of this (hard cuts, swings cut short, sliding while hitting, snap turns, position snaps, feet against the ground).
- Acting (`unit_view.gd`, `unit_face.gd`, numbers in `feel.json` "acting"): each class moves its own way (Tanks plod with a thump and a puff of dust at each step; Tank Destroyers lean in, crouch and pounce; Ranged kick back on every shot; fliers bob, swoop, bank into turns and dive in and pull back up). Animals blink, fidget now and then (a rendered look-around and head shake), alternate two attacks if they're common, flinch and bounce when hit, wobble when stunned, move in slow motion when slowed, sweat when nearly beaten, trip now and then, look smug after a knockout and celebrate when their herd wins (a rendered victory). Faces are drawn over the rendered eyes (where they are in each frame comes from the sprite sheet): a squint on the wind-up, wide eyes when hit, dizzy swirls when stunned or knocked out, drowsy lids when slowed, happy eyes when celebrating. A knockout poofs, or bounces off the screen with a spin. Every animal has a rendered fidget and eye data, and Common animals a second attack; Stun animals have a rendered wind-up for the blow that stuns (a chest beat, a hiss, a roar). Brown Bear, Lion and Peregrine Falcon also have a rendered victory; the rest celebrate with bounces and a spin through their drawn directions. Specialist traits act in the game: Burrow animals sink into the ground and pop out with a boing, Splash animals belly-flop with a splash ring, Slow animals wind up with a lazy yawn. Body plans walk their own way (fish wiggle, upright animals waddle, snakes ripple, frogs bound, seals slide).
- Choreography (`feel.json` "choreography"): a fight opens with both herds hopping into place and a bouncy FIGHT! banner; a dragging ending with few animals left gradually plays faster (never changing what happens); the last knockout plays in slow motion with a push-in, then the winners celebrate and the score pops up. Health bars show once an animal is hurt and fade away when it hasn't been hit for a while.
- Sprite sheets (version 3) crop each animation to its own frame size, so a big pose doesn't make every frame bigger, and pack frames tightly; the unused death frames are left out.
- Hits land on the strike: the fight deals a hit, the attacker's wind-up plays (started then if none was showing), a shot flies if it's thrown, and only then do the flash, sparks, number, health-bar drop and any knockout show.
- Effects (`fx_layer.gd`, `particle_layer.gd`): hit sparks, hit-stop and screen shake on big hits and knockouts only, bouncy damage numbers, chunky health bars with a delayed "damage taken" bar, glowing projectile trails, sparkles, stars, puffs, confetti and coins.
- The arena is toned down a little (`ground.gdshader`) so the animals pop, with drifting cloud shadows, swaying grass and petals, leaves or snow to suit it.
- Every number is in `game/data/feel.json`.

**The menus** are a chunky cartoon style, built in code so the whole look
lives in `scripts/ui/ui_kit.gd`:
- **Buttons** have a pressable colored edge, a gloss and a soft shadow, and sink when pressed (`button_skin.gd`).
- **Panels** are raised (a lighter rim and a drop shadow) or sunken for lists and stats. Text is bold and outlined in deep navy with a drop shadow.
- **Cards** (`animal_card.gd`): a glossy rim in the rarity's color (steel silver Common, orange Rare, purple Epic, teal Legendary, rose pink Mythic), the animal's portrait in a spotlight of its habitat color, a name plate, its class badge in the top-left corner (left out among the cards under a class's own header, which already says it: Section 7 of the readability pass), and at the bottom its level on a round badge with a small bar under it filling with copies toward the next upgrade (blue, green with an arrow once it can be upgraded, gold at the top level; ui_style.json card). Rarity shows only in the frame's color; the biome is in the animal's details (the hold-for-info popup, the 3D viewer, the detail view), not on the card's front. In Draft Duel (`game_card.gd`) a card shows only the art, its class badge in the top-left corner, its stars and, when a pick would add a star, a green arrow. The rarer the card, the bigger its show (a Rare's soft shine up to a Mythic's shimmering border, sparkles and light rays; see GAME_DESIGN.md, Card show).
- **The menu background** is a deep blue gradient with faint paw prints; the bottom bar has an icon per tab, and the chosen tab lifts up.
- **Icons:** white silhouettes from [game-icons.net](https://game-icons.net) (free to use with credit, see [CREDITS.md](../CREDITS.md)) for tools, emotes, player icons, tabs and buttons.
- **Rival Ranger portraits** (`ranger_portrait.gd`): placeholders drawn in code from each rival's `look` in `rivals.json` (skin, hair and hat styles, eyes, mouth, glasses or freckles...), lit from the top left with a cool rim on the right and outlines in a dark shade of each part's color, on the rival's banner colors. Their face changes with their mood (happy, sad). An illustrator could replace them with painted heads later.
- **Logo:** a wolf and a lion facing off in a den entrance, above "DEN DUEL" in Lilita One. The PNGs are in `game/art/logo/`, the editable SVGs in `game/art/logo/source/`.
- **Fonts:** **Lilita One** for titles and buttons and **Nunito** for longer text.
- **Sounds and two music loops:** generated by `tools/make_sounds.py`.

## Design system: "Ranger Camp" (in progress)

Summer camp, ranger stations, wooden trail signs and brass: warm, chunky and
toy-like. One look for every screen, from `game/data/ui_style.json` through
`game/scripts/ui/style/`. Screens use these and never pick their own colors or
sizes. So far the Draft Duel shop uses it; the rest of the screens move over next.

- **Materials:** painted wood panels with soft grain, painted-wood buttons with a
  gloss, brass for money, a wooden trail-sign plank for titles, sunken dark-wood
  wells. They're drawn by `tools/make_ui_art.py` into `game/art/ui/` as grayscale
  nine-slice shapes (outline, lip, bevel lit from the top left, grain, soft
  shadow) plus a white shine, at 2x for sharp edges on 3x iPhone screens, and
  tinted in the game with the colors in `ui_style.json`. Run the script again
  after changing it; `skins.json` holds each piece's slice margins.
- **Palette:** warm summer sky to sunshine behind everything, wood browns, leaf
  green for the main action, sky blue, barn red for danger, purple for tools,
  brass/gold for rewards, dark brown outlines, and a frame color per rarity.
  The home screen keeps its blue look: a bright sky-blue backdrop with deep,
  saturated blue panels, each with a bright rim. **Every color lives in
  `ui_style.json`** ("colors"): the Ranger Camp pieces, the home screen's blues
  (`kit_*`), rarities (`rarity_*`), classes (`class_*`), habitats
  (`habitat_*`), sorting and a few one-off pieces; rarities.json, classes.json
  and habitats.json have none of their own. All of them are solid and
  saturated: nothing is see-through. Disabled and locked things are solid but
  muted (a gray button, an arena you haven't reached in muted tones), never
  faded; an enabled button is never gray.
- **Light:** no full-screen grade or vignette (they browned and darkened
  everything); a warm glow around picked things; brass icons catch a glint
  now and then.
- **Text:** four sizes only (26, 32, 44 and 64 px, which is 14, 17, 24 and 35 pt
  on an iPhone). Titles, numbers and buttons are in Lilita One with a thick
  dark-brown outline and a drop shadow; the few longer lines are in Nunito.
- **Spacing:** 8, 16, 24 or 32 px. Every corner is rounded.
- **Components:** `SkinBox` (a skin as a style box: one draw call),
  `ChunkyButton` (primary, secondary, danger, tool, gold; at least 88 px tall;
  squashes on press, bounces back, pops with a sparkle; the main one breathes),
  `ValuePill` (icon and a number that ticks; brass for money), `GameCard`
  (rarity frame, big art in a habitat-lit window, a brass cost coin, habitat
  badge, stars).
- **Particles** (sparks, stars, coins, confetti, leaves, dust...) are cells of
  one sheet, `game/art/ui/particles.png`, drawn as a single MultiMesh.
- **Motion:** screens change with a leafy circle wipe and a swirl of leaves
  (`Transition`); shop cards bob out of step and pop in one after another; a
  bought card flies to your herd and lands with a squash and a puff of dust;
  a star added flashes and bursts. Every timing is in `feel.json`.
- **Sound:** wood knocks, soft pops, brass clinks, marimba and glockenspiel
  chimes, soft whooshes; music with a whistled tune, ukulele and marimba
  (`tools/make_sounds.py`).

## Bought art: the art pack test (November 2026)

The animals generated by `tools/creatures` can't reach the quality bar, so
the game is moving to art bought from artists. The first test is the free
sample of Omabuarts' **Quirky Series** (rigged, animated low-poly animals in
flat colors with a face of blendshapes), three animals standing in for a
Tank, a Ranged animal and a flier: the **Colobus** plays as the Brown Bear,
the **Taipan** as the King Cobra and the **Sparrow** as the Peregrine Falcon.

* **Pipeline:** `tools/packs/` (see its README) makes the same files as
  `tools/creatures`: viewer and battle models, a card portrait in a hero
  pose and battle sprite sheets, with each of our animations built from the
  pack's clips and timed like the animal it replaces.
* **Look:** a flat-color shader of its own (`model_toon.gdshader`,
  `viewer.json` "toon_look"): two soft tones, darker underneath, a rim of
  light, bolder color, a bolder dark outline. Its face is the pack's: real
  eyes moved by blendshapes (blink, happy, angry, sleepy, spinning dizzy
  eyes), driven by the same face states as our shader-drawn eyes.
* **Size:** each is drawn so it stands exactly as tall on screen as the
  animal it replaces (`art_tests.json` size and pose_up, measured by the
  game: `tests/art_test_report.tscn`).
* **Gameplay:** none changes. They are *art tests*, out of the roster and
  only made by dev links (`?arttest=1`, `?viewer=test_colobus`,
  `&herds=test_colobus,...`), and fight exactly as the animal they play as
  (`tests/test_art_tests.gd`).

A second test uses free **CC0** art from Quaternius (public domain: it may
be used, changed and kept in this repository, `art_sources/quaternius/`):
the **Fox** and **Wolf** (Ultimate Animated Animal Pack) play as the Red Fox
and the Wolf Pack, the **Yeti** and **Dragon** (Ultimate Monsters) as our
Mythic Yeti and Dragon. Their rigs are real ones (knees, neck, head, tail,
fingers) with longer clips, but they have no facial blendshapes, so their
faces don't change. The Fox and Wolf are faceted low-poly models: the
flat-color shader lights them face by face (`viewer.json` toon_look, the
shader's `faceted`), while their outline still follows smoothed normals.

A third test is **our own**: the **Toy Fox**, a Red Fox built by code in the
packs' flat toy style (`tools/toys/`: a few big round shapes, flat colors in
crisp patches, stick legs, button eyes), to see whether models we make
ourselves can stand next to a pack's. The packs are the reference for the
style only; no pack mesh is copied or reshaped. It keeps our own skeleton
and animations (the Red Fox's trot, pounce, bite and persona), has the same
blendshape faces as the first pack, and comes into the game through
`tools/packs` like a pack animal (pack `own`, its files in
`art_sources/own/`).

## What's next for the art

1. **Play with the 20 animals and react:** which ones don't look right, which
   animations feel weak. Each one is a file to tweak and re-render (about
   10-15 minutes per animal, or a few minutes to redo one animation).
2. **The rest of the world in the same style:** the tools' effects, the
   cages and the menu backgrounds could also be rendered 3D.
3. **More animals** from `game/data/animals_later.json`, once these 20 feel
   right. Most reuse an existing body plan (four-legged, bird); snakes,
   turtles and primates need new ones.
4. **Optional: an artist.** For a hand-painted finish, an illustrator could
   paint over the renders, especially the card portraits. Ask for a paid test
   of 2-3 cards first, and get the rights to the art in writing.

## Name

**Den Duel** is the name. A web search found no game or app with that name on
the App Store, Google Play or Steam. Before launch, still check the USPTO
trademark database (tmsearch.uspto.gov) and grab a matching website name
and social handles.

The other ideas we considered, for reference:

| Name | Why it fits |
|---|---|
| **Uncaged** | The cages, freeing animals. Short and punchy |
| **Wild Release** | "Release" is already the in-game word for playing an animal, plus freeing them |
| **Last of Their Kind** | The rarity = endangered idea. Memorable, a little long |
| **Wildcard Rangers** | A pun: wild animals plus cards, and you're a Ranger |
| **Rescue Rumble** | Playful, says "battles" and "animals" |
| **Sanctuary Showdown** | Ties to the top arena, Last Sanctuary |

