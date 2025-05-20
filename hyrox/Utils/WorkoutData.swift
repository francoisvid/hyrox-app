
import Foundation

/// Modèle simple pour passer des données Workout à la vue/statistique
struct WorkoutData {
    let date: Date
    let duration: TimeInterval
    let distance: Double

    init(workout: Workout) {
        self.date = workout.date ?? Date()
        self.duration = workout.duration
        self.distance = workout.distance
    }
}
