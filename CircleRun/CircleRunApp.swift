//
//  CircleRunApp.swift
//  CircleRun
//
//  Created by Anjan Athreya on 4/3/25.
//

import SwiftUI
import BackgroundTasks
import CoreLocation

@main
struct CircleRunApp: App {
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Enable background task scheduling
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.circlerun.locationupdate",
                                      using: nil) { task in
            self.handleBackgroundTask(task as! BGAppRefreshTask)
        }
        
        // Configure background capabilities
        application.beginReceivingRemoteControlEvents()
        application.beginBackgroundTask(expirationHandler: nil)
        
        return true
    }
    
    func application(_ application: UIApplication,
                    configurationForConnecting connectingSceneSession: UISceneSession,
                    options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let sceneConfig = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        sceneConfig.delegateClass = SceneDelegate.self
        return sceneConfig
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        let backgroundTask = application.beginBackgroundTask { [weak self] in
            self?.scheduleBackgroundTask()
        }
        
        scheduleBackgroundTask()
        
        if backgroundTask != .invalid {
            application.endBackgroundTask(backgroundTask)
        }
    }
    
    private func scheduleBackgroundTask() {
        let request = BGAppRefreshTaskRequest(identifier: "com.circlerun.locationupdate")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule app refresh: \(error)")
        }
    }
    
    private func handleBackgroundTask(_ task: BGAppRefreshTask) {
        scheduleBackgroundTask()
        
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        // Perform any background processing here
        
        task.setTaskCompleted(success: true)
    }
}

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    func windowScene(_ windowScene: UIWindowScene,
                    didUpdate previousCoordinateSpace: UICoordinateSpace,
                    interfaceOrientation previousInterfaceOrientation: UIInterfaceOrientation) {
        // Handle scene lifecycle if needed
    }
    
    func sceneDidEnterBackground(_ scene: UIScene) {
        // Handle scene entering background if needed
    }
}
