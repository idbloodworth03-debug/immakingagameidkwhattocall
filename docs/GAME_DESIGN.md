# Game Design

The working design for every system. Numbers are starting points for
balancing and live in `game/data/*.json`, so they can change without code.
Draft Duel's rules are in `game/data/draft_rules.json`, and the fighting
itself (speeds, timing, luck) in `game/data/battle_rules.json`.

## The big idea

An animal battler built around one mode, **Draft Duel**: a best-of-7 duel.
Each round you make 3 picks from your collection (new animals, tools, or
stars for animals you have), then watch your herd fight on its own while you
make a few well-timed calls: the War Horn and your tools. Every animal has a
class (Tank, Tank Destroyer, Ranged, Air or Specialist) that sets its row
and what it beats. First to 4 round wins takes the match.

The theme is wildlife rescue: chests are **cages** you open to **free**
animals, the player is a **Ranger**, and card rarity follows how endangered
the animal is in real life. You pick from a deck of 8 of the animals you free.

(Den Duel started as a real-time card battler with three dens per side and a
river across the field. That mode, "Classic battle", and the dens, river and
8-card deck were removed so Draft Duel is the whole game. Draft Duel has
its own deck of 8 now.)

## Draft Duel

The goal: a simple, clear game that feels like commanding an army. Armies
fight on their own in formation; your choices are what to pick, and when to
blow the War Horn or use a tool. **Best of 7**: the first player
to win 4 rounds wins (at most 7 rounds; then the most wins, or a draw). The
score is always big at the top: "2 - 1", with 4 pips each.

**Each round: Pick, then Fight, then a quick result.**

