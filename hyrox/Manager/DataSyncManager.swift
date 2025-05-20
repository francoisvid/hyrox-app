import Foundation
import CoreData
import WatchConnectivity

final class DataSyncManager: NSObject, WCSessionDelegate {
    static let shared = DataSyncManager()
    
    // Pour stocker le dernier token d'historique
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
    
    // Pour afficher dans l'UI
    var lastTokenForDisplay: String {
        if let token = lastToken {
            return "\(token)"
        }
        return "Aucun"
    }
    
    private let container = DataController.shared.container
    
    private override init() {
        super.init()
        
        if WCSession.isSupported() {
            print("WCSession est supporté, tentative d'activation...")
            WCSession.default.delegate = self
            WCSession.default.activate()
        } else {
            print("⚠️ WCSession n'est pas supporté sur cet appareil")
        }
    }
    
    // MARK: - Synchronisation directe
    
    // Envoie un workout spécifique à l'autre appareil
    func sendWorkout(_ workout: Workout) {
        guard
            let workoutID = workout.id?.uuidString,
            WCSession.default.activationState == .activated
        else { return }
        
        // Préparer les données du workout
        var workoutData: [String: Any] = [
            "name": workout.name ?? "Unnamed",
            "duration": workout.duration,
            "completed": workout.completed
        ]
        
        if let date = workout.date {
            workoutData["date"] = date.timeIntervalSince1970
        }
        
        // Préparer les données des exercices associés
        var exercisesData: [[String: Any]] = []
        if let exercises = workout.exercises?.allObjects as? [Exercise] {
            for exercise in exercises {
                guard let exerciseID = exercise.id?.uuidString else { continue }
                
                var exData: [String: Any] = [
                    "id": exerciseID,
                    "name": exercise.name ?? "Unnamed",
                    "duration": exercise.duration,
                    "workoutID": workoutID
                ]
                
                if let date = exercise.date {
                    exData["date"] = date.timeIntervalSince1970
                }
                
                // Ajouter des propriétés spécifiques
                if exercise.repetitions > 0 {
                    exData["repetitions"] = exercise.repetitions
                }
                
                if exercise.distance > 0 {
                    exData["distance"] = exercise.distance
                }
                
                exercisesData.append([
                    "entity": "Exercise",
                    "id": exerciseID,
                    "type": 0, // Insert
                    "values": exData
                ])
            }
        }
        
        // Créer le message complet
        var historyItems: [[String: Any]] = [
            [
                "entity": "Workout",
                "id": workoutID,
                "type": 0, // Insert
                "values": workoutData
            ]
        ]
        
        // Ajouter les exercices au message
        historyItems.append(contentsOf: exercisesData)
        
        let message: [String: Any] = ["history": historyItems]
        
        // Envoyer le message
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(
                message,
                replyHandler: { reply in
                    print("✅ Workout envoyé avec succès, réponse:", reply)
                },
                errorHandler: { error in
                    print("❌ Erreur d'envoi WCSession:", error)
                    WCSession.default.transferUserInfo(message)
                }
            )
        } else {
            print("📤 WCSession.isReachable = false, utilisation de transferUserInfo")
            WCSession.default.transferUserInfo(message)
        }
    }
    
    // Force l'envoi de tous les workouts récents
    func forceSendAllWorkouts() {
        let ctx = container.newBackgroundContext()
        ctx.perform {
            do {
                // Récupérer tous les workouts des dernières 24 heures
                let fetchRequest: NSFetchRequest<Workout> = Workout.fetchRequest()
                let oneDayAgo = Date().addingTimeInterval(-86400)
                fetchRequest.predicate = NSPredicate(format: "date >= %@", oneDayAgo as NSDate)
                let recentWorkouts = try ctx.fetch(fetchRequest)
                
                print("🔄 Envoi forcé de \(recentWorkouts.count) workouts récents")
                
                for workout in recentWorkouts {
                    self.sendWorkout(workout)
                }
                
            } catch {
                print("❌ Erreur récupération workouts récents:", error)
            }
        }
    }
    
    // MARK: - Méthode historique (pour compatibilité)
    
    func sendPendingChanges() {
        print("🔍 Début de sendPendingChanges")
        
        // Pour les besoins actuels, nous allons simplement utiliser la méthode directe
        forceSendAllWorkouts()
    }
    
    // MARK: - Test de communication
    
    func forceSendTestMessage() {
        let testMessage: [String: Any] = [
            "test": "ping",
            "timestamp": Date().timeIntervalSince1970,
            "device": "watch"
        ]
        
        print("📤 Test: envoi message test")
        
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(
                testMessage,
                replyHandler: { reply in
                    print("✅ Test: message test envoyé, réponse: \(reply)")
                },
                errorHandler: { error in
                    print("❌ Test: erreur envoi message test: \(error)")
                    WCSession.default.transferUserInfo(testMessage)
                }
            )
        } else {
            print("📤 Test: WCSession non reachable, utilisation transferUserInfo")
            WCSession.default.transferUserInfo(testMessage)
        }
    }
    
    // MARK: - WCSessionDelegate
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("🔌 WCSession activation complétée avec état: \(activationState.rawValue)")
        
        if let error = error {
            print("❌ Erreur d'activation WCSession:", error)
        }
        
        #if os(iOS)
        print("📱 iOS - isReachable: \(session.isReachable), isPaired: \(session.isPaired), isWatchAppInstalled: \(session.isWatchAppInstalled)")
        #else
        print("⌚️ watchOS - isReachable: \(session.isReachable), isCompanionAppInstalled: \(session.isCompanionAppInstalled)")
        #endif
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String:Any], replyHandler: @escaping ([String:Any]) -> Void) {
        print("📥 Message reçu avec replyHandler, clés:", message.keys)
        
        // Traiter les messages de test
        if message["test"] != nil {
            print("📥 Message de test reçu de \(message["device"] ?? "unknown") à \(message["timestamp"] ?? "unknown")")
            replyHandler(["status": "received", "type": "test_acknowledgement"])
            return
        }
        
        // Traiter les messages d'historique
        if let history = message["history"] as? [[String: Any]] {
            print("📥 Historique reçu avec \(history.count) changements")
            
            if let firstChange = history.first {
                print("📄 Premier changement: \(firstChange)")
            }
            
            processReceivedMessage(message)
            replyHandler(["status": "received", "type": "history_acknowledgement"])
        } else {
            print("⚠️ Message reçu avec format inconnu: \(message)")
            replyHandler(["status": "error", "message": "format_unknown"])
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String:Any]) {
        print("📥 Message reçu sans replyHandler, clés:", message.keys)
        
        if message["test"] != nil {
            print("📥 Message de test reçu")
            return
        }
        
        if message["history"] != nil {
            processReceivedMessage(message)
        }
    }
    
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        print("📥 UserInfo reçu, clés:", userInfo.keys)
        
        if userInfo["history"] != nil {
            processReceivedMessage(userInfo)
        }
    }
    
    private func processReceivedMessage(_ message: [String: Any]) {
        print("🔄 Début traitement message:", message.keys)
        
        guard let historyData = message["history"] as? [[String: Any]] else {
            print("⚠️ Format de message d'historique invalide")
            return
        }
        
        print("📊 Traitement de \(historyData.count) changements")
        
        let bg = container.newBackgroundContext()
        bg.perform {
            for change in historyData {
                print("🔍 Traitement changement:", change)
                
                guard
                    let entityName = change["entity"] as? String,
                    let idString = change["id"] as? String,
                    let rawType = change["type"] as? Int
                else {
                    print("⚠️ Données de changement incomplètes")
                    continue
                }
                
                if rawType == NSPersistentHistoryChangeType.insert.rawValue ||
                   rawType == NSPersistentHistoryChangeType.update.rawValue {
                    
                    guard let values = change["values"] as? [String: Any] else {
                        print("⚠️ Valeurs manquantes pour insert/update")
                        continue
                    }
                    
                    if entityName == "Workout" {
                        self.processWorkout(idString: idString, values: values, context: bg)
                    } else if entityName == "Exercise" {
                        self.processExercise(idString: idString, values: values, context: bg)
                    } else {
                        print("⚠️ Type d'entité inconnu:", entityName)
                    }
                } else if rawType == NSPersistentHistoryChangeType.delete.rawValue {
                    // Traiter les suppressions si nécessaire
                }
            }
            
            do {
                if bg.hasChanges {
                    try bg.save()
                    print("✅ Changements sauvegardés dans Core Data")
                } else {
                    print("ℹ️ Aucun changement à sauvegarder")
                }
            } catch {
                print("❌ Erreur lors de la sauvegarde:", error)
            }
        }
    }
    
    private func processWorkout(idString: String, values: [String: Any], context: NSManagedObjectContext) {
        let fetchRequest: NSFetchRequest<Workout> = Workout.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", idString)
        
        do {
            let existingWorkouts = try context.fetch(fetchRequest)
            
            let workout: Workout
            if let existing = existingWorkouts.first {
                workout = existing
                print("📝 Mise à jour d'un workout existant:", idString)
            } else {
                workout = Workout(context: context)
                workout.id = UUID(uuidString: idString)
                print("📝 Création d'un nouveau workout:", idString)
            }
            
            if let name = values["name"] as? String {
                workout.name = name
            }
            
            if let duration = values["duration"] as? Double {
                workout.duration = duration
            }
            
            if let completed = values["completed"] as? Bool {
                workout.completed = completed
            }
            
            if let dateTimestamp = values["date"] as? Double {
                workout.date = Date(timeIntervalSince1970: dateTimestamp)
            } else if let date = values["date"] as? Date {
                workout.date = date
            }
            
        } catch {
            print("❌ Erreur lors du traitement du workout:", error)
        }
    }
    
    private func processExercise(idString: String, values: [String: Any], context: NSManagedObjectContext) {
        let fetchRequest: NSFetchRequest<Exercise> = Exercise.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", idString)
        
        do {
            let existingExercises = try context.fetch(fetchRequest)
            
            let exercise: Exercise
            if let existing = existingExercises.first {
                exercise = existing
                print("📝 Mise à jour d'un exercice existant:", idString)
            } else {
                exercise = Exercise(context: context)
                exercise.id = UUID(uuidString: idString)
                print("📝 Création d'un nouvel exercice:", idString)
            }
            
            if let name = values["name"] as? String {
                exercise.name = name
            }
            
            if let duration = values["duration"] as? Double {
                exercise.duration = duration
            }
            
            if let repetitions = values["repetitions"] as? Int16 {
                exercise.repetitions = repetitions
            }
            
            if let distance = values["distance"] as? Double {
                exercise.distance = distance
            }
            
            if let dateTimestamp = values["date"] as? Double {
                exercise.date = Date(timeIntervalSince1970: dateTimestamp)
            } else if let date = values["date"] as? Date {
                exercise.date = date
            }
            
            if let workoutIDString = values["workoutID"] as? String,
               let workoutID = UUID(uuidString: workoutIDString) {
                let workoutFetch: NSFetchRequest<Workout> = Workout.fetchRequest()
                workoutFetch.predicate = NSPredicate(format: "id == %@", workoutID as CVarArg)
                
                let workouts = try context.fetch(workoutFetch)
                if let parentWorkout = workouts.first {
                    exercise.workout = parentWorkout
                    print("🔗 Exercice associé au workout:", workoutIDString)
                } else {
                    print("⚠️ Workout parent non trouvé:", workoutIDString)
                }
            }
        } catch {
            print("❌ Erreur lors du traitement de l'exercice:", error)
        }
    }
    
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("📱 WCSession est devenue inactive")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        print("📱 WCSession est désactivée, réactivation...")
        session.activate()
    }
    #endif
}
