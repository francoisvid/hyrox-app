// HyroxApp.swift

import SwiftUI

@main
struct HyroxApp: App {
    private let dataController = DataController.shared

    init() {
        dataController.createDemoDataIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext,
                              dataController.container.viewContext)
        }
    }
}
