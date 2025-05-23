import SwiftUI
import CoreData
import WatchConnectivity
import FirebaseCore
import FirebaseFirestore

@main
struct HyroxApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("isDarkModeEnabled") private var isDarkModeEnabled = true
    
    // Initialisation explicite
    private let dataController: DataController
    private let syncManager: DataSyncManager
    private let firebaseSyncManager: SyncManager
    
    init() {
        print("🚀 Initialisation de l'application iOS")
        
        // Configurer Firebase en premier
        FirebaseApp.configure()
        
        // Configuration pour l'émulateur en mode debug
        #if DEBUG
        let settings = FirestoreSettings()
        settings.host = "localhost:8080"
        settings.isPersistenceEnabled = false
        settings.isSSLEnabled = false
        
        let db = Firestore.firestore()
        db.settings = settings
        #endif
        
        // Initialiser les managers
        self.dataController = DataController.shared
        self.syncManager = DataSyncManager.shared
        self.firebaseSyncManager = SyncManager.shared
        
        // Activer la session explicitement
        if WCSession.isSupported() {
            print("📱 WCSession est supporté sur l'iPhone")
            if WCSession.default.activationState != .activated {
                print("📱 Tentative d'activation de WCSession")
                WCSession.default.delegate = syncManager
                WCSession.default.activate()
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            SplashScreenView()
                .environment(\.managedObjectContext, dataController.container.viewContext)
                .preferredColorScheme(isDarkModeEnabled ? .dark : .light)
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
