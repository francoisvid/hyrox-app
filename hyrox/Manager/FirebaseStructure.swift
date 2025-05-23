import Foundation
import CoreData
import FirebaseFirestore

/// Structure des données Firebase
enum FirebaseStructure {
    // MARK: - Chemins de base
    static let users = "users"
    static let statistics = "statistics"
    static let workouts = "workouts"
    static let templates = "templates"
    static let heartRates = "heartRates"
    
    // MARK: - Sous-chemins
    enum Statistics {
        static let exercises = "exercises"
        static let workouts = "workouts"
        static let progression = "progression"
    }
    
    // MARK: - Chemins complets
    static func userPath(_ userId: String) -> String {
        "\(users)/\(userId)"
    }
    
    static func userStatisticsPath(_ userId: String) -> String {
        "\(users)/\(userId)/\(statistics)"
    }
    
    static func exerciseStatisticsPath(_ userId: String, exerciseId: String) -> String {
        "\(users)/\(userId)/\(statistics)/\(Statistics.exercises)/\(exerciseId)"
    }
    
    static func workoutStatisticsPath(_ userId: String, workoutId: String) -> String {
        "\(users)/\(userId)/\(statistics)/\(Statistics.workouts)/\(workoutId)"
    }
    
    static func workoutPath(_ workoutId: String) -> String {
        "\(workouts)/\(workoutId)"
    }
    
    static func templatePath(_ templateId: String) -> String {
        "\(templates)/\(templateId)"
    }
    
    static func heartRatePath(_ workoutId: String, pointId: String) -> String {
        "\(workouts)/\(workoutId)/\(heartRates)/\(pointId)"
    }
    
    // MARK: - Structure des données
    
    /// Structure d'un utilisateur
    struct FirebaseUser: Codable {
        let id: String
        let displayName: String
        let email: String
        let createdAt: Date
        let lastLoginAt: Date
        let preferences: UserPreferences?
    }
    
    /// Préférences utilisateur
    struct UserPreferences: Codable {
        let theme: String?
        let notifications: Bool?
        let units: String?
        let customSettings: [String: String]?
    }
    
    /// Structure des statistiques d'exercice
    struct FirebaseExerciseStatistics: Codable {
        let totalCompleted: Int
        let averageTime: Double
        let bestTime: Double
        let progression: [ProgressionPoint]
    }
    
    /// Structure des statistiques de workout
    struct FirebaseWorkoutStatistics: Codable {
        let totalCompleted: Int
        let averageTime: Double
        let bestTime: Double
        let progression: [ProgressionPoint]
    }
    
    /// Structure d'un point de progression
    struct ProgressionPoint: Codable {
        let date: Date
        let value: Double
    }
    
    /// Structure d'un workout
    struct FirebaseWorkout: Codable {
        let id: String
        let userId: String
        let templateId: String?
        let name: String
        let date: Date
        let duration: Double
        let distance: Double
        let completed: Bool
        let exercises: [FirebaseExercise]
        let version: Int
        let lastSyncedAt: Date
    }
    
    /// Structure d'un exercice
    struct FirebaseExercise: Codable {
        let id: String
        let name: String
        let duration: Double
        let distance: Double
        let repetitions: Int
        let version: Int
    }
    
    /// Structure d'un point de fréquence cardiaque
    struct FirebaseHeartRatePoint: Codable {
        let id: String
        let timestamp: Date
        let value: Double
        let version: Int
    }
    
    /// Structure d'un template de workout
    struct FirebaseWorkoutTemplate: Codable {
        let id: String
        let creatorId: String
        let name: String
        let description: String?
        let category: String
        let difficulty: String
        let estimatedDuration: Double
        let isPublic: Bool
        let exercises: [FirebaseExerciseTemplate]
        let version: Int
        let lastSyncedAt: Date
    }
    
    /// Structure d'un template d'exercice
    struct FirebaseExerciseTemplate: Codable {
        let id: String
        let name: String
        let description: String?
        let type: String
        let defaultDuration: Double
        let defaultDistance: Double
        let defaultRepetitions: Int
        let order: Int
        let version: Int
    }
}

