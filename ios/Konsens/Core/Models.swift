import Foundation

struct Market: Identifiable, Hashable, Decodable {
    let id: UUID
    let category: String
    let question: String
    let yesProbability: Int
    let movement: Int
    let closesAt: String

    enum CodingKeys: String, CodingKey {
        case id, category, question
        case yesProbability = "yes_probability"
        case movement
        case closesAt = "closes_at"
    }

    init(id: UUID, category: String, question: String, yesProbability: Int, movement: Int = 0, closesAt: String) {
        self.id = id
        self.category = category
        self.question = question
        self.yesProbability = yesProbability
        self.movement = movement
        self.closesAt = closesAt
    }
}

struct WealthSnapshot {
    var cash: Double = 0
    var investments: Double = 0
    var bets: Double = 0
    var total: Double = 0
    var performance: Double { ((total - 1000) / 1000) * 100 }
}

struct AssetQuote: Identifiable, Hashable {
    let id: UUID
    let symbol: String
    let name: String
    let kind: String
    let price: Double
}

struct LearningLesson: Identifiable, Hashable {
    let id: UUID
    let title: String
    let summary: String
    let concept: String
    let xpReward: Int
}

struct Position: Identifiable {
    let id = UUID()
    let symbol: String
    let name: String
    let value: Int
    let performance: Double
    let colorHex: UInt
}

struct Leader: Identifiable {
    let id = UUID()
    let rank: Int
    let name: String
    let initials: String
    let score: Double
    let isCurrentUser: Bool
}

enum AppTab: String, CaseIterable {
    case wealth, play, invest, learn, profile

    var title: String {
        switch self {
        case .wealth: "Patrimoine"
        case .play: "Jouer"
        case .invest: "Investir"
        case .learn: "Apprendre"
        case .profile: "Profil"
        }
    }

    var symbol: String {
        switch self {
        case .wealth: "house.fill"
        case .play: "play.fill"
        case .invest: "chart.line.uptrend.xyaxis"
        case .learn: "book.fill"
        case .profile: "person.crop.circle.fill"
        }
    }
}
