// DataSeeder.swift
import Foundation
import CoreData

class DataSeeder {
    /// Vérifie si des données existent déjà et ajoute des données initiales si nécessaire
    static func seedInitialData(context: NSManagedObjectContext) {
        // Vérifier si des données existent déjà
        let request: NSFetchRequest<Workout> = Workout.fetchRequest()
        
        do {
            let count = try context.count(for: request)
            
            // Ne seeder que si la base de données est vide
            if count == 0 {
                seedWorkouts(context: context)
            }
        } catch {
            print("Erreur lors de la vérification des données existantes: \(error)")
        }
    }
    
    /// Crée des entraînements d'exemple dans la base de données
    private static func seedWorkouts(context: NSManagedObjectContext) {
        // Exemple pour un entraînement complet
        let workout1 = Workout(context: context)
        workout1.id = UUID()
        workout1.name = "Entraînement complet"
        workout1.date = Date().addingTimeInterval(-86400) // Hier
        workout1.duration = 2775 // 46:15
        workout1.distance = 7.52
        workout1.completed = true
        workout1.endDate = Date().addingTimeInterval(-86400 + 2775) // Date fin = date début + durée
        
        // Ajouter des exercices
        let exerciseData: [(name: String, duration: Double, distance: Double, repetitions: Int16, personalBest: Bool)] = [
            ("SkiErg", 185, 1000, 0, false),
            ("Sled Push", 243, 50, 0, false),
            ("Sled Pull", 258, 50, 0, false),
            ("Burpees Broad Jump", 312, 0, 80, false),
            ("RowErg", 187, 1000, 0, false),
            ("Farmers Carry", 235, 200, 0, false),
            ("Sandbag Lunges", 323, 200, 0, false),
            ("Wall Balls", 209, 0, 75, true)
        ]
        
        // Créer les exercices avec toutes leurs propriétés
        for data in exerciseData {
            let exercise = Exercise(context: context)
            exercise.id = UUID()
            exercise.name = data.name
            exercise.duration = data.duration
            exercise.distance = data.distance
            exercise.repetitions = data.repetitions
            exercise.personalBest = data.personalBest
            exercise.workout = workout1
            
            // Ajouter un temps cible basé sur les standards Hyrox
            if let targetTime = getTargetTimeForExercise(data.name) {
                exercise.targetTime = targetTime
            }
        }
        
        // Ajouter un second entraînement plus récent (mais partiel)
        let workout2 = Workout(context: context)
        workout2.id = UUID()
        workout2.name = "Entraînement partiel"
        workout2.date = Date().addingTimeInterval(-259200) // 3 jours avant
        workout2.duration = 1200 // 20:00
        workout2.distance = 3.5
        workout2.completed = true
        workout2.endDate = Date().addingTimeInterval(-259200 + 1200)
        
        // Ajouter quelques exercices au second entraînement
        let partialExerciseData: [(name: String, duration: Double, distance: Double, repetitions: Int16)] = [
            ("SkiErg", 192, 1000, 0),
            ("Sled Push", 255, 50, 0),
            ("Sled Pull", 267, 50, 0),
            ("Burpees Broad Jump", 325, 0, 80)
        ]
        
        for data in partialExerciseData {
            let exercise = Exercise(context: context)
            exercise.id = UUID()
            exercise.name = data.name
            exercise.duration = data.duration
            exercise.distance = data.distance
            exercise.repetitions = data.repetitions
            exercise.workout = workout2
            
            if let targetTime = getTargetTimeForExercise(data.name) {
                exercise.targetTime = targetTime
            }
        }
        
        // Ajouter les données cardiaques aux deux entraînements
        seedHeartRateData(for: workout1, startTime: workout1.date!, duration: workout1.duration, context: context)
        seedHeartRateData(for: workout2, startTime: workout2.date!, duration: workout2.duration, context: context)
        
        // Sauvegarder le contexte
        do {
            try context.save()
            print("Données initiales chargées avec succès")
        } catch {
            print("Erreur lors du chargement des données initiales: \(error)")
        }
    }
    
    /// Génère des données de fréquence cardiaque simulées pour un entraînement
    private static func seedHeartRateData(for workout: Workout, startTime: Date, duration: Double, context: NSManagedObjectContext) {
        // Réduire le nombre de points pour les grandes durées
        let interval: TimeInterval = duration > 1800 ? 30 : 10 // Moins de points pour les longs entraînements
        let steps = min(100, Int(duration / interval)) // Limiter à un maximum de 100 points
        
        for i in 0..<steps {
            let time = startTime.addingTimeInterval(Double(i) * interval)
            
            // Simuler un profil cardiaque réaliste
            // - Au début : augmentation progressive (échauffement)
            // - Au milieu : valeurs élevées avec fluctuations (effort intense)
            // - À la fin : diminution progressive (récupération)
            let progress = Double(i) / Double(steps)
            let baseValue: Double
            
            if progress < 0.2 {
                // Phase d'échauffement
                baseValue = 130 + (progress * 5 * 20) // Augmentation progressive jusqu'à ~150
            } else if progress > 0.8 {
                // Phase de récupération
                baseValue = 170 - ((progress - 0.8) * 5 * 30) // Diminution progressive depuis ~170
            } else {
                // Phase d'effort intense
                baseValue = 150 + (sin(progress * 10) * 15) // Fluctuation autour de 150-165
            }
            
            // Ajouter une variation aléatoire
            let value = baseValue + Double.random(in: -8...8)
            
            let heartRate = HeartRatePoint(context: context)
            heartRate.id = UUID()
            heartRate.timestamp = time
            heartRate.value = value
            heartRate.workout = workout
        }
    }
    
    /// Retourne le temps cible pour un exercice spécifique
    private static func getTargetTimeForExercise(_ name: String) -> Double? {
        let targetTimes: [String: Double] = [
            "SkiErg": 180,             // 3:00
            "Sled Push": 240,          // 4:00
            "Sled Pull": 240,          // 4:00
            "Burpees Broad Jump": 300, // 5:00
            "RowErg": 180,             // 3:00
            "Farmers Carry": 240,      // 4:00
            "Sandbag Lunges": 300,     // 5:00
            "Wall Balls": 210          // 3:30
        ]
        
        return targetTimes[name]
    }
}
