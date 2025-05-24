import Foundation
import CoreData
import Combine

@MainActor
class WorkoutViewModel: ObservableObject {
    // MARK: - Inputs
    @Published var selectedExercise: Exercise?
    @Published var isEditingExercise: Bool = false

    // MARK: - Outputs
    @Published private(set) var currentExercises: [Exercise] = []
    @Published private(set) var workoutProgress: Double = 0
    @Published private(set) var elapsedTime: TimeInterval = 0
    @Published private(set) var isActive: Bool = false
    @Published private(set) var templates: [WorkoutTemplate] = []

    // MARK: - Dependencies
    let workoutManager: WorkoutManager
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init
    init(workoutManager: WorkoutManager) {
        self.workoutManager = workoutManager

        // Observer l'état courant, l'activation et le temps écoulé
        Publishers.CombineLatest3(
            workoutManager.$currentWorkout,
            workoutManager.$isWorkoutActive,
            workoutManager.$elapsedTime
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] workout, active, elapsed in
            guard let self = self else { return }
            self.isActive = active
            self.elapsedTime = elapsed

            if active, let w = workout {
                self.currentExercises = w.orderedExercises
                self.updateProgress(for: w)
            } else {
                self.currentExercises = []
                self.workoutProgress = 0
            }
        }
        .store(in: &cancellables)
        
