# Roadmap

## Phase 0: Foundation (done)

- [x] Godot 4 project set up for phones: portrait, scales to any screen, mobile renderer
- [x] All game content as data: 57 animals, 12 arenas, 6 cages, emotes, quick chats, banners and icons
- [x] Rules with automated tests: trophies, arena floors, card leveling, Ranger level, cage rolls and odds, release requirements
- [x] Offline save with currencies, collection, deck, cage slots and cosmetics
- [x] Menus in the usual mobile card game layout: Shop, Animals, Battle, Clan and Events tabs; profile; Trophy Road; cage opening
- [x] Battle sandbox: energy, 4-card hand rotation, release requirements, emotes, quick chat and mute

## Phase 1: Battle rules (mostly done)

- [x] Decide the rules: 3 towers, 3 minutes plus overtime, Ranger tools, same map everywhere
- [x] Battle engine: movement and bridges, targeting, attacks, towers that shoot, win/lose/draw, overtime, double energy
- [x] **Deterministic** engine (whole numbers, fixed 20 ticks per second), tested to give identical battles from identical inputs
- [x] All 38 ability types and 6 Ranger tools, with release requirements checked against the real battle
- [x] Computer opponent that plays by the same rules
- [ ] Settle the open questions at the end of [GAME_DESIGN.md](GAME_DESIGN.md)
- [ ] Playtest a lot and balance costs and stats
- [ ] Bot difficulty that scales with trophies
- [ ] Drag-to-play cards (right now it's tap the card, then tap the field)

## Phase 2: Look and feel

- [ ] Pick the **name and logo**, and check the name is free on both app stores and has no trademark conflict
- [ ] Art direction: animal portraits, battlefield, towers, cages, UI frames. Placeholder art is drawn in code, so it swaps out cleanly.
- [ ] Sound effects and music
- [ ] Animations: cage shaking and opening, card upgrades, battle hits

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
- [ ] Battles: both phones run the deterministic simulation; the server relays and checks every release (energy, requirements, timing) and confirms the result
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
3. **Play battles and tell me how they feel.** Too easy or too hard? Which animals feel too strong or useless? Is it fun to watch? And answer the remaining questions at the end of [GAME_DESIGN.md](GAME_DESIGN.md).
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
