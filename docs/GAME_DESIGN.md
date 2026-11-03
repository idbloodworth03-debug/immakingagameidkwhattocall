# Game Design

The working design for every system. Numbers are starting points for
balancing and live in `game/data/*.json`, so they can change without code.
Draft Duel's rules are in `game/data/draft_rules.json`, and the fighting
itself (speeds, timing, luck) in `game/data/battle_rules.json`.

## The big idea

An animal battler built around one mode, **Draft Duel**: a best-of-7 duel.
Each round you make 3 picks from your collection (new animals, tools, or
stars for animals you have), then watch your herd fight on its own while you
make a few well-timed calls: a Rally and your tools. Every animal has a
class (Tank, Tank Destroyer, Ranged, Air or Specialist) that sets its row
and what it beats. First to 4 round wins takes the match.

The theme is wildlife rescue: chests are **cages** you open to **free**
animals, the player is a **Ranger**, and card rarity follows how endangered
the animal is in real life. The animals you free are your draft pool.

(Den Duel started as a real-time card battler with three dens per side and a
river across the field. That mode, "Classic battle", and the dens, river and
8-card deck were removed so Draft Duel is the whole game.)

## Draft Duel

The goal: a simple, clear game. Herds fight on their own; your choices are
what to pick, and when to Rally or use a tool. **Best of 7**: the first player
to win 4 rounds wins (at most 7 rounds; then the most wins, or a draw). The
score is always big at the top: "2 - 1", with 4 pips each.

**Each round: Pick, then Fight, then a quick result.**

**Pick 3.** Every round you make exactly 3 picks:
- **Round 1:** 3 starting animals from your collection (any you own,
  Legendaries included).
- **After that:** 5 options from your collection, a mix of animals and tools
  (rarer ones come up less often). Each pick is one of:
  - an offered animal (one you already have gets a **star** instead of a copy),
  - an offered tool (2 at most; a third replaces one you choose),
  - a star for an animal already in your herd (tap it in the herd row).
- Stars go up to 3; each star after the first adds 60% health and bite.
- **No limit on the herd**: it grows every round, so fights get bigger.
- Tap your latest pick to take it back. **Fight!** lights up once all 3
  picks are made. Hold any card for its name and one short line.
- No money, no shop, no hearts: there are no Acorns any more.

**Classes** (`game/data/classes.json`): every animal has one, shown as an
icon on its card and under it on the field. Animals take their places
automatically by class:

| Class | Row | What it does |
|---|---|---|
| Tank | Front | Tough. Holds the front line |
| Tank Destroyer | Middle | +150% damage to Tanks, and goes for them first |
| Ranged | Back | Reaches at least 5 tiles; +50% damage to Air, and goes for it first |
| Air | Over the middle | Flies: only Ranged and Air can hit it |
| Specialist | By trait | One trait: Burrow, Splash, Stun or Slow |

