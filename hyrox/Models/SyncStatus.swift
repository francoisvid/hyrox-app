import Foundation
import Combine

/// Statuts possibles pour la synchronisation
enum SyncStatus: String {
    case pending = "pending"    // En attente de synchronisation
    case synced = "synced"      // Synchronisé avec succès
    case conflict = "conflict"  // Conflit détecté
    case error = "error"        // Erreur lors de la synchronisation
    
    /// Vérifie si l'objet est synchronisé
    var isSynced: Bool {
        self == .synced
    }
    
    /// Vérifie si l'objet a un conflit
    var hasConflict: Bool {
        self == .conflict
    }
    
    /// Vérifie si l'objet est en attente
    var isPending: Bool {
        self == .pending
    }
    
    /// Vérifie si l'objet a une erreur
    var hasError: Bool {
        self == .error
    }
}

/// Protocole pour les entités synchronisables
protocol Syncable {
    var firebaseId: String? { get set }
    var lastSyncedAt: Date? { get set }
    var syncStatus: String? { get set }
    var version: Int32 { get set }
}

/// Extension pour les entités synchronisables
extension Syncable {
    /// Met à jour le statut de synchronisation
    mutating func updateSyncStatus(_ status: SyncStatus) {
        syncStatus = status.rawValue
        if status == .synced {
            lastSyncedAt = Date()
        }
    }
    
    /// Vérifie si l'objet est synchronisé
    var isSynced: Bool {
        guard let status = syncStatus else { return false }
        return SyncStatus(rawValue: status)?.isSynced ?? false
    }
    
    /// Vérifie si l'objet a un conflit
    var hasConflict: Bool {
        guard let status = syncStatus else { return false }
        return SyncStatus(rawValue: status)?.hasConflict ?? false
    }
    
    /// Vérifie si l'objet est en attente
    var isPending: Bool {
        guard let status = syncStatus else { return true }
        return SyncStatus(rawValue: status)?.isPending ?? true
    }
    
    /// Vérifie si l'objet a une erreur
    var hasError: Bool {
        guard let status = syncStatus else { return false }
        return SyncStatus(rawValue: status)?.hasError ?? false
    }
    
    /// Incrémente la version
    mutating func incrementVersion() {
        version += 1
    }
}

