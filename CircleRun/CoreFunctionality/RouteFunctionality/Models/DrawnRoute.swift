////
////  DrawnRoute.swift
////  CircleRun
////
////  Created by Anjan Athreya on 6/3/25.
////
//
//import Foundation
//import MapKit
//import CoreLocation
//
//struct DrawnRoute: Identifiable, Codable {
//    let id: UUID
//    let name: String
//    let coordinates: [RouteCoordinate]
//    let distance: Double // in meters
//    let createdAt: Date
//    
//    init(id: UUID = UUID(), name: String, coordinates: [CLLocationCoordinate2D], distance: Double) {
//        self.id = id
//        self.name = name
//        self.coordinates = coordinates.map(RouteCoordinate.init)
//        self.distance = distance
//        self.createdAt = Date()
//    }
//    
//    var polyline: MKPolyline {
//        let coords = coordinates.map { $0.coordinate }
//        return MKPolyline(coordinates: coords, count: coords.count)
//    }
//}
//
//// Helper struct to make CLLocationCoordinate2D codable
//struct RouteCoordinate: Codable {
//    let latitude: Double
//    let longitude: Double
//    
//    init(coordinate: CLLocationCoordinate2D) {
//        self.latitude = coordinate.latitude
//        self.longitude = coordinate.longitude
//    }
//    
//    var coordinate: CLLocationCoordinate2D {
//        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
//    }
//}
//
//// MARK: - Route Store
//class DrawnRouteStore: ObservableObject {
//    @Published private(set) var routes: [DrawnRoute] = []
//    private let saveKey = "DrawnRoutes"
//    
//    init() {
//        loadRoutes()
//    }
//    
//    func addRoute(_ route: DrawnRoute) {
//        routes.append(route)
//        saveRoutes()
//    }
//    
//    func deleteRoute(_ route: DrawnRoute) {
//        routes.removeAll { $0.id == route.id }
//        saveRoutes()
//    }
//    
//    private func loadRoutes() {
//        if let data = UserDefaults.standard.data(forKey: saveKey),
//           let decodedRoutes = try? JSONDecoder().decode([DrawnRoute].self, from: data) {
//            routes = decodedRoutes
//        }
//    }
//    
//    private func saveRoutes() {
//        if let encoded = try? JSONEncoder().encode(routes) {
//            UserDefaults.standard.set(encoded, forKey: saveKey)
//        }
//    }
//} 
