// Views/DashboardView.swift
import SwiftUI

struct DashboardView: View {
    @ObservedObject var viewModel: WorkoutViewModel
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM"
        return formatter
    }()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Dashboard")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                // Utiliser Group pour envelopper le contenu conditionnel
                Group {
                    if let lastWorkout = viewModel.workouts.first {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Dernier entraînement")
                                .font(.headline)
                                .foregroundColor(.gray)
                            
                            HStack {
                                Text(viewModel.formatTime(lastWorkout.duration))
                                    .font(.system(size: 45, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Image(systemName: "lock.fill")
                                    .foregroundColor(.gray)
                            }
                            
                            Text("\(String(format: "%.2f", lastWorkout.distance)) km")
                                .foregroundColor(.gray)
                            
                            // Graph
                            ChartView(data: (lastWorkout.heartRates as? Set<HeartRatePoint> ?? [])
                                .compactMap { $0.value })
                                .frame(height: 60)
                                .padding(.vertical)
                            
                            Text(dateFormatter.string(from: lastWorkout.date ?? Date()))
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    } else {
                        Text("Aucun entraînement récent")
                            .foregroundColor(.gray)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    }
                }
                
                // Objectifs
                Text("Objectifs HYROX")
                    .font(.headline)
                    .foregroundColor(.white)
                
                // Liste exercices
                VStack(spacing: 8) {
                    // Afficher les 3 premiers exercices Hyrox standards
                    ForEach(0..<min(3, HyroxConstants.standardExercises.count), id: \.self) { index in
                        let exerciseInfo = HyroxConstants.standardExercises[index]
                        ExerciseGoalRow(
                            name: exerciseInfo.name,
                            goal: viewModel.formatTime(exerciseInfo.targetTime)
                        )
                    }
                    
                    ExerciseGoalRow(name: "Autres", goal: "Autres")
                }
                
                // Timer actuel - Utiliser Group pour envelopper
                Group {
                    if viewModel.isWorkoutActive {
                        HStack(alignment: .bottom) {
                            VStack(alignment: .leading) {
                                Text(viewModel.formatTime(viewModel.elapsedTime))
                                    .font(.system(size: 45, weight: .bold))
                                    .foregroundColor(.white)
                                Text(viewModel.selectedExercise?.name ?? "En cours")
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing) {
                                Text("--")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(.white)
                                Text("-- m")
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
            }
            .padding()
        }
        .background(Color.black.ignoresSafeArea())
    }
}

struct ExerciseGoalRow: View {
    let name: String
    let goal: String
    
    var body: some View {
        HStack {
            Text(name)
                .foregroundColor(.white)
            
            Spacer()
            
            if goal != "Autres" {
                Text("< \(goal)")
                    .foregroundColor(.yellow)
            } else {
                Text(goal)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct ChartView: View {
    let data: [Double]
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                let points = normalizedPoints(width: width, height: height)
                
                // Tracer le chemin
                if !points.isEmpty {
                    path.move(to: points[0])
                    for i in 1..<points.count {
                        path.addLine(to: points[i])
                    }
                }
            }
            .stroke(Color.yellow, lineWidth: 2)
        }
    }
    
    private func normalizedPoints(width: CGFloat, height: CGFloat) -> [CGPoint] {
        guard !data.isEmpty else { return [] }
        
        // Trouver min et max pour normalisation
        let minValue = data.min() ?? 0
        let maxValue = data.max() ?? 1
        let range = maxValue - minValue
        
        // Normaliser les données
        return (0..<data.count).map { index in
            let x = width * CGFloat(index) / CGFloat(data.count - 1)
            let normalizedValue = (data[index] - minValue) / range
            let y = height * (1 - CGFloat(normalizedValue))
            return CGPoint(x: x, y: y)
        }
    }
}
