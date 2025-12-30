# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**CircleRun** is an iOS app that generates circular running routes based on a target distance using Mapbox APIs and road-aware algorithms. The app uses SwiftUI and integrates heavily with Mapbox Maps, Directions, and Navigation SDKs.

## Build Commands

### Building the App
```bash
# Build for iOS Simulator (Debug)
xcodebuild -scheme CircleRun -destination 'platform=iOS Simulator,name=iPhone 15' build

# Build for Release
xcodebuild -scheme CircleRun -configuration Release build
```

### Running Tests
```bash
# Run all tests
xcodebuild test -scheme CircleRun -destination 'platform=iOS Simulator,name=iPhone 15'

# Run unit tests only
xcodebuild test -scheme CircleRun -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:CircleRunTests

# Run UI tests only
xcodebuild test -scheme CircleRun -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:CircleRunUITests

# Run a single test
xcodebuild test -scheme CircleRun -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:CircleRunTests/CircleRunTests/example
```

**Note:** The app uses Swift Package Manager for dependencies. Xcode will automatically resolve packages on first build.

## Architecture Overview

### Core Components

**1. Route Generation Engine (`MapboxLoopGeneration.swift`)**
- Most complex component at 797 lines
- Uses Mapbox Isochrone API to determine reachable area boundaries based on target distance
- Samples waypoints from isochrone boundary with angular distribution
- Quality-aware algorithm with scoring for backtracking, loop closure, and smoothness
- Multi-stage refinement with up to 3 attempts if quality score < 6.0 or distance error > 15%
- Fallback to geometric circle algorithm if API calls fail
- Exports routes as GPX files to Documents directory
- **Critical Issue:** Algorithm currently generates routes ~2x requested distance (user-reported accuracy problem)

**2. Map Interface (`MapboxMapView.swift` + `MapboxViewController`)**
- Hybrid SwiftUI/UIKit architecture
- MapboxMapView is SwiftUI wrapper around native UIViewController
- MapboxViewController manages Mapbox Maps SDK lifecycle
- State: 3D toggle, location tracking, route display, loading overlay
- 6 map styles: Streets, Outdoors, Satellite, Dark, Light, Navigation
- Camera animations for 3D/2D, centering, bearing reset

**3. Data Flow Architecture**
```
User Input (Target Miles)
    ↓
MapboxLoopGenerator.generateCircularRoute()
    ↓
1. Calculate isochrone parameters (walking profile + 20% buffer)
2. Fetch isochrone boundary via Mapbox API
3. Sample waypoints from boundary
4. Filter waypoints (remove close/redundant points)
5. Optimize waypoint order (angular sorting)
6. Build route via Mapbox Directions API (avoids ferries)
7. Assess quality (backtracking, closure, smoothness)
8. Refine if quality < 6.0 OR distance error > 15%
    ↓
Display on Map + Export GPX
    ↓
Optional: Save to Favorites (UserDefaults)
```

**4. Favorites System**
- Model: `Route.swift` (Identifiable, Codable)
  - Properties: id, name, path (CLLocationCoordinate2D array), runCount, bestTime, distance
- Storage: UserDefaults with key "savedFavorites" (JSON encoded)
- Communication: NotificationCenter for "LoadFavoriteRoute" and "FavoritesUpdated"
- View: FavoritesView displays saved routes, pull-to-refresh support

**5. Location & Navigation**
- LocationManager uses CLLocationManager with fitness activity type
- Background location updates enabled (10m distance filter)
- Turn-by-turn navigation via MapboxNavigation SDK
- Real-time distance/bearing calculations

### App Structure

```
CircleRunApp (entry point)
    └─ MapboxConfig.configure() called in init
    └─ MainTabView (root UI)
        ├─ Tab 0: MapboxMapView (map + route generation)
        └─ Tab 1: FavoritesView (saved routes)
```

### Key Files by Function

