//
//  MapboxLoopGeneration.swift
//  CircleRun
//
//  Created by Anjan Athreya on 6/5/25.
//

import Foundation
import MapboxMaps
import MapboxDirections
import CoreLocation

/// A finished loop route ready to display.
struct GeneratedLoop {
    let coordinates: [CLLocationCoordinate2D]
    let distanceMeters: CLLocationDistance
    let expectedTravelTime: TimeInterval
    /// Fraction of the route that retraces itself (0 = clean loop, 1 = pure out-and-back).
    let overlapRatio: Double
    /// Total climbing in meters; nil when elevation data wasn't needed or available.
    let elevationGainMeters: Double?

    var distanceMiles: Double { distanceMeters / 1609.34 }
}

/// User-tunable routing preferences, persisted in UserDefaults and read per generation.
struct LoopPreferences {
    enum Heading: String, CaseIterable {
        case any, north, east, south, west

        /// Compass bearing the loop should head toward, or nil for random.
        var bearing: Double? {
            switch self {
            case .any: return nil
            case .north: return 0
            case .east: return 90
            case .south: return 180
            case .west: return 270
            }
        }
    }

    enum Terrain: String, CaseIterable {
        case any, flat, rolling, hilly
    }

    /// Bias routing onto sidewalks, footpaths, and trails, and away from alleys.
    var preferSafePaths = true
    var heading: Heading = .any
    /// Preferred hilliness of the loop; candidates are scored against it.
    var terrain: Terrain = .any
    /// Soft cap on total climbing, in meters; nil means no limit.
    var maxElevationGainMeters: Double?

    /// True when generation should spend a request per candidate on elevation.
    var wantsElevationData: Bool {
        terrain != .any || maxElevationGainMeters != nil
    }

    static func fromUserDefaults() -> LoopPreferences {
        let defaults = UserDefaults.standard
        var prefs = LoopPreferences()
        if defaults.object(forKey: "preferSafePaths") != nil {
            prefs.preferSafePaths = defaults.bool(forKey: "preferSafePaths")
        }
        if let raw = defaults.string(forKey: "loopHeading"),
           let heading = Heading(rawValue: raw) {
            prefs.heading = heading
        }
        if let raw = defaults.string(forKey: "terrainPreference"),
           let terrain = Terrain(rawValue: raw) {
            prefs.terrain = terrain
        }
        let maxGainFeet = defaults.double(forKey: "maxElevationGainFeet")
        if maxGainFeet > 0 {
            prefs.maxElevationGainMeters = maxGainFeet / 3.28084
        }
        return prefs
    }
}

/// Every way generation can fail, each with a plain-English explanation,
/// a recovery suggestion, an alert title, and whether retrying can help.
/// The generator diagnoses WHICH of these happened from its request log
/// instead of collapsing everything into "no route found".
enum LoopGenerationError: LocalizedError {
    case offline
    case locationUnavailable
    case invalidStartLocation
    case distanceTooShort(minMiles: Double)
    case distanceTooLong(maxMiles: Double)
    case serviceMisconfigured
    case serviceBusy
    case serviceError
    case noRoadsNearby
    case distanceNotAchievable(targetMiles: Double, closestMiles: Double)
    case timedOut
    case noRouteFound
    case cancelled

    var errorDescription: String? {
        switch self {
        case .offline:
            return "You're offline. Building a loop needs a connection to the routing service."
        case .locationUnavailable:
            return "Your location isn't available yet."
        case .invalidStartLocation:
            return "That start point isn't a usable location."
        case .distanceTooShort(let min):
            return String(format: "Loops under %.1f miles are too short to route reliably.", min)
        case .distanceTooLong(let max):
            return String(format: "That's beyond the %.0f-mile ceiling for a single loop.", max)
        case .serviceMisconfigured:
            return "The Mapbox access token is missing, so routing can't run."
        case .serviceBusy:
            return "The routing service is rate-limiting requests right now."
        case .serviceError:
            return "The routing service rejected the requests."
        case .noRoadsNearby:
            return "No runnable roads or paths were found around this start point — it may be over water, private land, or far from a mapped road."
        case .distanceNotAchievable(let target, let closest):
            return String(format: "Couldn't build a %.1f-mile loop here — the closest runnable loop was %.1f miles.", target, closest)
        case .timedOut:
            return "Route generation took too long and was stopped."
        case .noRouteFound:
            return "Couldn't find a runnable loop near you. The road network here may not support a loop this size."
        case .cancelled:
            return "Route generation was cancelled."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .offline:
            return "Check Wi-Fi or cellular and try again."
        case .locationUnavailable:
            return "Give the app a moment to find you, check Location permissions in Settings, or long-press the map to pick a start point."
        case .invalidStartLocation:
            return "Clear the start pin and drop it on a street or path."
        case .distanceTooShort:
            return "Pull the distance slider up a little."
        case .distanceTooLong:
            return "Choose a shorter distance."
        case .serviceMisconfigured:
            return "Copy Config/Secrets.example.xcconfig to Config/Secrets.xcconfig and add a Mapbox token, then rebuild."
        case .serviceBusy:
            return "Wait a minute and try again."
        case .serviceError:
            return "Try again in a bit. If it keeps happening, the Mapbox token may be invalid or out of quota."
        case .noRoadsNearby:
            return "Move the start pin closer to a street, or clear it to start from your location."
        case .distanceNotAchievable:
            return "Shuffle for a different direction, or adjust the distance."
        case .timedOut:
            return "Try again — the network may just be slow."
        case .noRouteFound:
            return "Try a shorter distance or a different start point."
        case .cancelled:
            return nil
        }
    }

