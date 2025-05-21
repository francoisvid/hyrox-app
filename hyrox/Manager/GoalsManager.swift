import Foundation
import CoreData

class GoalsManager {
    static let shared = GoalsManager()
    
    // Objectifs par défaut (utilisés uniquement si aucun objectif n'existe) // TODO : utiliser ExerciseDefinition
    private var defaultGoals: [String: TimeInterval] {
        var goals: [String: TimeInterval] = [:]
        for (name, definition) in ExerciseDefinitions.all {
            if let targetTime = definition.targetTime {
                goals[name] = targetTime
            }
        }
        return goals
    }
    
    // Préfixe pour les clés UserDefaults
    private let keyPrefix = "goal_"
    
    // UserDefaults app group pour partager entre Watch et iPhone
    private let defaults = UserDefaults(suiteName: "group.com.vdl-creation.hyrox.data")!
    
    // Cache en mémoire
    private var goalsCache: [String: TimeInterval] = [:]
    private var cacheInitialized = false
    
    private init() {
        // Initialiser le cache au démarrage
        refreshCache()
    }
    
    // Récupérer l'objectif pour un exercice
    func getGoalFor(exerciseName: String) -> TimeInterval {
        // Utiliser le cache si disponible
        if cacheInitialized, let cached = goalsCache[exerciseName] {
            return cached
        }
        
        // Sinon, chercher dans UserDefaults
        let key = keyPrefix + exerciseName
        let storedValue = defaults.double(forKey: key)
        
        // Si une valeur est trouvée, la retourner
        if storedValue > 0 {
            goalsCache[exerciseName] = storedValue
            return storedValue
        }
        
        // Sinon, retourner la valeur par défaut
        let defaultValue = defaultGoals[exerciseName] ?? 0
        goalsCache[exerciseName] = defaultValue
        return defaultValue
    }
    
    // Définir un objectif pour un exercice
    func setGoalFor(exerciseName: String, targetTime: TimeInterval) {
        print("💾 Sauvegarde objectif \(exerciseName): \(targetTime)s")
        
        // Mettre à jour le cache
        goalsCache[exerciseName] = targetTime
        
        // Sauvegarder dans UserDefaults
        let key = keyPrefix + exerciseName
        defaults.set(targetTime, forKey: key)
        defaults.synchronize() // Force la synchronisation immédiate
        
        print("✅ Objectif sauvegardé: \(exerciseName) = \(targetTime)")
        
        // Notifier pour mettre à jour l'UI
        NotificationCenter.default.post(
            name: NSNotification.Name("GoalsUpdated"),
            object: nil
        )
        
        // Envoyer les objectifs à l'autre appareil
        #if os(iOS)
        DataSyncManager.shared.sendGoals()
        #endif
    }
    
    // Récupérer tous les objectifs
    func getAllGoals() -> [String: TimeInterval] {
        // Si le cache n'est pas initialisé, le faire
        if !cacheInitialized {
            refreshCache()
        }
        
        return goalsCache
    }
    
    // Rafraîchir le cache depuis UserDefaults
    func refreshCache() {
        var goals: [String: TimeInterval] = [:]
        
        // D'abord, ajouter tous les objectifs par défaut
        for (exercise, defaultTime) in defaultGoals {
            let key = keyPrefix + exercise
            let storedValue = defaults.double(forKey: key)
            goals[exercise] = storedValue > 0 ? storedValue : defaultTime
        }
        
        // Chercher également d'autres objectifs potentiels
        let allKeys = defaults.dictionaryRepresentation().keys
        for key in allKeys {
            if key.hasPrefix(keyPrefix) {
                let exercise = String(key.dropFirst(keyPrefix.count))
                if goals[exercise] == nil {
                    goals[exercise] = defaults.double(forKey: key)
                }
            }
        }
        
        goalsCache = goals
        cacheInitialized = true
        print("✅ Cache initialisé avec \(goals.count) objectifs")
    }
    
    // Recevoir les objectifs de l'iPhone (Watch seulement)
    #if os(watchOS)
    func processReceivedGoals(_ goals: [String: Double]) {
        print("📱 Traitement de \(goals.count) objectifs reçus de l'iPhone")
        
        for (exercise, time) in goals {
            let key = keyPrefix + exercise
            defaults.set(time, forKey: key)
            goalsCache[exercise] = time
        }
        
        defaults.synchronize()
        cacheInitialized = true
        
        print("✅ \(goals.count) objectifs sauvegardés depuis l'iPhone")
        
        // Notifier pour mettre à jour l'UI
        NotificationCenter.default.post(
            name: NSNotification.Name("GoalsUpdated"),
            object: nil
        )
    }
    #endif
}
