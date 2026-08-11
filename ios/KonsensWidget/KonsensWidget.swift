import WidgetKit
import SwiftUI
import AppIntents

enum WidgetUniverse: String, AppEnum {
    case play
    case finance
    case mixed

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Univers Konsens")
    static var caseDisplayRepresentations: [WidgetUniverse: DisplayRepresentation] = [
        .play: "Jeux",
        .finance: "Finance",
        .mixed: "Jeux + Finance"
    ]
}

struct KonsensWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Contenu du widget"
    static var description = IntentDescription("Choisis les prédictions, les marchés financiers ou les deux.")

    @Parameter(title: "Afficher", default: .mixed)
    var universe: WidgetUniverse
}

struct WidgetMarket: Codable, Hashable {
    let question: String
    let category: String
    let probability: Int
    let volume: Int
}

struct WidgetAsset: Codable, Hashable {
    let symbol: String
    let name: String
    let price: Double
    let change: Double
    let currency: String
}

struct KonsensWidgetEntry: TimelineEntry {
    let date: Date
    let configuration: KonsensWidgetIntent
    let wealth: Int
    let performance: Double
    let markets: [WidgetMarket]
    let assets: [WidgetAsset]
}

struct KonsensWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> KonsensWidgetEntry {
        .init(date: .now, configuration: KonsensWidgetIntent(), wealth: 1000, performance: 0, markets: [.init(question: "Bitcoin dépassera-t-il 150 000 $ avant fin 2026 ?", category: "Crypto", probability: 28, volume: 0)], assets: [.init(symbol: "AAPL", name: "Apple", price: 221.45, change: 1.3, currency: "USD")])
    }

    func snapshot(for configuration: KonsensWidgetIntent, in context: Context) async -> KonsensWidgetEntry {
        entry(configuration)
    }

    func timeline(for configuration: KonsensWidgetIntent, in context: Context) async -> Timeline<KonsensWidgetEntry> {
        Timeline(entries: [entry(configuration)], policy: .after(Date().addingTimeInterval(15 * 60)))
    }

    private func entry(_ configuration: KonsensWidgetIntent) -> KonsensWidgetEntry {
        let defaults = UserDefaults(suiteName: "group.com.konsens.beta")
        let wealth = defaults?.integer(forKey: "konsens_widget_wealth") ?? 1000
        let performance = defaults?.double(forKey: "konsens_widget_performance") ?? 0
        let marketData = defaults?.data(forKey: "konsens_widget_markets")
        let assetData = defaults?.data(forKey: "konsens_widget_assets")
        let markets = marketData.flatMap { try? JSONDecoder().decode([WidgetMarket].self, from: $0) } ?? []
        let assets = assetData.flatMap { try? JSONDecoder().decode([WidgetAsset].self, from: $0) } ?? []
        return .init(date: .now, configuration: configuration, wealth: wealth == 0 ? 1000 : wealth, performance: performance, markets: markets, assets: assets)
    }
}

