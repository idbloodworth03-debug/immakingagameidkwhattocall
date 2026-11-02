# Game Design

The working design for every system. Numbers are starting points for
balancing and live in `game/data/*.json`, so they can change without code.
Draft Duel's rules are in `game/data/draft_rules.json`, and the fighting
itself (speeds, timing, luck) in `game/data/battle_rules.json`.

## The big idea

An animal battler built around one mode, **Draft Duel**: a round-based duel.
Pick a few starters from your collection, then each round shop for more
animals and train them up, place your herd with no clock running, and
watch it fight on its own while you make a few well-timed calls: a Rally,
your tools and a bet. Each player has 30 hearts; lose a fight and you lose
hearts. There's a gambling layer with Acorns, which only exist inside a
match.

The theme is wildlife rescue: chests are **cages** you open to **free**
animals, the player is a **Ranger**, and card rarity follows how endangered
the animal is in real life. The animals you free are your draft pool.

(Den Duel started as a real-time card battler with three dens per side and a
river across the field. That mode, "Classic battle", and the dens, river and
8-card deck were removed so Draft Duel is the whole game.)

## Draft Duel

The goal: give players time to think, keep them involved during the fight,
and add the thrill of a bet, while skill (reading the fight) still beats
luck. Each player starts with **30 hearts**, and the match goes round by
round until someone runs out (at most 15 rounds).

**Starters.** Before the first round, each player picks up to **3 animals**
they own to start with, worth up to **12 Acorns** together (so not just
the three strongest). They start the match in the herd.

Then each round has four parts:

