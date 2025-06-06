import SwiftUI
import FirebaseAuth
import Combine

struct ProfileView: View {
    @Binding var isLoggedIn: Bool
    @StateObject private var vm = ProfileViewModel()
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ProfileHeaderView(vm: vm)
                ActivitySummaryView(vm: vm)
                GoalsSectionView(formatTime: vm.formatTime)
                SettingsView(vm: vm)
                LogoutButton(isLoggedIn: $isLoggedIn, vm: vm) // Passer le ViewModel
                Text("Version 0.1")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top)
            }
            .padding()
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .navigationTitle("Profil")
        .preferredColorScheme(vm.isDarkModeEnabled ? .dark : .light)
        .onAppear {
            vm.refreshUserInfo() // Rafraîchir les infos utilisateur à l'apparition
        }
    }
}

// MARK: - Goals Section

private struct GoalsSectionView: View {
    let formatTime: (TimeInterval) -> String
    @StateObject private var viewModel = GoalsViewModel()
    @State private var editingGoal: String? = nil
    @State private var newGoalMinutes: Double = 0
    
    // Trier les exercices selon l'ordre standard
    private var sortedExercises: [ExerciseDefinition] {
        Workout.standardExerciseOrder.compactMap { name in
            ExerciseDefinitions.all[name]
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Objectifs HYROX")
                .font(.headline)
                .foregroundColor(.primary)
            
            ForEach(sortedExercises, id: \.name) { def in
                HStack {
                    Text(def.name)
                        .foregroundColor(.primary)
                    Spacer()
                    if editingGoal == def.name {
                        HStack(spacing: 4) {
                            TextField("Minutes", value: $newGoalMinutes, format: .number)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 80)
                            Text("min")
                                .foregroundColor(.secondary)
                        }
                        .onSubmit {
                            // Convertir les minutes en secondes
                            let seconds = newGoalMinutes * 60
                            viewModel.setGoal(for: def.name, targetTime: seconds)
                            editingGoal = nil
                        }
                    } else {
                        let currentGoal = viewModel.goals[def.name] ?? 0
                        if currentGoal > 0 {
                            Text("< \(formatTime(currentGoal))")
                                .foregroundColor(.yellow)
                        } else {
                            Text("--:--")
                                .foregroundColor(.secondary)
                        }
                    }
                    Button(action: {
                        if editingGoal == def.name {
                            // Convertir les minutes en secondes
                            let seconds = newGoalMinutes * 60
                            viewModel.setGoal(for: def.name, targetTime: seconds)
                            editingGoal = nil
                        } else {
                            editingGoal = def.name
                            // Convertir les secondes en minutes
                            newGoalMinutes = (viewModel.goals[def.name] ?? 0) / 60
                        }
                    }) {
                        Image(systemName: editingGoal == def.name ? "checkmark.circle" : "pencil.circle")
                            .foregroundColor(.yellow)
                    }
                }
                .padding()
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .onAppear {
            viewModel.refreshGoals()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("GoalsUpdated"))) { _ in
            viewModel.refreshGoals()
        }
    }
}

// MARK: - Subviews

private struct ProfileHeaderView: View {
    @ObservedObject var vm: ProfileViewModel
    @State private var editing = false
    @State private var draft = ""
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 15) {
            HStack(spacing: 15) {
                Circle()
                    .fill(Color(.secondarySystemBackground))
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.yellow, lineWidth: 4)
                    )
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
                                .foregroundColor(.primary)
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
                                .foregroundColor(.primary)
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
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Message informatif si le nom est par défaut
            if vm.username == "Athlète Hyrox" {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.yellow)
                    Text("Cliquez sur le crayon pour personnaliser votre nom")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 5)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

private struct ActivitySummaryView: View {
    @ObservedObject var vm: ProfileViewModel
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Résumé d'activité")
                .font(.headline)
                .foregroundColor(.primary)

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
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

private struct SettingsView: View {
    @ObservedObject var vm: ProfileViewModel
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Paramètres")
                .font(.headline)
                .foregroundColor(.primary)

            Toggle("Monitoring cardiaque", isOn: $vm.isHeartRateMonitoringEnabled)
                .toggleStyle(SwitchToggleStyle(tint: .yellow))
                .foregroundColor(.primary)
                .disabled(true)

            VStack(alignment: .leading) {
                Text("Unité de poids").foregroundColor(.primary)
                Picker("", selection: $vm.selectedWeightUnit) {
                    Text("kg").tag(0)
                    Text("lb").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
            }

            VStack(alignment: .leading) {
                Text("Unité de distance").foregroundColor(.primary)
                Picker("", selection: $vm.selectedDistanceUnit) {
                    Text("m").tag(0)
                    Text("km").tag(1)
                    Text("mi").tag(2)
                }
                .pickerStyle(SegmentedPickerStyle())
            }

            Toggle("Mode sombre", isOn: $vm.isDarkModeEnabled)
                .toggleStyle(SwitchToggleStyle(tint: .yellow))
                .foregroundColor(.primary)
                .onChange(of: vm.isDarkModeEnabled) { _ in
                    vm.toggleDarkMode()
                }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

private struct LogoutButton: View {
    @Binding var isLoggedIn: Bool
    @ObservedObject var vm: ProfileViewModel

    var body: some View {
        Button {
            // Déconnexion Firebase
            do {
                try Auth.auth().signOut()
                isLoggedIn = false
                // Optionnel: nettoyer les données locales
                UserDefaults.standard.removeObject(forKey: "username")
                UserDefaults.standard.removeObject(forKey: "email")
            } catch let signOutError as NSError {
                print("Erreur lors de la déconnexion: \(signOutError.localizedDescription)")
                // Même en cas d'erreur, déconnecter localement
                isLoggedIn = false
            }
        } label: {
            Text("Déconnexion")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red)
                .cornerRadius(12)
        }
    }
}

private struct ActivityStatCard: View {
    let title: String
    let value: String
    let icon: String
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2).foregroundColor(.yellow)
            Text(value)
                .font(.title3).bold().foregroundColor(.primary)
            Text(title)
                .font(.caption).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 100)
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(8)
    }
}

#Preview {
    ProfileView(isLoggedIn: .constant(true))
}