    /// Short, honest alert titles so the headline already says what class
    /// of problem this is.
    var alertTitle: String {
        switch self {
        case .offline: return "You're Offline"
        case .locationUnavailable: return "Location Not Ready"
        case .invalidStartLocation: return "Bad Start Point"
        case .distanceTooShort, .distanceTooLong: return "Distance Out of Range"
        case .serviceMisconfigured: return "Setup Needed"
        case .serviceBusy: return "Routing Service Busy"
        case .serviceError: return "Routing Service Error"
        case .noRoadsNearby: return "No Runnable Roads Here"
        case .timedOut: return "Taking Too Long"
        case .distanceNotAchievable, .noRouteFound: return "No Loop Found"
        case .cancelled: return "Cancelled"
        }
    }

    /// Whether an immediate retry has a realistic chance of succeeding.
    var isRetryable: Bool {
        switch self {
        case .offline, .serviceBusy, .serviceError, .timedOut,
             .distanceNotAchievable, .noRouteFound, .locationUnavailable:
            return true
        case .invalidStartLocation, .distanceTooShort, .distanceTooLong,
             .serviceMisconfigured, .noRoadsNearby, .cancelled:
            return false
        }
    }
}

/// Generates circular running loops with the Mapbox Directions API.
///
/// Strategy: the start point sits ON a circle of waypoints (the circle's center is
/// offset from the runner), so the route is a genuine loop rather than a lollipop
/// with an out-and-back stick. Several candidate directions are tried, each
/// calibrated to the target distance, and the winner is the candidate with the
/// least distance error and the least self-overlap (dead ends and retraced streets
/// show up as overlap). A candidate whose distance is far off target can never
/// beat one that's on target, and if nothing lands close enough the generator
/// fails with a descriptive error rather than returning a wrong-length route.
final class MapboxLoopGenerator {
    static let shared = MapboxLoopGenerator()

    struct Configuration {
        /// Compass directions tried in the first round.
        var initialBearings = 3
        /// Total directions allowed when the first round finds nothing on target.
        var maxBearings = 6
        /// Directions API requests allowed per direction (failures included).
        var maxRequestsPerBearing = 4
        /// Directions API requests allowed for one whole generation.
        var totalRequestBudget = 14
        /// Relative distance error at which a candidate stops calibrating.
        var distanceTolerance = 0.08
        /// Relative distance error a candidate may have and still count as on-target.
        var acceptanceTolerance = 0.12
        /// Worst relative error the generator will ever return; beyond this it errors out.
        var maxRelativeError = 0.25
        /// Radius multiplier applied when routing fails outright (waypoint in water etc.).
        var failureShrinkFactor = 0.75
        /// Waypoints placed around the circle in addition to the start point.
        var intermediateWaypoints = 4
        /// Streets wind, so routed distance exceeds the waypoint polygon perimeter.
        var windingFactor = 1.15
        /// Weight of self-overlap vs. distance error when ranking candidates.
        var overlapPenaltyWeight = 2.0
        /// Self-overlap above which a candidate can never count as acceptable,
        /// no matter how on-target its distance is.
        var maxAcceptableOverlap = 0.25
        /// Requests allowed per traversal direction when routing through spots
        /// (spot loops get extra calibration attempts since excising dead ends
        /// changes the distance between attempts).
        var maxRequestsPerSpotDirection = 6
    }

    var configuration = Configuration()

    /// Hard ceiling on one generation's wall-clock time.
    private let generationTimeLimit: TimeInterval = 60
    private let minTargetMiles = 0.5
    private let maxTargetMiles = 100.0

    private var generationTask: Task<Void, Never>?

    private init() {}

    // MARK: - Failure accounting