// MARK: - Extensions pour la conversion

extension FirebaseStructure {
    /// Convertit un objet CoreData en structure Firebase
    static func convertToFirebase<T: NSManagedObject>(_ object: T) -> [String: Any]? {
        switch object {
        case let workout as Workout:
            return convertWorkout(workout)
        case let exercise as Exercise:
            return convertExercise(exercise)
        case let template as WorkoutTemplate:
            return convertWorkoutTemplate(template)
        case let exerciseTemplate as ExerciseTemplate:
            return convertExerciseTemplate(exerciseTemplate)
        case let heartRate as HeartRatePoint:
            return convertHeartRatePoint(heartRate)
        default:
            return nil
        }
    }
    
    private static func convertWorkout(_ workout: Workout) -> [String: Any] {
        var data: [String: Any] = [
            "id": workout.id?.uuidString ?? "",
            "userId": workout.userId?.uuidString ?? "",
            "name": workout.name ?? "",
            "date": workout.date ?? Date(),
            "duration": workout.duration,
            "distance": workout.distance,
            "completed": workout.completed,
            "version": workout.version,
            "lastSyncedAt": workout.lastSyncedAt ?? Date()
        ]
        
        if let templateId = workout.templateId {
            data["templateId"] = templateId.uuidString
        }
        
        // Convertir les exercices
        var exercises: [[String: Any]] = []
        for exercise in workout.exercises as? Set<Exercise> ?? [] {
            if let exerciseData = convertExercise(exercise) {
                exercises.append(exerciseData)
            }
        }
        data["exercises"] = exercises
        
        return data
    }
    
    private static func convertExercise(_ exercise: Exercise) -> [String: Any]? {
        guard let id = exercise.id?.uuidString else { return nil }
        
        return [
            "id": id,
            "name": exercise.name ?? "",
            "duration": exercise.duration,
            "distance": exercise.distance,
            "repetitions": exercise.repetitions,
            "version": exercise.version
        ]
    }
    
    private static func convertWorkoutTemplate(_ template: WorkoutTemplate) -> [String: Any] {
        var data: [String: Any] = [
            "id": template.id?.uuidString ?? "",
            "creatorId": template.creator?.id?.uuidString ?? "",
            "name": template.name ?? "",
            "category": template.category ?? "",
            "difficulty": template.difficulty ?? "",
            "estimatedDuration": template.estimatedDuration,
            "isPublic": template.isPublic,
            "version": template.version,
            "lastSyncedAt": template.lastSyncedAt ?? Date()
        ]
        
        if let description = template.workoutDescription {
            data["description"] = description
        }
        
        // Convertir les exercices
        var exercises: [[String: Any]] = []
        for exercise in template.exercises as? Set<ExerciseTemplate> ?? [] {
            if let exerciseData = convertExerciseTemplate(exercise) {
                exercises.append(exerciseData)
            }
        }
        data["exercises"] = exercises
        
        return data
    }
    
    private static func convertExerciseTemplate(_ template: ExerciseTemplate) -> [String: Any]? {
        guard let id = template.id?.uuidString else { return nil }
        
        var data: [String: Any] = [
            "id": id,
            "name": template.name ?? "",
            "type": template.type ?? "",
            "defaultDuration": template.defaultDuration,
            "defaultDistance": template.defaultDistance,
            "defaultRepetitions": template.defaultRepetitions,
            "order": template.order,
            "version": template.version
        ]
        
        if let description = template.exerciseDescription {
            data["description"] = description
        }
        
        return data
    }
    
    private static func convertHeartRatePoint(_ point: HeartRatePoint) -> [String: Any]? {
        guard let id = point.id?.uuidString else { return nil }
        
        return [
            "id": id,
            "timestamp": point.timestamp ?? Date(),
            "value": point.value,
            "version": point.version
        ]
    }
}
