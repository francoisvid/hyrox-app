import SwiftUI
import CoreData
import WatchConnectivity

struct WatchWorkoutView: View {
    @ObservedObject var viewModel: WorkoutViewModel
    
    @State private var currentExerciseIndex = 0
    @State private var showingExerciseDetail = false
    @State private var selectedExercise: Exercise?
    
    @State private var exerciseDuration: TimeInterval = 0
    @State private var exerciseDistance: Double = 0
    @State private var exerciseRepetitions: Int = 0
    @State private var isTimerRunning = false
    @State private var startTime: Date?
    @State private var timer: Timer?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    if showingExerciseDetail, let exercise = selectedExercise {
                        exerciseDetailView(exercise: exercise)
                    } else if viewModel.isActive {
                        activeWorkoutView
                    } else {
                        startWorkoutView
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 20)
            }
            .background(Color.black)
            .navigationBarHidden(true)
        }
        .onAppear {
            viewModel.reloadWorkouts()
        }
        .onDisappear {
            timer?.invalidate()
        }
        // MARK: - Notifications
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SyncCompleted"))) { _ in
            handleSyncCompleted()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("WorkoutsDeleted"))) { _ in
            viewModel.reloadWorkouts()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("WorkoutDeleted"))) { _ in
            viewModel.reloadWorkouts()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("WorkoutReceived"))) { _ in
            viewModel.reloadWorkouts()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("WorkoutCompleted"))) { _ in
            viewModel.reloadWorkouts()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("WorkoutTemplateReceived"))) { _ in
            handleTemplateReceived()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave, object: DataController.shared.container.viewContext)) { _ in
            viewModel.reloadWorkouts()
        }
    }

    // MARK: - Helper Methods

    private func handleSyncCompleted() {
        print("⌚️ 🔄 Synchronisation terminée, mise à jour de l'UI")
        viewModel.reloadWorkouts()
        viewModel.loadTemplates()
        viewModel.objectWillChange.send()
    }

    private func handleTemplateReceived() {
        viewModel.loadTemplates()
        viewModel.objectWillChange.send()
    }
    
    // MARK: - Start Screen
    
    private var startWorkoutView: some View {
        VStack(spacing: 20) {
            // Header avec statistiques
            headerStatsView
            
            // Bouton de synchronisation
            syncButton
            
            // Templates disponibles
            if !viewModel.templates.isEmpty {
                templatesListView
            } else {
                emptyStateView
            }
        }
    }

    private var syncButton: some View {
        Button(action: performSync) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14, weight: .bold))
                Text("SYNCHRONISER")
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.cyan)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func performSync() {
        print("⌚️ Démarrage synchronisation...")
        DataSyncManager.shared.syncAllFromiPhone()
        
        // Forcer le rechargement après un délai
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            print("⌚️ Rechargement forcé des données...")
            viewModel.reloadWorkouts()
            viewModel.loadTemplates()
            viewModel.objectWillChange.send()
        }
    }
    
    private var headerStatsView: some View {
        VStack(spacing: 8) {
            Text("WORKOUTS")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.yellow)
            
            Text("\(viewModel.workouts.count)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text("séances terminées")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.3))
        )
    }
    
    private var templatesListView: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Templates")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Text("\(viewModel.templates.count)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.cyan)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.cyan.opacity(0.2))
                    .clipShape(Capsule())
            }
            
            ForEach(viewModel.templates.prefix(3)) { template in
                modernTemplateCard(template: template)
            }
            
            if viewModel.templates.count > 3 {
                Text("et \(viewModel.templates.count - 3) autres...")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .padding(.top, 4)
            }
        }
    }
    
    private func modernTemplateCard(template: WorkoutTemplate) -> some View {
        VStack(spacing: 10) {
            // Header du template
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.name ?? "Sans nom")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    if let exercises = template.exercises as? Set<ExerciseTemplate> {
                        Text("\(exercises.count) exercices")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.cyan)
                    }
                }
                
                Spacer()
                
                // Durée estimée
                if template.estimatedDuration > 0 {
                    VStack(spacing: 2) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.yellow)
                        Text("\(Int(template.estimatedDuration / 60))min")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.yellow)
                    }
                }
            }
            
            // Bouton de démarrage
            Button(action: {
                print("⌚️ Démarrage template:", template.name ?? "Sans nom")
                viewModel.startWorkout(from: template)
                currentExerciseIndex = 0
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text("DÉMARRER")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.yellow)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.2))
        )
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "dumbbell")
                .font(.system(size: 32))
                .foregroundColor(.gray)
            
            Text("Aucun template")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.gray)
            
            Text("Créez des templates sur votre iPhone")
                .font(.system(size: 12))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 30)
    }
    
    // MARK: - Active Workout
    
    private var activeWorkoutView: some View {
        VStack(spacing: 20) {
            // Timer principal
            workoutTimerView
            
            // Exercice actuel
            let exercises = viewModel.currentExercises
            if currentExerciseIndex < exercises.count {
                currentExerciseCardModern(for: exercises[currentExerciseIndex])
            }
            
            // Bouton d'arrêt
            stopWorkoutButton
        }
    }
    
    private var workoutTimerView: some View {
        VStack(spacing: 8) {
            Text("TEMPS TOTAL")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
            
            Text(viewModel.formatTime(viewModel.elapsedTime))
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .foregroundColor(.yellow)
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.2))
        )
    }
    
    private func currentExerciseCardModern(for exercise: Exercise) -> some View {
        VStack(spacing: 16) {
            // Header exercice
            VStack(spacing: 8) {
                Text("\(currentExerciseIndex + 1)/\(viewModel.currentExercises.count)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.cyan)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.cyan.opacity(0.2))
                    .clipShape(Capsule())
                
                Text(exercise.name ?? "Exercice")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            
            // Objectif et statut
            objectiveView(for: exercise)
            
            // Boutons d'action
            exerciseActionsView(for: exercise)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.2))
        )
    }
    
    private func objectiveView(for exercise: Exercise) -> some View {
        VStack(spacing: 8) {
            if let name = exercise.name {
                let goal = GoalsManager.shared.getGoalFor(exerciseName: name)
                if goal > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "target")
                            .font(.system(size: 12))
                            .foregroundColor(.yellow)
                        Text("Objectif: \(formatTime(goal))")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.yellow)
                    }
                }
            }
            
            if viewModel.isExerciseCompleted(exercise) {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.green)
                    Text("Terminé")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.green)
                }
            }
        }
    }
    
    private func exerciseActionsView(for exercise: Exercise) -> some View {
        VStack(spacing: 12) {
            // Bouton principal
            Button(action: {
                selectedExercise = exercise
                resetExerciseData()
                showingExerciseDetail = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: viewModel.isExerciseCompleted(exercise) ? "pencil" : "play.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text(viewModel.isExerciseCompleted(exercise) ? "MODIFIER" : "DÉMARRER")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.yellow)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(PlainButtonStyle())
            
            // Navigation
            HStack(spacing: 16) {
                if currentExerciseIndex > 0 {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            currentExerciseIndex -= 1
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.gray.opacity(0.3))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Spacer()
                
                if currentExerciseIndex < viewModel.currentExercises.count - 1 {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            currentExerciseIndex += 1
                        }
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.black)
                            .frame(width: 32, height: 32)
                            .background(Color.green)
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                } else if viewModel.isExerciseCompleted(exercise) {
                    Button(action: {
                        viewModel.endWorkout()
                        viewModel.saveAndSync()
                    }) {
                        Text("TERMINER")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.red)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
    
    private var stopWorkoutButton: some View {
        Button(action: {
            viewModel.endWorkout()
            viewModel.saveAndSync()
        }) {
            HStack(spacing: 8) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 12, weight: .bold))
                Text("ARRÊTER")
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.red)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Exercise Detail
    
    private func exerciseDetailView(exercise: Exercise) -> some View {
        VStack(spacing: 20) {
            // Header avec retour
            HStack {
                Button(action: {
                    showingExerciseDetail = false
                    timer?.invalidate()
                    timer = nil
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .bold))
                        Text("Retour")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.cyan)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
            }
            
            // Nom de l'exercice
            Text(exercise.name ?? "Exercice")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            
            // Timer avec objectif
            exerciseTimerView(for: exercise)
            
            // Contrôles du timer
            timerControlsView
            
            // Champs spécifiques
            exerciseSpecificFields(for: exercise)
            
            // Bouton terminer
            Button(action: {
                viewModel.completeExercise(
                    exercise: exercise,
                    duration: exerciseDuration,
                    distance: exerciseDistance,
                    repetitions: exerciseRepetitions
                )
                showingExerciseDetail = false
                resetExerciseData()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                    Text("TERMINER")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.yellow)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private func exerciseTimerView(for exercise: Exercise) -> some View {
        VStack(spacing: 12) {
            if let name = exercise.name {
                let goal = GoalsManager.shared.getGoalFor(exerciseName: name)
                if goal > 0 {
                    VStack(spacing: 8) {
                        Text(formatTimeWithMilliseconds(exerciseDuration))
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .foregroundColor(getTimeColor(current: exerciseDuration, goal: goal))
                        
                        Text("Objectif: \(formatTime(goal))")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.yellow)
                        
                        let difference = exerciseDuration - goal
                        if difference != 0 {
                            Text(difference > 0 ? "+\(formatTime(difference))" : formatTime(difference))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(difference > 0 ? .red : .green)
                        }
                    }
                } else {
                    Text(formatTimeWithMilliseconds(exerciseDuration))
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.2))
        )
    }
    
    private var timerControlsView: some View {
        HStack(spacing: 20) {
            Button(action: toggleTimer) {
                Image(systemName: isTimerRunning ? "pause.fill" : "play.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(isTimerRunning ? .white : .black)
                    .frame(width: 44, height: 44)
                    .background(isTimerRunning ? Color.red : Color.green)
                    .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
            
            Button(action: resetTimer) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.black)
                    .frame(width: 44, height: 44)
                    .background(Color.yellow)
                    .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private func distanceInputView() -> some View {
        VStack(spacing: 8) {
            Text("Distance (m)")
                .font(.system(size: 12, weight: .medium))
            
            TextField("0", value: $exerciseDistance, format: .number)
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .background(Color.gray.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func repetitionsInputView() -> some View {
        VStack(spacing: 8) {
            Text("Répétitions")
                .font(.system(size: 12, weight: .medium))
            
            TextField("0", value: $exerciseRepetitions, format: .number)
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .background(Color.gray.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // Et dans exerciseSpecificFields :
    @ViewBuilder
    private func exerciseSpecificFields(for exercise: Exercise) -> some View {
        if let name = exercise.name {
            VStack(spacing: 16) {
                if name == "SkiErg" || name == "RowErg" {
                    distanceInputView()
                }
                
                if name == "Burpees Broad Jump" || name == "Wall Balls" {
                    repetitionsInputView()
                }
            }
        }
    }
    
    private func inputFieldView(
        title: String,
        value: Binding<Double>,
        isInteger: Bool = false
    ) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
            
            if isInteger {
                TextField("0", value: Binding(
                    get: { Int(value.wrappedValue) },
                    set: { value.wrappedValue = Double($0) }
                ), format: .number)
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 12)
                    .background(Color.gray.opacity(0.3)) // Changé .fill par .background
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                TextField("0", value: value, format: .number)
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 12)
                    .background(Color.gray.opacity(0.3)) // Changé .fill par .background
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
    
    // MARK: - Utilities
    
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
        return String(format: "%02d:%02d", m, s)
    }
    
    private func getTimeColor(current: TimeInterval, goal: TimeInterval) -> Color {
        let percentage = current / goal
        switch percentage {
        case ..<0.8:
            return .green
        case 0.8..<1.0:
            return .orange
        default:
            return .red
        }
    }
}

// MARK: - Preview

#Preview {
    let previewSetup = setupPreview()
    return WatchWorkoutView(viewModel: previewSetup.viewModel)
        .environment(\.managedObjectContext, previewSetup.context)
}

@MainActor func setupPreview() -> (viewModel: WorkoutViewModel, context: NSManagedObjectContext) {
    let previewDataController = DataController.shared
    previewDataController.container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
    
    let context = previewDataController.container.viewContext
    let workoutManager = WorkoutManager(dataController: previewDataController)
    
    // Créer des templates de démonstration
    createDemoTemplates(in: context)
    
    // Créer quelques workouts historiques
    createDemoWorkouts(in: context)
    
    try? context.save()
    
    let viewModel = WorkoutViewModel(workoutManager: workoutManager)
    
    // Charger les templates dans le viewModel
    viewModel.loadTemplates()
    viewModel.reloadWorkouts()
    
    return (viewModel, context)
}

private func createDemoTemplates(in context: NSManagedObjectContext) {
    // Template 1: Hyrox Complet
    let hyroxTemplate = WorkoutTemplate(context: context)
    hyroxTemplate.id = UUID()
    hyroxTemplate.name = "Hyrox Complet"
    hyroxTemplate.workoutDescription = "Entraînement Hyrox complet avec tous les exercices"
    hyroxTemplate.estimatedDuration = 45 * 60 // 45 minutes
    hyroxTemplate.createdAt = Date()
    
    let hyroxExercises = [
        "SkiErg", "Sled Push", "Sled Pull", "Burpees Broad Jump",
        "RowErg", "Farmers Carry", "Sandbag Lunges", "Wall Balls"
    ]
    
    for (index, exerciseName) in hyroxExercises.enumerated() {
        let exerciseTemplate = ExerciseTemplate(context: context)
        exerciseTemplate.id = UUID()
        exerciseTemplate.name = exerciseName
        exerciseTemplate.order = Int16(index)
        exerciseTemplate.workoutTemplate = hyroxTemplate
    }
    
    // Template 2: Cardio Express
    let cardioTemplate = WorkoutTemplate(context: context)
    cardioTemplate.id = UUID()
    cardioTemplate.name = "Cardio Express"
    cardioTemplate.workoutDescription = "Session cardio rapide et intense"
    cardioTemplate.estimatedDuration = 20 * 60 // 20 minutes
    cardioTemplate.createdAt = Date()
    
    let cardioExercises = ["SkiErg", "RowErg", "Assault Bike", "Jump Rope"]
    
    for (index, exerciseName) in cardioExercises.enumerated() {
        let exerciseTemplate = ExerciseTemplate(context: context)
        exerciseTemplate.id = UUID()
        exerciseTemplate.name = exerciseName
        exerciseTemplate.order = Int16(index)
        exerciseTemplate.workoutTemplate = cardioTemplate
    }
    
    // Template 3: Force & Puissance
    let forceTemplate = WorkoutTemplate(context: context)
    forceTemplate.id = UUID()
    forceTemplate.name = "Force & Puissance"
    forceTemplate.workoutDescription = "Développement de la force et puissance"
    forceTemplate.estimatedDuration = 35 * 60 // 35 minutes
    forceTemplate.createdAt = Date()
    
    let forceExercises = [
        "Sled Push", "Sled Pull", "Farmers Carry", "Sandbag Lunges",
        "Wall Balls", "Deadlifts", "Box Jumps"
    ]
    
    for (index, exerciseName) in forceExercises.enumerated() {
        let exerciseTemplate = ExerciseTemplate(context: context)
        exerciseTemplate.id = UUID()
        exerciseTemplate.name = exerciseName
        exerciseTemplate.order = Int16(index)
        exerciseTemplate.workoutTemplate = forceTemplate
    }
    
    // Template 4: Session Courte
    let shortTemplate = WorkoutTemplate(context: context)
    shortTemplate.id = UUID()
    shortTemplate.name = "Session Courte"
    shortTemplate.workoutDescription = "Parfait pour un entraînement rapide"
    shortTemplate.estimatedDuration = 15 * 60 // 15 minutes
    shortTemplate.createdAt = Date()
    
    let shortExercises = ["Burpees", "Air Squats", "Push-ups"]
    
    for (index, exerciseName) in shortExercises.enumerated() {
        let exerciseTemplate = ExerciseTemplate(context: context)
        exerciseTemplate.id = UUID()
        exerciseTemplate.name = exerciseName
        exerciseTemplate.order = Int16(index)
        exerciseTemplate.workoutTemplate = shortTemplate
    }
    
    // Template 5: Core Training
    let coreTemplate = WorkoutTemplate(context: context)
    coreTemplate.id = UUID()
    coreTemplate.name = "Core Training"
    coreTemplate.workoutDescription = "Renforcement du centre du corps"
    coreTemplate.estimatedDuration = 25 * 60 // 25 minutes
    coreTemplate.createdAt = Date()
    
    let coreExercises = [
        "SkiErg", "Wall Balls", "Plank Hold", "Russian Twists", "Hanging Knee Raises",
        "Sit-ups", "Mountain Climbers"
    ]
    
    for (index, exerciseName) in coreExercises.enumerated() {
        let exerciseTemplate = ExerciseTemplate(context: context)
        exerciseTemplate.id = UUID()
        exerciseTemplate.name = exerciseName
        exerciseTemplate.order = Int16(index)
        exerciseTemplate.workoutTemplate = coreTemplate
    }
}

private func createDemoWorkouts(in context: NSManagedObjectContext) {
    // Workout 1: Terminé hier
    let workout1 = Workout.create(
        name: "Hyrox Morning",
        date: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
        in: context
    )
    workout1.duration = 42 * 60 + 30 // 42min 30s
    workout1.completed = true
    workout1.distance = 2400 // 2.4km
    
    workout1.addExercise(name: "SkiErg")
    workout1.addExercise(name: "Sled Push")
    workout1.addExercise(name: "RowErg")
    
    // Workout 2: Terminé il y a 3 jours
    let workout2 = Workout.create(
        name: "Cardio Session",
        date: Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date(),
        in: context
    )
    workout2.duration = 28 * 60 + 15 // 28min 15s
    workout2.completed = true
    workout2.distance = 1800 // 1.8km
    
    workout2.addExercise(name: "RowErg")
    workout2.addExercise(name: "Assault Bike")
    
    // Workout 3: Terminé la semaine dernière
    let workout3 = Workout.create(
        name: "Force Training",
        date: Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date(),
        in: context
    )
    workout3.duration = 35 * 60 + 45 // 35min 45s
    workout3.completed = true
    workout3.distance = 600 // 600m
    
    workout3.addExercise(name: "Farmers Carry")
    workout3.addExercise(name: "Wall Balls")
    workout3.addExercise(name: "Burpees Broad Jump")
    
    // Workout 4: Session courte
    let workout4 = Workout.create(
        name: "Quick HIIT",
        date: Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date(),
        in: context
    )
    workout4.duration = 18 * 60 + 30 // 18min 30s
    workout4.completed = true
    workout4.distance = 0
    
    workout4.addExercise(name: "Burpees")
    workout4.addExercise(name: "Mountain Climbers")
    
    // Workout 5: Session de cette semaine
    let workout5 = Workout.create(
        name: "Full Body",
        date: Calendar.current.date(byAdding: .day, value: -5, to: Date()) ?? Date(),
        in: context
    )
    workout5.duration = 52 * 60 + 20 // 52min 20s
    workout5.completed = true
    workout5.distance = 3200 // 3.2km
    
    workout5.addExercise(name: "SkiErg")
    workout5.addExercise(name: "Sled Push")
    workout5.addExercise(name: "Sled Pull")
    workout5.addExercise(name: "RowErg")
    workout5.addExercise(name: "Farmers Carry")
}
