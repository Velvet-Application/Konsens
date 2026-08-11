import Foundation

struct Market: Identifiable, Hashable, Decodable {
    let id: UUID
    let category: String
    let question: String
    let yesProbability: Int
    let movement: Int
    let closesAt: String
    let resolutionRules: String
    let sourceType: String
    let sourceURLs: [String]
    let sourceTitles: [String]
    let sourceSummary: String?
    let aiConfidence: Double?
    let aiRationale: String?
    let suggestedStakeMin: Int?
    let suggestedStakeMax: Int?
    let volumeKoins: Double
    let openInterestKoins: Double

    init(id: UUID, category: String, question: String, yesProbability: Int, movement: Int = 0, closesAt: String, resolutionRules: String = "", sourceType: String = "manual", sourceURLs: [String] = [], sourceTitles: [String] = [], sourceSummary: String? = nil, aiConfidence: Double? = nil, aiRationale: String? = nil, suggestedStakeMin: Int? = nil, suggestedStakeMax: Int? = nil, volumeKoins: Double = 0, openInterestKoins: Double = 0) {
        self.id = id; self.category = category; self.question = question; self.yesProbability = yesProbability; self.movement = movement; self.closesAt = closesAt; self.resolutionRules = resolutionRules; self.sourceType = sourceType; self.sourceURLs = sourceURLs; self.sourceTitles = sourceTitles; self.sourceSummary = sourceSummary; self.aiConfidence = aiConfidence; self.aiRationale = aiRationale; self.suggestedStakeMin = suggestedStakeMin; self.suggestedStakeMax = suggestedStakeMax; self.volumeKoins = volumeKoins; self.openInterestKoins = openInterestKoins
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
    let currency: String
    let externalRef: String
    let price: Double

    init(id: UUID, symbol: String, name: String, kind: String, currency: String = "USD", externalRef: String = "", price: Double) {
        self.id = id; self.symbol = symbol; self.name = name; self.kind = kind; self.currency = currency; self.externalRef = externalRef; self.price = price
    }
}

struct LessonChapter: Codable, Hashable {
    let title: String
    let body: String
    let example: String?
    let callout: String?
}

struct LessonMedia: Codable, Hashable {
    let type: String
    let kind: String?
    let title: String
    let url: String?
    let source: String?
}

struct LessonQuiz: Codable, Hashable {
    let question: String
    let choices: [String]
    let answer: Int
    let explanation: String
}

struct LearningLesson: Identifiable, Hashable {
    let id: UUID
    let title: String
    let summary: String
    let concept: String
    let xpReward: Int
    let position: Int
    let category: String
    let durationMinutes: Int
    let riskNote: String?
    let level: String
    let objectives: [String]
    let takeaways: [String]
    let chapters: [LessonChapter]
    let media: [LessonMedia]
    let quiz: [LessonQuiz]
}

struct MarketPoint: Identifiable, Hashable {
    let id = UUID()
    let time: Date
    let price: Double
}

struct LiveMarketQuote: Hashable {
    let symbol: String
    let currency: String
    let exchange: String
    let price: Double
    let previousClose: Double
    let changePct: Double
    let updatedAt: String
    let provider: String
    let points: [MarketPoint]
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
    var shortAddress: String { guard address.count > 12 else { return address }; return "\(address.prefix(6))…\(address.suffix(4))" }
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
    var eventLabel: String { switch eventType { case "swap": "Échange"; case "defi_deposit": "Dépôt DeFi"; case "defi_withdrawal": "Retrait DeFi"; case "transfer": "Transfert"; default: "Mouvement" } }
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
    var title: String { switch self { case .wealth: "Patrimoine"; case .play: "Jouer"; case .invest: "Investir"; case .learn: "Apprendre"; case .profile: "Profil" } }
    var symbol: String { switch self { case .wealth: "house.fill"; case .play: "play.fill"; case .invest: "chart.line.uptrend.xyaxis"; case .learn: "book.fill"; case .profile: "person.crop.circle.fill" } }
}
