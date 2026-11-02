# Den Duel

![Den Duel](game/art/logo/logo.png)

Den Duel is an animal battler for iOS and Android, made with Godot 4. In
**Draft Duel**, the main mode, you and your opponent take turns drafting
animals, place your herds, bet Acorns on the fight and knock down each
other's dens round by round. There's also a **Classic battle**, a real-time
card battler. You free animals from cages and climb through arenas. The
rarer the card, the rarer the animal in real life: Commons are Least
Concern species, Legendaries are Critically Endangered.

## What works today

Everything runs offline on your computer, saved on the device:

- **Menus:** five tabs laid out like other mobile card games (Shop, Animals, Battle, Clan, Events)
- **Cards:** 20 animals in 4 rarities, each with stats, an ability and release requirements, plus 6 Ranger tools (37 more animals are designed and waiting)
- **Deck:** an 8-card battle deck you can edit, plus card leveling with copies and gold
- **Trophies:** 12 arenas on a Trophy Road, and new animals unlock as you climb
- **Cages:** 6 kinds of cage (our chests), with unlock timers, gem skips and a drop-odds screen
- **Ranger level:** an account level, plus player banners, icons and emotes to unlock
- **Shop:** daily animal offers, cages, gold packs and cosmetics
- **Draft Duel** against a computer opponent: draft at the Watering Hole (with a Mystery Crate), place your herd with no clock running, back it at the Bookie's odds, Rally once a fight, use your tools, and raise, call or fold at halftime. Dens carry their damage from round to round. Choose Safe, Bold or All-in trophy stakes. See "Draft Duel" in [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md).
- **Classic battles** against a computer opponent that gets tougher as you climb: drag a card onto the field (or tap it, then tap the field) and the animals walk and fight on their own, use their abilities, and attack the enemy's dens, which fight back. Matches last 3 minutes, with double energy in the last minute and sudden-death overtime. Take a side den and you can release animals deeper on the enemy's side. Emotes and quick chat work.
- **Look and feel:**
  - every animal is a 3D render, with fur, real markings and its own walk and attack animations (made by our Blender pipeline in `tools/creatures/`)
  - 12 rendered arenas (river, bridges, paths and themed scenery) and treehouse dens
  - polished cartoon menus: glossy pressable buttons, raised panels, cards with rarity rims and portraits, an icon tab bar, and popups that pop in
  - chunky mobile-game fonts
  - animations: walking, attacks, screen shake, bouncy buttons and smooth screen fades
  - sound effects and music, which players can switch off
- **Tests:** 100 automated tests for the rules, the battle engine and Draft Duel, plus reports that play hundreds of bot-vs-bot battles

Not built yet:

- online play and clans
- 3D-rendered tool effects and cages to match the animals (see [docs/ART_DIRECTION.md](docs/ART_DIRECTION.md))
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
tests, builds the web version and publishes it with **GitHub Pages**, which is
free for public repositories, with no limit on how often it publishes.

The site is https://idbloodworth03-debug.github.io/immakingagameidkwhattocall/

**One-time setup** (on github.com, in this repository):

1. **Switch on GitHub Pages:** *Settings*, then *Pages* (left side). Under
   *Build and deployment*, set *Source* to **GitHub Actions**.
2. **Publish now:** open the *Actions* tab, click the latest *Web version*
   run, then *Re-run all jobs*. From then on, every push publishes by itself.
   You can also click *Web version* on the left, then *Run workflow*.

If a publish fails, the run's *publish* job says why. If it says the branch
isn't allowed to deploy to `github-pages`, go to *Settings*, *Environments*,
**github-pages**, and under *Deployment branches and tags* add a rule for
`claude/*` (or choose *No restriction*), then re-run.

**Moving from Netlify:** the old site (denduel.netlify.app) no longer gets
updates. Saves belong to the website they were made on, so the new site
starts a fresh profile. Delete the old home-screen icon and add the new site.

**On the iPhone:** open the site in **Safari**, tap **Share**, then
**Add to Home Screen**. To get an update, close the app completely (swipe it
away) and open it again.

Good to know:
- **Saves:** progress is saved in the browser on that device. The home-screen app and a Safari tab keep separate saves.
- **No sound?** Check the ring/silent switch on the side of the iPhone. Safari mutes web audio in silent mode.
- **Dev tools:** the web version is a release build, so the developer tools in the profile are hidden.
- **Every run's build** is also under *Artifacts* on the run's page (`den-duel-web`), to download or host anywhere else.
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

And for Draft Duel: match length, den damage, betting and the Bookie's odds:

```bash
godot --headless --path game res://tests/draft_report.tscn -- 40
```

## Where things are

```
game/
  project.godot        Godot project settings (portrait, 720x1280, mobile renderer)
  data/                ALL game content as JSON: animals, arenas, cages, emotes, art.json...
  art/                 Rendered animals (art/units/), icons (game-icons.net) and fonts
  audio/               Sound effects and music (generated by tools/make_sounds.py)
  scenes/              main.tscn (menu), draft.tscn (Draft Duel) and battle.tscn (Classic)
  scripts/
    autoload/          GameData (loads data/) and Profile (the player's save)
    rules/             Pure game rules: trophies, leveling, cages, release requirements
    ui/                Menu screens, popups, cards, the cage opening
    battle/            Battle engine, abilities, tools, the bot and the battle screen
    draft/             Draft Duel: the match rules, the Bookie, the bot and the screen
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
- **Draft Duel tuning** (Acorns, the Watering Hole, rounds, bets, luck, Rally): `draft_rules.json`
- **Cage odds:** `cages.json`
- **Trophy and leveling numbers:** `progression.json`
- **Emotes, quick chats, banners and icons:** their own files
- **Which icon something uses:** `art.json`, then run `tools/import_icons.py`

Run the tests afterwards. `test_game_data` catches typos like an unknown arena
or tag.
