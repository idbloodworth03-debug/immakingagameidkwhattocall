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
`POOL=all WEIGHTS=draft`): the animal joins a random herd of four and fights
the same herd with a random animal in its place instead, 240 times, every
card at its starting level. 0.50 is an average offered card. The targets are
about 0.46 for Common, 0.54 for Rare, 0.64 for Epic, 0.75 for Legendary and
0.75-0.80 for Mythic. These numbers are from before the army rework (squads
and formations) and the cut, and will be measured again when it's tuned.

**Starting cards** (a new player's collection and first deck): Brown Bear,
Snapping Turtle, Wolf Pack, Wild Boar, Gray Squirrel, Striped Skunk,
Peregrine Falcon, Red Fox and the Net.

## In the game (35)

| Animal | Class | Row | Rarity | Found in | Power |
|---|---|---|---|---|---|
| Brown Bear | Tank | Front | Common (LC) | 4. Whispering Woods | 0.48 |
| Snapping Turtle | Tank | Front | Common (LC) | 5. Misty Marsh | 0.45 |
| Giant Panda | Tank | Front | Rare (VU) | 10. Cloudpeak Mountains | 0.47 |
| Hippopotamus | Tank | Front | Rare (VU) | 5. Misty Marsh | 0.57 |
| Asian Elephant | Tank | Front | Epic (EN) | 9. Emerald Jungle | 0.63 |
| Black Rhino | Tank | Front | Legendary (CR) | 12. Last Sanctuary | 0.75 |
| Yeti | Tank | Front | Mythic | 8. Frozen Tundra | 0.80 |
| Honey Badger | Tank Destroyer | Middle | Common (LC) | 6. Sunbaked Savanna | 0.44 |
| Wild Boar | Tank Destroyer | Middle | Common (LC) | 2. City Park | 0.44 |
| Wolf Pack | Tank Destroyer | Middle | Common (LC) | 4. Whispering Woods | 0.42 |
| Lion | Tank Destroyer | Middle | Rare (VU) | 6. Sunbaked Savanna | 0.53 |
| Komodo Dragon | Tank Destroyer | Middle | Epic (EN) | 11. Coral Coast | 0.61 |
| Tiger | Tank Destroyer | Middle | Epic (EN) | 8. Frozen Tundra | 0.64 |
| Cerberus | Tank Destroyer | Middle | Mythic | 12. Last Sanctuary | 0.78 |
| Gray Squirrel | Ranged | Back | Common (LC) | 1. Rescue Center | 0.46 |
| Raccoon | Ranged | Back | Common (LC) | 1. Rescue Center | 0.43 |
| Striped Skunk | Ranged | Back | Common (LC) | 2. City Park | 0.38 |
| King Cobra | Ranged | Back | Rare (VU) | 9. Emerald Jungle | 0.54 |
| Wild Bactrian Camel | Ranged | Back | Epic (EN) | 7. Red Rock Canyon | 0.70 |
| Sumatran Orangutan | Ranged | Back | Legendary (CR) | 12. Last Sanctuary | 0.75 |
| Unicorn | Ranged | Back | Mythic | 4. Whispering Woods | 0.75 |
| Barn Owl | Air | Over the middle (own line) | Common (LC) | 3. Prairie Fields | 0.40 |
| Peregrine Falcon | Air | Over the middle (own line) | Common (LC) | 1. Rescue Center | 0.45 |
| Harpy Eagle | Air | Over the middle (own line) | Rare (VU) | 3. Prairie Fields | 0.53 |
| Hyacinth Macaw | Air | Over the middle (own line) | Rare (VU) | 9. Emerald Jungle | 0.55 |
| California Condor | Air | Over the middle (own line) | Legendary (CR) | 7. Red Rock Canyon | 0.75 |
| Dragon | Air | Over the middle (own line) | Mythic | 10. Cloudpeak Mountains | 0.77 |
| Electric Eel | Specialist (Stun) | Middle | Common (LC) | 5. Misty Marsh | 0.42 |
| Harbor Seal | Specialist (Splash) | Back | Common (LC) | 11. Coral Coast | 0.46 |
| Red Fox | Specialist (Burrow) | Front (then underground) | Common (LC) | 1. Rescue Center | 0.45 |
| Mountain Gorilla | Specialist (Stun) | Middle | Epic (EN) | 10. Cloudpeak Mountains | 0.68 |
| Red Panda | Specialist (Slow) | Middle | Epic (EN) | 10. Cloudpeak Mountains | 0.70 |
| Pygmy Three-toed Sloth | Specialist (Slow) | Middle | Legendary (CR) | 12. Last Sanctuary | 0.74 |
| Sunda Pangolin | Specialist (Burrow) | Front (then underground) | Legendary (CR) | 9. Emerald Jungle | 0.74 |
| Kraken | Specialist (Splash) | Back | Mythic | 11. Coral Coast | 0.78 |

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
