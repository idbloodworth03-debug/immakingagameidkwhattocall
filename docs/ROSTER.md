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
0.75-0.80 for Mythic.

## In the game (122)

| Animal | Class | Row | Rarity | Found in | Power |
|---|---|---|---|---|---|
| Sewer Rats | Specialist (Burrow) | Front (then underground) | Common (LC) | 1. Rescue Center | 0.46 |
| Raccoon | Ranged | Back | Common (LC) | 1. Rescue Center | 0.43 |
| Gray Squirrel | Ranged | Back | Common (LC) | 1. Rescue Center | 0.46 |
| Red Fox | Specialist (Burrow) | Front (then underground) | Common (LC) | 1. Rescue Center | 0.45 |
| Peregrine Falcon | Air | Over the middle (own line) | Common (LC) | 1. Rescue Center | 0.45 |
| Wild Boar | Tank Destroyer | Middle | Common (LC) | 2. City Park | 0.44 |
| Wolf Pack | Tank Destroyer | Middle | Common (LC) | 4. Whispering Woods | 0.42 |
| Brown Bear | Tank | Front | Common (LC) | 4. Whispering Woods | 0.48 |
| Cheetah | Tank Destroyer | Middle | Rare (VU) | 1. Rescue Center | 0.54 |
| American Bison | Tank | Front | Rare (NT) | 3. Prairie Fields | 0.53 |
| Hippopotamus | Tank | Front | Rare (VU) | 5. Misty Marsh | 0.57 |
| Lion | Tank Destroyer | Middle | Rare (VU) | 6. Sunbaked Savanna | 0.53 |
| Polar Bear | Tank | Front | Rare (VU) | 11. Coral Coast | 0.49 |
| African Wild Dogs | Tank Destroyer | Middle | Epic (EN) | 6. Sunbaked Savanna | 0.64 |
| Tiger | Tank Destroyer | Middle | Epic (EN) | 9. Emerald Jungle | 0.64 |
| Asian Elephant | Tank | Front | Epic (EN) | 9. Emerald Jungle | 0.63 |
| Red Panda | Specialist (Slow) | Middle | Epic (EN) | 10. Cloudpeak Mountains | 0.70 |
| Black Rhino | Tank | Front | Legendary (CR) | 12. Last Sanctuary | 0.75 |
| California Condor | Air | Over the middle (own line) | Legendary (CR) | 7. Red Rock Canyon | 0.75 |
| Amur Leopard | Tank Destroyer | Middle | Legendary (CR) | 8. Frozen Tundra | 0.75 |
| Pigeon Flock | Air | Over the middle (own line) | Common (LC) | 1. Rescue Center | 0.46 |
| Murder of Crows | Air | Over the middle (own line) | Common (LC) | 2. City Park | 0.48 |
| Striped Skunk | Ranged | Back | Common (LC) | 2. City Park | 0.38 |
| Barn Owl | Air | Over the middle (own line) | Common (LC) | 3. Prairie Fields | 0.40 |
| Bullfrog | Ranged | Back | Common (LC) | 5. Misty Marsh | 0.42 |
| Mountain Goat | Ranged | Back | Common (LC) | 10. Cloudpeak Mountains | 0.47 |
| King Cobra | Ranged | Back | Rare (VU) | 9. Emerald Jungle | 0.54 |
| Whooping Crane | Air | Over the middle (own line) | Epic (EN) | 5. Misty Marsh | 0.61 |
| Chimpanzee | Ranged | Back | Epic (EN) | 9. Emerald Jungle | 0.60 |
| Sea Otter | Ranged | Back | Epic (EN) | 11. Coral Coast | 0.62 |
| Philippine Eagle | Air | Over the middle (own line) | Legendary (CR) | 12. Last Sanctuary | 0.78 |
| Sumatran Orangutan | Ranged | Back | Legendary (CR) | 12. Last Sanctuary | 0.75 |
| Harpy Eagle | Air | Over the middle (own line) | Rare (VU) | 9. Emerald Jungle | 0.53 |
| Steller's Sea Eagle | Air | Over the middle (own line) | Rare (VU) | 8. Frozen Tundra | 0.48 |
| Snowy Owl | Air | Over the middle (own line) | Rare (VU) | 8. Frozen Tundra | 0.57 |
| Hyacinth Macaw | Air | Over the middle (own line) | Rare (VU) | 9. Emerald Jungle | 0.55 |
| Helmeted Hornbill | Air | Over the middle (own line) | Legendary (CR) | 12. Last Sanctuary | 0.75 |
| Atlantic Puffin | Air | Over the middle (own line) | Rare (VU) | 8. Frozen Tundra | 0.50 |
| Wandering Albatross | Air | Over the middle (own line) | Rare (VU) | 8. Frozen Tundra | 0.51 |
| Flying Fox Colony | Air | Over the middle (own line) | Rare (VU) | 2. City Park | 0.57 |
| Monarch Butterflies | Air | Over the middle (own line) | Rare (VU) | 2. City Park | 0.54 |
| Wild Bactrian Camel | Ranged | Back | Epic (EN) | 7. Red Rock Canyon | 0.70 |
| Porcupine | Ranged | Back | Common (LC) | 4. Whispering Woods | 0.49 |
| Texas Horned Lizard | Ranged | Back | Common (LC) | 7. Red Rock Canyon | 0.44 |
| Archerfish | Ranged | Back | Common (LC) | 5. Misty Marsh | 0.43 |
| Pink River Dolphin | Ranged | Back | Epic (EN) | 9. Emerald Jungle | 0.59 |
| Bonobo | Ranged | Back | Epic (EN) | 9. Emerald Jungle | 0.58 |
| Pistol Shrimp | Ranged | Back | Common (NE) | 11. Coral Coast | 0.45 |
| Phoenix | Air | Over the middle (own line) | Mythic | 12. Last Sanctuary | 0.75 |
| Dragon | Air | Over the middle (own line) | Mythic | 10. Cloudpeak Mountains | 0.77 |
| Griffin | Air | Over the middle (own line) | Mythic | 6. Sunbaked Savanna | 0.79 |
| Pegasus | Air | Over the middle (own line) | Mythic | 10. Cloudpeak Mountains | 0.77 |
| Roc | Air | Over the middle (own line) | Mythic | 10. Cloudpeak Mountains | 0.78 |
| Kitsune | Ranged | Back | Mythic | 4. Whispering Woods | 0.73 |
| Qilin | Ranged | Back | Mythic | 9. Emerald Jungle | 0.76 |
| Jackalope | Ranged | Back | Mythic | 3. Prairie Fields | 0.77 |
| Unicorn | Ranged | Back | Mythic | 4. Whispering Woods | 0.75 |
| Opossum | Tank | Front | Common (LC) | 1. Rescue Center | 0.45 |
| Coyote Pack | Tank Destroyer | Middle | Common (LC) | 3. Prairie Fields | 0.46 |
| Snapping Turtle | Tank | Front | Common (LC) | 5. Misty Marsh | 0.45 |
| Honey Badger | Tank Destroyer | Middle | Common (LC) | 6. Sunbaked Savanna | 0.44 |
| Spotted Hyenas | Tank Destroyer | Middle | Common (LC) | 6. Sunbaked Savanna | 0.47 |
| Rattlesnake | Specialist (Stun) | Middle | Common (LC) | 7. Red Rock Canyon | 0.44 |
| Moose | Tank | Front | Common (LC) | 8. Frozen Tundra | 0.45 |
| Harbor Seal | Specialist (Splash) | Back | Common (LC) | 11. Coral Coast | 0.46 |
| Platypus | Specialist (Slow) | Middle | Rare (NT) | 1. Rescue Center | 0.57 |
| Eastern Box Turtle | Tank | Front | Rare (VU) | 2. City Park | 0.51 |
| Gila Monster | Specialist (Slow) | Middle | Rare (NT) | 7. Red Rock Canyon | 0.54 |
| Walrus | Specialist (Splash) | Back | Rare (VU) | 8. Frozen Tundra | 0.59 |
| Jaguar | Tank Destroyer | Middle | Rare (NT) | 9. Emerald Jungle | 0.61 |
| Snow Leopard | Tank Destroyer | Middle | Rare (VU) | 10. Cloudpeak Mountains | 0.53 |
| Giant Panda | Tank | Front | Rare (VU) | 10. Cloudpeak Mountains | 0.47 |
| Loggerhead Turtle | Tank | Front | Rare (VU) | 11. Coral Coast | 0.52 |
| Black-footed Ferret | Specialist (Burrow) | Front (then underground) | Epic (EN) | 3. Prairie Fields | 0.63 |
| Mountain Gorilla | Specialist (Stun) | Middle | Epic (EN) | 10. Cloudpeak Mountains | 0.68 |
| Komodo Dragon | Tank Destroyer | Middle | Epic (EN) | 11. Coral Coast | 0.61 |
| Red Wolf | Tank Destroyer | Middle | Legendary (CR) | 4. Whispering Woods | 0.74 |
| Axolotl | Specialist (Slow) | Middle | Legendary (CR) | 5. Misty Marsh | 0.74 |
| Sunda Pangolin | Specialist (Burrow) | Front (then underground) | Legendary (CR) | 9. Emerald Jungle | 0.74 |
| Saola | Tank | Front | Legendary (CR) | 10. Cloudpeak Mountains | 0.73 |
| African Penguins | Specialist (Splash) | Back | Legendary (CR) | 11. Coral Coast | 0.75 |
| Kakapo | Specialist (Stun) | Middle | Legendary (CR) | 12. Last Sanctuary | 0.73 |
| Galápagos Giant Tortoise | Tank | Front | Legendary (CR) | 12. Last Sanctuary | 0.78 |
| West Indian Manatee | Tank | Front | Rare (VU) | 5. Misty Marsh | 0.51 |
| Malayan Tapir | Tank | Front | Epic (EN) | 9. Emerald Jungle | 0.63 |
| Gaur | Tank | Front | Rare (VU) | 4. Whispering Woods | 0.56 |
| Pygmy Hippo | Tank | Front | Epic (EN) | 5. Misty Marsh | 0.65 |
| Andean Bear | Tank | Front | Rare (VU) | 10. Cloudpeak Mountains | 0.53 |
| Tasmanian Devil | Tank Destroyer | Middle | Epic (EN) | 4. Whispering Woods | 0.65 |
| Iberian Lynx | Tank Destroyer | Middle | Rare (VU) | 4. Whispering Woods | 0.57 |
| Wolverine | Tank Destroyer | Middle | Common (LC) | 8. Frozen Tundra | 0.45 |
| Gharial | Tank Destroyer | Middle | Legendary (CR) | 12. Last Sanctuary | 0.74 |
| Great Hammerhead Shark | Tank Destroyer | Middle | Legendary (CR) | 11. Coral Coast | 0.73 |
| Shoebill | Tank Destroyer | Middle | Rare (VU) | 5. Misty Marsh | 0.52 |
| Fossa | Tank Destroyer | Middle | Rare (VU) | 9. Emerald Jungle | 0.53 |
| Northern Hairy-nosed Wombat | Specialist (Burrow) | Front (then underground) | Legendary (CR) | 6. Sunbaked Savanna | 0.77 |
| Greater Bilby | Specialist (Burrow) | Front (then underground) | Rare (VU) | 3. Prairie Fields | 0.54 |
| Aardvark | Specialist (Burrow) | Front (then underground) | Common (LC) | 6. Sunbaked Savanna | 0.42 |
| Gopher Tortoise | Specialist (Burrow) | Front (then underground) | Legendary (CR) | 3. Prairie Fields | 0.77 |
| Humpback Whale | Specialist (Splash) | Back | Common (LC) | 11. Coral Coast | 0.44 |
| Giant Manta Ray | Specialist (Splash) | Back | Epic (EN) | 11. Coral Coast | 0.64 |
| Electric Eel | Specialist (Stun) | Middle | Common (LC) | 5. Misty Marsh | 0.42 |
| Howler Monkey | Specialist (Stun) | Middle | Rare (VU) | 9. Emerald Jungle | 0.50 |
| Philippine Tarsier | Specialist (Stun) | Middle | Rare (NT) | 12. Last Sanctuary | 0.57 |
| Pygmy Three-toed Sloth | Specialist (Slow) | Middle | Legendary (CR) | 12. Last Sanctuary | 0.74 |
| Slow Loris | Specialist (Slow) | Middle | Epic (EN) | 9. Emerald Jungle | 0.63 |
| Chinese Giant Salamander | Specialist (Slow) | Middle | Legendary (CR) | 10. Cloudpeak Mountains | 0.77 |
| Yeti | Tank | Front | Mythic | 8. Frozen Tundra | 0.80 |
| Bigfoot | Tank | Front | Mythic | 4. Whispering Woods | 0.76 |
| Black Tortoise | Tank | Front | Mythic | 11. Coral Coast | 0.77 |
| Fenrir | Tank Destroyer | Middle | Mythic | 8. Frozen Tundra | 0.79 |
| Nemean Lion | Tank Destroyer | Middle | Mythic | 6. Sunbaked Savanna | 0.75 |
| Cerberus | Tank Destroyer | Middle | Mythic | 12. Last Sanctuary | 0.78 |
| Manticore | Tank Destroyer | Middle | Mythic | 6. Sunbaked Savanna | 0.78 |
| Chupacabra | Tank Destroyer | Middle | Mythic | 7. Red Rock Canyon | 0.76 |
| Loch Ness Monster | Specialist (Burrow) | Front (then underground) | Mythic | 5. Misty Marsh | 0.79 |
| Mongolian Death Worm | Specialist (Burrow) | Front (then underground) | Mythic | 7. Red Rock Canyon | 0.77 |
| Kraken | Specialist (Splash) | Back | Mythic | 11. Coral Coast | 0.78 |
| Hydra | Specialist (Splash) | Back | Mythic | 5. Misty Marsh | 0.76 |
| Basilisk | Specialist (Stun) | Middle | Mythic | 5. Misty Marsh | 0.78 |
| Sphinx | Specialist (Stun) | Middle | Mythic | 7. Red Rock Canyon | 0.75 |
| Baku | Specialist (Slow) | Middle | Mythic | 9. Emerald Jungle | 0.76 |

