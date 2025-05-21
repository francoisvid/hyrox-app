import SwiftUI

struct SplashScreenView: View {
    @State private var currentQuoteIndex = Int.random(in: 0..<MotivationalQuotes.quotes.count)
    @State private var opacity = 0.0
    @State private var isActive = false
    
    let timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    
    var body: some View {
        if isActive {
            ContentView()
        } else {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 20) {
                    Image("logo_myrox")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 150, height: 150)
                        .opacity(opacity)
                        .foregroundColor(.yellow)
                        .clipShape(Circle())
                        
                    
                    VStack(spacing: 10) {
                        Text(MotivationalQuotes.quotes[currentQuoteIndex].text)
                            .font(.title3)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white)
                            .padding(.horizontal)
                            .opacity(opacity)
                            .padding(.bottom, 60)
                        
                        Text("- \(MotivationalQuotes.quotes[currentQuoteIndex].author)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .opacity(opacity)
                            .padding(.bottom, 70)
                    }
                }
            }
            .onAppear {
                withAnimation(.easeIn(duration: 1.0)) {
                    opacity = 1.0
                }
            }
            .onReceive(timer) { _ in
                withAnimation {
                    if currentQuoteIndex < MotivationalQuotes.quotes.count - 1 {
                        currentQuoteIndex += 1
                    } else {
                        currentQuoteIndex = 0
                    }
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    withAnimation {
                        self.isActive = true
                    }
                }
            }
        }
    }
}

#Preview {
    SplashScreenView()
        .environment(\.managedObjectContext, DataController.shared.container.viewContext)
} 
