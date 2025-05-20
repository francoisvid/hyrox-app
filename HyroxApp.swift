// HyroxApp.swift

import SwiftUI
import CoreData
import WatchConnectivity

@main
struct HyroxApp: App {
    @Environment(\.scenePhase) private var scenePhase
    
    // Initialisation explicite
    private let dataController = DataController.shared
    private let syncManager = DataSyncManager.shared
    
    init() {
        print("🚀 Initialisation de l'application iOS")
        
        // Activer la session explicitement
        if WCSession.isSupported() {
            print("📱 WCSession est supporté sur l'iPhone")
            if WCSession.default.activationState != .activated {
                print("📱 Tentative d'activation de WCSession")
                WCSession.default.delegate = syncManager
                WCSession.default.activate()
            }
        }
        
        // Seed / load Core Data
        dataController.createDemoDataIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext,
                              dataController.container.viewContext)
                .onChange(of: scenePhase) { newPhase in
                    if newPhase == .active {
                        print("📱 Application devenue active")
                        print("📱 WCSession actif: \(WCSession.default.activationState.rawValue)")
                        if WCSession.default.activationState == .activated {
                            print("📱 WCSession reachable: \(WCSession.default.isReachable)")
                        }
                    }
                }
        }
    }
}
