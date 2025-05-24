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
    public let category: String
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
            standardWeightFemale: nil,
            category: "Cardio"
        ),
        "Sled Push": .init(
            name: "Sled Push",
            description: "50m de poussée de traîneau",
            targetTime: 240,
            standardDistance: 50,
            standardRepetitions: nil,
            standardWeightMale: 175,
            standardWeightFemale: 125,
            category: "Force"
        ),
        "Sled Pull": .init(
            name: "Sled Pull",
            description: "50m de traction de traîneau",
            targetTime: 240,
            standardDistance: 50,
            standardRepetitions: nil,
            standardWeightMale: 125,
            standardWeightFemale: 75,
            category: "Force"
        ),
        "Burpees Broad Jump": .init(
            name: "Burpees Broad Jump",
            description: "80 répétitions",
            targetTime: 300,
            standardDistance: nil,
            standardRepetitions: 80,
            standardWeightMale: nil,
            standardWeightFemale: nil,
            category: "Plyo"
        ),
        "RowErg": .init(
            name: "RowErg",
            description: "1000m sur rameur",
            targetTime: 180,
            standardDistance: 1000,
            standardRepetitions: nil,
            standardWeightMale: nil,
            standardWeightFemale: nil,
            category: "Cardio"
        ),
        "Farmers Carry": .init(
            name: "Farmers Carry",
            description: "200m de transport de poids",
            targetTime: 240,
            standardDistance: 200,
            standardRepetitions: nil,
            standardWeightMale: 32,
            standardWeightFemale: 24,
            category: "Force"
        ),
        "Sandbag Lunges": .init(
            name: "Sandbag Lunges",
            description: "200m de fentes avec sac de sable",
            targetTime: 300,
            standardDistance: 200,
            standardRepetitions: nil,
            standardWeightMale: 20,
            standardWeightFemale: 12,
            category: "Force"
        ),
        "Wall Balls": .init(
            name: "Wall Balls",
            description: "75 répétitions",
            targetTime: 210,
            standardDistance: nil,
            standardRepetitions: 75,
            standardWeightMale: 6,
            standardWeightFemale: 4,
            category: "Force"
        ),
        "1 km Run": .init(
            name: "1 km Run",
            description: "Course de 1 kilomètre",
            targetTime: nil,
            standardDistance: 1000,
            standardRepetitions: nil,
            standardWeightMale: nil,
            standardWeightFemale: nil,
            category: "Cardio"
        ),
        "Assault Bike": .init(
            name: "Assault Bike",
            description: "Exercice sur Assault Bike",
            targetTime: nil,
            standardDistance: nil,
            standardRepetitions: nil,
            standardWeightMale: nil,
            standardWeightFemale: nil,
            category: "Cardio"
        ),
        "Jump Rope": .init(
            name: "Jump Rope",
            description: "Exercice de corde à sauter",
            targetTime: nil,
            standardDistance: nil,
            standardRepetitions: nil,
            standardWeightMale: nil,
            standardWeightFemale: nil,
            category: "Cardio"
        ),
        "Sprint Intervals": .init(
            name: "Sprint Intervals",
            description: "Intervalles de sprint",
            targetTime: nil,
            standardDistance: nil,
            standardRepetitions: nil,
            standardWeightMale: nil,
            standardWeightFemale: nil,
            category: "Cardio"
        ),
        "High Knees": .init(
            name: "High Knees",
            description: "Exercice de genoux hauts",
            targetTime: nil,
            standardDistance: nil,
            standardRepetitions: nil,
            standardWeightMale: nil,
            standardWeightFemale: nil,
            category: "Cardio"
        ),
        "Mountain Climbers": .init(
            name: "Mountain Climbers",
            description: "Exercice de grimpeurs",
            targetTime: nil,
            standardDistance: nil,
            standardRepetitions: nil,
            standardWeightMale: nil,
            standardWeightFemale: nil,
            category: "Cardio"
        ),
        "Bear Crawl": .init(
            name: "Bear Crawl",
            description: "Exercice de déplacement en ours",
            targetTime: nil,
            standardDistance: nil,
            standardRepetitions: nil,
            standardWeightMale: nil,
            standardWeightFemale: nil,
            category: "Cardio"
        ),
        "Battle Ropes": .init(
            name: "Battle Ropes",
            description: "Exercice avec cordes ondulatoires",
            targetTime: nil,
            standardDistance: nil,
            standardRepetitions: nil,
            standardWeightMale: nil,
            standardWeightFemale: nil,
            category: "Cardio"
        ),
        "Deadlifts": .init(
            name: "Deadlifts",
            description: "Soulevés de terre",
            targetTime: nil,
            standardDistance: nil,
            standardRepetitions: nil,
            standardWeightMale: nil,
            standardWeightFemale: nil,
            category: "Force"
        ),
        "Dumbbell Thrusters": .init(
            name: "Dumbbell Thrusters",
            description: "Thrusters avec haltères",
            targetTime: nil,
            standardDistance: nil,
            standardRepetitions: nil,
            standardWeightMale: nil,
            standardWeightFemale: nil,
            category: "Force"
        ),
        "Dumbbell Snatch": .init(
            name: "Dumbbell Snatch",
            description: "Arraché avec haltère",
            targetTime: nil,
            standardDistance: nil,
            standardRepetitions: nil,
            standardWeightMale: nil,
            standardWeightFemale: nil,
            category: "Force"
        ),
        "Kettlebell Snatches": .init(
            name: "Kettlebell Snatches",
            description: "Arrachés avec kettlebell",
            targetTime: nil,
            standardDistance: nil,
            standardRepetitions: nil,
            standardWeightMale: nil,
            standardWeightFemale: nil,
            category: "Force"
        ),
        "Kettlebell Cleans": .init(
            name: "Kettlebell Cleans",
            description: "Clean avec kettlebell",
            targetTime: nil,
            standardDistance: nil,
            standardRepetitions: nil,
            standardWeightMale: nil,
            standardWeightFemale: nil,
            category: "Force"
        ),
        "Kettlebell Goblet Squats": .init(
            name: "Kettlebell Goblet Squats",
            description: "Squats goblet avec kettlebell",
            targetTime: nil,
            standardDistance: nil,
            standardRepetitions: nil,
            standardWeightMale: nil,
            standardWeightFemale: nil,
            category: "Force"
        ),
        "Sandbag Cleans": .init(
            name: "Sandbag Cleans",
            description: "Clean avec sac de sable",
            targetTime: nil,
            standardDistance: nil,
            standardRepetitions: nil,
            standardWeightMale: nil,
            standardWeightFemale: nil,
            category: "Force"
        ),
        "Sandbag Shouldering": .init(
            name: "Sandbag Shouldering",
            description: "Portage de sac de sable sur l'épaule",
            targetTime: nil,
            standardDistance: nil,
            standardRepetitions: nil,
            standardWeightMale: nil,
            standardWeightFemale: nil,
            category: "Force"
        ),
        "Weighted Lunges": .init(
            name: "Weighted Lunges",
            description: "Fentes avec poids",
            targetTime: nil,
            standardDistance: nil,
            standardRepetitions: nil,
            standardWeightMale: nil,
            standardWeightFemale: nil,
            category: "Force"
        ),
        "Box Step Overs": .init(
            name: "Box Step Overs",
            description: "Montées sur caisse",
            targetTime: nil,
            standardDistance: nil,
            standardRepetitions: nil,
            standardWeightMale: nil,
            standardWeightFemale: nil,
            category: "Force"
        ),
        "Overhead Carry": .init(
            name: "Overhead Carry",
            description: "Transport en position overhead",
            targetTime: nil,
            standardDistance: nil,
            standardRepetitions: nil,
            standardWeightMale: nil,
            standardWeightFemale: nil,
            category: "Force"
        ),
        "Med Ball Slams": .init(
            name: "Med Ball Slams",
            description: "Lancers de médecine ball",
            targetTime: nil,
            standardDistance: nil,
            standardRepetitions: nil,
            standardWeightMale: nil,
            standardWeightFemale: nil,
            category: "Force"
        ),
        "Push-ups": .init(
            name: "Push-ups",
            description: "Pompes",
            targetTime: nil,
            standardDistance: nil,
            standardRepetitions: nil,
            standardWeightMale: nil,
            standardWeightFemale: nil,
            category: "Force"
        ),
        "Wall Sit": .init(
            name: "Wall Sit",
            description: "Position assise contre un mur",
            targetTime: nil,
            standardDistance: nil,
            standardRepetitions: nil,
            standardWeightMale: nil,
            standardWeightFemale: nil,
            category: "Force"
        ),
        "Plank Hold": .init(
            name: "Plank Hold",
            description: "Gainage en planche",
            targetTime: nil,
            standardDistance: nil,
            standardRepetitions: nil,
            standardWeightMale: nil,
            standardWeightFemale: nil,
            category: "Core"
        ),
        "Sit-ups": .init(
            name: "Sit-ups",
            description: "Redressements assis",
            targetTime: nil,
            standardDistance: nil,
            standardRepetitions: nil,
            standardWeightMale: nil,
            standardWeightFemale: nil,
            category: "Core"
        ),
        "Russian Twists": .init(
            name: "Russian Twists",
            description: "Rotations russes",
            targetTime: nil,
            standardDistance: nil,
            standardRepetitions: nil,
            standardWeightMale: nil,
            standardWeightFemale: nil,
            category: "Core"
        ),
        "Hanging Knee Raises": .init(
            name: "Hanging Knee Raises",
            description: "Élévations de genoux suspendu",
            targetTime: nil,
            standardDistance: nil,
            standardRepetitions: nil,
            standardWeightMale: nil,
            standardWeightFemale: nil,
            category: "Core"
        ),
        "Toes to Bar": .init(
            name: "Toes to Bar",
            description: "Orteils à la barre",
            targetTime: nil,
            standardDistance: nil,
            standardRepetitions: nil,
            standardWeightMale: nil,
            standardWeightFemale: nil,
            category: "Core"
        ),
        "Standing Pallof Press": .init(
            name: "Standing Pallof Press",
            description: "Press Pallof debout",
            targetTime: nil,
            standardDistance: nil,
            standardRepetitions: nil,
            standardWeightMale: nil,
            standardWeightFemale: nil,
            category: "Core"
        ),
        "Air Squats": .init(
            name: "Air Squats",
            description: "Squats au poids du corps",
            targetTime: nil,
            standardDistance: nil,
            standardRepetitions: nil,
            standardWeightMale: nil,
            standardWeightFemale: nil,
            category: "Core"
        ),
        "Box Jumps": .init(
            name: "Box Jumps",
            description: "Sauts sur caisse",
            targetTime: nil,
            standardDistance: nil,
            standardRepetitions: nil,
            standardWeightMale: nil,
            standardWeightFemale: nil,
            category: "Plyo"
        ),
        "Broad Jumps": .init(
            name: "Broad Jumps",
            description: "Sauts en longueur",
            targetTime: nil,
            standardDistance: nil,
            standardRepetitions: nil,
            standardWeightMale: nil,
            standardWeightFemale: nil,
            category: "Plyo"
        ),
        "Jumping Lunges": .init(
            name: "Jumping Lunges",
            description: "Fentes sautées",
            targetTime: nil,
            standardDistance: nil,
            standardRepetitions: nil,
            standardWeightMale: nil,
            standardWeightFemale: nil,
            category: "Plyo"
        ),
        "Burpee Broad Jumps": .init(
            name: "Burpee Broad Jumps",
            description: "Burpees avec saut en longueur",
            targetTime: nil,
            standardDistance: nil,
            standardRepetitions: nil,
            standardWeightMale: nil,
            standardWeightFemale: nil,
            category: "Plyo"
        ),
        "Burpees": .init(
            name: "Burpees",
            description: "Burpees classiques",
            targetTime: nil,
            standardDistance: nil,
            standardRepetitions: nil,
            standardWeightMale: nil,
            standardWeightFemale: nil,
            category: "Plyo"
        ),
        "Lateral Hops": .init(
            name: "Lateral Hops",
            description: "Sauts latéraux",
            targetTime: nil,
            standardDistance: nil,
            standardRepetitions: nil,
            standardWeightMale: nil,
            standardWeightFemale: nil,
            category: "Plyo"
        )
    ]
}