Counters: Tank Destroyers beat Tanks, Tanks protect Ranged, Ranged beat Air,
Air beats Tank Destroyers (they can't hit back), and Specialists disrupt.

Specialist traits: **Burrow** (starts in front, travels underground and pops
up behind the enemy's last row), **Splash** (back row; every hit also hits
the group around the target for 60%), **Stun** (middle; every third hit
freezes the target for 1 second), **Slow** (middle; hits slow the target 40%
for 2 seconds). Swarms bring 2 animals at most.

**Fight.** The herds fight on their own. You can **Rally** once (tap Rally,
then the field: your animals there bite harder and move faster for a few
seconds) and use **each tool once a fight**; tools stay in your belt for the
next fight. The herd that outlasts the other wins the round; at the bell
(40 seconds), the one with more of itself left.

**Big moments:** reaching 3 stars ("3 STARS!", stars and confetti), a
flawless round ("FLAWLESS!"), and winning a match after being 2 rounds down
("Comeback Victory!"). Timings and particle counts are in `feel.json`.

**Rival Rangers** (`game/data/rivals.json`, `scripts/battle/opponents.gd`):
you play against named Rangers, not random usernames. Each arena has 2 or 3
regulars and one **boss** (38 in all), each with a cartoon portrait (drawn in
code from `look` in `rivals.json` until there's painted art), a personality
line, a banner, a favorite class or way of playing, and emotes for the
start, their big hits, and rounds going their way or not.

- **VS screen** before every match: their portrait and banner on top, yours
  below, a VS that slams down, their line and favorite class, and an ARENA
  BOSS ribbon for a boss. Tap to go on (or it goes on by itself).
- **In the match** their badge shows their portrait. They emote (a speech
  bubble and a change of face) when the match starts, on their first big hit
  of a round, and when they win or lose a round, at most one every few
  seconds. At the end they react to the result.
- **Ways of playing** (`style`): a favorite class they pick more of, and how
  much they like stars over new animals, and tools. 0.5 is ordinary.
- **Bosses guard promotion.** When a win could take you to the next arena
  (within `boss_within_trophies`), you face that arena's boss. Beat the boss
  and you go up; regular wins stop just short of the next arena. In the top
  arena the boss turns up once you're `top_arena_boss_after` trophies in, then
  joins the regulars for rematches. The home screen shows "Boss next" when a
  boss is waiting.
- **The first win against each boss** gives `boss_reward` (1,000 gold, 100 gems
  and a Golden Cage if a slot is free), with a "BOSS DEFEATED!" banner,
  fireworks and coins, and a gold box on the results.
- **Difficulty:** the arena (0 in the first, 1 at the top) plus the rival's
  own `skill`, plus `boss_skill` for a boss. After `ease_after_losses` (3)
  losses in a row, the next rival is quietly easier: `ease_amount` less
  difficulty and cards `ease_card_levels` lower. Nothing on screen says so.
- Timings and sizes for the VS screen and emotes are in `feel.json` ("rivals").

**Your collection matters.** Your picks come from the cards you own, and they
fight at their levels. The computer opponent's cards are leveled like yours on
average. New players start with 5 cards, one of each of four classes plus a
tool: Brown Bear (Tank), Wild Boar (Tank Destroyer), Gray Squirrel (Ranged),
Peregrine Falcon (Air) and the Net (`starting_cards` in
`game/data/progression.json`). That fills the 5 options, and the first match
already shows the whole counter loop. A save with fewer than 5 cards (or
fewer than 3 animals) gets topped up with the starting cards.

**Tuning** is in `game/data/draft_rules.json` (wins needed, picks, options,
tools, stars) and `game/data/classes.json` (counters, rows, traits, swarm
size). `tests/draft_report.tscn` plays bot-vs-bot matches and prints match
length, fight length, herd sizes, what the bots pick and how each class does.
A run of 240 matches: about 5 rounds a match, fights about 21 seconds, 88%
end in a wipe-out, about 14 animals on the field per fight (32 at most). The
bots' picks: 61% new animals, 27% stars, 12% tools. Each class turns up in a
herd in 1,650 to 2,450 fights and wins 46% to 54% of them; with the same
herds on both sides each side wins half the time.

**Removed:** the shop, Acorns (costs, rerolls, interest, win streak and loss
bonuses), hearts, manual placement, habitat synergies, per-animal abilities
(animals now fight by class; their old ability names are kept in the data for
flavor only), and moods. Draft Duel also used to have a gambling layer (a
Bookie, a halftime Pot, a Mystery Crate, trophy stakes). It's all in the git
history.

## Rarity = how endangered the animal is

| Rarity    | Real-world status (IUCN Red List) | Starts at level | Card color |
|-----------|-----------------------------------|-----------------|------------|
| Common    | Least Concern                     | 1               | Silver     |
| Rare      | Near Threatened or Vulnerable     | 3               | Orange     |
| Epic      | Endangered                        | 6               | Purple     |
| Legendary | Critically Endangered             | 9               | Teal       |

Each animal's detail screen shows its real status. A test checks that every
animal's rarity matches its status. IUCN statuses change over time, so
re-check them before launch.

## Animals

The game starts with **20 animals**: 8 Common, 5 Rare, 4 Epic and 3
Legendary. Each one is modeled, painted, furred and animated (see
[ART_DIRECTION.md](ART_DIRECTION.md)), and the plan is to get these 20 right
before adding more. Another 37 are already designed (stats, abilities,
requirements) and wait in `game/data/animals_later.json`, which the game
doesn't load.

Each animal has:

- **A class** (and a trait for Specialists): see Draft Duel. This decides its row and what it beats.
- **Stats** at its starting level: hitpoints, damage, hit speed, speed and range. Its **count** says how many come in a pack (2 at most on the field).
- **A habitat** (flavor: the color of its card window) and **tags** like Canine or Big Cat.
- A **power** number (2 to 8, the old shop cost) the computer opponent uses to judge it. The old ability names stay in the data for flavor; they don't do anything in a fight.

### The roster

| Animal | Rarity | Class | Unlocks in |
|---|---|---|---|
| Sewer Rats | Common | Specialist (Burrow) | 1. Rescue Center |
| Raccoon | Common | Ranged | 1. Rescue Center |
| Gray Squirrel | Common | Ranged | 1. Rescue Center |
| Red Fox | Common | Specialist (Burrow) | 1. Rescue Center |
| Peregrine Falcon | Common | Air | 1. Rescue Center |
| Wild Boar | Common | Tank Destroyer | 2. City Park |
| Wolf Pack | Common | Tank Destroyer | 4. Whispering Woods |
| Brown Bear | Common | Tank | 4. Whispering Woods |
| Cheetah | Rare | Tank Destroyer | 1. Rescue Center |
| American Bison | Rare | Tank | 3. Prairie Fields |
| Hippopotamus | Rare | Tank | 5. Misty Marsh |
| Lion | Rare | Tank Destroyer | 6. Sunbaked Savanna |
| Polar Bear | Rare | Tank | 11. Coral Coast |
| African Wild Dogs | Epic | Tank Destroyer | 6. Sunbaked Savanna |
| Tiger | Epic | Tank Destroyer | 9. Emerald Jungle |
| Asian Elephant | Epic | Tank | 9. Emerald Jungle |
| Red Panda | Epic | Specialist (Slow) | 10. Cloudpeak Mountains |
| Black Rhino | Legendary | Tank | 12. Last Sanctuary |
| California Condor | Legendary | Air | 7. Red Rock Canyon |
| Amur Leopard | Legendary | Tank Destroyer | 8. Frozen Tundra |

Every arena unlocks at least one animal. Of these 20, 6 are Tanks, 7 Tank
Destroyers, 2 Ranged, 2 Air and 3 Specialists (Burrow and Slow); the 37 still
to come add more Ranged and Air animals and the Splash and Stun Specialists.

## Arenas and trophies

You win and lose **trophies** in battles. A win against an even opponent is +30 and a
loss is -30. Beating someone with more trophies gives more, and losing to someone with fewer
costs more (always 20 to 40). Trophies decide your arena, and each arena adds
new animals to your cages. To move up you beat the arena's **boss** (see
Rival Rangers): it shows up when a win could take you over, and regular wins
stop one trophy short. Most arenas have a **floor**: once you reach one,
you can't drop back below it. The top two arenas don't, to keep some stakes.

| # | Arena | Trophies | Floor | New animals |
|---|---|---|---|---|
| 1 | Rescue Center | 0 | yes | Pigeon Flock, Sewer Rats, Raccoon, Gray Squirrel, Opossum, Red Fox, Platypus (R), Cheetah (R) |
| 2 | City Park | 300 | yes | Murder of Crows, Striped Skunk, Peregrine Falcon, Eastern Box Turtle (R) |
| 3 | Prairie Fields | 600 | yes | Coyote Pack, Barn Owl, American Bison (R), Black-footed Ferret (E) |
| 4 | Whispering Woods | 1,000 | yes | Wild Boar, Wolf Pack, Brown Bear, Red Wolf (L) |
| 5 | Misty Marsh | 1,400 | yes | Bullfrog, Snapping Turtle, Hippopotamus (R), Whooping Crane (E), Axolotl (L) |
| 6 | Sunbaked Savanna | 1,800 | yes | Honey Badger, Spotted Hyenas, Lion (R), African Wild Dogs (E), Black Rhino (L) |
| 7 | Red Rock Canyon | 2,300 | yes | Rattlesnake, Gila Monster (R), California Condor (L) |
| 8 | Frozen Tundra | 2,800 | yes | Moose, Polar Bear (R), Walrus (R), Amur Leopard (L) |
| 9 | Emerald Jungle | 3,400 | yes | Jaguar (R), King Cobra (R), Tiger (E), Asian Elephant (E), Chimpanzee (E), Sunda Pangolin (L) |
| 10 | Cloudpeak Mountains | 4,000 | yes | Mountain Goat, Snow Leopard (R), Giant Panda (R), Red Panda (E), Mountain Gorilla (E), Saola (L) |
| 11 | Coral Coast | 4,600 | no | Harbor Seal, Loggerhead Turtle (R), Sea Otter (E), Komodo Dragon (E), African Penguins (L) |
| 12 | Last Sanctuary | 5,300 | no | Kakapo (L), Philippine Eagle (L), Sumatran Orangutan (L) |

New players start with the 5 starting cards (see Draft Duel); the rest are
found in cages.

### Ranking (with online play)

- **Global and local leaderboards** by trophies.
- **Seasons** (proposal): above Last Sanctuary, a monthly ranked league with
  tiers (e.g. Bronze to Apex) that reset each season, with end-of-season
  cages and a banner for your best tier.
- **Matchmaking** by trophies. Bots fill in while the player count is small,
  so nobody waits forever.

## Leveling animals

All cards share a **max level of 14**, and rarer cards start higher. Upgrading needs
**copies** of the animal from cages or the shop, plus **gold**. Every level adds **10%**
to hitpoints and damage. Example costs for the next level:

| Upgrade to level | Common copies | Rare copies | Epic copies | Legendary copies | Gold |
|---|---|---|---|---|---|
| 2  | 2   | -  | -  | -  | 5 |
| 4  | 10  | 2  | -  | -  | 50 |
| 7  | 100 | 20 | 2  | -  | 1,000 |
| 10 | 800 | 200 | 20 | 2 | 8,000 |
| 14 | 5,000 | 1,250 | 200 | 20 | 100,000 |

Each upgrade also gives **Ranger XP**. The full tables are in
`progression.json`.

## Ranger Level (account level)

- XP comes from upgrading animals, +10 per win and +4 per loss.
- 20 levels to start.
- Levels unlock banners, icons and emotes. Later, gameplay boosts could be
  added if wanted.

## Cages (chests)

Win a battle and you get a cage if one of your **4 cage slots** is free. Wins
follow a repeating cycle: mostly Twig, some Iron, the occasional Golden and
Crystal. Only **one cage unlocks at a time**. Gems finish the timer instantly
(6 gems per hour left).

| Cage | From | Unlock | Animals (Arena 1 / +per arena) | Guaranteed | Shop price |
|---|---|---|---|---|---|
| Twig Cage | Wins | 3h | 12 / +2 | 1 Rare | - |
| Iron Cage | Wins | 8h | 30 / +6 | 3 Rare | - |
| Golden Cage | Wins | 12h | 60 / +10 | 6 Rare, 1 Epic | - |
| Crystal Cage | Wins, Shop | 24h | 120 / +20 | 20 Rare, 4 Epic | 500 gems |
| Grand Enclosure | Shop | 24h | 300 / +40 | 50 Rare, 10 Epic | 1,500 gems |
| Sanctuary Cage | Shop (from Arena 4) | 24h | exactly 1 | 1 Legendary | 500 gems |

How a cage fills:

1. Guaranteed cards first.
2. Every other card rolls its rarity separately using the cage's odds.
3. Cards of the same rarity are grouped into a few stacks of different animals.

Only animals from arenas you've reached can drop. If a rarity isn't unlocked
yet, its odds and guarantees pass down to the next rarity.

**Odds disclosure:** Apple and Google both require showing loot box odds
before purchase, so every cage has a "See odds" button with the exact
chances for your arena. Some countries, such as Belgium, treat paid loot boxes
as gambling. We'll need a plan for those regions before launch: hide paid
cages there, or sell animals directly.

The opening screen is the fun part: tap to open, then tap through each reward,
with a big **NEW ANIMAL FREED!** for first finds, and a summary at the end.

## Shop

- **Daily Animals:** three offers that change every day (UTC): a Common (x20), a Rare (x5) and an Epic (x1). Only animals you already own are offered, for gold.
- **Cages** for gems, each with an Odds button.
- **Gold** for gems, in three sizes.
- **Emotes and banners** for gems.
- **Gems** for real money, once the store accounts exist.

## Player customization

- **Banners** (12): background and border colors behind your name. You unlock them by reaching arenas or Ranger levels, or buy them.
- **Icons** (14): your avatar. Many unlock when you **find a specific animal**, e.g. the Axolotl icon.
- Unlock rules are data: `default`, `ranger_level`, `arena`, `animal` or `shop`.

## Emotes and quick chat

- **12 emotes**, each an animal with a caption (*Laughing Hyena: "Hee-hee-hee!"*, *Crocodile Tears: "Boo-hoo..."*). Four are free; the rest unlock by level or arena, or in the shop.
- **8 quick chats:** "Good luck!", "Well played!", "Wow!", "Thanks!", "Good game!", "Oops!", "Nice one!", "Free the animals!"
- A 2-second cooldown, and a **Mute opponent** button.
- There's deliberately **no free typing in battles**. That keeps matches friendly
  and avoids needing chat moderation, which matters because an animal game
  will attract kids.

## Clans (planned, needs online play)

- Up to **50 members**, with roles **Leader, Co-leader, Elder and Member**. Clan settings: open, invite-only or closed, and a minimum trophy count to join.
- **Clan chat:** we need to decide on quick chats and emotes only, or free text with a word filter, reporting and moderation. That decision depends on the target age (see the roadmap).
- **Animal requests:** ask for copies of an animal every few hours. Clanmates donate and earn gold and Ranger XP.
- **Friendly battles** with clanmates and friends, which don't change trophies.
- **Clan Wars** (proposal): a weekly event where each member gets a few war battles a day. Wins earn points for the clan. Clans are matched in groups of about 5, and the final ranking gives Clan Cages to everyone who took part.

## The fight

**The field:** 16 tiles wide and 20 long, with a halfway line and a fence
around it. You play from the bottom. Each class lines up across the field:
front row 2.2 tiles back from the middle line, middle row 4.4, Air 5.5 and the
back row 6.6 (`rows` in `classes.json`). A row with too many animals for one
line gets more lines behind it, every other line shifted half a place so
nobody hides behind another, and the rows behind it move back to make room.

**Big herds** (`field` in `draft_rules.json`): the field grows as the herds
do, keeping its shape. It starts at 12 animals on the bigger side and is
1.5 times as big at 36. It also grows if the rows wouldn't fit otherwise.
The rows spread wider and deeper with it, and the camera zooms out smoothly
to show it all (the arena picture grows with the field, and mirrored copies of
its edges fill a tall screen). 1.5 is the limit, so animals are never drawn
smaller than two thirds of their size. Big fights also keep their effects in
check (`crowd` in `feel.json`). From 24 animals on the field:
- only so many hit sparks and damage numbers show at once, and the biggest
  hits take the place of the smallest;
- bursts use half their particles;
- ordinary hits skip their claw and bite marks;
- the animals use a plain look that draws faster.

**How animals behave:**
- Tank Destroyers go for a Tank within 7 tiles first, Ranged for Air within 6;
  otherwise everyone goes for the nearest enemy it can reach (Food Bait close
  by comes first). An animal on its way to a target that's still fine looks
  around for a better one 4 times a second (`retarget_seconds`), which keeps
  big fights cheap on a phone.
- Only Ranged and Air can hit Air.
- Melee range is 0.7 tiles. Speeds: Slow 0.75, Medium 1, Fast 1.5 and Very fast 2 tiles per second.

**On screen** there's only the score, the herds (with a class icon under
each animal and health bars on hurt ones), Rally and the tool buttons; no
words float up over the field. After a fight the new score pops up big over
the field and flies into the score bar.

