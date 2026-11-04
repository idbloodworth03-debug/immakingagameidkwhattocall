# Roadmap

## Phase 0: Foundation (done)

- [x] Godot 4 project set up for phones: portrait, scales to any screen, mobile renderer
- [x] All game content as data: 57 animals (65 more on the way), 12 arenas, 7 cages, emotes, quick chats, banners and icons
- [x] Rules with automated tests: trophies, arena floors, card leveling, Ranger level, cage rolls and odds, release requirements
- [x] Offline save with currencies, collection, deck, cage slots and cosmetics
- [x] Menus in the usual mobile card game layout: Shop, Animals, Battle, Clan and Events tabs; profile; Trophy Road; cage opening
- [x] Battle sandbox: energy, 4-card hand rotation, release requirements, emotes, quick chat and mute

## Phase 1: Battle rules (done; this real-time mode was later replaced by Draft Duel)

- [x] Decide the rules: 3 dens each, 3 minutes plus overtime, Ranger tools, same map everywhere
- [x] Battle engine: movement and bridges, targeting, attacks, dens that fight back, win/lose/draw, overtime, double energy
- [x] **Deterministic** engine (whole numbers, fixed 20 ticks per second), tested to give identical battles from identical inputs
- [x] All 38 ability types and 6 Ranger tools, with release requirements checked against the real battle
- [x] Computer opponent that plays by the same rules
- [x] Bot difficulty that scales with your arena
- [x] Drag-to-play cards with a placement preview (tap the card, then the field, still works)
- [x] Deeper placement after destroying a side den
- [x] Segmented energy bar, and hand cards that fill up as energy comes in
- [x] Balance report: hundreds of bot-vs-bot battles, win rate and play rate per card
- [x] First balance pass from bot-vs-bot battles (see "Computer opponent" in [GAME_DESIGN.md](GAME_DESIGN.md))

## Phase 1b: Draft Duel (first version done)

- [x] Round-based mode: draft, place, bet, fight, results, with dens as lives
- [x] The Watering Hole: alternate picks from a shared pool, a Ranger tool and a Mystery Crate
- [x] Acorns: the match's own money, for animals, tools and bets
- [x] The Bookie: odds from playing the fight out ahead, and bets on your own herd
- [x] Luck that the Bookie can't foresee: moods and hit luck
- [x] Rally once a fight, tools during the fight, and the halftime Pot (raise, call, fold)
- [x] Match stakes (Safe, Bold, All-in) for trophies
- [x] Computer opponent that drafts, places, rallies, uses tools and bets (with bluffs)
- [x] Draft Duel report: bot-vs-bot matches with the real Bookie

## Phase 1c: Draft Duel is the game (done)

