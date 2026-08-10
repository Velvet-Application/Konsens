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

struct SponsoredAd: Identifiable, Hashable {
    let campaignID: UUID
    let id: UUID
    let sponsorName: String
    let eyebrow: String
    let headline: String
    let body: String?
    let ctaLabel: String
    let destinationURL: String
    let placement: String
}

struct MonetizationSnapshot: Hashable {
    var advertisers = 0
    var activeCampaigns = 0
    var impressions = 0
    var clicks = 0
    var sdkClients = 0
    var ctr: Double { impressions > 0 ? (Double(clicks) / Double(impressions)) * 100 : 0 }
}

struct PublicWallet: Identifiable, Hashable {
    let id: UUID
    let chain: String
    let address: String
    let displayName: String
    let confidenceScore: Int
    let observableValueEUR: Double?

    var shortAddress: String {
        guard address.count > 12 else { return address }
        return "\(address.prefix(6))…\(address.suffix(4))"
    }
}

struct WalletEvent: Identifiable, Hashable {
    let id: UUID
    let walletID: UUID
    let eventType: String
    let direction: String
    let assetSymbol: String?
    let assetAmount: Double?
    let estimatedValueEUR: Double?
    let blockTime: String?
    let explorerURL: String?

    var eventLabel: String {
        switch eventType {
        case "swap": "Échange"
        case "defi_deposit": "Dépôt DeFi"
        case "defi_withdrawal": "Retrait DeFi"
        case "transfer": "Transfert"
        default: "Mouvement"
        }
    }
}

struct RealityComparison: Identifiable, Hashable {
    let id: UUID
    let simulatedValueEUR: Double
    let realMarketValueEUR: Double
    let networkFeesEUR: Double
    let slippageEUR: Double
    let comparedAt: String

    var deltaEUR: Double { realMarketValueEUR - simulatedValueEUR - networkFeesEUR - slippageEUR }
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