struct KonsensWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: KonsensWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                mark
                VStack(alignment: .leading, spacing: 0) {
                    Text("KONSENS").font(.system(size: 9, weight: .black, design: .rounded)).tracking(1)
                    Text(modeTitle).font(.system(size: 7, weight: .bold)).foregroundStyle(.secondary)
                }
                Spacer()
                if entry.configuration.universe != .play {
                    Text(entry.wealth.formatted()).font(.caption.monospacedDigit().bold())
                    Text("K").font(.system(size: 7, weight: .bold)).foregroundStyle(.secondary)
                }
            }

            if family == .systemSmall {
                smallContent
            } else {
                mediumContent
            }
            Spacer(minLength: 0)
            HStack {
                Circle().fill(Color.mint).frame(width: 5, height: 5)
                Text("Koins fictifs · mise à jour 15 min").font(.system(size: 6)).foregroundStyle(.secondary)
                Spacer()
            }
        }
        .containerBackground(for: .widget) { background }
        .widgetURL(URL(string: entry.configuration.universe == .finance ? "konsens://invest" : "konsens://play"))
    }

    @ViewBuilder private var smallContent: some View {
        switch entry.configuration.universe {
        case .play:
            if let market = entry.markets.first { PlayRow(market: market, large: true) } else { empty("Aucun jeu à la une") }
        case .finance:
            if let asset = entry.assets.first { FinanceRow(asset: asset, large: true) } else { empty("Marché en attente") }
        case .mixed:
            if let market = entry.markets.first { PlayRow(market: market, large: false) }
            if let asset = entry.assets.first { FinanceRow(asset: asset, large: false) }
        }
    }

    @ViewBuilder private var mediumContent: some View {
        switch entry.configuration.universe {
        case .play:
            HStack(spacing: 8) { ForEach(Array(entry.markets.prefix(2).enumerated()), id: \.offset) { _, market in PlayRow(market: market, large: false) } }
        case .finance:
            HStack(spacing: 8) { ForEach(Array(entry.assets.prefix(3).enumerated()), id: \.offset) { _, asset in FinanceRow(asset: asset, large: false) } }
        case .mixed:
            HStack(spacing: 8) {
                if let market = entry.markets.first { PlayRow(market: market, large: false).frame(maxWidth: .infinity) }
                Rectangle().fill(Color.white.opacity(0.08)).frame(width: 1)
                VStack(spacing: 6) { ForEach(Array(entry.assets.prefix(2).enumerated()), id: \.offset) { _, asset in FinanceRow(asset: asset, large: false) } }.frame(maxWidth: .infinity)
            }
        }
    }

    private var modeTitle: String {
        switch entry.configuration.universe { case .play: "PLAY"; case .finance: "FINANCE"; case .mixed: "PLAY · FINANCE" }
    }

    private var mark: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9).fill(Color(red: 0.035, green: 0.075, blue: 0.10))
            Text("K").font(.system(size: 17, weight: .black, design: .rounded).italic()).foregroundStyle(LinearGradient(colors: [.mint,.blue,.purple], startPoint: .topLeading, endPoint: .bottomTrailing))
        }.frame(width: 31, height: 31)
    }

    private var background: some View {
        ZStack {
            Color(red: 0.025, green: 0.045, blue: 0.065)
            if entry.configuration.universe != .finance {
                RadialGradient(colors: [Color.purple.opacity(0.18), .clear], center: .topTrailing, startRadius: 0, endRadius: 160)
            }
            if entry.configuration.universe != .play {
                LinearGradient(colors: [Color.blue.opacity(0.05), .clear], startPoint: .bottomLeading, endPoint: .topTrailing)
            }
        }
    }

    private func empty(_ text: String) -> some View { Text(text).font(.caption).foregroundStyle(.secondary) }
}

private struct PlayRow: View {
    let market: WidgetMarket
    let large: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack { Text(market.category.uppercased()).font(.system(size: 6, weight: .bold)).foregroundStyle(.purple); Spacer(); Text("\(market.probability)%").font((large ? Font.title2 : Font.caption).monospacedDigit().bold()).foregroundStyle(.mint) }
            Text(market.question).font(.system(size: large ? 11 : 9, weight: .semibold)).lineLimit(large ? 3 : 2)
            HStack { Text("OUI").font(.system(size: 6, weight: .black)).foregroundStyle(.mint); Text("x\(String(format: "%.2f", 1 / max(0.02, Double(market.probability) / 100)))").font(.system(size: 7, weight: .bold)).foregroundStyle(.secondary); Spacer(); Text("\(market.volume) K vol.").font(.system(size: 6)).foregroundStyle(.secondary) }
        }
        .padding(8).background(Color.purple.opacity(0.07), in: RoundedRectangle(cornerRadius: 11))
    }
}

private struct FinanceRow: View {
    let asset: WidgetAsset
    let large: Bool
    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text(asset.symbol).font(.system(size: large ? 12 : 9, weight: .black, design: .monospaced))
                Text(asset.price.formatted(.number.precision(.fractionLength(2)))).font(.system(size: large ? 18 : 11, weight: .bold, design: .monospaced))
                Text(asset.currency).font(.system(size: 6)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 2)
            Text(String(format: "%+.1f%%", asset.change)).font(.system(size: large ? 9 : 7, weight: .bold)).foregroundStyle(asset.change >= 0 ? Color.mint : Color.red)
        }
        .padding(8).background(Color.blue.opacity(0.055), in: RoundedRectangle(cornerRadius: 11))
    }
}

@main
struct KonsensWidget: Widget {
    let kind = "KonsensWidget"
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: KonsensWidgetIntent.self, provider: KonsensWidgetProvider()) { entry in
            KonsensWidgetView(entry: entry)
        }
        .configurationDisplayName("Konsens Live")
        .description("Choisis les jeux les plus engageants, les marchés financiers ou un mix des deux.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
