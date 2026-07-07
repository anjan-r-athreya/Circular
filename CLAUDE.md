# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**CircleRun** is an iOS app that generates circular running routes of a target distance using the Mapbox Directions API, tracks runs against them, and keeps history, favorites, and best times. SwiftUI throughout, with UIKit bridges for the Mapbox map and run navigation.

## Build Commands

```bash
# Build for iOS Simulator (Debug)
xcodebuild -scheme CircleRun -destination 'generic/platform=iOS Simulator' build

# Run all tests
xcodebuild test -scheme CircleRun -destination 'platform=iOS Simulator,name=iPhone 15'
```

Dependencies resolve via Swift Package Manager on first build. The Xcode project uses **filesystem-synchronized groups**: every file under `CircleRun/` is automatically part of the app target (exceptions: `Info.plist`, `CircleRun.entitlements`).

## Architecture

### Route generation (`MapboxLoopGeneration.swift`)
The generator places the start point ON a circle of waypoints (center offset from the runner) so routes are genuine loops, not lollipops. Per attempt it:
1. Tries several compass bearings (clustered around a heading preference, or spread from a random base so shuffles differ).
2. For each bearing, **calibrates** the circle radius: route via Mapbox Directions (walking profile, silent via-points, ferry rejection), excise dead-end spurs from the polyline, then correct the radius multiplicatively toward the target distance.
3. Scores candidates on distance error + self-overlap + elevation preference mismatch; acceptance requires ≤12% distance error and ≤25% overlap. If nothing lands within 25% error it throws `distanceNotAchievable` instead of returning a wrong-length route.
4. Reports progress stages through a callback (shown live on the loading overlay).

Scenic-spot loops anchor waypoints at the chosen spots and calibrate filler waypoints instead. Request budget: 14 Directions calls per generation.

### Screens (`MainTabView`)
- **Map** (`MapboxMapView` + `MapboxViewController` + `MapboxViewModel`): generation flow, route card (distance honesty line, elevation strip, share/shuffle/favorite/start), weather-and-sunset nudge banner, long-press custom start pin.
- **Favorites** (`FavoritesView`): saved routes → `RouteDetailView` (podium of best times, share GPX, start run).
- **Activity** (`ActivityView`): run history from `RunStore`, streak / weekly / lifetime mileage.
- **Settings** (`SettingsView`): pace, route preferences, terrain/elevation caps, voice cues, Apple Health sync, replay intro.

First launch shows `IntroView` (gated by `hasCompletedIntro` in UserDefaults; Settings → Replay intro resets it).

### Run tracking (`NavigationManager` + `NavigationInterface`)
MapKit-based chase-camera navigation with pause-aware elapsed time, spoken turn cues and mile splits (single persistent `AVSpeechSynthesizer`; toggle in Settings), and an end-of-run summary (PR detection, Save/Discard). Saving records to `RunStore` (always), the favorite's top-three times (if ≥90% of route distance covered), and Apple Health (`HealthKitService`, opt-in).

### Services
- `ElevationService` — Open-Meteo elevation API (free, no key): smoothed profiles, gain, terrain/difficulty classification. Cached.
- `RunConditionsService` — Open-Meteo forecast + locally computed NOAA sunset → one-line "good time to run" nudge. Cached 30 min.
- `ScenicSpotService` / `SpotPhotoService` — nearby POIs offered as route stops with photos.
- `RouteSharing` — GPX building + share sheet (used by generator export and share buttons).
- `Haptics` — success/error/selection/milestone wrappers.

### Persistence
All UserDefaults: favorites (`savedFavorites`, JSON-encoded routes), run history (`runHistory`), preferences (`targetPaceMinPerMile`, `preferSafePaths`, `loopHeading`, `terrainPreference`, `maxElevationGainFeet`, `voiceCuesEnabled`, `healthKitSyncEnabled`, `hasCompletedIntro`). Cross-component updates via NotificationCenter (`FavoritesUpdated`, `LoadFavoriteRoute`).

## Dependencies (actually linked)

MapboxMaps (10.x), MapboxNavigation + MapboxCoreNavigation (2.x), CoreGPX, SwiftGraph, GEOSwift. (Turf, MapboxDirections, MapboxCommon arrive transitively.) Weather/elevation/sunset need no SDK — Open-Meteo is keyless and sunset is computed with the NOAA equation in `RunConditionsService.swift`.

## Configuration

- Mapbox token: lives ONLY in the gitignored `Config/Secrets.xcconfig` (`MAPBOX_ACCESS_TOKEN`); the build injects it into Info.plist's `MBXAccessToken`, and `MapboxConfig.accessToken` reads it from the bundle. Fresh clone: copy `Config/Secrets.example.xcconfig` to `Config/Secrets.xcconfig` and paste a token. Never hardcode tokens in source — GitHub push protection blocks the push.
- HealthKit: entitlement in `CircleRun/CircleRun.entitlements` (`CODE_SIGN_ENTITLEMENTS` set on the app target); write-only.
- Background refresh: identifier `com.circlerun.locationupdate` (registered in AppDelegate).
- Widgets/Live Activity: not yet added — see `docs/LiveActivitySetup.md` for the target-creation steps and starter code.

## Gotchas

- Stale-looking SourceKit "No such module" diagnostics appear in editors that haven't resolved SPM packages; trust `xcodebuild`.
- `Route` encodes coordinates as `lat_N`/`lng_N` keys in a dictionary — decoding order matters; don't "simplify" to an array without a migration.
- `RouteManager.recordRun` only matches favorites by UUID; generated (unfavorited) routes get history entries but no podium times by design.
