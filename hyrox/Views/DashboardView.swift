import SwiftUI
import CoreData

// Définition d'une structure pour les événements
struct HyroxEvent: Identifiable {
    let id = UUID()
    let imageName: String
    let locationCode: String
    let name: String
    let dateRange: String
    let registrationURL: URL?
}

// Vue pour afficher une carte d'événement
private struct EventCardView: View {
    let event: HyroxEvent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(event.imageName)
                .resizable()
                .scaledToFit()
                .cornerRadius(12)
                .opacity(0.8)
                .overlay(alignment: .topLeading) {
                    Text(event.locationCode)
                        .font(.caption).bold()
                        .foregroundColor(.white)
                        .padding(4)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(4)
                        .padding(8)
                }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(event.name)
                    .font(.headline).bold()
                    .foregroundColor(.white)
                Text(event.dateRange)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal)
            
            // Bouton d'inscription
            if let url = event.registrationURL {
                Link(destination: url) {
                    Text("S'INSCRIRE !")
                        .font(.caption).bold()
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.yellow)
                        .cornerRadius(8)
                }
                .padding(.horizontal)
            }
        }
        .padding(.bottom)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

class GoalsViewModel: ObservableObject {
    @Published var goals: [String: TimeInterval] = [:]
    
    init() {
        refreshGoals()
    }
    
    func refreshGoals() {
        goals = GoalsManager.shared.getAllGoals()
    }
    
    func setGoal(for exerciseName: String, targetTime: TimeInterval) {
        GoalsManager.shared.setGoalFor(exerciseName: exerciseName, targetTime: targetTime)
        refreshGoals()
    }
}

struct DashboardView: View {
    @ObservedObject var viewModel: WorkoutViewModel
    @Environment(\.managedObjectContext) private var viewContext

    // Liste fictive des prochains événements
    private let upcomingEvents: [HyroxEvent] = [
        HyroxEvent(
            imageName: "hyrox_prs", // Assurez-vous que ces images sont dans vos Assets
            locationCode: "PAR",
            name: "FITNESS PARK HYROX PARIS",
            dateRange: "23. Oct. 2025 – 26. Oct. 2025",
            registrationURL: URL(string: "https://hyroxfrance.com/fr/trouve-ta-course/?filter_region=france") // Remplacez par l'URL réelle
        ),
        HyroxEvent(
            imageName: "hyrox_bdx", // Assurez-vous que ces images sont dans vos Assets
            locationCode: "BDX",
            name: "HYROX BORDEAUX",
            dateRange: "20. Nov. 2025 – 23. Nov. 2025",
            registrationURL: URL(string: "https://hyroxfrance.com/fr/trouve-ta-course/?filter_region=france") // Remplacez par l'URL réelle
        )
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Dashboard")
                    .font(.largeTitle).bold()
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Dernier entraînement
                if viewModel.workouts.isEmpty {
                    NoDataView()
                } else if let workout = viewModel.workouts.first {
                    WorkoutSummaryView(
                        workout: workout,
                        bestTimes: viewModel.personalBests,
                        formatTime: viewModel.formatTime(_:)
                    )
                }
                
                #if DEBUG
                Button("Test Start Workout") {
                    viewModel.startNewWorkout(name: "Test Sync Firebase")
                }
                .padding()
                .background(Color.yellow)
                .foregroundColor(.black)
                .cornerRadius(8)
                #endif

                // Section des prochains événements
                VStack(alignment: .leading, spacing: 12) {
                    Text("Prochains Événements HYROX France")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    ForEach(upcomingEvents) { event in
                        EventCardView(event: event)
                    }
                }

                // Timer actif
                if viewModel.isActive {
                    ActiveTimerView(
                        elapsedTime: viewModel.elapsedTime,
                        currentExercise: viewModel.currentExercises
                            .first { exercise in
                                viewModel.isNext(exercise)
                            }?
                            .name ?? "En cours",
                        formatTime: viewModel.formatTime(_:)
                    )
                }
            }
            .padding()
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            viewModel.reloadWorkouts()
        }
    }
}

// MARK: - No Data View

private struct NoDataView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.run.circle")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            
            Text("Commencez votre premier entraînement")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Vos statistiques apparaîtront ici")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Sous-vues

private struct WorkoutSummaryView: View {
    let workout: Workout
    let bestTimes: [String: Exercise]
    let formatTime: (TimeInterval) -> String
    
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium; f.timeStyle = .short
        return f
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dernier entraînement")
                .font(.headline).foregroundColor(.gray)
            
