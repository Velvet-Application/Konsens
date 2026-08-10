import Foundation

@MainActor
final class AppStore: ObservableObject {
    @Published var selectedTab: AppTab = .arena
    @Published var credits = 18_420
    @Published var streak = 6
    @Published var dailyAnswer: Bool?
    @Published var activeMarket: Market?
    @Published var toast: String?

    let markets = [
        Market(id: UUID(), category: "MACRO", question: "La BCE baissera-t-elle ses taux avant le 31 décembre ?", yesProbability: 63, movement: 4, closesAt: "31 déc."),
        Market(id: UUID(), category: "MARCHÉS", question: "Le CAC 40 terminera-t-il la semaine au-dessus de 8 200 points ?", yesProbability: 46, movement: -2, closesAt: "14 août"),
        Market(id: UUID(), category: "TECH", question: "Apple dépassera-t-elle 4 000 Md$ de capitalisation cette année ?", yesProbability: 57, movement: 7, closesAt: "31 déc.")
    ]

    let positions = [
        Position(symbol: "AIR", name: "Airbus", value: 3_240, performance: 8.4, colorHex: 0x7DA7FF),
        Position(symbol: "CW8", name: "ETF Monde", value: 4_680, performance: 3.1, colorHex: 0xA687FF),
        Position(symbol: "BCE", name: "Prédiction OUI", value: 2_180, performance: 12.6, colorHex: 0x42E89D)
    ]

    let leaders = [
        Leader(rank: 1, name: "MacroKing", initials: "MK", score: 18.9, isCurrentUser: false),
        Leader(rank: 2, name: "ClaraQuant", initials: "CQ", score: 14.2, isCurrentUser: false),
        Leader(rank: 3, name: "NordCapital", initials: "NC", score: 9.1, isCurrentUser: false),
        Leader(rank: 4, name: "CyrilG", initials: "CG", score: 6.8, isCurrentUser: true),
        Leader(rank: 5, name: "LucidBear", initials: "LB", score: 5.4, isCurrentUser: false)
    ]

    func answerDaily(_ answer: Bool) {
        guard dailyAnswer == nil else { return }
        dailyAnswer = answer
        streak += 1
        showToast("Position enregistrée · série prolongée")
    }

    func buy(outcome: Bool) {
        guard credits >= 250 else { return }
        credits -= 250
        activeMarket = nil
        showToast("250 € virtuels placés sur \(outcome ? "OUI" : "NON")")
    }

    func showToast(_ message: String) {
        toast = message
        Task {
            try? await Task.sleep(for: .seconds(2.2))
            if toast == message { toast = nil }
        }
    }
}
