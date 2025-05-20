import SwiftUI

struct DashboardView: View {
    @ObservedObject var viewModel: WorkoutViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Dashboard")
                    .font(.largeTitle).bold()
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Dernier entraînement
                if let workout = viewModel.workouts.first {
                    WorkoutSummaryView(
                        workout: workout,
                        bestTimes:     viewModel.personalBests,
                        formatTime:    viewModel.formatTime(_:),
                        chartData:     workout.heartRateArray.map { $0.value }
                    )
                } else {
                    PlaceholderCard(text: "Aucun entraînement récent")
                }

                // Objectifs
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
    }
}

// MARK: - Sous-vues

private struct WorkoutSummaryView: View {
    let workout: Workout
    let bestTimes: [String: Exercise]
    let formatTime: (TimeInterval) -> String
    let chartData: [Double]
    
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
            
            Text("\(String(format: "%.2f", workout.distance)) km")
                .foregroundColor(.gray)
            
            // Liste des exercices et records
            ForEach(workout.exerciseArray, id: \.id) { ex in
                HStack {
                    Text(ex.name ?? "")
                        .foregroundColor(.gray)
                        .font(.subheadline)
                    Spacer()
                    Text(formatTime(ex.duration))
                        .foregroundColor(.white)
                        .font(.subheadline)
                    if let best = bestTimes[ex.name ?? ""]?.duration {
                        Text(formatTime(best))
                            .foregroundColor(.yellow)
                            .font(.subheadline)
                    }
                }
            }
            
            // Graphe fréquence cardiaque
            ChartView(data: chartData)
                .frame(height: 60)
            
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Objectifs HYROX")
                .font(.headline).foregroundColor(.white)
            
            ForEach(Array(ExerciseDefinitions.all.values.prefix(3)), id: \.name) { def in
                HStack {
                    Text(def.name)
                        .foregroundColor(.white)
                    Spacer()
                    Text("< \(formatTime(def.targetTime ?? 0))")
                        .foregroundColor(.yellow)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            
            HStack {
                Text("Autres")
                    .foregroundColor(.white)
                Spacer()
                Text("…")
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
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
        Text(text)
            .foregroundColor(.gray)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(.systemGray6))
            .cornerRadius(12)
    }
}
