import Foundation

struct Market: Identifiable, Hashable {
    let id: UUID
    let category: String
    let question: String
    let yesProbability: Int
    let movement: Int
    let closesAt: String
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

enum AppTab: String, CaseIterable { case arena, markets, league, profile }
