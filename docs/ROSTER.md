# Roster

The 35 animals in the game, and the 87 taken out when the roster was cut
for decks and armies. Each has a class (and a trait for Specialists), a
place in the army, a rarity (for real animals, from its IUCN Red List
status: Common = Least Concern, Rare = Near Threatened or Vulnerable, Epic
= Endangered, Legendary = Critically Endangered) and the arena where it's
found. In the game: `game/data/animals.json`. Taken out:
`game/data/animals_archived.json` (move an entry back into animals.json to
bring an animal back; saves keep its card level, and its art is still in
`game/art/units/`, left out of the web build by `game/export_presets.cfg`).

**Power** comes from bot fights (`game/tests/power_report.tscn` with
`WEIGHTS=draft`): the animal joins a random army of four cards and fights
the same army with a random card in its place instead, every card at its
starting level, one squad each (see Squads in GAME_DESIGN.md). Cards come
up as often as Draft Duel offers each rarity, so 0.50 is an average offered
card. Measured with the armies and every animal's attack style (three
runs of 96 fights each, averaged; about plus or minus 0.04). The targets
are 0.46 for Common, 0.54 for Rare, 0.64 for Epic, 0.75 for Legendary and
0.84 for Mythic (raised from 0.80 when the Mythics' abilities were made
stronger, so a Mythic is clearly the best card on the field), with
Specialists (elites) a little above their rarity. The averages: Common
0.46, Rare 0.54, Epic 0.64, Legendary 0.75, Mythic 0.83; every card is
within 0.05 of its target (the Peregrine Falcon the furthest, 0.04 above).