    /// What each Directions request did, tallied across a generation so a
    /// total failure can be diagnosed honestly instead of guessed at.
    private final class Diagnostics {
        var routesReturned = 0      // API answered with a usable route
        var routingFailures = 0     // API answered: no route through these points
        var networkFailures = 0
        var rateLimited = 0
        var apiErrors = 0           // auth / quota / malformed
    }

    private enum RequestFailure {
        case network, rateLimited, api, noRoute
    }

    private func classify(_ error: Error) -> RequestFailure {
        if error is URLError { return .network }
        if let directionsError = error as? DirectionsError {
            switch directionsError {
            case .network: return .network
            case .rateLimited: return .rateLimited
            case .unableToRoute, .noMatches: return .noRoute
            default: return .api
            }
        }
        return .api
    }

    /// The honest story of why nothing came back, from the request tally.
    private func diagnoseTotalFailure(_ diagnostics: Diagnostics,
                                      deadline: Date) -> LoopGenerationError {
        if !NetworkMonitor.shared.isOnline { return .offline }
        if diagnostics.networkFailures > 0 && diagnostics.routesReturned == 0
            && diagnostics.routingFailures == 0 {
            return .offline
        }
        if diagnostics.rateLimited > 0 { return .serviceBusy }
        if diagnostics.apiErrors > 0 && diagnostics.routesReturned == 0
            && diagnostics.routingFailures == 0 {
            return .serviceError
        }
        if Date() >= deadline && diagnostics.routesReturned == 0 { return .timedOut }
        if diagnostics.routesReturned == 0 { return .noRoadsNearby }
        return .noRouteFound
    }

    /// Cheap sanity checks before any API budget is spent.
    private func preflight(start: CLLocationCoordinate2D, targetMiles: Double) throws {
        guard CLLocationCoordinate2DIsValid(start),
              abs(start.latitude) > 0.0001 || abs(start.longitude) > 0.0001 else {
            throw LoopGenerationError.invalidStartLocation
        }
        guard targetMiles >= minTargetMiles else {
            throw LoopGenerationError.distanceTooShort(minMiles: minTargetMiles)
        }
        guard targetMiles <= maxTargetMiles else {
            throw LoopGenerationError.distanceTooLong(maxMiles: maxTargetMiles)
        }
        guard !MapboxConfig.accessToken.isEmpty else {
            throw LoopGenerationError.serviceMisconfigured
        }
        guard NetworkMonitor.shared.isOnline else {
            throw LoopGenerationError.offline
        }
    }

    // MARK: - Public API

    func generateCircularRoute(from start: CLLocationCoordinate2D,
                               targetMiles: Double,
                               preferences: LoopPreferences = LoopPreferences(),
                               viaSpots: [CLLocationCoordinate2D] = [],
                               progress: (@MainActor (String) -> Void)? = nil,
                               completion: @escaping (Result<GeneratedLoop, Error>) -> Void) {
        // A new request supersedes any in-flight one (e.g. rapid shuffle taps).
        generationTask?.cancel()

        let targetMeters = targetMiles * 1609.34
        generationTask = Task {
            do {
                try self.preflight(start: start, targetMiles: targetMiles)
                let loop = try await self.findBestLoop(from: start,
                                                       targetMeters: targetMeters,
                                                       preferences: preferences,
                                                       viaSpots: viaSpots,
                                                       progress: progress)
                guard !Task.isCancelled else { return }
                await MainActor.run { completion(.success(loop)) }
                self.exportGPXFile(coordinates: loop.coordinates, distance: loop.distanceMiles)
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run { completion(.failure(error)) }
            }
        }
    }

    func cancel() {
        generationTask?.cancel()
    }

    // MARK: - Candidate search

    private struct Candidate {
        let loop: GeneratedLoop
        let relativeError: Double
        let score: Double
    }

    /// Acceptable = close enough to the target distance AND clean enough that
    /// it isn't riddled with retraced streets. Both matter: an on-target route
    /// full of out-and-backs is as wrong as a clean route of the wrong length.
    private func isAcceptable(_ candidate: Candidate) -> Bool {
        candidate.relativeError <= configuration.acceptanceTolerance &&
        candidate.loop.overlapRatio <= configuration.maxAcceptableOverlap
    }

    /// Acceptable candidates always outrank unacceptable ones; within a tier
    /// the lower combined distance-error + overlap score wins.
    private func isBetter(_ lhs: Candidate, than rhs: Candidate) -> Bool {
        let lhsOK = isAcceptable(lhs)
        let rhsOK = isAcceptable(rhs)
        if lhsOK != rhsOK { return lhsOK }
        return lhs.score < rhs.score
    }