**The end:** a fight is over when a herd is wiped out, or after 40 seconds.
The fight engine is deterministic: the same herds, seed and actions always
play out the same way, which online play will rely on.

## Ranger tools

Picked like animals, kept on your tool belt (2 at most) and used once each
fight, anywhere on the field:

| Tool | Rarity | Unlocks | What it does |
|---|---|---|---|
| Net | Common | Arena 1 | Enemies in a 2-tile area are stuck for 2.5s and take 40 damage |
| Air Horn | Common | Arena 1 | 145 damage in 2.5 tiles and knocks enemies back |
| Food Bait | Rare | Arena 2 | A snack that enemy ground animals within 5 tiles go for, for up to 7s |
| Medkit | Rare | Arena 3 | Heals your animals in 3 tiles for 440 |
| Tranquilizer Dart | Epic | Arena 5 | Puts the closest enemy animal to sleep for 4s |
| Signal Flare | Epic | Arena 6 | 340 damage in 2.5 tiles |

Tools level up like animals (+10% damage or healing per level). New players
start with the Net.

## Computer opponent

The opponent is a Rival Ranger (see Draft Duel) played by this bot. It plays
Draft Duel through the same calls as a person, so it follows the same rules:

- **Picks:** it scores each option and each possible star (`bot` in
  `draft_rules.json`). Every pick costs the same, so what counts most is what
  its herd needs against yours: Tank Destroyers against your Tanks, Ranged
  against your Air, Air against your Tank Destroyers, a Tank to shield its own
  Ranged, and classes it doesn't have yet. An animal's power only tips the
  balance, and tools are worth more once its herd is big. It goes by your herd
  as it was when the round's picking started, as you do: it can't see your new
  picks either. Starters favor a spread of classes, and a little luck plays a
  part.
