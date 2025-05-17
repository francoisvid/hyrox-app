import SwiftUI

@main
struct HyroxApp: App {
    // Injecter le controller de persistance
    let persistenceController = PersistenceController.shared
    
    // Créer le workout manager avec le controller de persistance
    @StateObject private var workoutManager = WorkoutManager()
    
    // État pour gérer la connexion utilisateur
    @State private var isLoggedIn = false
    
    init() {
        persistenceController.createDemoDataIfNeeded()
    }
    
    var body: some Scene {
        WindowGroup {
            if isLoggedIn {
                MainTabView(workoutManager: workoutManager, isLoggedIn: $isLoggedIn)
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
            } else {
                LoginView(isLoggedIn: $isLoggedIn)
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
            }
        }
    }
}
