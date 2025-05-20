import Foundation
import CoreData
import WatchConnectivity

/// Gère Core Data + synchronisation via Persistent History + WCSession
final class DataController: NSObject, WCSessionDelegate {
    static let shared = DataController()

    let container: NSPersistentContainer

    // Pour stocker le dernier token d’historique en App Group
    private var lastToken: NSPersistentHistoryToken? {
        get {
            guard let data = UserDefaults(suiteName: "group.com.monApp")?
                            .data(forKey: "lastHistoryToken")
            else { return nil }
            return try? NSKeyedUnarchiver.unarchivedObject(
                ofClass: NSPersistentHistoryToken.self,
                from: data
            )
        }
        set {
            let data = try? NSKeyedArchiver.archivedData(
                withRootObject: newValue as Any,
                requiringSecureCoding: true
            )
            UserDefaults(suiteName: "group.com.monApp")?
                .set(data, forKey: "lastHistoryToken")
        }
    }

    private override init() {
        // 1️⃣ Création du container
        container = NSPersistentContainer(name: "hyrox")

        // 2️⃣ — ÉTAPE 1 : activer le tracking d’historique
        let description = container.persistentStoreDescriptions.first!
        description.setOption(true as NSNumber,
                              forKey: NSPersistentHistoryTrackingKey)

        // 3️⃣ Charger le store (maintenant avec history tracking activé)
        container.loadPersistentStores { storeDescription, error in
            if let error = error {
                fatalError("Core Data store failed: \(error)")
            }
        }

        // 4️⃣ Fusion automatique des changements
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        super.init()

        // 5️⃣ Démarrer la session WatchConnectivity
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func sendPendingChanges() {
        let req = NSPersistentHistoryChangeRequest.fetchHistory(after: lastToken)
        req.resultType = .transactionsOnly

        do {
            guard
                let result = try container.viewContext.execute(req) as? NSPersistentHistoryResult,
                let transactions = result.result as? [NSPersistentHistoryTransaction],
                !transactions.isEmpty
            else { return }

            var payload = [[String:Any]]()
            for tx in transactions {
                // Mémoriser le token pour la prochaine passe
                lastToken = tx.token

                for change in tx.changes ?? [] {
                    let entityName  = change.changedObjectID.entity.name
                    let objectURI   = change.changedObjectID.uriRepresentation().absoluteString
                    let changeType  = change.changeType.rawValue

                    var record: [String:Any] = [
                        "entity": entityName ?? "",
                        "id":     objectURI,
                        "type":   changeType
                    ]

                    if change.changeType == .insert || change.changeType == .update {
                        do {
                            let obj  = try container.viewContext
                                               .existingObject(with: change.changedObjectID)
                            let keys   = Array(obj.entity.attributesByName.keys)
                            let values = obj.dictionaryWithValues(forKeys: keys)
                            record["values"] = values
                        } catch {
                            print("⚠️ Lect. obj \(objectURI) échouée:", error)
                        }
                    }

                    payload.append(record)
                }
            }
            
            let data = try JSONSerialization.data(withJSONObject: payload)
            WCSession.default.sendMessage(
                ["history": data],
                replyHandler: nil,
                errorHandler: { print("WCSession send error:", $0) }
            )
            
            print("Will send \(transactions.count) tx, new token = \(String(describing: lastToken))")
        } catch {
            print("Erreur fetch history:", error)
        }
    }
    
    func createDemoDataIfNeeded() {
        let context = container.viewContext
        DataSeeder.seedInitialData(in: context)
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, didReceiveMessage message: [String:Any]) {
        guard
            let data = message["history"] as? Data,
            let arr  = try? JSONSerialization.jsonObject(with: data)
                            as? [[String:Any]]
        else { return }

        let bg = container.newBackgroundContext()
        bg.perform {
            for dict in arr {
                guard
                    let uriString = dict["id"]   as? String,
                    let url       = URL(string: uriString),
                    let objID     = bg.persistentStoreCoordinator?
                                      .managedObjectID(forURIRepresentation: url),
                    let rawType   = dict["type"] as? Int
                else { continue }

                do {
                    let obj = try bg.existingObject(with: objID)
                    if rawType == NSPersistentHistoryChangeType.insert.rawValue ||
                       rawType == NSPersistentHistoryChangeType.update.rawValue {
                        if let values = dict["values"] as? [String:Any] {
                            values.forEach { key, val in
                                obj.setValue(val is NSNull ? nil : val, forKey: key)
                            }
                        }
                    } else if rawType == NSPersistentHistoryChangeType.delete.rawValue {
                        bg.delete(obj)
                    }
                } catch {
                    print("Merge error:", error)
                }
            }
            try? bg.save()
        }
    }
    
    func saveContext() {
        let ctx = container.viewContext
        guard ctx.hasChanges else { return }
        do {
            try ctx.save()
            // 📤 juste après le save, on envoie les transactions pending
            sendPendingChanges()
        } catch {
            print("Erreur lors de la sauvegarde du contexte:", error)
        }
    }

    @objc private func contextDidSave(_ notification: Notification) {
        DataSyncManager.shared.sendPendingChanges()
    }

    func session(_ session: WCSession,
                 activationDidCompleteWith state: WCSessionActivationState,
                 error: Error?) {}
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {}
}
