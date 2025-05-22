import SwiftUI
import Combine
import FirebaseAuth

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var username = UserDefaults.standard.string(forKey: "username") ?? "Athlète Hyrox"
    @Published var email    = UserDefaults.standard.string(forKey: "email")    ?? "user@example.com"
    @AppStorage("isHeartRateMonitoringEnabled") var isHeartRateMonitoringEnabled = true
    @AppStorage("selectedWeightUnit")            var selectedWeightUnit            = 0
    @AppStorage("selectedDistanceUnit")          var selectedDistanceUnit          = 0
    @AppStorage("isDarkModeEnabled")             var isDarkModeEnabled             = true

    // On initialise le manager directement ici
    private let manager = WorkoutManager(dataController: DataController.shared)
    
    init() {
        loadUserInfo()
        // Observer les changements d'authentification
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.loadUserInfo()
        }
    }

    // MARK: - User Info Management
    
    private func loadUserInfo() {
        guard let user = Auth.auth().currentUser else {
            // Utilisateur non connecté, utiliser les valeurs par défaut
            username = UserDefaults.standard.string(forKey: "username") ?? "Athlète Hyrox"
            email = UserDefaults.standard.string(forKey: "email") ?? "user@example.com"
            return
        }
        
        // Récupérer le nom d'affichage
        if let displayName = user.displayName, !displayName.isEmpty {
            username = displayName
        } else {
            // Fallback sur le nom sauvegardé localement ou nom par défaut
            username = UserDefaults.standard.string(forKey: "username") ?? "Athlète Hyrox"
        }
        
        // Récupérer l'email
        if let userEmail = user.email, !userEmail.isEmpty {
            email = userEmail
        } else {
            // Pour Apple Sign-In, l'email peut être masqué
            // Utiliser l'email sauvegardé ou un placeholder
            email = UserDefaults.standard.string(forKey: "email") ?? "Email masqué"
        }
        
        // Sauvegarder les informations localement pour les futures utilisations
        UserDefaults.standard.set(username, forKey: "username")
        UserDefaults.standard.set(email, forKey: "email")
    }
    
    func refreshUserInfo() {
        loadUserInfo()
    }

    // Computed properties avant utilisées sur les méthodes manquantes
    var totalWorkouts: Int {
        manager.workouts.count
    }
    var totalDuration: TimeInterval {
        manager.workouts.reduce(0) { $0 + $1.duration }
    }
    var totalDistance: Double {
        manager.workouts.reduce(0) { $0 + $1.distance }
    }

    func formatTime(_ time: TimeInterval) -> String {
        let m = Int(time) / 60
        let s = Int(time) % 60
        return String(format: "%02d:%02d", m, s)
    }

    func saveUsername(_ newName: String) {
        username = newName
        UserDefaults.standard.set(newName, forKey: "username")
        
        // Mettre à jour aussi le profil Firebase si l'utilisateur est connecté
        if let user = Auth.auth().currentUser {
            let changeRequest = user.createProfileChangeRequest()
            changeRequest.displayName = newName
            changeRequest.commitChanges { error in
                if let error = error {
                    print("Erreur lors de la mise à jour du profil Firebase: \(error.localizedDescription)")
                } else {
                    print("Profil Firebase mis à jour avec succès")
                }
            }
        }
    }
    
    func toggleDarkMode() {
        isDarkModeEnabled.toggle()
        // Forcer le changement de mode
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            windowScene.windows.forEach { window in
                window.overrideUserInterfaceStyle = isDarkModeEnabled ? .dark : .light
            }
        }
    }
}
