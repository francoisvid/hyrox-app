// Views/ProfileView.swift (mise à jour pour utiliser Core Data)
import SwiftUI
import CoreData

struct ProfileView: View {
    // État de l'utilisateur
    @State private var username = UserDefaults.standard.string(forKey: "username") ?? "Athlète Hyrox"
    @State private var email = UserDefaults.standard.string(forKey: "email") ?? "user@example.com"
    @State private var editingUsername = false
    @State private var tempUsername = ""
    
    // États pour les paramètres
    @AppStorage("isHeartRateMonitoringEnabled") private var isHeartRateMonitoringEnabled = true
    @AppStorage("selectedWeightUnit") private var selectedWeightUnit = 0 // 0: kg, 1: lb
    @AppStorage("selectedDistanceUnit") private var selectedDistanceUnit = 0 // 0: m, 1: km, 2: miles
    @State private var isDarkModeEnabled = true
    
    // Pour accéder aux données Core Data
    @Environment(\.managedObjectContext) private var viewContext
    
    // Pour la déconnexion
    @Binding var isLoggedIn: Bool
    
    // Pour accéder au WorkoutManager
    @ObservedObject var workoutManager: WorkoutManager
    
    // Formateurs
    private let timeFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter
    }()
    
    // Calcul des statistiques
    private var totalWorkouts: Int {
        return workoutManager.getTotalWorkoutCount()
    }
    
    private var totalDuration: TimeInterval {
        return workoutManager.workouts.reduce(0) { $0 + $1.duration }
    }
    
    private var totalDistance: Double {
        return workoutManager.workouts.reduce(0) { $0 + $1.distance }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // En-tête du profil
                HStack(spacing: 15) {
                    // Avatar
                    ZStack {
                        Circle()
                            .fill(Color(.systemGray6))
                            .frame(width: 80, height: 80)
                        
                        Text(username.prefix(1).uppercased())
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(.yellow)
                    }
                    
                    // Infos utilisateur
                    VStack(alignment: .leading, spacing: 4) {
                        if editingUsername {
                            HStack {
                                TextField("Nom d'utilisateur", text: $tempUsername)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                
                                Button(action: {
                                    if !tempUsername.isEmpty {
                                        username = tempUsername
                                        UserDefaults.standard.set(username, forKey: "username")
                                    }
                                    editingUsername = false
                                }) {
                                    Text("Enregistrer")
                                        .foregroundColor(.yellow)
                                }
                            }
                        } else {
                            HStack {
                                Text(username)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                
                                Button(action: {
                                    tempUsername = username
                                    editingUsername = true
                                }) {
                                    Image(systemName: "pencil")
                                        .foregroundColor(.yellow)
                                }
                            }
                        }
                        
                        Text(email)
                            .foregroundColor(.gray)
                            .font(.subheadline)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Résumé d'activité
                VStack(alignment: .leading, spacing: 10) {
                    Text("Résumé d'activité")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    HStack(spacing: 20) {
                        ActivityStatCard(
                            title: "Entraînements",
                            value: "\(totalWorkouts)",
                            icon: "figure.run"
                        )
                        
                        ActivityStatCard(
                            title: "Temps total",
                            value: timeFormatter.string(from: totalDuration) ?? "0h",
                            icon: "clock"
                        )
                        
                        ActivityStatCard(
                            title: "Distance",
                            value: String(format: "%.1f km", totalDistance),
                            icon: "arrow.left.and.right"
                        )
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Paramètres
                VStack(alignment: .leading, spacing: 15) {
                    Text("Paramètres")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    // Monitoring cardiaque
                    Toggle("Monitoring cardiaque", isOn: $isHeartRateMonitoringEnabled)
                        .foregroundColor(.white)
                        .toggleStyle(SwitchToggleStyle(tint: .yellow))
                    
                    // Unités
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Unité de poids")
                            .foregroundColor(.white)
                        
                        Picker("", selection: $selectedWeightUnit) {
                            Text("Kilogrammes (kg)").tag(0)
                            Text("Livres (lb)").tag(1)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .colorMultiply(.yellow)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Unité de distance")
                            .foregroundColor(.white)
                        
                        Picker("", selection: $selectedDistanceUnit) {
                            Text("Mètres (m)").tag(0)
                            Text("Kilomètres (km)").tag(1)
                            Text("Miles (mi)").tag(2)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .colorMultiply(.yellow)
                    }
                    
                    // Mode sombre
                    Toggle("Mode sombre", isOn: $isDarkModeEnabled)
                        .foregroundColor(.white)
                        .toggleStyle(SwitchToggleStyle(tint: .yellow))
                        .disabled(true) // Toujours activé pour l'instant
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Bouton de déconnexion
                Button(action: {
                    // Déconnexion
                    isLoggedIn = false
                }) {
                    HStack {
                        Spacer()
                        Text("Déconnexion")
                            .font(.headline)
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding()
                    .background(Color.red.opacity(0.8))
                    .cornerRadius(12)
                }
                
                // Version
                Text("Version 1.0.0")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top)
            }
            .padding()
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Profil")
    }
}

// Composant pour afficher une statistique d'activité
struct ActivityStatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.yellow)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.black.opacity(0.3))
        .cornerRadius(8)
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        let persistenceController = PersistenceController(inMemory: true)
        let workoutManager = WorkoutManager(persistenceController: persistenceController)
        
        return ProfileView(isLoggedIn: .constant(true), workoutManager: workoutManager)
            .preferredColorScheme(.dark)
            .environment(\.managedObjectContext, persistenceController.container.viewContext)
    }
}
