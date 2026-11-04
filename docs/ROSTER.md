# Roster

Every animal in the game or on the way: its class (and trait), where it
lines up, its rarity (for real animals, from its IUCN Red List status:
Common = Least Concern, Rare = Near Threatened or Vulnerable, Epic =
Endangered, Legendary = Critically Endangered), where it's found and the
batch it's rendered in. In the game: `game/data/animals.json`; on the way:
`game/data/animals_later.json`.

**Power** comes from bot fights (`game/tests/power_report.tscn` with
`POOL=all WEIGHTS=draft`): the animal joins a random herd of four and fights
the same herd with a random animal in its place instead, 240 times, every
card at its starting level. The herds and the animal it's compared with come
from the whole roster, the animals on the way too, picked as often as Draft
Duel offers each rarity, so 0.50 is an average offered card. The targets are
about 0.46 for Common, 0.54 for Rare, 0.64 for Epic, 0.75 for Legendary and
0.75-0.80 for Mythic. The original 20 are shown as they are: some are outside
their rarity's range and wait for a decision.

## In the game (122)

| Animal | Class | Row | Rarity | Found in | Power |
|---|---|---|---|---|---|
| Sewer Rats | Specialist (Burrow) | Front (then underground) | Common (LC) | 1. Rescue Center | 0.10 |
| Raccoon | Ranged | Back | Common (LC) | 1. Rescue Center | 0.52 |
| Gray Squirrel | Ranged | Back | Common (LC) | 1. Rescue Center | 0.37 |
| Red Fox | Specialist (Burrow) | Front (then underground) | Common (LC) | 1. Rescue Center | 0.20 |
| Peregrine Falcon | Air | Over the middle (own line) | Common (LC) | 1. Rescue Center | 0.23 |
| Wild Boar | Tank Destroyer | Middle | Common (LC) | 2. City Park | 0.36 |
| Wolf Pack | Tank Destroyer | Middle | Common (LC) | 4. Whispering Woods | 0.45 |
| Brown Bear | Tank | Front | Common (LC) | 4. Whispering Woods | 0.53 |
| Cheetah | Tank Destroyer | Middle | Rare (VU) | 1. Rescue Center | 0.32 |
| American Bison | Tank | Front | Rare (NT) | 3. Prairie Fields | 0.56 |
| Hippopotamus | Tank | Front | Rare (VU) | 5. Misty Marsh | 0.62 |
| Lion | Tank Destroyer | Middle | Rare (VU) | 6. Sunbaked Savanna | 0.67 |
| Polar Bear | Tank | Front | Rare (VU) | 11. Coral Coast | 0.55 |
| African Wild Dogs | Tank Destroyer | Middle | Epic (EN) | 6. Sunbaked Savanna | 0.43 |
| Tiger | Tank Destroyer | Middle | Epic (EN) | 9. Emerald Jungle | 0.78 |
| Asian Elephant | Tank | Front | Epic (EN) | 9. Emerald Jungle | 0.88 |
| Red Panda | Specialist (Slow) | Middle | Epic (EN) | 10. Cloudpeak Mountains | 0.14 |
| Black Rhino | Tank | Front | Legendary (CR) | 12. Last Sanctuary | 0.87 |
| California Condor | Air | Over the middle (own line) | Legendary (CR) | 7. Red Rock Canyon | 0.46 |
| Amur Leopard | Tank Destroyer | Middle | Legendary (CR) | 8. Frozen Tundra | 0.60 |
| Pigeon Flock | Air | Over the middle (own line) | Common (LC) | 1. Rescue Center | 0.48 |
| Murder of Crows | Air | Over the middle (own line) | Common (LC) | 2. City Park | 0.50 |
| Striped Skunk | Ranged | Back | Common (LC) | 2. City Park | 0.46 |
| Barn Owl | Air | Over the middle (own line) | Common (LC) | 3. Prairie Fields | 0.45 |
| Bullfrog | Ranged | Back | Common (LC) | 5. Misty Marsh | 0.47 |
| Mountain Goat | Ranged | Back | Common (LC) | 10. Cloudpeak Mountains | 0.51 |
| King Cobra | Ranged | Back | Rare (VU) | 9. Emerald Jungle | 0.61 |
| Whooping Crane | Air | Over the middle (own line) | Epic (EN) | 5. Misty Marsh | 0.64 |
| Chimpanzee | Ranged | Back | Epic (EN) | 9. Emerald Jungle | 0.68 |
| Sea Otter | Ranged | Back | Epic (EN) | 11. Coral Coast | 0.65 |
| Philippine Eagle | Air | Over the middle (own line) | Legendary (CR) | 12. Last Sanctuary | 0.77 |
| Sumatran Orangutan | Ranged | Back | Legendary (CR) | 12. Last Sanctuary | 0.78 |
| Harpy Eagle | Air | Over the middle (own line) | Rare (VU) | 9. Emerald Jungle | 0.55 |
| Steller's Sea Eagle | Air | Over the middle (own line) | Rare (VU) | 8. Frozen Tundra | 0.47 |
| Snowy Owl | Air | Over the middle (own line) | Rare (VU) | 8. Frozen Tundra | 0.56 |
| Hyacinth Macaw | Air | Over the middle (own line) | Rare (VU) | 9. Emerald Jungle | 0.56 |
| Helmeted Hornbill | Air | Over the middle (own line) | Legendary (CR) | 12. Last Sanctuary | 0.76 |
| Atlantic Puffin | Air | Over the middle (own line) | Rare (VU) | 8. Frozen Tundra | 0.50 |
| Wandering Albatross | Air | Over the middle (own line) | Rare (VU) | 8. Frozen Tundra | 0.51 |
| Flying Fox Colony | Air | Over the middle (own line) | Rare (VU) | 2. City Park | 0.58 |
| Monarch Butterflies | Air | Over the middle (own line) | Rare (VU) | 2. City Park | 0.55 |
| Wild Bactrian Camel | Ranged | Back | Epic (EN) | 7. Red Rock Canyon | 0.70 |
| Porcupine | Ranged | Back | Common (LC) | 4. Whispering Woods | 0.47 |
| Texas Horned Lizard | Ranged | Back | Common (LC) | 7. Red Rock Canyon | 0.49 |
| Archerfish | Ranged | Back | Common (LC) | 5. Misty Marsh | 0.46 |
| Pink River Dolphin | Ranged | Back | Epic (EN) | 9. Emerald Jungle | 0.64 |
| Bonobo | Ranged | Back | Epic (EN) | 9. Emerald Jungle | 0.62 |
| Pistol Shrimp | Ranged | Back | Common (NE) | 11. Coral Coast | 0.47 |
| Phoenix | Air | Over the middle (own line) | Mythic | 12. Last Sanctuary | 0.78 |
| Dragon | Air | Over the middle (own line) | Mythic | 10. Cloudpeak Mountains | 0.77 |
| Griffin | Air | Over the middle (own line) | Mythic | 6. Sunbaked Savanna | 0.81 |
| Pegasus | Air | Over the middle (own line) | Mythic | 10. Cloudpeak Mountains | 0.74 |
| Roc | Air | Over the middle (own line) | Mythic | 10. Cloudpeak Mountains | 0.78 |
| Kitsune | Ranged | Back | Mythic | 4. Whispering Woods | 0.75 |
| Qilin | Ranged | Back | Mythic | 9. Emerald Jungle | 0.78 |
| Jackalope | Ranged | Back | Mythic | 3. Prairie Fields | 0.75 |
| Unicorn | Ranged | Back | Mythic | 4. Whispering Woods | 0.78 |
| Opossum | Tank | Front | Common (LC) | 1. Rescue Center | 0.48 |
| Coyote Pack | Tank Destroyer | Middle | Common (LC) | 3. Prairie Fields | 0.45 |
| Snapping Turtle | Tank | Front | Common (LC) | 5. Misty Marsh | 0.50 |
| Honey Badger | Tank Destroyer | Middle | Common (LC) | 6. Sunbaked Savanna | 0.48 |
| Spotted Hyenas | Tank Destroyer | Middle | Common (LC) | 6. Sunbaked Savanna | 0.47 |
| Rattlesnake | Specialist (Stun) | Middle | Common (LC) | 7. Red Rock Canyon | 0.47 |
| Moose | Tank | Front | Common (LC) | 8. Frozen Tundra | 0.48 |
| Harbor Seal | Specialist (Splash) | Back | Common (LC) | 11. Coral Coast | 0.48 |
| Platypus | Specialist (Slow) | Middle | Rare (NT) | 1. Rescue Center | 0.57 |
| Eastern Box Turtle | Tank | Front | Rare (VU) | 2. City Park | 0.54 |
| Gila Monster | Specialist (Slow) | Middle | Rare (NT) | 7. Red Rock Canyon | 0.53 |
| Walrus | Specialist (Splash) | Back | Rare (VU) | 8. Frozen Tundra | 0.59 |
| Jaguar | Tank Destroyer | Middle | Rare (NT) | 9. Emerald Jungle | 0.63 |
| Snow Leopard | Tank Destroyer | Middle | Rare (VU) | 10. Cloudpeak Mountains | 0.57 |
| Giant Panda | Tank | Front | Rare (VU) | 10. Cloudpeak Mountains | 0.56 |
| Loggerhead Turtle | Tank | Front | Rare (VU) | 11. Coral Coast | 0.58 |
| Black-footed Ferret | Specialist (Burrow) | Front (then underground) | Epic (EN) | 3. Prairie Fields | 0.65 |
| Mountain Gorilla | Specialist (Stun) | Middle | Epic (EN) | 10. Cloudpeak Mountains | 0.69 |
| Komodo Dragon | Tank Destroyer | Middle | Epic (EN) | 11. Coral Coast | 0.63 |
| Red Wolf | Tank Destroyer | Middle | Legendary (CR) | 4. Whispering Woods | 0.76 |
| Axolotl | Specialist (Slow) | Middle | Legendary (CR) | 5. Misty Marsh | 0.76 |
| Sunda Pangolin | Specialist (Burrow) | Front (then underground) | Legendary (CR) | 9. Emerald Jungle | 0.76 |
| Saola | Tank | Front | Legendary (CR) | 10. Cloudpeak Mountains | 0.78 |
| African Penguins | Specialist (Splash) | Back | Legendary (CR) | 11. Coral Coast | 0.76 |
| Kakapo | Specialist (Stun) | Middle | Legendary (CR) | 12. Last Sanctuary | 0.76 |
| Galápagos Giant Tortoise | Tank | Front | Legendary (CR) | 12. Last Sanctuary | 0.77 |
| West Indian Manatee | Tank | Front | Rare (VU) | 5. Misty Marsh | 0.53 |
| Malayan Tapir | Tank | Front | Epic (EN) | 9. Emerald Jungle | 0.65 |
| Gaur | Tank | Front | Rare (VU) | 4. Whispering Woods | 0.57 |
| Pygmy Hippo | Tank | Front | Epic (EN) | 5. Misty Marsh | 0.65 |
| Andean Bear | Tank | Front | Rare (VU) | 10. Cloudpeak Mountains | 0.60 |
| Tasmanian Devil | Tank Destroyer | Middle | Epic (EN) | 4. Whispering Woods | 0.68 |
| Iberian Lynx | Tank Destroyer | Middle | Rare (VU) | 4. Whispering Woods | 0.57 |
| Wolverine | Tank Destroyer | Middle | Common (LC) | 8. Frozen Tundra | 0.49 |
| Gharial | Tank Destroyer | Middle | Legendary (CR) | 12. Last Sanctuary | 0.78 |
| Great Hammerhead Shark | Tank Destroyer | Middle | Legendary (CR) | 11. Coral Coast | 0.72 |
| Shoebill | Tank Destroyer | Middle | Rare (VU) | 5. Misty Marsh | 0.56 |
| Fossa | Tank Destroyer | Middle | Rare (VU) | 9. Emerald Jungle | 0.57 |
| Northern Hairy-nosed Wombat | Specialist (Burrow) | Front (then underground) | Legendary (CR) | 6. Sunbaked Savanna | 0.77 |
| Greater Bilby | Specialist (Burrow) | Front (then underground) | Rare (VU) | 3. Prairie Fields | 0.56 |
| Aardvark | Specialist (Burrow) | Front (then underground) | Common (LC) | 6. Sunbaked Savanna | 0.48 |
| Gopher Tortoise | Specialist (Burrow) | Front (then underground) | Legendary (CR) | 3. Prairie Fields | 0.77 |
| Humpback Whale | Specialist (Splash) | Back | Common (LC) | 11. Coral Coast | 0.46 |
| Giant Manta Ray | Specialist (Splash) | Back | Epic (EN) | 11. Coral Coast | 0.65 |
| Electric Eel | Specialist (Stun) | Middle | Common (LC) | 5. Misty Marsh | 0.45 |
| Howler Monkey | Specialist (Stun) | Middle | Rare (VU) | 9. Emerald Jungle | 0.53 |
| Philippine Tarsier | Specialist (Stun) | Middle | Rare (NT) | 12. Last Sanctuary | 0.62 |
| Pygmy Three-toed Sloth | Specialist (Slow) | Middle | Legendary (CR) | 12. Last Sanctuary | 0.77 |
| Slow Loris | Specialist (Slow) | Middle | Epic (EN) | 9. Emerald Jungle | 0.66 |
| Chinese Giant Salamander | Specialist (Slow) | Middle | Legendary (CR) | 10. Cloudpeak Mountains | 0.78 |
| Yeti | Tank | Front | Mythic | 8. Frozen Tundra | 0.77 |
| Bigfoot | Tank | Front | Mythic | 4. Whispering Woods | 0.75 |
| Black Tortoise | Tank | Front | Mythic | 11. Coral Coast | 0.80 |
| Fenrir | Tank Destroyer | Middle | Mythic | 8. Frozen Tundra | 0.80 |
| Nemean Lion | Tank Destroyer | Middle | Mythic | 6. Sunbaked Savanna | 0.78 |
| Cerberus | Tank Destroyer | Middle | Mythic | 12. Last Sanctuary | 0.74 |
| Manticore | Tank Destroyer | Middle | Mythic | 6. Sunbaked Savanna | 0.80 |
| Chupacabra | Tank Destroyer | Middle | Mythic | 7. Red Rock Canyon | 0.77 |
| Loch Ness Monster | Specialist (Burrow) | Front (then underground) | Mythic | 5. Misty Marsh | 0.80 |
| Mongolian Death Worm | Specialist (Burrow) | Front (then underground) | Mythic | 7. Red Rock Canyon | 0.78 |
| Kraken | Specialist (Splash) | Back | Mythic | 11. Coral Coast | 0.80 |
| Hydra | Specialist (Splash) | Back | Mythic | 5. Misty Marsh | 0.77 |
| Basilisk | Specialist (Stun) | Middle | Mythic | 5. Misty Marsh | 0.80 |
| Sphinx | Specialist (Stun) | Middle | Mythic | 7. Red Rock Canyon | 0.78 |
| Baku | Specialist (Slow) | Middle | Mythic | 9. Emerald Jungle | 0.77 |

## Designed, not rendered yet (0)

| Animal | Class | Row | Rarity | Found in | Batch | Power |
|---|---|---|---|---|---|---|

## New real animals, not rendered yet (0)

| Animal | Class | Row | Rarity | Found in | Batch | Power |
|---|---|---|---|---|---|---|

## Mythical creatures, not rendered yet (0)

| Mythic | Class | Row | Found from | Batch | Power | Behind the legend |
|---|---|---|---|---|---|---|

## Class balance

| Class | In the game | On the way | All | Average power (all) |
|---|---|---|---|---|
| Tank | 22 | 0 | 22 | 0.64 |
| Tank Destroyer | 26 | 0 | 26 | 0.61 |
| Ranged | 20 | 0 | 20 | 0.60 |
| Air | 21 | 0 | 21 | 0.59 |
| Specialist | 33 | 0 | 33 | 0.62 |
