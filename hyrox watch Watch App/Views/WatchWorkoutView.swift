import SwiftUI
import CoreData
import WatchConnectivity

struct WatchWorkoutView: View {
    @ObservedObject var viewModel: WorkoutViewModel

    @State private var currentExerciseIndex = 0
    @State private var showingExerciseDetail = false
    @State private var selectedExercise: Exercise?

    @State private var debugMessage: String = ""
    @State private var showDebug: Bool = false

    @State private var exerciseDuration: TimeInterval = 0
    @State private var exerciseDistance: Double = 0
    @State private var exerciseRepetitions: Int = 0
    @State private var isTimerRunning = false
    @State private var startTime: Date?
    @State private var timer: Timer?
    
    @State private var showSyncStatus: Bool = false


    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if showingExerciseDetail, let exercise = selectedExercise {
                    exerciseDetailView(exercise: exercise)
                } else if viewModel.isActive {
                    activeWorkoutView
                } else {
                    startWorkoutView
                }
            }
            .padding(.horizontal, 8)
        }
        .background(Color.black)
        .onAppear {
            viewModel.reloadWorkouts()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: .NSManagedObjectContextDidSave,
                object: DataController.shared.container.viewContext
            )
        ) { _ in
            viewModel.reloadWorkouts()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }

    // MARK: - Start Screen

    private var startWorkoutView: some View {
        VStack(spacing: 15) {
            Text("Hyrox")
                .font(.title2).bold()
                .foregroundColor(Color.white)
            
            // Ajout du compteur de workouts
            Text("\(viewModel.workouts.count) workouts enregistrés")
                .font(.subheadline)
                .foregroundColor(Color.cyan)
            
            // Hardcoded count if ExerciseConfig isn't available
            Text("8 exercices")
                .font(.subheadline)
                .foregroundColor(Color.secondary)
            
            // Status de synchronisation
//            Button(action: { showSyncStatus.toggle() }) {
//                Text("Sync Info")
//                    .font(.caption)
//                    .foregroundColor(.gray)
//            }
            
//            if showSyncStatus {
//                VStack(alignment: .leading, spacing: 2) {
//                    Text("Session: \(WCSession.default.activationState.rawValue)")
//                    Text("Reachable: \(WCSession.default.isReachable ? "✅" : "❌")")
//                    Text("Companion: \(WCSession.default.isCompanionAppInstalled ? "✅" : "❌")")
//                    
//                    // Bouton pour forcer un message test
//                    Button("Force Test Message") {
//                        DataSyncManager.shared.forceSendTestMessage()
//                    }
//                    .font(.system(size: 10))
//                    .padding(3)
//                    .background(Color.blue.opacity(0.5))
//                    .cornerRadius(4)
//                }
//                .font(.system(size: 9))
//                .foregroundColor(.gray)
//                .padding(5)
//                .background(Color.black.opacity(0.5))
//                .cornerRadius(5)
//            }
//            
//            if showDebug {
//                Text(debugMessage)
//                    .font(.caption)
//                    .foregroundColor(.green)
//                    .padding()
//                    .background(Color.black.opacity(0.8))
//                    .cornerRadius(8)
//            }
//            
//            Button("🚀 DIRECT") {
//                sendDirectTestData()
//            }
//            
//            Button("🧪 TEST") {
//                createTestWorkout()
//            }
            
//            Button("📊 FORCE SYNC") {
//                DataSyncManager.shared.forceSendAllWorkouts()
//            }
//            
//            if showDebug {
//                Text(debugMessage)
//                    .font(.caption)
//                    .foregroundColor(.green)
//                    .frame(maxWidth: .infinity, alignment: .leading)
//                    .padding(5)
//                    .background(Color.black.opacity(0.8))
//                    .cornerRadius(8)
//            }
            
            Button("DÉMARRER") {
                let newWorkout: () = viewModel.startWorkout()
                viewModel.saveAndSync()
                currentExerciseIndex = 0
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.yellow)
            .foregroundColor(Color.black)
            
            Button("🧹 EFFACER TOUT") {
                clearAllData()
            }
            .foregroundColor(.red)
        }
    }

    // MARK: - Active Workout

    private var activeWorkoutView: some View {
        VStack(spacing: 15) {
            Text(viewModel.formatTime(viewModel.elapsedTime))
                .font(.title2).bold()
                .foregroundColor(Color.white)
            
            Button("Arrêter") {
                viewModel.endWorkout()
                viewModel.saveAndSync()
            }
            .buttonStyle(.bordered)
            .tint(Color.red)
            
            let exercises = viewModel.currentExercises
            if currentExerciseIndex < exercises.count {
                currentExerciseCard(for: exercises[currentExerciseIndex])
            }
        }
    }

    private func currentExerciseCard(for exercise: Exercise) -> some View {
        VStack(spacing: 10) {
            Text("\(currentExerciseIndex + 1)/\(viewModel.currentExercises.count)")
                .font(.caption)
                .foregroundColor(Color.secondary)

            Text(exercise.name ?? "Exercice")
                .font(.headline)
                .foregroundColor(Color.white)
                .minimumScaleFactor(0.8)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            
            // Afficher l'objectif
            if let name = exercise.name {
                let goal = GoalsManager.shared.getGoalFor(exerciseName: name)
                if goal > 0 {
                    Text("Objectif: \(formatTime(goal))")
                        .font(.caption)
                        .foregroundColor(Color.yellow)
                }
            }

            if viewModel.isExerciseCompleted(exercise) {
                Text("✓ Terminé")
                    .font(.caption)
                    .foregroundColor(Color.green)
            }

            VStack(spacing: 8) {
                Button {
                    selectedExercise = exercise
                    resetExerciseData()
                    showingExerciseDetail = true
                } label: {
                    Text(viewModel.isExerciseCompleted(exercise) ? "MODIFIER" : "DÉMARRER")
                        .font(.caption).bold()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.yellow)
                .foregroundColor(Color.black)

                HStack(spacing: 20) {
                    if currentExerciseIndex > 0 {
                        Button {
                            withAnimation { currentExerciseIndex -= 1 }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                    }
                    if currentExerciseIndex < viewModel.currentExercises.count - 1 {
                        Button {
                            withAnimation { currentExerciseIndex += 1 }
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .tint(Color.green)
                    } else if viewModel.isExerciseCompleted(exercise) {
                        Button("FIN") {
                            viewModel.endWorkout()
                            viewModel.saveAndSync()
                        }
                        .buttonStyle(.bordered)
                        .tint(Color.red)
                    }
                }
            }
        }
        .padding(12)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(10)
    }

    // MARK: - Exercise Detail

    private func exerciseDetailView(exercise: Exercise) -> some View {
        VStack(spacing: 15) {
            HStack {
                Button("← Retour") {
                    showingExerciseDetail = false
                    timer?.invalidate()
                    timer = nil
                }
                .buttonStyle(.bordered)
                .tint(Color.gray)
                Spacer()
            }

            Text(exercise.name ?? "Exercice")
                .font(.headline).bold()
                .foregroundColor(Color.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            // Afficher le temps actuel avec la couleur appropriée
            if let name = exercise.name {
                let goal = GoalsManager.shared.getGoalFor(exerciseName: name)
                if goal > 0 {
                    VStack(spacing: 4) {
                        Text(formatTimeWithMilliseconds(exerciseDuration))
                            .font(.title).bold()
                            .foregroundColor(getTimeColor(current: exerciseDuration, goal: goal))
                        
                        Text("Objectif: \(formatTime(goal))")
                            .font(.caption)
                            .foregroundColor(.yellow)
                        
                        // Afficher la différence
                        let difference = exerciseDuration - goal
                        if difference != 0 {
                            Text(difference > 0 ? "+\(formatTime(difference))" : formatTime(difference))
                                .font(.caption)
                                .foregroundColor(difference > 0 ? .red : .green)
                        }
                    }
                } else {
                    Text(formatTimeWithMilliseconds(exerciseDuration))
                        .font(.title).bold()
                        .foregroundColor(.white)
                }
            }

            HStack(spacing: 15) {
                Button(action: toggleTimer) {
                    Image(systemName: isTimerRunning ? "pause.fill" : "play.fill")
                        .font(.title3)
                }
                .buttonStyle(.bordered)
                .tint(isTimerRunning ? Color.red : Color.green)

                Button(action: resetTimer) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.title3)
                }
                .buttonStyle(.bordered)
                .tint(Color.yellow)
            }

            exerciseSpecificFields(for: exercise)

            Button("TERMINER") {
                viewModel.completeExercise(
                    exercise: exercise,
                    duration: exerciseDuration,
                    distance: exerciseDistance,
                    repetitions: exerciseRepetitions
                )
                showingExerciseDetail = false
                resetExerciseData()
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.yellow)
            .foregroundColor(Color.black)
        }
        .padding(12)
    }

    @ViewBuilder
    private func exerciseSpecificFields(for exercise: Exercise) -> some View {
        if let name = exercise.name {
            if name == "SkiErg" || name == "RowErg" {
                VStack(spacing: 8) {
                    Text("Distance (m)")
                        .font(.caption)
                        .foregroundColor(Color.secondary)

                    // No keyboardType on watchOS
                    TextField("0", value: $exerciseDistance, format: .number)
                        .padding(8)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                        .multilineTextAlignment(.center)
                }
            }
            if name == "Burpees Broad Jump" || name == "Wall Balls" {
                VStack(spacing: 8) {
                    Text("Répétitions")
                        .font(.caption)
                        .foregroundColor(Color.secondary)

                    TextField("0", value: $exerciseRepetitions, format: .number)
                        .padding(8)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }

    // MARK: - Utilities

    private func createTestWorkout() {
        debugMessage = "Création workout avec envoi..."
        showDebug = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let ctx = DataController.shared.container.viewContext
            
            // Créer un workout avec des attributs explicites
            let w = Workout(context: ctx)
            w.id = UUID()
            w.name = "TEST DIRECT \(Int(Date().timeIntervalSince1970))"
            w.date = Date()
            w.duration = Double.random(in: 100...999)
            w.completed = true
            
            // Sauvegarder et synchroniser
            self.viewModel.saveAndSync(w)
            
            self.debugMessage = "✅ Workout créé et synchronisé!"
        }
    }

    private func resetExerciseData() {
        exerciseDuration = 0
        exerciseDistance = 0
        exerciseRepetitions = 0
        isTimerRunning = false
        startTime = nil
        timer?.invalidate()
        timer = nil
    }

    private func toggleTimer() {
        if isTimerRunning {
            isTimerRunning = false
            timer?.invalidate()
        } else {
            isTimerRunning = true
            startTime = Date()
            startTimer()
        }
    }

    private func resetTimer() {
        exerciseDuration = 0
        isTimerRunning = false
        startTime = nil
        timer?.invalidate()
        timer = nil
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if isTimerRunning, let start = startTime {
                exerciseDuration = Date().timeIntervalSince(start)
            }
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let m = Int(time) / 60
        let s = Int(time) % 60
        return String(format: "%02d:%02d", m, s)
    }
    
    private func formatTimeWithMilliseconds(_ time: TimeInterval) -> String {
        let m = Int(time) / 60
        let s = Int(time) % 60
        let cs = Int((time.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d.%02d", m, s, cs)
    }
    
    private func getTimeColor(current: TimeInterval, goal: TimeInterval) -> Color {
        let percentage = current / goal
        switch percentage {
        case ..<0.8:  // Moins de 80% du temps objectif
            return .green
        case 0.8..<1.0:  // Entre 80% et 100% du temps objectif
            return .orange
        default:  // Plus de 100% du temps objectif
            return .red
        }
    }
    
    // TODO : TEST
    
    func clearAllData() {
        debugMessage = "Suppression de toutes les données..."
        showDebug = true
        
        // Appeler la méthode de DataController
        DataController.shared.clearAllData()
        
        // Recharger les données dans le ViewModel
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.viewModel.reloadWorkouts()
            self.debugMessage = "✅ Toutes les données ont été effacées"
            
            // Masquer le message après quelques secondes
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.showDebug = false
            }
        }
    }

    // Nouvelle fonction pour envoyer des données explicitement
    private func sendDirectTestData() {
        debugMessage = "Envoi direct de données de test..."
        showDebug = true
        
        // Créer un nouveau workout dans Core Data
        let ctx = DataController.shared.container.viewContext
        let newWorkout = Workout(context: ctx)
        newWorkout.id = UUID()
        newWorkout.name = "TEST DIRECT \(Int(Date().timeIntervalSince1970))"
        newWorkout.date = Date()
        newWorkout.duration = Double.random(in: 100...999)
        newWorkout.completed = true
        
        // Sauvegarder
        do {
            try ctx.save()
            debugMessage += "\nWorkout créé et sauvegardé"
        } catch {
            debugMessage += "\nErreur sauvegarde: \(error.localizedDescription)"
            return
        }
        
        // Créer un payload explicite pour l'envoi
        let workoutData: [String: Any] = [
            "id": newWorkout.id?.uuidString ?? "unknown",
            "name": newWorkout.name ?? "unnamed",
            "date": newWorkout.date?.timeIntervalSince1970 ?? 0,
            "duration": newWorkout.duration,
            "completed": newWorkout.completed
        ]
        
        // Message complet
        let directMessage: [String: Any] = [
            "history": [
                [
                    "entity": "Workout",
                    "id": newWorkout.id?.uuidString ?? "unknown",
                    "type": 0, // Insert
                    "values": workoutData
                ]
            ]
        ]
        
        // Envoyer avec la méthode la plus directe
        WCSession.default.sendMessage(
            directMessage,
            replyHandler: { reply in
                DispatchQueue.main.async {
                    self.debugMessage += "\n✅ Message envoyé, réponse: \(reply)"
                }
            },
            errorHandler: { error in
                DispatchQueue.main.async {
                    self.debugMessage += "\n❌ Erreur: \(error.localizedDescription)"
                    
                    // Essayer une autre méthode
                    WCSession.default.transferUserInfo(directMessage)
                    self.debugMessage += "\nTenté avec transferUserInfo"
                }
            }
        )
    }
}
#Preview {
    // Utiliser une fonction séparée pour créer tous les objets nécessaires
    let previewSetup = setupPreview()
    
    return WatchWorkoutView(viewModel: previewSetup.viewModel)
        .environment(\.managedObjectContext, previewSetup.context)
}

// Fonction auxiliaire pour créer les objets nécessaires
@MainActor func setupPreview() -> (viewModel: WorkoutViewModel, context: NSManagedObjectContext) {
    // Utiliser un DataController configuré pour le preview
    let previewDataController = DataController.shared
    previewDataController.container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
    
    let context = previewDataController.container.viewContext
    
    // Créer un WorkoutManager
    let workoutManager = WorkoutManager(dataController: previewDataController)
    
    // Créer un workout de démonstration
    let demoWorkout = Workout.create(name: "Preview Workout", date: Date(), in: context)
    
    // Ajouter quelques exercices simples
    demoWorkout.addExercise(name: "SkiErg")
    demoWorkout.addExercise(name: "Sled Push")
    
    // Sauvegarder
    try? context.save()
    
    // Créer le ViewModel
    let viewModel = WorkoutViewModel(workoutManager: workoutManager)
    
    return (viewModel, context)
}
