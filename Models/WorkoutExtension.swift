import CoreData

/// Extension de l'entité Workout pour ajouter des fonctionnalités utiles
extension Workout {
    /// Retourne les exercices triés par nom
    var exerciseArray: [Exercise] {
        let set = exercises as? Set<Exercise> ?? []
        return set.sorted { ($0.name ?? "") < ($1.name ?? "") }
    }
    
    /// Retourne les exercices triés selon l'ordre standard Hyrox
    var orderedExercises: [Exercise] {
        let exerciseSet = exercises as? Set<Exercise> ?? []
        
        // Création d'un dictionnaire pour retrouver les exercices par nom
        var exercisesByName: [String: Exercise] = [:]
        for exercise in exerciseSet {
            if let name = exercise.name {
                exercisesByName[name] = exercise
            }
        }
        
        // Tri selon l'ordre standard des exercices Hyrox
        var orderedResult: [Exercise] = []
        for exerciseName in HyroxConstants.exerciseNames {
            if let exercise = exercisesByName[exerciseName] {
                orderedResult.append(exercise)
            }
        }
        
        // Ajouter les exercices qui ne sont pas dans l'ordre standard à la fin
        for exercise in exerciseSet {
            if let name = exercise.name, !HyroxConstants.exerciseNames.contains(name) {
                orderedResult.append(exercise)
            }
        }
        
        return orderedResult
    }
    
    /// Retourne les données cardiaques triées par timestamp
    var heartRateArray: [HeartRatePoint] {
        let set = heartRates as? Set<HeartRatePoint> ?? []
        return set.sorted { ($0.timestamp ?? Date()) < ($1.timestamp ?? Date()) }
    }
    
    /// Retourne la fréquence cardiaque moyenne pendant l'entraînement
    var averageHeartRate: Double {
        let heartRates = heartRateArray
        guard !heartRates.isEmpty else { return 0 }
        
        let sum = heartRates.reduce(0) { $0 + ($1.value) }
        return sum / Double(heartRates.count)
    }
    
    /// Retourne la fréquence cardiaque maximale pendant l'entraînement
    var maxHeartRate: Double {
        return heartRateArray.map { $0.value }.max() ?? 0
    }
    
    /// Retourne la progression globale de l'entraînement (pourcentage d'exercices terminés)
    var progressPercentage: Double {
        let exercises = exerciseArray
        guard !exercises.isEmpty else { return 0 }
        
        let completedCount = exercises.filter { $0.isCompleted }.count
        return (Double(completedCount) / Double(exercises.count)) * 100
    }
    
    /// Retourne un formatage lisible de la durée
    var formattedDuration: String {
        return HyroxConstants.formatTime(duration)
    }
    
    /// Retourne une représentation lisible de la date
    var formattedDate: String {
        guard let date = date else { return "Date inconnue" }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    /// Crée un nouvel entraînement
    static func create(name: String, date: Date, in context: NSManagedObjectContext) -> Workout {
        let workout = Workout(context: context)
        workout.id = UUID()
        workout.name = name
        workout.date = date
        workout.completed = false
        workout.duration = 0
        workout.distance = 0
        
        return workout
    }
    
    /// Ajoute un exercice à l'entraînement
    func addExercise(name: String) -> Exercise {
        guard let context = self.managedObjectContext else {
            fatalError("No managed object context found")
        }
        
        let exercise = Exercise(context: context)
        exercise.id = UUID()
        exercise.name = name
        exercise.workout = self
        exercise.duration = 0
        exercise.distance = 0
        exercise.repetitions = 0
        exercise.personalBest = false
        
        // Établir la relation bidirectionnelle
        var exercisesSet = self.exercises as? Set<Exercise> ?? Set<Exercise>()
        exercisesSet.insert(exercise)
        self.exercises = exercisesSet as NSSet
        
        return exercise
    }
    
    /// Ajoute des données cardiaques à l'entraînement
    func addHeartRate(value: Double, timestamp: Date) -> HeartRatePoint {
        guard let context = self.managedObjectContext else {
            fatalError("No managed object context found")
        }
        
        let heartRate = HeartRatePoint(context: context)
        heartRate.id = UUID()
        heartRate.value = value
        heartRate.timestamp = timestamp
        heartRate.workout = self
        
        return heartRate
    }
    
    /// Finalise l'entraînement avec les données complètes
    func finish(duration: Double, distance: Double) {
        self.completed = true
        self.duration = duration
        self.distance = distance
        self.endDate = Date()
    }
    
    /// Trouve un exercice spécifique par son nom
    func findExercise(named exerciseName: String) -> Exercise? {
        guard let exercises = self.exercises as? Set<Exercise> else { return nil }
        return exercises.first { $0.name == exerciseName }
    }
    
    /// Calcule le temps total en excluant les pauses
    var effectiveWorkoutTime: TimeInterval {
        return exerciseArray.reduce(0) { $0 + $1.duration }
    }
    
    /// Calcule le temps de pause (différence entre durée totale et temps effectif)
    var pauseTime: TimeInterval {
        let effective = effectiveWorkoutTime
        return duration > effective ? duration - effective : 0
    }
}
