import CoreData

/// Extension de l'entité Exercise pour ajouter des fonctionnalités utiles
extension Exercise {
    /// Définit cet exercice comme un record personnel
    func setAsPersonalBest() {
        self.personalBest = true
    }
    
    /// Vérifie si cet exercice est considéré comme terminé
    var isCompleted: Bool {
        return duration > 0
    }
    
    /// Pourcentage de complétion par rapport à l'objectif
    var completionPercentage: Double {
        // Vérifier si targetTime est défini et positif
        if targetTime <= 0 { return 0 }
        
        // Récupérer le nom de l'exercice avec gestion des optionnels
        let exerciseName = name ?? ""
        
        if HyroxConstants.isDistanceBased(exerciseName) {
            // Pour les exercices basés sur la distance
            guard let standardDistance = HyroxConstants.standardDistance(for: exerciseName), standardDistance > 0 else { return 0 }
            return min(1.0, distance / standardDistance) * 100
        } else if HyroxConstants.isRepetitionBased(exerciseName) {
            // Pour les exercices basés sur les répétitions
            guard let standardReps = HyroxConstants.standardRepetitions(for: exerciseName), standardReps > 0 else { return 0 }
            return min(1.0, Double(repetitions) / Double(standardReps)) * 100
        } else {
            // Par défaut, basé sur le temps (inverse car un temps plus court est meilleur)
            return targetTime > 0 ? min(1.0, targetTime / duration) * 100 : 0
        }
    }
    
    /// Formatage du temps au format mm:ss
    var formattedDuration: String {
        return HyroxConstants.formatTime(duration)
    }
    
    /// Formatage du temps cible au format mm:ss
    var formattedTargetTime: String {
        // Si targetTime est 0, retourner une valeur par défaut
        if targetTime <= 0 { return "--:--" }
        return HyroxConstants.formatTime(targetTime)
    }
    
    /// Description formatée de la performance
    var performanceSummary: String {
        // Récupérer le nom de l'exercice avec gestion des optionnels
        let exerciseName = name ?? ""
        
        if HyroxConstants.isDistanceBased(exerciseName) {
            return "\(Int(distance))m en \(formattedDuration)"
        } else if HyroxConstants.isRepetitionBased(exerciseName) {
            return "\(repetitions) reps en \(formattedDuration)"
        } else {
            return formattedDuration
        }
    }
}
