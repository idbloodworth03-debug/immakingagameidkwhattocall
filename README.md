# Den Duel

![Den Duel](game/art/logo/logo.png)

Den Duel is a real-time animal card battler for iOS and Android, made with Godot 4.
You free animals from cages, build an 8-animal deck and battle other players
to climb through arenas. The rarer the card, the rarer the animal in real life:
Commons are Least Concern species, Legendaries are Critically Endangered.

## What works today

Everything runs offline on your computer, saved on the device:

- **Menus:** five tabs laid out like other mobile card games (Shop, Animals, Battle, Clan, Events)
- **Cards:** 20 animals in 4 rarities, each with stats, an ability and release requirements, plus 6 Ranger tools (37 more animals are designed and waiting)
- **Deck:** an 8-card battle deck you can edit, plus card leveling with copies and gold
- **Trophies:** 12 arenas on a Trophy Road, and new animals unlock as you climb
- **Cages:** 6 kinds of cage (our chests), with unlock timers, gem skips and a drop-odds screen
- **Ranger level:** an account level, plus player banners, icons and emotes to unlock
- **Shop:** daily animal offers, cages, gold packs and cosmetics
- **Battles** against a computer opponent that gets tougher as you climb: drag a card onto the field (or tap it, then tap the field) and the animals walk and fight on their own, use their abilities, and attack the enemy's dens, which fight back. Matches last 3 minutes, with double energy in the last minute and sudden-death overtime. Take a side den and you can release animals deeper on the enemy's side. Emotes and quick chat work.
- **Look and feel:**
  - every animal is a 3D render, with fur, real markings and its own walk and attack animations (made by our Blender pipeline in `tools/creatures/`)
  - rendered card portraits, icons for tools and emotes, arena scenery, and dens (side dens and a main den)
  - chunky mobile-game fonts
  - animations: walking, attacks, screen shake and bouncy buttons
  - sound effects and music, which players can switch off
- **Tests:** 72 automated tests for the rules and the battle engine, plus a balance report that plays hundreds of bot-vs-bot battles

Not built yet:

- online play and clans
- 3D-rendered dens, arenas and tools to match the animals (see [docs/ART_DIRECTION.md](docs/ART_DIRECTION.md))
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

## Play on your iPhone (web version)

Den Duel also runs as a website in Safari, and you can add it to your iPhone's
home screen so it opens full-screen like an app. Every time new work is pushed
to GitHub, the **Web version** workflow (`.github/workflows/web.yml`) runs the
tests, builds the web version and publishes it to your Netlify site.

The site is https://denduel.netlify.app. Its Netlify Project ID is in
`.github/workflows/web.yml`; to publish somewhere else, change it there.

**One-time setup**

1. **Make the project public:** in Netlify, open the project and click
   *Make public*. Otherwise Safari asks you to log in to Netlify.
2. **Make an access token:** click your avatar (top right), then *User
   settings*, *Applications*, *Personal access tokens*, *New access token*.
   Name it "GitHub", pick the longest expiration, and copy the token. It's
   only shown once, and it works like a password, so never paste it into a
   file in this repository.
3. **Give it to GitHub:** on github.com, open this repository, then
   *Settings*, *Secrets and variables*, *Actions*, *New repository secret*.
   Name it `NETLIFY_AUTH_TOKEN` and paste the token as the value.
4. **Publish now:** open the *Actions* tab, click the latest *Web version*
   run, then *Re-run all jobs*. From then on, every push publishes by itself.

**On the iPhone:** open your Netlify link in **Safari**, tap **Share**, then
**Add to Home Screen**. To get an update, close the app completely (swipe it
away) and open it again.

Good to know:
- **Saves:** progress is saved in the browser on that device. The home-screen app and a Safari tab keep separate saves.
- **No sound?** Check the ring/silent switch on the side of the iPhone. Safari mutes web audio in silent mode.
- **Dev tools:** the web version is a release build, so the developer tools in the profile are hidden.
- **Without the token**, each workflow run still builds and tests the game. The finished web version is under *Artifacts* on the run's page (`den-duel-web`), ready to drag into Netlify by hand.
- **Building on your own PC** (optional): run `tools/build_web.sh` (needs Godot and Python), or use Godot's *Project > Export > Web*.

## Run the tests

From the repository root (with `godot` on your PATH):

```bash
godot --headless --path game res://tests/test_runner.tscn
```

To see how every card does in a few hundred bot-vs-bot battles (takes a few
minutes):

```bash
godot --headless --path game res://tests/balance_report.tscn -- 400
```

## Where things are

```
game/
  project.godot        Godot project settings (portrait, 720x1280, mobile renderer)
  data/                ALL game content as JSON: animals, arenas, cages, emotes, art.json...
  art/                 Rendered animals (art/units/), icons (game-icons.net) and fonts
  audio/               Sound effects and music (generated by tools/make_sounds.py)
  scenes/              main.tscn (menu) and battle.tscn
  scripts/
    autoload/          GameData (loads data/) and Profile (the player's save)
    rules/             Pure game rules: trophies, leveling, cages, release requirements
    ui/                Menu screens, popups, cards, the cage opening
    battle/            Battle engine, abilities, tools, the bot and the battle screen
  tests/               Automated tests for the rules, and the balance report
.github/workflows/     web.yml: tests, builds and publishes the web version on every push
docs/
  GAME_DESIGN.md       How every system works and why
  ROADMAP.md           What's next, and what you need to do
  ART_DIRECTION.md     The current look, the plan for final art, and name ideas
tools/
  import_icons.py      Copies the icons listed in art.json into the game
  make_sounds.py       Regenerates every sound effect and music loop
  creatures/           Builds and renders the 3D animals with Blender (see its README)
  build_web.sh         Tests and exports the web version (used by the workflow)
  fetch_web_templates.py  Downloads just Godot's web export templates
CREDITS.md             Who made the icons and fonts (required by their licenses)
```

## Changing game content

You don't need to touch code to add or rebalance content. Edit the JSON
files in `game/data/`:

- **New animal:** copy an entry in `animals.json` and change it. Its `unlock_arena` must be an arena id from `arenas.json`, and its tags must exist in `tags.json`. The ability `id` must be one of the types the battle engine knows (listed in `scripts/battle/battle_abilities.gd`).
- **New tool:** same idea in `tools.json`. The effect ids are listed in `scripts/battle/tool_effects.gd`.
- **Battle tuning** (dens, match length, energy): `battle_rules.json`
- **Cage odds:** `cages.json`
- **Trophy and leveling numbers:** `progression.json`
- **Emotes, quick chats, banners and icons:** their own files
- **Which icon something uses:** `art.json`, then run `tools/import_icons.py`

Run the tests afterwards. `test_game_data` catches typos like an unknown arena
or tag.