- [x] Hearts instead of dens: 30 each; a lost fight costs the round number plus 1 per enemy animal still standing
- [x] An open 16x20 field with no river, bridges or dens; animals go for the nearest enemy
- [x] Classic battle removed, with its bot, the 8-card deck, energy and release requirements
- [x] Your collection is your draft pool, and your cards fight at their levels (the opponent's are leveled to match)
- [x] Abilities reworked for the new field (the Raccoon steals Acorns, the Hippo guards its own half, the Bison shoves)
- [x] 12 arenas re-rendered as open, fenced fields
- [x] Starters: pick up to 3 animals you own (within a 12-Acorn budget) to start the match with
- [x] Your own shop each round, from your collection, with rerolls; both players shop at once
- [x] Stars: train an animal for Acorns, or buy a copy for a free star (up to 3, +60% health and bite each)
- [x] Bonus Acorns for the loser of a round
- [x] All the gambling removed for now: the Bookie's odds and bets, the halftime Pot, the Mystery Crate and the trophy stakes
- [x] Interest, win streaks and big-moment celebrations (3 stars, comebacks, flawless rounds)
- [x] Habitat synergies at 2, 4 and 6 different animals of a habitat
- [x] Rival Rangers: 38 named opponents with portraits, lines, styles and emotes; a VS screen; arena bosses that guard promotion, with a first-win reward; quiet easing after 3 losses in a row
- [x] Simpler rules: best of 7, Pick 3 each round (no shop, Acorns or hearts), five classes with counters and automatic rows, Specialist traits (Burrow, Splash, Stun, Slow), tools once a fight; habitat synergies, per-animal abilities and moods removed
- [x] New players start with 5 cards from four classes plus a tool; small saves are topped up
- [x] Big herds: the field grows and the camera zooms out, rows spread out without overlapping, effects are capped (biggest hits first), and the fight was made cheaper (draw calls in the biggest fight down from about 600 to under 200)
- [x] The computer picks by counters and what its herd lacks (all five classes and tools get picked) and can't see your picks before the fight
- [ ] Painted portraits for the Rival Rangers (they're drawn in code for now)
- [ ] Playtest with real people: is it fun? Too long, too random, too predictable?
- [ ] A balance pass for the open field, from real play
- [ ] Settle the open questions at the end of [GAME_DESIGN.md](GAME_DESIGN.md)
- [ ] Online Draft Duel: picking is turn-based, so it suits online play well

## Phase 2: Look and feel (first pass done)

- [x] Icons for every animal, tool, emote, player icon and arena (game-icons.net), with habitat-colored cards and rarity glow
- [x] Mobile-game fonts (Lilita One and Nunito)
- [x] Sound effects, menu and battle music, and Sound/Music settings
- [x] Animations: walking hops, attack lunges, screen shake, damage numbers, bouncy buttons, card reveal glow
- [x] Credits screen and [ART_DIRECTION.md](ART_DIRECTION.md) with the plan for final art
- [x] Name: **Den Duel**, with a logo, app icon and splash screen
- [ ] Before launch: USPTO trademark check, website domain and social handles
- [x] Web version that runs in Safari and installs to the iPhone home screen
- [x] Publishing: every push runs the tests, builds the web version and publishes it with GitHub Pages (free, no deploy limits; Netlify's free credits ran out)
- [x] 3D-rendered animals with fur, real markings and walk, attack and death animations (Blender pipeline in `tools/creatures/`)
- [x] Rendered arenas: 12 themed battlefields, each an open fenced field with scenery around it (`tools/creatures/arena.py`)
- [x] Menu facelift: glossy buttons, raised panels, redesigned cards, icon tab bar, arena preview, popup and screen animations
- [x] Visual polish pass: fake-3D shader on the animals, squash-and-stretch animation, combat juice (hit flash, knockback, hit-stop, shake, damage numbers, health bars, poof defeats), particles, bouncy UI, ambient motion; all tunable in `data/feel.json`
- [ ] Blinking: needs eye-closed frames from the Blender pipeline (about an hour of rendering for all 20 animals)
- [ ] Render the tools' effects and the cages in the same style
- [ ] Roster expansion: batch 1 (Air and Ranged, 37) is in; batches 2-4 (65) are designed, tuned and rendering (docs/ROSTER.md)

## Phase 3: Online play

Recommended backend: **[Nakama](https://heroiclabs.com/nakama/)**, an open-source
game server with an official Godot 4 client. It already has most of what we need:

| We need | Nakama feature |
|---|---|
| Accounts (guest, Apple, Google sign-in) | Authentication |
| Server-owned profile, gold, gems, cages | Storage, wallet, server code |
| Finding opponents by trophies | Matchmaker |
| Real-time battles | Authoritative multiplayer matches |
| Trophy rankings | Leaderboards |
| Clans and clan chat | Groups and chat |

- [ ] Move rewards to the server. Cage rolls, trophies and purchases must be decided there so nobody can cheat by editing their save. The rules in `scripts/rules/` and the JSON data are written to be shared with the server for exactly this.
- [ ] Draft Duel online: both phones run the deterministic fight; the server deals the Watering Hole, relays purchases, placements, Rallies and tools, and confirms the result
- [ ] Matchmaking with bots as backup, plus leaderboards
- [ ] Hosting: a small server is about $10-20 a month for testing. Heroic Labs also offers paid managed hosting.

## Phase 4: Social

- [ ] Clans: create, search, join, roles
- [ ] Clan chat, animal requests and donations, friendly battles
- [ ] Clan Wars
- [ ] Friends list and battling friends

## Phase 5: Launch

- [ ] In-app purchases for gems, and the paid loot box plan for countries such as Belgium
- [ ] Privacy policy, age rating questionnaires, Google's Data Safety form, Apple's privacy labels
- [ ] Analytics and crash reporting
- [ ] Testing: TestFlight (iOS) and Google Play closed testing
- [ ] Store pages: icon, screenshots, description
- [ ] Release

---

# What you need to do

## Now

1. **Install Godot 4.7** (Standard, not .NET) and **GitHub Desktop**, then run the project (see the [README](../README.md)).
2. **Play with it and react.** Change anything you like: animal names, which animals are in the game, rarities, arena names, cage names and prices. It's all in `game/data/`, or just tell me.
3. **Play Draft Duel and tell me how it feels.** Too easy or too hard? Which animals feel too strong or useless? Is it fun to watch? And answer the remaining questions at the end of [GAME_DESIGN.md](GAME_DESIGN.md).
4. **Tell me what devices you have:**
   - **Mac?** Building for iPhone needs a Mac with Xcode. Without one, we can build iOS in the cloud (for example GitHub Actions' macOS machines or Codemagic) or launch on Android first.
   - **Android phone?** It's the easiest way to try the game on a real device early, over a USB cable.

## Soon (during Phases 1-2)

5. **Decide the age you're aiming for.** It affects a lot: if kids under 13 are a target audience, there are strict rules on data collection, ads, chat and purchases (COPPA in the US, Google Play's Families policy). "13 and up" keeps things simpler.
6. **Art plan:** draw it yourself, hire an artist, or start with asset packs.
7. **Name and logo** ideas.

## Later (Phases 3-5)

8. **Google Play developer account:** $25 once. Sign up a few weeks before you want to launch. New personal accounts must run a closed test with **at least 12 testers for 14 days in a row** before they can publish, so line up friends and family as testers.
9. **Apple Developer Program:** $99 a year. Needed for TestFlight and the App Store.
10. **Server hosting** for online play, starting at about $10-20 a month.
11. **A privacy policy page.** Both stores require one, even for a game that collects almost nothing.
