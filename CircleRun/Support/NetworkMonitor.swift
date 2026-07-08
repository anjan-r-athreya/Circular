//
//  NetworkMonitor.swift
//  CircleRun
//
//  Live connectivity hint so generation can fail fast with "you're
//  offline" instead of burning its request budget against a dead radio.
//

import Network
import Foundation

final class NetworkMonitor {
    static let shared = NetworkMonitor()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.circlerun.network-monitor")
    private var _isOnline = true

    /// Optimistic until the first path update lands.
    var isOnline: Bool {
        queue.sync { _isOnline }
    }

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?._isOnline = path.status == .satisfied
        }
        // Handler runs on the same serial queue that guards reads.
        monitor.start(queue: queue)
    }
}
