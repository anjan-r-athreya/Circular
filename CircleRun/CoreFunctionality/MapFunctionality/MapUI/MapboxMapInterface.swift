//
//  MapboxMapInterface.swift
//  CircleRun
//
//  Created by Anjan Athreya on 6/5/25.
//

import SwiftUI
import MapboxMaps

enum MapboxMapInterface {
    // MARK: - Colors & Styling
    enum Colors {
        static let primary = Color(red: 0.2, green: 0.6, blue: 1.0) // Brighter blue
        static let background = Color(white: 0.08) // Almost black
        static let overlay = Color.black.opacity(0.6) // Darker overlay
        static let text = Color(white: 0.95) // Almost white
        static let secondaryText = Color(white: 0.7) // Light gray
        static let controlBackground = Color(white: 0.12).opacity(0.95) // Very dark gray
        
        enum Gradients {
            static let bottomOverlay = Gradient(colors: [
                Color.black.opacity(0.0),
                Color.black.opacity(0.8)
            ])
            
            static let blueGlow = Gradient(colors: [
                primary.opacity(0.2),
                primary.opacity(0.0)
            ])
        }
        
        enum Effects {
            static let activeGlow = primary.opacity(0.3)
            static let inactiveGlow = Color.clear
        }
    }
    
    // MARK: - Layout
    enum Layout {
        enum size {
            static let searchBarCollapsed: CGFloat = 50
            static let controlButton: CGFloat = 44
            static let iconSize: CGFloat = 20
            static let glowRadius: CGFloat = 8
            static let activeGlowRadius: CGFloat = 12
            static let loadingIndicator: CGFloat = 1.5
        }
        
        enum spacing {
            static let small: CGFloat = 4
            static let medium: CGFloat = 12
            static let large: CGFloat = 16
        }
        
        enum padding {
            static let control: CGFloat = 12
            static let card: SwiftUI.EdgeInsets = .init(top: 16, leading: 16, bottom: 16, trailing: 16)
            static let bottomOffset: CGFloat = 100
        }
        
        enum cornerRadius {
            static let small: CGFloat = 8
            static let medium: CGFloat = 12
            static let large: CGFloat = 16
            static let circular: CGFloat = 25
        }
    }
    
    // MARK: - Typography
    enum Typography {
        static let headline = Font.headline
        static let subheadline = Font.subheadline
        static let buttonText = Font.headline.weight(.semibold)
        static let body = Font.body
    }
    
    // MARK: - Shadows
    enum Shadows {
        static let subtle = Shadow(
            color: Colors.primary.opacity(0.2),
            radius: 8,
            x: 0,
            y: 2
        )
        static let medium = Shadow(
            color: Colors.primary.opacity(0.3),
            radius: 12,
            x: 0,
            y: 4
        )
        static let glow = Shadow(
            color: Colors.primary.opacity(0.4),
            radius: 15,
            x: 0,
            y: 0
        )
        
        struct Shadow {
            let color: Color
            let radius: CGFloat
            let x: CGFloat
            let y: CGFloat
        }
    }
    
    // MARK: - Animation
    enum Animation {
        static let spring = SwiftUI.Animation.spring(
            response: 0.4,
            dampingFraction: 0.8,
            blendDuration: 0.2
        )
        static let defaultDuration: TimeInterval = 0.5
    }
    
    // MARK: - Controls
    enum Controls {
        static let sliderRange: ClosedRange<Double> = 1...50
        static let sliderStep: Double = 0.5
        static let defaultMiles: Double = 3.0
        static let paceRange: ClosedRange<Double> = 5...16
        static let paceStep: Double = 0.25
        static let defaultPaceMinPerMile: Double = 10.0

        enum Icons {
            static let search = "magnifyingglass"
            static let location = "location.fill"
            static let compass = "compass.fill"
            static let view2D = "view.2d"
            static let view3D = "view.3d"
            static let loop = "circle.dashed"
            static let map = "map"
            static let shuffle = "arrow.triangle.2.circlepath"
        }
    }

    // MARK: - Text
    enum Text {
        static let searchPlaceholder = "Generate a loop run"
        static let generatedRoute = "Generated Route"
        static let generatingRoute = "Generating Route..."
        static let startButton = "Start"
        static let generateButton = "Generate Loop"
        static let cancelButton = "Cancel"
        static let distancePrompt = "How far would you like to run?"
        static let pacePrompt = "Your pace"
        static let safePathsToggle = "Prefer sidewalks & trails"
        static let safePathsDetail = "Keeps the route on walkways and paths, away from alleys and busy streets"
        static let headingPrompt = "Preferred direction"
        static let suggestionsTitle = "Scenic spots nearby"
        static let suggestionsSubtitle = "Add stops to your run, then create the route"
        static let skipSuggestionsButton = "No Thanks"
        static let createRouteButton = "Create Route"
        static let scenicSpotsLoading = "Finding scenic spots nearby…"
        static let settingsTitle = "Settings"
        static let runningSection = "Running"
        static let routePreferencesSection = "Route Preferences"
        static let paceFooter = "Used to estimate how long a generated loop will take."
        static let loopGeneratorTitle = "Generate Loop"
        static let favoriteAdded = "Route added to favorites"
        static let favoriteRemoved = "Route removed from favorites"
        static let generationFailedTitle = "No Loop Found"
        static let tryAgainButton = "Try Again"
        static let okButton = "OK"
    }

    // MARK: - Presentation
    enum Presentation {
        static let loopGeneratorHeight: CGFloat = 480
    }
    
    // MARK: - Location
    enum Location {
        static let puckConfiguration = Puck2DConfiguration(
            topImage: UIImage(systemName: Controls.Icons.location)?.withTintColor(UIColor(Colors.primary)),
            bearingImage: UIImage(systemName: Controls.Icons.location)?.withTintColor(UIColor(Colors.primary)),
            shadowImage: nil,
            scale: .constant(1.0)
        )
        
        static let options = LocationOptions(
            puckType: .puck2D(puckConfiguration)
        )
    }
    
    // MARK: - Map Style
    enum MapStyle {
        static let darkStyle = StyleURI.dark
    }
} 
