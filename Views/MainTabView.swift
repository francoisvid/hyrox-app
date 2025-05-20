// MainTabView.swift

import SwiftUI

struct MainTabView: View {
    // Un seul manager partagé
    @StateObject private var workoutManager: WorkoutManager
    @StateObject private var workoutVM: WorkoutViewModel
    @StateObject private var statsVM: StatsViewModel
    @Binding var isLoggedIn: Bool

    init(isLoggedIn: Binding<Bool>) {
        self._isLoggedIn = isLoggedIn
        // Crée d’abord le manager, puis les VMs
        let manager = WorkoutManager(dataController: DataController.shared)
        self._workoutManager = StateObject(wrappedValue: manager)
        self._workoutVM     = StateObject(wrappedValue: WorkoutViewModel(workoutManager: manager))
        self._statsVM       = StateObject(wrappedValue: StatsViewModel(workoutManager: manager))
    }

    var body: some View {
        TabView {
            DashboardView(viewModel: workoutVM)
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.fill")
                }

            WorkoutView(viewModel: workoutVM)
                .tabItem {
                    Label("Entraînement", systemImage: "figure.run")
                }

            StatisticsView(viewModel: statsVM)
                .tabItem {
                    Label("Statistiques", systemImage: "chart.line.uptrend.xyaxis")
                }

            ProfileView(isLoggedIn: $isLoggedIn)
                .tabItem {
                    Label("Profil", systemImage: "person.fill")
                }
        }
        .accentColor(.yellow)
        .preferredColorScheme(.dark)
    }
}
