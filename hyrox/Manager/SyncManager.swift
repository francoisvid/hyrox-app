import Foundation
import CoreData
import FirebaseFirestore
import Combine
import Network

/// Gère la synchronisation entre CoreData et Firebase
final class SyncManager: ObservableObject {
    static let shared = SyncManager()
    
    private let db = Firestore.firestore()
    private let container = DataController.shared.container
    private var listeners: [ListenerRegistration] = []
    private var cancellables = Set<AnyCancellable>()
    
    // Network monitoring
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NetworkMonitor")
    
    // Published properties
    @Published var isSyncing = false
    @Published var syncErrors: [SyncError] = []
    @Published var isConnected = true
    
    // MARK: - Types
    
    enum SyncStatus: String {
        case pending = "pending"
        case syncing = "syncing"
        case synced = "synced"
        case conflict = "conflict"
        case error = "error"
    }
    
    struct SyncError: Identifiable, Error {
        let id = UUID()
        let message: String
        let date = Date()
        let objectId: String?
    }
    
    enum ConflictResolution {
        case useLocal
        case useRemote
        case merge
    }
    
    // MARK: - Initialization
    
    private init() {
        setupNetworkMonitoring()
    }
    
    deinit {
        stopListeners()
        monitor.cancel()
    }
    
    // MARK: - Network Monitoring
    
