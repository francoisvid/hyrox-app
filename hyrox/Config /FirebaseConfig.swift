import FirebaseCore
import FirebaseAuth
#if !os(watchOS)
import FirebaseFirestore
#endif

class FirebaseConfig {
    static let shared = FirebaseConfig()
    
    private init() {}
    
    func configure() {
        FirebaseApp.configure()
    }
}
