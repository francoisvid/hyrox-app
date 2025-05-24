// Views/WorkoutView.swift

import SwiftUI

struct WorkoutView: View {
    @ObservedObject var viewModel: WorkoutViewModel
    @State private var showingNewWorkoutSheet = false
    @State private var showingActiveWorkout = false
    @State private var selectedTemplate: WorkoutTemplate?
    @State private var isInitializing = false

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 13),
                    GridItem(.flexible(), spacing: 13)
                ], spacing: 20) {
                    // Liste des templates existants
                    ForEach(viewModel.templates) { template in
                        WorkoutTemplateCard(template: template, onStart: {
                            guard !isInitializing else { return }
                            isInitializing = true
                            print("🟡 Démarrage de l'initialisation pour le template: \(template.name ?? "Sans nom")")
                            
                            if viewModel.isActive {
                                showingActiveWorkout = true
                                isInitializing = false
                            } else {
                                selectedTemplate = template
                                // Initialiser le workout avant d'afficher la modal
                                viewModel.startWorkout(from: template)
                                // Attendre que le workout soit initialisé
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    print("🟡 Workout initialisé, affichage de la modal")
                                    showingActiveWorkout = true
                                    isInitializing = false
                                }
                            }
                        }, viewModel: viewModel)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.top, 30)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("Entraînements")
                        .font(.largeTitle.bold())
                        .foregroundColor(.white)
                        .padding(.top, 30)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 15) {
                        Menu {
                            Button(role: .destructive, action: {
                                viewModel.deleteAllTemplates()
                            }) {
                                Label("Supprimer tous les templates", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 24))
                                .foregroundColor(.yellow)
                        }
                        
                        Button(action: { showingNewWorkoutSheet = true }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.yellow)
                        }
                    }
                    .padding(.top, 30)
                }
            }
            .sheet(isPresented: $showingActiveWorkout, onDismiss: {
                print("🟡 Sheet fermée")
            }) {
                if viewModel.isActive {
                    ActiveWorkoutView(viewModel: viewModel, template: nil)
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                } else if let template = selectedTemplate {
                    ActiveWorkoutView(viewModel: viewModel, template: template)
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                }
            }
            .sheet(isPresented: $showingNewWorkoutSheet) {
                NewWorkoutTemplateView(viewModel: viewModel)
            }
        }
        .navigationBarHidden(false)
    }
}

struct WorkoutTemplateCard: View {
    let template: WorkoutTemplate
    let onStart: () -> Void
    @ObservedObject var viewModel: WorkoutViewModel
    @State private var isStarting = false
    
    private var isCurrentTemplate: Bool {
        guard let currentWorkout = viewModel.workoutManager.currentWorkout,
              let currentTemplateId = currentWorkout.templateId,
              let templateId = template.id else {
            return false
        }
        return currentTemplateId == templateId
    }
    
    private var orderedExercises: [ExerciseTemplate] {
        template.exercises?.allObjects.compactMap { $0 as? ExerciseTemplate }
            .sorted { $0.order < $1.order } ?? []
    }
    
