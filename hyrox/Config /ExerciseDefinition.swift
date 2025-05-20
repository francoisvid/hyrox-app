import Foundation

/// Définit toutes les propriétés d'un exercice Hyrox
public struct ExerciseDefinition {
    public let name: String
    public let description: String
    public let targetTime: TimeInterval?
    public let standardDistance: Double?
    public let standardRepetitions: Int?
    public let standardWeightMale: Double?
    public let standardWeightFemale: Double?
    var isDistanceBased: Bool {
        standardDistance != nil
    }

    var isRepetitionBased: Bool {
        standardRepetitions != nil
    }
}

/// Liste de toutes les définitions d'exercices, indexée par nom
public enum ExerciseDefinitions {
    public static let all: [String: ExerciseDefinition] = [
        "SkiErg": .init(
            name: "SkiErg",
            description: "1000m sur la machine SkiErg",
            targetTime: 180,
            standardDistance: 1000,
            standardRepetitions: nil,
            standardWeightMale: nil,
            standardWeightFemale: nil
        ),
        "Sled Push": .init(
            name: "Sled Push",
            description: "50m de poussée de traîneau",
            targetTime: 240,
            standardDistance: 50,
            standardRepetitions: nil,
            standardWeightMale: 175,
            standardWeightFemale: 125
        ),
        "Sled Pull": .init(
            name: "Sled Pull",
            description: "50m de traction de traîneau",
            targetTime: 240,
            standardDistance: 50,
            standardRepetitions: nil,
            standardWeightMale: 125,
            standardWeightFemale: 75
        ),
        "Burpees Broad Jump": .init(
            name: "Burpees Broad Jump",
            description: "80 répétitions",
            targetTime: 300,
            standardDistance: nil,
            standardRepetitions: 80,
            standardWeightMale: nil,
            standardWeightFemale: nil
        ),
        "RowErg": .init(
            name: "RowErg",
            description: "1000m sur rameur",
            targetTime: 180,
            standardDistance: 1000,
            standardRepetitions: nil,
            standardWeightMale: nil,
            standardWeightFemale: nil
        ),
        "Farmers Carry": .init(
            name: "Farmers Carry",
            description: "200m de transport de poids",
            targetTime: 240,
            standardDistance: 200,
            standardRepetitions: nil,
            standardWeightMale: 32,
            standardWeightFemale: 24
        ),
        "Sandbag Lunges": .init(
            name: "Sandbag Lunges",
            description: "200m de fentes avec sac de sable",
            targetTime: 300,
            standardDistance: 200,
            standardRepetitions: nil,
            standardWeightMale: 20,
            standardWeightFemale: 12
        ),
        "Wall Balls": .init(
            name: "Wall Balls",
            description: "75 répétitions",
            targetTime: 210,
            standardDistance: nil,
            standardRepetitions: 75,
            standardWeightMale: 6,
            standardWeightFemale: 4
        )
    ]
}
