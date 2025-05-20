import Foundation
import CoreData

enum DataSeeder {
    /// Vérifie s’il n’y a pas de Workouts et en crée deux exemples si nécessaire
    static func seedInitialData(in context: NSManagedObjectContext) {
        let request: NSFetchRequest<Workout> = Workout.fetchRequest()
        do {
            let count = try context.count(for: request)
            if count == 0 {
                seedWorkouts(in: context)
            }
        } catch {
            print("DataSeeder – échec du check initial : \(error)")
        }
    }

    private static func seedWorkouts(in context: NSManagedObjectContext) {
        // Premier entraînement complet
        let workout1 = Workout.create(name: "Entraînement complet",
                                      date: Date().addingTimeInterval(-86_400),
                                      in: context)
        workout1.duration = 2_775
        workout1.distance = 7.52
        workout1.completed = true
        workout1.endDate = workout1.date!.addingTimeInterval(2_775)
        addExercises(to: workout1, full: true)

        // Second entraînement partiel
        let workout2 = Workout.create(name: "Entraînement partiel",
                                      date: Date().addingTimeInterval(-259_200),
                                      in: context)
        workout2.duration = 1_200
        workout2.distance = 3.5
        workout2.completed = true
        workout2.endDate = workout2.date!.addingTimeInterval(1_200)
        addExercises(to: workout2, full: false)

        // Seed heart rate data
        seedHeartRates(for: workout1, in: context)
        seedHeartRates(for: workout2, in: context)

        do {
            DataController.shared.saveContext()
            print("DataSeeder – données initiales créées")
        } catch {
            print("DataSeeder – échec du save : \(error)")
        }
    }

    private static func addExercises(to workout: Workout, full: Bool) {
        // Si full=true on ajoute tous les exercices, sinon seulement les 4 premiers
        let definitions = Array(ExerciseDefinitions.all.values)
        let allDefs = Array(ExerciseDefinitions.all.values)
        let slice: [ExerciseDefinition] = full
            ? allDefs
            : Array(allDefs.prefix(4))
        for def in slice {
            let ex = workout.addExercise(name: def.name)
            ex.targetTime = def.targetTime ?? 0
            // initialiser performances à zéro
            ex.duration = 0
            ex.distance = def.standardDistance ?? 0
            ex.repetitions = Int16(def.standardRepetitions ?? 0)
        }
    }

    private static func seedHeartRates(for workout: Workout, in context: NSManagedObjectContext) {
        guard let start = workout.date else { return }
        let duration = workout.duration
        let interval: TimeInterval = duration > 1_800 ? 30 : 10
        let steps = min(100, Int(duration / interval))

        for i in 0..<steps {
            let progress = Double(i) / Double(steps)
            let base: Double = {
                switch progress {
                case 0..<0.2: return 130 + progress * 100
                case 0.8...1: return 170 - (progress - 0.8) * 150
                default:     return 150 + sin(progress * 10) * 15
                }
            }()
            let hr = base + Double.random(in: -8...8)
            _ = workout.addHeartRate(value: hr,
                                     timestamp: start.addingTimeInterval(Double(i) * interval))
        }
    }
}
