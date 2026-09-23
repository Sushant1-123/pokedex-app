# Pokedex — Flutter + Riverpod + PokeAPI

A cross-platform Pokedex app. Browse Pokemon, search in real time, and open a
detail screen with full stats, abilities, and animated type badges.

- **Data source:** [pokeapi.co](https://pokeapi.co) (sole data source, no other API)
- **State management:** Riverpod, using `NotifierProvider` / `NotifierProvider.family`
- **Persistence/cache:** Hive (disk-backed box store), 1-hour TTL, no in-memory-only cache
- **Platforms:** Android, iOS, Web, macOS, Windows, Linux (all Flutter-supported targets)

The presentation layer implements the Google Stitch "Research-Grade Field
Pokedex" visual direction while preserving the existing data and state layers.

---

## 1. Prerequisites

- Flutter SDK 3.19+ (`flutter --version` to check) — [install guide](https://docs.flutter.dev/get-started/install)
- Dart 3.3+ (ships with the Flutter SDK above)
- A code editor (VS Code or Android Studio recommended, both have Flutter plugins)
- For web hosting: a free [Firebase](https://firebase.google.com) account and the Firebase CLI

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

Hive initializes automatically on app start (`Hive.initFlutter()` in
`main.dart`) and creates its storage boxes on first launch — no manual setup
needed. On web it uses IndexedDB; on mobile/desktop it uses the app's local
documents directory. Cached pages/details expire automatically after 1 hour.

---

## 3. Project structure

```
lib/
  core/
    constants.dart      # API base URL, cache TTL, type color palette
    theme.dart           # Light/dark theme + responsive breakpoints
    result.dart          # Sealed Result<T> (Loading/Success/Failure) — Dart 3 pattern matching
  data/
    models/              # PokemonSummary, PokemonDetail, PokemonStat
    datasources/
      pokeapi_client.dart  # ONLY place that calls pokeapi.co
      pokemon_cache.dart   # Hive-backed persistent cache, 1h TTL
    repositories/
      pokemon_repository.dart  # Cache-then-network logic, single source of truth
  presentation/
    providers/            # NotifierProvider (list) + NotifierProvider.family (detail)
    screens/               # PokemonListScreen, PokemonDetailScreen
    widgets/                # Card, TypeBadge (animated), StatBar, skeletons, error/empty states
  main.dart                # Hive init + ProviderScope wiring
```

This follows a data → domain(repository) → presentation layering: screens
never call the network or Hive directly, only through `PokemonRepository` via
Riverpod providers.

---

## 4. Caching behavior (as required: persistent, 1 hour, no in-memory-only)

- List pages and Pokemon details are cached in **Hive boxes** (`pokemon_list_cache`,
  `pokemon_detail_cache`), which persist to disk/IndexedDB across app restarts.
- Every cache entry stores a `cachedAt` timestamp. On read, if
  `now - cachedAt > 1 hour`, the entry is treated as expired, deleted, and a
  fresh network call is made.
- To manually clear the cache during testing: uninstall/reinstall the app, or
  call `PokemonCache.clearAll()` (wire a debug button if useful).

---

## 5. Building & hosting the web version (Firebase Hosting)

```bash
# Build the release web bundle
flutter build web --release

# One-time Firebase setup
npm install -g firebase-tools
firebase login
firebase init hosting
#   - Public directory: build/web
#   - Configure as single-page app: Yes
#   - Set up automatic builds with GitHub: optional, No is fine

# Deploy
firebase deploy --only hosting
```

Firebase will print your live hosting URL (`https://<project-id>.web.app`) —
that's the link to submit.

---

## 6. Building for other platforms (optional, for local verification)

```bash
flutter build apk --release        # Android
flutter build ios --release        # iOS (requires macOS + Xcode, signing)
flutter build macos --release      # macOS
flutter build windows --release    # Windows
flutter build linux --release      # Linux
```

---

## 7. Architecture & design notes

- **State management:** `PokemonListNotifier` (a `Notifier`) owns loading
  state, the current page, and the search query; `filtered` is a derived
  getter so the UI never manages its own filtering logic. Detail screens use
  `NotifierProvider.family` so each Pokemon gets an isolated notifier instance.
- **Dart 3 leverage:** a sealed `Result<T>` (`Loading` / `Success` / `Failure`)
  is pattern-matched with `switch` throughout the UI instead of juggling
  `isLoading`/`error`/`data` booleans separately; records (`(items, fromCache)`)
  are used as lightweight repository return types instead of ad hoc wrapper classes.
  the return type of repository methods.
- **Responsiveness:** grid column count scales with `MediaQuery` width
  (2 columns on phones, 3 on tablets, 5 on desktop) via `Breakpoints.columnsFor`.
- **Error/empty/loading states:** every async boundary (list load, detail
  load, search-with-no-results) has a dedicated, designed state — shimmer
  skeletons, a retryable error view, and an empty-results view.

## 8. Verification notes

- No pagination/infinite scroll on the list yet — it loads the first 40
  Pokemon. Extending `PokemonListNotifier` with an `offset` cursor and a
  "load more" trigger would be the natural next step.
- Automated tests cover list search/type filtering, provider success/failure,
  the one-hour TTL contract, and the root widget shell. Run `flutter test`.
- Type effectiveness (strengths/weaknesses) on the detail screen would be a
  nice creative addition — PokeAPI exposes this via the `/type/{name}` endpoint.
