import SwiftUI
import Combine

struct ProfileView: View {
    @Binding var isLoggedIn: Bool
    @StateObject private var vm = ProfileViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ProfileHeaderView(vm: vm)
                ActivitySummaryView(vm: vm)
                SettingsView(vm: vm)
                LogoutButton(isLoggedIn: $isLoggedIn)
                Text("Version 1.0.0")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.top)
            }
            .padding()
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Profil")
    }
}

// MARK: - ViewModel

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var username = UserDefaults.standard.string(forKey: "username") ?? "Athlète Hyrox"
    @Published var email    = UserDefaults.standard.string(forKey: "email")    ?? "user@example.com"
    @AppStorage("isHeartRateMonitoringEnabled") var isHeartRateMonitoringEnabled = true
    @AppStorage("selectedWeightUnit")            var selectedWeightUnit            = 0
    @AppStorage("selectedDistanceUnit")          var selectedDistanceUnit          = 0
    @Published var isDarkModeEnabled = true

    // On initialise le manager directement ici
    private let manager = WorkoutManager(dataController: DataController.shared)

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

    func saveUsername(_ newName: String) {
        username = newName
        UserDefaults.standard.set(newName, forKey: "username")
    }
}

// MARK: - Subviews

private struct ProfileHeaderView: View {
    @ObservedObject var vm: ProfileViewModel
    @State private var editing = false
    @State private var draft    = ""

    var body: some View {
        HStack(spacing: 15) {
            Circle()
                .fill(Color(.systemGray6))
                .frame(width: 80, height: 80)
                .overlay(
                    Text(vm.username.prefix(1).uppercased())
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(.yellow)
                )

            VStack(alignment: .leading, spacing: 4) {
                if editing {
                    HStack {
                        TextField("Nom d'utilisateur", text: $draft)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .foregroundColor(.white)
                        Button("Enregistrer") {
                            if !draft.isEmpty {
                                vm.saveUsername(draft)
                            }
                            editing = false
                        }
                        .foregroundColor(.yellow)
                    }
                } else {
                    HStack {
                        Text(vm.username)
                            .font(.title2).bold()
                            .foregroundColor(.white)
                        Button {
                            draft = vm.username
                            editing = true
                        } label: {
                            Image(systemName: "pencil")
                                .foregroundColor(.yellow)
                        }
                    }
                    Text(vm.email)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

private struct ActivitySummaryView: View {
    @ObservedObject var vm: ProfileViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Résumé d'activité")
                .font(.headline)
                .foregroundColor(.white)

            HStack(spacing: 10) {
                ActivityStatCard(title: "Entraînements",
                                 value: "\(vm.totalWorkouts)",
                                 icon: "figure.run")
                ActivityStatCard(title: "Temps total",
                                 value: TimeFormatter.formatTime(vm.totalDuration),
                                 icon: "clock")
                ActivityStatCard(title: "Distance",
                                 value: String(format: "%.1f km", vm.totalDistance),
                                 icon: "arrow.left.and.right")
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

private struct SettingsView: View {
    @ObservedObject var vm: ProfileViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Paramètres")
                .font(.headline)
                .foregroundColor(.white)

            Toggle("Monitoring cardiaque", isOn: $vm.isHeartRateMonitoringEnabled)
                .toggleStyle(SwitchToggleStyle(tint: .yellow))
                .foregroundColor(.white)

            VStack(alignment: .leading) {
                Text("Unité de poids").foregroundColor(.white)
                Picker("", selection: $vm.selectedWeightUnit) {
                    Text("kg").tag(0)
                    Text("lb").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
            }

            VStack(alignment: .leading) {
                Text("Unité de distance").foregroundColor(.white)
                Picker("", selection: $vm.selectedDistanceUnit) {
                    Text("m").tag(0)
                    Text("km").tag(1)
                    Text("mi").tag(2)
                }
                .pickerStyle(SegmentedPickerStyle())
            }

            Toggle("Mode sombre", isOn: $vm.isDarkModeEnabled)
                .toggleStyle(SwitchToggleStyle(tint: .yellow))
                .foregroundColor(.white)
                .disabled(true)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

private struct LogoutButton: View {
    @Binding var isLoggedIn: Bool

    var body: some View {
        Button {
            isLoggedIn = false
        } label: {
            Text("Déconnexion")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red.opacity(0.8))
                .cornerRadius(12)
        }
    }
}

private struct ActivityStatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2).foregroundColor(.yellow)
            Text(value)
                .font(.title3).bold().foregroundColor(.white)
            Text(title)
                .font(.caption).foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.black.opacity(0.3))
        .cornerRadius(8)
    }
}

#Preview {
    ProfileView(isLoggedIn: .constant(true))
}
