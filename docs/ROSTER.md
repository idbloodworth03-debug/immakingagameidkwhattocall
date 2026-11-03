# Roster

Every animal in the game or on the way: its class (and trait), where it
lines up, its rarity (for real animals, from its IUCN Red List status:
Common = Least Concern, Rare = Near Threatened or Vulnerable, Epic =
Endangered, Legendary = Critically Endangered), where it's found and the
batch it's rendered in. In the game: `game/data/animals.json`; on the way:
`game/data/animals_later.json`.

**Power** is a first measure from bot fights (`game/tests/power_report.tscn`):
the animal joins a random herd of four of today's 20 and fights the same
herd with a random one of today's 20 instead, 48 times, each card at its
starting level. 0.50 is an average pick today. Today's 20 range from 0.08
(Sewer Rats) to 0.85 (Black Rhino); by rarity they average about 0.38
(Common), 0.51 (Rare), 0.58 (Epic) and 0.74 (Legendary). Air scores high
for now because today's herds have so few Ranged and Air animals to hit it;
batch 1 changes that.

## In the game (20)

| Animal | Class | Row | Rarity | Found in | Power |
|---|---|---|---|---|---|
| Sewer Rats | Specialist (Burrow) | Front (then underground) | Common (LC) | 1. Rescue Center | 0.08 |
| Raccoon | Ranged | Back | Common (LC) | 1. Rescue Center | 0.42 |
| Gray Squirrel | Ranged | Back | Common (LC) | 1. Rescue Center | 0.33 |
| Red Fox | Specialist (Burrow) | Front (then underground) | Common (LC) | 1. Rescue Center | 0.19 |
| Peregrine Falcon | Air | Over the middle (own line) | Common (LC) | 1. Rescue Center | 0.44 |
| Wild Boar | Tank Destroyer | Middle | Common (LC) | 2. City Park | 0.54 |
| Wolf Pack | Tank Destroyer | Middle | Common (LC) | 4. Whispering Woods | 0.58 |
| Brown Bear | Tank | Front | Common (LC) | 4. Whispering Woods | 0.44 |
| Cheetah | Tank Destroyer | Middle | Rare (VU) | 1. Rescue Center | 0.35 |
| American Bison | Tank | Front | Rare (NT) | 3. Prairie Fields | 0.50 |
| Hippopotamus | Tank | Front | Rare (VU) | 5. Misty Marsh | 0.56 |
| Lion | Tank Destroyer | Middle | Rare (VU) | 6. Sunbaked Savanna | 0.67 |
| Polar Bear | Tank | Front | Rare (VU) | 11. Coral Coast | 0.48 |
| African Wild Dogs | Tank Destroyer | Middle | Epic (EN) | 6. Sunbaked Savanna | 0.44 |
| Tiger | Tank Destroyer | Middle | Epic (EN) | 9. Emerald Jungle | 0.81 |
| Asian Elephant | Tank | Front | Epic (EN) | 9. Emerald Jungle | 0.83 |
| Red Panda | Specialist (Slow) | Middle | Epic (EN) | 10. Cloudpeak Mountains | 0.25 |
| Black Rhino | Tank | Front | Legendary (CR) | 12. Last Sanctuary | 0.85 |
| California Condor | Air | Over the middle (own line) | Legendary (CR) | 7. Red Rock Canyon | 0.71 |
| Amur Leopard | Tank Destroyer | Middle | Legendary (CR) | 8. Frozen Tundra | 0.65 |

## Designed, not rendered yet (37)

