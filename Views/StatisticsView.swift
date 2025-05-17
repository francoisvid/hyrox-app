import SwiftUI

struct StatisticsView: View {
    @ObservedObject var viewModel: StatsViewModel
    let periods = ["3 mois", "6 mois", "1 an", "2 ans"]
    
    // Formateurs
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter
    }()
    
    private let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter
    }()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Statistiques")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                // Sélecteur de période
                HStack {
                    ForEach(0..<periods.count, id: \.self) { index in
                        Button(action: {
                            viewModel.selectedPeriod = index
                            viewModel.updateChartData()
                        }) {
                            Text(periods[index])
                                .foregroundColor(viewModel.selectedPeriod == index ? .yellow : .gray)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    viewModel.selectedPeriod == index ?
                                        Color.yellow.opacity(0.2) : Color.clear
                                )
                                .cornerRadius(8)
                        }
                    }
                }
                
                // Graphique amélioré
                VStack(alignment: .leading, spacing: 0) {
                    ImprovedChartView(
                        data: viewModel.getChartData(),
                        dateFormatter: shortDateFormatter
                    )
                    .frame(height: 300)
                }
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Historique et meilleurs temps
                Text("Historique des exercices")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.top, 10)
                
                ForEach(getUniqueExercises(), id: \.self) { exerciseName in
                    ExerciseHistoryCard(
                        exerciseName: exerciseName,
                        history: getExerciseHistory(name: exerciseName),
                        personalBest: viewModel.personalBests[exerciseName],
                        formatTime: formatTime
                    )
                }
                
                // Comparaison
                let comparison = viewModel.getComparisonData()
                if let latest = comparison.latest, let previous = comparison.previous {
                    Text("Comparaison d'entraînements")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.top, 10)
                    
                    VStack(spacing: 15) {
                        HStack {
                            Text("Comparaison")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Text("Temps total")
                                .foregroundColor(.gray)
                                .font(.subheadline)
                        }
                        
                        Divider()
                            .background(Color.gray.opacity(0.5))
                        
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Récent")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                
                                Text(dateFormatter.string(from: latest.date ?? Date()))
                                    .foregroundColor(.white)
                                    .font(.caption)
                            }
                            
                            Spacer()
                            
                            Text(formatTime(latest.duration))
                                .foregroundColor(.white)
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                        
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Précédent")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                
                                Text(dateFormatter.string(from: previous.date ?? Date()))
                                    .foregroundColor(.white)
                                    .font(.caption)
                            }
                            
                            Spacer()
                            
                            Text(formatTime(previous.duration))
                                .foregroundColor(.white)
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                        
                        Divider()
                            .background(Color.gray.opacity(0.5))
                        
                        // Différence
                        let diff = latest.duration - previous.duration
                        let isImprovement = diff < 0
                        
                        HStack {
                            Text("Différence")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            
                            Spacer()
                            
                            HStack(spacing: 4) {
                                Image(systemName: isImprovement ? "arrow.down" : "arrow.up")
                                    .foregroundColor(isImprovement ? .green : .red)
                                
                                Text(formatTime(abs(diff)))
                                    .foregroundColor(isImprovement ? .green : .red)
                                    .font(.headline)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
            }
            .padding()
        }
        .background(Color.black.ignoresSafeArea())
    }
    
    // Fonctions utilitaires
    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let seconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func getUniqueExercises() -> [String] {
        var exerciseNames = Set<String>()
        
        for workout in viewModel.workouts {
            // Accéder aux exercices via la relation Core Data
            if let exercises = workout.exercises as? Set<Exercise> {
                for exercise in exercises {
                    if let name = exercise.name {
                        exerciseNames.insert(name)
                    }
                }
            }
        }
        
        return Array(exerciseNames).sorted()
    }
    
    private func getExerciseHistory(name: String) -> [(Exercise, Date)] {
        var exercisesWithDates: [(Exercise, Date)] = []
        
        // Parcourir les entraînements pour trouver les exercices correspondants
        for workout in viewModel.workouts.prefix(3) {
            if let exercises = workout.exercises as? Set<Exercise>,
               let exercise = exercises.first(where: { $0.name == name }),
               let date = workout.date {
                exercisesWithDates.append((exercise, date))
            }
        }
        
        return exercisesWithDates
    }
}

