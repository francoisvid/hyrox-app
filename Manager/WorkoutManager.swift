// Manager/WorkoutManager.swift

import Foundation
import CoreData
import Combine

@MainActor
final class WorkoutManager: ObservableObject {
    private let dataController: DataController
    private var cancellables = Set<AnyCancellable>()
    private var workoutTimer: AnyCancellable?
    private var heartRateTimer: AnyCancellable?
    private var startTime: Date?

    @Published var workouts: [Workout] = []
    @Published var currentWorkout: Workout?
    @Published var isWorkoutActive = false
    @Published var elapsedTime: TimeInterval = 0
    @Published var personalBests: [String: Exercise] = [:]

    init(dataController: DataController = .shared) {
        self.dataController = dataController
        loadWorkouts()
        updatePersonalBests()
    }

    func loadWorkouts() {
        let context = dataController.container.viewContext
        let request: NSFetchRequest<Workout> = Workout.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Workout.date, ascending: false)]
        do {
            workouts = try context.fetch(request)
        } catch {
            print("Erreur chargement workouts: \(error.localizedDescription)")
        }
    }

    func updatePersonalBests() {
        var bests: [String: Exercise] = [:]
        for workout in workouts where workout.completed {
            if let exercises = workout.exercises as? Set<Exercise> {
                for exercise in exercises {
                    guard let name = exercise.name, exercise.duration > 0 else { continue }
                    if let previous = bests[name] {
                        if exercise.duration < previous.duration {
                            bests[name] = exercise
                        }
                    } else {
                        bests[name] = exercise
                    }
                }
            }
        }
        personalBests = bests
    }

    func startNewWorkout(name: String = "Entraînement Hyrox") {
        let context = dataController.container.viewContext
        context.perform {
            let workout = Workout.create(name: name, date: Date(), in: context)
            for (exName, def) in ExerciseDefinitions.all {
                let ex = workout.addExercise(name: exName)
                if let t = def.targetTime { ex.targetTime = t }
            }
            do {
                // Sauvegarder le contexte
                DataController.shared.saveContext()
                
                // Synchroniser le workout
                DataSyncManager.shared.sendWorkout(workout)
                
                DispatchQueue.main.async {
                    self.currentWorkout = workout
                    self.isWorkoutActive = true
                    self.startTime = Date()
                    self.startTimers()
                }
            } catch {
                print("Erreur save nouveau workout: \(error)")
            }
        }
    }

    func endWorkout() {
        guard let workout = currentWorkout, let start = startTime else { return }
        
        let duration = Date().timeIntervalSince(start)
        let totalDistance = (workout.exercises as? Set<Exercise>)?
            .reduce(0) { $0 + $1.distance } ?? 0
        
        workout.finish(duration: duration, distance: totalDistance)
        
        // Sauvegarder le contexte
        DataController.shared.saveContext()
        
        // Synchroniser le workout après qu'il soit terminé
        DataSyncManager.shared.sendWorkout(workout)
        
        // Le reste de votre code reste inchangé
        loadWorkouts()
        updatePersonalBests()
        currentWorkout = nil
        isWorkoutActive = false
        stopTimers()
    }

    private func startTimers() {
        workoutTimer = Timer
            .publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, let start = self.startTime else { return }
                self.elapsedTime = Date().timeIntervalSince(start)
            }

        heartRateTimer = Timer
            .publish(every: 5.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, let workout = self.currentWorkout else { return }
                let baseHR = 130.0
                let intensity = min(50, self.elapsedTime / 60)
                let hr = baseHR + intensity + Double.random(in: -5...5)
                _ = workout.addHeartRate(value: hr, timestamp: Date())
                DataController.shared.saveContext()
            }
    }

    private func stopTimers() {
        workoutTimer?.cancel()
        heartRateTimer?.cancel()
        elapsedTime = 0
        startTime = nil
    }

    func updateExercise(id: UUID, duration: Double, distance: Double = 0, repetitions: Int16 = 0) {
        guard
            let workout = currentWorkout,
            let exercises = workout.exercises as? Set<Exercise>,
            let ex = exercises.first(where: { $0.id == id })
        else { return }
        ex.updatePerformance(duration: duration, distance: distance, repetitions: repetitions)
        DataController.shared.saveContext()
    }

    func deleteWorkout(_ workout: Workout) {
        let context = dataController.container.viewContext
        context.perform {
            context.delete(workout)
            do {
                DataController.shared.saveContext()
                DispatchQueue.main.async {
                    self.loadWorkouts()
                    self.updatePersonalBests()
                }
            } catch {
                print("Erreur suppression workout: \(error)")
            }
        }
    }

    func deleteAllWorkouts() {
        let context = dataController.container.viewContext
        context.perform {
            let req = NSFetchRequest<NSFetchRequestResult>(entityName: "Workout")
            let delete = NSBatchDeleteRequest(fetchRequest: req)
            do {
                try context.execute(delete)
                DataController.shared.saveContext()
                DispatchQueue.main.async {
                    self.loadWorkouts()
                    self.updatePersonalBests()
                }
            } catch {
                print("Erreur suppression tous workouts: \(error)")
            }
        }
    }

    // MARK: - Statistiques

    func getWorkoutStatistics(months: Int) -> [(Date, TimeInterval)] {
        let calendar = Calendar.current
        let since = calendar.date(byAdding: .month, value: -months, to: Date())!
        return workouts
            .filter { $0.completed && ($0.date ?? Date()) >= since }
            .map { ($0.date ?? Date(), $0.duration) }
            .sorted { $0.0 < $1.0 }
    }

    func getTopExercises(limit: Int = 3) -> [(name: String, duration: TimeInterval)] {
        personalBests.values
            .sorted { $0.duration < $1.duration }
            .prefix(limit)
            .compactMap { ex in
                guard let name = ex.name else { return nil }
                return (name, ex.duration)
            }
    }
}
