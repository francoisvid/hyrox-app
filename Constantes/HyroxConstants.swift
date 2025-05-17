import Foundation

/// Constantes et méthodes utilitaires pour les exercices Hyrox
struct HyroxConstants {
    // Exercices Hyrox standards avec temps cibles (en secondes)
    static let standardExercises: [(name: String, targetTime: Double, description: String)] = [
        ("SkiErg", 180.0, "1000m sur la machine SkiErg"),              // 3:00
        ("Sled Push", 240.0, "50m de poussée de traîneau"),            // 4:00
        ("Sled Pull", 240.0, "50m de traction de traîneau"),           // 4:00
        ("Burpees Broad Jump", 300.0, "80 répétitions"),                // 5:00
        ("RowErg", 180.0, "1000m sur rameur"),                         // 3:00
        ("Farmers Carry", 240.0, "200m de transport de poids"),         // 4:00
        ("Sandbag Lunges", 300.0, "200m de fentes avec sac de sable"),  // 5:00
        ("Wall Balls", 210.0, "75 répétitions")                        // 3:30
    ]
    
    /// Les distances standard pour les exercices basés sur la distance (en mètres)
    static let standardDistances: [String: Double] = [
        "SkiErg": 1000.0,
        "Sled Push": 50.0,
        "Sled Pull": 50.0,
        "RowErg": 1000.0,
        "Farmers Carry": 200.0,
        "Sandbag Lunges": 200.0
    ]
    
    /// Les répétitions standard pour les exercices basés sur les répétitions
    static let standardRepetitions: [String: Int] = [
        "Burpees Broad Jump": 80,
        "Wall Balls": 75
    ]
    
    /// Les poids standard pour les exercices (en kg) - hommes
    static let standardWeightsMale: [String: Double] = [
        "Sled Push": 175.0,
        "Sled Pull": 125.0,
        "Farmers Carry": 32.0,
        "Sandbag Lunges": 20.0,
        "Wall Balls": 6.0
    ]
    
    /// Les poids standard pour les exercices (en kg) - femmes
    static let standardWeightsFemale: [String: Double] = [
        "Sled Push": 125.0,
        "Sled Pull": 75.0,
        "Farmers Carry": 24.0,
        "Sandbag Lunges": 12.0,
        "Wall Balls": 4.0
    ]
    
    /// Récupérer uniquement les noms des exercices dans l'ordre standard
    static var exerciseNames: [String] {
        return standardExercises.map { $0.name }
    }
    
    /// Récupérer le temps cible pour un exercice donné
    static func targetTime(for exerciseName: String) -> Double? {
        return standardExercises.first { $0.name == exerciseName }?.targetTime
    }
    
    /// Récupérer la description pour un exercice donné
    static func description(for exerciseName: String) -> String? {
        return standardExercises.first { $0.name == exerciseName }?.description
    }
    
    /// Récupérer la distance standard pour un exercice (en mètres)
    static func standardDistance(for exerciseName: String) -> Double? {
        return standardDistances[exerciseName]
    }
    
    /// Récupérer le nombre de répétitions standard pour un exercice
    static func standardRepetitions(for exerciseName: String) -> Int? {
        return standardRepetitions[exerciseName]
    }
    
    /// Détermine si un exercice est basé sur la distance
    static func isDistanceBased(_ exerciseName: String) -> Bool {
        return standardDistances[exerciseName] != nil
    }
    
    /// Détermine si un exercice est basé sur les répétitions
    static func isRepetitionBased(_ exerciseName: String) -> Bool {
        return standardRepetitions[exerciseName] != nil
    }
    
    /// Récupérer le poids standard pour un exercice selon le genre
    static func standardWeight(for exerciseName: String, isMale: Bool) -> Double? {
        return isMale ? standardWeightsMale[exerciseName] : standardWeightsFemale[exerciseName]
    }
    
    /// Formater un temps en secondes en format mm:ss
    static func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let seconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
