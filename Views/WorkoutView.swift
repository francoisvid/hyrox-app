// Views/WorkoutView.swift
import SwiftUI
import CoreData

struct WorkoutView: View {
    @ObservedObject var viewModel: WorkoutViewModel
    @State private var currentExerciseIndex: Int = 0
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 15) {
                if viewModel.isWorkoutActive {
                    // Afficher minuteur
                    HStack {
                        Text(viewModel.formatTime(viewModel.elapsedTime))
                            .font(.system(size: 45, weight: .bold))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Button(action: {
                            viewModel.endWorkout()
                        }) {
                            Image(systemName: "stop.fill")
                                .font(.title)
                                .foregroundColor(.red)
                                .padding()
                                .background(Color(.systemGray6))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.vertical)
                    
                    // Afficher l'exercice en cours
                    if !viewModel.currentExercises.isEmpty {
                        let currentExercise = viewModel.currentExercises[currentExerciseIndex]
                        
                        VStack(spacing: 20) {
                            // En-tête de l'exercice
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Exercice \(currentExerciseIndex + 1) sur \(viewModel.currentExercises.count)")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                
                                Text(currentExercise.name ?? "Exercice")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                
                                if let description = HyroxConstants.description(for: currentExercise.name ?? "") {
                                    Text(description)
                                        .font(.body)
                                        .foregroundColor(.gray)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            
                            // Bouton pour démarrer/terminer l'exercice
                            Button(action: {
                                viewModel.selectExercise(currentExercise)
                            }) {
                                Text(viewModel.isExerciseCompleted(currentExercise) ? "MODIFIER L'EXERCICE" : "DÉMARRER L'EXERCICE")
                                    .font(.headline)
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.yellow)
                                    .cornerRadius(8)
                            }
                            
                            // Bouton suivant (visible uniquement si l'exercice est terminé)
                            if viewModel.isExerciseCompleted(currentExercise) && currentExerciseIndex < viewModel.currentExercises.count - 1 {
                                Button(action: {
                                    withAnimation {
                                        currentExerciseIndex += 1
                                    }
                                }) {
                                    Text("EXERCICE SUIVANT")
                                        .font(.headline)
                                        .foregroundColor(.black)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.green)
                                        .cornerRadius(8)
                                }
                            }
                            
                            // Bouton terminer l'entraînement (visible uniquement sur le dernier exercice)
                            if currentExerciseIndex == viewModel.currentExercises.count - 1 && viewModel.isExerciseCompleted(currentExercise) {
                                Button(action: {
                                    viewModel.endWorkout()
                                }) {
                                    Text("TERMINER L'ENTRAÎNEMENT")
                                        .font(.headline)
                                        .foregroundColor(.black)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.red)
                                        .cornerRadius(8)
                                }
                            }
                        }
                    } else {
                        Text("Chargement des exercices...")
                            .foregroundColor(.white)
                    }
                } else {
                    // Écran de démarrage d'entraînement
                    VStack(spacing: 30) {
                        // Aperçu des exercices
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Exercices de l'entraînement")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            ForEach(HyroxConstants.standardExercises.indices, id: \.self) { index in
                                let exercise = HyroxConstants.standardExercises[index]
                                HStack {
                                    Text("\(index + 1).")
                                        .foregroundColor(.gray)
                                        .frame(width: 30, alignment: .leading)
                                    
                                    Text(exercise.name)
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    Text(exercise.description)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        
                        Button(action: {
                            viewModel.startWorkout()
                            currentExerciseIndex = 0
                        }) {
                            Text("DÉMARRER L'ENTRAÎNEMENT")
                                .font(.headline)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.yellow)
                                .cornerRadius(8)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Entraînement Hyrox")
            .navigationBarTitleDisplayMode(.large)
            /** .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Entraînement")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }**/
        }
        .sheet(item: $viewModel.selectedExercise) { exercise in
            ExerciseDetailView(exercise: exercise, viewModel: viewModel)
        }
    }
}

// Extension pour accéder en toute sécurité aux éléments d'un tableau
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