    /// Pushes a human-readable stage description to the UI, if anyone listens.
    private func report(_ progress: (@MainActor (String) -> Void)?, _ message: String) async {
        guard let progress else { return }
        await MainActor.run { progress(message) }
    }

    private func findBestLoop(from start: CLLocationCoordinate2D,
                              targetMeters: Double,
                              preferences: LoopPreferences,
                              viaSpots: [CLLocationCoordinate2D],
                              progress: (@MainActor (String) -> Void)? = nil) async throws -> GeneratedLoop {
        // Loops through chosen scenic spots are anchored to those spots rather
        // than searched across compass directions.
        if !viaSpots.isEmpty {
            return try await findBestSpotLoop(from: start,
                                              targetMeters: targetMeters,
                                              preferences: preferences,
                                              spots: viaSpots,
                                              progress: progress)
        }

        let config = configuration
        let diagnostics = Diagnostics()
        let deadline = Date().addingTimeInterval(generationTimeLimit)

        // With a heading preference, cluster candidate directions around it;
        // otherwise spread them evenly from a random base so shuffling varies.
        let baseBearing = preferences.heading.bearing ?? Double.random(in: 0..<360)
        let offsets: [Double] = preferences.heading == .any
            ? [0, 120, 240, 60, 180, 300]
            : [0, -45, 45, -90, 90, 180]

        var best: Candidate?
        var budget = config.totalRequestBudget

        for (index, offset) in offsets.prefix(config.maxBearings).enumerated() {
            try Task.checkCancellation()
            guard budget > 0, Date() < deadline else { break }

            // Extra bearings beyond the first round only run while nothing is on target.
            if index >= config.initialBearings,
               let best = best, isAcceptable(best) {
                break
            }

            let bearing = (baseBearing + offset + 360).truncatingRemainder(dividingBy: 360)
            let clockwise = Bool.random()
            let allowed = min(config.maxRequestsPerBearing, budget)
            await report(progress, "Exploring \(compassName(bearing))…")
            let (candidate, used) = await calibrate(
                initialParameter: targetMeters / (2 * Double.pi) / config.windingFactor,
                allowance: allowed,
                targetMeters: targetMeters,
                preferences: preferences,
                label: "bearing \(Int(bearing))°",
                progress: progress,
                diagnostics: diagnostics,
                deadline: deadline
            ) { radius in
                self.circleWaypoints(from: start, bearing: bearing, clockwise: clockwise, radius: radius)
            }
            budget -= used

            if let candidate = candidate {
                if best == nil || isBetter(candidate, than: best!) {
                    best = candidate
                }
                // A near-perfect loop means we can stop spending API calls.
                if isAcceptable(candidate), candidate.score < 0.05 {
                    break
                }
            }
        }

        guard let winner = best else {
            throw diagnoseTotalFailure(diagnostics, deadline: deadline)
        }

        // Never hand back a route wildly off the requested distance (this is what
        // used to produce 7-mile "20-mile" loops) — fail with the details instead.
        guard winner.relativeError <= config.maxRelativeError else {
            throw LoopGenerationError.distanceNotAchievable(
                targetMiles: targetMeters / 1609.34,
                closestMiles: winner.loop.distanceMiles
            )
        }

        print("Loop chosen: \(String(format: "%.2f", winner.loop.distanceMiles)) mi, " +
              "error \(String(format: "%.0f%%", winner.relativeError * 100)), " +
              "overlap \(String(format: "%.0f%%", winner.loop.overlapRatio * 100)), " +
              "requests used \(config.totalRequestBudget - budget)")
        return winner.loop
    }

    /// Finds a loop anchored through user-chosen scenic spots. The spots stay
    /// fixed; filler waypoints scale in and out to calibrate total distance.
    /// Both traversal directions are tried and the same acceptance gating
    /// applies, so an impossible combination (a far spot with a short target)
    /// produces a descriptive error rather than a wrong-length route.
    private func findBestSpotLoop(from start: CLLocationCoordinate2D,
                                  targetMeters: Double,
                                  preferences: LoopPreferences,
                                  spots: [CLLocationCoordinate2D],
                                  progress: (@MainActor (String) -> Void)? = nil) async throws -> GeneratedLoop {
        let config = configuration
        let diagnostics = Diagnostics()
        let deadline = Date().addingTimeInterval(generationTimeLimit)
        var best: Candidate?
        var budget = config.totalRequestBudget

        await report(progress, "Weaving in your scenic stops…")
        for clockwise in [true, false].shuffled() {
            try Task.checkCancellation()
            guard budget > 0, Date() < deadline else { break }

            let allowed = min(config.maxRequestsPerSpotDirection, budget)
            let (candidate, used) = await calibrate(
                initialParameter: 1.0,
                allowance: allowed,
                targetMeters: targetMeters,
                preferences: preferences,
                label: clockwise ? "spots cw" : "spots ccw",
                progress: progress,
                diagnostics: diagnostics,
                deadline: deadline
            ) { scale in
                self.spotWaypoints(from: start, spots: spots, clockwise: clockwise,
                                   fillerScale: scale, targetMeters: targetMeters)
            }
            budget -= used

            if let candidate = candidate {
                if best == nil || isBetter(candidate, than: best!) {
                    best = candidate
                }
                if isAcceptable(candidate), candidate.score < 0.05 {
                    break
                }
            }
        }

        guard let winner = best else {
            throw diagnoseTotalFailure(diagnostics, deadline: deadline)
        }
        guard winner.relativeError <= config.maxRelativeError else {
            throw LoopGenerationError.distanceNotAchievable(
                targetMiles: targetMeters / 1609.34,
                closestMiles: winner.loop.distanceMiles
            )
        }
        return winner.loop
    }