**Pick 3.** Every round you make exactly 3 picks:
- **Round 1:** 3 starting animals from your deck of 8.
- **After that:** 4 animals from your deck and 2 of your tools, shown as
  two groups, each on its own tray (rarer ones come up less often). Each
  pick is one of:
  - an offered animal: a **squad** of it joins your army (another squad if
    it's there already),
  - an offered tool (2 at most; a third replaces one you choose),
  - tap an animal in your army (or its card in the row below) for two big
    buttons: **Upgrade** (a star for every squad of it) or **+Squad**
    (another full squad of it: "+3 Squad" for a Ranged animal, "+1 Squad" for
    a Tank). The computer chooses between them too.
- Stars go up to 3; each star after the first adds 60% health and bite.
- The army grows every round, up to 40 animals (`army_max_units`); after
  that +Squad and offered animals say "Army full" (tools and upgrades still
  work).
- While you pick, your army stands in formation under the options; new
  squads march into their places.
- Tap your latest pick to take it back. **Fight!** lights up once all 3
  picks are made. Hold any card for its name and one short line.
- No money, no shop, no hearts: there are no Acorns any more.

**Squads** (`squads` in `game/data/classes.json`): a card brings a squad,
each animal with its share of the card's health and bite: Tanks 1 (big),
Tank Destroyers 2, Ranged 3, Air 2, Specialists 1 (an elite: stronger,
drawn bigger, with a gold ring and banner), a Mythic 1 (a large hero). Each
squad carries a banner in its team's color with its class's icon.

**Classes** (`game/data/classes.json`): every animal has one, shown as an
icon on its card and on its squad's banner. The army lines up in formation
by class (`formation`):

| Class | Place | What it does |
|---|---|---|
| Tank | The wall in front, shoulder to shoulder (a second line if it's long) | Tough: armored, everyone but Tank Destroyers does 30% less to it. Holds the front line |
| Tank Destroyer | The line behind the wall | +200% damage to Tanks (and no armor in the way); charges them after the clash |
| Ranged | The back ranks, every other line shifted half a place | Reaches at least 7 tiles; +50% damage to Air; fires in volleys |
| Air | Hovering over the Tank Destroyers | Flies: only Ranged and Air can hit it |
| Specialist | On the flanks (Burrowers the wall's, the rest the Tank Destroyers') | One trait: Burrow, Splash, Stun or Slow |

Counters: Tank Destroyers beat Tanks, Tanks protect Ranged, Ranged beat Air,
Air beats Tank Destroyers (they can't hit back), and Specialists disrupt.

Specialist traits: **Burrow** (lines up on the wall's flank, digs in as the
march starts, travels underground and pops up behind the enemy's last row),
**Splash** (every hit also hits the group around the target for 75%),
**Stun** (every second hit freezes the target for 1 second), **Slow** (hits
slow the target 50% for 2.5 seconds). Specialists are elites: one animal,
stronger than a squad's, with these stronger traits.

**Fight** (`scripts/battle/battle_army.gd`, numbers in `battle_rules.json`
"army"). The armies fight on their own, as armies:
1. **Lineup:** both armies stand in formation a moment, then FIGHT!
2. **March:** each army moves up as one, at one pace, every animal in its
   place and the whole army in step (with dust and a stomp on every step).
3. **Volleys:** Ranged ranks stop to shoot once an enemy is in reach and
   all fire together every 2 seconds, their shots arcing over as a flock.
4. **Clash:** the walls meet with a big thump and a ring of dust. The front
   holds while it fights; the lines never pass through each other.
5. **Charge:** a moment later the Tank Destroyers leave their line and go
   around the end of their own wall for the enemy Tanks (back to their line
   once there are none left).
6. **All-out war:** from the clash on, nobody keeps its place or waits for
   a fight to come to it. Every animal goes for an enemy anywhere on the
   field. Fighters take an open spot around one, the less crowded enemies
   first, so the whole enemy line is fought along, not just its middle;
   they walk around teammates and other enemies in the way, round the end
   of a line if they must. Shooters close in until they're in reach and
   shoot over everyone (nothing blocks a shot). A burrower whose army is
   gone comes up at once.
7. **Collapse:** when animals fall, the ones behind step up into the gaps.

You can blow the **War Horn** once (one tap: the whole army surges, biting
harder, attacking faster and moving faster for a few seconds, with a horn
and a banner) and use **each tool once a fight**; tools stay in your belt
for the next fight. The camera frames the whole battle line, easing in as
the armies close. The army that outlasts the other wins the round; at the
bell (40 seconds), the one with more of itself left. Everyone marches,
shoots and charges in unison; small random differences are kept only for
standing about (breathing, fidgets, blinks, faces). The biggest armies (40 a
side) run smoothly on an iPhone; Profile > Developer tools > Big army test
checks it.

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
  and a Golden Cage if a slot is free; from Whispering Woods on, a Moonlit
  Cage with one Mythic instead), with a "BOSS DEFEATED!" banner,
  fireworks and coins, and a gold box on the results.
- **Difficulty:** the arena (0 in the first, 1 at the top) plus the rival's
  own `skill`, plus `boss_skill` for a boss. After `ease_after_losses` (3)
  losses in a row, the next rival is quietly easier: `ease_amount` less
  difficulty and cards `ease_card_levels` lower. Nothing on screen says so.
- Timings and sizes for the VS screen and emotes are in `feel.json` ("rivals").

**Bans.** Once you own 11 animals, every match starts with bans
(`scripts/ui/ban_screen.gd`, rules in `scripts/draft/ban_phase.gd`, numbers
in `draft_rules.json` "bans"). A coin flip decides who bans first; then you
and the rival take turns, 3 bans each (you, rival, you, rival, you, rival).
Nobody can use a banned animal that match: not in a deck, never offered,
never in an army. The screen is a grid of big cards (yours and every animal
the rival could bring), a big "Your turn" / "Rival's turn" banner and each
side's three ban slots; on your turn tap a card and BAN; the rival thinks a
second (dots bouncing) and bans one of yours, going for what beats its
favorite class (`threats`), your best-leveled and strongest first. Every
ban stamps a big red X on its card with a thump. You can always fill a
deck: 11 is a deck plus the rival's 3 bans, and a ban of one of your own is
refused if it could leave you short. The first time, one line explains it.
With fewer than 11 animals, matches go straight to your deck.

**Your deck of 8.** DRAFT DUEL opens your deck before every match (after
the bans): 8 big slots filled with your last deck, your collection below
(tap a card to add or take it out). A slot that held a banned animal shows
empty for you to fill, and banned animals are crossed out. START (once all
8 slots are full) saves it and begins the match, so it's one tap if nothing
changes.
Round 1 offers exactly those 8, and you pick 3 to start. From round 2 the
options are 4 animals from your deck's 8 and 2 of the tools you own (the
computer gets the same). Every card
fights at its level. The computer opponent builds its own deck of 8 from the
animals unlocked up to its arena (topped up to 8 from the starting cards in
the first arenas), leaning toward its favorite class
(`deck_favorite`) with at least one of each class (`DraftBot.build_deck`),
and its cards are leveled like yours on average.

New players start with 8 animals across all five classes plus two tools;
the animals are also their first deck: Brown Bear and Snapping Turtle
(Tank), Wolf Pack and Wild Boar (Tank Destroyer), Gray Squirrel and Striped
Skunk (Ranged), Peregrine Falcon (Air), Red Fox (Specialist), and the Net
and the Air Horn (`starting_cards` in `game/data/progression.json`). A save
with too few animals for a deck gets all the starting cards, then the first
arena's animals if it still needs more; one with fewer than 2 tools gets the
starting tools it's missing. Deck size is `deck_size` in
`game/data/draft_rules.json`.

**Tuning** is in `game/data/draft_rules.json` (wins needed, picks, deck
and army size, options, tools, stars), `game/data/classes.json` (counters,
squads, formation, traits) and `game/data/battle_rules.json` "army" (the
march, volleys, clash, charge, and `damage_pct`: how hard every army animal
bites, which sets how long fights take). Three bot-vs-bot reports:

- `tests/draft_report.tscn`: whole matches. A run of 100: about 5 rounds a
  match, fights about 26 seconds (the first 3.6 the march), 98% end in a
  wipe-out, about 16 animals on the field per fight (46 at most). Each
  class wins 49% to 52% of the fights its armies are in.
- `tests/class_report.tscn`: armies of one class against another (4 cards
  each). Tank Destroyers beat Tanks 70%; Tanks beat Ranged; Ranged beat
  Tank Destroyers and Air; Air beats every army that has no Ranged or Air
  (nothing else can reach it). Ranged average 31% across the classes, so
  they're no army-winner alone.
- `tests/power_report.tscn`: each animal's power (see ROSTER.md). Every
  rarity lands within about 0.03 of its target, Specialists a little above
  their rarity and Mythics above Legendaries.

To tune the classes the squad shares were set first (Tanks 150% health and
130% bite with armor against everyone but Tank Destroyers, which do +200% to
them; Tank Destroyers 2 x 66%; Ranged 3 x 28% / 27%; Air 2 x 55%; elite
Specialists 140% / 135% with stronger traits; a Mythic hero a whole squad of
its class in one animal), then each animal's own health and bite.

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

The game has **35 animals**: 13 Common, 6 Rare, 6 Epic, 5 Legendary and 5
Mythic, 7 Tanks, 7 Tank Destroyers, 7 Ranged, 6 Air and 8 Specialists. The
roster was cut from 122 so each animal stands out and decks are easy to
build; the other 87 are archived in `game/data/animals_archived.json` with
their art kept (left out of the web build). A save that owned an archived
animal keeps its level aside (`archived_cards`), and gets it back if the
animal returns. Each animal is modeled, painted and animated (see
[ART_DIRECTION.md](ART_DIRECTION.md)). [ROSTER.md](ROSTER.md) lists every
animal with its class, row, rarity, arena and power, and the archived ones.

**Mythic** is the rarity above Legendary, for creatures from myth and
legend: they start at level 11, have a rose-pink card with an animated frame
(a pulsing glow, a slowly shifting rainbow tint, a spark running round the
rim and twinkling sparkles; `frame` in rarities.json), and a Ranger Journal
on their card that tells the real animal behind the legend. They come from
Moonlit Cages and as a rare extra in big cages (see Cages).

Each animal has:

- **A class** (and a trait for Specialists): see Draft Duel. This decides its row and what it beats.
- **Stats** at its starting level: hitpoints, damage, hit speed, speed and range (a squad's animals each get their class's share: see Squads).
- **A habitat** (flavor: the color of its card window) and **tags** like Canine or Big Cat.
- A **power** number (2 to 8, the old shop cost) the computer opponent uses to judge it. The old ability names stay in the data for flavor; they don't do anything in a fight.

### The roster

| Animal | Rarity | Class | Unlocks in |
|---|---|---|---|
| Brown Bear | Common | Tank | 4. Whispering Woods |
| Snapping Turtle | Common | Tank | 5. Misty Marsh |
| Giant Panda | Rare | Tank | 10. Cloudpeak Mountains |
| Hippopotamus | Rare | Tank | 5. Misty Marsh |
| Asian Elephant | Epic | Tank | 9. Emerald Jungle |
| Black Rhino | Legendary | Tank | 12. Last Sanctuary |
| Yeti | Mythic | Tank | 8. Frozen Tundra |
| Honey Badger | Common | Tank Destroyer | 6. Sunbaked Savanna |
| Wild Boar | Common | Tank Destroyer | 2. City Park |
| Wolf Pack | Common | Tank Destroyer | 4. Whispering Woods |
| Lion | Rare | Tank Destroyer | 6. Sunbaked Savanna |
| Komodo Dragon | Epic | Tank Destroyer | 11. Coral Coast |
| Tiger | Epic | Tank Destroyer | 8. Frozen Tundra |
| Cerberus | Mythic | Tank Destroyer | 12. Last Sanctuary |
| Gray Squirrel | Common | Ranged | 1. Rescue Center |
| Raccoon | Common | Ranged | 1. Rescue Center |
| Striped Skunk | Common | Ranged | 2. City Park |
| King Cobra | Rare | Ranged | 9. Emerald Jungle |
| Wild Bactrian Camel | Epic | Ranged | 7. Red Rock Canyon |
| Sumatran Orangutan | Legendary | Ranged | 12. Last Sanctuary |
| Unicorn | Mythic | Ranged | 4. Whispering Woods |
| Barn Owl | Common | Air | 3. Prairie Fields |
| Peregrine Falcon | Common | Air | 1. Rescue Center |
| Harpy Eagle | Rare | Air | 3. Prairie Fields |
| Hyacinth Macaw | Rare | Air | 9. Emerald Jungle |
| California Condor | Legendary | Air | 7. Red Rock Canyon |
| Dragon | Mythic | Air | 10. Cloudpeak Mountains |
| Electric Eel | Common | Specialist (Stun) | 5. Misty Marsh |
| Harbor Seal | Common | Specialist (Splash) | 11. Coral Coast |
| Red Fox | Common | Specialist (Burrow) | 1. Rescue Center |
| Mountain Gorilla | Epic | Specialist (Stun) | 10. Cloudpeak Mountains |
| Red Panda | Epic | Specialist (Slow) | 10. Cloudpeak Mountains |
| Pygmy Three-toed Sloth | Legendary | Specialist (Slow) | 12. Last Sanctuary |
| Sunda Pangolin | Legendary | Specialist (Burrow) | 9. Emerald Jungle |
| Kraken | Mythic | Specialist (Splash) | 11. Coral Coast |

Every arena unlocks at least one animal.

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
| 1 | Rescue Center | 0 | yes | Gray Squirrel, Peregrine Falcon, Raccoon, Red Fox |
| 2 | City Park | 300 | yes | Striped Skunk, Wild Boar |
| 3 | Prairie Fields | 600 | yes | Barn Owl, Harpy Eagle (R) |
| 4 | Whispering Woods | 1,000 | yes | Brown Bear, Wolf Pack, Unicorn (M) |
| 5 | Misty Marsh | 1,400 | yes | Electric Eel, Snapping Turtle, Hippopotamus (R) |
| 6 | Sunbaked Savanna | 1,800 | yes | Honey Badger, Lion (R) |
| 7 | Red Rock Canyon | 2,300 | yes | Wild Bactrian Camel (E), California Condor (L) |
| 8 | Frozen Tundra | 2,800 | yes | Tiger (E), Yeti (M) |
| 9 | Emerald Jungle | 3,400 | yes | Hyacinth Macaw (R), King Cobra (R), Asian Elephant (E), Sunda Pangolin (L) |
| 10 | Cloudpeak Mountains | 4,000 | yes | Giant Panda (R), Mountain Gorilla (E), Red Panda (E), Dragon (M) |
| 11 | Coral Coast | 4,600 | no | Harbor Seal, Komodo Dragon (E), Kraken (M) |
| 12 | Last Sanctuary | 5,300 | no | Black Rhino (L), Pygmy Three-toed Sloth (L), Sumatran Orangutan (L), Cerberus (M) |

New players start with the 8 starting animals and the Net (see Draft Duel);
the rest are found in cages.

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
| Moonlit Cage | First win against each boss from Whispering Woods on | 24h | exactly 1 | 1 Mythic | never sold |

**Mythics** come their own way: every Moonlit Cage holds one, and a Crystal
Cage has a 3% chance of one Mythic on top of its other animals, a Grand
Enclosure 6% and a Sanctuary Cage 15% (`mythic_chance` in cages.json, rolled
once per cage, shown with the odds). Twig, Iron and Golden Cages never have
one, and no cage holds a Mythic until you've reached the arena of at least
one.

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
  big fights cheap on a phone, and only switches for one that's clearly
  better: Food Bait, the class it goes after, an enemy already in reach, or
  one at least a tile closer (`retarget_margin_tiles`), so animals don't
  dither between two enemies.
- Only Ranged and Air can hit Air.
- Melee range is 0.7 tiles. Speeds: Slow 0.75, Medium 1, Fast 1.5 and Very fast 2 tiles per second.

**Attack styles.** Every animal also fights in its own way, fitting the
real animal, on top of its class's job (`game/data/styles.json`, rules in
`scripts/battle/battle_styles.gd`; how they look in
`scripts/fx/style_look.gd` and `battle_field.gd`). Each reads without
words, and holding its card shows one line (8 words or fewer). Numbers are
tuned with the power report so cards of a rarity land near the same win
rate. Profile > Developer tools > Attack styles shows each one on its own
in a little fight (with a Slow button).
- Tanks:
  - **Brown Bear**, "Big swipes hit two at once.": each swipe also catches
    the next enemy in reach (35%), drawn as one wide white arc.
  - **Snapping Turtle**, "Hides in its shell when hurt.": below 40% health it
    hides for 2.5 s (taking 40% damage, not fighting), flat under a green
    shell; then not again for 8 s.
  - **Giant Panda**, "Sits down for a bamboo snack heal.": once a fight, at
    half health, it sits for 2 s munching bamboo and heals 35%.
  - **Hippopotamus**, "Thick hide bites back at attackers.": 15% of every
    bite it takes goes back to the biter, with a ripple and a spray of sparks.
  - **Asian Elephant**, "Shields the friends right behind it.": a shot at a
    teammate just behind it hits the Elephant instead, a blue shield
    flashing up.
  - **Black Rhino**, "Charges through the enemy line first.": once an enemy
    is within 5 tiles (or the war starts), it charges 5 tiles at 2.6 times
    its speed in a cloud of dust, knocking everyone aside.
  - **Yeti**, "Every third hit: icy ground pound.": it glows icy blue the hit
    before; the pound hits and knocks back everyone around it.
- Tank Destroyers:
  - **Wild Boar**, "Charges a Tank. Huge first hit.": outside an army it goes
    for the nearest Tank; it sprints at a Tank head down in a trail of dust,
    and its first hit on each Tank does double, with a slam.
  - **Wolf Pack**, "Pack bites harder on the same target.": 30% more while
    the other wolf bites the same enemy (a golden double chomp).
  - **Lion**, "Pride leader: nearby Tank Destroyers hit faster.": every 5 s
    in a fight it roars (a golden ring): its Tank Destroyers within 3 tiles
    attack 25% faster for 3 s, glowing gold.
  - **Honey Badger**, "Fearless: always picks the biggest enemy.": it goes
    for the biggest enemy within 4 tiles (if there's room round it), red
    steam puffing off it, and nothing knocks it back.
  - **Tiger**, "Circles the flank, pounces from the side.": crouched low, it
    circles 2 tiles out to its prey's side, then pounces (an orange claw
    slash); its first strike on each enemy does 1.8 times.
  - **Komodo Dragon**, "Venom bite keeps hurting; moves to the next.": its
    bite poisons for 4 s (the victim goes green); then it's off to an enemy
    not poisoned yet.
  - **Cerberus**, "Three heads, three bites every attack.": three quick fiery
    bites (42% each), spread over the enemies in reach.
- Ranged (every Ranged animal is a little tougher than before, 35% of its
  card's health and 32% of its bite each, so they hold up now that
  everyone fights everywhere):
  - **Gray Squirrel**, "Rapid fire: lots of little pinecones.": every shot
    is three little pinecones, a moment apart (the same damage between them).
  - **Striped Skunk**, "Stink spray hits a whole group.": a short spray (4.5
    tiles) that fans out and hits everyone in a 60-degree cone for 105%; the
    sprayed give off stink lines.
  - **Raccoon**, "Lobs trash over the line at the back.": it lobs tin cans in
    high arcs at the enemy furthest back in its reach.
  - **King Cobra**, "Sniper: shoots farthest, from the very back.": 10 tiles
    of reach; slower, harder, fast flat shots; its hood flares as it aims.
  - **Wild Bactrian Camel**, "Charges up one giant spit.": it stands still,
    cheeks puffing up, for 1.5 s, then one giant spit for 3.5 times its bite
    (its own rhythm, not the volley).
  - **Sumatran Orangutan**, "Bouncing fruit hits up to three.": its fruit
    bounces on to two more enemies (50% each).
  - **Unicorn**, "Rainbow beam pierces the whole line.": a rainbow beam that
    goes on through its target, hitting every enemy along it (60%).
- Air:
  - **Peregrine Falcon**, "Super-fast dives, then climbs back up.": it dives
    at 2.5 times its speed, stretched out with white speed lines, dropping
    lower (its shadow growing) as it closes in; the dive hits for 1.35 times
    in a white flash and feathers, then it climbs away for 0.6 s and dives
    again.
  - **Barn Owl**, "Silent hunter: picks off enemy Ranged.": it flies past the
    front line to the nearest enemy Ranged animal within 12 tiles; pale as a
    ghost with a misty trail, its eyes glinting as it strikes. Silent, it
    takes only 65% from Ranged (who otherwise hit Air hard).
  - **Harpy Eagle**, "Grabs a small enemy and drops it far.": every 6 s it
    snatches up a small enemy (a Ranged-sized one) it hits, flies it 4 tiles
    back over its own side, dangling and wriggling in its talons, and drops
    it with a thud (a full bite, and 0.6 s stunned).
  - **Hyacinth Macaw**, "Cracks armor: its target takes extra damage.": its
    peck leaves a blue crack mark; for 4 s that enemy takes 25% more from
    everyone.
  - **California Condor**, "Grows stronger with every nearby fall.": every
    animal that falls within 5 tiles sends a wisp into it, and it grows and
    bites 8% harder (up to 8 times).
  - **Dragon**, "Fire-breath runs leave a burning line.": every 6 s it flies
    a run over the nearest ground enemy, breathing fire, and leaves a
    5-tile line of fire burning for 3 s (30% of its bite a second to anyone
    on the ground in it).
- Specialists (the Burrowers still start underground; for the others the
  style is how their trait works, in place of the plain every-hit splash,
  stun or slow):
  - **Red Fox** (Burrow), "Pops up behind, hits Ranged, digs again.": it
    surfaces right behind the nearest enemy Ranged and goes for them; after
    3 hits, or when it's down to half health, it digs down again (once a
    fight) and pops up by another group of Ranged at least 3 tiles away.
  - **Sunda Pangolin** (Burrow), "Flips a Tank, then rolls into a ball.":
    it surfaces under the nearest enemy Tank and flips it onto its back (1.5
    times its bite, stunned 1.5 s, legs kicking); when hit it curls into a
    scaly ball for 1.5 s, taking half damage, then not again for 6 s.
  - **Harbor Seal** (Splash), "Belly-slides through a line, splashing all.":
    every 5 s, with an enemy within 3 tiles, it flops onto its belly and
    slides 3 tiles at it, hitting everyone it passes with a splash and
    bowling them aside.
  - **Kraken** (Splash), "Tentacles slam and drag enemies together.": every
    attack, purple tentacles slam its target and two more enemies within
    2.5 tiles (everyone near a slam takes 35%), then drag them all in toward
    it.
  - **Electric Eel** (Stun), "Lightning chains through four, stunning
    them.": every 2nd hit, lightning jumps from its target through up to
    four enemies, stunning each for 0.6 s (25% of its bite to the ones it
    jumps to); it crackles with sparks the hit before.
  - **Mountain Gorilla** (Stun), "Chest-beat roar stuns everyone around.":
    every 7 s, with an enemy close, it beats its chest for half a second,
    then a shockwave: everyone on the ground within 2.5 tiles takes 30%, is
    stunned 0.8 s and knocked back.
  - **Red Panda** (Slow), "Stands tall: everyone near slows down.": every
    6 s, with an enemy within 3 tiles, it rears up tall (an orange ring) and
    everyone within 3 tiles moves 35% slower for 3 s.
  - **Pygmy Three-toed Sloth** (Slow), "Slow-motion zone: everything
    crawls, even shots.": a 2.5-tile slow-motion zone (a turning teal ring)
    goes with it: enemies in it move at half speed and attack 15% slower,
    and enemy shots at anything in it crawl (flying twice as long, and
    coming 15% slower).

