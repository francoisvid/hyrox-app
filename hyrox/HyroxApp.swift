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
    
    // Flag pour éviter la synchronisation multiple
    @State private var hasPerformedInitialSync = false
    
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
                        
                        // Synchronisation initiale au premier lancement
                        if !hasPerformedInitialSync {
                            hasPerformedInitialSync = true
                            performInitialSync()
                        }
                    }
                }
        }
    }
    
    private func performInitialSync() {
        Task {
            do {
                print("🔄 Début de la synchronisation initiale")
                
                // Attendre un peu que tout soit initialisé
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconde
                
                // 1. Charger les workouts depuis Firebase
                let workoutManager = WorkoutManager()
                try await workoutManager.loadWorkoutsFromFirebase()
                print("✅ Workouts chargés depuis Firebase")
                
                // 2. Demander les workouts de la Watch si elle est connectée
                if WCSession.default.isReachable {
                    syncManager.forceSendAllWorkouts()
                    print("📱 Demande de synchronisation envoyée à la Watch")
                } else {
                    print("⌚️ Watch non accessible pour la synchronisation")
                }
                
                // 3. Envoyer les objectifs à la Watch
                syncManager.sendGoals()
                
            } catch {
                print("❌ Erreur lors de la synchronisation initiale: \(error)")
            }
        }
    }
}
