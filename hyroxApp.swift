// HyroxApp.swift

import SwiftUI

@main
struct HyroxApp: App {
    private let dataController = DataController.shared

    init() {
        dataController.createDemoDataIfNeeded()
        _ = DataController.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext,
                              dataController.container.viewContext)
        }
    }
}