## Mythics and the real animals behind them (24)

Each Mythic's card has a Ranger Journal with this line; a linked animal opens its card.

| Mythic | Behind the legend | Links to |
|---|---|---|
| Phoenix | One theory: Egypt's sacred Bennu bird, drawn as a heron, inspired the Greek phoenix. |  |
| Dragon | In China, fossil bones were long sold as 'dragon bones' for medicine. |  |
| Griffin | One theory suggests ancient fossil hunters mistook dinosaur skeletons for griffins. |  |
| Pegasus | From Greek myth: the winged horse tamed by the hero Bellerophon. |  |
| Roc | One theory: the giant elephant bird of Madagascar, now extinct. |  |
| Kitsune | Kitsune are the red foxes of Japanese folklore; fox statues guard Inari shrines all over Japan. | Red Fox |
| Qilin | When a giraffe was brought to the Chinese emperor in 1414, people called it a qilin. |  |
| Jackalope | One theory: rabbits with a virus that grows horn-like bumps on their heads. |  |
| Unicorn | Narwhal tusks were once sold in Europe as unicorn horns. |  |
| Yeti | A 2017 DNA study found most supposed Yeti samples came from bears. | Brown Bear |
| Bigfoot | One theory: many sightings are black bears walking on their hind legs. |  |
| Black Tortoise | From Chinese star lore: the guardian of the north, a tortoise wound with a snake. |  |
| Fenrir | From Norse myth: a giant wolf the gods could only hold with a magic ribbon. |  |
| Nemean Lion | Lions really lived in ancient Greece, until about 2,000 years ago. | Lion |
| Cerberus | From Greek myth: the three-headed dog that guards the gate of the underworld. |  |
| Manticore | One theory: Greek writers heard Persian tales of the tiger and turned it into a monster. | Tiger |
| Chupacabra | Many 'chupacabras' found in the US turned out to be coyotes with mange. | Coyote Pack |
| Loch Ness Monster | A 2018 DNA survey of Loch Ness found lots of eel DNA and no reptile DNA. |  |
| Mongolian Death Worm | Told by nomads of the Gobi Desert; explorer Roy Chapman Andrews wrote about it in 1926. |  |
| Kraken | Likely inspired by sightings of giant squid. |  |
| Hydra | The tiny freshwater hydra, which regrows when cut, was named after it. |  |
| Basilisk | The real basilisk lizard, which runs across water, was named after it. |  |
| Sphinx | Egypt's Great Sphinx, a lion with a human head, was carved about 4,500 years ago. |  |
| Baku | In Japanese, the word for tapir is baku, and the dream-eater is often drawn like one. | Malayan Tapir |

## Class balance

| Class | In the game | On the way | All | Average power (all) |
|---|---|---|---|---|
| Tank | 22 | 0 | 22 | 0.59 |
| Tank Destroyer | 26 | 0 | 26 | 0.61 |
| Ranged | 20 | 0 | 20 | 0.57 |
| Air | 21 | 0 | 21 | 0.61 |
| Specialist | 33 | 0 | 33 | 0.64 |
