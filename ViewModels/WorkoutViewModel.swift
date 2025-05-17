import Foundation
import Combine

/// ViewModel pour la gestion des entraînements en cours
class WorkoutViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// Exercice actuellement sélectionné
    @Published var selectedExercise: Exercise?
    
    /// État d'édition d'un exercice
    @Published var isEditingExercise: Bool = false
    
    /// Progression actuelle de l'entraînement (pourcentage)
    @Published var workoutProgress: Double = 0
    
    // MARK: - Private Properties
    
    private var workoutManager: WorkoutManager
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(workoutManager: WorkoutManager) {
        self.workoutManager = workoutManager
        
        // Observer les changements dans le WorkoutManager
        setupObservers()
    }
    
    private func setupObservers() {
        // Observer l'entraînement actuel pour mettre à jour la progression
        workoutManager.$currentWorkout
            .combineLatest(workoutManager.$isWorkoutActive)
            .receive(on: RunLoop.main)
            .sink { [weak self] workout, isActive in
                guard let self = self else { return }
                
                if let workout = workout, isActive {
                    self.updateWorkoutProgress(workout)
                } else {
                    self.workoutProgress = 0
                }
            }
            .store(in: &cancellables)
        
        // Observer le temps écoulé pour mettre à jour la progression
        workoutManager.$elapsedTime
            .throttle(for: .seconds(1), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] _ in
                guard let self = self,
                      let workout = self.workoutManager.currentWorkout,
                      self.workoutManager.isWorkoutActive else { return }
                
                self.updateWorkoutProgress(workout)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Accessors
    
    /// Liste de tous les entraînements
    var workouts: [Workout] {
        workoutManager.workouts
    }
    
    /// Entraînement actuellement en cours
    var currentWorkout: Workout? {
        workoutManager.currentWorkout
    }
    
    /// Indique si un entraînement est en cours
    var isWorkoutActive: Bool {
        workoutManager.isWorkoutActive
    }
    
    /// Temps écoulé depuis le début de l'entraînement
    var elapsedTime: TimeInterval {
        workoutManager.elapsedTime
    }
    
    /// Récupère les exercices de l'entraînement actuel dans l'ordre Hyrox
    var currentExercises: [Exercise] {
        currentWorkout?.orderedExercises ?? []
    }
    
    /// Nombre d'exercices terminés dans l'entraînement actuel
    var completedExercisesCount: Int {
        currentExercises.filter { $0.duration > 0 }.count
    }
    
    // MARK: - Workout Actions
    
    /// Démarre un nouvel entraînement
    func startWorkout() {
        workoutManager.startNewWorkout()
    }
    
    /// Termine l'entraînement en cours
    func endWorkout() {
        workoutManager.endWorkout()
    }
    
    /// Sélectionne un exercice pour modification
    func selectExercise(_ exercise: Exercise) {
        selectedExercise = exercise
        isEditingExercise = true
    }
    
    /// Enregistre les performances d'un exercice
    func completeExercise(duration: TimeInterval, distance: Double = 0, repetitions: Int = 0) {
        guard let exercise = selectedExercise else { return }
        
        workoutManager.updateExercise(
            id: exercise.id ?? UUID(),
            duration: duration,
            distance: distance,
            repetitions: Int16(repetitions)
        )
        
        // Mettre à jour la progression
        if let workout = currentWorkout {
            updateWorkoutProgress(workout)
        }
        
        // Réinitialiser l'état
        selectedExercise = nil
        isEditingExercise = false
    }
    
    /// Annule la sélection d'exercice
    func cancelExerciseSelection() {
        selectedExercise = nil
        isEditingExercise = false
    }
    
    // MARK: - Helper Methods
    
    /// Formate un temps en secondes au format mm:ss
    func formatTime(_ seconds: TimeInterval) -> String {
        return HyroxConstants.formatTime(seconds)
    }
    
    /// Vérifie si un exercice est terminé
    func isExerciseCompleted(_ exercise: Exercise) -> Bool {
        return exercise.duration > 0
    }
    
    /// Vérifie si un exercice est le prochain à faire
    func isNextExercise(_ exercise: Exercise) -> Bool {
        guard let workout = currentWorkout else { return false }
        
        let orderedExercises = workout.orderedExercises
        
        // Trouver l'index du premier exercice non complété
        if let nextIndex = orderedExercises.firstIndex(where: { $0.duration <= 0 }),
           let exerciseIndex = orderedExercises.firstIndex(where: { $0.id == exercise.id }) {
            return exerciseIndex == nextIndex
        }
        
        return false
    }
    
    /// Met à jour la progression de l'entraînement
    private func updateWorkoutProgress(_ workout: Workout) {
        let totalExercises = workout.exerciseArray.count
        guard totalExercises > 0 else {
            workoutProgress = 0
            return
        }
        
        let completedCount = workout.exerciseArray.filter { $0.duration > 0 }.count
        workoutProgress = Double(completedCount) / Double(totalExercises) * 100
    }
    
    // MARK: - Data Retrieval
    
    /// Récupère un exercice par son ID
    func getExercise(withId id: UUID) -> Exercise? {
        return currentWorkout?.exerciseArray.first(where: { $0.id == id })
    }
    
    /// Récupère les détails standards d'un exercice
    func getExerciseDetails(for exerciseName: String) -> (distance: Double?, repetitions: Int?, description: String?) {
        let distance = HyroxConstants.standardDistance(for: exerciseName)
        let repetitions = HyroxConstants.standardRepetitions(for: exerciseName)
        let description = HyroxConstants.description(for: exerciseName)
        
        return (distance, repetitions, description)
    }
    
    /// Détermine si un exercice est basé sur la distance
    func isDistanceBasedExercise(_ exerciseName: String) -> Bool {
        return HyroxConstants.isDistanceBased(exerciseName)
    }
    
    /// Détermine si un exercice est basé sur les répétitions
    func isRepetitionBasedExercise(_ exerciseName: String) -> Bool {
        return HyroxConstants.isRepetitionBased(exerciseName)
    }
    
    /// Temps estimé restant de l'entraînement (basé sur les exercices non complétés)
    var estimatedRemainingTime: TimeInterval {
        guard let workout = currentWorkout else { return 0 }
        
        // Somme des temps cibles des exercices non complétés
        return workout.exerciseArray
            .filter { $0.duration <= 0 }
            .reduce(0) { $0 + ($1.targetTime > 0 ? $1.targetTime : 240) }
    }
    
    /// Temps estimé total de l'entraînement
    var estimatedTotalTime: TimeInterval {
        guard let workout = currentWorkout else { return 0 }
        
        // Somme des temps complétés + temps cibles restants
        let completedTime = workout.exerciseArray
            .filter { $0.duration > 0 }
            .reduce(0) { $0 + $1.duration }
        
        return completedTime + estimatedRemainingTime
    }
}