    /// Iteratively adjusts one scalar parameter (circle radius, or filler scale
    /// for spot loops) until the routed distance is close to the target,
    /// returning the best attempt and the number of API requests consumed.
    /// Routing failures shrink the parameter gently; distance misses correct it
    /// multiplicatively, so a shrunken loop can grow back toward the target
    /// instead of being returned short.
    private func calibrate(initialParameter: Double,
                           allowance: Int,
                           targetMeters: Double,
                           preferences: LoopPreferences,
                           label: String,
                           progress: (@MainActor (String) -> Void)? = nil,
                           diagnostics: Diagnostics,
                           deadline: Date,
                           makeWaypoints: (Double) -> [Waypoint]) async -> (Candidate?, Int) {
        let config = configuration
        var parameter = initialParameter
        var best: Candidate?
        var used = 0

        while used < allowance, Date() < deadline {
            if Task.isCancelled { return (best, used) }
            used += 1
            if used > 1 {
                await report(progress, "Dialing in the distance…")
            }

            let outcome = await requestRoute(waypoints: makeWaypoints(parameter),
                                             preferences: preferences,
                                             label: label,
                                             diagnostics: diagnostics)
            guard let loop = outcome.loop else {
                switch outcome.failure {
                case .noRoute, .none:
                    // Waypoint in water / off the road grid; shrink and retry.
                    parameter *= config.failureShrinkFactor
                case .network:
                    // Transient blip gets one breather; a dead connection
                    // stops this direction rather than burning the budget.
                    if !NetworkMonitor.shared.isOnline { return (best, used) }
                    try? await Task.sleep(nanoseconds: 600_000_000)
                case .rateLimited:
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                case .api:
                    // Auth/quota problems won't fix themselves mid-run.
                    return (best, used)
                }
                continue
            }

            let relativeError = abs(loop.distanceMeters - targetMeters) / targetMeters
            let score = relativeError
                + config.overlapPenaltyWeight * loop.overlapRatio
                + elevationPenalty(for: loop, preferences: preferences)
            let candidate = Candidate(loop: loop, relativeError: relativeError, score: score)
            print("\(label) request \(used): " +
                  "\(String(format: "%.2f", loop.distanceMiles)) mi, " +
                  "overlap \(String(format: "%.0f%%", loop.overlapRatio * 100))" +
                  (loop.elevationGainMeters.map { String(format: ", gain %.0fm", $0) } ?? ""))

            if best == nil || isBetter(candidate, than: best!) {
                best = candidate
            }
            if relativeError <= config.distanceTolerance { break }

            // Multiplicative correction, clamped so one bad estimate can't explode.
            let correction = min(max(targetMeters / loop.distanceMeters, 0.5), 2.0)
            parameter *= correction
        }

        return (best, used)
    }

    // MARK: - Waypoint construction

    private func circleWaypoints(from start: CLLocationCoordinate2D,
                                 bearing: Double,
                                 clockwise: Bool,
                                 radius: Double) -> [Waypoint] {
        let config = configuration

        // The circle's center sits `radius` away from the runner, so the start
        // point lies on the circle itself.
        let center = offsetCoordinate(from: start,
                                      metersEast: radius * sin(bearing * .pi / 180),
                                      metersNorth: radius * cos(bearing * .pi / 180))

        // Angle from the center back to the start point (reverse of the bearing),
        // measured from north in radians.
        let startAngle = (bearing + 180) * .pi / 180

        var waypoints: [Waypoint] = [Waypoint(coordinate: start, name: "Start")]

        let divisions = config.intermediateWaypoints + 1
        for k in 1..<divisions {
            let delta = 2.0 * Double.pi * Double(k) / Double(divisions)
            let angle = clockwise ? startAngle - delta : startAngle + delta
            let coordinate = offsetCoordinate(from: center,
                                              metersEast: radius * sin(angle),
                                              metersNorth: radius * cos(angle))
            let waypoint = Waypoint(coordinate: coordinate)
            // Silent via-points: the router passes through without treating them
            // as stops, which avoids forced detours into dead-end streets.
            waypoint.separatesLegs = false
            waypoints.append(waypoint)
        }

        waypoints.append(Waypoint(coordinate: start, name: "Finish"))
        return waypoints
    }

