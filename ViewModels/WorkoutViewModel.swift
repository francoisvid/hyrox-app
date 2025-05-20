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

        // Observe workout state and elapsed time
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
    }

    // MARK: - Actions
    func startWorkout() {
        workoutManager.startNewWorkout()
    }

    func endWorkout() {
        workoutManager.endWorkout()
    }

    func select(_ exercise: Exercise) {
        selectedExercise = exercise
        isEditingExercise = true
    }

    func completeExercise(duration: TimeInterval,
                          distance: Double = 0,
                          repetitions: Int = 0) {
        guard let ex = selectedExercise else { return }
        workoutManager.updateExercise(
            id: ex.id ?? UUID(),
            duration: duration,
            distance: distance,
            repetitions: Int16(repetitions)
        )
        selectedExercise = nil
        isEditingExercise = false
    }

    // MARK: - Progress
    private func updateProgress(for workout: Workout) {
        let exercises = workout.orderedExercises
        guard !exercises.isEmpty else {
            workoutProgress = 0
            return
        }
        let done = exercises.filter { $0.duration > 0 }.count
        workoutProgress = Double(done) / Double(exercises.count) * 100
    }

    // MARK: - Helpers
    func isNext(_ exercise: Exercise) -> Bool {
        guard let workout = workoutManager.currentWorkout else { return false }
        let next = workout.orderedExercises.first { $0.duration <= 0 }
        return exercise.id == next?.id
    }

    var estimatedRemainingTime: TimeInterval {
        guard let workout = workoutManager.currentWorkout else { return 0 }
        return workout.orderedExercises
            .filter { $0.duration <= 0 }
            .reduce(0) { $0 + ($1.targetTime) }
    }

    var estimatedTotalTime: TimeInterval {
        guard let workout = workoutManager.currentWorkout else { return 0 }
        let done = workout.orderedExercises
            .filter { $0.duration > 0 }
            .reduce(0) { $0 + $1.duration }
        return done + estimatedRemainingTime
    }
    
    /// Liste de tous les workouts (directement depuis le manager)
    var workouts: [Workout] {
        workoutManager.workouts
    }

    /// Records personnels (idem)
    var personalBests: [String: Exercise] {
        workoutManager.personalBests
    }
    
    func formatTime(_ seconds: TimeInterval) -> String {
        TimeFormatter.formatTime(seconds)
    }
}
