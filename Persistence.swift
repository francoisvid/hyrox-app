import CoreData

class PersistenceController {
    static let shared = PersistenceController()
    
    let container: NSPersistentContainer
    
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "hyrox")
        
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Erreur au chargement du Core Data stack: \(error.localizedDescription)")
            }
        }
        
        // Configuration pour la fusion automatique des changements
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    // Créer un contexte de background pour les opérations en arrière-plan
    func backgroundContext() -> NSManagedObjectContext {
        return container.newBackgroundContext()
    }
    
    // Sauvegarder le contexte (utilisé pour les opérations simples)
    func save() {
        if container.viewContext.hasChanges {
            do {
                try container.viewContext.save()
            } catch {
                print("Erreur lors de la sauvegarde du contexte: \(error)")
            }
        }
    }
    
    func createDemoDataIfNeeded() {
        let fetchRequest: NSFetchRequest<Workout> = Workout.fetchRequest()
        
        do {
            let count = try container.viewContext.count(for: fetchRequest)
            
            if count == 0 {
                createDemoData()
            }
        } catch {
            print("Erreur lors de la vérification des données d'exemple: \(error)")
        }
    }
    
    private func createDemoData() {
            // Créer un entraînement exemple terminé
            let workout = Workout.create(
                name: "Premier entraînement Hyrox",
                date: Date().addingTimeInterval(-86400), // Hier
                in: container.viewContext
            )
            
            // Ajouter les exercices standard
            let exerciseDurations: [Double] = [185, 243, 258, 312, 187, 235, 323, 209]
            let exerciseDistances: [Double] = [1000, 50, 50, 0, 1000, 200, 200, 0]
            let exerciseReps: [Int16] = [0, 0, 0, 80, 0, 0, 0, 75]
            
            for (index, exerciseInfo) in HyroxConstants.standardExercises.enumerated() {
                let exercise = workout.addExercise(name: exerciseInfo.name)
                exercise.targetTime = exerciseInfo.targetTime
                
                // Ajouter des performances si nous avons des données pour cet indice
                if index < exerciseDurations.count {
                    exercise.duration = exerciseDurations[index]
                    exercise.distance = exerciseDistances[index]
                    exercise.repetitions = exerciseReps[index]
                }
            }
            
            // Marquer l'entraînement comme terminé
            workout.duration = 2775 // 46:15
            workout.distance = 7.52
            workout.completed = true
            workout.endDate = Date().addingTimeInterval(-84600) // Hier + durée
            
            // Ajouter quelques données cardiaques simulées
            let startTime = workout.date!
            let interval: TimeInterval = 30 // Un point toutes les 30 secondes pour limiter la quantité
            let steps = Int(workout.duration / interval)
            
            for i in 0..<steps {
                let time = startTime.addingTimeInterval(Double(i) * interval)
                // Base + variation aléatoire
                let value = 150.0 + Double.random(in: -20...30)
                
                let heartRate = HeartRatePoint(context: container.viewContext)
                heartRate.id = UUID()
                heartRate.timestamp = time
                heartRate.value = value
                heartRate.workout = workout
            }
            
            // Sauvegarder le contexte
            save()
            print("Données d'exemple créées avec succès")
        }
}