    /// Builds waypoints for a loop through chosen scenic spots. Spots are fixed
    /// anchors ordered by angle around the group's centroid; angular gaps larger
    /// than ~72° get filler waypoints on a circle whose radius is
    /// `fillerScale × ideal loop radius`, so scaling the fillers adjusts total
    /// distance without moving the spots.
    private func spotWaypoints(from start: CLLocationCoordinate2D,
                               spots: [CLLocationCoordinate2D],
                               clockwise: Bool,
                               fillerScale: Double,
                               targetMeters: Double) -> [Waypoint] {
        let config = configuration
        let all = [start] + spots
        let centroid = CLLocationCoordinate2D(
            latitude: all.map(\.latitude).reduce(0, +) / Double(all.count),
            longitude: all.map(\.longitude).reduce(0, +) / Double(all.count)
        )

        // Angle from north, in the same convention as the circle math.
        func angle(of c: CLLocationCoordinate2D) -> Double {
            let offset = metersOffset(of: c, from: centroid)
            return atan2(offset.east, offset.north)
        }

        // Angular distance travelled from the start in the chosen direction.
        let startAngle = angle(of: start)
        func travel(_ a: Double) -> Double {
            let diff = clockwise ? (startAngle - a) : (a - startAngle)
            return (diff + 4 * Double.pi).truncatingRemainder(dividingBy: 2 * Double.pi)
        }

        let ordered = spots.sorted { travel(angle(of: $0)) < travel(angle(of: $1)) }
        let fillerRadius = fillerScale * targetMeters / (2 * Double.pi) / config.windingFactor
        let gapThreshold = 2 * Double.pi / 5

        var waypoints: [Waypoint] = [Waypoint(coordinate: start, name: "Start")]
        let ring = [start] + ordered + [start]

        for i in 0..<(ring.count - 1) {
            if i > 0 {
                let anchor = Waypoint(coordinate: ring[i])
                anchor.separatesLegs = false
                waypoints.append(anchor)
            }

            let fromTravel = i == 0 ? 0 : travel(angle(of: ring[i]))
            let toTravel = i == ring.count - 2 ? 2 * Double.pi : travel(angle(of: ring[i + 1]))
            let gap = toTravel - fromTravel

            if gap > gapThreshold, waypoints.count < 9 {
                let fillerCount = min(Int(gap / gapThreshold), 3)
                for f in 1...fillerCount {
                    let t = fromTravel + gap * Double(f) / Double(fillerCount + 1)
                    let a = clockwise ? startAngle - t : startAngle + t
                    let coordinate = offsetCoordinate(from: centroid,
                                                      metersEast: fillerRadius * sin(a),
                                                      metersNorth: fillerRadius * cos(a))
                    let filler = Waypoint(coordinate: coordinate)
                    filler.separatesLegs = false
                    waypoints.append(filler)
                }
            }
        }

        waypoints.append(Waypoint(coordinate: start, name: "Finish"))
        return waypoints
    }

    // MARK: - Single route request

