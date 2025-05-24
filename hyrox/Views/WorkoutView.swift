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
                    GridItem(.flexible(), spacing: 15),
                    GridItem(.flexible(), spacing: 15)
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
                .padding(.horizontal, 20)
                .padding(.top, 30)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("Entraînements")
                        .font(.largeTitle.bold())
                        .foregroundColor(.white)
                        .padding(.leading, 10)
                        .padding(.top, 30)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingNewWorkoutSheet = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.yellow)
                            .padding(.trailing, 10)
                            .padding(.top, 30)
                    }
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(template.name ?? "Sans nom")
                .font(.headline)
                .foregroundColor(.white)
            
            if let description = template.workoutDescription {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            
            // Liste des exercices
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(orderedExercises.enumerated()), id: \.element.id) { index, exercise in
                        Text("\(index + 1). \(exercise.name ?? "")")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                }
                .padding(8)
            }
            .frame(height: 110)
            .background(Color(.systemGray5))
            .cornerRadius(8)
            
            if template.estimatedDuration > 0 {
                Text("Durée estimée: \(TimeFormatter.formatTime(template.estimatedDuration))")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Button(action: {
                guard !isStarting else { return }
                isStarting = true
                print("🟡 Clic sur le bouton \(isCurrentTemplate ? "VOIR" : "DÉMARRER") pour le template: \(template.name ?? "Sans nom")")
                onStart()
                // Réinitialiser après un court délai
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    isStarting = false
                }
            }) {
                Text(isCurrentTemplate ? "VOIR" : "DÉMARRER")
                    .font(.headline)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(isCurrentTemplate ? Color.gray : Color.yellow)
                    .cornerRadius(8)
            }
            .disabled(isStarting)
        }
        .padding(10)
        .frame(height: 250)
        .background(Color(.systemGray6))
        .cornerRadius(12)
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
                    ForEach(Workout.standardExerciseOrder, id: \.self) { name in
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
            Text("Exercices Hyrox")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.top)

            List {
                ForEach(Workout.standardExerciseOrder, id: \.self) { name in
                    if let def = ExerciseDefinitions.all[name] {
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
    
    // Créer quelques templates de test pour la preview
    let template1 = WorkoutTemplate(context: context)
    template1.id = UUID()
    template1.name = "Template Test 1"
    template1.workoutDescription = "Description du template 1"
    template1.createdAt = Date()
    
    // Ajouter des exercices au template 1
    let exercises1 = ["SkiErg", "RowErg", "Burpees Broad Jump"]
    for (index, name) in exercises1.enumerated() {
        let exercise = ExerciseTemplate(context: context)
        exercise.id = UUID()
        exercise.name = name
        exercise.order = Int16(index)
        exercise.workoutTemplate = template1
    }
    
    let template2 = WorkoutTemplate(context: context)
    template2.id = UUID()
    template2.name = "Template Test 2"
    template2.workoutDescription = "Description du template 2"
    template2.createdAt = Date()
    
    // Ajouter des exercices au template 2
    let exercises2 = ["Wall Balls", "Sled Push", "Sled Pull", "Farmers Carry"]
    for (index, name) in exercises2.enumerated() {
        let exercise = ExerciseTemplate(context: context)
        exercise.id = UUID()
        exercise.name = name
        exercise.order = Int16(index)
        exercise.workoutTemplate = template2
    }
    
    // Ajouter les templates au viewModel
    viewModel.setPreviewTemplates([template1, template2])
    
    return WorkoutView(viewModel: viewModel)
        .environment(\.managedObjectContext, context)
        .preferredColorScheme(.dark)
}