1. **Shop.** Each player has their own Watering Hole: 4 animals, 1 Ranger
   tool and a face-down **Mystery Crate** (a random animal for 4 Acorns:
   maybe a Legendary, maybe one rat), all from **your collection** (topped
   up with the first arena's cards if you own too few). Both players shop
   at the same time, and each can:
   - **Buy** cards. A herd holds up to 6 animals and 2 tools, and it carries over from round to round.
   - **Buy a copy** of an animal already in the herd: instead of joining, it gives that animal a **star** (and a copy still fits when the herd is full).
   - **Train** a herd animal up a star for Acorns: its card cost times the stars it has, plus 1 (a Brown Bear costs 7 to reach 2 stars, 13 to reach 3).
   - **Reroll** the shop for 1 Acorn.
   - Press **Done**. When both are done, it's time to place.

   **Stars:** every animal starts with 1 and can reach 3. Each star after
   the first adds 60% health and bite, and stars count at the bell.
   Each player's shop has its own dice, so one player's rerolls never
   change what the other is offered.
2. **Place your herd.** Nothing moves and there's no clock. Both herds are on
   the field (the opponent places first, so you can answer it). Animals start
   on your own half, at least a tile back from the middle line.
   When both players press Ready, the fight starts.
3. **The fight** (up to 40 seconds) runs on its own, with some luck:
   - **Moods:** at the whistle, every animal rolls a mood for
     the fight: up to 30% harder or softer bites ("Fired up!", "Sleepy").
   - **Hits** vary by up to 25% each.
   - **Rally:** once a fight, tap a spot and your animals there bite 30%
     harder, attack and move 20% faster for 4 seconds. Timing is everything.
   - **Tools** bought in the draft can be used anywhere, any time.
   - **The Raccoon** (Trash Panda) steals an Acorn from the other player as
     the fight starts.
   - **Halftime** (8 seconds in): the fight pauses for the **Pot**. Both
     players put a 1-Acorn ante in when the fight starts. At halftime you
     may raise (up to 3, never more than the other player can call) or
     check, then the opponent. A raise must be called or folded. Folding
     ends the round at once: you lose the round and the Pot, but only the
     round's base hearts (see below), nothing for the enemy animals still
     standing. So the player who's ahead chooses: raise to win Acorns and
     offer a way out, or check and let the herd finish the job. Which tools
     you hold is hidden (only how many shows), so a raise can be a bluff.
4. **Round over.** The fight ends when a herd is wiped out; the other herd
   wins the round. If both still stand at the bell, the one with more of
   itself left wins (each animal counts its card's cost times the share of
   health it has left). The winner takes the Pot; a tie carries it over.

**Hearts.** The loser of a round loses hearts: **the round number, plus 1
for each of the winner's animals still standing** (a pack counts once). A
round 4 loss to a herd with 3 animals left costs 7 hearts. A tie costs
nobody anything. Run out of hearts and you lose; after round 15, more
hearts wins.

**Acorns** are the only money in a match: 6 to start, +6 each round, +2
more for the loser of the last round (to help it catch up), plus Pots and
Raccoon thefts. Spend them on animals, tools, training and rerolls, or keep
them for the halftime Pot. Everyone starts with the same Acorns.

**Your collection matters, a little.** Your starters and shop come from the
cards you own, and your animals and tools fight at their levels. The computer opponent's cards
are leveled like yours on average, so leveling a few favorites helps without
making the match one-sided.

**Match stakes.** Before the match: Safe (half the trophies, win or lose),
Bold (normal) or All-in (double).

**Gambling without harm.** Acorns can't be bought, carry nothing out of a
match and reset every time. The Pot rewards reading the fight (and knowing
your own tools), not blind luck. Keep it that way: if Acorns or bets ever
connect to anything bought with money, the game becomes real gambling, with
legal trouble in some countries and a higher App Store age rating.

**Tuning** is in `game/data/draft_rules.json`. `tests/draft_report.tscn` plays
bot-vs-bot matches and prints match length, hearts lost, shopping, the
halftime Pot and how close fights are at halftime. From the latest runs
(30 matches):
- Matches last about 7 rounds. Wins split 13-17.
- A fight lasts about 17 seconds, and 3 in 4 end with a herd wiped out. A loss costs 5.4 hearts on average.
- Herds average 5 animals with 1.3 stars each. A bot buys about 16 cards a match (a third of them copies for a star) and trains 2 or 3 times.
- At halftime, about 60% of fights are still fairly close (each side has 20-80% of the strength left). The bots fold in about 1 halftime in 5.
- Before starters and shops, with one shared, take-turns Watering Hole and no stars, fights were much more one-sided.

**The Bookie (removed for now).** There used to be a betting step between
placing and the fight: a raccoon Bookie played the fight out ahead a few
times, posted the odds, and you could bet Acorns on your own herd at those
odds. It was taken out to keep rounds simpler; it's in the git history
(before the commit that removed it) if it comes back.

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

- **Acorn cost** (2 to 8): what it costs at the Watering Hole. Its **count** says how many come in a pack (the Wolf Pack is several wolves).
- **Stats** at its starting level: hitpoints, damage, hit speed, speed, range and what it targets (ground, or air & ground)
- **Tags** like Canine, Big Cat, Aquatic or Savanna animal, used by abilities
- **One ability**, e.g. *Pounce*, *Pack Hunters*, *Trash Panda* or *Apex Pounce*. Abilities are built from reusable types (pounce, poison, stealth, shield...), so the battle code implements each type once and many animals share it.

### The roster

| Animal | Rarity | Cost | Ability | Unlocks in |
|---|---|---|---|---|
| Sewer Rats | Common | 2 | Scurry | 1. Rescue Center |
| Raccoon | Common | 3 | Trash Panda | 1. Rescue Center |
| Gray Squirrel | Common | 3 | Hidden Stash | 1. Rescue Center |
| Red Fox | Common | 3 | Pounce | 1. Rescue Center |
| Peregrine Falcon | Common | 3 | Stoop Dive | 1. Rescue Center |
| Wild Boar | Common | 4 | Charge | 2. City Park |
| Wolf Pack | Common | 5 | Pack Hunters | 4. Whispering Woods |
| Brown Bear | Common | 6 | Maul | 4. Whispering Woods |
| Cheetah | Rare | 4 | Sprint | 1. Rescue Center |
| American Bison | Rare | 5 | Stampede | 3. Prairie Fields |
| Hippopotamus | Rare | 6 | Territorial | 5. Misty Marsh |
| Lion | Rare | 5 | Roar | 6. Sunbaked Savanna |
| Polar Bear | Rare | 6 | Thick Fur | 11. Coral Coast |
| African Wild Dogs | Epic | 5 | Relentless | 6. Sunbaked Savanna |
| Tiger | Epic | 6 | Apex Pounce | 9. Emerald Jungle |
| Asian Elephant | Epic | 8 | Trample | 9. Emerald Jungle |
| Red Panda | Epic | 3 | Stand Tall | 10. Cloudpeak Mountains |
| California Condor | Legendary | 5 | Sky Scavenger | 7. Red Rock Canyon |
| Amur Leopard | Legendary | 5 | Phantom | 8. Frozen Tundra |
| Black Rhino | Legendary | 7 | Thunder Charge | 12. Last Sanctuary |

Every arena unlocks at least one animal. New players own the six Rescue
Center animals plus the Net and Air Horn, which is enough to fill the
Watering Hole.

## Arenas and trophies

You win and lose **trophies** in battles. A win against an even opponent is +30 and a
loss is -30. Beating someone with more trophies gives more, and losing to someone with fewer
costs more (always 20 to 40). Trophies decide your arena, and each arena adds
new animals to your cages. Most arenas have a **floor**: once you reach one,
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

New players start owning every Rescue Center card.

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

The animals fight on their own: you choose what to draft, where it starts,
and when to Rally or use a tool.

**The field:** 16 tiles wide and 20 long, open, with a halfway line and a
center ring, and a fence around it. You play from the bottom. Every arena
uses the same field; only the look and scenery change.

**How animals behave:**
- Each goes for the nearest enemy it can reach, anywhere on the field (Food Bait close by comes first). With no enemy left, it stands still.
- Ground-only animals can't hit flyers (the Falcon and Condor); animals that target "air & ground" (the Squirrel's thrown acorns, the birds) can.
- Melee range is 0.7 tiles. Speeds: Slow 0.75, Medium 1, Fast 1.5 and Very fast 2 tiles per second.
- Moods and hit luck make each fight a bit different (see Draft Duel above).

