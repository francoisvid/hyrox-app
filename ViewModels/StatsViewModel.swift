import SwiftUI
import Combine

/// ViewModel pour l'affichage des statistiques d'entraînement
class StatsViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// Période sélectionnée pour les statistiques (0: 3 mois, 1: 6 mois, 2: 1 an, 3: 2 ans)
    @Published var selectedPeriod: Int = 0
    
    /// Records personnels par nom d'exercice
    @Published var personalBests: [String: Exercise] = [:]
    
    /// Données filtrées pour le graphique
    @Published var chartData: [(Date, TimeInterval)] = []
    
    /// Statistiques globales
    @Published var totalWorkouts: Int = 0
    @Published var totalTime: TimeInterval = 0
    @Published var totalDistance: Double = 0
    
    // MARK: - Private Properties
    
    private var workoutManager: WorkoutManager
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(workoutManager: WorkoutManager) {
        self.workoutManager = workoutManager
        
        // S'abonner aux changements des entraînements
        workoutManager.$workouts
            .receive(on: RunLoop.main)
            .sink { [weak self] workouts in
                guard let self = self else { return }
                self.calculatePersonalBests(from: workouts)
                self.updateChartData()
                self.updateStatistics(workouts: workouts)
                self.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        // Charger les données initiales
        calculatePersonalBests(from: workoutManager.workouts)
        updateChartData()
        updateStatistics(workouts: workoutManager.workouts)
    }
    
    // MARK: - Data Updates
    
    /// Calcule les records personnels à partir des entraînements
    private func calculatePersonalBests(from workouts: [Workout]) {
        var bestExercises: [String: Exercise] = [:]
        
        // Parcourir tous les entraînements complétés
        for workout in workouts where workout.completed {
            for exercise in workout.exerciseArray {
                guard let name = exercise.name, exercise.duration > 0 else { continue }
                
                // Vérifier si cet exercice est meilleur que celui actuellement enregistré
                if let currentBest = bestExercises[name] {
                    if exercise.isBetterThan(currentBest) {
                        bestExercises[name] = exercise
                    }
                } else {
                    bestExercises[name] = exercise
                }
            }
        }
        
        self.personalBests = bestExercises
    }
    
    /// Met à jour les statistiques globales
    private func updateStatistics(workouts: [Workout]) {
        let completedWorkouts = workouts.filter { $0.completed }
        
        totalWorkouts = completedWorkouts.count
        totalTime = completedWorkouts.reduce(0) { $0 + $1.duration }
        totalDistance = completedWorkouts.reduce(0) { $0 + $1.distance }
    }
    
    // MARK: - Accessors
    
    /// Récupère la liste des entraînements depuis le WorkoutManager
    var workouts: [Workout] {
        workoutManager.workouts
    }
    
    /// Récupère les entraînements complets uniquement
    var completedWorkouts: [Workout] {
        workoutManager.workouts.filter { $0.completed }
    }
    
    /// Récupère les entraînements filtrés selon la période courante
    var filteredWorkouts: [Workout] {
        let calendar = Calendar.current
        let today = Date()
        
        let periodInMonths = getPeriodInMonths()
        let startDate = calendar.date(byAdding: .month, value: -periodInMonths, to: today)!
        
        return workoutManager.workouts.filter {
            $0.completed && ($0.date ?? Date()) >= startDate
        }.sorted { ($0.date ?? Date()) > ($1.date ?? Date()) }
    }
    
    // MARK: - Chart Data
    
    /// Récupère les données pour le graphique, filtrées selon la période sélectionnée
    func getChartData() -> [(Date, TimeInterval)] {
        return chartData
    }
    
    /// Met à jour les données du graphique selon la période sélectionnée
    func updateChartData() {
        chartData = workoutManager.getWorkoutStatistics(for: selectedPeriod)
    }
    
    /// Récupère la durée en mois de la période sélectionnée
    func getPeriodInMonths() -> Int {
        switch selectedPeriod {
        case 0: return 3
        case 1: return 6
        case 2: return 12
        case 3: return 24
        default: return 3
        }
    }
    
    /// Change la période sélectionnée et met à jour les données
    func selectPeriod(_ period: Int) {
        selectedPeriod = period
        updateChartData()
        objectWillChange.send()
    }
    
    // MARK: - Analysis
    
    /// Récupère les exercices les plus performants
    func getTopExercises(limit: Int = 3) -> [Exercise] {
        return Array(personalBests.values)
            .sorted { $0.duration < $1.duration }
            .prefix(limit)
            .compactMap { $0 }
    }
    
    /// Récupère les données pour la comparaison entre le dernier et l'avant-dernier entraînement
    func getComparisonData() -> (latest: Workout?, previous: Workout?) {
        let completed = workouts.filter { $0.completed }
        guard completed.count >= 2 else { return (completed.first, nil) }
        
        return (completed[0], completed[1])
    }
    
    /// Calcule l'amélioration entre deux entraînements (valeur négative = amélioration)
    func calculateImprovement(from previous: Workout?, to latest: Workout?) -> TimeInterval {
        guard let previous = previous, let latest = latest else { return 0 }
        return latest.duration - previous.duration
    }
    
    /// Vérifie si une amélioration est positive (temps plus court)
    func isImprovement(_ value: TimeInterval) -> Bool {
        return value < 0
    }
    
    /// Récupère l'historique d'un exercice spécifique dans les derniers entraînements
    func getExerciseHistory(name: String, limit: Int = 5) -> [(Exercise, Date)] {
        var result: [(Exercise, Date)] = []
        
        for workout in workouts.filter({ $0.completed }).prefix(limit) {
            if let exercise = workout.findExercise(named: name),
               let date = workout.date,
               exercise.duration > 0 {
                result.append((exercise, date))
            }
        }
        
        return result
    }
    
    // MARK: - Formatting Helpers
    
    /// Formate une durée en format mm:ss
    func formatTime(_ seconds: TimeInterval) -> String {
        return HyroxConstants.formatTime(seconds)
    }
    
    /// Formate une date en format court
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