    private func setupNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                if path.status == .satisfied {
                    self?.performPendingSync()
                }
            }
        }
        monitor.start(queue: monitorQueue)
    }
    
    private func performPendingSync() {
        Task {
            do {
                try await syncPendingWorkouts()
                try await syncPendingTemplates()
            } catch {
                await MainActor.run {
                    self.syncErrors.append(SyncError(
                        message: error.localizedDescription,
                        objectId: nil
                    ))
                }
            }
        }
    }
    
    // MARK: - Synchronisation CoreData → Firebase
    
    /// Synchronise un workout actif (pendant l'entraînement)
    func syncActiveWorkout(_ workout: Workout) async throws {
        guard isConnected else {
            workout.setValue(SyncStatus.pending.rawValue, forKey: "syncStatus")
            try container.viewContext.save()
            return
        }
        
        guard let workoutId = workout.id?.uuidString else {
            throw SyncError(message: "Invalid workout ID", objectId: nil)
        }
        
        await MainActor.run { self.isSyncing = true }
        defer { Task { @MainActor in self.isSyncing = false } }
        
        // Marquer comme en cours de sync
        workout.setValue(SyncStatus.syncing.rawValue, forKey: "syncStatus")
        try container.viewContext.save()
        
        do {
            // Préparer les données
            let workoutData = try prepareWorkoutData(workout)
            
            // Envoyer à Firebase
            try await db.collection(FirebaseStructure.workouts)
                .document(workoutId)
                .setData(workoutData, merge: true)
            
            // Mettre à jour les statistiques
            if let userId = workout.userId?.uuidString {
                try await updateStatistics(for: workout, userId: userId)
            }
            
            // Marquer comme synchronisé
            workout.setValue(SyncStatus.synced.rawValue, forKey: "syncStatus")
            workout.setValue(Date(), forKey: "lastSyncedAt")
            let currentVersion = workout.value(forKey: "version") as? Int32 ?? 0
            workout.setValue(currentVersion + 1, forKey: "version")
            
            try container.viewContext.save()
            
        } catch {
            workout.setValue(SyncStatus.error.rawValue, forKey: "syncStatus")
            try container.viewContext.save()
            throw error
        }
    }
    
    /// Synchronise tous les workouts en attente
    func syncPendingWorkouts() async throws {
        let context = container.newBackgroundContext()
        
        let fetchRequest: NSFetchRequest<Workout> = Workout.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "syncStatus == %@ OR syncStatus == nil",
            SyncStatus.pending.rawValue
        )
        
        let workouts = try context.fetch(fetchRequest)
        
        for workout in workouts {
            do {
                try await syncWorkoutInBackground(workout, context: context)
            } catch {
                print("Failed to sync workout \(workout.id?.uuidString ?? "unknown"): \(error)")
            }
        }
    }
    
    /// Synchronise tous les templates en attente
    func syncPendingTemplates() async throws {
        let context = container.newBackgroundContext()
        
        let fetchRequest: NSFetchRequest<WorkoutTemplate> = WorkoutTemplate.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "syncStatus == %@ OR syncStatus == nil",
            SyncStatus.pending.rawValue
        )
        
        let templates = try context.fetch(fetchRequest)
        
        for template in templates {
            do {
                try await syncTemplateInBackground(template, context: context)
            } catch {
                print("Failed to sync template \(template.id?.uuidString ?? "unknown"): \(error)")
            }
        }
    }
    
    // MARK: - Synchronisation Firebase → CoreData
    
    /// Configure les listeners pour la synchronisation temps réel
    func setupRealtimeListeners(for userId: String) {
        stopListeners() // Nettoyer les anciens listeners
        
        // Listener pour les workouts de l'utilisateur
        let workoutListener = db.collection(FirebaseStructure.workouts)
            .whereField("userId", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents, error == nil else { return }
                
                Task {
                    for document in documents where document.metadata.hasPendingWrites == false {
                        try await self?.handleWorkoutUpdate(document)
                    }
                }
            }
        listeners.append(workoutListener)
        
        // Listener pour les templates publics
        let templateListener = db.collection(FirebaseStructure.templates)
            .whereField("isPublic", isEqualTo: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents, error == nil else { return }
                
                Task {
                    for document in documents where document.metadata.hasPendingWrites == false {
                        try await self?.handleTemplateUpdate(document)
                    }
                }
            }
        listeners.append(templateListener)
    }
    
    /// Arrête tous les listeners
    func stopListeners() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
    }
    
    // MARK: - Batch Operations
    
    /// Synchronise plusieurs workouts en batch
    func syncWorkoutsBatch(_ workouts: [Workout]) async throws {
        guard isConnected else { return }
        
        let batch = db.batch()
        var processedWorkouts: [(workout: Workout, ref: DocumentReference)] = []
        
        for workout in workouts {
            guard let workoutId = workout.id?.uuidString else { continue }
            
            do {
                let data = try prepareWorkoutData(workout)
                let ref = db.collection(FirebaseStructure.workouts).document(workoutId)
                batch.setData(data, forDocument: ref, merge: true)
                processedWorkouts.append((workout, ref))
            } catch {
                print("Failed to prepare workout \(workoutId): \(error)")
            }
        }
        
        try await batch.commit()
        
        // Mettre à jour les statuts localement
        for (workout, _) in processedWorkouts {
            workout.setValue(SyncStatus.synced.rawValue, forKey: "syncStatus")
            workout.setValue(Date(), forKey: "lastSyncedAt")
            let currentVersion = workout.value(forKey: "version") as? Int32 ?? 0
            workout.setValue(currentVersion + 1, forKey: "version")
        }
        
        try container.viewContext.save()
    }
    
    // MARK: - Statistics Update
    
    private func updateStatistics(for workout: Workout, userId: String) async throws {
        // Statistiques globales
        let globalStats = try await calculateGlobalStatistics(userId: userId)
        
        try await db.collection(FirebaseStructure.users)
            .document(userId)
            .collection(FirebaseStructure.statistics)
            .document("global")
            .setData([
                "totalWorkouts": globalStats.totalWorkouts,
                "totalDuration": globalStats.totalDuration,
                "totalDistance": globalStats.totalDistance,
                "lastWorkoutDate": workout.date ?? Date(),
                "lastUpdated": Date()
            ], merge: true)
        
        // Statistiques par exercice
        if let exercises = workout.exercises as? Set<Exercise> {
            for exercise in exercises {
                try await updateExerciseStatistics(exercise, userId: userId)
            }
        }
        
        // Statistiques par type de workout
        if let templateId = workout.templateId?.uuidString {
            try await updateWorkoutTypeStatistics(workout, templateId: templateId, userId: userId)
        }
    }
    
    private func updateExerciseStatistics(_ exercise: Exercise, userId: String) async throws {
        guard let exerciseName = exercise.name else { return }
        
        let exerciseId = exerciseName.lowercased().replacingOccurrences(of: " ", with: "_")
        let docRef = db.collection(FirebaseStructure.users)
            .document(userId)
            .collection(FirebaseStructure.statistics)
            .document(FirebaseStructure.Statistics.exercises)
            .collection(exerciseId)
            .document(exerciseId)
        
        // Récupérer les stats existantes
        let doc = try await docRef.getDocument()
        var stats = doc.data() ?? [:]
        
        // Mettre à jour les compteurs
        let totalCompleted = (stats["totalCompleted"] as? Int ?? 0) + 1
        let currentBestTime = stats["bestTime"] as? Double ?? Double.infinity
        let currentBestDistance = stats["bestDistance"] as? Double ?? 0
        let currentBestReps = stats["bestRepetitions"] as? Int ?? 0
        
        // Calculer la nouvelle moyenne
        let currentAverage = stats["averageTime"] as? Double ?? 0
        let newAverage = ((currentAverage * Double(totalCompleted - 1)) + exercise.duration) / Double(totalCompleted)
        
        // Gérer la progression
        var progression = (stats["progression"] as? [[String: Any]]) ?? []
        let progressionValue = calculateProgressionValue(for: exercise)
        
        progression.insert([
            "date": Date(),
            "value": progressionValue
        ], at: 0)
        
        // Limiter à 100 entrées
        if progression.count > 100 {
            progression = Array(progression.prefix(100))
        }
        
        // Sauvegarder
        try await docRef.setData([
            "totalCompleted": totalCompleted,
            "averageTime": newAverage,
            "bestTime": min(currentBestTime, exercise.duration),
            "bestDistance": max(currentBestDistance, exercise.distance),
            "bestRepetitions": max(currentBestReps, Int(exercise.repetitions)),
            "progression": progression,
            "lastUpdated": Date()
        ], merge: true)
    }
    
    private func updateWorkoutTypeStatistics(_ workout: Workout, templateId: String, userId: String) async throws {
        let docRef = db.collection(FirebaseStructure.users)
            .document(userId)
            .collection(FirebaseStructure.statistics)
            .document(FirebaseStructure.Statistics.workouts)  // Ajout de .document()
            .collection(templateId)
            .document(templateId)
        
        // Récupérer les stats existantes
        let doc = try await docRef.getDocument()
        var stats = doc.data() ?? [:]
        
        // Mettre à jour
        let totalCompleted = (stats["totalCompleted"] as? Int ?? 0) + 1
        let currentBestTime = stats["bestTime"] as? Double ?? Double.infinity
        let currentAverage = stats["averageTime"] as? Double ?? 0
        let newAverage = ((currentAverage * Double(totalCompleted - 1)) + workout.duration) / Double(totalCompleted)
        
        // Progression
        var progression = (stats["progression"] as? [[String: Any]]) ?? []
        progression.insert([
            "date": Date(),
            "value": min(100, (workout.duration > 0 ? 100 : 0))
        ], at: 0)
        
        if progression.count > 100 {
            progression = Array(progression.prefix(100))
        }
        
        try await docRef.setData([
            "totalCompleted": totalCompleted,
            "averageTime": newAverage,
            "bestTime": min(currentBestTime, workout.duration),
            "progression": progression,
            "lastUpdated": Date()
        ], merge: true)
    }
    
    // MARK: - Helper Methods
    
    private func prepareWorkoutData(_ workout: Workout) throws -> [String: Any] {
        guard let workoutId = workout.id?.uuidString else {
            throw SyncError(message: "Invalid workout ID", objectId: nil)
        }
        
        var data: [String: Any] = [
            "id": workoutId,
            "userId": workout.userId?.uuidString ?? "",
            "name": workout.name ?? "",
            "date": Timestamp(date: workout.date ?? Date()),
            "duration": workout.duration,
            "distance": workout.distance,
            "completed": workout.completed,
            "version": workout.value(forKey: "version") as? Int32 ?? 1,
            "lastSyncedAt": Timestamp(date: Date())
        ]
        
        if let templateId = workout.templateId?.uuidString {
            data["templateId"] = templateId
        }
        
        // Ajouter les exercices
        if let exercises = workout.exercises as? Set<Exercise> {
            let exercisesData = exercises.compactMap { exercise -> [String: Any]? in
                guard let exerciseId = exercise.id?.uuidString else { return nil }
                
                return [
                    "id": exerciseId,
                    "name": exercise.name ?? "",
                    "duration": exercise.duration,
                    "distance": exercise.distance,
                    "repetitions": exercise.repetitions,
                    "order": exercise.order,
                    "personalBest": exercise.personalBest,
                    "version": exercise.value(forKey: "version") as? Int32 ?? 1
                ]
            }.sorted { ($0["order"] as? Int16 ?? 0) < ($1["order"] as? Int16 ?? 0) }
            
            data["exercises"] = exercisesData
        }
        
        return data
    }
    
    private func syncWorkoutInBackground(_ workout: Workout, context: NSManagedObjectContext) async throws {
        guard let workoutId = workout.id?.uuidString else { return }
        
        let data = try prepareWorkoutData(workout)
        
        try await db.collection(FirebaseStructure.workouts)
            .document(workoutId)
            .setData(data, merge: true)
        
        workout.setValue(SyncStatus.synced.rawValue, forKey: "syncStatus")
        workout.setValue(Date(), forKey: "lastSyncedAt")
        let currentVersion = workout.value(forKey: "version") as? Int32 ?? 0
        workout.setValue(currentVersion + 1, forKey: "version")
        
        try context.save()
    }
    
    private func syncTemplateInBackground(_ template: WorkoutTemplate, context: NSManagedObjectContext) async throws {
        guard let templateId = template.id?.uuidString else { return }
        
        guard let data = FirebaseStructure.convertToFirebase(template) else {
            throw SyncError(message: "Failed to convert template", objectId: templateId)
        }
        
        try await db.collection(FirebaseStructure.templates)
            .document(templateId)
            .setData(data, merge: true)
        
        template.setValue(SyncStatus.synced.rawValue, forKey: "syncStatus")
        template.setValue(Date(), forKey: "lastSyncedAt")
        let currentVersion = template.value(forKey: "version") as? Int32 ?? 0
        template.setValue(currentVersion + 1, forKey: "version")
        
        try context.save()
    }
    
    private func handleWorkoutUpdate(_ document: QueryDocumentSnapshot) async throws {
        let context = container.newBackgroundContext()
        let workoutId = document.documentID
        let data = document.data()
        
        // Vérifier si le workout existe
        let fetchRequest: NSFetchRequest<Workout> = Workout.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", workoutId)
        
        let existingWorkouts = try context.fetch(fetchRequest)
        
        if let existingWorkout = existingWorkouts.first {
            // Résoudre les conflits
            let resolution = try resolveConflict(local: existingWorkout, remote: data)
            
            if resolution == .useRemote {
                updateWorkoutFromRemote(existingWorkout, with: data)
                try context.save()
            }
        } else {
            // Créer un nouveau workout
            createWorkoutFromRemote(data: data, context: context)
            try context.save()
        }
    }
    
    private func handleTemplateUpdate(_ document: QueryDocumentSnapshot) async throws {
        // Logique similaire pour les templates
    }
    
    private func resolveConflict(local: NSManagedObject, remote: [String: Any]) throws -> ConflictResolution {
        let remoteVersion = remote["version"] as? Int ?? 0
        let localVersion = local.value(forKey: "version") as? Int32 ?? 0
        
        if remoteVersion > localVersion {
            return .useRemote
        } else if remoteVersion < localVersion {
            return .useLocal
        } else {
            // Comparer les dates
            let remoteDate = (remote["lastSyncedAt"] as? Timestamp)?.dateValue()
            let localDate = local.value(forKey: "lastSyncedAt") as? Date
            
            if let remoteDate = remoteDate, let localDate = localDate {
                return remoteDate > localDate ? .useRemote : .useLocal
            }
            
            return .useLocal
        }
    }
    
    private func updateWorkoutFromRemote(_ workout: Workout, with data: [String: Any]) {
        workout.name = data["name"] as? String
        workout.date = (data["date"] as? Timestamp)?.dateValue()
        workout.duration = data["duration"] as? Double ?? 0
        workout.distance = data["distance"] as? Double ?? 0
        workout.completed = data["completed"] as? Bool ?? false
        
        if let version = data["version"] as? Int {
            workout.setValue(Int32(version), forKey: "version")
        }
        
        workout.setValue(SyncStatus.synced.rawValue, forKey: "syncStatus")
        workout.setValue(Date(), forKey: "lastSyncedAt")
    }
    
    private func createWorkoutFromRemote(data: [String: Any], context: NSManagedObjectContext) {
        let workout = Workout(context: context)
        
        if let idString = data["id"] as? String,
           let id = UUID(uuidString: idString) {
            workout.id = id
        }
        
        updateWorkoutFromRemote(workout, with: data)
    }
    
    private func calculateGlobalStatistics(userId: String) async throws -> (totalWorkouts: Int, totalDuration: Double, totalDistance: Double) {
        let context = container.viewContext
        let fetchRequest: NSFetchRequest<Workout> = Workout.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "userId == %@ AND completed == true", UUID(uuidString: userId)! as CVarArg)
        
        let workouts = try context.fetch(fetchRequest)
        
        let totalWorkouts = workouts.count
        let totalDuration = workouts.reduce(0) { $0 + $1.duration }
        let totalDistance = workouts.reduce(0) { $0 + $1.distance }
        
        return (totalWorkouts, totalDuration, totalDistance)
    }
    
    private func calculateProgressionValue(for exercise: Exercise) -> Double {
        // Si l'exercice a un temps cible
        if exercise.targetTime > 0 && exercise.duration > 0 {
            let performance = (exercise.targetTime / exercise.duration) * 100
            return min(100, max(0, performance))
        }
        
        // Sinon, utiliser d'autres métriques
        if exercise.distance > 0 {
            // Plus de distance = meilleur
            return min(100, exercise.distance * 10)
        }
        
        if exercise.repetitions > 0 {
            // Plus de répétitions = meilleur
            return min(100, Double(exercise.repetitions) * 2)
        }
        
        // Par défaut
        return exercise.personalBest ? 100 : 50
    }
}
