import Foundation
import Combine

@MainActor
class StatsViewModel: ObservableObject {
    // MARK: - Inputs
    @Published var selectedPeriodIndex: Int = 0

    // MARK: - Outputs
    @Published private(set) var personalBests: [String: Exercise] = [:]
    @Published private(set) var chartData: [(Date, TimeInterval)] = []
    @Published private(set) var totalWorkouts: Int = 0
    @Published private(set) var totalTime: TimeInterval = 0
    @Published private(set) var totalDistance: Double = 0

    // MARK: - Dependencies
    private let workoutManager: WorkoutManager
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init
    init(workoutManager: WorkoutManager) {
        self.workoutManager = workoutManager

        // Recompute when workouts change
        workoutManager.$workouts
            .sink { [weak self] ws in self?.recompute(from: ws) }
            .store(in: &cancellables)

        // Update chart when period changes
        $selectedPeriodIndex
            .sink { [weak self] _ in self?.updateChart() }
            .store(in: &cancellables)
    }

    // MARK: - Computations
    private func recompute(from workouts: [Workout]) {
        personalBests = Self.computeBests(from: workouts)
        updateChart()
        updateTotals(from: workouts)
    }

    private static func computeBests(from workouts: [Workout]) -> [String: Exercise] {
        var bests: [String: Exercise] = [:]
        for w in workouts where w.completed {
            for ex in w.orderedExercises {
                guard let name = ex.name, ex.duration > 0 else { continue }
                if let current = bests[name] {
                    if ex.duration < current.duration { bests[name] = ex }
                } else {
                    bests[name] = ex
                }
            }
        }
        return bests
    }

    private func updateTotals(from workouts: [Workout]) {
        let completed = workouts.filter { $0.completed }
        totalWorkouts = completed.count
        totalTime = completed.reduce(0) { $0 + $1.duration }
        totalDistance = completed.reduce(0) { $0 + $1.distance }
    }
    
    // MARK: – Méthodes privées existantes
    /// Force le recalcul de tous les stats (pour pull-to-refresh ou bouton)
    @MainActor
    func reloadStats() {
        workoutManager.loadWorkouts()
    }

    private func updateChart() {
        let months = [3, 6, 12, 24].indices.contains(selectedPeriodIndex)
            ? [3, 6, 12, 24][selectedPeriodIndex]
            : 3
        chartData = workoutManager.getWorkoutStatistics(months: months)
    }

    // MARK: - Helpers
    var completedWorkouts: [Workout] {
        workoutManager.workouts.filter { $0.completed }
    }

    var topExercises: [(name: String, duration: TimeInterval)] {
        workoutManager.getTopExercises(limit: 3)
    }
    
    var workouts: [Workout] {
        workoutManager.workouts
    }

    /// Supprime une séance
    func deleteWorkout(_ workout: Workout) {
        workoutManager.deleteWorkout(workout)
        // Puis recalcule les stats
        recompute(from: workoutManager.workouts)
    }

    /// Supprime toutes les séances
    func deleteAllWorkouts() {
        workoutManager.deleteAllWorkouts()
        recompute(from: workoutManager.workouts)
    }

    func comparison() -> (previous: Workout?, latest: Workout?) {
        let done = completedWorkouts
        guard done.count >= 2 else { return (done.first, nil) }
        return (done[1], done[0])
    }

    func improvement() -> TimeInterval {
        let (prev, latest) = comparison()
        guard let p = prev, let l = latest else { return 0 }
        return l.duration - p.duration
    }

    func isImprovement(_ value: TimeInterval) -> Bool {
        value < 0
    }
}

extension StatsViewModel {
    /// Formate un TimeInterval en "m:ss"
    func formatTime(_ seconds: TimeInterval) -> String {
        TimeFormatter.formatTime(seconds)
    }
}