            HStack {
                Text(formatTime(workout.duration))
                    .font(.system(size: 42, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
            }
            
            // Distance (seulement si disponible)
            if workout.distance > 0 {
                Text("\(String(format: "%.2f", workout.distance / 1000)) km")
                    .foregroundColor(.gray)
            }
            
            // Liste des exercices et records
            ForEach(workout.exerciseArray.sorted(by: { ($0.date ?? Date()) < ($1.date ?? Date()) }), id: \.id) { ex in
                HStack {
                    Text(ex.name ?? "")
                        .foregroundColor(.gray)
                        .font(.subheadline)
                    Spacer()
                    Text(formatTime(ex.duration))
                        .foregroundColor(.white)
                        .font(.subheadline)
                    if let best = bestTimes[ex.name ?? ""]?.duration, best > 0 {
                        Text(formatTime(best))
                            .foregroundColor(.yellow)
                            .font(.subheadline)
                    }
                }
                .padding(.vertical, 2)
            }
            
            Divider()
                .background(Color.gray.opacity(0.5))
                .padding(.vertical, 4)
            
            // Date du workout
            Text(Self.dateFormatter.string(from: workout.date ?? Date()))
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - ChartView

private struct ChartView: View {
    let data: [Double]

    private var average: Double { data.isEmpty ? 0 : data.reduce(0,+)/Double(data.count) }
    private var maxValue: Double { data.max() ?? 1 }
    private var minValue: Double { data.min() ?? 0 }

    var body: some View {
        GeometryReader { geo in
            Path { path in
                let points = normalizedPoints(width: geo.size.width, height: geo.size.height)
                guard !points.isEmpty else { return }
                path.move(to: points[0])
                for pt in points.dropFirst() { path.addLine(to: pt) }
            }
            .stroke(Color.yellow, lineWidth: 2)
        }
    }

    private func normalizedPoints(width: CGFloat, height: CGFloat) -> [CGPoint] {
        guard data.count > 1 else { return [] }
        let range = maxValue - minValue
        return data.enumerated().map { i, v in
            let x = width * CGFloat(i) / CGFloat(data.count - 1)
            let y = height * (1 - CGFloat((v - minValue) / range))
            return CGPoint(x: x, y: y)
        }
    }
}


private struct GoalsSectionView: View {
    let formatTime: (TimeInterval) -> String
    @StateObject private var viewModel = GoalsViewModel()
    @State private var editingGoal: String? = nil
    @State private var newGoalMinutes: Double = 0
    
    // Trier les exercices selon l'ordre standard
    private var sortedExercises: [ExerciseDefinition] {
        Workout.standardExerciseOrder.compactMap { name in
            ExerciseDefinitions.all[name]
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Objectifs HYROX")
                .font(.headline).foregroundColor(.white)
            
            ForEach(sortedExercises, id: \.name) { def in
                HStack {
                    Text(def.name)
                        .foregroundColor(.white)
                    Spacer()
                    if editingGoal == def.name {
                        HStack(spacing: 4) {
                            TextField("Minutes", value: $newGoalMinutes, format: .number)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 80)
                            Text("min")
                                .foregroundColor(.gray)
                        }
                        .onSubmit {
                            // Convertir les minutes en secondes
                            let seconds = newGoalMinutes * 60
                            viewModel.setGoal(for: def.name, targetTime: seconds)
                            editingGoal = nil
                        }
                    } else {
                        let currentGoal = viewModel.goals[def.name] ?? 0
                        if currentGoal > 0 {
                            Text("< \(formatTime(currentGoal))")
                                .foregroundColor(.yellow)
                        } else {
                            Text("--:--")
                                .foregroundColor(.gray)
                        }
                    }
                    Button(action: {
                        if editingGoal == def.name {
                            // Convertir les minutes en secondes
                            let seconds = newGoalMinutes * 60
                            viewModel.setGoal(for: def.name, targetTime: seconds)
                            editingGoal = nil
                        } else {
                            editingGoal = def.name
                            // Convertir les secondes en minutes
                            newGoalMinutes = (viewModel.goals[def.name] ?? 0) / 60
                        }
                    }) {
                        Image(systemName: editingGoal == def.name ? "checkmark.circle" : "pencil.circle")
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
        .onAppear {
            viewModel.refreshGoals()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("GoalsUpdated"))) { _ in
            viewModel.refreshGoals()
        }
    }
}

private struct ActiveTimerView: View {
    let elapsedTime: TimeInterval
    let currentExercise: String
    let formatTime: (TimeInterval) -> String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(formatTime(elapsedTime))
                .font(.system(size: 42, weight: .bold))
                .foregroundColor(.white)
            Text(currentExercise)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}


private struct PlaceholderCard: View {
    let text: String
    
    var body: some View {
        VStack {
            Text(text)
                .foregroundColor(.gray)
                .padding()
        }
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    let context = DataController.shared.container.viewContext
    let workoutManager = WorkoutManager(dataController: DataController.shared)
    let viewModel = WorkoutViewModel(workoutManager: workoutManager)
    
    return DashboardView(viewModel: viewModel)
        .environment(\.managedObjectContext, context)
}