        // Observer les notifications de nouveaux templates
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNewTemplate),
            name: NSNotification.Name("WorkoutTemplateReceived"),
            object: nil
        )
        
        // Charger les templates et les workouts
        loadTemplates()
        reloadWorkouts()
    }

    @objc private func handleNewTemplate() {
        print("🔵 WorkoutViewModel - Nouveau template reçu")
        loadTemplates()
    }

    // MARK: - Actions
    func startWorkout(from template: WorkoutTemplate? = nil) {
        print("🔵 WorkoutViewModel - startWorkout appelé")
        
        // Réinitialiser l'état
        currentExercises = []
        workoutProgress = 0
        elapsedTime = 0
        isActive = false
        
        if let template = template {
            print("🔵 WorkoutViewModel - Démarrage avec template: \(template.name ?? "Sans nom")")
            workoutManager.startWorkoutFromTemplate(template)
        } else {
            print("🔵 WorkoutViewModel - Démarrage sans template")
            workoutManager.startNewWorkout()
        }
        
        // Attendre que le workout soit initialisé
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            print("🔵 WorkoutViewModel - Vérification après délai")
            print("🔵 WorkoutViewModel - Workout démarré, currentWorkout: \(self.workoutManager.currentWorkout?.id?.uuidString ?? "nil")")
            print("🔵 WorkoutViewModel - isActive: \(self.workoutManager.isWorkoutActive)")
            print("🔵 WorkoutViewModel - Nombre d'exercices: \(self.workoutManager.currentWorkout?.exercises?.count ?? 0)")
            
            // Forcer la mise à jour de l'UI
            self.objectWillChange.send()
            
            // Sauvegarder et synchroniser
            self.saveAndSync(self.workoutManager.currentWorkout)
        }
    }
    
    func createTemplate(name: String, description: String, exercises: [String]) {
        print("🔵 WorkoutViewModel - createTemplate appelé")
        let context = DataController.shared.container.viewContext
        let template = WorkoutTemplate(context: context)
        template.id = UUID()
        template.name = name
        template.workoutDescription = description
        template.createdAt = Date()
        template.isPublic = false
        
        // Calculer la durée estimée
        var totalDuration: TimeInterval = 0
        for exerciseName in exercises {
            if let def = ExerciseDefinitions.all[exerciseName] {
                totalDuration += def.targetTime ?? 0
            }
        }
        template.estimatedDuration = totalDuration
        
        // Ajouter les exercices
        for (index, exerciseName) in exercises.enumerated() {
            let exerciseTemplate = ExerciseTemplate(context: context)
            exerciseTemplate.id = UUID()
            exerciseTemplate.name = exerciseName
            exerciseTemplate.order = Int16(index)
            exerciseTemplate.workoutTemplate = template
            
            if let def = ExerciseDefinitions.all[exerciseName] {
                exerciseTemplate.defaultDuration = def.targetTime ?? 0
                exerciseTemplate.defaultDistance = def.standardDistance ?? 0
                exerciseTemplate.defaultRepetitions = Int16(def.standardRepetitions ?? 0)
                exerciseTemplate.exerciseDescription = def.description
            }
        }
        
        // Sauvegarder et synchroniser
        DataController.shared.saveContext()
        DataSyncManager.shared.sendWorkoutTemplate(template)
        loadTemplates()
        print("🔵 WorkoutViewModel - Template créé: \(template.id?.uuidString ?? "nil")")
    }

    func endWorkout() {
        print("🔵 WorkoutViewModel - endWorkout appelé")
        workoutManager.endWorkout()
        saveAndSync()
    }

    func forceRefresh() {
        print("🔵 WorkoutViewModel - forceRefresh appelé")
        objectWillChange.send()
        loadTemplates()
        reloadWorkouts()
    }
    
    func reloadWorkouts() {
        print("🔵 WorkoutViewModel - reloadWorkouts appelé")
        workoutManager.loadWorkouts()
        objectWillChange.send() // Force UI update
        print("🔄 WorkoutViewModel rechargé: \(workouts.count) workouts")
    }
    
    private func loadTemplates() {
        print("🔵 WorkoutViewModel - loadTemplates appelé")
        let context = DataController.shared.container.viewContext
        let request: NSFetchRequest<WorkoutTemplate> = WorkoutTemplate.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \WorkoutTemplate.createdAt, ascending: false)]
        do {
            templates = try context.fetch(request)
            print("🔵 WorkoutViewModel - Templates chargés: \(templates.count)")
        } catch {
            print("Erreur chargement templates: \(error)")
        }
    }
    
    func saveAndSync(_ workout: Workout? = nil) {
        print("🔵 WorkoutViewModel - saveAndSync appelé")
        // Sauvegarder dans Core Data
        DataController.shared.saveContext()
        
        // Synchroniser avec l'autre appareil
        if let workout = workout {
            // Si un workout spécifique est fourni
            DataSyncManager.shared.sendWorkout(workout)
            print("🔵 WorkoutViewModel - Workout synchronisé: \(workout.id?.uuidString ?? "nil")")
        } else if let currentWorkout = workoutManager.currentWorkout {
            // Utiliser le workout actuel du manager
            DataSyncManager.shared.sendWorkout(currentWorkout)
            print("🔵 WorkoutViewModel - Workout actuel synchronisé: \(currentWorkout.id?.uuidString ?? "nil")")
        }
    }
    
    func completeExercise(exercise: Exercise, duration: TimeInterval, distance: Double, repetitions: Int) {
        exercise.duration = duration
        exercise.distance = distance
        exercise.repetitions = Int16(repetitions)
        
        // Sauvegarder et synchroniser le workout parent
        if let workout = exercise.workout {
            saveAndSync(workout)
        } else {
            DataController.shared.saveContext()
        }
    }

    // MARK: - Helpers
    func isExerciseCompleted(_ exercise: Exercise) -> Bool {
        return exercise.duration > 0
    }

    private func updateProgress(for workout: Workout) {
        let exercises = workout.orderedExercises
        guard !exercises.isEmpty else {
            workoutProgress = 0
            return
        }
        let done = exercises.filter { $0.duration > 0 }.count
        workoutProgress = Double(done) / Double(exercises.count) * 100
    }

    func formatTime(_ seconds: TimeInterval) -> String {
        TimeFormatter.formatTime(seconds)
    }
    
    func select(_ exercise: Exercise) {
        selectedExercise = exercise
        isEditingExercise = true
    }
    
    func isNext(_ exercise: Exercise) -> Bool {
        guard let workout = workoutManager.currentWorkout else { return false }
        return workout.orderedExercises.first(where: { $0.duration <= 0 })?.id == exercise.id
    }

    // MARK: - Preview Helpers
    #if DEBUG
    func setPreviewTemplates(_ templates: [WorkoutTemplate]) {
        self.templates = templates
    }
    #endif

    // MARK: - Exposés pour la Watch
    var workouts: [Workout] {
        workoutManager.workouts
    }

    var personalBests: [String: Exercise] {
        workoutManager.personalBests
    }
}
