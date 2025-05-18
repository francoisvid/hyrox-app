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
                            
                            // Temps des exercices
                            if let exercises = lastWorkout.exercises as? Set<Exercise> {
                                VStack(spacing: 8) {
                                    ForEach(Array(exercises.sorted { ($0.name ?? "") < ($1.name ?? "") }), id: \.id) { exercise in
                                        if let name = exercise.name {
                                            HStack {
                                                Text(name)
                                                    .foregroundColor(.gray)
                                                    .font(.subheadline)
                                                Spacer()
                                                HStack(alignment: .center, spacing: 10) {
                                                    Text(viewModel.formatTime(exercise.duration))
                                                        .foregroundColor(.white)
                                                        .font(.subheadline)
                                                    if let bestTime = viewModel.getBestTimeForExercise(name: name) {
                                                        Text((viewModel.formatTime(bestTime)))
                                                            .foregroundColor(.yellow)
                                                            .font(.subheadline)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                            
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
    
    private var average: Double {
        guard !data.isEmpty else { return 0 }
        return data.reduce(0, +) / Double(data.count)
    }
    
    private var maxValue: Double {
        data.max() ?? 0
    }
    
    private var minValue: Double {
        data.min() ?? 0
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Grille de fond
                VStack(spacing: 0) {
                    ForEach(0..<4) { i in
                        Divider()
                            .background(Color.gray.opacity(0.3))
                        Spacer()
                    }
                    Divider()
                        .background(Color.gray.opacity(0.3))
                }
                
                // Ligne moyenne
                if !data.isEmpty {
                    let avgY = geometry.size.height * (1 - CGFloat((average - minValue) / (maxValue - minValue)))
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: avgY))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: avgY))
                    }
                    .stroke(Color.gray.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                }
                
                // Courbe principale
                Path { path in
                    let points = normalizedPoints(width: geometry.size.width, height: geometry.size.height)
                    if !points.isEmpty {
                        path.move(to: points[0])
                        for i in 1..<points.count {
                            path.addLine(to: points[i])
                        }
                    }
                }
                .stroke(Color.yellow, lineWidth: 2)
                
                // Points de données
                ForEach(0..<data.count, id: \.self) { index in
                    if index % 5 == 0 { // Afficher un point tous les 5 points pour éviter la surcharge
                        let point = normalizedPoints(width: geometry.size.width, height: geometry.size.height)[index]
                        Circle()
                            .fill(Color.yellow)
                            .frame(width: 4, height: 4)
                            .position(point)
                    }
                }
                
                // Indicateurs de valeurs
                VStack(alignment: .leading, spacing: 4) {
                    Text("Max: \(Int(maxValue)) bpm")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text("Moy: \(Int(average)) bpm")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text("Min: \(Int(minValue)) bpm")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                .padding(4)
                .background(Color.black.opacity(0.7))
                .cornerRadius(4)
                .position(x: 50, y: 20)
            }
        }
    }
    
    private func normalizedPoints(width: CGFloat, height: CGFloat) -> [CGPoint] {
        guard !data.isEmpty else { return [] }
        
        let minValue = data.min() ?? 0
        let maxValue = data.max() ?? 1
        let range = maxValue - minValue
        
        return (0..<data.count).map { index in
            let x = width * CGFloat(index) / CGFloat(data.count - 1)
            let normalizedValue = (data[index] - minValue) / range
            let y = height * (1 - CGFloat(normalizedValue))
            return CGPoint(x: x, y: y)
        }
    }
}

struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        let persistenceController = PersistenceController(inMemory: true)
        persistenceController.createDemoDataIfNeeded()
        
        let workoutManager = WorkoutManager(persistenceController: persistenceController)
        let viewModel = WorkoutViewModel(workoutManager: workoutManager)
        
        return DashboardView(viewModel: viewModel)
            .preferredColorScheme(.dark)
            .environment(\.managedObjectContext, persistenceController.container.viewContext)
    }
}
