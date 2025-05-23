// Manager/WorkoutManager.swift

import Foundation
import CoreData
import Combine
#if os(iOS)
import FirebaseFirestore
#endif

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
        
        #if os(iOS)
        // Charger les workouts depuis Firebase au démarrage
        Task {
            do {
                try await loadWorkoutsFromFirebase()
            } catch {
                print("Erreur chargement workouts Firebase: \(error)")
            }
        }
        #endif
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
            
            // Utiliser l'ordre standard des exercices
            for exerciseName in Workout.standardExerciseOrder {
                if let def = ExerciseDefinitions.all[exerciseName] {
                    let ex = workout.addExercise(name: exerciseName)
                    if let targetTime = def.targetTime {
                        ex.targetTime = targetTime
                        // Initialiser la durée à 0 pour indiquer que l'exercice n'est pas terminé
                        ex.duration = 0
                        // Initialiser les autres métriques
                        ex.distance = 0
                        ex.repetitions = 0
                    }
                }
            }
            
            do {
                // Sauvegarder le contexte
                DataController.shared.saveContext()
                
                // Synchroniser avec la montre
                DataSyncManager.shared.sendWorkout(workout)
                
                #if os(iOS)
                Task {
                    do {
                        try await DataSyncManager.shared.saveWorkoutToFirebase(workout)
                        print("✅ Workout initial sauvegardé avec Firebase")
                    } catch {
                        print("❌ Erreur enregistrement initial Firebase: \(error)")
                    }
                }
                #endif
                
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
            .reduce(0.0) { $0 + $1.distance } ?? 0.0
        
        workout.finish(duration: duration, distance: totalDistance)
        
        // Sauvegarder le contexte CoreData
        DataController.shared.saveContext()
        
        #if os(iOS)
        DataController.shared.saveContext()
        Task {
            do {
                try await DataSyncManager.shared.saveWorkoutToFirebase(workout)
                print("✅ Workout mis à jour dans Firebase après fin")
            } catch {
                print("❌ Erreur mise à jour Firebase après fin workout: \(error)")
            }
        }
        #endif
        
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
            // Supprimer de Firebase
            Task {
                do {
                    #if os(iOS)
                    // Supprimer de Firebase via DataSyncManager
                    if let workoutId = workout.id?.uuidString {
                        // Attendre la suppression Firebase
                        try await DataSyncManager.shared.deleteWorkout(workoutId)
                        print("✅ Workout supprimé de Firebase:", workoutId)
                    }
                    #endif
                } catch {
                    print("❌ Erreur suppression workout Firebase: \(error)")
                }
            }
            
            // Supprimer de CoreData
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
            // Supprimer de Firebase
            #if os(iOS)
            Task {
                do {
                    try await DataSyncManager.shared.deleteAllWorkoutsFromFirebase()
                    print("✅ Tous les workouts supprimés de Firebase")
                } catch {
                    print("❌ Erreur suppression tous workouts Firebase: \(error)")
                }
            }
            #endif
            
            // Supprimer de CoreData
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

    #if os(iOS)
    private func loadWorkoutsFromFirebase() async throws {
        let db = Firestore.firestore()
        let snapshot = try await db.collection("workouts").getDocuments()
        
        let context = dataController.container.viewContext
        await context.perform {
            for document in snapshot.documents {
                let data = document.data()
                let workoutId = document.documentID
                
                // Vérifier si le workout existe déjà
                let fetchRequest: NSFetchRequest<Workout> = Workout.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", workoutId)
                
                do {
                    let existingWorkouts = try context.fetch(fetchRequest)
                    if existingWorkouts.isEmpty {
                        // Créer un nouveau workout
                        let workout = Workout(context: context)
                        workout.id = UUID(uuidString: workoutId)
                        workout.name = data["name"] as? String
                        workout.duration = data["duration"] as? Double ?? 0
                        workout.completed = data["completed"] as? Bool ?? false
                        workout.distance = data["distance"] as? Double ?? 0
                        
                        if let timestamp = data["date"] as? Timestamp {
                            workout.date = timestamp.dateValue()
                        }
                        
                        // Charger les exercices depuis l'array
                        if let exercisesArray = data["exercises"] as? [[String: Any]] {
                            for exData in exercisesArray {
                                let exercise = Exercise(context: context)
                                exercise.id = UUID(uuidString: exData["id"] as? String ?? UUID().uuidString)
                                exercise.name = exData["name"] as? String
                                exercise.duration = exData["duration"] as? Double ?? 0
                                exercise.distance = exData["distance"] as? Double ?? 0
                                exercise.repetitions = exData["repetitions"] as? Int16 ?? 0
                                exercise.order = exData["order"] as? Int16 ?? 0
                                exercise.personalBest = exData["personalBest"] as? Bool ?? false
                                exercise.workout = workout
                            }
                        }
                        
                        try context.save()
                        DispatchQueue.main.async {
                            self.loadWorkouts()
                            self.updatePersonalBests()
                        }
                    }
                } catch {
                    print("Erreur chargement workout depuis Firebase: \(error)")
                }
            }
        }
    }
//    private func loadWorkoutsFromFirebase() async throws {
//        let db = Firestore.firestore()
//        let snapshot = try await db.collection("workouts").getDocuments()
//        
//        let context = dataController.container.viewContext
//        await context.perform {
//            for document in snapshot.documents {
//                let data = document.data()
//                let workoutId = document.documentID
//                
//                // Vérifier si le workout existe déjà
//                let fetchRequest: NSFetchRequest<Workout> = Workout.fetchRequest()
//                fetchRequest.predicate = NSPredicate(format: "id == %@", workoutId)
//                
//                do {
//                    let existingWorkouts = try context.fetch(fetchRequest)
//                    if existingWorkouts.isEmpty {
//                        // Créer un nouveau workout
//                        let workout = Workout(context: context)
//                        workout.id = UUID(uuidString: workoutId)
//                        workout.name = data["name"] as? String
//                        workout.duration = data["duration"] as? Double ?? 0
//                        workout.completed = data["completed"] as? Bool ?? false
//                        workout.distance = data["distance"] as? Double ?? 0
//                        
//                        if let timestamp = data["date"] as? Double {
//                            workout.date = Date(timeIntervalSince1970: timestamp)
//                        }
//                        
//                        // Charger les exercices
//                        Task {
//                            do {
//                                let exercisesSnapshot = try await db.collection("workouts")
//                                    .document(workoutId)
//                                    .collection("exercises")
//                                    .getDocuments()
//                                
//                                for exerciseDoc in exercisesSnapshot.documents {
//                                    let exData = exerciseDoc.data()
//                                    let exId = exerciseDoc.documentID
//                                    
//                                    let exercise = Exercise(context: context)
//                                    exercise.id = UUID(uuidString: exId)
//                                    exercise.name = exData["name"] as? String
//                                    exercise.duration = exData["duration"] as? Double ?? 0
//                                    exercise.distance = exData["distance"] as? Double ?? 0
//                                    exercise.repetitions = exData["repetitions"] as? Int16 ?? 0
//                                    exercise.order = exData["order"] as? Int16 ?? 0
//                                    exercise.personalBest = exData["personalBest"] as? Bool ?? false
//                                    exercise.workout = workout
//                                    
//                                    if let timestamp = exData["date"] as? Double {
//                                        exercise.date = Date(timeIntervalSince1970: timestamp)
//                                    }
//                                }
//                                
//                                try context.save()
//                                DispatchQueue.main.async {
//                                    self.loadWorkouts()
//                                    self.updatePersonalBests()
//                                }
//                            } catch {
//                                print("Erreur chargement exercices Firebase: \(error)")
//                            }
//                        }
//                    }
//                } catch {
//                    print("Erreur vérification workout existant: \(error)")
//                }
//            }
//        }
//    }
    #endif
}
