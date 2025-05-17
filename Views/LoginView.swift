// Views/LoginView.swift
import SwiftUI

struct LoginView: View {
    // Propriétés d'état
    @State private var email = ""
    @State private var password = ""
    @State private var rememberMe = false
    @State private var isPasswordVisible = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    @State private var isRegistering = false
    
    // Communication externe
    @Binding var isLoggedIn: Bool
    
    // Environnement pour le mode sombre
    @Environment(\.colorScheme) var colorScheme
    
    // Vérification de validité du formulaire
    private var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty && isValidEmail(email)
    }
    
    var body: some View {
        ZStack {
            // Arrière-plan avec dégradé
            LinearGradient(
                gradient: Gradient(colors: [Color.black, Color(hex: "#181818")]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Contenu principal
            ScrollView {
                VStack(spacing: 25) {
                    // Logo et titre
                    logoSection
                    
                    // Changement entre connexion et inscription
                    modeToggleSection
                    
                    // Formulaire
                    VStack(spacing: 20) {
                        // Champ email
                        emailField
                        
                        // Champ mot de passe
                        passwordField
                        
                        // Option "Se souvenir de moi"
                        if !isRegistering {
                            rememberMeToggle
                        }
                        
                        // Bouton principal
                        primaryButton
                        
                        // Séparateur
                        divider
                        
                        // Options alternatives de connexion
                        socialLoginButtons
                    }
                    .padding(.horizontal, 25)
                    
                    Spacer()
                    
                    // Lien vers conditions d'utilisation
                    termsAndConditions
                }
                .padding(.top, 60)
            }
            
            // Indicateur de chargement
            if isLoading {
                loadingOverlay
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Information"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    // MARK: - UI Components
    
    private var logoSection: some View {
        VStack(spacing: 10) {
            Image(systemName: "figure.run.circle.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .foregroundColor(.yellow)
            
            Text("HYROX")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
            
            Text("Entraînez-vous. Suivez. Progressez.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .padding(.bottom, 20)
        }
    }
    
    private var modeToggleSection: some View {
        HStack(spacing: 0) {
            // Bouton Connexion
            Button(action: {
                withAnimation {
                    isRegistering = false
                }
            }) {
                Text("Connexion")
                    .font(.headline)
                    .padding(.vertical, 15)
                    .frame(maxWidth: .infinity)
                    .background(!isRegistering ? Color.yellow : Color.clear)
                    .foregroundColor(!isRegistering ? .black : .gray)
                    .cornerRadius(8, corners: [.topLeft, .bottomLeft])
            }
            
            // Bouton Inscription
            Button(action: {
                withAnimation {
                    isRegistering = true
                }
            }) {
                Text("Inscription")
                    .font(.headline)
                    .padding(.vertical, 15)
                    .frame(maxWidth: .infinity)
                    .background(isRegistering ? Color.yellow : Color.clear)
                    .foregroundColor(isRegistering ? .black : .gray)
                    .cornerRadius(8, corners: [.topRight, .bottomRight])
            }
        }
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .padding(.horizontal, 25)
        .padding(.bottom, 20)
    }
    
    private var emailField: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Email")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.leading, 5)
            
            HStack {
                Image(systemName: "envelope")
                    .foregroundColor(.gray)
                    .frame(width: 20)
                
                TextField("votre@email.com", text: $email)
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                    .foregroundColor(.white)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
            
            if !email.isEmpty && !isValidEmail(email) {
                Text("Veuillez entrer une adresse email valide")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.leading, 5)
            }
        }
    }
    
    private var passwordField: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Mot de passe")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.leading, 5)
            
            HStack {
                Image(systemName: "lock")
                    .foregroundColor(.gray)
                    .frame(width: 20)
                
                if isPasswordVisible {
                    TextField("Votre mot de passe", text: $password)
                        .foregroundColor(.white)
                } else {
                    SecureField("Votre mot de passe", text: $password)
                        .foregroundColor(.white)
                }
                
                Button(action: {
                    isPasswordVisible.toggle()
                }) {
                    Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                        .foregroundColor(.gray)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
            
            if isRegistering && !password.isEmpty && password.count < 6 {
                Text("Le mot de passe doit contenir au moins 6 caractères")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.leading, 5)
            }
        }
    }
    
    private var rememberMeToggle: some View {
        HStack {
            Toggle("", isOn: $rememberMe)
                .toggleStyle(iOSCheckboxToggleStyle())
            
            Text("Se souvenir de moi")
                .font(.subheadline)
                .foregroundColor(.white)
            
            Spacer()
            
            Button(action: {
                showAlert = true
                alertMessage = "Un email de récupération va vous être envoyé."
            }) {
                Text("Mot de passe oublié ?")
                    .font(.subheadline)
                    .foregroundColor(.yellow)
            }
        }
    }
    
    private var primaryButton: some View {
        Button(action: {
            handleAuthentication()
        }) {
            Text(isRegistering ? "Créer un compte" : "Se connecter")
                .font(.headline)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(isFormValid ? Color.yellow : Color.yellow.opacity(0.5))
                .cornerRadius(8)
        }
        .disabled(!isFormValid || isLoading)
        .padding(.top, 10)
    }
    
    private var divider: some View {
        HStack {
            Rectangle()
                .fill(Color.gray.opacity(0.5))
                .frame(height: 1)
            
            Text("ou")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.horizontal, 10)
            
            Rectangle()
                .fill(Color.gray.opacity(0.5))
                .frame(height: 1)
        }
        .padding(.vertical, 10)
    }
    
    private var socialLoginButtons: some View {
        VStack(spacing: 15) {
            // Bouton Google
            Button(action: {
                handleSocialLogin(provider: "Google")
            }) {
                HStack {
                    Image(systemName: "g.circle.fill")
                        .font(.title3)
                        .foregroundColor(.white)
                    
                    Text("Continuer avec Google")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(.systemGray5))
                .cornerRadius(8)
            }
            
            // Bouton Apple (uniquement sur iOS)
            Button(action: {
                handleSocialLogin(provider: "Apple")
            }) {
                HStack {
                    Image(systemName: "apple.logo")
                        .font(.title3)
                        .foregroundColor(.white)
                    
                    Text("Continuer avec Apple")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(.systemGray5))
                .cornerRadius(8)
            }
        }
    }
    
    private var termsAndConditions: some View {
        Text("En vous connectant, vous acceptez nos Conditions d'utilisation et notre Politique de confidentialité")
            .font(.caption)
            .foregroundColor(.gray)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 40)
            .padding(.bottom, 20)
    }
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .yellow))
                    .scaleEffect(1.5)
                
                Text("Connexion en cours...")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(25)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Fonctions
    
    private func handleAuthentication() {
        isLoading = true
        
        // Simulation d'un délai réseau
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            // Dans une vraie application, ceci serait remplacé par votre logique d'authentification
            
            if isRegistering {
                // Logique d'inscription
                showAlert = true
                alertMessage = "Compte créé avec succès ! Vous pouvez maintenant vous connecter."
                isRegistering = false
            } else {
                // Logique de connexion
                isLoggedIn = true
                
                // Stocker l'email si "Se souvenir de moi" est activé
                if rememberMe {
                    UserDefaults.standard.set(email, forKey: "savedEmail")
                }
            }
            
            isLoading = false
        }
    }
    
    private func handleSocialLogin(provider: String) {
        isLoading = true
        
        // Simulation d'un délai réseau
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            // Dans une vraie application, ceci serait remplacé par votre logique d'authentification sociale
            isLoggedIn = true
            isLoading = false
        }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
}

// MARK: - Styles personnalisés

// Style de checkbox iOS
struct iOSCheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                .foregroundColor(configuration.isOn ? .yellow : .gray)
                .font(.system(size: 20, weight: .bold))
                .onTapGesture {
                    configuration.isOn.toggle()
                }
            
            configuration.label
        }
    }
}

// Extension pour les coins arrondis spécifiques
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// Extension pour les couleurs hex
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
