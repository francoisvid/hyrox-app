import Foundation

struct MotivationalQuote: Identifiable {
    let id = UUID()
    let text: String
    let author: String
}

class MotivationalQuotes {
    static let quotes = [
        MotivationalQuote(text: "Le succès n'est pas final, l'échec n'est pas fatal : c'est le courage de continuer qui compte.", author: "Winston Churchill"),
        MotivationalQuote(text: "La douleur que vous ressentirez aujourd'hui sera la force que vous ressentirez demain.", author: "Arnold Schwarzenegger"),
        MotivationalQuote(text: "Votre corps peut supporter presque tout. C'est votre esprit que vous devez convaincre.", author: "Andrew Murphy"),
        MotivationalQuote(text: "La différence entre l'impossible et le possible réside dans la détermination d'une personne.", author: "Tommy Lasorda"),
        MotivationalQuote(text: "Ne limitez pas vos défis. Défiez vos limites.", author: "Jerry Dunn"),
        MotivationalQuote(text: "La force ne vient pas de la capacité physique. Elle vient d'une volonté indomptable.", author: "Mahatma Gandhi"),
        MotivationalQuote(text: "Le seul mauvais entraînement est celui qui n'a pas eu lieu.", author: "Inconnu"),
        MotivationalQuote(text: "Votre corps peut tout supporter. C'est votre esprit que vous devez convaincre.", author: "Inconnu")
    ]
} 