// Composant pour afficher l'historique d'un exercice
struct ExerciseHistoryCard: View {
    let exerciseName: String
    let history: [(Exercise, Date)]
    let personalBest: Exercise?
    let formatTime: (TimeInterval) -> String
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Titre de l'exercice
            HStack {
                Text(exerciseName)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                // Badge meilleur temps
                if let best = personalBest {
                    HStack(spacing: 4) {
                        Image(systemName: "trophy.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                        
                        Text("Meilleur: \(formatTime(best.duration))")
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
            
            // Historique
            if history.isEmpty {
                Text("Aucun historique récent")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                ForEach(0..<min(3, history.count), id: \.self) { index in
                    let (exercise, date) = history[index]
                    let isBest = personalBest?.id == exercise.id
                    
                    HStack {
                        // Affichage de la date
                        Text(dateFormatter.string(from: date))
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
                            
                            Text(formatTime(exercise.duration))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(isBest ? .yellow : .white)
                        }
                    }
                    
                    if index < min(3, history.count) - 1 {
                        Divider()
                            .background(Color.gray.opacity(0.3))
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// Graphique amélioré avec correction d'approche
struct ImprovedChartView: View {
    let data: [(Date, TimeInterval)]
    let dateFormatter: DateFormatter
    
    private var minTime: TimeInterval {
        if let min = data.map({ $0.1 }).min() {
            // Retourner un temps légèrement inférieur pour laisser de l'espace
            return max(0, min * 0.9)
        }
        return 0
    }
    
    private var maxTime: TimeInterval {
        if let max = data.map({ $0.1 }).max() {
            // Retourner un temps légèrement supérieur pour laisser de l'espace
            return max * 1.1
        }
        return 3600 // 1 heure par défaut
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Titre et légende
            HStack {
                Text("Progression des temps")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.leading, 15)
                
                Spacer()
                
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.yellow)
                        .frame(width: 8, height: 8)
                    Text("Temps total")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.trailing, 15)
            }
            .padding(.top, 15)
            .padding(.bottom, 10)
            
            // Graphique principal
            GeometryReader { geometry in
                // Zone de graphique
                ZStack {
                    // Lignes de grille et étiquettes Y
                    VStack(spacing: 0) {
                        ForEach(0..<5, id: \.self) { i in
                            HStack {
                                // Valeur de temps pour cette ligne
                                let value = minTime + (Double(4 - i) / 4.0) * (maxTime - minTime)
                                
                                // Étiquette Y
                                Text(formatTime(value))
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray)
                                    .frame(width: 45, alignment: .trailing)
                                    .padding(.trailing, 5)
                                
                                // Ligne horizontale
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(height: 1)
                            }
                            
                            if i < 4 {
                                Spacer()
                            }
                        }
                    }
                    
                    // Tracé du graphique
                    HStack {
                        // Espace pour les labels de l'axe Y
                        Spacer()
                            .frame(width: 50)
                        
                        // Zone du graphique
                        ZStack {
                            // Dessiner le remplissage et la ligne dans un ZStack
                            ChartFillView(data: data, minTime: minTime, maxTime: maxTime,
                                          geometrySize: geometry.size)
                            
                            ChartLineView(data: data, minTime: minTime, maxTime: maxTime,
                                          geometrySize: geometry.size)
                            
                            // Points sur la ligne
                            ForEach(0..<data.count, id: \.self) { i in
                                let point = calculatePoint(
                                    for: i,
                                    in: geometry.size,
                                    data: data,
                                    minTime: minTime,
                                    maxTime: maxTime
                                )
                                
                                Circle()
                                    .fill(Color.yellow)
                                    .frame(width: 8, height: 8)
                                    .position(point)
                            }
                        }
                    }
                }
                .padding(.bottom, 25) // Espace pour les étiquettes X
            }
            
            // Axe X (dates)
            HStack(spacing: 0) {
                Spacer()
                    .frame(width: 50) // Aligner avec les étiquettes Y
                
                if !data.isEmpty {
                    HStack(spacing: 0) {
                        ForEach(0..<data.count, id: \.self) { i in
                            Text(dateFormatter.string(from: data[i].0))
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .padding(.bottom, 15)
        }
    }
    
    // Fonction utilitaire pour calculer la position d'un point
    private func calculatePoint(for index: Int, in size: CGSize, data: [(Date, TimeInterval)],
                                minTime: TimeInterval, maxTime: TimeInterval) -> CGPoint {
        let availableWidth = size.width - 50 // Espace pour étiquettes Y
        let availableHeight = size.height - 25 // Espace pour étiquettes X
        
        let xPosition: CGFloat
        if data.count > 1 {
            xPosition = 50 + (availableWidth / CGFloat(data.count - 1)) * CGFloat(index)
        } else {
            xPosition = 50 + availableWidth / 2
        }
        
        let timeRange = maxTime - minTime
        let normalizedTime = (data[index].1 - minTime) / timeRange
        let yPosition = availableHeight * (1 - CGFloat(normalizedTime))
        
        return CGPoint(x: xPosition, y: yPosition)
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let seconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// Vue pour le remplissage du graphique
struct ChartFillView: View {
    let data: [(Date, TimeInterval)]
    let minTime: TimeInterval
    let maxTime: TimeInterval
    let geometrySize: CGSize
    
    var body: some View {
        if !data.isEmpty {
            Path { path in
                let availableWidth = geometrySize.width - 50
                let availableHeight = geometrySize.height - 25
                let timeRange = maxTime - minTime
                
                // Points pour le tracé
                let points = data.enumerated().map { index, point -> CGPoint in
                    let xPosition: CGFloat
                    if data.count > 1 {
                        xPosition = (availableWidth / CGFloat(data.count - 1)) * CGFloat(index)
                    } else {
                        xPosition = availableWidth / 2
                    }
                    
                    let normalizedTime = (point.1 - minTime) / timeRange
                    let yPosition = availableHeight * (1 - CGFloat(normalizedTime))
                    
                    return CGPoint(x: xPosition, y: yPosition)
                }
                
                // Commencer le chemin
                path.move(to: CGPoint(x: points.first?.x ?? 0, y: availableHeight))
                
                // Tracer jusqu'au premier point
                if let firstPoint = points.first {
                    path.addLine(to: firstPoint)
                }
                
                // Tracer la ligne pour chaque point
                for i in 1..<points.count {
                    path.addLine(to: points[i])
                }
                
                // Fermer le chemin
                if let lastPoint = points.last {
                    path.addLine(to: CGPoint(x: lastPoint.x, y: availableHeight))
                }
                
                path.closeSubpath()
            }
            .fill(LinearGradient(
                gradient: Gradient(colors: [Color.yellow.opacity(0.3), Color.yellow.opacity(0.05)]),
                startPoint: .top,
                endPoint: .bottom
            ))
        }
    }
}

// Vue pour la ligne du graphique
struct ChartLineView: View {
    let data: [(Date, TimeInterval)]
    let minTime: TimeInterval
    let maxTime: TimeInterval
    let geometrySize: CGSize
    
    var body: some View {
        if !data.isEmpty {
            Path { path in
                let availableWidth = geometrySize.width - 50
                let availableHeight = geometrySize.height - 25
                let timeRange = maxTime - minTime
                
                // Points pour le tracé
                let points = data.enumerated().map { index, point -> CGPoint in
                    let xPosition: CGFloat
                    if data.count > 1 {
                        xPosition = (availableWidth / CGFloat(data.count - 1)) * CGFloat(index)
                    } else {
                        xPosition = availableWidth / 2
                    }
                    
                    let normalizedTime = (point.1 - minTime) / timeRange
                    let yPosition = availableHeight * (1 - CGFloat(normalizedTime))
                    
                    return CGPoint(x: xPosition, y: yPosition)
                }
                
                // Tracer la ligne
                if let firstPoint = points.first {
                    path.move(to: firstPoint)
                    
                    for i in 1..<points.count {
                        path.addLine(to: points[i])
                    }
                }
            }
            .stroke(Color.yellow, lineWidth: 2)
        }
    }
}