    private var exerciseCount: Int {
        orderedExercises.count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header avec titre et badge
            headerSection
            
            // Description si présente
            if let description = template.workoutDescription {
                descriptionSection(description)
            }
            
            // Liste des exercices
            exerciseListSection
            
            // Footer avec durée et bouton
            footerSection
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
                .shadow(
                    color: isCurrentTemplate ? .yellow.opacity(0.3) : .black.opacity(0.1),
                    radius: isCurrentTemplate ? 8 : 4,
                    x: 0,
                    y: 2
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isCurrentTemplate ? Color.yellow : Color.clear,
                    lineWidth: isCurrentTemplate ? 2 : 0
                )
        )
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(template.name ?? "Sans nom")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                HStack(spacing: 8) {
                    // Badge nombre d'exercices
                    Label("\(exerciseCount)", systemImage: "figure.strengthtraining.traditional")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.7))
                        .clipShape(Capsule())
                    
                    // Badge actuel si applicable
                    if isCurrentTemplate {
                        Text("EN COURS")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.yellow)
                            .clipShape(Capsule())
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }
    
    // MARK: - Description Section
    private func descriptionSection(_ description: String) -> some View {
        Text(description)
            .font(.subheadline)
            .foregroundColor(.gray)
            .lineLimit(2)
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
    }
    
    // MARK: - Exercise List Section
    private var exerciseListSection: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                ForEach(Array(orderedExercises.prefix(6).enumerated()), id: \.element.id) { index, exercise in
                    HStack(spacing: 12) {
                        // Numéro d'exercice (sans cercle)
                        Text("\(index + 1).")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.blue.opacity(0.8))
                        
                        // Nom de l'exercice avec plus d'espace
                        Text(exercise.name ?? "")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        
                        Spacer()
                        
                        // Icône du type d'exercice
                        if let name = exercise.name,
                           let definition = ExerciseDefinitions.all[name] {
                            Image(systemName: iconForCategory(definition.category))
                                .font(.system(size: 10))
                        }
                    }
                }
                
                // Indicateur s'il y a plus d'exercices
                if orderedExercises.count > 6 {
                    HStack(spacing: 8) {
                        Text("...")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.blue.opacity(0.8))
                            .frame(minWidth: 20, alignment: .leading)
                        
                        Text("et \(orderedExercises.count - 6) autres exercices")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                        
                        Spacer()
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 16)
        }
        .frame(height: 160) // Augmenté pour plus d'espace
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray5))
        )
        .padding(.horizontal, 13)
    }
    
    // MARK: - Footer Section
    private var footerSection: some View {
        VStack(spacing: 16) {
            // Durée estimée
            if template.estimatedDuration > 0 {
                HStack {
                    Image(systemName: "clock")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                    Text("Durée estimée: \(TimeFormatter.formatTime(template.estimatedDuration))")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 20)
            }
            
            // Bouton d'action
            Button(action: {
                guard !isStarting else { return }
                isStarting = true
                print("🟡 Clic sur le bouton \(isCurrentTemplate ? "VOIR" : "DÉMARRER") pour le template: \(template.name ?? "Sans nom")")
                
                onStart()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    isStarting = false
                }
            }) {
                HStack(spacing: 8) {
                    if isStarting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .black))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: isCurrentTemplate ? "eye" : "play.fill")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    
                    Text(isCurrentTemplate ? "VOIR" : "DÉMARRER")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isCurrentTemplate ? Color.gray.opacity(0.8) : Color.yellow)
                )
                .scaleEffect(isStarting ? 0.95 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: isStarting)
            }
            .disabled(isStarting)
            .padding(.horizontal, 13)
            .padding(.bottom, 13)
            .padding(.top, 10)
        }
    }
    
    // MARK: - Helper Functions
    private func iconForCategory(_ category: String) -> String {
        switch category {
        case "Cardio": return "heart.fill"
        case "Force": return "dumbbell.fill"
        case "Core": return "figure.core.training"
        case "Plyo": return "figure.jumprope"
        default: return "figure.strengthtraining.traditional"
        }
    }
}