**Starting cards** (a new player's collection and first deck): Brown Bear,
Snapping Turtle, Wolf Pack, Wild Boar, Gray Squirrel, Striped Skunk,
Peregrine Falcon, Red Fox and the Net.

## In the game (35)

| Animal | Class | In the army | Rarity | Found in | Power |
|---|---|---|---|---|---|
| Brown Bear | Tank | The wall | Common (LC) | 4. Whispering Woods | 0.47 |
| Snapping Turtle | Tank | The wall | Common (LC) | 5. Misty Marsh | 0.46 |
| Giant Panda | Tank | The wall | Rare (VU) | 10. Cloudpeak Mountains | 0.53 |
| Hippopotamus | Tank | The wall | Rare (VU) | 5. Misty Marsh | 0.54 |
| Asian Elephant | Tank | The wall | Epic (EN) | 9. Emerald Jungle | 0.65 |
| Black Rhino | Tank | The wall | Legendary (CR) | 12. Last Sanctuary | 0.74 |
| Yeti | Tank | The wall | Mythic | 8. Frozen Tundra | 0.81 |
| Honey Badger | Tank Destroyer | Behind the wall | Common (LC) | 6. Sunbaked Savanna | 0.48 |
| Wild Boar | Tank Destroyer | Behind the wall | Common (LC) | 2. City Park | 0.42 |
| Wolf Pack | Tank Destroyer | Behind the wall | Common (LC) | 4. Whispering Woods | 0.45 |
| Lion | Tank Destroyer | Behind the wall | Rare (VU) | 6. Sunbaked Savanna | 0.55 |
| Komodo Dragon | Tank Destroyer | Behind the wall | Epic (EN) | 11. Coral Coast | 0.66 |
| Tiger | Tank Destroyer | Behind the wall | Epic (EN) | 8. Frozen Tundra | 0.65 |
| Cerberus | Tank Destroyer | Behind the wall | Mythic | 12. Last Sanctuary | 0.83 |
| Gray Squirrel | Ranged | The back ranks | Common (LC) | 1. Rescue Center | 0.42 |
| Raccoon | Ranged | The back ranks | Common (LC) | 1. Rescue Center | 0.46 |
| Striped Skunk | Ranged | The back ranks | Common (LC) | 2. City Park | 0.42 |
| King Cobra | Ranged | The back ranks | Rare (VU) | 9. Emerald Jungle | 0.57 |
| Wild Bactrian Camel | Ranged | The back ranks | Epic (EN) | 7. Red Rock Canyon | 0.62 |
| Sumatran Orangutan | Ranged | The back ranks | Legendary (CR) | 12. Last Sanctuary | 0.77 |
| Unicorn | Ranged | The back ranks | Mythic | 4. Whispering Woods | 0.81 |
| Barn Owl | Air | Over the Tank Destroyers | Common (LC) | 3. Prairie Fields | 0.46 |
| Peregrine Falcon | Air | Over the Tank Destroyers | Common (LC) | 1. Rescue Center | 0.50 |
| Harpy Eagle | Air | Over the Tank Destroyers | Rare (VU) | 3. Prairie Fields | 0.52 |
| Hyacinth Macaw | Air | Over the Tank Destroyers | Rare (VU) | 9. Emerald Jungle | 0.53 |
| California Condor | Air | Over the Tank Destroyers | Legendary (CR) | 7. Red Rock Canyon | 0.73 |
| Dragon | Air | Over the Tank Destroyers | Mythic | 10. Cloudpeak Mountains | 0.83 |
| Electric Eel | Specialist (Stun) | On the Tank Destroyers' flank | Common (LC) | 5. Misty Marsh | 0.47 |
| Harbor Seal | Specialist (Splash) | On the Tank Destroyers' flank | Common (LC) | 11. Coral Coast | 0.49 |
| Red Fox | Specialist (Burrow) | On the wall's flank (then underground) | Common (LC) | 1. Rescue Center | 0.49 |
| Mountain Gorilla | Specialist (Stun) | On the Tank Destroyers' flank | Epic (EN) | 10. Cloudpeak Mountains | 0.62 |
| Red Panda | Specialist (Slow) | On the Tank Destroyers' flank | Epic (EN) | 10. Cloudpeak Mountains | 0.67 |
| Pygmy Three-toed Sloth | Specialist (Slow) | On the Tank Destroyers' flank | Legendary (CR) | 12. Last Sanctuary | 0.77 |
| Sunda Pangolin | Specialist (Burrow) | On the wall's flank (then underground) | Legendary (CR) | 9. Emerald Jungle | 0.74 |
| Kraken | Specialist (Splash) | On the Tank Destroyers' flank | Mythic | 11. Coral Coast | 0.87 |

13 Common, 6 Rare, 6 Epic, 5 Legendary and 5 Mythic. Every arena unlocks at least one animal; the Tiger moved to Frozen Tundra and the Harpy Eagle to Prairie Fields to fill gaps left by the cut.

## Mythics and the real animals behind them (5)

Each Mythic's card has a Ranger Journal with this line; a linked animal opens its card.

| Mythic | Behind the legend | Links to |
|---|---|---|
| Yeti | A 2017 DNA study found most supposed Yeti samples came from bears. | Brown Bear |
| Cerberus | From Greek myth: the three-headed dog that guards the gate of the underworld. |  |
| Unicorn | Narwhal tusks were once sold in Europe as unicorn horns. |  |
| Dragon | In China, fossil bones were long sold as 'dragon bones' for medicine. |  |
| Kraken | Likely inspired by sightings of giant squid. |  |

## Class balance

| Class | In the game | Common | Rare | Epic | Legendary | Mythic |
|---|---|---|---|---|---|---|
| Tank | 7 | 2 | 2 | 1 | 1 | 1 |
| Tank Destroyer | 7 | 3 | 1 | 2 | 0 | 1 |
| Ranged | 7 | 3 | 1 | 1 | 1 | 1 |
| Air | 6 | 2 | 2 | 0 | 1 | 1 |
| Specialist | 8 | 3 | 0 | 2 | 2 | 1 |

## Taken out (87)

Archived in `game/data/animals_archived.json`, with their art kept.

| Animal | Class | Rarity | Was found in | Power |
|---|---|---|---|---|
| Moose | Tank | Common (LC) | 8. Frozen Tundra | 0.45 |
| Opossum | Tank | Common (LC) | 1. Rescue Center | 0.45 |
| American Bison | Tank | Rare (NT) | 3. Prairie Fields | 0.53 |
| Andean Bear | Tank | Rare (VU) | 10. Cloudpeak Mountains | 0.53 |
| Eastern Box Turtle | Tank | Rare (VU) | 2. City Park | 0.51 |
| Gaur | Tank | Rare (VU) | 4. Whispering Woods | 0.56 |
| Loggerhead Turtle | Tank | Rare (VU) | 11. Coral Coast | 0.52 |
| Polar Bear | Tank | Rare (VU) | 11. Coral Coast | 0.49 |
| West Indian Manatee | Tank | Rare (VU) | 5. Misty Marsh | 0.51 |
| Malayan Tapir | Tank | Epic (EN) | 9. Emerald Jungle | 0.63 |
| Pygmy Hippo | Tank | Epic (EN) | 5. Misty Marsh | 0.65 |
| Galápagos Giant Tortoise | Tank | Legendary (CR) | 12. Last Sanctuary | 0.78 |
| Saola | Tank | Legendary (CR) | 10. Cloudpeak Mountains | 0.73 |
| Bigfoot | Tank | Mythic | 4. Whispering Woods | 0.76 |
| Black Tortoise | Tank | Mythic | 11. Coral Coast | 0.77 |
| Coyote Pack | Tank Destroyer | Common (LC) | 3. Prairie Fields | 0.46 |
| Spotted Hyenas | Tank Destroyer | Common (LC) | 6. Sunbaked Savanna | 0.47 |
| Wolverine | Tank Destroyer | Common (LC) | 8. Frozen Tundra | 0.45 |
| Cheetah | Tank Destroyer | Rare (VU) | 1. Rescue Center | 0.54 |
| Fossa | Tank Destroyer | Rare (VU) | 9. Emerald Jungle | 0.53 |
| Iberian Lynx | Tank Destroyer | Rare (VU) | 4. Whispering Woods | 0.57 |
| Jaguar | Tank Destroyer | Rare (NT) | 9. Emerald Jungle | 0.61 |
| Shoebill | Tank Destroyer | Rare (VU) | 5. Misty Marsh | 0.52 |
| Snow Leopard | Tank Destroyer | Rare (VU) | 10. Cloudpeak Mountains | 0.53 |
| African Wild Dogs | Tank Destroyer | Epic (EN) | 6. Sunbaked Savanna | 0.64 |
| Tasmanian Devil | Tank Destroyer | Epic (EN) | 4. Whispering Woods | 0.65 |
| Amur Leopard | Tank Destroyer | Legendary (CR) | 8. Frozen Tundra | 0.75 |
| Gharial | Tank Destroyer | Legendary (CR) | 12. Last Sanctuary | 0.74 |
| Great Hammerhead Shark | Tank Destroyer | Legendary (CR) | 11. Coral Coast | 0.73 |
| Red Wolf | Tank Destroyer | Legendary (CR) | 4. Whispering Woods | 0.74 |
| Chupacabra | Tank Destroyer | Mythic | 7. Red Rock Canyon | 0.76 |
| Fenrir | Tank Destroyer | Mythic | 8. Frozen Tundra | 0.79 |
| Manticore | Tank Destroyer | Mythic | 6. Sunbaked Savanna | 0.78 |
| Nemean Lion | Tank Destroyer | Mythic | 6. Sunbaked Savanna | 0.75 |
| Archerfish | Ranged | Common (LC) | 5. Misty Marsh | 0.43 |
| Bullfrog | Ranged | Common (LC) | 5. Misty Marsh | 0.42 |
| Mountain Goat | Ranged | Common (LC) | 10. Cloudpeak Mountains | 0.47 |
| Pistol Shrimp | Ranged | Common (NE) | 11. Coral Coast | 0.45 |
| Porcupine | Ranged | Common (LC) | 4. Whispering Woods | 0.49 |
| Texas Horned Lizard | Ranged | Common (LC) | 7. Red Rock Canyon | 0.44 |
| Bonobo | Ranged | Epic (EN) | 9. Emerald Jungle | 0.58 |
| Chimpanzee | Ranged | Epic (EN) | 9. Emerald Jungle | 0.60 |
| Pink River Dolphin | Ranged | Epic (EN) | 9. Emerald Jungle | 0.59 |
| Sea Otter | Ranged | Epic (EN) | 11. Coral Coast | 0.62 |
| Jackalope | Ranged | Mythic | 3. Prairie Fields | 0.77 |
| Kitsune | Ranged | Mythic | 4. Whispering Woods | 0.73 |
| Qilin | Ranged | Mythic | 9. Emerald Jungle | 0.76 |
| Murder of Crows | Air | Common (LC) | 2. City Park | 0.48 |
| Pigeon Flock | Air | Common (LC) | 1. Rescue Center | 0.46 |
| Atlantic Puffin | Air | Rare (VU) | 8. Frozen Tundra | 0.50 |
| Flying Fox Colony | Air | Rare (VU) | 2. City Park | 0.57 |
| Monarch Butterflies | Air | Rare (VU) | 2. City Park | 0.54 |
| Snowy Owl | Air | Rare (VU) | 8. Frozen Tundra | 0.57 |
| Steller's Sea Eagle | Air | Rare (VU) | 8. Frozen Tundra | 0.48 |
| Wandering Albatross | Air | Rare (VU) | 8. Frozen Tundra | 0.51 |
| Whooping Crane | Air | Epic (EN) | 5. Misty Marsh | 0.61 |
| Helmeted Hornbill | Air | Legendary (CR) | 12. Last Sanctuary | 0.75 |
| Philippine Eagle | Air | Legendary (CR) | 12. Last Sanctuary | 0.78 |
| Griffin | Air | Mythic | 6. Sunbaked Savanna | 0.79 |
| Pegasus | Air | Mythic | 10. Cloudpeak Mountains | 0.77 |
| Phoenix | Air | Mythic | 12. Last Sanctuary | 0.75 |
| Roc | Air | Mythic | 10. Cloudpeak Mountains | 0.78 |
| Aardvark | Specialist (Burrow) | Common (LC) | 6. Sunbaked Savanna | 0.42 |
| Humpback Whale | Specialist (Splash) | Common (LC) | 11. Coral Coast | 0.44 |
| Rattlesnake | Specialist (Stun) | Common (LC) | 7. Red Rock Canyon | 0.44 |
| Sewer Rats | Specialist (Burrow) | Common (LC) | 1. Rescue Center | 0.46 |
| Gila Monster | Specialist (Slow) | Rare (NT) | 7. Red Rock Canyon | 0.54 |
| Greater Bilby | Specialist (Burrow) | Rare (VU) | 3. Prairie Fields | 0.54 |
| Howler Monkey | Specialist (Stun) | Rare (VU) | 9. Emerald Jungle | 0.50 |
| Philippine Tarsier | Specialist (Stun) | Rare (NT) | 12. Last Sanctuary | 0.57 |
| Platypus | Specialist (Slow) | Rare (NT) | 1. Rescue Center | 0.57 |
| Walrus | Specialist (Splash) | Rare (VU) | 8. Frozen Tundra | 0.59 |
| Black-footed Ferret | Specialist (Burrow) | Epic (EN) | 3. Prairie Fields | 0.63 |
| Giant Manta Ray | Specialist (Splash) | Epic (EN) | 11. Coral Coast | 0.64 |
| Slow Loris | Specialist (Slow) | Epic (EN) | 9. Emerald Jungle | 0.63 |
| African Penguins | Specialist (Splash) | Legendary (CR) | 11. Coral Coast | 0.75 |
| Axolotl | Specialist (Slow) | Legendary (CR) | 5. Misty Marsh | 0.74 |
| Chinese Giant Salamander | Specialist (Slow) | Legendary (CR) | 10. Cloudpeak Mountains | 0.77 |
| Gopher Tortoise | Specialist (Burrow) | Legendary (CR) | 3. Prairie Fields | 0.77 |
| Kakapo | Specialist (Stun) | Legendary (CR) | 12. Last Sanctuary | 0.73 |
| Northern Hairy-nosed Wombat | Specialist (Burrow) | Legendary (CR) | 6. Sunbaked Savanna | 0.77 |
| Baku | Specialist (Slow) | Mythic | 9. Emerald Jungle | 0.76 |
| Basilisk | Specialist (Stun) | Mythic | 5. Misty Marsh | 0.78 |
| Hydra | Specialist (Splash) | Mythic | 5. Misty Marsh | 0.76 |
| Loch Ness Monster | Specialist (Burrow) | Mythic | 5. Misty Marsh | 0.79 |
| Mongolian Death Worm | Specialist (Burrow) | Mythic | 7. Red Rock Canyon | 0.77 |
| Sphinx | Specialist (Stun) | Mythic | 7. Red Rock Canyon | 0.75 |
