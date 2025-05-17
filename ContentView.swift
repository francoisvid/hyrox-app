// ContentView.swift
import SwiftUI

struct ContentView: View {
    @State private var isLoggedIn = false
    @StateObject private var workoutManager = WorkoutManager()
    
    // Accès au PersistenceController pour l'environnement
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        if isLoggedIn {
           MainTabView(workoutManager: workoutManager, isLoggedIn: $isLoggedIn)
                .environment(\.managedObjectContext, viewContext)
        } else {
           LoginView(isLoggedIn: $isLoggedIn)
                .environment(\.managedObjectContext, viewContext)
        }
    }
}
