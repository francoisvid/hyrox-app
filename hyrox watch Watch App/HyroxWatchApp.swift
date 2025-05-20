import SwiftUI
import WatchConnectivity

@main
struct HyroxWatchApp: App {
    // Initialisation explicite des singletons
    private let dataController = DataController.shared
    private let syncManager = DataSyncManager.shared
    
    init() {
        print("⌚️ Initialisation de l'application Watch")
        print("⌚️ DataSyncManager initialisé")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, dataController.container.viewContext)
        }
    }
}
