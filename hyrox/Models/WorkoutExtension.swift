import Foundation
import CoreData

extension Workout {
    // Ordre standard défini par l'insertion dans ExerciseDefinitions.all
    public static let standardExerciseOrder = Array(ExerciseDefinitions.all.keys)

    private static let sharedDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    /// Tableau d'exercices triés par nom
    var exerciseArray: [Exercise] {
        (exercises as? Set<Exercise> ?? [])
            .sorted { ($0.name ?? "") < ($1.name ?? "") }
    }

    /// Exercices dans l'ordre Hyrox, puis les autres
    public var orderedExercises: [Exercise] {
        let set = exercises as? Set<Exercise> ?? []
        let map = Dictionary(uniqueKeysWithValues:
            set.compactMap { ex in ex.name.map { ($0, ex) } }
        )
        var result: [Exercise] = []
        for name in Workout.standardExerciseOrder {
            if let ex = map[name] { result.append(ex) }
        }
        for ex in set where !(Workout.standardExerciseOrder.contains(ex.name ?? "")) {
            result.append(ex)
        }
        return result
    }

    /// Points cardiaques triés par date
    var heartRateArray: [HeartRatePoint] {
        (heartRates as? Set<HeartRatePoint> ?? [])
            .sorted { ($0.timestamp ?? Date()) < ($1.timestamp ?? Date()) }
    }

    var averageHeartRate: Double {
        let arr = heartRateArray
        guard !arr.isEmpty else { return 0 }
        return arr.reduce(0) { $0 + $1.value } / Double(arr.count)
    }

    var maxHeartRate: Double {
        heartRateArray.map { $0.value }.max() ?? 0
    }

    var progressPercentage: Double {
        let arr = exerciseArray
        guard !arr.isEmpty else { return 0 }
        let done = arr.filter { $0.isCompleted }.count
        return Double(done) / Double(arr.count) * 100
    }

    /// Durée affichable
    var formattedDuration: String {
        TimeFormatter.formatTime(duration)
    }

    /// Date affichable
    var formattedDate: String {
        guard let date = date else { return "Date inconnue" }
        return Workout.sharedDateFormatter.string(from: date)
    }

    static func create(name: String, date: Date, in context: NSManagedObjectContext) -> Workout {
        let w = Workout(context: context)
        w.id = UUID()
        w.name = name
        w.date = date
        w.completed = false
        w.duration = 0
        w.distance = 0
        return w
    }

    func addExercise(name: String) -> Exercise {
        guard let ctx = managedObjectContext else {
            fatalError("No managed object context")
        }
        let ex = Exercise(context: ctx)
        ex.id = UUID()
        ex.name = name
        ex.workout = self
        ex.duration = 0
        ex.distance = 0
        ex.repetitions = 0
        ex.personalBest = false
        return ex
    }

    func addHeartRate(value: Double, timestamp: Date) -> HeartRatePoint {
        guard let ctx = managedObjectContext else {
            fatalError("No managed object context")
        }
        let hr = HeartRatePoint(context: ctx)
        hr.id = UUID()
        hr.value = value
        hr.timestamp = timestamp
        hr.workout = self
        return hr
    }

    func finish(duration: Double, distance: Double) {
        completed = true
        self.duration = duration
        self.distance = distance
        endDate = Date()
    }

    /// Exercice par nom
    func findExercise(named exerciseName: String) -> Exercise? {
        (exercises as? Set<Exercise>)?.first { $0.name == exerciseName }
    }

    /// Temps effectif (sans pauses)
    var effectiveWorkoutTime: TimeInterval {
        exerciseArray.reduce(0) { $0 + $1.duration }
    }

    /// Durée des pauses
    var pauseTime: TimeInterval {
        let eff = effectiveWorkoutTime
        return duration > eff ? duration - eff : 0
    }
}
