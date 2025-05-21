import SwiftUI
import Combine

// MARK: - AuthViewModel

@MainActor
class AuthViewModel: ObservableObject {
    @Published var email = "test@email.com"
    @Published var password = "test"
    @Published var rememberMe = false
    @Published var isRegistering = false

    @Published var isLoading = false
    @Published var showAlert = false
    @Published var alertMessage = ""
    @Published var isLoggedIn = false

    var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty && email.contains("@")
    }

    func toggleMode() { isRegistering.toggle() }

    func submit() {
        guard isFormValid else {
            alertMessage = "Veuillez remplir correctement le formulaire."
            showAlert = true
            return
        }
        isLoading = true
        DispatchQueue.main.asyncAfter(deadline: .now()+1.5) {
            self.isLoading = false
            if self.isRegistering {
                self.alertMessage = "Compte créé avec succès !"
                self.showAlert = true
                self.isRegistering = false
            } else {
                self.isLoggedIn = true
                if self.rememberMe {
                    UserDefaults.standard.set(self.email, forKey: "savedEmail")
                }
            }
        }
    }
}

// MARK: - LoginView

struct LoginView: View {
    @StateObject private var vm = AuthViewModel()
    @FocusState private var focusedField: Field?

    enum Field { case email, password }

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.black, Color(hex: "#181818")]),
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    LogoView()

                    ModeToggleView(isRegistering: $vm.isRegistering, action: vm.toggleMode)

                    CredentialsFormView(
                        email: $vm.email,
                        password: $vm.password,
                        rememberMe: $vm.rememberMe,
                        isRegistering: vm.isRegistering,
                        isValid: vm.isFormValid
                    )
                    .focused($focusedField, equals: .email)

                    Button(action: vm.submit) {
                        Text(vm.isRegistering ? "Créer un compte" : "Se connecter")
                            .font(.headline)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(vm.isFormValid ? Color.yellow : Color.yellow.opacity(0.5))
                            .cornerRadius(8)
                    }
                    .disabled(!vm.isFormValid || vm.isLoading)

                    SocialLoginButtonsView()

                    Text("En vous connectant, vous acceptez nos Conditions d'utilisation.")
                        .font(.caption).foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding()
            }

            if vm.isLoading {
                LoadingOverlayView()
            }
        }
        .alert(isPresented: $vm.showAlert) {
            Alert(
                title: Text("Info"),
                message: Text(vm.alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .fullScreenCover(isPresented: $vm.isLoggedIn) {
            MainTabView(isLoggedIn: $vm.isLoggedIn)
        }
    }
}

// MARK: - Sous-vues Login

private struct LogoView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "figure.run.circle.fill")
                .resizable().frame(width: 80, height: 80)
                .foregroundColor(.yellow)
            Text("MyHyrox")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
            Text("Entraînez-vous. Suivez et Progressez")
                .foregroundColor(.gray)
        }
    }
}

private struct ModeToggleView: View {
    @Binding var isRegistering: Bool
    var action: () -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            Button("Connexion") { if isRegistering { action() } }
                .toggleStyle(isActive: !isRegistering)
            Button("Inscription") { if !isRegistering { action() } }
                .toggleStyle(isActive:  isRegistering)
        }
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

private extension Button {
    func toggleStyle(isActive: Bool) -> some View {
        self
            .font(.headline)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(isActive ? Color.yellow : Color.clear)
            .foregroundColor(isActive ? .black : .gray)
    }
}

private struct CredentialsFormView: View {
    @Binding var email: String
    @Binding var password: String
    @Binding var rememberMe: Bool
    let isRegistering: Bool
    let isValid: Bool
    
    @State private var showPassword = false
    @Environment(\.colorScheme) var scheme
    
    var body: some View {
        VStack(spacing: 16) {
            // Email
            VStack(alignment: .leading, spacing: 4) {
                Text("Email").font(.caption).foregroundColor(.gray)
                HStack {
                    Image(systemName: "envelope").foregroundColor(.gray)
                    TextField("Votre email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }
                .padding().background(Color(.systemGray6)).cornerRadius(8)
            }
            
            // Password
            VStack(alignment: .leading, spacing: 4) {
                Text("Mot de passe").font(.caption).foregroundColor(.gray)
                HStack {
                    Image(systemName: "lock").foregroundColor(.gray)
                    Group {
                        if showPassword {
                            TextField("Mot de passe", text: $password)
                        } else {
                            SecureField("Mot de passe", text: $password)
                        }
                    }
                    Button(action: { showPassword.toggle() }) {
                        Image(systemName: showPassword ? "eye.slash" : "eye")
                            .foregroundColor(.gray)
                    }
                }
                .padding().background(Color(.systemGray6)).cornerRadius(8)
            }
            
            // Remember Me + Forgot
            if !isRegistering {
                HStack {
                    Toggle("Se souvenir de moi", isOn: $rememberMe)
                        .toggleStyle(.checkbox)
                    Spacer()
                    Button("Mot de passe oublié ?") {
                        // action
                    }
                    .foregroundColor(.yellow)
                }
            }
        }
    }
}

private struct SocialButton: View {
    let icon: String
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.white)
                Text(text)
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemGray5))
            .cornerRadius(8)
        }
    }
}

private struct SocialLoginButtonsView: View {
    var body: some View {
        VStack(spacing: 12) {
            SocialButton(icon: "g.circle.fill", text: "Continuer avec Google") { /*…*/ }
            SocialButton(icon: "apple.logo",   text: "Continuer avec Apple")  { /*…*/ }
        }
    }
}

private struct LoadingOverlayView: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            ProgressView("Chargement…")
                .progressViewStyle(.circular)
                .foregroundColor(.white)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
        }
    }
}

// MARK: - Checkbox ToggleStyle

private struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                .foregroundColor(configuration.isOn ? .yellow : .gray)
                .onTapGesture { configuration.isOn.toggle() }
            configuration.label
        }
    }
}

private extension ToggleStyle where Self == CheckboxToggleStyle {
    static var checkbox: CheckboxToggleStyle { .init() }
}

// MARK: - Color hex initializer (move to Extensions/Color+Hex.swift)

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var int: UInt64 = 0; Scanner(string: hex).scanHexInt64(&int)
        let (a,r,g,b): (UInt64,UInt64,UInt64,UInt64) = {
            switch hex.count {
            case 3: return (255, (int>>8)*17, (int>>4&0xF)*17, (int&0xF)*17)
            case 6: return (255, int>>16, int>>8 & 0xFF, int & 0xFF)
            case 8: return (int>>24, int>>16 & 0xFF, int>>8 & 0xFF, int & 0xFF)
            default: return (255,0,0,0)
            }
        }()
        self.init(.sRGB,
                  red: Double(r)/255,
                  green: Double(g)/255,
                  blue: Double(b)/255,
                  opacity: Double(a)/255)
    }
}

#Preview {
    LoginView()
}
