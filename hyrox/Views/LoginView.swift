import SwiftUI

// MARK: - SocialLoginView

struct LoginView: View {
    @StateObject private var vm = AuthViewModel()

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.black, Color(hex: "#181818")]),
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 40) {
                    Spacer(minLength: 30)
                    
                    LogoView()
                    
                    Spacer()
                    
                    QuotesView()
                    
                    Spacer()
                                        
                    SocialLoginButtonsView()
                        .environmentObject(vm)
                    
                    TermsView()
                }
                .padding(.horizontal, 24)
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

// MARK: - Sous-vues

private struct LogoView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image("logo_myrox")
                .resizable()
                .frame(width: 100, height: 100)
                .foregroundColor(.yellow)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.yellow, lineWidth: 4)
                )
            
            Text("MyROX")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.white)
            
            Text("Entraînez-vous. Suivez et Progressez")
                .font(.system(size: 16))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
    }
}

private struct QuotesView: View {
    @State private var currentQuoteIndex = Int.random(in: 0..<MotivationalQuotes.quotes.count)
    @State private var opacity = 1.0
    
    let timer = Timer.publish(every: 6, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 0) {
            // Container fixe pour les citations - centré verticalement
            VStack(spacing: 12) {
                Text(MotivationalQuotes.quotes[currentQuoteIndex].text)
                    .font(.system(size: 18, weight: .medium))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                    .lineSpacing(2)
                    .opacity(opacity)
                
                Text("- \(MotivationalQuotes.quotes[currentQuoteIndex].author)")
                    .font(.system(size: 14))
                    .foregroundColor(.yellow)
                    .opacity(opacity)
            }
            .frame(height: 100) // Hauteur fixe pour éviter les mouvements
            .frame(maxWidth: .infinity)
        }
        .onReceive(timer) { _ in
            // Fade out rapide
            withAnimation(.easeOut(duration: 0.3)) {
                opacity = 0.0
            }
            
            // Changer la citation puis fade in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                currentQuoteIndex = (currentQuoteIndex + 1) % MotivationalQuotes.quotes.count
                
                withAnimation(.easeIn(duration: 0.3)) {
                    opacity = 1.0
                }
            }
        }
    }
}

private struct SocialLoginButtonsView: View {
    @EnvironmentObject var vm: AuthViewModel

    var body: some View {
        VStack(spacing: 24) {
            // Texte juste au-dessus du bouton
            VStack(spacing: 16) {
                Text("Prêt à vous entraîner ?")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("Accédez à vos séances HYROX et suivez vos performances en temps réel")
                    .font(.system(size: 15))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
            
            // Bouton Apple
            SocialButton(
                icon: "apple.logo",
                text: "Continuer avec Apple",
                backgroundColor: .white,
                textColor: .black
            ) {
                vm.signInWithApple()
            }
            
            // Bouton Google (pour plus tard)
//            SocialButton(
//                icon: "g.circle.fill",
//                text: "Continuer avec Google",
//                backgroundColor: Color(.systemGray5),
//                textColor: .white
//            ) {
//                // TODO: Implémenter Google Sign-In plus tard
//                print("Google Sign-In - À implémenter")
//            }
        }
    }
}

private struct SocialButton: View {
    let icon: String
    let text: String
    let backgroundColor: Color
    let textColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(textColor)
                
                Text(text)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(textColor)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(backgroundColor)
            .cornerRadius(12)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

private struct TermsView: View {
    var body: some View {
        Text("En vous connectant, vous acceptez nos Conditions d'utilisation et notre Politique de confidentialité.")
            .font(.system(size: 12))
            .foregroundColor(.gray)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
    }
}

private struct LoadingOverlayView: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .yellow))
                    .scaleEffect(1.2)
                
                Text("Connexion en cours...")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(24)
            .background(Color(.systemGray6))
            .cornerRadius(16)
        }
    }
}

// MARK: - Button Style

private struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Color hex initializer

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
