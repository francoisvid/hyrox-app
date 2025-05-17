// Dans MainTabView.swift

import SwiftUICore
import SwiftUI
struct MainTabView: View {
    @ObservedObject var workoutManager: WorkoutManager
    
    // Créer les ViewModels avec le WorkoutManager
    @StateObject private var workoutViewModel: WorkoutViewModel
    @StateObject private var statsViewModel: StatsViewModel
    @Binding var isLoggedIn: Bool
    
    init(workoutManager: WorkoutManager, isLoggedIn: Binding<Bool>) {
        self.workoutManager = workoutManager
        self._isLoggedIn = isLoggedIn
        
        // Initialiser les ViewModels avec le WorkoutManager
        self._workoutViewModel = StateObject(wrappedValue: WorkoutViewModel(workoutManager: workoutManager))
        self._statsViewModel = StateObject(wrappedValue: StatsViewModel(workoutManager: workoutManager))
    }
    
    var body: some View {
        TabView {
            DashboardView(viewModel: workoutViewModel)
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.fill")
                }
            
            WorkoutView(viewModel: workoutViewModel)
                .tabItem {
                    Label("Entraînement", systemImage: "figure.run")
                }
            
            StatisticsView(viewModel: statsViewModel)
                .tabItem {
                    Label("Statistiques", systemImage: "chart.line.uptrend.xyaxis")
                }
            
            ProfileView(isLoggedIn: $isLoggedIn, workoutManager: workoutManager)
                .tabItem {
                    Label("Profil", systemImage: "person.fill")
                }
        }
        .accentColor(.yellow)
        .preferredColorScheme(.dark)
    }
}