struct NewWorkoutTemplateView: View {
    @ObservedObject var viewModel: WorkoutViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var templateName = ""
    @State private var templateDescription = ""
    @State private var selectedExercises: Set<String> = []
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Informations de l'entrainement")) {
                    TextField("Nom", text: $templateName)
                    TextField("Description", text: $templateDescription)
                }
                
                Section(header: Text("Exercices")) {
                    ForEach(ExerciseDefinitions.all.keys.sorted(), id: \.self) { name in
                        if let def = ExerciseDefinitions.all[name] {
                            Toggle(isOn: Binding(
                                get: { selectedExercises.contains(name) },
                                set: { isSelected in
                                    if isSelected {
                                        selectedExercises.insert(name)
                                    } else {
                                        selectedExercises.remove(name)
                                    }
                                }
                            )) {
                                VStack(alignment: .leading) {
                                    Text(def.name)
                                    Text(def.description)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    // Optionnel : afficher la catégorie
                                    Text(def.category)
                                        .font(.caption2)
                                        .foregroundColor(.yellow)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Nouvelle entrainement")
            .navigationBarItems(
                leading: Button("Annuler") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Créer") {
                    createTemplate()
                }
                .disabled(templateName.isEmpty || selectedExercises.isEmpty)
            )
        }
    }
    
    private func createTemplate() {
        viewModel.createTemplate(
            name: templateName,
            description: templateDescription,
            exercises: Array(selectedExercises)
        )
        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - Active Workout

private struct ActiveWorkoutView: View {
    @ObservedObject var viewModel: WorkoutViewModel
    let template: WorkoutTemplate?
    @Environment(\.presentationMode) var presentationMode
    @State private var isInitialized = false
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .yellow))
                    .scaleEffect(1.5)
            } else {
                VStack(spacing: 16) {
                    // Timer + Stop
                    HStack {
                        Text(viewModel.formatTime(viewModel.elapsedTime))
                            .font(.system(size: 45, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                        Button {
                            viewModel.endWorkout()
                            presentationMode.wrappedValue.dismiss()
                        } label: {
                            Image(systemName: "stop.fill")
                                .font(.title)
                                .foregroundColor(.red)
                                .padding()
                                .background(Color(.systemGray6))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 30)
                    .padding(.top, 50)

                    // Liste des exercices
                    List {
                        ForEach(viewModel.currentExercises, id: \.id) { exercise in
                            ExerciseRow(
                                exercise: exercise,
                                isCurrent: viewModel.isNext(exercise),
                                duration: viewModel.formatTime(exercise.duration)
                            ) {
                                viewModel.select(exercise)
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
        }
        .background(Color.black.ignoresSafeArea())
        .sheet(isPresented: $viewModel.isEditingExercise) {
            if let exercise = viewModel.selectedExercise {
                ExerciseDetailView(exercise: exercise, viewModel: viewModel)
            }
        }
        .onAppear {
            if !isInitialized {
                isInitialized = true
                if let template = template {
                    viewModel.startWorkout(from: template)
                }
                
                // Attendre que le workout soit initialisé
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    // Vérifier si le workout est bien initialisé
                    if viewModel.isActive && !viewModel.currentExercises.isEmpty {
                        isLoading = false
                    } else {
                        // Si le workout n'est pas initialisé, on attend encore un peu
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            isLoading = false
                        }
                    }
                }
            }
        }
    }
}

private struct ExerciseRow: View {
    let exercise: Exercise
    let isCurrent: Bool
    let duration: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(exercise.name ?? "")
                    .foregroundColor(isCurrent ? .yellow : .white)
                Spacer()
                Text(duration)
                    .foregroundColor(.white)
                if isCurrent {
                    Image(systemName: "play.circle.fill")
                        .foregroundColor(.yellow)
                }
            }
            .padding(.vertical, 8)
        }
        .listRowBackground(isCurrent ? Color(.systemGray5) : Color.clear)
    }
}

private struct ExerciseDetailView: View {
    let exercise: Exercise
    @ObservedObject var viewModel: WorkoutViewModel
    @Environment(\.presentationMode) var presentationMode

    @State private var duration: TimeInterval = 0
    @State private var distance: Double = 0
    @State private var repetitions: Int = 0
    @State private var isTimerRunning = false
    @State private var startTime: Date?

    // Nom de l'exercice avec gestion de nil
    private var exerciseName: String {
        exercise.name ?? "Exercice"
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text(exerciseName)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text(viewModel.formatTime(duration))
                    .font(.system(size: 60, weight: .bold))
                    .foregroundColor(.white)

                HStack(spacing: 40) {
                    timerControls
                }
                .padding()

                // Afficher les champs pertinents selon le type
                exerciseFields

                Spacer()

                finishButton
            }
            .padding()
            .background(Color.black.ignoresSafeArea())
            .navigationBarItems(trailing:
                Button("Fermer") {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(.yellow)
            )
        }
        .onAppear {
            // Initialiser les champs depuis l'exercice existant
            duration = exercise.duration
            distance = exercise.distance
            repetitions = Int(exercise.repetitions)
        }
    }

    // MARK: - Contrôles du timer

    private var timerControls: some View {
        HStack(spacing: 40) {
            Button(action: toggleTimer) {
                Image(systemName: isTimerRunning ? "pause.fill" : "play.fill")
                    .font(.title)
                    .foregroundColor(isTimerRunning ? .red : .green)
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(Circle())
            }

            Button(action: resetTimer) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.title)
                    .foregroundColor(.yellow)
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(Circle())
            }
        }
    }

    // MARK: - Champs de données

    @ViewBuilder
    private var exerciseFields: some View {
        if let name = exercise.name {
            if ["SkiErg", "RowErg"].contains(name) {
                distanceField
            }
            if ["Burpees Broad Jump", "Wall Balls"].contains(name) {
                repetitionsField
            }
        }
    }

    private var distanceField: some View {
        HStack {
            Text("Distance:")
                .foregroundColor(.white)
            TextField("Mètres", value: $distance, format: .number)
                .keyboardType(.numberPad)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .foregroundColor(.white)
        }
        .padding(.horizontal)
    }

    private var repetitionsField: some View {
        HStack {
            Text("Répétitions:")
                .foregroundColor(.white)
            TextField("Nombre", value: $repetitions, format: .number)
                .keyboardType(.numberPad)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .foregroundColor(.white)
        }
        .padding(.horizontal)
    }

    // MARK: - Bouton terminer

    private var finishButton: some View {
        Button(action: {
            viewModel.completeExercise(
                exercise: exercise,
                duration: duration,
                distance: distance,
                repetitions: repetitions
            )
            presentationMode.wrappedValue.dismiss()
        }) {
            Text("TERMINER")
                .font(.headline)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.yellow)
                .cornerRadius(8)
        }
        .padding(.horizontal)
    }

    // MARK: - Fonctions timer

    private func toggleTimer() {
        if isTimerRunning {
            isTimerRunning = false
        } else {
            isTimerRunning = true
            startTime = Date()
            startTimerUpdates()
        }
    }

    private func resetTimer() {
        duration = 0
        isTimerRunning = false
        startTime = nil
    }

    private func startTimerUpdates() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if isTimerRunning, let start = startTime {
                duration = Date().timeIntervalSince(start)
            } else {
                timer.invalidate()
            }
        }
    }
}


