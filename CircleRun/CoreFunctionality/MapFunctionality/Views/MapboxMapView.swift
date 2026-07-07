//
//  MapboxMapView.swift
//  CircleRun
//
//  Created by Anjan Athreya on 6/5/25.
//

import SwiftUI
import MapboxMaps
import CoreLocation

struct MapboxMapView: View {
    @StateObject private var viewModel = MapboxViewModel()
    @State private var selectedStyle: MapboxConfig.MapStyle = .dark
    @State private var showingStylePicker = false
    @State private var showingLoopGenerator = false
    @State private var targetMiles: Double = MapboxMapInterface.Controls.defaultMiles
    @State private var showingRunNavigation = false
    @State private var shareItem: ShareItem?
    @State private var conditionsNudge: RunConditionsNudge?
    @State private var nudgeDismissed = false
    @State private var cardCollapsed = false
    @AppStorage("targetPaceMinPerMile") private var paceMinPerMile: Double = MapboxMapInterface.Controls.defaultPaceMinPerMile
    
    // The current generated loop wrapped as a Route so the run navigation
    // flow can treat it exactly like a favorite.
    private var generatedRoute: Route {
        Route(
            id: UUID(),
            name: MapboxMapInterface.Text.generatedRoute,
            path: viewModel.routeCoordinates,
            runCount: 0,
            bestTimes: [],
            distance: viewModel.routeDistance
        )
    }
    
