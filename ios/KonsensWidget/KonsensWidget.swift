import WidgetKit
import SwiftUI
import AppIntents

enum WidgetUniverse: String, AppEnum {
    case play, finance, learn, mixed

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Univers Konsens")
    static var caseDisplayRepresentations: [WidgetUniverse: DisplayRepresentation] = [
        .play: "Jouer",
        .finance: "Investir",
        .learn: "Apprendre",
        .mixed: "Les 3 univers"
    ]
}

struct KonsensWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Univers du widget"
    static var description = IntentDescription("Choisis Jouer, Investir, Apprendre ou les trois univers Konsens.")

    @Parameter(title: "Afficher", default: WidgetUniverse.mixed)
    var universe: WidgetUniverse
}

struct WidgetMarket: Codable, Hashable {
    let question: String
    let category: String
    let probability: Int
    let volume: Int
    let movement: Double
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
        .init(
            date: .now,
            configuration: KonsensWidgetIntent(),
            wealth: 1000,
            performance: 0,
            markets: [.init(question: "Bitcoin dépassera-t-il son prochain seuil ?", category: "Crypto", probability: 51, volume: 0, movement: 2.4)],
            assets: [.init(symbol: "BTC", name: "Bitcoin", price: 58240, change: 1.3, currency: "EUR")]
        )
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
        return .init(
            date: .now,
            configuration: configuration,
            wealth: wealth == 0 ? 1000 : wealth,
            performance: performance,
            markets: markets,
            assets: assets
        )
    }
}

