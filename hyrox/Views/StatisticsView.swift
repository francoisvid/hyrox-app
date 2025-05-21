// Views/StatisticsView.swift

import SwiftUI

struct StatisticsView: View {
    @ObservedObject var viewModel: StatsViewModel
    @ObservedObject var wvm: WorkoutViewModel
    @State private var showDeleteAllAlert = false
    @State private var debugMessage: String = ""
    @State private var showDebug: Bool = false

    private static let longDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()
    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        return f
    }()

    private let periods = ["3 mois", "6 mois", "1 an", "2 ans"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                if viewModel.workouts.isEmpty {
                    NoDataView()
                } else {
                    PeriodPickerView(
                        periods: periods,
                        selectedIndex: $viewModel.selectedPeriodIndex
                    )

                    StatsChartView(data: viewModel.chartData, formatter: Self.shortDateFormatter)
                        .padding(12)
                        .frame(height: 250)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)

                    HistorySectionView(
                        workouts: viewModel.workouts,
                        personalBests: viewModel.personalBests,
                        formatter: { Self.longDateFormatter.string(from: $0) },
                        onDelete: viewModel.deleteWorkout
                    )

                    let comp = viewModel.comparison()
                    if let prev = comp.previous, let latest = comp.latest {
                        ComparisonSectionView(
                            previous: prev,
                            latest: latest,
                            longFormatter: Self.longDateFormatter,
                            shortFormatter: Self.shortDateFormatter,
                            formatTime: viewModel.formatTime(_:)
                        )
                    }
                }
            }
            .padding()
        }
        .background(Color.black.ignoresSafeArea())
        .alert("Supprimer toutes les séances",
               isPresented: $showDeleteAllAlert) {
            Button("Annuler", role: .cancel) {}
            Button("Supprimer", role: .destructive) {
                viewModel.deleteAllWorkouts()
            }
        } message: {
            Text("Cette action supprimera toutes les séances définitivement.")
        }
        .refreshable {
            viewModel.reloadStats()
        }
    }

    private var header: some View {
        HStack {
            Text("Statistiques")
                .font(.largeTitle).bold()
                .foregroundColor(.white)
            Spacer()
            Button {
                showDeleteAllAlert = true
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.red)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .clipShape(Circle())
            }
        }
    }
    
    func clearAllData() {
        debugMessage = "Suppression de toutes les données..."
        showDebug = true
        
        // Appeler la méthode de DataController
        DataController.shared.clearAllData()
        
        // Recharger les données dans le ViewModel
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.wvm.reloadWorkouts()
            self.debugMessage = "✅ Toutes les données ont été effacées"
            
            // Masquer le message après quelques secondes
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.showDebug = false
            }
        }
    }
}

// MARK: - Period Picker

private struct PeriodPickerView: View {
    let periods: [String]
    @Binding var selectedIndex: Int

    var body: some View {
        HStack {
            ForEach(periods.indices, id: \.self) { idx in
                Button(periods[idx]) {
                    selectedIndex = idx
                    // viewModel will react to selectedPeriodIndex binding
                }
                .font(.subheadline)
                .foregroundColor(selectedIndex == idx ? .yellow : .gray)
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(
                    selectedIndex == idx ? Color.yellow.opacity(0.2) : Color.clear
                )
                .cornerRadius(8)
            }
        }
    }
}

// MARK: - Chart View

private struct StatsChartView: View {
    let data: [(Date, TimeInterval)]
    let formatter: DateFormatter

    var body: some View {
        ImprovedChartView(
            data: data,
            dateFormatter: formatter
        )
    }
}

// Graphique avancé
private struct ImprovedChartView: View {
    let data: [(Date, TimeInterval)]
    let dateFormatter: DateFormatter

    private var minTime: TimeInterval {
        data.map(\.1).min().map { max(0, $0 * 0.9) } ?? 0
    }
    private var maxTime: TimeInterval {
        data.map(\.1).max().map { $0 * 1.1 } ?? 3600
    }

