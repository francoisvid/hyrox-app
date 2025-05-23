// Manager/WorkoutManager.swift

import Foundation
import CoreData
import Combine
#if os(iOS)
import FirebaseFirestore
import WatchConnectivity
#else
import WatchConnectivity
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
        
        context.perform { [weak self] in
            guard let self = self else { return }
            
            print("🆕 Création d'un nouveau workout: \(name)")
            
            // Créer le workout
            let workout = Workout.create(name: name, date: Date(), in: context)
            
            // Ajouter les exercices standard
            for (index, exerciseName) in Workout.standardExerciseOrder.enumerated() {
                if let def = ExerciseDefinitions.all[exerciseName] {
                    let ex = workout.addExercise(name: exerciseName)
                    ex.order = Int16(index) // Définir l'ordre correct
                    
                    if let targetTime = def.targetTime {
                        ex.targetTime = targetTime
                        ex.duration = 0 // Non terminé
                        ex.distance = 0
                        ex.repetitions = 0
                    }
                }
            }
            
            do {
                // Sauvegarder dans CoreData
                try context.save()
                print("✅ Workout sauvegardé dans CoreData")
                
                // Mettre à jour l'interface sur le main thread
                DispatchQueue.main.async {
                    self.currentWorkout = workout
                    self.isWorkoutActive = true
                    self.startTime = Date()
                    self.startTimers()
                    self.loadWorkouts() // Rafraîchir la liste
                }
                
                // Synchronisation selon la plateforme
                #if os(watchOS)
                // Sur Watch : envoyer à l'iPhone
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    DataSyncManager.shared.sendWorkout(workout)
                    print("⌚️ Workout envoyé vers iPhone")
                }
                #endif
                
                #if os(iOS)
                // Sur iPhone : sauvegarder dans Firebase ET envoyer à la Watch
                Task { @MainActor in
                    do {
                        // 1. Sauvegarder dans Firebase
                        try await DataSyncManager.shared.saveWorkoutToFirebase(workout)
                        print("☁️ Workout sauvegardé dans Firebase")
                        
                        // 2. Envoyer à la Watch si connectée
                        if WCSession.default.isReachable {
                            DataSyncManager.shared.sendWorkout(workout)
                            print("📱 Workout envoyé vers Watch")
                        }
                    } catch {
                        print("❌ Erreur synchronisation: \(error)")
                    }
                }
                #endif
                
            } catch {
                print("❌ Erreur création workout: \(error)")
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
        
        print("🏁 Workout terminé: \(workout.id?.uuidString ?? "unknown")")
        
        // Synchronisation selon la plateforme
        #if os(watchOS)
        // Sur Watch : envoyer immédiatement à l'iPhone
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            DataSyncManager.shared.sendWorkout(workout)
            print("⌚️ Workout terminé envoyé vers iPhone")
        }
        #endif
        
        #if os(iOS)
        Task { @MainActor in
            do {
                // 1. Sauvegarder dans Firebase
                try await DataSyncManager.shared.saveWorkoutToFirebase(workout)
                print("☁️ Workout terminé sauvegardé dans Firebase")
                
                // 2. Envoyer à la Watch
                if WCSession.default.isReachable || WCSession.default.isWatchAppInstalled {
                    DataSyncManager.shared.sendWorkout(workout)
                    print("📱 Workout terminé envoyé vers Watch")
                }
                
                // 3. Notification pour rafraîchir l'UI locale
                NotificationCenter.default.post(
                    name: NSNotification.Name("WorkoutCompleted"),
                    object: nil,
                    userInfo: ["workoutId": workout.id?.uuidString ?? ""]
                )
            } catch {
                print("❌ Erreur synchronisation workout terminé: \(error)")
            }
        }
        #endif
        
        // Réinitialiser l'état local
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
            guard let workoutId = workout.id?.uuidString else { return }
            
            // Supprimer partout
            Task {
                do {
                    #if os(iOS)
                    // Supprimer de Firebase ET envoyer à la Watch
                    try await DataSyncManager.shared.deleteWorkoutEverywhere(workoutId)
                    #else
                    // Sur Watch, envoyer la suppression à l'iPhone
                    let deleteMessage: [String: Any] = [
                        "action": "deleteWorkout",
                        "workoutId": workoutId,
                        "timestamp": Date().timeIntervalSince1970
                    ]
                    
                    if WCSession.default.isReachable {
                        WCSession.default.sendMessage(deleteMessage, replyHandler: nil, errorHandler: nil)
                    } else {
                        WCSession.default.transferUserInfo(deleteMessage)
                    }
                    #endif
                } catch {
                    print("❌ Erreur suppression workout: \(error)")
                }
            }
            
            // Supprimer de CoreData localement
            context.delete(workout)
            DataController.shared.saveContext()
            
            DispatchQueue.main.async {
                self.loadWorkouts()
                self.updatePersonalBests()
            }
        }
    }

    func deleteAllWorkouts() {
        let context = dataController.container.viewContext
        context.perform {
            // Supprimer de Firebase et envoyer message à la Watch
            #if os(iOS)
            Task {
                do {
                    try await DataSyncManager.shared.deleteAllWorkoutsFromFirebase()
                    print("✅ Tous les workouts supprimés de Firebase")

                    // 🔄 Envoi d'un message de suppression à la Watch
                    let message: [String: Any] = [
                        "action": "deleteAllWorkouts",  // Changé pour cohérence
                        "timestamp": Date().timeIntervalSince1970
                    ]
                    
                    if WCSession.default.isReachable {
                        WCSession.default.sendMessage(message, replyHandler: nil) { error in
                            print("❌ Erreur envoi deleteAllWorkouts vers Watch:", error)
                            // Fallback avec transferUserInfo
                            WCSession.default.transferUserInfo(message)
                        }
                    } else {
                        WCSession.default.transferUserInfo(message)
                    }
                } catch {
                    print("❌ Erreur suppression tous workouts Firebase: \(error)")
                }
            }
            #else
            // Sur Watch, envoyer la demande de suppression à l'iPhone
            let message: [String: Any] = [
                "action": "deleteAllWorkouts",
                "timestamp": Date().timeIntervalSince1970
            ]
            
            if WCSession.default.isReachable {
                WCSession.default.sendMessage(message, replyHandler: nil) { error in
                    print("❌ Erreur envoi deleteAllWorkouts vers iPhone:", error)
                    WCSession.default.transferUserInfo(message)
                }
            } else {
                WCSession.default.transferUserInfo(message)
            }
            #endif

            // Supprimer de CoreData localement
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
    func loadWorkoutsFromFirebase() async throws {
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
