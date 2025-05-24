import Foundation
import FirebaseAuth
import CoreData
import WatchConnectivity
#if os(iOS)
import FirebaseCore
import FirebaseFirestore
#endif

final class DataSyncManager: NSObject, WCSessionDelegate, ObservableObject {
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
        else {
            print("⚠️ Impossible d'envoyer le workout: session non activée ou ID manquant")
            return
        }
        
        // Vérifier si on a déjà envoyé récemment pour éviter les doublons
        let lastSentKey = "lastSent_\(workoutID)"
        let lastSent = UserDefaults.standard.object(forKey: lastSentKey) as? Date
        
        if let lastSent = lastSent, Date().timeIntervalSince(lastSent) < 5 {
            print("⏭️ Workout \(workoutID) déjà envoyé il y a moins de 5 secondes, skip")
            return
        }
        
        // Marquer comme envoyé
        UserDefaults.standard.set(Date(), forKey: lastSentKey)
        
        print("📤 Préparation envoi workout \(workoutID)")
        
        // Préparer les données du workout
        var workoutData: [String: Any] = [
            "name": workout.name ?? "Unnamed",
            "duration": workout.duration,
            "completed": workout.completed,
            "distance": workout.distance
        ]
        
        if let date = workout.date {
            workoutData["date"] = date.timeIntervalSince1970
        }
        