    private func requestRoute(waypoints: [Waypoint],
                              preferences: LoopPreferences,
                              label: String,
                              diagnostics: Diagnostics) async -> (loop: GeneratedLoop?, failure: RequestFailure?) {
        let options = RouteOptions(waypoints: waypoints, profileIdentifier: .walking)
        options.routeShapeResolution = .full
        options.shapeFormat = .polyline6
        options.includesSteps = true

        if preferences.preferSafePaths {
            // Bias hard onto sidewalks/footpaths/trails and away from alleys.
            // (The package's .high/.low presets aren't public, hence rawValue.)
            options.walkwayPriority = DirectionsPriority(rawValue: 1.0)
            options.alleyPriority = DirectionsPriority(rawValue: -1.0)
        }

        do {
            let response = try await calculate(options)
            guard let route = response.routes?.first,
                  let coordinates = route.shape?.coordinates,
                  coordinates.count > 1 else {
                diagnostics.routingFailures += 1
                return (nil, .noRoute)
            }

            // Walking routes can still board ferries; those are never runnable loops.
            let usesFerry = route.legs.contains { leg in
                leg.steps.contains { $0.transportType == .ferry }
            }
            if usesFerry {
                diagnostics.routingFailures += 1
                return (nil, .noRoute)
            }

            // Cut dead-end spurs out of the polyline before scoring. The
            // distance drops accordingly, and calibration then grows the loop
            // back to the target with the spur mileage gone.
            let cleaned = excisingSpurs(coordinates)
            let cleanedDistance = pathLength(cleaned)
            guard cleanedDistance > 0 else {
                diagnostics.routingFailures += 1
                return (nil, .noRoute)
            }
            if cleanedDistance < route.distance * 0.98 {
                print("\(label): excised \(Int(route.distance - cleanedDistance))m of dead ends")
            }

            // Elevation is only fetched when a terrain or climb preference is
            // set, so default generations stay fast.
            var gain: Double?
            if preferences.wantsElevationData {
                gain = await ElevationService.shared.gainMeters(for: cleaned)
            }

            diagnostics.routesReturned += 1
            let loop = GeneratedLoop(coordinates: cleaned,
                                     distanceMeters: cleanedDistance,
                                     expectedTravelTime: route.expectedTravelTime * (cleanedDistance / route.distance),
                                     overlapRatio: overlapRatio(of: cleaned),
                                     elevationGainMeters: gain)
            return (loop, nil)
        } catch {
            let failure = classify(error)
            switch failure {
            case .network: diagnostics.networkFailures += 1
            case .rateLimited: diagnostics.rateLimited += 1
            case .api: diagnostics.apiErrors += 1
            case .noRoute: diagnostics.routingFailures += 1
            }
            print("Routing error (\(label), \(failure)): \(error.localizedDescription)")
            return (nil, failure)
        }
    }