| Animal | Class | Row | Rarity | Found in | Batch | Power |
|---|---|---|---|---|---|---|
| Pigeon Flock | Air | Over the middle (own line) | Common (LC) | 1. Rescue Center | 1 | 0.29 |
| Opossum | Tank | Front | Common (LC) | 1. Rescue Center | 2 | 0.12 |
| Murder of Crows | Air | Over the middle (own line) | Common (LC) | 2. City Park | 1 | 0.54 |
| Striped Skunk | Ranged | Back | Common (LC) | 2. City Park | 1 | 0.31 |
| Coyote Pack | Tank Destroyer | Middle | Common (LC) | 3. Prairie Fields | 2 | 0.65 |
| Barn Owl | Air | Over the middle (own line) | Common (LC) | 3. Prairie Fields | 1 | 0.52 |
| Bullfrog | Ranged | Back | Common (LC) | 5. Misty Marsh | 1 | 0.38 |
| Snapping Turtle | Tank | Front | Common (LC) | 5. Misty Marsh | 2 | 0.19 |
| Honey Badger | Tank Destroyer | Middle | Common (LC) | 6. Sunbaked Savanna | 2 | 0.29 |
| Spotted Hyenas | Tank Destroyer | Middle | Common (LC) | 6. Sunbaked Savanna | 2 | 0.52 |
| Rattlesnake | Specialist (Stun) | Middle | Common (LC) | 7. Red Rock Canyon | 2 | 0.19 |
| Moose | Tank | Front | Common (LC) | 8. Frozen Tundra | 2 | 0.29 |
| Mountain Goat | Ranged | Back | Common (LC) | 10. Cloudpeak Mountains | 1 | 0.50 |
| Harbor Seal | Specialist (Splash) | Back | Common (LC) | 11. Coral Coast | 2 | 0.17 |
| Platypus | Specialist (Slow) | Middle | Rare (NT) | 1. Rescue Center | 2 | 0.21 |
| Eastern Box Turtle | Tank | Front | Rare (VU) | 2. City Park | 2 | 0.10 |
| Gila Monster | Specialist (Slow) | Middle | Rare (NT) | 7. Red Rock Canyon | 2 | 0.31 |
| Walrus | Specialist (Splash) | Back | Rare (VU) | 8. Frozen Tundra | 2 | 0.35 |
| Jaguar | Tank Destroyer | Middle | Rare (NT) | 9. Emerald Jungle | 2 | 0.54 |
| King Cobra | Ranged | Back | Rare (VU) | 9. Emerald Jungle | 1 | 0.58 |
| Snow Leopard | Tank Destroyer | Middle | Rare (VU) | 10. Cloudpeak Mountains | 2 | 0.40 |
| Giant Panda | Tank | Front | Rare (VU) | 10. Cloudpeak Mountains | 2 | 0.35 |
| Loggerhead Turtle | Tank | Front | Rare (VU) | 11. Coral Coast | 2 | 0.08 |
| Black-footed Ferret | Specialist (Burrow) | Front (then underground) | Epic (EN) | 3. Prairie Fields | 2 | 0.19 |
| Whooping Crane | Air | Over the middle (own line) | Epic (EN) | 5. Misty Marsh | 1 | 0.71 |
| Chimpanzee | Ranged | Back | Epic (EN) | 9. Emerald Jungle | 1 | 0.38 |
| Mountain Gorilla | Specialist (Stun) | Middle | Epic (EN) | 10. Cloudpeak Mountains | 2 | 0.75 |
| Sea Otter | Ranged | Back | Epic (EN) | 11. Coral Coast | 1 | 0.54 |
| Komodo Dragon | Tank Destroyer | Middle | Epic (EN) | 11. Coral Coast | 2 | 0.54 |
| Red Wolf | Tank Destroyer | Middle | Legendary (CR) | 4. Whispering Woods | 2 | 0.56 |
| Axolotl | Specialist (Slow) | Middle | Legendary (CR) | 5. Misty Marsh | 2 | 0.21 |
| Sunda Pangolin | Specialist (Burrow) | Front (then underground) | Legendary (CR) | 9. Emerald Jungle | 2 | 0.19 |
| Saola | Tank | Front | Legendary (CR) | 10. Cloudpeak Mountains | 2 | 0.46 |
| African Penguins | Specialist (Splash) | Back | Legendary (CR) | 11. Coral Coast | 2 | 0.52 |
| Kakapo | Specialist (Stun) | Middle | Legendary (CR) | 12. Last Sanctuary | 2 | 0.15 |
| Philippine Eagle | Air | Over the middle (own line) | Legendary (CR) | 12. Last Sanctuary | 1 | 0.88 |
| Sumatran Orangutan | Ranged | Back | Legendary (CR) | 12. Last Sanctuary | 1 | 0.75 |

