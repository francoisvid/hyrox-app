import CoreData

extension Exercise {
    /// Marque cet exercice comme record personnel
    func setAsPersonalBest() {
        personalBest = true
    }

    /// Est-ce que l’exercice est terminé ?
    var isCompleted: Bool {
        duration > 0
    }

    /// Pourcentage de complétion (%)
    var completionPercentage: Double {
        guard
            let name = name,
            let def = ExerciseDefinitions.all[name],
            let target = def.targetTime,
            target > 0
        else { return 0 }

        if def.isDistanceBased, let std = def.standardDistance, std > 0 {
            return min(1, distance / std) * 100
        }
        if def.isRepetitionBased, let reps = def.standardRepetitions, reps > 0 {
            return min(1, Double(repetitions) / Double(reps)) * 100
        }
        return min(1, target / duration) * 100
    }

    /// Durée formatée mm:ss
    var formattedDuration: String {
        TimeFormatter.formatTime(duration)
    }

    /// Temps cible formaté mm:ss
    var formattedTargetTime: String {
        guard
            let name = name,
            let def = ExerciseDefinitions.all[name],
            let target = def.targetTime,
            target > 0
        else { return "--:--" }
        return TimeFormatter.formatTime(target)
    }

    /// Résumé de la performance (“1000m en 03:00”, “75 reps en 04:00”, ou “03:00”)
    var performanceSummary: String {
        guard
            let name = name,
            let def = ExerciseDefinitions.all[name]
        else { return formattedDuration }

        if def.isDistanceBased {
            return "\(Int(distance))m en \(formattedDuration)"
        }
        if def.isRepetitionBased {
            return "\(repetitions) reps en \(formattedDuration)"
        }
        return formattedDuration
    }
    
    func updatePerformance(duration: Double, distance: Double = 0, repetitions: Int16 = 0) {
          self.duration = duration
          self.distance = distance
          self.repetitions = Int16(repetitions)
      }
}