struct ExerciseDetailView: View {
    let exercise: Exercise
    @ObservedObject var viewModel: WorkoutViewModel
    @State private var duration: TimeInterval = 0
    @State private var distance: Double = 0
    @State private var repetitions: Int = 0
    @State private var isTimerRunning = false
    @State private var startTime: Date?
    @Environment(\.presentationMode) var presentationMode
    
    // Nom de l'exercice avec gestion de nil
    private var exerciseName: String {
        return exercise.name ?? "Exercice"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text(exerciseName)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(viewModel.formatTime(duration))
                    .font(.system(size: 60, weight: .bold))
                    .foregroundColor(.white)
                
                HStack(spacing: 40) {
                    timerControls
                }
                .padding()
                
                // Afficher les champs pertinents en fonction du type d'exercice
                exerciseFields
                
                Spacer()
                
                finishButton
            }
            .padding()
            .background(Color.black)
            .navigationBarItems(
                trailing: Button("Fermer") {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(.yellow)
            )
        }
    }
    
    // Boutons de contrôle du timer
    private var timerControls: some View {
        HStack(spacing: 40) {
            Button(action: toggleTimer) {
                Image(systemName: isTimerRunning ? "pause.fill" : "play.fill")
                    .font(.title)
                    .foregroundColor(isTimerRunning ? .red : .green)
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(Circle())
            }
            
            Button(action: resetTimer) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.title)
                    .foregroundColor(.yellow)
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(Circle())
            }
        }
    }
    
    // Champs spécifiques à l'exercice
    @ViewBuilder
    private var exerciseFields: some View {
        // Vérifier si le nom n'est pas nil
        if let name = exercise.name {
            if ["SkiErg", "RowErg"].contains(name) {
                distanceField
            }
            
            if ["Burpees Broad Jump", "Wall Balls"].contains(name) {
                repetitionsField
            }
        }
    }
    
    // Champ de distance
    private var distanceField: some View {
        HStack {
            Text("Distance:")
                .foregroundColor(.white)
            
            TextField("Mètres", value: $distance, format: .number)
                .keyboardType(.numberPad)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .foregroundColor(.white)
        }
        .padding(.horizontal)
    }
    
    // Champ de répétitions
    private var repetitionsField: some View {
        HStack {
            Text("Répétitions:")
                .foregroundColor(.white)
            
            TextField("Nombre", value: $repetitions, format: .number)
                .keyboardType(.numberPad)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .foregroundColor(.white)
        }
        .padding(.horizontal)
    }
    
    // Bouton terminer
    private var finishButton: some View {
        Button(action: {
            // Enregistrer l'exercice
            viewModel.completeExercise(
                duration: duration,
                distance: distance,
                repetitions: repetitions
            )
            presentationMode.wrappedValue.dismiss()
        }) {
            Text("TERMINER")
                .font(.headline)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.yellow)
                .cornerRadius(8)
        }
        .padding(.horizontal)
    }
    
    // Fonctions pour les actions
    private func toggleTimer() {
        if isTimerRunning {
            // Arrêter le timer
            isTimerRunning = false
        } else {
            // Démarrer le timer
            isTimerRunning = true
            startTime = Date()
            startTimerUpdates()
        }
    }
    
    private func resetTimer() {
        // Réinitialiser le timer
        duration = 0
        isTimerRunning = false
        startTime = nil
    }
    
    private func startTimerUpdates() {
        // Timer pour mettre à jour la durée
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if isTimerRunning, let start = startTime {
                duration = Date().timeIntervalSince(start)
            } else {
                timer.invalidate()
            }
        }
    }
}

struct WorkoutView_Previews: PreviewProvider {
    static var previews: some View {
        let persistenceController = PersistenceController(inMemory: true)
        let workoutManager = WorkoutManager(persistenceController: persistenceController)
        let viewModel = WorkoutViewModel(workoutManager: workoutManager)
        
        return WorkoutView(viewModel: viewModel)
            .preferredColorScheme(.dark)
            .environment(\.managedObjectContext, persistenceController.container.viewContext)
    }
}
