# Animal Arena (working title)

A real-time animal card battler for iOS and Android, made with Godot 4.
You free animals from cages, build an 8-animal deck and battle other players
to climb through arenas. The rarer the card, the rarer the animal in real life:
Commons are Least Concern species, Legendaries are Critically Endangered.

The name and logo are placeholders until we pick real ones.

## What works today

Everything runs offline on your computer, saved on the device:

- **Menus:** five tabs laid out like other mobile card games (Shop, Animals, Battle, Clan, Events)
- **Cards:** 57 animals in 4 rarities, each with stats, an ability and release requirements, plus 6 Ranger tools
- **Deck:** an 8-card battle deck you can edit, plus card leveling with copies and gold
- **Trophies:** 12 arenas on a Trophy Road, and new animals unlock as you climb
- **Cages:** 6 kinds of cage (our chests), with unlock timers, gem skips and a drop-odds screen
- **Ranger level:** an account level, plus player banners, icons and emotes to unlock
- **Shop:** daily animal offers, cages, gold packs and cosmetics
- **Battles** against a computer opponent: animals walk and fight on their own, use their abilities, and attack towers that shoot back. Matches last 3 minutes, with double energy in the last minute and sudden-death overtime. Emotes and quick chat work.
- **Tests:** 70 automated tests for the rules and the battle engine

Not built yet:

- online play and clans
- real art and sound
- store purchases

See [docs/ROADMAP.md](docs/ROADMAP.md).

## Run it

1. Install **Godot 4.7** (the *Standard* version, not .NET) from https://godotengine.org/download
2. Get this repository onto your computer. With GitHub Desktop: *File > Clone repository*.
   Until this work is merged, switch to the branch `claude/funny-brown-sxbcoj`.
3. Open Godot, click **Import**, pick `game/project.godot`, then **Import & Edit**.
4. Press **F5** (or the play button in the top right) to run.

The window is phone-shaped, and a mouse click counts as a tap. Tap your banner
in the top left to open your profile. In test builds the profile has
**developer tools**: free gold and gems, trophies, skipping cage timers,
unlocking every animal and resetting your save.

## Run the tests

From the repository root (with `godot` on your PATH):

```bash
godot --headless --path game res://tests/test_runner.tscn
```

## Where things are

```
game/
  project.godot        Godot project settings (portrait, 720x1280, mobile renderer)
  data/                ALL game content as JSON: animals, arenas, cages, emotes...
  scenes/              main.tscn (menu) and battle.tscn
  scripts/
    autoload/          GameData (loads data/) and Profile (the player's save)
    rules/             Pure game rules: trophies, leveling, cages, release requirements
    ui/                Menu screens, popups, cards, the cage opening
    battle/            Battle engine, abilities, tools, the bot and the battle screen
  tests/               Automated tests for the rules
docs/
  GAME_DESIGN.md       How every system works and why
  ROADMAP.md           What's next, and what you need to do
```

## Changing game content

You don't need to touch code to add or rebalance content. Edit the JSON
files in `game/data/`:

- **New animal:** copy an entry in `animals.json` and change it. Its `unlock_arena` must be an arena id from `arenas.json`, and its tags must exist in `tags.json`. The ability `id` must be one of the types the battle engine knows (listed in `scripts/battle/battle_abilities.gd`).
- **New tool:** same idea in `tools.json`. The effect ids are listed in `scripts/battle/tool_effects.gd`.
- **Battle tuning** (towers, match length, energy): `battle_rules.json`
- **Cage odds:** `cages.json`
- **Trophy and leveling numbers:** `progression.json`
- **Emotes, quick chats, banners and icons:** their own files

Run the tests afterwards. `test_game_data` catches typos like an unknown arena
or tag.