struct KonsensWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: KonsensWidgetEntry

    private var universe: WidgetUniverse { entry.configuration.universe }

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular: accessoryCircle
            case .accessoryRectangular: accessoryRect
            case .accessoryInline: accessoryInline
            default: standard
            }
        }
        .containerBackground(for: .widget) { background }
        .widgetURL(deepLink)
    }

    private var standard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                mark
                VStack(alignment: .leading, spacing: 0) {
                    Text("KONSENS")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .tracking(1)
                    Text(modeTitle)
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if universe == .finance || universe == .mixed {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(entry.wealth.formatted()).font(.caption.monospacedDigit().bold())
                        Text("K · \(String(format: "%+.1f%%", entry.performance))")
                            .font(.system(size: 6, weight: .bold))
                            .foregroundStyle(entry.performance >= 0 ? Color.mint : Color.red)
                    }
                }
            }

            if family == .systemSmall { smallContent } else { mediumContent }
            Spacer(minLength: 0)
            learningFooter
        }
        .padding(3)
    }

    @ViewBuilder
    private var smallContent: some View {
        switch universe {
        case .play:
            if let market = entry.markets.first { PlayRow(market: market, large: true) } else { empty("Aucun jeu suivi") }
        case .finance:
            if let asset = entry.assets.first { FinanceRow(asset: asset, large: true) } else { empty("Marché en attente") }
        case .learn:
            LearnRow(large: true)
        case .mixed:
            ThreeWorldsCompact(market: entry.markets.first, asset: entry.assets.first)
        }
    }

    @ViewBuilder
    private var mediumContent: some View {
        switch universe {
        case .play:
            HStack(spacing: 8) {
                ForEach(Array(entry.markets.prefix(2).enumerated()), id: \.offset) { _, market in
                    PlayRow(market: market, large: false)
                }
            }
        case .finance:
            HStack(spacing: 8) {
                ForEach(Array(entry.assets.prefix(3).enumerated()), id: \.offset) { _, asset in
                    FinanceRow(asset: asset, large: false)
                }
            }
        case .learn:
            LearnRow(large: false)
        case .mixed:
            HStack(spacing: 7) {
                if let market = entry.markets.first {
                    PlayRow(market: market, large: false).frame(maxWidth: .infinity)
                } else {
                    UniverseFallback(icon: "bolt.fill", title: "JOUER", subtitle: "Tester une intuition", accent: .purple)
                }
                if let asset = entry.assets.first {
                    FinanceRow(asset: asset, large: false).frame(maxWidth: .infinity)
                } else {
                    UniverseFallback(icon: "chart.line.uptrend.xyaxis", title: "INVESTIR", subtitle: "Lire le marché", accent: .blue)
                }
                LearnRow(large: false).frame(maxWidth: .infinity)
            }
        }
    }

    private var accessoryCircle: some View {
        ZStack {
            Image("KonsensLogo").resizable().scaledToFit().clipShape(Circle())
            switch universe {
            case .play:
                if let market = entry.markets.first {
                    Text("\(market.probability)%")
                        .font(.system(size: 10, weight: .black))
                        .padding(3)
                        .background(.black.opacity(0.72), in: Capsule())
                        .offset(y: 18)
                }
            case .finance:
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 11, weight: .bold))
                    .padding(4)
                    .background(.black.opacity(0.72), in: Circle())
                    .offset(x: 17, y: 17)
            case .learn:
                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.mint)
                    .padding(4)
                    .background(.black.opacity(0.72), in: Circle())
                    .offset(x: 17, y: 17)
            case .mixed:
                Circle().fill(Color.mint).frame(width: 6, height: 6).offset(y: 22)
            }
        }
    }

    private var accessoryRect: some View {
        HStack(spacing: 7) {
            Image("KonsensLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 26, height: 26)
                .clipShape(RoundedRectangle(cornerRadius: 7))
            switch universe {
            case .finance:
                if let asset = entry.assets.first {
                    VStack(alignment: .leading) {
                        Text(asset.symbol).font(.caption.bold())
                        Text(String(format: "%+.1f%%", asset.change))
                            .font(.caption2)
                            .foregroundStyle(asset.change >= 0 ? Color.green : Color.red)
                    }
                }
            case .learn:
                VStack(alignment: .leading, spacing: 1) {
                    Text("APPRENDRE").font(.caption2.bold())
                    Text("Comprendre le risque").font(.caption2).foregroundStyle(.secondary)
                }
            case .play, .mixed:
                if let market = entry.markets.first {
                    VStack(alignment: .leading) {
                        Text(market.category).font(.caption2)
                        Text("OUI \(market.probability)%").font(.caption.bold())
                    }
                } else {
                    Text("Jouer · Investir · Apprendre").font(.caption2)
                }
            }
            Spacer()
        }
    }

    private var accessoryInline: some View {
        Group {
            switch universe {
            case .finance:
                if let asset = entry.assets.first {
                    Text("Konsens · \(asset.symbol) \(String(format: "%+.1f%%", asset.change))")
                } else { Text("Konsens Finance") }
            case .learn:
                Text("Konsens · comprendre avant de risquer")
            case .play:
                if let market = entry.markets.first { Text("Konsens · \(market.probability)% OUI") }
                else { Text("Konsens Play") }
            case .mixed:
                Text("Konsens · jouer · investir · apprendre")
            }
        }
    }

    private var learningFooter: some View {
        HStack(spacing: 6) {
            Capsule().fill(Color.mint).frame(width: 28, height: 2)
            Text("APPRENDRE LA FINANCE")
                .font(.system(size: 6, weight: .black, design: .rounded))
                .tracking(0.7)
                .foregroundStyle(Color.mint)
            Spacer()
            Text("Koins fictifs · 15 min")
                .font(.system(size: 6))
                .foregroundStyle(.secondary)
        }
    }

    private var modeTitle: String {
        switch universe {
        case .play: "PLAY · JOUER"
        case .finance: "FINANCE · INVESTIR"
        case .learn: "ACADEMY · APPRENDRE"
        case .mixed: "3 UNIVERS · 1 APPRENTISSAGE"
        }
    }

    private var deepLink: URL? {
        switch universe {
        case .play: URL(string: "konsens://play")
        case .finance: URL(string: "konsens://invest")
        case .learn: URL(string: "konsens://learn")
        case .mixed: URL(string: "konsens://wealth")
        }
    }

    private var mark: some View {
        Image("KonsensLogo")
            .resizable()
            .scaledToFit()
            .frame(width: 31, height: 31)
            .clipShape(RoundedRectangle(cornerRadius: 9))
    }

    private var background: some View {
        ZStack {
            Color(red: 0.025, green: 0.045, blue: 0.065)
            switch universe {
            case .play:
                RadialGradient(colors: [Color.purple.opacity(0.20), .clear], center: .topTrailing, startRadius: 0, endRadius: 170)
            case .finance:
                LinearGradient(colors: [Color.blue.opacity(0.09), .clear], startPoint: .bottomLeading, endPoint: .topTrailing)
            case .learn:
                RadialGradient(colors: [Color.mint.opacity(0.10), Color.yellow.opacity(0.035), .clear], center: .topTrailing, startRadius: 0, endRadius: 180)
            case .mixed:
                ZStack {
                    RadialGradient(colors: [Color.purple.opacity(0.13), .clear], center: .topTrailing, startRadius: 0, endRadius: 150)
                    LinearGradient(colors: [Color.blue.opacity(0.05), Color.mint.opacity(0.035), .clear], startPoint: .bottomLeading, endPoint: .topTrailing)
                }
            }
        }
    }

    private func empty(_ text: String) -> some View {
        Text(text).font(.caption).foregroundStyle(.secondary)
    }
}