    private func calculate(_ options: RouteOptions) async throws -> RouteResponse {
        try await withCheckedThrowingContinuation { continuation in
            Directions.shared.calculate(options) { _, result in
                switch result {
                case .success(let response):
                    continuation.resume(returning: response)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Elevation scoring

    /// Penalty added to a candidate's score when its climbing profile doesn't
    /// match the user's terrain preference or exceeds their climb cap.
    /// Normalized to roughly 0–1 per violation so it trades off sensibly
    /// against distance error and overlap.
    private func elevationPenalty(for loop: GeneratedLoop,
                                  preferences: LoopPreferences) -> Double {
        guard let gain = loop.elevationGainMeters else { return 0 }

        var penalty = 0.0
        let gainPerMile = gain / max(loop.distanceMiles, 0.1)

        // Bands match ElevationService's classification: flat < 12 m/mi,
        // rolling 12–30 m/mi, hilly > 30 m/mi.
        switch preferences.terrain {
        case .any:
            break
        case .flat:
            penalty += max(0, gainPerMile - 12) / 24
        case .rolling:
            penalty += max(0, 12 - gainPerMile) / 24 + max(0, gainPerMile - 30) / 30
        case .hilly:
            penalty += max(0, 30 - gainPerMile) / 30
        }

        if let cap = preferences.maxElevationGainMeters, gain > cap {
            penalty += (gain - cap) / cap
        }

        return min(penalty, 2.0)
    }

    // MARK: - Dead-end excision

    /// Removes dead-end spurs — stretches where the route walks down a street
    /// and retraces itself straight back (a park dive to reach a POI centroid,
    /// a cul-de-sac the router used for mileage). The router emits identical
    /// vertices in both directions of a retraced edge, so a spur is a
    /// palindrome around its tip and cancels out with a stack; a stretch with
    /// a genuine loop at the far end never matches and is left intact.
    private func excisingSpurs(_ coordinates: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        guard coordinates.count > 3 else { return coordinates }

        // Consecutive duplicate vertices (step boundaries repeat the junction
        // point) would desync the palindrome check below.
        var path: [CLLocationCoordinate2D] = []
        for coordinate in coordinates {
            if let last = path.last, meters(from: last, to: coordinate) < 0.5 { continue }
            path.append(coordinate)
        }

        var out: [CLLocationCoordinate2D] = []
        for point in path {
            if out.count >= 2, meters(from: out[out.count - 2], to: point) < 2.0 {
                out.removeLast()
            } else {
                out.append(point)
            }
        }
        return out
    }

    private func pathLength(_ coordinates: [CLLocationCoordinate2D]) -> CLLocationDistance {
        guard coordinates.count > 1 else { return 0 }
        var total = 0.0
        for i in 0..<(coordinates.count - 1) {
            total += meters(from: coordinates[i], to: coordinates[i + 1])
        }
        return total
    }

    private func meters(from a: CLLocationCoordinate2D, to b: CLLocationCoordinate2D) -> Double {
        CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }

    // MARK: - Route quality

    /// Fraction of the route that travels the same street segment more than once
    /// (in either direction). Dead-end spurs and out-and-back sections both
    /// register as overlap.
    private func overlapRatio(of coordinates: [CLLocationCoordinate2D]) -> Double {
        let sampled = resample(coordinates, spacingMeters: 25)
        guard sampled.count > 2 else { return 0 }

        func gridKey(_ c: CLLocationCoordinate2D) -> String {
            // ~11 m grid: coarse enough to match retraced paths, fine enough to
            // keep parallel streets distinct.
            String(format: "%.4f,%.4f", c.latitude, c.longitude)
        }

        var counts: [String: Int] = [:]
        var keys: [String] = []
        for i in 0..<(sampled.count - 1) {
            let a = gridKey(sampled[i])
            let b = gridKey(sampled[i + 1])
            let key = a < b ? "\(a)|\(b)" : "\(b)|\(a)"
            keys.append(key)
            counts[key, default: 0] += 1
        }

        let repeated = keys.filter { counts[$0]! > 1 }.count
        return Double(repeated) / Double(keys.count)
    }

    /// Walks the polyline and emits points at a fixed spacing so segment
    /// comparisons aren't skewed by the router's uneven vertex density.
    private func resample(_ coordinates: [CLLocationCoordinate2D],
                          spacingMeters: Double) -> [CLLocationCoordinate2D] {
        guard coordinates.count > 1 else { return coordinates }

        var result: [CLLocationCoordinate2D] = [coordinates[0]]
        var carried = 0.0

        for i in 0..<(coordinates.count - 1) {
            let from = CLLocation(latitude: coordinates[i].latitude, longitude: coordinates[i].longitude)
            let to = CLLocation(latitude: coordinates[i + 1].latitude, longitude: coordinates[i + 1].longitude)
            let segment = from.distance(from: to)
            guard segment > 0 else { continue }

            var distanceAlong = spacingMeters - carried
            while distanceAlong < segment {
                let t = distanceAlong / segment
                result.append(CLLocationCoordinate2D(
                    latitude: coordinates[i].latitude + t * (coordinates[i + 1].latitude - coordinates[i].latitude),
                    longitude: coordinates[i].longitude + t * (coordinates[i + 1].longitude - coordinates[i].longitude)
                ))
                distanceAlong += spacingMeters
            }
            carried = segment - (distanceAlong - spacingMeters)
        }

        result.append(coordinates[coordinates.count - 1])
        return result
    }

    /// Eight-wind compass name for progress messages ("Exploring northeast…").
    private func compassName(_ bearing: Double) -> String {
        let names = ["north", "northeast", "east", "southeast",
                     "south", "southwest", "west", "northwest"]
        let index = Int(((bearing + 22.5).truncatingRemainder(dividingBy: 360)) / 45)
        return names[index]
    }

    // MARK: - Geometry helpers

    /// Metric offset of a coordinate relative to an origin (equirectangular
    /// approximation — fine at loop-run scales).
    private func metersOffset(of coordinate: CLLocationCoordinate2D,
                              from origin: CLLocationCoordinate2D) -> (east: Double, north: Double) {
        let earthRadius = 6371000.0
        let north = (coordinate.latitude - origin.latitude) * .pi / 180 * earthRadius
        let east = (coordinate.longitude - origin.longitude) * .pi / 180 * earthRadius * cos(origin.latitude * .pi / 180)
        return (east, north)
    }

    private func offsetCoordinate(from coordinate: CLLocationCoordinate2D,
                                  metersEast: Double,
                                  metersNorth: Double) -> CLLocationCoordinate2D {
        let earthRadius = 6371000.0
        let latChange = (metersNorth / earthRadius) * (180.0 / .pi)
        let lonChange = (metersEast / (earthRadius * cos(coordinate.latitude * .pi / 180.0))) * (180.0 / .pi)
        return CLLocationCoordinate2D(
            latitude: coordinate.latitude + latChange,
            longitude: coordinate.longitude + lonChange
        )
    }

    // MARK: - GPX export

    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func exportGPXFile(coordinates: [CLLocationCoordinate2D], distance: Double) {
        let routeName = "CircleRoute_\(String(format: "%.1f", distance))mi"
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let docsDir = getDocumentsDirectory()

        let gpxContent = RouteSharing.gpxContent(coordinates: coordinates, routeName: routeName)
        let gpxPath = docsDir.appendingPathComponent("\(routeName)_\(timestamp).gpx")

        do {
            try gpxContent.write(to: gpxPath, atomically: true, encoding: .utf8)
            print("GPX file exported to: \(gpxPath.path)")
        } catch {
            print("Error saving GPX file: \(error.localizedDescription)")
        }
    }
}
