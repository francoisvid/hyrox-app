// Views/WorkoutView.swift

import SwiftUI

struct WorkoutView: View {
    @ObservedObject var viewModel: WorkoutViewModel

    var body: some View {
        NavigationView {
            Group {
                if viewModel.isActive {
                    ActiveWorkoutView(viewModel: viewModel)
                } else {
                    StartWorkoutView(viewModel: viewModel)
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Entraînement")
            .navigationBarTitleDisplayMode(.large)
            // Présentation de la feuille de détail d'exercice
            .sheet(item: $viewModel.selectedExercise) { exercise in
                ExerciseDetailView(exercise: exercise, viewModel: viewModel)
            }
        }
    }
}

// MARK: - Active Workout

private struct ActiveWorkoutView: View {
    @ObservedObject var viewModel: WorkoutViewModel

    var body: some View {
        VStack(spacing: 16) {
            // Timer + Stop
            HStack {
                Text(viewModel.formatTime(viewModel.elapsedTime))
                    .font(.system(size: 45, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Button {
                    viewModel.endWorkout()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.title)
                        .foregroundColor(.red)
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal)

            // Liste des exercices
            List {
                ForEach(viewModel.currentExercises, id: \.id) { exercise in
                    ExerciseRow(
                        exercise: exercise,
                        isCurrent: viewModel.isNext(exercise),
                        duration: viewModel.formatTime(exercise.duration)
                    ) {
                        viewModel.select(exercise)
                    }
                }
            }
            .listStyle(PlainListStyle())
        }
    }
}

private struct ExerciseRow: View {
    let exercise: Exercise
    let isCurrent: Bool
    let duration: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(exercise.name ?? "")
                    .foregroundColor(isCurrent ? .yellow : .white)
                Spacer()
                Text(duration)
                    .foregroundColor(.white)
                if isCurrent {
                    Image(systemName: "play.circle.fill")
                        .foregroundColor(.yellow)
                }
            }
            .padding(.vertical, 8)
        }
        .listRowBackground(isCurrent ? Color(.systemGray5) : Color.clear)
    }
}

private struct ExerciseDetailView: View {
    let exercise: Exercise
    @ObservedObject var viewModel: WorkoutViewModel
    @Environment(\.presentationMode) var presentationMode

    @State private var duration: TimeInterval = 0
    @State private var distance: Double = 0
    @State private var repetitions: Int = 0
    @State private var isTimerRunning = false
    @State private var startTime: Date?

    // Nom de l'exercice avec gestion de nil
    private var exerciseName: String {
        exercise.name ?? "Exercice"
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

                // Afficher les champs pertinents selon le type
                exerciseFields

                Spacer()

                finishButton
            }
            .padding()
            .background(Color.black.ignoresSafeArea())
            .navigationBarItems(trailing:
                Button("Fermer") {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(.yellow)
            )
        }
        .onAppear {
            // Initialiser les champs depuis l’exercice existant
            duration = exercise.duration
            distance = exercise.distance
            repetitions = Int(exercise.repetitions)
        }
    }

    // MARK: - Contrôles du timer

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

    // MARK: - Champs de données

    @ViewBuilder
    private var exerciseFields: some View {
        if let name = exercise.name {
            if ["SkiErg", "RowErg"].contains(name) {
                distanceField
            }
            if ["Burpees Broad Jump", "Wall Balls"].contains(name) {
                repetitionsField
            }
        }
    }

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

    // MARK: - Bouton terminer

    private var finishButton: some View {
        Button(action: {
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

    // MARK: - Fonctions timer

    private func toggleTimer() {
        if isTimerRunning {
            isTimerRunning = false
        } else {
            isTimerRunning = true
            startTime = Date()
            startTimerUpdates()
        }
    }

    private func resetTimer() {
        duration = 0
        isTimerRunning = false
        startTime = nil
    }

    private func startTimerUpdates() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if isTimerRunning, let start = startTime {
                duration = Date().timeIntervalSince(start)
            } else {
                timer.invalidate()
            }
        }
    }
}


// MARK: - Start Workout

private struct StartWorkoutView: View {
    @ObservedObject var viewModel: WorkoutViewModel

    var body: some View {
        VStack(spacing: 24) {
            Text("Exercices Hyrox")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.top)

            List {
                ForEach(Array(ExerciseDefinitions.all.values), id: \.name) { def in
                    HStack {
                        Text(def.name)
                            .foregroundColor(.white)
                        Spacer()
                        Text(def.description)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(PlainListStyle())

            Button("DÉMARRER L'ENTRAÎNEMENT") {
                viewModel.startWorkout()
            }
            .font(.headline)
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.yellow)
            .cornerRadius(8)
            .padding(.horizontal)
        }
    }
}
