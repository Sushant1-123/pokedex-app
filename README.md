# Pokedex: Flutter + Riverpod + PokeAPI

A cross-platform "research-grade field Pokedex". It opens with an anime-style
intro in which a trainer throws a Poke Ball that splits open to reveal the app. The
directory pages through every species, searches the full catalog (alternate
forms included) and filters by type. Each Pokemon has a detail dossier with
species data, its evolution chain, a defensive type matrix, its cry,
animated sprites and a colour-matched entrance animation. Five field tools
sit alongside: Evolution Engine, Type Spectra, Habitat Radar, Compare Lab
and Ability Codex.

- **Data source:** [pokeapi.co](https://pokeapi.co) is the only API. Images
  come from the PokeAPI sprites repository and cries from the PokeAPI cries
  repository (both on raw.githubusercontent.com, as returned by the API).
- **State management:** Riverpod `NotifierProvider` / `NotifierProvider.family`
  only. Plain `Provider` is used just for dependency injection.
- **Persistence/cache:** Hive (disk-backed) with a 1-hour TTL on every API
  response. There is no in-memory-only cache.
- **Platforms:** Android, iOS, Web, macOS, Windows, Linux.
- **Design:** the Google Stitch "Pokédex" suite (dark surface `#0b0f17`,
  containers `#181c24`, crimson `#ef4444`, cyan `#38bdf8`, Plus Jakarta Sans).

---

## 1. Prerequisites

- **Flutter 3.38.4+ / Dart 3.11+** (`flutter --version` to check). The code
  uses Flutter 3.27+ APIs (`CardThemeData`, `Color.withValues`), and the
  committed `pubspec.lock` resolves packages that need Dart 3.11 /
  Flutter 3.38.4. Verified with Flutter 3.47.5 / Dart 3.13.4.
  [Install guide](https://docs.flutter.dev/get-started/install)
- **Linux desktop builds only:** `audioplayers` needs GStreamer development
  packages (`libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev`).
- For web hosting: a [Firebase](https://firebase.google.com) account and the
  Firebase CLI.

Run `flutter doctor` after installing and resolve anything it flags.

---

## 2. Run it locally

```bash
git clone <your-repo-url>
cd pokedex_app
flutter pub get
flutter run            # pick a device
flutter run -d chrome  # web
```

`main()` calls `Hive.initFlutter()` and `PokemonCache.init()`, which opens
the boxes (IndexedDB on web, the app documents directory elsewhere). There is
nothing to set up by hand.

---

## 3. Tests and static analysis

```bash
dart format lib test
flutter analyze
flutter test
```

The tests never touch the network. They use an in-memory
`FakeRepository`/`FakeCryPlayer` (`test/support/fakes.dart`), `MockClient`
from `package:http/testing.dart`, and a real Hive store in a temp directory
with an injected clock. They cover:

- **Models:** species parsing (genus, cleaned flavor text, gender ratio incl.
  genderless); evolution chains (linear with levels, branching (Eevee), single stage); the defensive matrix (dual types, 4×, 0×, cancelled
  matchups); detail parsing (cries fallback, sprites, hidden abilities).
- **Directory:** numbered pagination (page change, page count, page-loading
  state, retry, fast page switching); base species vs forms (id < 10000);
  debounced search; stale responses ignored; search and type results
  paginated; type ∩ query; real latency readout.
- **Cache:** the 1h TTL of the name index, `/type` data, species, evolution
  chains and details; eviction of expired entries.
- **Detail screen:** prev/next boundaries (#1 and the last species); the
  animated-sprite toggle and its fallback; tapping plays the cry; layout at
  mobile/tablet/desktop sizes without overflow.
- **Intro:** it plays on launch while the directory preloads underneath;
  SKIP / tap-anywhere reveal the directory; reduce-motion uses a < 400ms
  fade; it doesn't replay on in-app navigation.
- **Navigation:** all 8 destinations as deep links (the intro still plays
  first), the mobile "More" sheet, saved records, telemetry sampling, Ctrl+K
  and the clear button.
- **Intro:** it plays in full at 1440x900 with reduce motion off; the ball
  starts at the measured hand position; the trainer asset loads; the layout
  fits 390x844 up to 1920x1080.
- **Motion and polish:** species colour -> glow mapping with the type
  fallback; the entrance/tap choreography (taps alternate jump/kick, reduce
  motion stays at rest); stat colour thresholds.
- **Field tools:** habitat, ability list and ability detail parsing with a 1h
  TTL; the full 18x18 type chart; Compare Lab limits (max 3, no
  duplicates); Evolution Engine search -> chain.

---

## 4. Project structure

```
assets/fonts/            # Plus Jakarta Sans (400-800) + OFL.txt licence
assets/images/intro/     # trainer.webp (see Asset credits)
lib/
  core/
    design_tokens.dart   # AppColors, AppSpacing, AppRadii, AppTypography
    theme.dart           # ThemeData from the tokens + responsive breakpoints
    constants.dart       # API URL, page size, TTL, box names, type palette
    result.dart          # Sealed Result<T> (Loading/Success/Failure)
  data/
    models/              # Summary, Detail, Species, EvolutionChain, TypeData,
                         # TypeDefenses, TypeChart, Habitat, Ability,
                         # IndexEntry, FetchSource (sealed)
    datasources/
      pokeapi_client.dart  # ONLY place that calls pokeapi.co
      pokemon_cache.dart   # Hive boxes with the 1h TTL
      cry_player.dart      # audioplayers wrapper, fails silently
    repositories/
      pokemon_repository.dart  # cache-then-network, timed network requests
  presentation/
    intro/               # launch intro: provider, overlay, scene + painters
    providers/           # list, detail (.family), telemetry, saved, navigation,
                         # node status, name index, section providers
    screens/             # directory, detail, telemetry, saved records
      sections/          # evolution, type spectra, habitats, compare, abilities
    widgets/             # shell, cards, pager, search, skeletons, error/empty
      detail/            # specimen viewport, choreography, detail sections
```

The layering is data → repository → presentation. Screens never call the
network, Hive or the audio player directly. They go through providers backed
by `PokemonRepository` (and `cryPlayerProvider` for sound).

---

## 5. Directory: pagination, search, type filter

- **Numbered pages of 30.** 30 fills the 2-, 3- and 5-column grids evenly.
  The pager shows Prev, 1, 2, 3, …, last, Next, and each page change scrolls
  back to the top. A slow page change is discarded if a newer one wins. A
  failed page keeps the pager and offers a retry.
- **Base species vs forms.** The directory lists base species only
  (ids < 10000). Search also finds alternate forms (megas, regional forms,
  ...), whose ids start at 10001.
- **Name index.** `GET /pokemon?limit=100000&offset=0` is fetched once (and
  preloaded during the intro), and each entry's id is parsed from its URL.
  The specimen counter ("1,025 specimens indexed") is computed from it.
- **Real-time search.** Case-insensitive name match or an exact id (`25`,
  `#0025`), debounced by 300ms. A generation counter discards stale
  responses. Clearing the search restores the last directory page without
  refetching.
- **Type filter.** A type chip loads `GET /type/{name}`. With a query as
  well, the list shows the intersection.
- **States.** Sealed `PokemonListStatus`: initial loading, failure, empty,
  and a paged state (page loading / loaded / page failure) that the screen
  pattern-matches.
- **Latency readout.** Shows the measured duration of the last network
  request (timed in the repository), or `CACHE` when the result came from
  Hive. It never shows a made-up number.
- **Keyboard.** Cmd+K (macOS) / Ctrl+K (elsewhere) focuses the search on web
  and desktop. The hint is shown on wide screens.

### Card animations and polish

- A page of cards fades and slides in with a short stagger (22ms per card,
  capped at 12 steps), so a page is in within ~0.5s. There are no timers:
  each card's controller spans its delay plus its own 240ms.
- Hover (web/desktop): the card lifts with a soft glow in the type colour,
  and the Pokemon hops inside its artwork box. Touch: the card scales down
  while pressed. With reduce motion there is no hop or stagger.
- Each artwork area has a type-colour gradient at the top, a faint large
  dex-number watermark, and artwork that pops out above its top edge.
- Type chips have a coloured dot, and the active chip glows in its type
  colour. The search field is larger, with more breathing room.
- Card glows use the type colour, so no extra species request is made per
  card.

## 6. Detail dossier

The record loads first (so the Hero lands on real artwork). Each section then
loads on its own and has its own skeleton/error state:

- Breadcrumbs with prev/next species (#0005 ↔ #0007). There is no previous
  link on #1 and no next link on the last species (or on forms).
- Genus, generation, legendary/mythical tags and the newest English flavor
  text from `/pokemon-species/{id}`.
- Height (with ft/in), weight (with lbs), gender ratio ("Genderless" when
  `gender_rate` is -1), and base experience with growth rate.
- The evolution chain from `/evolution-chain/{id}` as tappable stage cards
  with triggers ("Lv. 16", "Thunder Stone", "Friendship · Day", "Trade").
  Branching chains show every branch; single-stage species say so.
- Base stats with BST total. Bars are coloured by value
  (`AppStatScale`: under 60 muted, 60-99 cyan, 100+ crimson).
- Abilities, with hidden abilities marked. Tapping one opens it in Ability
  Codex.
- A **Compare** button adds the Pokemon to Compare Lab and opens it.
- Every section is the same card, with a small upper-case label and a thin
  accent line, and there is more space between sections.
- A defensive type matrix computed from the `/type/{name}` damage relations
  (the same cached response as the type filter). Dual types multiply, giving
  4×, 0.25× and 0× (immune).

### Animations (detail)

- **Entrance (~1.5s, after the Hero flight):**
  1. The Pokemon dashes in from the left of the viewport with a glowing
     silhouette trail.
  2. It jumps and lands with squash and stretch, and a glowing ring spreads
     on the floor.
  3. It lunges into a kick with an impact flash.
  4. It settles into the idle float, whose floor shadow grows and shrinks.

  The motion curves live in `SpecimenChoreography` as pure functions, so
  they are tested without widgets.
- **Its own colour:** the trail, ring, flash and the viewport's radial glow
  use the species `color` from `/pokemon-species` (already cached), mapped
  through the `AppColors.speciesGlow` token map. "black" and "gray" map to
  light tones that glow on the dark surface; without a species colour the
  primary type colour is used. The viewport also shows a large faded dex
  number and a soft floor shadow.
- **Tap:** alternates a jump and a kick, and plays the cry (`cries.latest`,
  falling back to `cries.legacy`) through `audioplayers`. Failures are
  silent (e.g. OGG in Safari). A small speaker hint marks the Pokemon as
  tappable.
- **"▶ ANIMATED" toggle:** shows the Showdown sprite
  (`sprites.other.showdown.front_default`). It is disabled with the tooltip
  "No animated sprite" when there is none, and the choice is remembered for
  the session (NotifierProvider).
- **Reduce motion:** no entrance moves, trail, float or tap moves, only a
  short fade (the cry still plays).

## 7. Launch intro

`IntroGate` sits in `MaterialApp.builder`, above the Navigator. The intro
therefore plays on every launch / page load, over whichever route opens first
(deep links such as `/diagnostics` included), and never on in-app navigation.
The phase is an `IntroPhase` enum in a `NotifierProvider`.

1. The trainer artwork (`assets/images/intro/trainer.webp`, see Asset
   credits) dashes in from the left with speed lines, overshoots slightly
   and skids to a stop in a puff of dust.
2. Wind-up: he leans back around his feet with a slight squash. Throw: a
   fast forward lunge with a stretch, a forward step, speed lines and a
   flash at the hand. The arm overlaps his head and cap in the artwork, so
   the whole figure is animated rather than a cut-out arm.
3. The Poke Ball (also a `CustomPainter`) flies along a quadratic Bezier
   arc, spinning, with a fading trail.
4. It lands with a bounce and shadow, wobbles three times, and the button
   blinks.
5. It splits open with a crimson/cyan flash. The two halves carry the
   backdrop away and reveal the app, which is already built underneath.

He follows through and fades back while the ball flies. The ball leaves
exactly from the measured hand position (`TrainerArt.hand`).

The whole sequence takes about 3.4s (2.8s throw, 0.6s reveal). No width or
platform condition shortens it, so laptops and desktops get the full intro.
SKIP or tapping anywhere jumps to the reveal. The 350ms fade replaces it
only when the OS really asks for reduced motion: Flutter's
`MediaQuery.disableAnimations` follows Windows "Animation effects", macOS/iOS
"Reduce motion", Android "Remove animations", and `prefers-reduced-motion`
in the browser. The name
index and the first page load during the intro. Everything is sized from
the screen, so nothing is cut off from phone to desktop.

**Web boot screen:** `web/index.html` preloads the trainer image and shows a CSS Poke Ball spinner on
`#0b0f17` until Flutter's `flutter-first-frame` event, so there is no white
flash. `manifest.json` uses the same colour.

---

## 8. Field tools (sidebar sections)

| Route | Section | What it does |
| --- | --- | --- |
| `/` | Specimen Stream | The directory. |
| `/diagnostics` | Diagnostic Matrix | Telemetry from a sample of the first 30 species (`/telemetry` still works). |
| `/evolution` | Evolution Engine | Search any Pokemon (cached name index), or use the quick picks (Eevee, Charmander, Ralts) or "Random chain", to see its full tree: tappable stage cards with artwork and triggers. Branches sit side by side; single-stage species say they don't evolve. |
| `/types` | Type Spectra | 18x18 attacking-vs-defending chart from `/type/{name}` `damage_relations` (the same cache as the type filter), loaded at most 4 requests at a time. Colour-coded cells, a sticky attacker column, and horizontal scroll on small screens. Tapping a type shows its strengths, weaknesses and immunities, plus a paged grid of its Pokemon. |
| `/habitats` | Habitat Radar | `/pokemon-habitat` cards with species counts and a type-colour mix bar (computed from the cached `/type` members, so there are no per-species requests), and a paged grid per habitat. Notes that PokeAPI habitats cover Generations I-III. |
| `/compare` | Compare Lab | 2-3 Pokemon side by side: artwork, types, overlaid stat bars, a `CustomPainter` radar chart, BST and defensive matchups. The selection lives in a NotifierProvider (max 3, no duplicates). |
| `/abilities` | Ability Codex | `/ability?limit=100000` with live search, and `/ability/{name}` with the English short and full effect, the generation, and the Pokemon that have it (hidden ones marked, each tappable). |
| `/saved` | Saved Records | Hearted Pokemon. |

**Navigation:**
- **Desktop:** the Stitch sidebar. The "TERMINAL STATUS" box reads
  SYNCHRONIZED or OFFLINE from the last real request; the items have icons
  and a crimson active fill; the bottom box shows the real number of cached
  responses and the last request latency.
- **Tablet:** a navigation rail.
- **Mobile:** Specimen Stream, Evolution Engine and Type Spectra, plus
  "More", which opens a sheet with the rest.

Every section has a skeleton, an error view with retry and an empty state.
The repository reports each network result to a `NodeStatus`
NotifierProvider, which drives the status boxes.

## 9. Caching (persistent, 1 hour, no in-memory-only cache)

Every API response is stored in Hive as `{cachedAt, data}`. On read, if
`now - cachedAt > 1 hour` (`AppConstants.cacheTtl`), the entry is deleted
and refetched.

| Box                       | Key                 | Contents                                         | TTL  |
| ------------------------- | ------------------- | ------------------------------------------------ | ---- |
| `pokemon_detail_cache_v2` | Pokemon id          | `/pokemon/{id}`: stats, types, abilities, sprites, cries | 1h |
| `pokemon_index_cache`     | `"all"`             | Name index of every Pokemon (name + id)          | 1h   |
| `pokemon_index_cache`     | `"typedata:<type>"` | `/type/{name}`: members + damage relations       | 1h   |
| `pokemon_species_cache`   | species id          | `/pokemon-species/{id}`: genus, flavor, gender, chain id | 1h |
| `evolution_chain_cache`   | chain id            | `/evolution-chain/{id}`: stage tree + triggers   | 1h   |
| `pokemon_habitat_cache`   | `"all"`             | Habitat names from `/pokemon-habitat`            | 1h   |
| `pokemon_habitat_cache`   | `"habitat:<name>"`  | `/pokemon-habitat/{name}`: species list          | 1h   |
| `ability_cache`           | `"all"`             | Ability list from `/ability?limit=100000`        | 1h   |
| `ability_cache`           | `"ability:<name>"`  | `/ability/{name}`: effects, generation, holders  | 1h   |
| `saved_pokemon_records`   | Pokemon id          | The user's hearted records (not an API response) | none |

Directory cards are built from the detail cache, so opening a card, the
telemetry sample and revisiting a page need no extra request. Boxes from
earlier versions (`pokemon_list_cache`, `pokemon_detail_cache`) are no
longer read. To clear the cache, clear the site data or reinstall the app.

## 10. Fonts

Plus Jakarta Sans (Regular 400 to ExtraBold 800) is bundled in
`assets/fonts/` with its SIL Open Font License (`OFL.txt`). It is registered
in `pubspec.yaml` and in `LicenseRegistry`, and nothing is fetched at
runtime. Symbols the font doesn't contain (⌘, ♂, ♀) are drawn with the
bundled Material icons, so the web build never downloads a fallback font.

---

## 11. Build & host the web version (Firebase Hosting)

`firebase.json` (public `build/web`, SPA rewrite) and `.firebaserc` (project
`research-grade-pokedex`) are committed.

```bash
flutter build web --release
npm install -g firebase-tools   # one-time
firebase login                  # one-time
firebase deploy --only hosting  # `firebase use <id>` to target another project
```

## 12. Other platforms

```bash
flutter build apk --release        # Android
flutter build ios --release        # iOS (macOS + Xcode, signing)
flutter build macos --release      # macOS (network.client entitlement is set)
flutter build windows --release    # Windows (Visual Studio C++ toolchain)
flutter build linux --release      # Linux (GStreamer dev packages, see §1)
```

---

## 13. Architecture & design notes

- **Tokens:** every colour, size, radius and text style comes from
  `lib/core/design_tokens.dart`. Only the conventional Pokemon type palette
  lives in `constants.dart`.
- **Dart 3:** sealed classes (`Result`, `PokemonListStatus` with a sealed
  `ListPaged` sub-hierarchy, `FetchSource`, `GenderRatio`,
  `EvolutionTrigger`) are pattern-matched exhaustively. Records are used for
  repository results `(value, source)`, type matchups and dex neighbours.
- **Provenance:** the repository times each network request and returns a
  `FetchSource` (`CacheHit` / `NetworkFetch(latency)`). This drives the
  latency readout.

### Design & architecture rationale

Search, the type filter and the directory all resolve to one list of index
entries, which is paged 30 at a time through the detail cache. Request volume
therefore stays tied to what is on screen while covering the entire catalog.
A single `NotifierProvider` owns every list transition, and a generation
counter stops stale results. Paired with the sealed status that the UI must
handle exhaustively, this makes races and missing states hard to introduce.

---

## 14. Creative additions

- **Launch intro:** the trainer throw, a Bezier ball flight, three wobbles
  and a split reveal of the live app (section 7).
- **Detail entrance:** dash-in with a trail, a jump with a floor ring and a
  kick with an impact flash, all in the Pokemon's own colour, plus tap
  moves and cries (section 6).
- **Evolution Engine, Type Spectra, Habitat Radar, Compare Lab and Ability
  Codex** (section 8).

## 15. Design deviations (intentional differences from the Stitch file)

| Stitch element | In the app | Why |
| --- | --- | --- |
| Fictional telemetry (core temperature, wing span, GPS coordinates, BPM pulse, "99.4 kW", "Mach 1.2", energy level) | Removed | pokeapi.co is the sole data source and has none of it. |
| "Top 12% Gen IX" percentile, competitive min/max ranges at Lv. 100, IV/EV verification log | Removed; BST and base stats kept | Not in PokeAPI. Deriving them would be invented data. |
| Smogon tier and "competitive movepool / loadout" | Removed | Smogon is a different data source. The brief allows only pokeapi.co. |
| "Verified", "Apex Predator", "Class: Apex", "Uber"/"Titan" badges | Replaced with real tags: Legendary, Mythical, Alternate form, generation | Not in PokeAPI. The replacements come from `/pokemon-species` and the id range. |
| "Paldea Field Sub-Node #094", "Prof. Rowan" avatar, "Silph Co." footer, Preferences / Export JSON / Share buttons | Header shows "FIELD SUB-NODE" with a real online/offline badge; the other controls are not built | They name fictional nodes/users or features outside the assignment. |
| Sidebar "DATA BANDWIDTH 98.4%" and "SUB-SYSTEM VER" | Real cached-response count and last request latency | The value must not be made up. |
| Static "Latency: 14ms" | The real duration of the last request, or "CACHE" | The value must not be made up. |
| Hard-coded "1,025 specimens" / "103" pages | Counter and page count computed from the loaded index/results | They must come from real data. |
| Per-type counts on the filter chips ("Fire (86)") and the BST slider / "Fully evolved" checkboxes | Chips without counts; no slider/checkboxes | Counts would need 18 `/type` requests up front. The extra filters are outside the brief. |
| Monospace labels in the desktop frames | Plus Jakarta Sans everywhere (tabular figures for numbers) | The brief specifies Plus Jakarta Sans as the one bundled font. |
| 5 columns from 1024px | 5 columns from 1200px (3 below) | Next to the 232px sidebar, cards narrower than ~170px lose legibility. |
| "Explore / Favorites / Compare / System" bottom tabs | Specimen Stream / Evolution Engine / Type Spectra / More | Eight sections don't fit a bottom bar; "More" holds the rest. |
| Only the peak stat bar in crimson | Every bar coloured by value band (muted / cyan / crimson) | Makes low vs high stats readable at a glance; thresholds are tokens. |
| Sidebar sections without Stitch frames (Evolution Engine, Type Spectra, Habitat Radar, Compare Lab, Ability Codex) | Built in the same panel/token style | There were no frames for these screens. |
| ⌘, ♂, ♀ as text | Material icons | The bundled font lacks these glyphs, and a text fallback would load a font at runtime on web. |

## 16. Verification notes

- `flutter analyze`: no issues. `flutter test`: all tests pass.
  `flutter build web --release`: succeeds.
- Cries are OGG files. Browsers without OGG support (Safari) stay silent by
  design.
- Search/type pages resolve up to 30 detail requests in parallel. If one
  fails, that page shows a retry and the pager stays usable.

## Asset credits

- Ash Ketchum artwork © Nintendo / Creatures / GAME FREAK / The Pokémon
  Company, used for a non-commercial demo only
  (`assets/images/intro/trainer.webp`).
- Plus Jakarta Sans © The Plus Jakarta Sans Project Authors, SIL Open Font
  License 1.1 (`assets/fonts/OFL.txt`).
- Pokemon artwork, sprites and cries are loaded from the PokeAPI sprites and
  cries repositories, as returned by pokeapi.co.
