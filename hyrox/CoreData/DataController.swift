import Foundation
import CoreData
import WatchConnectivity

/// Gère Core Data + synchronisation via Persistent History + WCSession
final class DataController: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = DataController()
     
     let container: NSPersistentContainer
    
    @Published var dummyFlag = false
     
     // Pour stocker le dernier token d'historique en App Group
     private var lastToken: NSPersistentHistoryToken? {
         get {
             guard let data = UserDefaults(suiteName: "group.com.vdl-creation.hyrox.data")?
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
             UserDefaults(suiteName: "group.com.vdl-creation.hyrox.data")?
                 .set(data, forKey: "lastHistoryToken")
         }
     }

    private override init() {
        // CoreData setup code remains the same
        container = NSPersistentContainer(name: "hyrox")
        
        // Configuration du tracking d'historique
        let description = container.persistentStoreDescriptions.first!
        description.setOption(true as NSNumber,
                          forKey: NSPersistentHistoryTrackingKey)
        
        container.loadPersistentStores { storeDescription, error in
            if let error = error {
                fatalError("Core Data store failed: \(error)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        super.init()
        
        // Ajouter l'observation de sauvegarde de contexte
//        NotificationCenter.default.addObserver(
//            self,
//            selector: #selector(contextDidSave(_:)),
//            name: .NSManagedObjectContextDidSave,
//            object: container.viewContext
//        )
    }

    func sendPendingChanges() {
        print("🔍 Début de sendPendingChanges")
        
        if WCSession.default.activationState != .activated {
            print("⚠️ WCSession n'est pas activé, tentative d'activation")
            WCSession.default.activate()
            return
        }
        
        let req = NSPersistentHistoryChangeRequest.fetchHistory(after: lastToken)
        req.resultType = .transactionsAndChanges

        do {
            guard
                let result = try container.viewContext.execute(req) as? NSPersistentHistoryResult,
                let transactions = result.result as? [NSPersistentHistoryTransaction],
                !transactions.isEmpty
            else {
                print("Aucune transaction à envoyer")
                return
            }

            // Compter le nombre total de changements
            var totalChanges = 0
            for tx in transactions {
                totalChanges += tx.changes?.count ?? 0
            }
            
            if totalChanges == 0 {
                print("⚠️ Transactions trouvées mais aucun changement à envoyer")
                // Mise à jour du token quand même pour éviter de scanner les mêmes transactions en boucle
                lastToken = transactions.last?.token
                return
            }

            var payload = [[String:Any]]()
            for tx in transactions {
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
                            // Tenter de récupérer l'objet en utilisant existingObject
                            if let obj = try? container.viewContext.existingObject(with: change.changedObjectID) {
                                let keys = Array(obj.entity.attributesByName.keys)
                                let values = obj.dictionaryWithValues(forKeys: keys)
                                record["values"] = values
                                
                                // Ajouter des logs détaillés pour afficher les valeurs
                                print("📝 Changement: \(entityName ?? "Inconnu") - \(change.changeType)")
                                print("   Valeurs: \(values)")
                            } else {
                                print("⚠️ Impossible de trouver l'objet pour l'ID: \(objectURI)")
                            }
                        } catch {
                            print("⚠️ Lect. obj \(objectURI) échouée:", error)
                        }
                    }

                    payload.append(record)
                }
                
                // Mémoriser le token pour la prochaine passe
                lastToken = tx.token
            }
            
            if payload.isEmpty {
                print("⚠️ Aucun changement valide à envoyer")
                return
            }

            // Utiliser une structure plus simple pour le message
            let message: [String: Any] = ["history": payload]
            
            print("📤 Préparation à l'envoi de \(payload.count) changements via WCSession")
            
            // Log détaillé de ce qui est envoyé
            print("🔍 Contenu du message: \(message)")
            
            if WCSession.default.isReachable {
                print("🔄 Envoi via sendMessage")
                WCSession.default.sendMessage(
                    message,
                    replyHandler: { reply in
                        print("✅ Message envoyé avec succès, réponse:", reply)
                    },
                    errorHandler: { error in
                        print("❌ Erreur d'envoi WCSession:", error)
                    }
                )
            } else {
                print("📤 WCSession.isReachable = false, utilisation de transferUserInfo")
                WCSession.default.transferUserInfo(message)
            }
            
            print("📊 Envoi de \(transactions.count) tx avec \(payload.count) changements, nouveau token = \(String(describing: lastToken))")
        } catch {
            print("❌ Erreur fetch history:", error)
        }
    }
    
    func createDemoDataIfNeeded() {
         let context = container.viewContext
         DataSeeder.seedInitialData(in: context)
     }

    func clearAllData() {
        let context = container.viewContext

        let workoutFetchRequest: NSFetchRequest<NSFetchRequestResult> = Workout.fetchRequest()
        let workoutDeleteRequest = NSBatchDeleteRequest(fetchRequest: workoutFetchRequest)

        do {
            try container.persistentStoreCoordinator.execute(workoutDeleteRequest, with: context)
            lastToken = nil
            try context.save()
            
            print("✅ Toutes les données ont été supprimées avec succès")

            // 🔁 Assurer la mise à jour sur le thread principal
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        } catch {
            print("❌ Erreur lors de la suppression des données: \(error)")
        }
    }
    
    func saveContext() {
        let ctx = container.viewContext
        guard ctx.hasChanges else { return }
        do {
            try ctx.save()
            // DataSyncManager sera notifié via le NotificationCenter
        } catch {
            print("Erreur lors de la sauvegarde du contexte:", error)
        }
    }
    
//    @objc private func contextDidSave(_ notification: Notification) {
//        DataSyncManager.shared.sendPendingChanges()
//    }
    
    func session(_ session: WCSession,
                 activationDidCompleteWith state: WCSessionActivationState,
                 error: Error?) {
        if let e = error {
            print("⚠️ WCSession activation failed on iOS:", e)
        } else {
            print("✅ WCSession activated on iOS:", state.rawValue)
        }
    }

    #if os(iOS)
        // 4) Sur iOS uniquement, tu peux implémenter ces callbacks si tu veux
        func sessionDidBecomeInactive(_ session: WCSession) { }
        func sessionDidDeactivate(_ session: WCSession) {
          // Si tu veux ré-activer la session après changement de montre :
          WCSession.default.activate()
        }
    #endif
}
