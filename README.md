# Pokedex: Flutter + Riverpod + PokeAPI

A cross-platform Pokedex app. Browse the full catalog page by page, search
every Pokemon by name or id in real time, filter by type, and open a detail
screen with full stats, abilities, and animated type badges.

- **Data source:** [pokeapi.co](https://pokeapi.co) is the only API. Artwork
  comes from the PokeAPI sprites repository on raw.githubusercontent.com.
- **State management:** Riverpod, using `NotifierProvider` / `NotifierProvider.family`
- **Persistence/cache:** Hive (disk-backed box store) with a 1-hour TTL. There is no in-memory-only cache.
- **Platforms:** Android, iOS, Web, macOS, Windows, Linux

The presentation layer implements the Google Stitch "Research-Grade Field
Pokedex" visual direction (dark-only theme).

---

## 1. Prerequisites

- **Flutter 3.38.4+ / Dart 3.11+** (`flutter --version` to check). The code
  uses Flutter 3.27+ APIs (`CardThemeData`, `Color.withValues`), and the
  committed `pubspec.lock` resolves packages that need Dart 3.11 /
  Flutter 3.38.4. Verified with Flutter 3.47.5 / Dart 3.13.4.
  [Install guide](https://docs.flutter.dev/get-started/install)
- A code editor (VS Code or Android Studio recommended, both have Flutter plugins)
- For web hosting: a [Firebase](https://firebase.google.com) account and the Firebase CLI

Run `flutter doctor` after installing and resolve anything it flags before continuing.

---

## 2. Get the project running locally

The repository includes the Flutter platform folders and can be built directly
after installing the dependencies.

```bash
# 1. Clone your repo
git clone <your-repo-url>
cd pokedex_app

# 2. Install dependencies
flutter pub get

# 3. Confirm available devices/simulators
flutter devices

# 4. Run it
flutter run
```

To run specifically on web:

```bash
flutter run -d chrome
```

To run on an iOS simulator or Android emulator, start the simulator/emulator
first (Xcode → Open Simulator, or Android Studio → Device Manager), then
`flutter run` and pick it from the device list.

### First-run note on Hive

`main()` calls `Hive.initFlutter()` and then `PokemonCache.init()`, which
opens the boxes. Hive creates them on first launch, so there is nothing to
set up by hand. On web it uses IndexedDB; on mobile/desktop it uses the app's
local documents directory. Cached API responses expire after 1 hour.

---

## 3. Tests and static analysis

```bash
flutter analyze
flutter test
```

The tests never hit the network. They use fake repositories, `MockClient`
from `package:http/testing.dart`, and a real Hive store in a temp directory
with an injected clock. They cover:

- pagination (next page appends, loading-more state, short last page, page retry)
- name index search (case-insensitive, id match, beyond the loaded pages, debounce)
- stale search responses being ignored
- the type filter via `/type` and its intersection with the query
- the 1h TTL of the name index and type caches, and eviction of expired entries
- infinite scroll on the real list screen, navigation, saved records, the detail provider

---

## 4. Project structure

```
lib/
  core/
    constants.dart       # API base URL, page size, debounce, cache TTL + box names, type colors
    theme.dart           # Dark theme + responsive breakpoints
    result.dart          # Sealed Result<T> (Loading/Success/Failure)
  data/
    models/              # PokemonSummary, PokemonDetail, PokemonStat, PokemonIndexEntry
    datasources/
      pokeapi_client.dart  # ONLY place that calls pokeapi.co
      pokemon_cache.dart   # Hive-backed persistent cache, 1h TTL
    repositories/
      pokemon_repository.dart  # Cache-then-network logic, single source of truth
  presentation/
    providers/           # NotifierProvider (list, telemetry, saved, navigation) + .family (detail)
    screens/             # List, detail, telemetry, saved records
    widgets/             # Card, TypeBadge (animated), StatBar, skeletons, error/empty states
  main.dart              # Hive init + ProviderScope wiring
```

The app is layered data → repository → presentation. Screens never call the
network or Hive directly. They only go through `PokemonRepository`, via
Riverpod providers.

---

## 5. Pagination, search and type filter

- **Pagination / infinite scroll:** the catalog loads 40 Pokemon at a time
  (`AppConstants.pageSize`) from `GET /pokemon?offset&limit`. When the user
  scrolls within 600px of the bottom (or a page doesn't fill the screen), the
  next page is appended. A small spinner shows while it loads. If a page
  fails, the loaded items stay and a **RETRY PAGE** button appears.
- **Name index:** `GET /pokemon?limit=100000&offset=0` is fetched once and
  stored as `PokemonIndexEntry` (name + id parsed from the resource url).
- **Real-time search:** a non-empty query filters the full name index
  (case-insensitive `contains`, or an exact id like `25` / `#025`), debounced
  by 300ms. Matches are resolved to cards (types + artwork) 40 at a time
  through the detail cache, and more load on scroll. Every reload bumps a
  generation counter and older async results are discarded, so a slow
  response for an earlier query can't overwrite a newer one. Clearing the
  query restores the already-loaded catalog without refetching.
- **Type filter:** selecting a type chip loads `GET /type/{name}`, i.e. every
  Pokemon of that type across the catalog. With a query as well, the list
  shows the intersection (members of the type whose name matches).
- **States:** `PokemonListNotifier` exposes a sealed `PokemonListStatus`
  (`ListInitialLoading`, `ListFailure`, `ListEmpty`, `ListLoaded`,
  `ListLoadingMore`). The screen pattern-matches it to show skeletons, the
  retryable error view, the empty state, or the grid.

---

## 6. Caching behavior (persistent, 1 hour, no in-memory-only cache)

Every API response is stored in a Hive box as an envelope with a `cachedAt`
timestamp. On read, if `now - cachedAt > 1 hour` (`AppConstants.cacheTtl`),
the entry is deleted and a fresh network call is made.

| Box                    | Key                  | Contents                                   | TTL |
| ---------------------- | -------------------- | ------------------------------------------ | --- |
| `pokemon_list_cache`   | `"<offset>:<limit>"` | One catalog page of summaries              | 1h  |
| `pokemon_detail_cache` | Pokemon name         | Full record (stats, abilities, size)       | 1h  |
| `pokemon_index_cache`  | `"all"`              | Name index of every Pokemon (name + id)    | 1h  |
| `pokemon_index_cache`  | `"type:<name>"`      | Members of one type from `/type/{name}`    | 1h  |
| `saved_pokemon_records`| Pokemon id           | The user's bookmarks (not an API response) | none |

Loading a catalog page also stores each full record in the detail box. That
way opening a card, the telemetry sample and search results usually need no
extra request.

To clear the cache during testing, clear the site data in the browser, or
uninstall/reinstall the app.

---

## 7. Building & hosting the web version (Firebase Hosting)

`firebase.json` (public directory `build/web`, SPA rewrite to `/index.html`)
and `.firebaserc` (default project `research-grade-pokedex`) are committed,
so `firebase init` is not needed.

```bash
# Build the release web bundle
flutter build web --release

# One-time: install the CLI and log in
npm install -g firebase-tools
firebase login

# Deploy (use `firebase use <project-id>` first to target another project)
firebase deploy --only hosting
```

Firebase prints the live hosting URL (`https://<project-id>.web.app`).

---

## 8. Building for other platforms

```bash
flutter build apk --release        # Android
flutter build ios --release        # iOS (requires macOS + Xcode, signing)
flutter build macos --release      # macOS (requires macOS)
flutter build windows --release    # Windows (requires Windows)
flutter build linux --release      # Linux (requires Linux)
```

The macOS entitlements include `com.apple.security.network.client`, so the
sandboxed app can reach pokeapi.co.

---

## 9. Architecture & design notes

- **State management:** `PokemonListNotifier` (a `Notifier`) owns the query,
  selected type, paging and the sealed list status. The UI holds no filtering
  or paging logic of its own. Detail screens use `NotifierProvider.family`,
  so each Pokemon gets its own notifier instance. Telemetry and saved records
  are separate `NotifierProvider`s. Plain `Provider` is used only for
  dependency injection (client, cache, repository).
- **Dart 3 features:** sealed classes (`Result<T>`, `PokemonListStatus`) are
  pattern-matched with `switch` instead of juggling
  `isLoading`/`error`/`data` flags. Records are the repository's return types
  (`(items, fromCache)`) and the notifier's page type
  (`({items, hasMore})`).
- **Telemetry:** computed from a fixed sample, the first 40 Pokemon
  (#001 onwards), and the screen says so. It never fans out to hundreds of
  detail requests.
- **Responsiveness:** grid column count scales with width (2 columns on
  phones, 3 on tablets, 5 on desktop) via `Breakpoints.columnsFor`.
- **Error/empty/loading states:** every async boundary has a designed state.
  List, search and type loads show shimmer skeletons, a retryable error view,
  and an empty-results view naming the query and/or type. Pagination has its
  own spinner and retry.

### Design & architecture rationale

Search and type filtering run against a cached name index and `/type`
membership lists, and only the visible matches are turned into cards, 40 at a
time. This keeps request volume tied to what is on screen while still
covering the entire catalog. A single `NotifierProvider` owns every list
transition, and a generation counter stops stale async results. Paired with
the sealed status that the UI must handle exhaustively, this makes race
conditions and missing states hard to introduce.

## 10. Verification notes

- Pagination (infinite scroll), full-catalog search, and the `/type`-based
  type filter are implemented and covered by `flutter test`.
- Search/type results are resolved one page (40 matches) at a time. If any
  detail request in a page fails, that whole page fails and can be retried.
  Pages that already loaded stay on screen.
- Type effectiveness (strengths/weaknesses) on the detail screen would be a
  nice creative addition. The `/type/{name}` response already includes
  `damage_relations`.