    var body: some View {
        VStack(spacing: 0) {
            // Légende
            HStack {
                Text("Progression des temps")
                    .font(.headline).foregroundColor(.white)
                Spacer()
                HStack(spacing: 4) {
                    Circle().fill(Color.yellow).frame(width: 8, height: 8)
                    Text("Temps total")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            // Zone graphique sans padding horizontal !
            GeometryReader { geo in
                ZStack {
                    ChartFill(
                        data: data,
                        minTime: minTime,
                        maxTime: maxTime,
                        size: geo.size
                    )
                    ChartLine(
                        data: data,
                        minTime: minTime,
                        maxTime: maxTime,
                        size: geo.size
                    )
                }
            }

            // Axe X sans décalage
            HStack(spacing: 0) {
                ForEach(data.indices, id: \.self) { i in
                    Text(dateFormatter.string(from: data[i].0))
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
    }
}

private struct ChartLine: View {
    let data: [(Date, TimeInterval)]
    let minTime: TimeInterval
    let maxTime: TimeInterval
    let size: CGSize

    var body: some View {
        Path { path in
            let pts = scaledPoints()
            guard pts.count > 1 else { return }
            path.move(to: pts[0])
            for p in pts.dropFirst() { path.addLine(to: p) }
        }
        .stroke(Color.yellow, lineWidth: 2)
    }

    private func scaledPoints() -> [CGPoint] {
        let w = size.width
        let h = size.height
        let range = maxTime - minTime
        return data.enumerated().map { i, pair in
            let x = (w / CGFloat(data.count - 1)) * CGFloat(i)
            let y = h * (1 - CGFloat((pair.1 - minTime) / range))
            return CGPoint(x: x, y: y)
        }
    }
}

private struct ChartFill: View {
    let data: [(Date, TimeInterval)]
    let minTime: TimeInterval
    let maxTime: TimeInterval
    let size: CGSize

    var body: some View {
        Path { path in
            let pts = scaledPoints()
            guard !pts.isEmpty else { return }
            path.move(to: CGPoint(x: pts[0].x, y: size.height))
            for p in pts { path.addLine(to: p) }
            if let last = pts.last {
                path.addLine(to: CGPoint(x: last.x, y: size.height))
            }
            path.closeSubpath()
        }
        .fill(
            LinearGradient(
                gradient: Gradient(colors: [Color.yellow.opacity(0.3),
                                            Color.yellow.opacity(0.05)]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func scaledPoints() -> [CGPoint] {
        let w = size.width
        let h = size.height
        let range = maxTime - minTime
        return data.enumerated().map { i, pair in
            let x = (w / CGFloat(data.count - 1)) * CGFloat(i)
            let y = h * (1 - CGFloat((pair.1 - minTime) / range))
            return CGPoint(x: x, y: y)
        }
    }
}


// MARK: - History Section

private struct HistorySectionView: View {
    let workouts: [Workout]
    let personalBests: [String: Exercise]
    let formatter: (Date) -> String
    let onDelete: (Workout) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Historique des exercices")
                .font(.title3).bold()
                .foregroundColor(.white)

            let exerciseNames = uniqueExerciseNames(from: workouts)
            ForEach(exerciseNames, id: \.self) { name in
                ExerciseHistoryCard(
                    exerciseName: name,
                    history: history(for: name),
                    personalBest: personalBests[name],
                    formatDate: formatter,
                    onDelete: onDelete
                )
            }
        }
    }

    private func uniqueExerciseNames(from workouts: [Workout]) -> [String] {
        var set = Set<String>()
        workouts.forEach {
            ($0.exercises as? Set<Exercise> ?? []).forEach {
                if let name = $0.name { set.insert(name) }
            }
        }
        return set.sorted()
    }

    private func history(for name: String) -> [(Exercise, Date)] {
        workouts
            .filter { $0.completed }
            .compactMap { workout in
                guard let ex = (workout.exercises as? Set<Exercise>)?
                        .first(where: { $0.name == name }),
                      let date = workout.date
                else { return nil }
                return (ex, date)
            }
    }
}

private struct ExerciseHistoryCard: View {
    let exerciseName: String
    let history: [(Exercise, Date)]
    let personalBest: Exercise?
    let formatDate: (Date) -> String
    let onDelete: (Workout) -> Void

    @State private var workoutToDelete: Workout?
    @State private var showingDeleteAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Titre + badge record
            HStack {
                Text(exerciseName)
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                if let best = personalBest {
                    HStack(spacing: 8) {
                        Image(systemName: "trophy.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                        Text("Meilleur : \(TimeFormatter.formatTime(best.duration))")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.yellow.opacity(0.2))
                    .cornerRadius(4)
                }
            }

            Divider()
                .background(Color.gray.opacity(0.5))

            // Contenu de l'historique
            if history.isEmpty {
                Text("Aucun historique récent")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                List {
                    ForEach(0..<min(3, history.count), id: \.self) { idx in
                        let (exercise, date) = history[idx]
                        let isBest = personalBest?.id == exercise.id
                        if let workout = exercise.workout {
                            HStack {
                                Text(formatDate(date))
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                Spacer()
                                HStack(spacing: 8) {
                                    if exercise.repetitions > 0 {
                                        Text("\(exercise.repetitions) reps")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    if exercise.distance > 0 {
                                        Text("\(Int(exercise.distance)) m")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    Text(TimeFormatter.formatTime(exercise.duration))
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(isBest ? .yellow : .white)
                                }
                            }
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 14, trailing: 0))
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    workoutToDelete = workout
                                    showingDeleteAlert = true
                                } label: {
                                    Label("Supprimer", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .listStyle(PlainListStyle())
                .frame(height: CGFloat(min(3, history.count)) * 44)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .alert("Supprimer la séance", isPresented: $showingDeleteAlert) {
            Button("Annuler", role: .cancel) { }
            Button("Supprimer", role: .destructive) {
                if let w = workoutToDelete {
                    onDelete(w)
                }
            }
        } message: {
            Text("Attention, la suppression de cet exercice supprimera tout l'historique de cette séance.")
        }
    }
}


// MARK: - Comparison Section

private struct ComparisonSectionView: View {
    let previous: Workout
    let latest: Workout
    let longFormatter: DateFormatter
    let shortFormatter: DateFormatter
    let formatTime: (TimeInterval) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Comparaison d'entraînements")
                .font(.title3).bold()
                .foregroundColor(.white)

            StatRow(label: "Récente",
                    date: shortFormatter.string(from: latest.date!),
                    value: formatTime(latest.duration))
            StatRow(label: "Précédent",
                    date: shortFormatter.string(from: previous.date!),
                    value: formatTime(previous.duration))

            let diff = latest.duration - previous.duration
            let improved = diff < 0

            HStack {
                Text("Différence")
                    .foregroundColor(.white)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: improved ? "arrow.down" : "arrow.up")
                        .foregroundColor(improved ? .green : .red)
                    Text(formatTime(abs(diff)))
                        .foregroundColor(improved ? .green : .red)
                        .bold()
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }

    private struct StatRow: View {
        let label: String
        let date: String
        let value: String

        var body: some View {
            HStack {
                VStack(alignment: .leading) {
                    Text(label).font(.subheadline).foregroundColor(.gray)
                    Text(date).font(.caption).foregroundColor(.white)
                }
                Spacer()
                Text(value).font(.headline).foregroundColor(.white)
            }
            .padding(.vertical, 4)
            Divider().background(Color.gray.opacity(0.5))
        }
    }
}

// MARK: - No Data View

private struct NoDataView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("Aucune donnée disponible")
                .font(.title2)
                .foregroundColor(.white)
            
            Text("Commencez à vous entraîner pour voir vos statistiques")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    let context = DataController.shared.container.viewContext
    let workoutManager = WorkoutManager(dataController: DataController.shared)
    let viewModel = WorkoutViewModel(workoutManager: workoutManager)
    let statsViewModel = StatsViewModel(workoutManager: workoutManager)
    
    return StatisticsView(viewModel: statsViewModel, wvm: viewModel)
        .environment(\.managedObjectContext, context)
}
