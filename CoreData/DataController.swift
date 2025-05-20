// DataController.swift

import Foundation
import CoreData

final class DataController {
    static let shared = DataController()

    let container: NSPersistentContainer

    private init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "hyrox")
        let description = container.persistentStoreDescriptions.first!

        if inMemory {
            description.url = URL(fileURLWithPath: "/dev/null")
        }

        // Enable history tracking & remote change notifications
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        container.loadPersistentStores { storeDescription, error in
            if let error = error {
                fatalError("Unresolved Core Data error: \(error.localizedDescription)")
            }
        }

        // Configure viewContext
        container.viewContext.transactionAuthor = "main"
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        // Observe saves to trigger sync
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(contextDidSave(_:)),
            name: .NSManagedObjectContextDidSave,
            object: container.viewContext
        )
    }
    
    func createDemoDataIfNeeded() {
        let context = container.viewContext
        DataSeeder.seedInitialData(in: context)
    }

    /// A background context for heavy operations
    func backgroundContext() -> NSManagedObjectContext {
        let ctx = container.newBackgroundContext()
        ctx.transactionAuthor = "background"
        return ctx
    }

    /// Save viewContext if there are changes
    func save() {
        let context = container.viewContext
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            print("Error saving viewContext: \(error.localizedDescription)")
        }
    }

    @objc private func contextDidSave(_ notification: Notification) {
        DataSyncManager.shared.sendPendingChanges()
    }
}