## New real animals (41)

| Animal | Class | Row | Rarity | Found in | Batch | Power |
|---|---|---|---|---|---|---|
| Harpy Eagle *Harpia harpyja* | Air | Over the middle (own line) | Rare (VU) | 9. Emerald Jungle | 1 | 0.81 |
| Steller's Sea Eagle *Haliaeetus pelagicus* | Air | Over the middle (own line) | Rare (VU) | 8. Frozen Tundra | 1 | 0.79 |
| Snowy Owl *Bubo scandiacus* | Air | Over the middle (own line) | Rare (VU) | 8. Frozen Tundra | 1 | 0.60 |
| Hyacinth Macaw *Anodorhynchus hyacinthinus* | Air | Over the middle (own line) | Rare (VU) | 9. Emerald Jungle | 1 | 0.69 |
| Helmeted Hornbill *Rhinoplax vigil* | Air | Over the middle (own line) | Legendary (CR) | 12. Last Sanctuary | 1 | 0.88 |
| Atlantic Puffin *Fratercula arctica* | Air | Over the middle (own line) | Rare (VU) | 8. Frozen Tundra | 1 | 0.50 |
| Wandering Albatross *Diomedea exulans* | Air | Over the middle (own line) | Rare (VU) | 8. Frozen Tundra | 1 | 0.69 |
| Flying Fox Colony *Pteropus poliocephalus* | Air | Over the middle (own line) | Rare (VU) | 2. City Park | 1 | 0.65 |
| Monarch Butterflies *Danaus plexippus plexippus* | Air | Over the middle (own line) | Rare (VU) | 2. City Park | 1 | 0.40 |
| Wild Bactrian Camel *Camelus ferus* | Ranged | Back | Epic (EN) | 7. Red Rock Canyon | 1 | 0.77 |
| Porcupine *Erethizon dorsatum* | Ranged | Back | Common (LC) | 4. Whispering Woods | 1 | 0.33 |
| Texas Horned Lizard *Phrynosoma cornutum* | Ranged | Back | Common (LC) | 7. Red Rock Canyon | 1 | 0.27 |
| Archerfish *Toxotes jaculatrix* | Ranged | Back | Common (LC) | 5. Misty Marsh | 1 | 0.33 |
| Pink River Dolphin *Inia geoffrensis* | Ranged | Back | Epic (EN) | 9. Emerald Jungle | 1 | 0.65 |
| Bonobo *Pan paniscus* | Ranged | Back | Epic (EN) | 9. Emerald Jungle | 1 | 0.44 |
| Pistol Shrimp *Alpheus heterochaelis* | Ranged | Back | Common (NE) | 11. Coral Coast | 1 | 0.23 |
| Galápagos Giant Tortoise *Chelonoidis porteri* | Tank | Front | Legendary (CR) | 12. Last Sanctuary | 3 | 0.40 |
| West Indian Manatee *Trichechus manatus* | Tank | Front | Rare (VU) | 5. Misty Marsh | 3 | 0.33 |
| Malayan Tapir *Tapirus indicus* | Tank | Front | Epic (EN) | 9. Emerald Jungle | 3 | 0.48 |
| Gaur *Bos gaurus* | Tank | Front | Rare (VU) | 4. Whispering Woods | 3 | 0.58 |
| Pygmy Hippo *Choeropsis liberiensis* | Tank | Front | Epic (EN) | 5. Misty Marsh | 3 | 0.25 |
| Andean Bear *Tremarctos ornatus* | Tank | Front | Rare (VU) | 10. Cloudpeak Mountains | 3 | 0.42 |
| Tasmanian Devil *Sarcophilus harrisii* | Tank Destroyer | Middle | Epic (EN) | 4. Whispering Woods | 3 | 0.31 |
| Iberian Lynx *Lynx pardinus* | Tank Destroyer | Middle | Rare (VU) | 4. Whispering Woods | 3 | 0.48 |
| Wolverine *Gulo gulo* | Tank Destroyer | Middle | Common (LC) | 8. Frozen Tundra | 3 | 0.33 |
| Gharial *Gavialis gangeticus* | Tank Destroyer | Middle | Legendary (CR) | 12. Last Sanctuary | 3 | 0.69 |
| Great Hammerhead Shark *Sphyrna mokarran* | Tank Destroyer | Middle | Legendary (CR) | 11. Coral Coast | 3 | 0.69 |
| Shoebill *Balaeniceps rex* | Tank Destroyer | Middle | Rare (VU) | 5. Misty Marsh | 3 | 0.25 |
| Fossa *Cryptoprocta ferox* | Tank Destroyer | Middle | Rare (VU) | 9. Emerald Jungle | 3 | 0.50 |
| Northern Hairy-nosed Wombat *Lasiorhinus krefftii* | Specialist (Burrow) | Front (then underground) | Legendary (CR) | 6. Sunbaked Savanna | 3 | 0.29 |
| Greater Bilby *Macrotis lagotis* | Specialist (Burrow) | Front (then underground) | Rare (VU) | 3. Prairie Fields | 3 | 0.21 |
| Aardvark *Orycteropus afer* | Specialist (Burrow) | Front (then underground) | Common (LC) | 6. Sunbaked Savanna | 3 | 0.19 |
| Gopher Tortoise *Gopherus polyphemus* | Specialist (Burrow) | Front (then underground) | Legendary (CR) | 3. Prairie Fields | 3 | 0.12 |
| Humpback Whale *Megaptera novaeangliae* | Specialist (Splash) | Back | Common (LC) | 11. Coral Coast | 3 | 0.33 |
| Giant Manta Ray *Mobula birostris* | Specialist (Splash) | Back | Epic (EN) | 11. Coral Coast | 3 | 0.27 |
| Electric Eel *Electrophorus electricus* | Specialist (Stun) | Middle | Common (LC) | 5. Misty Marsh | 3 | 0.17 |
| Howler Monkey *Alouatta palliata* | Specialist (Stun) | Middle | Rare (VU) | 9. Emerald Jungle | 3 | 0.15 |
| Philippine Tarsier *Carlito syrichta* | Specialist (Stun) | Middle | Rare (NT) | 12. Last Sanctuary | 3 | 0.23 |
| Pygmy Three-toed Sloth *Bradypus pygmaeus* | Specialist (Slow) | Middle | Legendary (CR) | 12. Last Sanctuary | 3 | 0.10 |
| Slow Loris *Nycticebus coucang* | Specialist (Slow) | Middle | Epic (EN) | 9. Emerald Jungle | 3 | 0.06 |
| Chinese Giant Salamander *Andrias davidianus* | Specialist (Slow) | Middle | Legendary (CR) | 10. Cloudpeak Mountains | 3 | 0.27 |

