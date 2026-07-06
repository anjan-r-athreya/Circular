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
    @State private var isSearchExpanded = false
    @State private var showingRunNavigation = false
    @AppStorage("targetPaceMinPerMile") private var paceMinPerMile: Double = MapboxMapInterface.Controls.defaultPaceMinPerMile
    
    // Compute the vertical offset for side controls based on route existence
    private var sideControlsOffset: CGFloat {
        !viewModel.routeCoordinates.isEmpty ? -100 : 0 // Adjust this value to fine-tune the animation
    }

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
                VStack(spacing: 0) {
                    searchBar
                        .padding(.top, geometry.safeAreaInsets.top)
                    Spacer()
                    bottomControls
                }
                
                sideControls
                    .offset(y: sideControlsOffset)
                    .animation(.spring(
                        response: 0.35,
                        dampingFraction: 0.8,
                        blendDuration: 0
                    ), value: sideControlsOffset)
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
    
    private var searchBar: some View {
        Button(action: {
            withAnimation(MapboxMapInterface.Animation.spring) {
                isSearchExpanded.toggle()
            }
        }) {
            HStack {
                Image(systemName: MapboxMapInterface.Controls.Icons.search)
                    .foregroundColor(MapboxMapInterface.Colors.secondaryText)
                
                if isSearchExpanded {
                    Text(MapboxMapInterface.Text.searchPlaceholder)
                        .foregroundColor(MapboxMapInterface.Colors.secondaryText)
                    Spacer()
                }
            }
            .padding()
            .background(MapboxMapInterface.Colors.controlBackground)
            .cornerRadius(isSearchExpanded ? MapboxMapInterface.Layout.cornerRadius.small : MapboxMapInterface.Layout.cornerRadius.circular)
            .shadow(
                color: MapboxMapInterface.Shadows.subtle.color,
                radius: MapboxMapInterface.Shadows.subtle.radius,
                x: MapboxMapInterface.Shadows.subtle.x,
                y: MapboxMapInterface.Shadows.subtle.y
            )
        }
        .frame(maxWidth: isSearchExpanded ? .infinity : MapboxMapInterface.Layout.size.searchBarCollapsed)
        .padding()
    }
    
    private var sideControls: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
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
                .padding(.trailing)
                .background(
                    Group {
                        if !viewModel.routeCoordinates.isEmpty {
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    MapboxMapInterface.Colors.background.opacity(0),
                                    MapboxMapInterface.Colors.background.opacity(0.2)
                                ]),
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        }
                    }
                    .allowsHitTesting(false)
                )
            }
            .padding(.bottom, MapboxMapInterface.Layout.padding.bottomOffset)
        }
    }
    
    private var bottomControls: some View {
        VStack(spacing: 0) {
            if !viewModel.routeCoordinates.isEmpty {
                routeInfoCard
            }
            
            HStack {
                Button(action: {
                    showingStylePicker.toggle()
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
        HStack {
            VStack(alignment: .leading, spacing: MapboxMapInterface.Layout.spacing.small) {
                Text(MapboxMapInterface.Text.generatedRoute)
                    .font(MapboxMapInterface.Typography.headline)
                    .foregroundColor(MapboxMapInterface.Colors.text)

                Text(distanceLine)
                    .font(MapboxMapInterface.Typography.subheadline)
                    .foregroundColor(MapboxMapInterface.Colors.secondaryText)

                Text("~\(estimatedTimeString(miles: viewModel.routeDistance)) at \(paceString(paceMinPerMile)) /mi")
                    .font(MapboxMapInterface.Typography.subheadline)
                    .foregroundColor(MapboxMapInterface.Colors.secondaryText)
            }

            Spacer()

            HStack(spacing: MapboxMapInterface.Layout.spacing.medium) {
                // Shuffle button: new loop, same distance, different direction.
                // Hidden for loaded favorites — there's no target to redo.
                if viewModel.lastTargetMiles != nil {
                    Button(action: {
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
                
                // Start button: launches the same 3D run navigation favorites use
                Button(action: {
                    showingRunNavigation = true
                }) {
                    Text(MapboxMapInterface.Text.startButton)
                        .font(MapboxMapInterface.Typography.buttonText)
                        .foregroundColor(.white)
                        .padding(.horizontal, MapboxMapInterface.Layout.spacing.large)
                        .padding(.vertical, MapboxMapInterface.Layout.spacing.small)
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
        }
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
        Button(action: action) {
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
    }
    
    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: mapView)
        let coordinate = mapView.mapboxMap.coordinate(for: point)
        let camera = CameraOptions(center: coordinate, zoom: mapView.cameraState.zoom + 1)
        mapView.camera.fly(to: camera, duration: 0.5)
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
}

#Preview {
    MapboxMapView()
} 