**The end:** a fight is over when a herd is wiped out, or after 40 seconds.
The fight engine is deterministic: the same herds, seed and actions always
play out the same way, which online play will rely on.

## Ranger tools

Bought at the Watering Hole, kept on your tool belt (2 at most) and used
once, anywhere on the field, during a fight:

| Tool | Rarity | Cost | Unlocks | What it does |
|---|---|---|---|---|
| Net | Common | 2 | Arena 1 | Enemies in a 2-tile area are stuck for 2.5s and take 40 damage |
| Air Horn | Common | 2 | Arena 1 | 145 damage in 2.5 tiles and knocks enemies back |
| Food Bait | Rare | 2 | Arena 2 | A snack that enemy ground animals within 5 tiles go for, for up to 7s |
| Medkit | Rare | 3 | Arena 3 | Heals your animals in 3 tiles for 440 |
| Tranquilizer Dart | Epic | 3 | Arena 5 | Puts the closest enemy animal to sleep for 4s (Fearless ones are only slowed) |
| Signal Flare | Epic | 4 | Arena 6 | 340 damage in 2.5 tiles, reveals hidden animals |

Tools level up like animals (+10% damage or healing per level). New players
start with the Net and Air Horn.

## Computer opponent

The opponent plays Draft Duel through the same calls as a person, so it
follows the same rules:

- **Starters:** it tries random sets within the budget and keeps the one worth the most.
- **Shopping:** it buys by cost (pricier animals are stronger), likes copies that add a star (more so once its herd is full), trains its pricier animals when the herd is full, wants one tool, sometimes gambles on the Mystery Crate, rerolls a weak shop when it has Acorns to spare, and once its herd has 3 animals it keeps some Acorns back to bet with.
- **Placing:** tough animals in front, ranged ones behind, leaning toward the side where your herd is strongest.
- **Fighting:** it rallies where two or more of its animals are fighting, uses damage tools on groups, the Medkit on its hurt animals, the Dart on your biggest animal and Food Bait in front of its herd.
- **The halftime Pot:** it judges its chances by its share of the strength left on the field, plus its own tools (it's braver with tools in hand), raises when clearly ahead, folds only when clearly beaten, and sometimes bluffs.

**Difficulty grows with your arena:** it drafts less randomly, uses tools
sooner and on smaller groups, and bluffs more. Its cards are leveled
like yours on average. The same bot can later fill online matchmaking when
few players are on.

**Balance.** All animal stats were first tuned from about 7,000 bot battles
in the old Classic mode. Draft Duel's open field and herds change what's
strong, so they need a new pass from real play, with the Draft Duel report
as a guide.

## Still open

1. **Match length:** 30 hearts and the per-round loss give about 6 rounds against the bot. Real players may want shorter matches (25 hearts?) on a phone.
2. **Balance:** all stats are first guesses from the old mode. Playing a lot of Draft Duel is the only way to really tune them.
3. **The field:** one open field for every arena. Arena-specific features (a pond in Misty Marsh, rocks in Red Rock Canyon) could add variety later.

Settled: the bot gets harder as you climb (yes); Classic battle, dens and the river are gone (Draft Duel is the game).
