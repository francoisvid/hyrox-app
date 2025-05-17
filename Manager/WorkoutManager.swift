import CoreData
import Combine

/// Gère toutes les opérations liées aux entraînements et à leur persistance
class WorkoutManager: ObservableObject {
    // MARK: - Properties
    
    private let persistenceController: PersistenceController
    
    // État publié pour l'interface utilisateur
    @Published var workouts: [Workout] = []
    @Published var currentWorkout: Workout?
    @Published var isWorkoutActive = false
    @Published var elapsedTime: TimeInterval = 0
    @Published var personalBests: [String: Exercise] = [:]
    
    // Timers et référence temporelle
    private var timer: Timer?
    private var startTime: Date?
    private var heartRateTimer: Timer?
    
    // MARK: - Initialization
    
    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
        loadWorkouts()
        updatePersonalBests()
    }
    
    deinit {
        stopAllTimers()
    }
    
    // MARK: - Data Operations
    
    /// Charge tous les entraînements depuis Core Data
    func loadWorkouts() {
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<Workout> = Workout.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Workout.date, ascending: false)]
        
        do {
            workouts = try context.fetch(request)
        } catch {
            print("Erreur lors du chargement des entraînements: \(error.localizedDescription)")
        }
    }
    
    /// Met à jour la liste des records personnels
    func updatePersonalBests() {
        personalBests = calculatePersonalBests()
    }
    
    /// Sauvegarde les modifications dans Core Data
    private func saveContext() {
        persistenceController.save()
    }
    
    // MARK: - Workout Actions
    
    /// Démarre un nouvel entraînement Hyrox
    func startNewWorkout(name: String = "Entraînement Hyrox") {
        let context = persistenceController.container.viewContext
        
        // Créer un nouvel entraînement
        let workout = Workout.create(name: name, date: Date(), in: context)
        
        // Ajouter les exercices Hyrox standards avec leurs temps cibles
        for exerciseInfo in HyroxConstants.standardExercises {
            let exercise = workout.addExercise(name: exerciseInfo.name)
            exercise.targetTime = exerciseInfo.targetTime
            
            // Ajouter les valeurs standard selon le type d'exercice
            if let distance = HyroxConstants.standardDistance(for: exerciseInfo.name) {
                exercise.distance = 0 // On initialise à 0, mais on stocke la distance cible
            }
            
            if let reps = HyroxConstants.standardRepetitions(for: exerciseInfo.name) {
                exercise.repetitions = 0 // On initialise à 0, mais on stocke les répétitions cibles
            }
        }
        
        // Sauvegarder dans Core Data
        saveContext()
        
        // Mettre à jour l'état
        currentWorkout = workout
        isWorkoutActive = true
        startTime = Date()
        elapsedTime = 0
        
        // Démarrer les timers
        startWorkoutTimer()
        startHeartRateRecording()
    }
    
    /// Termine l'entraînement actuel
    func endWorkout() {
        guard let workout = currentWorkout, let startTime = startTime else { return }
        
        // Arrêter les timers
        stopAllTimers()
        
        // Calculer la durée finale et la distance totale
        let duration = Date().timeIntervalSince(startTime)
        let totalDistance = calculateTotalDistance(for: workout)
        
        // Mettre à jour l'entraînement
        workout.finish(duration: duration, distance: totalDistance)
        
        // Vérifier et marquer les nouveaux records personnels
        updateRecordsForWorkout(workout)
        
        // Sauvegarder et recharger les données
        saveContext()
        loadWorkouts()
        updatePersonalBests()
        
        // Réinitialiser l'état
        currentWorkout = nil
        isWorkoutActive = false
        elapsedTime = 0
        self.startTime = nil
    }
    
    /// Calcule la distance totale parcourue pendant l'entraînement
    private func calculateTotalDistance(for workout: Workout) -> Double {
        var totalDistance: Double = 0
        
        if let exercises = workout.exercises as? Set<Exercise> {
            for exercise in exercises {
                totalDistance += exercise.distance
            }
        }
        
        return totalDistance
    }
    
    /// Vérifie et marque les nouveaux records personnels
    private func updateRecordsForWorkout(_ workout: Workout) {
        guard let exercises = workout.exercises as? Set<Exercise> else { return }
        
        // Pour chaque exercice de l'entraînement
        for exercise in exercises {
            guard let name = exercise.name, exercise.duration > 0 else { continue }
            
            // Vérifier si c'est un record personnel
            if let existingBest = personalBests[name] {
                if exercise.isBetterThan(existingBest) {
                    // Effacer l'ancien marqueur de record
                    existingBest.personalBest = false
                    
                    // Marquer ce nouvel exercice comme record
                    exercise.personalBest = true
                    personalBests[name] = exercise
                }
            } else {
                // Premier enregistrement pour cet exercice
                exercise.personalBest = true
                personalBests[name] = exercise
            }
        }
    }
    
    /// Met à jour les performances d'un exercice
    func updateExercise(id: UUID, duration: Double, distance: Double = 0, repetitions: Int16 = 0) {
        guard let workout = currentWorkout else { return }
        
        // Trouver l'exercice dans le contexte actuel
        if let exercises = workout.exercises as? Set<Exercise>,
           let exercise = exercises.first(where: { $0.id == id }) {
            
            // Mettre à jour les valeurs
            exercise.duration = duration
            exercise.distance = distance
            exercise.repetitions = repetitions
            
            // Sauvegarder
            saveContext()
        }
    }
    
    // MARK: - Heart Rate
    
    /// Commence l'enregistrement périodique de la fréquence cardiaque simulée
    private func startHeartRateRecording() {
        // Simuler les données cardiaques pour la démo
        // Dans une vraie application, vous utiliseriez HealthKit
        heartRateTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self, let workout = self.currentWorkout else { return }
            
            // Simuler une fréquence cardiaque basée sur le temps écoulé
            let baseHeartRate = 130.0
            let intensity = min(50.0, self.elapsedTime / 60.0) // Augmente jusqu'à +50 bpm sur la durée
            let randomVariation = Double.random(in: -5...5)
            let heartRate = baseHeartRate + intensity + randomVariation
            
            // Enregistrer la valeur
            _ = workout.addHeartRate(value: heartRate, timestamp: Date())
            self.saveContext()
        }
    }
    
    // MARK: - Timers
    
    /// Démarre le timer principal de l'entraînement
    private func startWorkoutTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.startTime else { return }
            self.elapsedTime = Date().timeIntervalSince(startTime)
        }
    }
    
    /// Arrête tous les timers actifs
    private func stopAllTimers() {
        timer?.invalidate()
        timer = nil
        
        heartRateTimer?.invalidate()
        heartRateTimer = nil
    }
    
    // MARK: - Personal Bests
    
    /// Calcule les records personnels pour chaque exercice
    private func calculatePersonalBests() -> [String: Exercise] {
        var bestExercises: [String: Exercise] = [:]
        
        // Parcourir tous les entraînements complétés
        for workout in workouts where workout.completed {
            if let exercises = workout.exercises as? Set<Exercise> {
                for exercise in exercises {
                    guard let name = exercise.name, exercise.duration > 0 else { continue }
                    
                    // Vérifier si cet exercice est meilleur que celui déjà enregistré
                    if let currentBest = bestExercises[name] {
                        if exercise.isBetterThan(currentBest) {
                            bestExercises[name] = exercise
                        }
                    } else {
                        bestExercises[name] = exercise
                    }
                }
            }
        }
        
        return bestExercises
    }
    
    // MARK: - Statistics & Analysis
    
    /// Récupère les statistiques d'entraînement pour une période donnée
    func getWorkoutStatistics(for period: Int) -> [(Date, TimeInterval)] {
        // Filtrer les entraînements selon la période sélectionnée
        let calendar = Calendar.current
        let today = Date()
        
        // Période en mois (3, 6, 12, 24)
        let months = [3, 6, 12, 24][period]
        let startDate = calendar.date(byAdding: .month, value: -months, to: today)!
        
        // Récupérer les entraînements dans cette période, triés par date
        let filteredWorkouts = workouts.filter {
            $0.completed && ($0.date ?? Date()) >= startDate
        }
        
        // Créer les paires date-durée
        return filteredWorkouts.map {
            ($0.date ?? Date(), $0.duration)
        }.sorted { $0.0 < $1.0 }
    }
    
    /// Récupère les exercices les plus performants
    func getTopExercises(limit: Int = 3) -> [(name: String, duration: TimeInterval)] {
        // Utiliser les records personnels
        return personalBests.values
            .sorted { $0.duration < $1.duration } // Trier par durée (plus court = meilleur)
            .prefix(limit)
            .compactMap { exercise in
                guard let name = exercise.name else { return nil }
                return (name, exercise.duration)
            }
    }
    
    // MARK: - Helpers
    
    /// Formate un temps en secondes au format mm:ss
    func formatTime(_ seconds: TimeInterval) -> String {
        return HyroxConstants.formatTime(seconds)
    }
    
    /// Récupère l'exercice avec un ID spécifique dans l'entraînement actuel
    func getExercise(withId id: UUID) -> Exercise? {
        guard let workout = currentWorkout,
              let exercises = workout.exercises as? Set<Exercise> else { return nil }
        
        return exercises.first { $0.id == id }
    }
    
    /// Calcule le temps total d'entraînement
    func getTotalTrainingTime() -> TimeInterval {
        return workouts.reduce(0) { $0 + $1.duration }
    }
    
    /// Récupère le nombre total d'entraînements
    func getTotalWorkoutCount() -> Int {
        return workouts.count
    }
    
    /// Récupère la distance totale parcourue
    func getTotalDistance() -> Double {
        return workouts.reduce(0) { $0 + $1.distance }
    }
}

// MARK: - Exercise Extension
extension Exercise {
    /// Vérifie si cet exercice est meilleur qu'un autre
    func isBetterThan(_ other: Exercise) -> Bool {
        // Pour les exercices de type temps, un temps plus court est meilleur
        return self.duration > 0 && (other.duration <= 0 || self.duration < other.duration)
    }
    
    /// Met à jour les performances d'un exercice
    func updatePerformance(duration: Double, distance: Double = 0, repetitions: Int16 = 0) {
        self.duration = duration
        self.distance = distance
        self.repetitions = repetitions
    }
}