private struct PlayRow: View {
    let market: WidgetMarket
    let large: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(market.category.uppercased())
                    .font(.system(size: 6, weight: .bold))
                    .foregroundStyle(.purple)
                Spacer()
                Text("\(market.probability)%")
                    .font((large ? Font.title2 : Font.caption).monospacedDigit().bold())
                    .foregroundStyle(.mint)
            }
            Text(market.question)
                .font(.system(size: large ? 11 : 9, weight: .semibold))
                .lineLimit(large ? 3 : 2)
            HStack {
                Text("OUI").font(.system(size: 6, weight: .black)).foregroundStyle(.mint)
                Text("x\(String(format: "%.2f", 1 / max(0.02, Double(market.probability) / 100)))")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(.secondary)
                if abs(market.movement) >= 0.05 {
                    Text(String(format: "%@%.1f pt", market.movement > 0 ? "+" : "", market.movement))
                        .font(.system(size: 6, weight: .bold))
                        .foregroundStyle(market.movement >= 0 ? Color.mint : Color.red)
                }
                Spacer()
                Text("\(market.volume) K").font(.system(size: 6)).foregroundStyle(.secondary)
            }
        }
        .padding(8)
        .background(Color.purple.opacity(0.07), in: RoundedRectangle(cornerRadius: 11))
    }
}

private struct FinanceRow: View {
    let asset: WidgetAsset
    let large: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Circle().fill(Color.mint).frame(width: 4, height: 4)
                    Text(asset.symbol).font(.system(size: large ? 12 : 9, weight: .black, design: .monospaced))
                }
                Text(asset.price.formatted(.number.precision(.fractionLength(asset.price >= 1000 ? 0 : 2))))
                    .font(.system(size: large ? 18 : 11, weight: .bold, design: .monospaced))
                Text(asset.currency).font(.system(size: 6)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 2)
            Text(String(format: "%+.1f%%", asset.change))
                .font(.system(size: large ? 9 : 7, weight: .bold))
                .foregroundStyle(asset.change >= 0 ? Color.mint : Color.red)
        }
        .padding(8)
        .background(Color.blue.opacity(0.055), in: RoundedRectangle(cornerRadius: 11))
    }
}

private struct LearnRow: View {
    let large: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: large ? 7 : 5) {
            HStack {
                Image(systemName: "graduationcap.fill")
                    .font(.system(size: large ? 13 : 9, weight: .bold))
                    .foregroundStyle(.mint)
                Text("ACADEMY")
                    .font(.system(size: 6, weight: .black))
                    .foregroundStyle(.yellow)
                Spacer()
                Text("+ XP").font(.system(size: 6, weight: .black)).foregroundStyle(.mint)
            }
            Text("Comprendre avant de risquer.")
                .font(.system(size: large ? 13 : 9, weight: .semibold, design: .rounded))
                .lineLimit(2)
            Text("Leçon → quiz → pratique")
                .font(.system(size: large ? 8 : 6, weight: .medium))
                .foregroundStyle(.secondary)
            if large {
                Text("OUVRIR ACADEMY →")
                    .font(.system(size: 6, weight: .black))
                    .foregroundStyle(.mint)
            }
        }
        .padding(8)
        .background(Color.mint.opacity(0.055), in: RoundedRectangle(cornerRadius: 11))
    }
}

private struct ThreeWorldsCompact: View {
    let market: WidgetMarket?
    let asset: WidgetAsset?

    var body: some View {
        VStack(spacing: 6) {
            compact(icon: "bolt.fill", title: "JOUER", value: market.map { "\($0.probability)% OUI" } ?? "Tester", accent: .purple)
            compact(icon: "chart.line.uptrend.xyaxis", title: "INVESTIR", value: asset.map { "\($0.symbol) \(String(format: "%+.1f%%", $0.change))" } ?? "Observer", accent: .blue)
            compact(icon: "graduationcap.fill", title: "APPRENDRE", value: "Comprendre", accent: .mint)
        }
    }

    private func compact(icon: String, title: String, value: String, accent: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 8, weight: .bold)).foregroundStyle(accent)
            Text(title).font(.system(size: 6, weight: .black)).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.system(size: 8, weight: .bold, design: .rounded))
        }
        .padding(7)
        .background(accent.opacity(0.055), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct UniverseFallback: View {
    let icon: String
    let title: String
    let subtitle: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Image(systemName: icon).font(.system(size: 10, weight: .bold)).foregroundStyle(accent)
            Text(title).font(.system(size: 6, weight: .black)).foregroundStyle(.secondary)
            Text(subtitle).font(.system(size: 8, weight: .semibold)).lineLimit(2)
        }
        .padding(8)
        .background(accent.opacity(0.055), in: RoundedRectangle(cornerRadius: 11))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

@main
struct KonsensWidget: Widget {
    let kind = "KonsensWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: KonsensWidgetIntent.self, provider: KonsensWidgetProvider()) { entry in
            KonsensWidgetView(entry: entry)
        }
        .configurationDisplayName("Konsens · 3 univers")
        .description("Jouer, investir et apprendre avec un même fil conducteur financier.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}