    var body: some View {
        ZStack {
            MapboxViewRepresentable(
                selectedStyle: $selectedStyle,
                viewModel: viewModel
            )
            .edgesIgnoringSafeArea(.top)
            .onAppear {
                // Set up notification observer for loading favorite routes
                NotificationCenter.default.addObserver(
                    forName: Notification.Name("LoadFavoriteRoute"),
                    object: nil,
                    queue: .main
                ) { notification in
                    if let route = notification.object as? Route {
                        viewModel.loadFavoriteRoute(route)
                    }
                }
            }
            
            GeometryReader { geometry in
                // Side controls live in the same stack as the route card, so
                // the card can never slide underneath them.
                VStack(spacing: 0) {
                    searchBar
                        .padding(.top, geometry.safeAreaInsets.top)
                    if viewModel.customStartCoordinate != nil {
                        startPinChip
                    }
                    if let nudge = conditionsNudge, !nudgeDismissed {
                        conditionsBanner(nudge)
                    }
                    Spacer()

                    HStack {
                        Spacer()
                        sideControls
                    }
                    .padding(.trailing)
                    .padding(.bottom, MapboxMapInterface.Layout.spacing.medium)

                    bottomControls
                }
                .animation(MapboxMapInterface.Animation.spring, value: cardCollapsed)
                .animation(MapboxMapInterface.Animation.spring, value: viewModel.routeCoordinates.isEmpty)
            }
            
            if viewModel.showingSuggestions {
                suggestionsOverlay
            }

            if viewModel.isGeneratingRoute {
                loadingOverlay(viewModel.generationStatus.isEmpty
                               ? MapboxMapInterface.Text.generatingRoute
                               : viewModel.generationStatus)
            } else if viewModel.isLoadingSpots {
                loadingOverlay(MapboxMapInterface.Text.scenicSpotsLoading)
            }
        }
        .sheet(isPresented: $showingLoopGenerator) {
            loopGeneratorSheet
        }
        .fullScreenCover(isPresented: $showingRunNavigation) {
            NavigationInterface(route: generatedRoute)
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.url])
        }
        // The style button used to toggle a flag nothing was watching.
        .confirmationDialog("Map Style", isPresented: $showingStylePicker, titleVisibility: .visible) {
            ForEach(MapboxConfig.MapStyle.allCases, id: \.self) { style in
                Button(style.rawValue + (style == selectedStyle ? " ✓" : "")) {
                    Haptics.selection()
                    selectedStyle = style
                }
            }
        }
        .onReceive(viewModel.$customStartCoordinate) { coordinate in
            // Dropping a pin is a statement of intent — go straight to
            // picking a distance.
            if coordinate != nil {
                showingLoopGenerator = true
            }
        }
        .task {
            // Location takes a moment after launch; poll briefly, then fetch
            // conditions once. The service caches for half an hour.
            for _ in 0..<10 {
                if let coordinate = viewModel.mapViewController?.mapView.location.latestLocation?.coordinate {
                    let nudge = await RunConditionsService.shared.nudge(at: coordinate)
                    await MainActor.run {
                        withAnimation(MapboxMapInterface.Animation.spring) {
                            conditionsNudge = nudge
                        }
                    }
                    return
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
        .alert(MapboxMapInterface.Text.generationFailedTitle,
               isPresented: .constant(viewModel.errorMessage != nil)) {
            // A different direction often succeeds where the last one failed,
            // so offer the retry right in the alert.
            if viewModel.lastTargetMiles != nil {
                Button(MapboxMapInterface.Text.tryAgainButton) {
                    viewModel.errorMessage = nil
                    viewModel.regenerateLoop()
                }
            }
            Button(MapboxMapInterface.Text.okButton, role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
    }
    
    // The pill at the top is the main entry point to generation — it opens
    // the distance picker directly (it used to be a search bar that led
    // nowhere).
    private var searchBar: some View {
        Button(action: {
            Haptics.selection()
            showingLoopGenerator = true
        }) {
            HStack {
                Image(systemName: "figure.run")
                    .foregroundColor(MapboxMapInterface.Colors.primary)

                Text(MapboxMapInterface.Text.searchPlaceholder)
                    .foregroundColor(MapboxMapInterface.Colors.text)
                    .font(MapboxMapInterface.Typography.subheadline.weight(.medium))

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(MapboxMapInterface.Colors.secondaryText)
            }
            .padding()
            .background(MapboxMapInterface.Colors.controlBackground)
            .cornerRadius(MapboxMapInterface.Layout.cornerRadius.circular)
            .shadow(
                color: MapboxMapInterface.Shadows.subtle.color,
                radius: MapboxMapInterface.Shadows.subtle.radius,
                x: MapboxMapInterface.Shadows.subtle.x,
                y: MapboxMapInterface.Shadows.subtle.y
            )
        }
        .padding()
    }
    
    /// Shown while a custom start pin is set, with the way out.
    private var startPinChip: some View {
        HStack(spacing: 8) {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.green)

            Text("Loops start at the dropped pin")
                .font(.caption.weight(.medium))
                .foregroundColor(MapboxMapInterface.Colors.text)

            Button(action: {
                withAnimation(MapboxMapInterface.Animation.spring) {
                    viewModel.clearCustomStart()
                }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(MapboxMapInterface.Colors.secondaryText)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule().fill(MapboxMapInterface.Colors.controlBackground)
                .overlay(Capsule().stroke(Color.green.opacity(0.4), lineWidth: 1))
        )
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    /// One-line weather/sunset read on whether now is a good time to run.
    private func conditionsBanner(_ nudge: RunConditionsNudge) -> some View {
        HStack(spacing: 8) {
            Image(systemName: nudge.systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(MapboxMapInterface.Colors.primary)

            Text(nudge.text)
                .font(.caption.weight(.medium))
                .foregroundColor(MapboxMapInterface.Colors.text)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Button(action: {
                withAnimation(MapboxMapInterface.Animation.spring) {
                    nudgeDismissed = true
                }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(MapboxMapInterface.Colors.secondaryText)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule().fill(MapboxMapInterface.Colors.controlBackground)
                .overlay(Capsule().stroke(MapboxMapInterface.Colors.primary.opacity(0.3), lineWidth: 1))
        )
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var sideControls: some View {
        VStack(spacing: MapboxMapInterface.Layout.spacing.medium) {
            mapControlButton(
                icon: MapboxMapInterface.Controls.Icons.location,
                isActive: viewModel.isTrackingLocation
            ) {
                viewModel.centerOnUser()
            }

            mapControlButton(
                icon: MapboxMapInterface.Controls.Icons.compass
            ) {
                viewModel.resetBearing()
            }

            mapControlButton(
                icon: viewModel.is3DEnabled ? MapboxMapInterface.Controls.Icons.view3D : MapboxMapInterface.Controls.Icons.view2D
            ) {
                viewModel.toggle3D()
            }

            mapControlButton(
                icon: MapboxMapInterface.Controls.Icons.loop,
                isActive: !viewModel.routeCoordinates.isEmpty
            ) {
                showingLoopGenerator = true
            }
        }
    }
    
    private var bottomControls: some View {
        VStack(spacing: 0) {
            if !viewModel.routeCoordinates.isEmpty {
                routeInfoCard
            }
            
            HStack {
                Button(action: {
                    Haptics.selection()
                    showingStylePicker = true
                }) {
                    Image(systemName: MapboxMapInterface.Controls.Icons.map)
                        .foregroundColor(MapboxMapInterface.Colors.text)
                        .padding(MapboxMapInterface.Layout.padding.control)
                        .background(MapboxMapInterface.Colors.controlBackground)
                        .clipShape(Circle())
                        .shadow(
                            color: MapboxMapInterface.Shadows.subtle.color,
                            radius: MapboxMapInterface.Shadows.subtle.radius,
                            x: MapboxMapInterface.Shadows.subtle.x,
                            y: MapboxMapInterface.Shadows.subtle.y
                        )
                }
                Spacer()
            }
            .padding()
        }
        .background(
            LinearGradient(
                gradient: MapboxMapInterface.Colors.Gradients.bottomOverlay,
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    private var routeInfoCard: some View {
        VStack(spacing: MapboxMapInterface.Layout.spacing.medium) {
            // Grab handle: swipe down to collapse, up to expand.
            Capsule()
                .fill(Color(white: 0.35))
                .frame(width: 36, height: 4)

            if cardCollapsed {
                collapsedRouteRow
            } else {
                routeInfoHeader

                // Elevation strip slides in once its background fetch lands.
                if !viewModel.routeElevations.isEmpty {
                    ElevationProfileView(
                        elevations: viewModel.routeElevations,
                        miles: viewModel.routeDistance
                    )
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
        }
        .animation(MapboxMapInterface.Animation.spring, value: viewModel.routeElevations.isEmpty)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 15)
                .onEnded { value in
                    if value.translation.height > 20, !cardCollapsed {
                        withAnimation(MapboxMapInterface.Animation.spring) { cardCollapsed = true }
                        Haptics.selection()
                    } else if value.translation.height < -20, cardCollapsed {
                        withAnimation(MapboxMapInterface.Animation.spring) { cardCollapsed = false }
                        Haptics.selection()
                    }
                }
        )
        .padding(MapboxMapInterface.Layout.padding.card)
        .background(
            MapboxMapInterface.Colors.controlBackground
                .overlay(
                    RoundedRectangle(cornerRadius: MapboxMapInterface.Layout.cornerRadius.medium)
                        .stroke(MapboxMapInterface.Colors.primary.opacity(0.3), lineWidth: 1)
                )
        )
        .cornerRadius(MapboxMapInterface.Layout.cornerRadius.medium)
        .shadow(
            color: MapboxMapInterface.Shadows.glow.color,
            radius: MapboxMapInterface.Shadows.glow.radius,
            x: MapboxMapInterface.Shadows.glow.x,
            y: MapboxMapInterface.Shadows.glow.y
        )
        .padding()
    }

    /// Slim one-liner when the card is collapsed out of the way.
    private var collapsedRouteRow: some View {
        HStack {
            Text(MapboxMapInterface.Text.generatedRoute)
                .font(MapboxMapInterface.Typography.subheadline.weight(.semibold))
                .foregroundColor(MapboxMapInterface.Colors.text)
            Spacer()
            Text(String(format: "%.2f mi", viewModel.routeDistance))
                .font(MapboxMapInterface.Typography.subheadline)
                .foregroundColor(MapboxMapInterface.Colors.secondaryText)
            Image(systemName: "chevron.up")
                .font(.caption.weight(.semibold))
                .foregroundColor(MapboxMapInterface.Colors.secondaryText)
        }
    }

    // Text on top, actions in their own row underneath — the Start label
    // never gets squeezed into a vertical letter stack again.
    private var routeInfoHeader: some View {
        VStack(alignment: .leading, spacing: MapboxMapInterface.Layout.spacing.small) {
            Text(MapboxMapInterface.Text.generatedRoute)
                .font(MapboxMapInterface.Typography.headline)
                .foregroundColor(MapboxMapInterface.Colors.text)

            Text(distanceLine)
                .font(MapboxMapInterface.Typography.subheadline)
                .foregroundColor(MapboxMapInterface.Colors.secondaryText)
                .lineLimit(1)

            Text("~\(estimatedTimeString(miles: viewModel.routeDistance)) at \(paceString(paceMinPerMile)) /mi")
                .font(MapboxMapInterface.Typography.subheadline)
                .foregroundColor(MapboxMapInterface.Colors.secondaryText)
                .lineLimit(1)

            HStack(spacing: MapboxMapInterface.Layout.spacing.medium) {
                // Share the loop as GPX
                Button(action: {
                    Haptics.selection()
                    if let url = RouteSharing.gpxFileURL(
                        coordinates: viewModel.routeCoordinates,
                        name: MapboxMapInterface.Text.generatedRoute,
                        distanceMiles: viewModel.routeDistance
                    ) {
                        shareItem = ShareItem(url: url)
                    }
                }) {
                    Image(systemName: MapboxMapInterface.Controls.Icons.share)
                        .font(.system(size: MapboxMapInterface.Layout.size.iconSize))
                        .foregroundColor(MapboxMapInterface.Colors.text)
                        .frame(
                            width: MapboxMapInterface.Layout.size.controlButton,
                            height: MapboxMapInterface.Layout.size.controlButton
                        )
                        .background(MapboxMapInterface.Colors.controlBackground)
                        .clipShape(Circle())
                }

                // Shuffle button: new loop, same distance, different direction.
                // Hidden for loaded favorites — there's no target to redo.
                if viewModel.lastTargetMiles != nil {
                    Button(action: {
                        Haptics.selection()
                        viewModel.regenerateLoop()
                    }) {
                        Image(systemName: MapboxMapInterface.Controls.Icons.shuffle)
                            .font(.system(size: MapboxMapInterface.Layout.size.iconSize))
                            .foregroundColor(MapboxMapInterface.Colors.text)
                            .frame(
                                width: MapboxMapInterface.Layout.size.controlButton,
                                height: MapboxMapInterface.Layout.size.controlButton
                            )
                            .background(MapboxMapInterface.Colors.controlBackground)
                            .clipShape(Circle())
                            .shadow(
                                color: MapboxMapInterface.Colors.Effects.inactiveGlow,
                                radius: MapboxMapInterface.Layout.size.glowRadius,
                                x: 0,
                                y: 0
                            )
                    }
                }

                // Favorite button
                Button(action: {
                    viewModel.toggleFavorite()
                }) {
                    Image(systemName: viewModel.isFavorited ? "star.fill" : "star")
                        .font(.system(size: MapboxMapInterface.Layout.size.iconSize))
                        .foregroundColor(viewModel.isFavorited ? .yellow : MapboxMapInterface.Colors.text)
                        .frame(
                            width: MapboxMapInterface.Layout.size.controlButton,
                            height: MapboxMapInterface.Layout.size.controlButton
                        )
                        .background(MapboxMapInterface.Colors.controlBackground)
                        .clipShape(Circle())
                        .shadow(
                            color: viewModel.isFavorited ? MapboxMapInterface.Colors.Effects.activeGlow : MapboxMapInterface.Colors.Effects.inactiveGlow,
                            radius: viewModel.isFavorited ? MapboxMapInterface.Layout.size.activeGlowRadius : MapboxMapInterface.Layout.size.glowRadius,
                            x: 0,
                            y: 0
                        )
                }

                Spacer()

                // Start button: launches the same 3D run navigation favorites use
                Button(action: {
                    Haptics.success()
                    showingRunNavigation = true
                }) {
                    Text(MapboxMapInterface.Text.startButton)
                        .font(MapboxMapInterface.Typography.buttonText)
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, MapboxMapInterface.Layout.spacing.large)
                        .padding(.vertical, MapboxMapInterface.Layout.spacing.small + 4)
                        .background(MapboxMapInterface.Colors.primary)
                        .cornerRadius(MapboxMapInterface.Layout.cornerRadius.large)
                        .shadow(
                            color: MapboxMapInterface.Colors.Effects.activeGlow,
                            radius: MapboxMapInterface.Layout.size.glowRadius,
                            x: 0,
                            y: 0
                        )
                }
            }
            .padding(.top, MapboxMapInterface.Layout.spacing.small)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func loadingOverlay(_ message: String) -> some View {
        ZStack {
            MapboxMapInterface.Colors.overlay

            VStack(spacing: MapboxMapInterface.Layout.spacing.medium) {
                ProgressView()
                    .scaleEffect(MapboxMapInterface.Layout.size.loadingIndicator)
                    .tint(MapboxMapInterface.Colors.primary)

                Text(message)
                    .font(MapboxMapInterface.Typography.headline)
                    .foregroundColor(MapboxMapInterface.Colors.text)
            }
            .padding()
            .background(
                MapboxMapInterface.Colors.controlBackground
                    .overlay(
                        RoundedRectangle(cornerRadius: MapboxMapInterface.Layout.cornerRadius.medium)
                            .stroke(MapboxMapInterface.Colors.primary.opacity(0.3), lineWidth: 1)
                    )
            )
            .cornerRadius(MapboxMapInterface.Layout.cornerRadius.medium)
            .shadow(
                color: MapboxMapInterface.Shadows.glow.color,
                radius: MapboxMapInterface.Shadows.glow.radius,
                x: MapboxMapInterface.Shadows.glow.x,
                y: MapboxMapInterface.Shadows.glow.y
            )
        }
        .ignoresSafeArea()
    }
    
    private var loopGeneratorSheet: some View {
        NavigationStack {
            VStack(spacing: MapboxMapInterface.Layout.spacing.large) {
                Text(MapboxMapInterface.Text.distancePrompt)
                    .font(MapboxMapInterface.Typography.headline)
                    .padding(.top)

                HStack {
                    Slider(
                        value: $targetMiles,
                        in: MapboxMapInterface.Controls.sliderRange,
                        step: MapboxMapInterface.Controls.sliderStep
                    )
                    .accentColor(MapboxMapInterface.Colors.primary)

                    Text(String(format: "%.1f mi", targetMiles))
                        .font(MapboxMapInterface.Typography.body)
                        .foregroundColor(MapboxMapInterface.Colors.secondaryText)
                        .frame(width: 60)
                }
                .padding(.horizontal)

                Text("Estimated time: ~\(estimatedTimeString(miles: targetMiles)) at \(paceString(paceMinPerMile)) /mi")
                    .font(MapboxMapInterface.Typography.subheadline)
                    .foregroundColor(MapboxMapInterface.Colors.secondaryText)

                Button(action: {
                    Haptics.selection()
                    showingLoopGenerator = false
                    viewModel.beginGenerationFlow(targetMiles: targetMiles)
                }) {
                    Text(MapboxMapInterface.Text.generateButton)
                        .font(MapboxMapInterface.Typography.buttonText)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(MapboxMapInterface.Colors.primary)
                        .cornerRadius(MapboxMapInterface.Layout.cornerRadius.medium)
                }
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle(MapboxMapInterface.Text.loopGeneratorTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(MapboxMapInterface.Text.cancelButton) {
                        showingLoopGenerator = false
                    }
                }
            }
        }
        .presentationDetents([.height(280)])
    }

    /// Full-screen overlay of scenic spot suggestion cards shown after the
    /// user picks a distance and before the route is generated.
    private var suggestionsOverlay: some View {
        ZStack(alignment: .bottom) {
            MapboxMapInterface.Colors.overlay
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: MapboxMapInterface.Layout.spacing.medium) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(MapboxMapInterface.Text.suggestionsTitle)
                        .font(.title3.weight(.bold))
                        .foregroundColor(MapboxMapInterface.Colors.text)

                    Text(MapboxMapInterface.Text.suggestionsSubtitle)
                        .font(MapboxMapInterface.Typography.subheadline)
                        .foregroundColor(MapboxMapInterface.Colors.secondaryText)
                }
                .padding(.horizontal)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: MapboxMapInterface.Layout.spacing.medium) {
                        ForEach(viewModel.scenicSpots) { spot in
                            ScenicSpotCardView(
                                spot: spot,
                                isSelected: viewModel.selectedSpotIDs.contains(spot.id)
                            ) {
                                viewModel.toggleSpot(spot)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 2)
                }
                .frame(maxHeight: UIScreen.main.bounds.height * 0.45)

                // Instant feedback when the selection can't fit the chosen
                // distance — the route gets extended instead of failing later.
                if let needed = viewModel.minimumMilesForSelection(),
                   let target = viewModel.lastTargetMiles,
                   needed > target {
                    Label(
                        String(format: "These stops need about %.1f mi — your %.1f mi route will be extended to fit them.",
                               needed, target),
                        systemImage: "info.circle.fill"
                    )
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.horizontal)
                }

                HStack(spacing: MapboxMapInterface.Layout.spacing.medium) {
                    Button(action: {
                        Haptics.selection()
                        viewModel.skipSuggestions()
                    }) {
                        Text(MapboxMapInterface.Text.skipSuggestionsButton)
                            .font(MapboxMapInterface.Typography.buttonText)
                            .foregroundColor(MapboxMapInterface.Colors.text)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(MapboxMapInterface.Colors.controlBackground)
                            .cornerRadius(MapboxMapInterface.Layout.cornerRadius.medium)
                    }

                    Button(action: {
                        Haptics.selection()
                        viewModel.confirmSuggestions()
                    }) {
                        Text(createRouteLabel)
                            .font(MapboxMapInterface.Typography.buttonText)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(MapboxMapInterface.Colors.primary)
                            .cornerRadius(MapboxMapInterface.Layout.cornerRadius.medium)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
            .background(
                RoundedRectangle(cornerRadius: MapboxMapInterface.Layout.cornerRadius.large)
                    .fill(MapboxMapInterface.Colors.background.opacity(0.95))
                    .overlay(
                        RoundedRectangle(cornerRadius: MapboxMapInterface.Layout.cornerRadius.large)
                            .stroke(MapboxMapInterface.Colors.primary.opacity(0.3), lineWidth: 1)
                    )
            )
            .padding()
        }
    }

    private var createRouteLabel: String {
        let count = viewModel.selectedSpotIDs.count
        guard count > 0 else { return MapboxMapInterface.Text.createRouteButton }

        // When the selection forces a longer loop, put the real number on the
        // button so there's no surprise.
        if let effective = viewModel.effectiveTargetMiles,
           let target = viewModel.lastTargetMiles,
           effective > target {
            return String(format: "Create ~%.1f mi Route (%d)", effective, count)
        }
        return "\(MapboxMapInterface.Text.createRouteButton) (\(count))"
    }
    
    /// Route distance, owning the difference from what was asked for when
    /// there is one — "4.87 mi · asked for 5.0" builds more trust than hiding it.
    private var distanceLine: String {
        let actual = viewModel.routeDistance
        if let requested = viewModel.lastTargetMiles,
           abs(actual - requested) >= 0.05 {
            return String(format: "%.2f mi · asked for %.1f", actual, requested)
        }
        return String(format: "%.2f miles", actual)
    }

    private func paceString(_ minutesPerMile: Double) -> String {
        let minutes = Int(minutesPerMile)
        let seconds = Int((minutesPerMile - Double(minutes)) * 60)
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func estimatedTimeString(miles: Double) -> String {
        let totalMinutes = miles * paceMinPerMile
        let hours = Int(totalMinutes) / 60
        let minutes = Int(totalMinutes) % 60
        return hours > 0 ? "\(hours) hr \(minutes) min" : "\(minutes) min"
    }

    private func mapControlButton(icon: String, isActive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: {
            Haptics.selection()
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: MapboxMapInterface.Layout.size.iconSize))
                .foregroundColor(isActive ? MapboxMapInterface.Colors.primary : MapboxMapInterface.Colors.text)
                .frame(
                    width: MapboxMapInterface.Layout.size.controlButton,
                    height: MapboxMapInterface.Layout.size.controlButton
                )
                .background(MapboxMapInterface.Colors.controlBackground)
                .clipShape(Circle())
                .shadow(
                    color: isActive ? MapboxMapInterface.Colors.Effects.activeGlow : MapboxMapInterface.Colors.Effects.inactiveGlow,
                    radius: isActive ? MapboxMapInterface.Layout.size.activeGlowRadius : MapboxMapInterface.Layout.size.glowRadius,
                    x: 0,
                    y: 0
                )
                .shadow(
                    color: MapboxMapInterface.Shadows.subtle.color,
                    radius: MapboxMapInterface.Shadows.subtle.radius,
                    x: MapboxMapInterface.Shadows.subtle.x,
                    y: MapboxMapInterface.Shadows.subtle.y
                )
                .animation(MapboxMapInterface.Animation.spring, value: isActive)
        }
    }
}

// MARK: - Mapbox View Representable
struct MapboxViewRepresentable: UIViewControllerRepresentable {
    @Binding var selectedStyle: MapboxConfig.MapStyle
    @ObservedObject var viewModel: MapboxViewModel
    
    func makeUIViewController(context: Context) -> MapboxViewController {
        let viewController = MapboxViewController(selectedStyle: selectedStyle)
        viewController.delegate = viewModel
        viewModel.mapViewController = viewController
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: MapboxViewController, context: Context) {
        uiViewController.updateStyle(to: selectedStyle)
    }
}

// MARK: - Mapbox View Controller
class MapboxViewController: UIViewController {
    var mapView: MapView!
    var selectedStyle: MapboxConfig.MapStyle
    weak var delegate: MapboxViewControllerDelegate?
    private var locationManager: CLLocationManager?
    
    init(selectedStyle: MapboxConfig.MapStyle) {
        self.selectedStyle = selectedStyle
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupLocationManager()
        setupMapView()
    }
    
    private func setupLocationManager() {
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.desiredAccuracy = kCLLocationAccuracyBest
        locationManager?.allowsBackgroundLocationUpdates = true
        locationManager?.activityType = .fitness
        locationManager?.distanceFilter = 10
        locationManager?.requestWhenInUseAuthorization()
    }
    
    private func setupMapView() {
        let options = MapInitOptions(resourceOptions: ResourceOptions(accessToken: MapboxConfig.accessToken))
        mapView = MapView(frame: view.bounds, mapInitOptions: options)
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // Ensure map view extends under safe areas except for bottom
        mapView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mapView)
        
        // Pin map view to edges, but respect bottom safe area
        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: view.topAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mapView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        
        // Set initial style to dark
        mapView.mapboxMap.loadStyleURI(MapboxMapInterface.MapStyle.darkStyle)

        // A running app has no business at continent zoom — cap zoom-out at
        // roughly metro scale.
        try? mapView.mapboxMap.setCameraBounds(with: CameraBoundsOptions(minZoom: 8))
        
        // Configure location puck with the new styling
        mapView.location.options = MapboxMapInterface.Location.options
        
        // Enable location tracking
        mapView.location.locationProvider.startUpdatingLocation()
        mapView.location.locationProvider.startUpdatingHeading()
        
        // Set initial camera
        if let location = locationManager?.location?.coordinate {
            mapView.camera.fly(to: CameraOptions(
                center: location,
                zoom: 15,
                bearing: 0,
                pitch: 45 // Start with a slight 3D angle for more dramatic effect
            ), duration: 0)
        } else {
            mapView.camera.fly(to: MapboxConfig.defaultCameraOptions, duration: 0)
        }
        
        setupGestureRecognizers()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Update frame to respect safe area at bottom
        let bottomSafeArea = view.safeAreaInsets.bottom
        mapView.frame = CGRect(
            x: 0,
            y: 0,
            width: view.bounds.width,
            height: view.bounds.height - bottomSafeArea
        )
    }
    
    private func setupGestureRecognizers() {
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        mapView.addGestureRecognizer(doubleTap)

        // Long-press drops a custom start pin: plan loops from anywhere,
        // not just where you're standing.
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 0.5
        mapView.addGestureRecognizer(longPress)
    }

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: mapView)
        let coordinate = mapView.mapboxMap.coordinate(for: point)
        let camera = CameraOptions(center: coordinate, zoom: mapView.cameraState.zoom + 1)
        mapView.camera.fly(to: camera, duration: 0.5)
    }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        let point = gesture.location(in: mapView)
        let coordinate = mapView.mapboxMap.coordinate(for: point)
        delegate?.didLongPress(at: coordinate)
    }
    
    func updateStyle(to style: MapboxConfig.MapStyle) {
        guard style != selectedStyle else { return }
        selectedStyle = style
        mapView.mapboxMap.loadStyleURI(MapboxConfig.Style.styleURI(for: style))
    }
    
    func clearRouteLayer() {
        // Remove existing route layer if it exists
        if mapView.mapboxMap.style.layerExists(withId: "route-layer") {
            try? mapView.mapboxMap.style.removeLayer(withId: "route-layer")
        }
        
        // Remove existing route source if it exists
        if mapView.mapboxMap.style.sourceExists(withId: "route-source") {
            try? mapView.mapboxMap.style.removeSource(withId: "route-source")
        }
    }
}

// MARK: - Location Manager Delegate
extension MapboxViewController: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
            manager.startUpdatingHeading()
        default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        delegate?.didUpdateLocation(location)
    }
}


// MARK: - Protocols
protocol MapboxViewControllerDelegate: AnyObject {
    var is3DEnabled: Bool { get set }
    var isTrackingLocation: Bool { get set }
    func didUpdateLocation(_ location: CLLocation)
    func didLongPress(at coordinate: CLLocationCoordinate2D)
}

#Preview {
    MapboxMapView()
} 