| Function | Primary File | Line Count |
|----------|-------------|------------|
| Route Generation Algorithm | `MapboxLoopGeneration.swift` | 797 |
| Map Display & Controls | `MapboxMapView.swift` | 546 |
| Favorites Management | `FavoritesViewModel.swift` | - |
| Route Data Model | `Route.swift` | - |
| Location Tracking | `LocationManager.swift` | - |
| Mapbox Configuration | `MapboxConfig.swift` | - |
| UI Design System | `MapboxMapInterface.swift` | - |

## Dependencies

**Mapbox SDKs:**
- MapboxMaps (10.19.4) - Core mapping
- MapboxDirections (2.14.0) - Route calculation
- MapboxNavigation (2.19.0) - Turn-by-turn UI
- MapboxCoreNavigation - Navigation engine
- MapboxNavigationNative (206.1.1) - Native navigation
- MapboxCommon (23.11.4) - Shared utilities
- MapboxCoreMaps (10.19.2) - Core map engine
- Turf (2.8.0) - Geospatial calculations

**Other:**
- CoreGPX (0.9.3) - GPX file export
- GEOSwift (11.2.0) + geos (9.0.0) - Geometric operations
- SwiftGraph (3.1.0) - Graph/waypoint optimization
- Polyline (5.1.0) - Polyline encoding
- Solar (3.0.1) - Sunrise/sunset calculations
- MapboxSpeech (2.1.1) - Voice navigation

## Critical Algorithm Details

**Route Generation Quality Assessment:**
The algorithm scores routes on three metrics (each 0-10):
1. **Backtracking Detection** - Penalizes revisiting areas via cell grid (100m cells)
2. **Loop Closure** - Distance between end point and start (< 100m = good)
3. **Smoothness** - Counts sharp turns > 120° and penalizes

**Overall quality = (backtracking + closure + smoothness) / 3**

Routes with quality < 6.0 trigger refinement. Distance error > 15% also triggers refinement.

**Known Issue:** Current implementation generates routes approximately 2x the requested distance. This suggests problems in:
- Isochrone time calculation (line ~55: `calculateIsochroneParameters`)
- Waypoint sampling density (line ~70: `sampleWaypointsFromBoundary`)
- Distance calculation in quality assessment
- Route building API parameters

**Isochrone Profile:** Currently uses "walking" profile. Recent commits show migration from `.automobile` to `.walking` (commit 6b12eef).

## Configuration Notes

**Mapbox Access Token:**
- Stored in `MapboxConfig.swift`
- Public token visible in code (should be moved to environment variable or Info.plist)
- Configure via `MapboxConfig.configure()` called in app init

**Background Tasks:**
- Identifier: `com.circlerun.locationupdate`
- Scheduled every 15 minutes for location updates
- Registered in AppDelegate

**Location Permissions:**
- Requires "When In Use" and "Always" location permissions
- Fitness activity type for optimal GPS accuracy

## Recent Development History

Based on git commits:
- **fc33576** - Removed unused features: original home screen, watch connectivity, settings
- **6b12eef** - Fixed ferry bug, changed route profile from `.automobile` to `.walking`
- **036fac7** - Installed Mapbox dependencies, fixed package bugs
- **cc91a76** - Migration from MapKit to Mapbox with UI overhaul
- **8279f42** - Major route distance calculation fixes, improved directions UI

**Current Focus:** Algorithm accuracy improvement - routes are ~2x requested distance (unacceptable error).

## Development Patterns

**State Management:**
- MVVM pattern with `@StateObject` and `@ObservedObject`
- ViewModels use `@Published` for reactive updates
- NotificationCenter for cross-component communication

**API Integration:**
- Async/await patterns not consistently used (older callback style in MapboxLoopGeneration)
- URLSession for Mapbox Isochrone API (custom implementation)
- MapboxDirections SDK for route building

**Error Handling:**
- Graceful degradation with fallback algorithms
- Console logging via `print()` statements (extensive in MapboxLoopGeneration.swift)
- User-facing error alerts in UI layer

**Code Organization:**
- Heavy use of `// MARK:` comments for section organization
- Inline documentation for complex algorithms
- ViewModels and Views separated into different files