**Hold for info:** holding a finger on any card (picking, offers, your army
row, the deck and ban screens, the collection), or on an animal on the
battlefield, pops up its info near the finger for as long as it's held: its
name, class icon, rarity, stars, squad size ("×3"), its attack style in one
line, and bars for Health, Damage, Speed and Range. It never pauses the
fight (`scripts/autoload/hold_info.gd`, `scripts/ui/info_pop.gd`; timing in
feel.json "info").

**3D animal viewer:** tapping an animal in the Animals tab opens it as a
real 3D model in a little scene of its habitat (a round stage with cartoon
trees, rocks, ice, reeds or city things behind it, water for Ocean and
Wetlands animals, snow, pollen, leaves, bubbles or fireflies drifting by).
Drag to spin it, pinch to zoom, tap it to make it react (a fidget, its
attack, a victory dance, a Stun animal's big wind-up, in turn); it idles and
fidgets on its own. Below it: the same info as the hold popup, its level
and the Upgrade button, and its Ranger Journal entry (where it lives, true
facts, how to help; for a Mythic, the legend and the real clue behind it).
An animal you haven't found shows as a dark silhouette. The model loads
when the viewer opens and is freed when it closes
(`scripts/ui/animal_viewer.gd`, `habitat_stage.gd`; models from
`tools/creatures/export_gltf.py`; settings in data/viewer.json, journal in
data/journal.json).

**Arena life:** every arena has life outside its fence, drawn under the
animals so it never covers them. The camera frames the armies, so the strip
just behind the far fence is what's on screen: a crowd of the arena's
animals watches from there (penguins and seals on the Tundra, raccoons, a
fox and a bear at the Rescue Center), with the arena's sign on the fence,
flags fluttering, a ranger waving, a squirrel scurrying along the rail, a
fox pouncing in the snow, northern lights and twinkles on the ice. When the
view already reaches the far fence (the line-up, a fight at the back) the
camera eases a little further past it so the crowd shows; mid-field fights
are framed as before. Big moments (the clash, a knockout, a strong hit, the
War Horn) make the crowd hop and cheer in a wave from where it happened,
flags whip and the lights flare. Bigger set pieces (a ranger station and a
jeep, an igloo and snowbanks) are built into the arena's picture
(`scripts/fx/arena_life.gd`; data/arena_life.json; camera in feel.json
"camera").

**Colors** are bold and solid everywhere: no full-screen tint or darkened
edges, arenas in their full painted colors, panels, bars and badges solid.
States are shown without see-through dimming: cards in your deck stay
bright with a green checkmark, banned cards stay in color under the red X,
disabled buttons are solid gray and light up in their color when they can
be pressed.

**On screen** there's only the score, the armies (a banner with its class
icon over each squad, health bars on hurt animals), the War Horn and the tool buttons; no
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
