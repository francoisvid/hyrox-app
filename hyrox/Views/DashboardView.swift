import SwiftUI

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

                // Objectifs (toujours affichés)
                GoalsSectionView(formatTime: viewModel.formatTime(_:))

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
        let standardOrder = Workout.standardExerciseOrder
        return ExerciseDefinitions.all.values.sorted { def1, def2 in
            guard let index1 = standardOrder.firstIndex(of: def1.name),
                  let index2 = standardOrder.firstIndex(of: def2.name) else {
                return def1.name < def2.name
            }
            return index1 < index2
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