        // Préparer les données des exercices associés
        var exercisesData: [[String: Any]] = []
        if let exercises = workout.exercises?.allObjects as? [Exercise] {
            // Utiliser l'ordre standard des exercices
            let orderedExercises = workout.orderedExercises
            
            print("📊 \(orderedExercises.count) exercices à envoyer")
            
            for exercise in orderedExercises {
                guard let exerciseID = exercise.id?.uuidString else { continue }
                
                var exData: [String: Any] = [
                    "id": exerciseID,
                    "name": exercise.name ?? "Unnamed",
                    "duration": exercise.duration,
                    "distance": exercise.distance,
                    "repetitions": exercise.repetitions,
                    "workoutID": workoutID,
                    "order": exercise.order,
                    "personalBest": exercise.personalBest
                ]
                
                if let date = exercise.date {
                    exData["date"] = date.timeIntervalSince1970
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
        
        print("📤 Envoi de \(historyItems.count) éléments (1 workout + \(exercisesData.count) exercices)")
        
        // Envoyer le message avec gestion des erreurs améliorée
        if WCSession.default.isReachable {
            print("✅ Watch/iPhone accessible, envoi direct...")
            WCSession.default.sendMessage(
                message,
                replyHandler: { reply in
                    print("✅ Workout envoyé avec succès, réponse:", reply)
                    // Nettoyer le flag après succès
                    UserDefaults.standard.removeObject(forKey: lastSentKey)
                },
                errorHandler: { error in
                    print("❌ Erreur d'envoi WCSession:", error)
                    print("📤 Tentative avec transferUserInfo comme fallback")
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
        // Envoyer les objectifs dès que la session est activée
        if session.isReachable {
            sendGoals()
        }
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
        
        // Traiter les messages d'action
        if let action = message["action"] as? String {
            switch action {
            case "requestAllWorkouts":
                print("📥 Demande de synchronisation des workouts reçue")
                #if os(iOS)
                // Sur iOS, on envoie tous les workouts
                let context = container.viewContext
                let fetchRequest: NSFetchRequest<Workout> = Workout.fetchRequest()
                
                do {
                    let workouts = try context.fetch(fetchRequest)
                    print("📤 Envoi de \(workouts.count) workouts vers la Watch")
                    
                    // Créer le payload pour tous les workouts
                    var historyItems: [[String: Any]] = []
                    
                    for workout in workouts {
                        guard let workoutId = workout.id?.uuidString else { continue }
                        
                        // Données du workout
                        var workoutData: [String: Any] = [
                            "id": workoutId,
                            "name": workout.name ?? "Unnamed",
                            "duration": workout.duration,
                            "completed": workout.completed,
                            "distance": workout.distance,
                            "date": workout.date?.timeIntervalSince1970 ?? 0
                        ]
                        
                        // Ajouter le workout
                        historyItems.append([
                            "entity": "Workout",
                            "id": workoutId,
                            "type": 0, // Insert
                            "values": workoutData
                        ])
                        
                        // Ajouter les exercices
                        if let exercises = workout.exercises as? Set<Exercise> {
                            for exercise in exercises {
                                guard let exerciseId = exercise.id?.uuidString else { continue }
                                
                                let exerciseData: [String: Any] = [
                                    "id": exerciseId,
                                    "name": exercise.name ?? "Unnamed",
                                    "duration": exercise.duration,
                                    "distance": exercise.distance,
                                    "repetitions": exercise.repetitions,
                                    "workoutID": workoutId,
                                    "order": exercise.order,
                                    "personalBest": exercise.personalBest,
                                    "date": exercise.date?.timeIntervalSince1970 ?? 0
                                ]
                                
                                historyItems.append([
                                    "entity": "Exercise",
                                    "id": exerciseId,
                                    "type": 0, // Insert
                                    "values": exerciseData
                                ])
                            }
                        }
                    }
                    
                    let response: [String: Any] = [
                        "status": "success",
                        "type": "workouts_sync",
                        "workouts": historyItems
                    ]
                    replyHandler(response)
                } catch {
                    print("❌ Erreur récupération workouts:", error)
                    replyHandler(["status": "error", "message": "fetch_error"])
                }
                #else
                // Sur watchOS, on ne devrait pas recevoir cette action
                replyHandler(["status": "error", "message": "invalid_platform"])
                #endif
                return
                
            case "requestAllTemplates":
                print("📥 Demande de synchronisation des templates reçue")
                #if os(iOS)
                // Sur iOS, on envoie tous les templates
                let context = container.viewContext
                let fetchRequest: NSFetchRequest<WorkoutTemplate> = WorkoutTemplate.fetchRequest()
                
                do {
                    let templates = try context.fetch(fetchRequest)
                    print("📤 Envoi de \(templates.count) templates vers la Watch")
                    
                    // Créer le payload pour tous les templates
                    var historyItems: [[String: Any]] = []
                    
                    for template in templates {
                        guard let templateId = template.id?.uuidString else { continue }
                        
                        // Données du template
                        var templateData: [String: Any] = [
                            "id": templateId,
                            "name": template.name ?? "Unnamed",
                            "workoutDescription": template.workoutDescription ?? "",
                            "estimatedDuration": template.estimatedDuration,
                            "isPublic": template.isPublic,
                            "category": template.category ?? "",
                            "difficulty": template.difficulty ?? "",
                            "createdAt": template.createdAt?.timeIntervalSince1970 ?? 0
                        ]
                        
                        // Ajouter le template
                        historyItems.append([
                            "entity": "WorkoutTemplate",
                            "id": templateId,
                            "type": 0, // Insert
                            "values": templateData
                        ])
                        
                        // Ajouter les exercices du template
                        if let exercises = template.exercises as? Set<ExerciseTemplate> {
                            for exercise in exercises {
                                guard let exerciseId = exercise.id?.uuidString else { continue }
                                
                                let exerciseData: [String: Any] = [
                                    "id": exerciseId,
                                    "name": exercise.name ?? "Unnamed",
                                    "defaultDuration": exercise.defaultDuration,
                                    "defaultDistance": exercise.defaultDistance,
                                    "defaultRepetitions": exercise.defaultRepetitions,
                                    "order": exercise.order,
                                    "exerciseDescription": exercise.exerciseDescription ?? "",
                                    "templateID": templateId
                                ]
                                
                                historyItems.append([
                                    "entity": "ExerciseTemplate",
                                    "id": exerciseId,
                                    "type": 0, // Insert
                                    "values": exerciseData
                                ])
                            }
                        }
                    }
                    
                    let response: [String: Any] = [
                        "status": "success",
                        "type": "templates_sync",
                        "templates": historyItems
                    ]
                    replyHandler(response)
                } catch {
                    print("❌ Erreur récupération templates:", error)
                    replyHandler(["status": "error", "message": "fetch_error"])
                }
                #else
                // Sur watchOS, on ne devrait pas recevoir cette action
                replyHandler(["status": "error", "message": "invalid_platform"])
                #endif
                return
                
            default:
                print("⚠️ Action inconnue:", action)
                replyHandler(["status": "error", "message": "unknown_action"])
                return
            }
        }
        
        // Traiter les messages d'objectifs
        if let type = message["type"] as? String, type == "goals",
           let goals = message["goals"] as? [String: Double] {
            print("📥 Objectifs reçus: \(goals.count) exercices")
            #if os(watchOS)
            GoalsManager.shared.processReceivedGoals(goals)
            #else
            // Sur iOS, on met à jour le cache
            for (name, time) in goals {
                GoalsManager.shared.setGoalFor(exerciseName: name, targetTime: time)
            }
            #endif
            replyHandler(["status": "received", "type": "goals_acknowledgement"])
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
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        print("📱 Message reçu: \(message["action"] ?? message["type"] ?? "unknown")")
        
        // 1. Gérer les actions spécifiques en premier
        if let action = message["action"] as? String {
            DispatchQueue.main.async {
                switch action {
                case "deleteAllWorkouts", "clearAllData":
                    print("🗑️ Suppression de tous les workouts demandée")
                    DataController.shared.clearAllData()
                    
                    // Notification pour rafraîchir l'UI
                    NotificationCenter.default.post(
                        name: NSNotification.Name("WorkoutsDeleted"),
                        object: nil
                    )
                    
                case "deleteWorkout":
                    if let workoutId = message["workoutId"] as? String {
                        print("🗑️ Suppression du workout \(workoutId)")
                        self.handleDeleteWorkout(workoutId)
                        
                        // Notification pour rafraîchir l'UI
                        NotificationCenter.default.post(
                            name: NSNotification.Name("WorkoutDeleted"),
                            object: nil,
                            userInfo: ["workoutId": workoutId]
                        )
                    }
                    
                case "requestAllWorkouts":
                    #if os(watchOS)
                    print("📤 Envoi de tous les workouts vers l'iPhone")
                    self.sendAllWorkoutsToPhone()
                    #endif
                    
                default:
                    print("⚠️ Action inconnue: \(action)")
                }
            }
            return
        }
        
        // 2. Gérer les messages de type (goals, etc.)
        if let type = message["type"] as? String {
            switch type {
            case "goals":
                if let goals = message["goals"] as? [String: Double] {
                    print("📥 Objectifs reçus: \(goals.count) exercices")
                    #if os(watchOS)
                    GoalsManager.shared.processReceivedGoals(goals)
                    #else
                    // Sur iOS, mettre à jour le cache
                    for (name, time) in goals {
                        GoalsManager.shared.setGoalFor(exerciseName: name, targetTime: time)
                    }
                    #endif
                }
                return
                
            case "test":
                print("📥 Message de test reçu")
                return
                
            default:
                print("⚠️ Type de message inconnu: \(type)")
            }
        }
        
        // 3. Gérer les messages d'historique (workouts/exercices)
        if let history = message["history"] as? [[String: Any]] {
            print("📥 Historique reçu avec \(history.count) changements")
            processReceivedMessage(message)
            return
        }
        
        // 4. Si aucun cas ne correspond
        print("⚠️ Format de message non reconnu: \(message.keys)")
    }
    
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        print("📥 UserInfo reçu, clés:", userInfo.keys)

        // 📌 1. Traiter la suppression complète
        if let action = userInfo["action"] as? String, action == "clearAllData" {
            print("🧹 Suppression demandée via WCSession")
            DispatchQueue.main.async {
                DataController.shared.clearAllData()
            }
            return
        }

        // 📌 2. Traiter les objectifs
        if let type = userInfo["type"] as? String, type == "goals",
           let goals = userInfo["goals"] as? [String: Double] {
            print("📥 Objectifs reçus via transferUserInfo: \(goals.count) exercices")
            #if os(watchOS)
            GoalsManager.shared.processReceivedGoals(goals)
            #else
            for (name, time) in goals {
                GoalsManager.shared.setGoalFor(exerciseName: name, targetTime: time)
            }
            #endif
            return
        }

        // 📌 3. Traiter l'historique (workouts)
        if let historyPayload = userInfo["history"] as? [[String: Any]] {
            let bg = DataController.shared.container.newBackgroundContext()
            bg.perform {
                for dict in historyPayload {
                    guard
                        let uriString = dict["id"] as? String,
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
                do {
                    try bg.save()
                    print("✅ Merged \(historyPayload.count) changes from Watch")
                } catch {
                    print("❌ Failed saving merged data:", error)
                }
            }
        }
    }
    
    func processReceivedMessage(_ message: [String: Any]) {
        print("🔄 Début traitement message:", message.keys)
        
        guard let historyData = message["history"] as? [[String: Any]] else {
            print("⚠️ Format de message d'historique invalide")
            return
        }
        
        print("📊 Traitement de \(historyData.count) changements")
        
        let bg = container.newBackgroundContext()
        bg.perform {
            var workoutsToSync: Set<String> = []
            var processedIds: Set<String> = []
            var hasNewWorkouts = false
            var hasNewTemplates = false
            
            // 1. Traiter tous les changements
            for change in historyData {
                guard
                    let entityName = change["entity"] as? String,
                    let idString = change["id"] as? String,
                    let rawType = change["type"] as? Int
                else {
                    print("⚠️ Données de changement incomplètes")
                    continue
                }
                
                let uniqueKey = "\(entityName)-\(idString)"
                if processedIds.contains(uniqueKey) {
                    print("⏭️ Déjà traité: \(uniqueKey)")
                    continue
                }
                processedIds.insert(uniqueKey)
                
                if rawType == NSPersistentHistoryChangeType.insert.rawValue ||
                   rawType == NSPersistentHistoryChangeType.update.rawValue {
                    
                    guard let values = change["values"] as? [String: Any] else {
                        print("⚠️ Valeurs manquantes pour insert/update")
                        continue
                    }
                    
                    switch entityName {
                    case "Workout":
                        self.processWorkout(idString: idString, values: values, context: bg)
                        workoutsToSync.insert(idString)
                        hasNewWorkouts = true
                    case "Exercise":
                        self.processExercise(idString: idString, values: values, context: bg)
                        if let workoutID = values["workoutID"] as? String {
                            workoutsToSync.insert(workoutID)
                        }
                    case "WorkoutTemplate":
                        self.processWorkoutTemplate(idString: idString, values: values, context: bg)
                        hasNewTemplates = true
                    case "ExerciseTemplate":
                        self.processExerciseTemplate(idString: idString, values: values, context: bg)
                    default:
                        print("⚠️ Type d'entité inconnu: \(entityName)")
                    }
                }
            }
            
            // 2. Sauvegarder dans CoreData
            do {
                if bg.hasChanges {
                    try bg.save()
                    print("✅ Changements sauvegardés dans Core Data")
                    
                    // 3. Notifier l'UI si nouveaux workouts ou templates
                    if hasNewWorkouts {
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(
                                name: NSNotification.Name("WorkoutReceived"),
                                object: nil
                            )
                        }
                    }
                    
                    if hasNewTemplates {
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(
                                name: NSNotification.Name("WorkoutTemplateReceived"),
                                object: nil
                            )
                        }
                    }
                    
                    // 4. Synchroniser avec Firebase (iOS seulement)
                    #if os(iOS)
                    Task { @MainActor in
                        for workoutId in workoutsToSync {
                            do {
                                let fetchRequest: NSFetchRequest<Workout> = Workout.fetchRequest()
                                fetchRequest.predicate = NSPredicate(format: "id == %@", workoutId)
                                
                                let context = self.container.viewContext
                                if let workout = try context.fetch(fetchRequest).first {
                                    try await self.saveWorkoutToFirebase(workout)
                                    print("✅ Workout \(workoutId) synchronisé avec Firebase")
                                }
                            } catch {
                                print("❌ Erreur synchronisation Firebase pour workout \(workoutId):", error)
                            }
                        }
                    }
                    #endif
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
    
    // Envoyer les objectifs à l'autre appareil
    func sendGoals() {
        guard WCSession.default.activationState == .activated else {
            print("⚠️ Impossible d'envoyer les objectifs : WCSession non activée")
            return
        }
        
        let goals = GoalsManager.shared.getAllGoals()
        print("📱 Envoi de \(goals.count) objectifs à la Watch")
        
        // Afficher les objectifs pour le debug
        for (name, time) in goals {
            print("📱 Objectif \(name): \(time)s")
        }
        
        let message: [String: Any] = [
            "type": "goals",
            "goals": goals
        ]
        
        // Essayer d'abord avec sendMessage
        if WCSession.default.isReachable {
            print("📱 Watch reachable, envoi direct...")
            WCSession.default.sendMessage(message, replyHandler: { reply in
                print("✅ Objectifs envoyés avec succès, réponse:", reply)
            }) { error in
                print("❌ Erreur envoi objectifs: \(error.localizedDescription)")
                // En cas d'échec, utiliser transferUserInfo
                print("📱 Tentative avec transferUserInfo...")
                WCSession.default.transferUserInfo(message)
            }
        } else {
            print("📱 Watch non reachable, utilisation de transferUserInfo")
            // Envoyer plusieurs fois pour s'assurer que ça passe
            for _ in 0...2 {
                WCSession.default.transferUserInfo(message)
            }
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
    
    // MARK: - Firebase Operations
    
    #if os(iOS)
    func deleteWorkout(_ workoutId: String) async throws {
        let db = Firestore.firestore()
        
        // Supprimer les exercices d'abord
        let exercisesSnapshot = try await db.collection("workouts")
            .document(workoutId)
            .collection("exercises")
            .getDocuments()
        
        for exerciseDoc in exercisesSnapshot.documents {
            try await db.collection("workouts")
                .document(workoutId)
                .collection("exercises")
                .document(exerciseDoc.documentID)
                .delete()
        }
        
        // Supprimer le workout
        try await db.collection("workouts")
            .document(workoutId)
            .delete()
        
        // Supprimer les statistiques associées
        try await db.collection("users")
            .document("test_user") // ID utilisateur par défaut pour les tests
            .collection("statistics")
            .document("workouts")
            .collection(workoutId)
            .document(workoutId)
            .delete()
    }
    
    func saveWorkoutToFirebase(_ workout: Workout) async throws {
        guard let workoutId = workout.id?.uuidString else {
            throw NSError(domain: "DataSyncManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid workout ID"])
        }
        
        let db = Firestore.firestore()
        
        // Utiliser convertToFirebase qui inclut déjà les exercices dans un array
        guard var workoutData = FirebaseStructure.convertToFirebase(workout) else {
            throw NSError(domain: "DataSyncManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert workout"])
        }
        
        // Ajouter l'userId si disponible
        #if os(iOS)
        if let userId = Auth.auth().currentUser?.uid {
            workoutData["userId"] = userId
        }
        #endif
        
        // Une seule écriture avec tout inclus
        let workoutRef = db.collection("workouts").document(workoutId)
        try await workoutRef.setData(workoutData, merge: true)
        
        print("✅ Workout complet (avec \(workout.exercises?.count ?? 0) exercices) sauvegardé dans Firebase")
    }
    
    func deleteAllWorkoutsFromFirebase() async throws {
        print("deleteAllWorkoutsFromFirebase")
        let db = Firestore.firestore()
        let workoutsCollection = db.collection("workouts")
        
        // Obtenir tous les documents dans la collection workouts
        let snapshot = try await workoutsCollection.getDocuments()
        
        // Supprimer chaque document workout
        for document in snapshot.documents {
            try await document.reference.delete()
        }
    }
    #endif
    
    // MARK: - Suppression synchronisée

    #if os(iOS)
    func deleteWorkoutEverywhere(_ workoutId: String) async throws {
        // 1. Supprimer de Firebase
        try await deleteWorkout(workoutId)
        
        // 2. Envoyer message de suppression à la Watch
        let deleteMessage: [String: Any] = [
            "action": "deleteWorkout",
            "workoutId": workoutId,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(deleteMessage, replyHandler: nil) { error in
                print("❌ Erreur envoi suppression à Watch: \(error)")
                // Utiliser transferUserInfo comme fallback
                WCSession.default.transferUserInfo(deleteMessage)
            }
        } else {
            WCSession.default.transferUserInfo(deleteMessage)
        }
    }

    func syncAllWorkoutsFromWatch() async throws {
        // Implémenter la récupération des workouts depuis la Watch
        let message: [String: Any] = [
            "action": "requestAllWorkouts",
            "timestamp": Date().timeIntervalSince1970
        ]
        
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: { response in
                if let workouts = response["workouts"] as? [[String: Any]] {
                    Task {
                        for workoutData in workouts {
                            // Traiter chaque workout
                            self.processReceivedMessage(["history": [workoutData]])
                        }
                    }
                }
            }) { error in
                print("❌ Erreur récupération workouts Watch: \(error)")
            }
        }
    }
    #endif
    
    #if os(watchOS)
    // MARK: - Watch → iPhone sync

    func sendAllWorkoutsToPhone() {
        let message: [String: Any] = [
            "action": "requestAllWorkouts",
            "timestamp": Date().timeIntervalSince1970
        ]
        
        print("⌚️ Demande de synchronisation des workouts...")
        
        if WCSession.default.isReachable {
            print("⌚️ iPhone accessible, envoi direct...")
            WCSession.default.sendMessage(message, replyHandler: { reply in
                print("⌚️ Réponse reçue de l'iPhone:", reply)
                
                if let status = reply["status"] as? String,
                   status == "success",
                   let type = reply["type"] as? String,
                   type == "workouts_sync",
                   let workouts = reply["workouts"] as? [[String: Any]] {
                    print("⌚️ Traitement de \(workouts.count) workouts reçus")
                    self.processReceivedMessage(["history": workouts])
                } else {
                    print("⌚️ Format de réponse invalide:", reply)
                }
            }) { error in
                print("❌ Erreur envoi demande de synchronisation:", error)
                // Fallback avec transferUserInfo
                WCSession.default.transferUserInfo(message)
            }
        } else {
            print("⌚️ iPhone non accessible, utilisation de transferUserInfo")
            WCSession.default.transferUserInfo(message)
        }
    }
    #endif
    
    private func handleDeleteWorkout(_ workoutId: String) {
        let context = container.viewContext
        let fetchRequest: NSFetchRequest<Workout> = Workout.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", workoutId)
        
        context.perform {
            do {
                let workouts = try context.fetch(fetchRequest)
                for workout in workouts {
                    context.delete(workout)
                }
                try context.save()
                print("✅ Workout \(workoutId) supprimé localement")
                
                // Notification pour rafraîchir l'UI
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("WorkoutDeleted"),
                        object: nil
                    )
                }
            } catch {
                print("❌ Erreur suppression workout local: \(error)")
            }
        }
    }
    
    // MARK: - WorkoutTemplate Sync
    
    func sendWorkoutTemplate(_ template: WorkoutTemplate) {
        guard
            let templateID = template.id?.uuidString,
            WCSession.default.activationState == .activated
        else {
            print("⚠️ Impossible d'envoyer le template: session non activée ou ID manquant")
            return
        }
        
        // Vérifier si on a déjà envoyé récemment pour éviter les doublons
        let lastSentKey = "lastSentTemplate_\(templateID)"
        let lastSent = UserDefaults.standard.object(forKey: lastSentKey) as? Date
        
        if let lastSent = lastSent, Date().timeIntervalSince(lastSent) < 5 {
            print("⏭️ Template \(templateID) déjà envoyé il y a moins de 5 secondes, skip")
            return
        }
        
        // Marquer comme envoyé
        UserDefaults.standard.set(Date(), forKey: lastSentKey)
        
        print("📤 Préparation envoi template \(templateID)")
        
        // Préparer les données du template
        var templateData: [String: Any] = [
            "id": templateID,
            "name": template.name ?? "Unnamed",
            "workoutDescription": template.workoutDescription ?? "",
            "estimatedDuration": template.estimatedDuration,
            "isPublic": template.isPublic,
            "category": template.category ?? "",
            "difficulty": template.difficulty ?? ""
        ]
        
        if let date = template.createdAt {
            templateData["createdAt"] = date.timeIntervalSince1970
        }
        
        // Préparer les données des exercices associés
        var exercisesData: [[String: Any]] = []
        if let exercises = template.exercises?.allObjects as? [ExerciseTemplate] {
            // Utiliser l'ordre des exercices
            let orderedExercises = exercises.sorted { $0.order < $1.order }
            
            print("📊 \(orderedExercises.count) exercices à envoyer")
            
            for exercise in orderedExercises {
                guard let exerciseID = exercise.id?.uuidString else { continue }
                
                var exData: [String: Any] = [
                    "id": exerciseID,
                    "name": exercise.name ?? "Unnamed",
                    "defaultDuration": exercise.defaultDuration,
                    "defaultDistance": exercise.defaultDistance,
                    "defaultRepetitions": exercise.defaultRepetitions,
                    "order": exercise.order,
                    "exerciseDescription": exercise.exerciseDescription ?? ""
                ]
                
                exercisesData.append([
                    "entity": "ExerciseTemplate",
                    "id": exerciseID,
                    "type": 0, // Insert
                    "values": exData
                ])
            }
        }
        
        // Créer le message complet
        var historyItems: [[String: Any]] = [
            [
                "entity": "WorkoutTemplate",
                "id": templateID,
                "type": 0, // Insert
                "values": templateData
            ]
        ]
        
        // Ajouter les exercices au message
        historyItems.append(contentsOf: exercisesData)
        
        let message: [String: Any] = ["history": historyItems]
        
        print("📤 Envoi de \(historyItems.count) éléments (1 template + \(exercisesData.count) exercices)")
        
        // Envoyer le message avec gestion des erreurs améliorée
        if WCSession.default.isReachable {
            print("✅ Watch/iPhone accessible, envoi direct...")
            WCSession.default.sendMessage(
                message,
                replyHandler: { reply in
                    print("✅ Template envoyé avec succès, réponse:", reply)
                    // Nettoyer le flag après succès
                    UserDefaults.standard.removeObject(forKey: lastSentKey)
                },
                errorHandler: { error in
                    print("❌ Erreur d'envoi WCSession:", error)
                    print("📤 Tentative avec transferUserInfo comme fallback")
                    WCSession.default.transferUserInfo(message)
                }
            )
        } else {
            print("📤 WCSession.isReachable = false, utilisation de transferUserInfo")
            WCSession.default.transferUserInfo(message)
        }
    }
    
    // Force l'envoi de tous les templates
    func forceSendAllTemplates() {
        let ctx = container.newBackgroundContext()
        ctx.perform {
            do {
                let fetchRequest: NSFetchRequest<WorkoutTemplate> = WorkoutTemplate.fetchRequest()
                let templates = try ctx.fetch(fetchRequest)
                
                print("🔄 Envoi forcé de \(templates.count) templates")
                
                for template in templates {
                    self.sendWorkoutTemplate(template)
                }
                
            } catch {
                print("❌ Erreur récupération templates:", error)
            }
        }
    }
    
    private func processWorkoutTemplate(idString: String, values: [String: Any], context: NSManagedObjectContext) {
        let fetchRequest: NSFetchRequest<WorkoutTemplate> = WorkoutTemplate.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", idString)
        
        do {
            let existingTemplates = try context.fetch(fetchRequest)
            
            let template: WorkoutTemplate
            if let existing = existingTemplates.first {
                template = existing
                print("📝 Mise à jour d'un template existant:", idString)
            } else {
                template = WorkoutTemplate(context: context)
                template.id = UUID(uuidString: idString)
                print("📝 Création d'un nouveau template:", idString)
            }
            
            if let name = values["name"] as? String {
                template.name = name
            }
            
            if let description = values["workoutDescription"] as? String {
                template.workoutDescription = description
            }
            
            if let duration = values["estimatedDuration"] as? Double {
                template.estimatedDuration = duration
            }
            
            if let isPublic = values["isPublic"] as? Bool {
                template.isPublic = isPublic
            }
            
            if let category = values["category"] as? String {
                template.category = category
            }
            
            if let difficulty = values["difficulty"] as? String {
                template.difficulty = difficulty
            }
            
            if let dateTimestamp = values["createdAt"] as? Double {
                template.createdAt = Date(timeIntervalSince1970: dateTimestamp)
            }
            
        } catch {
            print("❌ Erreur lors du traitement du template:", error)
        }
    }
    
    private func processExerciseTemplate(idString: String, values: [String: Any], context: NSManagedObjectContext) {
        let fetchRequest: NSFetchRequest<ExerciseTemplate> = ExerciseTemplate.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", idString)
        
        do {
            let existingExercises = try context.fetch(fetchRequest)
            
            let exercise: ExerciseTemplate
            if let existing = existingExercises.first {
                exercise = existing
                print("📝 Mise à jour d'un exercice template existant:", idString)
            } else {
                exercise = ExerciseTemplate(context: context)
                exercise.id = UUID(uuidString: idString)
                print("📝 Création d'un nouvel exercice template:", idString)
            }
            
            if let name = values["name"] as? String {
                exercise.name = name
            }
            
            if let duration = values["defaultDuration"] as? Double {
                exercise.defaultDuration = duration
            }
            
            if let distance = values["defaultDistance"] as? Double {
                exercise.defaultDistance = distance
            }
            
            if let repetitions = values["defaultRepetitions"] as? Int16 {
                exercise.defaultRepetitions = repetitions
            }
            
            if let order = values["order"] as? Int16 {
                exercise.order = order
            }
            
            if let description = values["exerciseDescription"] as? String {
                exercise.exerciseDescription = description
            }
            
            // Associer au template parent si nécessaire
            if let templateIDString = values["templateID"] as? String,
               let templateID = UUID(uuidString: templateIDString) {
                let templateFetch: NSFetchRequest<WorkoutTemplate> = WorkoutTemplate.fetchRequest()
                templateFetch.predicate = NSPredicate(format: "id == %@", templateID as CVarArg)
                
                let templates = try context.fetch(templateFetch)
                if let parentTemplate = templates.first {
                    exercise.workoutTemplate = parentTemplate
                    print("🔗 Exercice template associé au template:", templateIDString)
                } else {
                    print("⚠️ Template parent non trouvé:", templateIDString)
                }
            }
        } catch {
            print("❌ Erreur lors du traitement de l'exercice template:", error)
        }
    }
}
