import SwiftUI
import WatchConnectivity

@main
struct HyroxWatchApp: App {
    // Initialisation explicite des singletons
    private let dataController = DataController.shared
    private let syncManager = DataSyncManager.shared
    
    init() {
        print("⌚️ Initialisation de l'application Watch")
        
        // Activer la session explicitement
        if WCSession.isSupported() {
            print("⌚️ WCSession est supporté sur la Watch")
            if WCSession.default.activationState != .activated {
                print("⌚️ Tentative d'activation de WCSession")
                WCSession.default.delegate = syncManager
                WCSession.default.activate()
            }
        }
        
        print("⌚️ DataSyncManager initialisé")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, dataController.container.viewContext)
        }
    }
}
