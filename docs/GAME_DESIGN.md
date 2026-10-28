# Game Design

The working design for every system. Numbers are starting points for
balancing and live in `game/data/*.json`, so they can change without code.
The **battle rules** (how animals move and fight, towers, win conditions)
are not designed yet. They're the next step (see [ROADMAP.md](ROADMAP.md)).

## The big idea

A hands-off, real-time card battler in the style of Clash Royale. You release
animals onto the field and they act on their own; your skill is choosing
*what* to release, *where* and *when*. The theme is wildlife rescue: chests
are **cages** you open to **free** animals, the player is a **Ranger**, and
card rarity follows how endangered the animal is in real life.

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

There are 57 to start: 22 Common, 14 Rare, 10 Epic and 11 Legendary. Each has:

- **Energy cost** (1 to 8) and **count** (swarms like Sewer Rats release several)
- **Stats** at its starting level: hitpoints, damage, hit speed, speed, range and what it targets (ground, air & ground, or towers only)
- **Tags** like Canine, Big Cat, Aquatic or Jungle animal, used by abilities and requirements
- **One ability**, e.g. *Play Dead*, *Pack Hunters*, *Stink Cloud* or *Alpha Howl*. Abilities are built from 38 reusable types (pounce, poison, stealth, shield...), so the battle code implements each type once and many animals share it.
- **Release requirements** (the prerequisites). Commons mostly have none. Rarer animals are stronger but harder to release.

### Release requirement types

| Type | Example |
|---|---|
| Energy | Every animal costs energy |
| Allies with a tag | Lion: "Needs 1 allied Savanna animal on the field" |
| No allies with a tag | Kakapo: "Can't be released while you have a Predator on the field" |
| Releases so far | Black-footed Ferret: "Release 2 other animals first" |
| Battle time | Tiger: "Available after 1:00 of battle" |
| Your tower took damage | Asian Elephant (protective): "Only after one of your towers takes damage" |
| Allies defeated | California Condor (a scavenger): "Only after 2 of your animals are defeated" |
| Only one at a time | Every Legendary |
| River only | Hippo, Sea Otter, Axolotl must be released in the river |

All **Aquatic** animals may also be released in the river; everyone else uses
their own side. The battle sandbox already checks all of these.

### Animals with requirements

| Animal | Rarity | Cost | Ability | Requirements |
|---|---|---|---|---|
| Hippopotamus | Rare | 6 | Territorial | River only |
| Lion | Rare | 5 | Roar | 1 allied Savanna animal |
| Black-footed Ferret | Epic | 3 | Tunnel | 2 releases first |
| Whooping Crane | Epic | 4 | Courtship Dance | 1 allied Wetland animal |
| African Wild Dogs | Epic | 5 | Relentless | 1 allied Pack animal |
| Tiger | Epic | 6 | Apex Pounce | After 1:00 |
| Asian Elephant | Epic | 8 | Trample | Your tower damaged |
| Chimpanzee | Epic | 4 | Tool User | 1 release first |
| Mountain Gorilla | Epic | 7 | Chest Beat | 3 releases first |
| Sea Otter | Epic | 3 | Raft Up | River only |
| Komodo Dragon | Epic | 5 | Venomous Bite | After 0:30 |
| Red Wolf | Legendary | 4 | Alpha Howl | Unique; 1 allied Canine |
| Axolotl | Legendary | 3 | Regrowth | Unique; river only |
| Black Rhino | Legendary | 7 | Thunder Charge | Unique; after 1:00 |
| California Condor | Legendary | 5 | Sky Scavenger | Unique; 2 allies defeated |
| Amur Leopard | Legendary | 5 | Phantom | Unique; no allied Big Cats |
| Sunda Pangolin | Legendary | 4 | Roll Up | Unique; 3 releases first |
| Saola | Legendary | 6 | Asian Unicorn | Unique; after 2:00 |
| African Penguins | Legendary | 4 | Colony | Unique; 1 allied Aquatic animal |
| Kakapo | Legendary | 2 | Booming Call | Unique; no allied Predators |
| Philippine Eagle | Legendary | 6 | Sky Snatch | Unique; after 1:30 |
| Sumatran Orangutan | Legendary | 6 | Forest Gardener | Unique; 2 allied Jungle animals |

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

New players start with all 8 Rescue Center animals already in their deck.

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
  added if wanted. (Clash Royale's King Level also boosts tower strength,
  and we can decide whether towers level up when we design battles.)

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

## Battle rules: open questions for the next session

1. **Towers:** keep the classic layout of 2 side towers and 1 main tower per player? And what are they called in our theme: Dens? Ranger Stations?
2. **Winning:** destroy the main tower for an instant win, otherwise whoever destroyed more towers wins when time runs out?
3. **Match length:** 3 minutes plus overtime? Energy that refills faster in the last minute?
4. **Energy:** 10 max, 1 per 2.8 seconds (what the sandbox uses)? And does it need a better name, like Stamina or Instinct?
5. **Non-animal cards:** only animals, or also "ranger tools" (nets, bait, medicine) as spell-like cards?
6. **Map:** one river with two bridges, or arena-specific terrain (marsh puddles, jungle trees)?
7. **Towers leveling** with Ranger Level, or fixed so only animal levels matter?
