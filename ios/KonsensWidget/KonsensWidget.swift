import WidgetKit
import SwiftUI
import AppIntents

enum WidgetUniverse: String, AppEnum {
    case play, finance, learn, mixed

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Vue Konsens")
    static var caseDisplayRepresentations: [WidgetUniverse: DisplayRepresentation] = [
        .mixed: "Konsens Game",
        .play: "Miser",
        .finance: "Investir",
        .learn: "Apprendre"
    ]
}

struct KonsensWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Vue du widget"
    static var description = IntentDescription("Garde ton score et tes prochains challenges Konsens sous les yeux.")

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
            wealth: 1280,
            performance: 12.8,
            markets: [
                .init(
                    question: "Le prochain gros lancement tech dépassera-t-il les attentes ?",
                    category: "Tech",
                    probability: 58,
                    volume: 1840,
                    movement: 3.2
                )
            ],
            assets: [
                .init(symbol: "BTC", name: "Bitcoin", price: 58240, change: 1.3, currency: "EUR")
            ]
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
            case .accessoryCircular:
                accessoryCircle
            case .accessoryRectangular:
                accessoryRect
            case .accessoryInline:
                accessoryInline
            default:
                standard
            }
        }
        .containerBackground(for: .widget) { background }
        .widgetURL(deepLink)
    }

    private var standard: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            if family == .systemSmall {
                smallContent
            } else {
                mediumContent
            }

            Spacer(minLength: 0)
            footer
        }
        .padding(3)
    }

    private var header: some View {
        HStack(spacing: 7) {
            Image("KonsensLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 31, height: 31)
                .clipShape(RoundedRectangle(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 0) {
                Text("KONSENS GAME")
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .tracking(0.8)
                Text(modeTitle)
                    .font(.system(size: 6, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if universe == .mixed || universe == .finance {
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(entry.wealth) K")
                        .font(.caption.monospacedDigit().bold())
                    Text("TON SCORE")
                        .font(.system(size: 5, weight: .black, design: .rounded))
                        .foregroundStyle(.mint)
                }
            }
        }
    }

    @ViewBuilder
    private var smallContent: some View {
        switch universe {
        case .mixed:
            gameCard
        case .play:
            if let market = entry.markets.first {
                PlayRow(market: market, large: true)
            } else {
                fallback(icon: "bolt.fill", title: "NOUVEAU DÉFI", subtitle: "Ouvre Konsens pour jouer", accent: .purple)
            }
        case .finance:
            if let asset = entry.assets.first {
                FinanceRow(asset: asset, large: true)
            } else {
                fallback(icon: "chart.line.uptrend.xyaxis", title: "INVESTIR", subtitle: "Un marché t’attend", accent: .blue)
            }
        case .learn:
            learnCard
        }
    }

    @ViewBuilder
    private var mediumContent: some View {
        switch universe {
        case .mixed:
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("PATRIMOINE")
                        .font(.system(size: 6, weight: .black, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text("\(entry.wealth) K")
                        .font(.system(size: 25, weight: .black, design: .rounded))
                        .monospacedDigit()
                    Text(entry.performance >= 0 ? "Tu montes. Continue." : "À toi de rebondir.")
                        .font(.system(size: 8, weight: .semibold, design: .rounded))
                        .foregroundStyle(entry.performance >= 0 ? Color.mint : Color.orange)
                    Spacer(minLength: 0)
                    Label("OUVRIR LA LIGUE", systemImage: "trophy.fill")
                        .font(.system(size: 6, weight: .black, design: .rounded))
                        .foregroundStyle(.yellow)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color.purple.opacity(0.09), in: RoundedRectangle(cornerRadius: 12))

                if let market = entry.markets.first {
                    PlayRow(market: market, large: false)
                        .frame(maxWidth: .infinity)
                } else {
                    fallback(icon: "bolt.fill", title: "CHALLENGE", subtitle: "Reviens jouer aujourd’hui", accent: .purple)
                        .frame(maxWidth: .infinity)
                }
            }
        case .play:
            HStack(spacing: 8) {
                ForEach(Array(entry.markets.prefix(2).enumerated()), id: \.offset) { _, market in
                    PlayRow(market: market, large: false)
                        .frame(maxWidth: .infinity)
                }
                if entry.markets.isEmpty {
                    fallback(icon: "bolt.fill", title: "MISER", subtitle: "Les prochains défis arrivent", accent: .purple)
                }
            }
        case .finance:
            HStack(spacing: 8) {
                ForEach(Array(entry.assets.prefix(3).enumerated()), id: \.offset) { _, asset in
                    FinanceRow(asset: asset, large: false)
                        .frame(maxWidth: .infinity)
                }
                if entry.assets.isEmpty {
                    fallback(icon: "chart.line.uptrend.xyaxis", title: "INVESTIR", subtitle: "Joue le marché réel", accent: .blue)
                }
            }
        case .learn:
            learnCard
        }
    }

    private var gameCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    Text("TON PATRIMOINE")
                        .font(.system(size: 6, weight: .black, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text("\(entry.wealth) K")
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .monospacedDigit()
                }
                Spacer()
                Image(systemName: "trophy.fill")
                    .font(.title2)
                    .foregroundStyle(.yellow)
            }

            if let market = entry.markets.first {
                Divider().opacity(0.25)
                Text("⚡ DÉFI À JOUER")
                    .font(.system(size: 6, weight: .black, design: .rounded))
                    .foregroundStyle(.mint)
                Text(market.question)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .lineLimit(3)
            } else {
                Text("🎁 Ton prochain drop et ta ligue t’attendent.")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
            }
        }
        .padding(9)
        .background(Color.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    private var learnCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "graduationcap.fill")
                    .foregroundStyle(.mint)
                Text("ACADEMY")
                    .font(.system(size: 7, weight: .black, design: .rounded))
                    .foregroundStyle(.yellow)
                Spacer()
            }
            Text("Comprends tes bons et tes mauvais coups.")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .lineLimit(3)
            Text("Leçon → quiz → pratique")
                .font(.system(size: 7, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(9)
        .background(Color.mint.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Capsule().fill(Color.mint).frame(width: 24, height: 2)
            Text(universe == .mixed ? "REVIENS JOUER AUJOURD’HUI" : "KOINS FICTIFS · RISQUE RÉEL SIMULÉ")
                .font(.system(size: 5, weight: .black, design: .rounded))
                .tracking(0.5)
                .foregroundStyle(.mint)
            Spacer()
        }
    }

    private var accessoryCircle: some View {
        ZStack {
            Image("KonsensLogo")
                .resizable()
                .scaledToFit()
                .clipShape(Circle())
            if universe == .mixed {
                Text("\(entry.wealth)")
                    .font(.system(size: 8, weight: .black))
                    .padding(3)
                    .background(.black.opacity(0.75), in: Capsule())
                    .offset(y: 19)
            } else if universe == .play, let market = entry.markets.first {
                Text("\(market.probability)%")
                    .font(.system(size: 9, weight: .black))
                    .padding(3)
                    .background(.black.opacity(0.75), in: Capsule())
                    .offset(y: 19)
            }
        }
    }

    private var accessoryRect: some View {
        HStack(spacing: 7) {
            Image("KonsensLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 25, height: 25)
                .clipShape(RoundedRectangle(cornerRadius: 7))
            VStack(alignment: .leading, spacing: 1) {
                if universe == .mixed {
                    Text("\(entry.wealth) K · TON SCORE").font(.caption2.bold())
                    Text("Ta ligue t’attend").font(.caption2).foregroundStyle(.secondary)
                } else if universe == .play, let market = entry.markets.first {
                    Text("DÉFI · \(market.probability)% OUI").font(.caption2.bold())
                    Text(market.category).font(.caption2).foregroundStyle(.secondary)
                } else if universe == .finance, let asset = entry.assets.first {
                    Text("\(asset.symbol) · \(String(format: "%+.1f%%", asset.change))").font(.caption2.bold())
                    Text("Joue le marché").font(.caption2).foregroundStyle(.secondary)
                } else {
                    Text("KONSENS GAME").font(.caption2.bold())
                    Text("Reviens jouer").font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }

    private var accessoryInline: some View {
        Group {
            switch universe {
            case .mixed:
                Text("Konsens · \(entry.wealth) K · ta ligue t’attend")
            case .play:
                if let market = entry.markets.first {
                    Text("Konsens · défi \(market.probability)% OUI")
                } else {
                    Text("Konsens · nouveau défi")
                }
            case .finance:
                if let asset = entry.assets.first {
                    Text("Konsens · \(asset.symbol) \(String(format: "%+.1f%%", asset.change))")
                } else {
                    Text("Konsens · investir")
                }
            case .learn:
                Text("Konsens · apprends de tes coups")
            }
        }
    }

    private var modeTitle: String {
        switch universe {
        case .mixed: return "SCORE · CHALLENGES · LIGUE"
        case .play: return "MISER"
        case .finance: return "INVESTIR"
        case .learn: return "ACADEMY"
        }
    }

    private var deepLink: URL? {
        switch universe {
        case .mixed: return URL(string: "konsens://wealth")
        case .play: return URL(string: "konsens://play")
        case .finance: return URL(string: "konsens://invest")
        case .learn: return URL(string: "konsens://learn")
        }
    }

    private var background: some View {
        ZStack {
            Color(red: 0.022, green: 0.035, blue: 0.055)
            switch universe {
            case .mixed:
                RadialGradient(colors: [Color.purple.opacity(0.25), .clear], center: .topTrailing, startRadius: 0, endRadius: 180)
                RadialGradient(colors: [Color.mint.opacity(0.10), .clear], center: .bottomLeading, startRadius: 0, endRadius: 150)
            case .play:
                RadialGradient(colors: [Color.purple.opacity(0.24), .clear], center: .topTrailing, startRadius: 0, endRadius: 180)
            case .finance:
                LinearGradient(colors: [Color.blue.opacity(0.12), .clear], startPoint: .bottomLeading, endPoint: .topTrailing)
            case .learn:
                RadialGradient(colors: [Color.mint.opacity(0.12), Color.yellow.opacity(0.04), .clear], center: .topTrailing, startRadius: 0, endRadius: 180)
            }
        }
    }

    private func fallback(icon: String, title: String, subtitle: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(accent)
            Text(title)
                .font(.system(size: 7, weight: .black, design: .rounded))
            Text(subtitle)
                .font(.system(size: 8, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(9)
        .background(accent.opacity(0.06), in: RoundedRectangle(cornerRadius: 11))
    }
}

private struct PlayRow: View {
    let market: WidgetMarket
    let large: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("⚡ \(market.category.uppercased())")
                    .font(.system(size: 6, weight: .black, design: .rounded))
                    .foregroundStyle(.purple)
                Spacer()
                Text("\(market.probability)%")
                    .font(.system(size: large ? 17 : 11, weight: .black, design: .rounded))
                    .foregroundStyle(.mint)
            }

            Text(market.question)
                .font(.system(size: large ? 11 : 9, weight: .bold, design: .rounded))
                .lineLimit(large ? 4 : 3)

            HStack {
                Text("OUI")
                    .font(.system(size: 6, weight: .black, design: .rounded))
                    .foregroundStyle(.mint)
                Spacer()
                Text("JOUER →")
                    .font(.system(size: 6, weight: .black, design: .rounded))
                    .foregroundStyle(.purple)
            }
        }
        .padding(9)
        .background(Color.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 11))
    }
}

private struct FinanceRow: View {
    let asset: WidgetAsset
    let large: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(asset.symbol)
                    .font(.system(size: large ? 13 : 9, weight: .black, design: .monospaced))
                Spacer()
                Text(String(format: "%+.1f%%", asset.change))
                    .font(.system(size: large ? 9 : 7, weight: .bold))
                    .foregroundStyle(asset.change >= 0 ? Color.mint : Color.red)
            }

            Text(String(format: asset.price >= 1000 ? "%.0f" : "%.2f", asset.price))
                .font(.system(size: large ? 20 : 12, weight: .bold, design: .monospaced))
            Text("\(asset.currency) · ENGAGE TES KOINS")
                .font(.system(size: 5, weight: .black, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(9)
        .background(Color.blue.opacity(0.07), in: RoundedRectangle(cornerRadius: 11))
    }
}

@main
struct KonsensWidget: Widget {
    let kind = "KonsensWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: KonsensWidgetIntent.self,
            provider: KonsensWidgetProvider()
        ) { entry in
            KonsensWidgetView(entry: entry)
        }
        .configurationDisplayName("Konsens Game")
        .description("Ton patrimoine est ton score. Reviens miser, investir et grimper dans ta ligue.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}