// MARK: - Start Workout

private struct StartWorkoutView: View {
    @ObservedObject var viewModel: WorkoutViewModel

    var body: some View {
        VStack(spacing: 24) {
            Text("Exercices sélectionnés") // Titre plus approprié
                .font(.headline)
                .foregroundColor(.white)
                .padding(.top)

            List {
                // Afficher les exercices du workout en cours ou du template
                ForEach(viewModel.currentExercises, id: \.id) { exercise in
                    if let name = exercise.name,
                       let def = ExerciseDefinitions.all[name] {
                        HStack {
                            Text(def.name)
                                .foregroundColor(.white)
                            Spacer()
                            Text(def.description)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .listStyle(PlainListStyle())

            Button("DÉMARRER L'ENTRAÎNEMENT") {
                viewModel.startWorkout()
            }
            .font(.headline)
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.yellow)
            .cornerRadius(8)
            .padding(.horizontal)
            .padding(.bottom)
        }
    }
}

#Preview {
    let context = DataController.shared.container.viewContext
    let workoutManager = WorkoutManager(dataController: DataController.shared)
    let viewModel = WorkoutViewModel(workoutManager: workoutManager)
    
    return WorkoutView(viewModel: viewModel)
        .environment(\.managedObjectContext, context)
        .preferredColorScheme(.dark)
}