- **Fighting:** it rallies where two or more of its animals are fighting, uses damage tools on groups, the Medkit on its hurt animals, the Dart on your biggest animal and Food Bait in front of its herd.

**Difficulty grows with your arena:** it picks less randomly, pays more
attention to counters, and uses tools sooner and on smaller groups. Each rival
adds its own skill, bosses more, and it eases off quietly after 3 losses in a
row. **Personality** (the rival's `style`): a favorite class it picks more of,
and how much it likes stars over new animals, and likes tools. The same bot can
later fill online matchmaking when few players are on.

**Balance.** All animal stats were first tuned from about 7,000 bot battles
in the old Classic mode. Draft Duel's open field and herds change what's
strong, so they need a new pass from real play, with the Draft Duel report
as a guide.

## Still open

1. **Match length:** best of 7 runs about 5 rounds against the bot, with fights of about 21 seconds. Real players may want a shorter match on a phone.
2. **Balance:** all stats are first guesses from the old mode. Playing a lot of Draft Duel is the only way to really tune them.
3. **The field:** one open field for every arena. Arena-specific features (a pond in Misty Marsh, rocks in Red Rock Canyon) could add variety later.

Settled: the bot gets harder as you climb (yes); Classic battle, dens and the river are gone (Draft Duel is the game); new players start with 5 cards (see Draft Duel).
