import SwiftUI
import FirebaseAuth
import Combine
import AuthenticationServices
import CryptoKit

// MARK: - AuthViewModel

@MainActor
class AuthViewModel: NSObject, ObservableObject {
    @Published var email = "test@email.com"
    @Published var password = "test"
    @Published var rememberMe = false
    @Published var isRegistering = false

    @Published var isLoading = false
    @Published var showAlert = false
    @Published var alertMessage = ""
    @Published var isLoggedIn = false

    // Propriété pour stocker le nonce sécurisé
    private var currentNonce: String?

    var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty && email.contains("@")
    }

    override init() {
        super.init()
        // Vérifier si l'utilisateur est déjà connecté
        checkAuthenticationState()
    }

    func toggleMode() {
        isRegistering.toggle()
    }

    // MARK: - Email/Password Authentication

    func submit() {
        guard isFormValid else {
            alertMessage = "Veuillez remplir correctement le formulaire."
            showAlert = true
            return
        }
        
        isLoading = true
        
        if isRegistering {
            createAccount()
        } else {
            signInWithEmailPassword()
        }
    }

    private func createAccount() {
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] authResult, error in
            guard let self = self else { return }
            
            self.isLoading = false
            
            if let error = error {
                self.alertMessage = "Erreur lors de la création du compte: \(error.localizedDescription)"
                self.showAlert = true
                return
            }
            
            self.alertMessage = "Compte créé avec succès !"
            self.showAlert = true
            self.isRegistering = false
            self.isLoggedIn = true
        }
    }

    private func signInWithEmailPassword() {
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] authResult, error in
            guard let self = self else { return }
            
            self.isLoading = false
            
            if let error = error {
                self.alertMessage = "Erreur de connexion: \(error.localizedDescription)"
                self.showAlert = true
                return
            }
            
            self.isLoggedIn = true
            
            if self.rememberMe {
                UserDefaults.standard.set(self.email, forKey: "savedEmail")
            }
        }
    }

    // MARK: - Sign in with Apple

    func signInWithApple() {
        isLoading = true

        // Générer un nonce sécurisé
        let nonce = randomNonceString()
        currentNonce = nonce

        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce) // Hasher le nonce pour Apple

        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }

    // MARK: - Authentication State

    private func checkAuthenticationState() {
        // Vérifier si un utilisateur est déjà connecté
        if Auth.auth().currentUser != nil {
            isLoggedIn = true
        }
        
        // Charger l'email sauvegardé si disponible
        if let savedEmail = UserDefaults.standard.string(forKey: "savedEmail") {
            email = savedEmail
            rememberMe = true
        }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            isLoggedIn = false
            // Optionnel: effacer l'email sauvegardé
            if !rememberMe {
                UserDefaults.standard.removeObject(forKey: "savedEmail")
            }
        } catch let signOutError as NSError {
            alertMessage = "Erreur lors de la déconnexion: \(signOutError.localizedDescription)"
            showAlert = true
        }
    }

    // MARK: - Nonce Generation

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }

            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }

                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }

        return result
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()

        return hashString
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AuthViewModel: ASAuthorizationControllerDelegate {

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        isLoading = false

        switch authorization.credential {
        case let appleIDCredential as ASAuthorizationAppleIDCredential:
            guard let appleIDToken = appleIDCredential.identityToken else {
                self.alertMessage = "Impossible d'obtenir le token d'identité Apple."
                self.showAlert = true
                return
            }
            
            guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                self.alertMessage = "Impossible de convertir le token d'identité en chaîne."
                self.showAlert = true
                return
            }

            // Créer le credential Firebase avec le nonce sécurisé
            let firebaseCredential = OAuthProvider.credential(
                withProviderID: "apple.com",
                idToken: idTokenString,
                rawNonce: currentNonce ?? "" // FIX 1: Unwrap avec une valeur par défaut
            )

            // Authentifier l'utilisateur avec Firebase
            Auth.auth().signIn(with: firebaseCredential) { [weak self] (authResult, error) in
                guard let self = self else { return }
                
                if let error = error {
                    self.alertMessage = "Erreur d'authentification Firebase avec Apple: \(error.localizedDescription)"
                    self.showAlert = true
                    return
                }
                
                if let authResult = authResult {
                    print("Connexion Firebase avec Apple réussie ! User: \(authResult.user.uid)")
                    self.isLoggedIn = true
                    
                    // FIX 2: Passer FirebaseAuth.User au lieu de hyrox.User
                    self.handleAppleUserInfo(credential: appleIDCredential, firebaseUser: authResult.user)
                }
            }

        default:
            break
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        isLoading = false

        if let authorizationError = error as? ASAuthorizationError {
            switch authorizationError.code {
            case .canceled:
                print("Connexion avec Apple annulée par l'utilisateur.")
                // Pas besoin d'afficher une erreur pour une annulation
            case .failed:
                self.alertMessage = "Échec de l'autorisation Apple."
                self.showAlert = true
            case .invalidResponse:
                self.alertMessage = "Réponse invalide d'Apple."
                self.showAlert = true
            case .notHandled:
                self.alertMessage = "Demande non gérée par Apple."
                self.showAlert = true
            case .unknown:
                self.alertMessage = "Erreur inconnue lors de l'autorisation Apple."
                self.showAlert = true
            @unknown default:
                self.alertMessage = "Erreur d'autorisation Apple: \(authorizationError.localizedDescription)"
                self.showAlert = true
            }
        } else {
            self.alertMessage = "Erreur inconnue lors de la connexion avec Apple: \(error.localizedDescription)"
            self.showAlert = true
        }
    }

    // MARK: - Handle Apple User Info
    private func handleAppleUserInfo(credential: ASAuthorizationAppleIDCredential, firebaseUser: FirebaseAuth.User) {
        var displayName: String?
        
        // Vérifier si on a le nom complet (première connexion)
        if let fullName = credential.fullName,
           let givenName = fullName.givenName,
           let familyName = fullName.familyName {
            
            displayName = "\(givenName) \(familyName)"
            print("✅ Première connexion Apple - Nom récupéré: \(displayName!)")
            
            // Sauvegarder immédiatement
            UserDefaults.standard.set(displayName, forKey: "username")
            
            // Mettre à jour Firebase
            let changeRequest = firebaseUser.createProfileChangeRequest()
            changeRequest.displayName = displayName
            changeRequest.commitChanges { error in
                if let error = error {
                    print("Erreur mise à jour profil: \(error.localizedDescription)")
                } else {
                    print("✅ Profil Firebase mis à jour")
                }
            }
        } else {
            print("⚠️ Connexion Apple suivante - Pas de nom fourni")
            // Vérifier si on a déjà un nom sauvegardé
            if let savedName = UserDefaults.standard.string(forKey: "username"),
               savedName != "Athlète Hyrox" {
                print("✅ Nom existant trouvé: \(savedName)")
            } else {
                // Demander à l'utilisateur de renseigner son nom
                DispatchQueue.main.async {
                    self.promptForUsername()
                }
            }
        }
        
        // Gérer l'email
        if let email = credential.email {
            UserDefaults.standard.set(email, forKey: "email")
            print("✅ Email Apple: \(email)")
        }
    }

    private func promptForUsername() {
        // Marquer qu'on doit demander le nom
        alertMessage = "Pour personnaliser votre profil, veuillez renseigner votre nom dans les paramètres."
        showAlert = true
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AuthViewModel: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            fatalError("No window available")
        }
        return window
    }
}
