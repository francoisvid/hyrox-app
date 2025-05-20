import Foundation
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

    // MARK: - Dependencies
    private let workoutManager: WorkoutManager
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
            self.elapsedTime     = elapsed

            if active, let w = workout {
                self.currentExercises = w.orderedExercises
                self.updateProgress(for: w)
            } else {
                self.currentExercises = []
                self.workoutProgress  = 0
            }
        }
        .store(in: &cancellables)
    }

    // MARK: - Actions
    func startWorkout() {
        workoutManager.startNewWorkout()
        saveAndSync(workoutManager.currentWorkout)
    }

    func endWorkout() {
        workoutManager.endWorkout()
        saveAndSync()
    }

    func reloadWorkouts() {
        workoutManager.loadWorkouts()
    }
    
    func saveAndSync(_ workout: Workout? = nil) {
        // Sauvegarder dans Core Data
        DataController.shared.saveContext()
        
        // Synchroniser avec l'autre appareil
        if let workout = workout {
            // Si un workout spécifique est fourni
            DataSyncManager.shared.sendWorkout(workout)
        } else if let currentWorkout = workoutManager.currentWorkout {
            // Utiliser le workout actuel du manager
            DataSyncManager.shared.sendWorkout(currentWorkout)
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
        selectedExercise   = exercise
        isEditingExercise  = true
    }
    
    func isNext(_ exercise: Exercise) -> Bool {
        guard let workout = workoutManager.currentWorkout else { return false }
        return workout.orderedExercises.first(where: { $0.duration <= 0 })?.id == exercise.id
    }

    // MARK: - Exposés pour la Watch

    var workouts: [Workout] {
        workoutManager.workouts
    }

    var personalBests: [String: Exercise] {
        workoutManager.personalBests
    }
}
