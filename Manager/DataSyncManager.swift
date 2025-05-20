// Manager/DataSyncManager.swift

import Foundation
import CoreData
import WatchConnectivity

final class DataSyncManager: NSObject, WCSessionDelegate {
    static let shared = DataSyncManager()
    
    // 1. Token d’historique Core Data
    private var lastToken: NSPersistentHistoryToken?
    // 2. Référence au container Core Data
    private let container = DataController.shared.container
    
    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Lit l’historique des transactions depuis `lastToken`, puis l’envoie via WCSession
    func sendPendingChanges() {
        // 3. Crée la requête pour l’historique depuis lastToken
        let request = NSPersistentHistoryChangeRequest.fetchHistory(after: lastToken)
        // Utiliser le bon enum case pour récupérer les transactions :contentReference[oaicite:0]{index=0}
        request.resultType = .transactionsOnly

        do {
            // 4. Exécute la requête
            guard
                let result = try container.viewContext.execute(request) as? NSPersistentHistoryResult,
                let transactions = result.result as? [NSPersistentHistoryTransaction],
                !transactions.isEmpty
            else { return }

            // 5. Met à jour le token pour la prochaine lecture
            lastToken = transactions.last?.token

            // 6. Sérialise chaque transaction en dictionnaire
            var payload: [[String: Any]] = []
            for tx in transactions {
                var txDict: [String: Any] = [
                    "timestamp": tx.timestamp
                ]
                // tx.token est non-optionnel
                let token = tx.token
                // Archive le token en Data
                let data = try NSKeyedArchiver.archivedData(
                    withRootObject: token,
                    requiringSecureCoding: true
                )
                txDict["tokenData"] = data

                payload.append(txDict)
            }

            // 7. Envoie le message à la Watch
            WCSession.default.sendMessage(
                ["history": payload],
                replyHandler: nil,
                errorHandler: { error in
                    print("WCSession send error: \(error.localizedDescription)")
                }
            )
        } catch {
            print("Error fetching Core Data history: \(error.localizedDescription)")
        }
    }

    // MARK: - WCSessionDelegate stubs

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) { }

    func sessionDidBecomeInactive(_ session: WCSession) { }
    func sessionDidDeactivate(_ session: WCSession) { }

    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        // À implémenter : décoder le payload et merger dans container.viewContext
    }
}
