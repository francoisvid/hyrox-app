import SwiftUI

struct ContentView: View {
    // Référence au singleton DataController
    private let dataController = DataController.shared

    var body: some View {
        // Créez directement la vue principale sans créer de nouveaux objets
        WatchWorkoutView(
            viewModel: WorkoutViewModel(
                workoutManager: WorkoutManager(dataController: dataController)
            )
        )
        .environment(\.managedObjectContext, dataController.container.viewContext)
    }
}