## Mythical creatures (24)

| Mythic | Class | Row | Found from | Batch | Power | Behind the legend |
|---|---|---|---|---|---|---|
| Phoenix | Air | Over the middle (own line) | 12. Last Sanctuary | 1 | 0.88 | One theory: Egypt's sacred Bennu bird, drawn as a heron, inspired the Greek phoenix. |
| Dragon | Air | Over the middle (own line) | 10. Cloudpeak Mountains | 1 | 0.85 | In China, fossil bones were long sold as 'dragon bones' for medicine. |
| Griffin | Air | Over the middle (own line) | 6. Sunbaked Savanna | 1 | 0.88 | One theory suggests ancient fossil hunters mistook dinosaur skeletons for griffins. |
| Pegasus | Air | Over the middle (own line) | 10. Cloudpeak Mountains | 1 | 0.92 | From Greek myth: the winged horse tamed by the hero Bellerophon. |
| Roc | Air | Over the middle (own line) | 10. Cloudpeak Mountains | 1 | 0.96 | One theory: the giant elephant bird of Madagascar, now extinct. |
| Kitsune | Ranged | Back | 4. Whispering Woods | 1 | 0.58 | Kitsune are the red foxes of Japanese folklore; fox statues guard Inari shrines all over Japan. (links to: Red Fox) |
| Qilin | Ranged | Back | 9. Emerald Jungle | 1 | 0.69 | When a giraffe was brought to the Chinese emperor in 1414, people called it a qilin. |
| Jackalope | Ranged | Back | 3. Prairie Fields | 1 | 0.35 | One theory: rabbits with a virus that grows horn-like bumps on their heads. |
| Unicorn | Ranged | Back | 4. Whispering Woods | 1 | 0.81 | Narwhal tusks were once sold in Europe as unicorn horns. |
| Yeti | Tank | Front | 8. Frozen Tundra | 4 | 0.83 | A 2017 DNA study found most supposed Yeti samples came from bears. (links to: Brown Bear) |
| Bigfoot | Tank | Front | 4. Whispering Woods | 4 | 0.75 | One theory: many sightings are black bears walking on their hind legs. |
| Black Tortoise | Tank | Front | 11. Coral Coast | 4 | 0.85 | From Chinese star lore: the guardian of the north, a tortoise wound with a snake. |
| Fenrir | Tank Destroyer | Middle | 8. Frozen Tundra | 4 | 0.85 | From Norse myth: a giant wolf the gods could only hold with a magic ribbon. |
| Nemean Lion | Tank Destroyer | Middle | 6. Sunbaked Savanna | 4 | 0.83 | Lions really lived in ancient Greece, until about 2,000 years ago. (links to: Lion) |
| Cerberus | Tank Destroyer | Middle | 12. Last Sanctuary | 4 | 0.79 | From Greek myth: the three-headed dog that guards the gate of the underworld. |
| Manticore | Tank Destroyer | Middle | 6. Sunbaked Savanna | 4 | 0.71 | One theory: Greek writers heard Persian tales of the tiger and turned it into a monster. (links to: Tiger) |
| Chupacabra | Tank Destroyer | Middle | 7. Red Rock Canyon | 4 | 0.65 | Many 'chupacabras' found in the US turned out to be coyotes with mange. (links to: Coyote Pack) |
| Loch Ness Monster | Specialist (Burrow) | Front (then underground) | 5. Misty Marsh | 4 | 0.35 | A 2018 DNA survey of Loch Ness found lots of eel DNA and no reptile DNA. |
| Mongolian Death Worm | Specialist (Burrow) | Front (then underground) | 7. Red Rock Canyon | 4 | 0.29 | Told by nomads of the Gobi Desert; explorer Roy Chapman Andrews wrote about it in 1926. |
| Kraken | Specialist (Splash) | Back | 11. Coral Coast | 4 | 0.52 | Likely inspired by sightings of giant squid. |
| Hydra | Specialist (Splash) | Back | 5. Misty Marsh | 4 | 0.46 | The tiny freshwater hydra, which regrows when cut, was named after it. |
| Basilisk | Specialist (Stun) | Middle | 5. Misty Marsh | 4 | 0.48 | The real basilisk lizard, which runs across water, was named after it. |
| Sphinx | Specialist (Stun) | Middle | 7. Red Rock Canyon | 4 | 0.33 | Egypt's Great Sphinx, a lion with a human head, was carved about 4,500 years ago. |
| Baku | Specialist (Slow) | Middle | 9. Emerald Jungle | 4 | 0.33 | In Japanese, the word for tapir is baku, and the dream-eater is often drawn like one. (links to: Malayan Tapir) |

## Class balance once everything is in

| Class | Now | Batch 1 adds | All batches |
|---|---|---|---|
| Tank | 6 | 0 | 22 |
| Tank Destroyer | 7 | 0 | 26 |
| Ranged | 2 | 18 | 20 |
| Air | 2 | 19 | 21 |
| Specialist | 3 | 0 | 33 |
