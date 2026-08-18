import WidgetKit
import SwiftUI
import AppIntents

enum WidgetUniverse: String, AppEnum {
    case journey, play, finance, academy, mixed

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Univers Konsens")
    static var caseDisplayRepresentations: [WidgetUniverse: DisplayRepresentation] = [
        WidgetUniverse.journey: "Aujourd’hui",
        WidgetUniverse.play: "Prédictions",
        WidgetUniverse.finance: "Finance + Blockchain",
        WidgetUniverse.academy: "Apprendre",
        WidgetUniverse.mixed: "Prédictions + Finance"
    ]
}

struct KonsensWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Contenu du widget"
    static var description = IntentDescription("Choisis ton entraînement du jour, Play, Finance + blockchain, Academy ou un mix.")
    @Parameter(title: "Afficher", default: WidgetUniverse.journey) var universe: WidgetUniverse
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
    let score: Int
    let progress: Int
    let next: String
    let streak: Int
    let archetype: String
    let chainFlow: Double
    let chainWallet: String
    let chainProvider: String
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
            score: 68,
            progress: 2,
            next: "Décider",
            streak: 4,
            archetype: "Explorateur",
            chainFlow: 125000,
            chainWallet: "Public wallet",
            chainProvider: "Blockscout",
            markets: [.init(question: "Bitcoin dépassera-t-il son prochain seuil ?", category: "Crypto", probability: 51, volume: 0, movement: 2.4)],
            assets: [.init(symbol: "AAPL", name: "Apple", price: 221.45, change: 1.3, currency: "USD")]
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
        let score = defaults?.integer(forKey: "konsens_journey_score") ?? 50
        let progress = defaults?.integer(forKey: "konsens_journey_progress") ?? 0
        let next = defaults?.string(forKey: "konsens_journey_next") ?? "Comprendre"
        let streak = defaults?.integer(forKey: "konsens_journey_streak") ?? 0
        let archetype = defaults?.string(forKey: "konsens_journey_archetype") ?? "Explorateur"
        let chainFlow = defaults?.double(forKey: "konsens_widget_chain_flow") ?? 0
        let chainWallet = defaults?.string(forKey: "konsens_widget_chain_wallet") ?? "Ethereum public"
        let chainProvider = defaults?.string(forKey: "konsens_widget_chain_provider") ?? "Blockchain"
        let marketData = defaults?.data(forKey: "konsens_widget_markets")
        let assetData = defaults?.data(forKey: "konsens_widget_assets")
        let markets = marketData.flatMap { try? JSONDecoder().decode([WidgetMarket].self, from: $0) } ?? []
        let assets = assetData.flatMap { try? JSONDecoder().decode([WidgetAsset].self, from: $0) } ?? []

        return .init(
            date: .now,
            configuration: configuration,
            wealth: wealth == 0 ? 1000 : wealth,
            performance: performance,
            score: score == 0 ? 50 : score,
            progress: progress,
            next: next,
            streak: streak,
            archetype: archetype,
            chainFlow: chainFlow,
            chainWallet: chainWallet,
            chainProvider: chainProvider,
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
        .widgetURL(URL(string: deepLink))
    }

    private var standard: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                mark
                VStack(alignment: .leading, spacing: 0) {
                    Text("KONSENS").font(.system(size: 9, weight: .black, design: .rounded)).tracking(1)
                    Text(modeTitle).font(.system(size: 7, weight: .bold)).foregroundStyle(.secondary)
                }
                Spacer()
                if universe == WidgetUniverse.journey || universe == WidgetUniverse.academy {
                    Text("\(entry.score)").font(.title3.monospacedDigit().bold())
                    Text("/100").font(.system(size: 7)).foregroundStyle(.secondary)
                } else if universe != WidgetUniverse.play {
                    Text(entry.wealth.formatted()).font(.caption.monospacedDigit().bold())
                    Text("K").font(.system(size: 7, weight: .bold)).foregroundStyle(.secondary)
                }
            }

            if family == .systemSmall { smallContent } else { mediumContent }

            Spacer(minLength: 0)
            HStack {
                Capsule().fill(Color.mint).frame(width: 22, height: 3)
                Text(footer).font(.system(size: 6)).foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding(3)
    }

    @ViewBuilder private var smallContent: some View {
        switch universe {
        case WidgetUniverse.journey:
            JourneyRow(entry: entry, compact: false)
        case WidgetUniverse.play:
            if let market = entry.markets.first { PlayRow(market: market, large: true) } else { empty("Aucun marché") }
        case WidgetUniverse.finance:
            VStack(spacing: 6) {
                if let asset = entry.assets.first { FinanceRow(asset: asset, large: true) } else { empty("Marché en attente") }
                ChainRow(entry: entry, compact: true)
            }
        case WidgetUniverse.academy:
            AcademyRow(entry: entry)
        case WidgetUniverse.mixed:
            if let market = entry.markets.first { PlayRow(market: market, large: false) }
            if let asset = entry.assets.first { FinanceRow(asset: asset, large: false) }
        }
    }

    @ViewBuilder private var mediumContent: some View {
        switch universe {
        case WidgetUniverse.journey:
            HStack(spacing: 10) {
                JourneyRow(entry: entry, compact: false).frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 7) {
                    Text("TON PROFIL").font(.system(size: 6, weight: .black)).foregroundStyle(.mint)
                    Text(entry.archetype).font(.caption.bold())
                    Text("\(entry.streak) j de régularité").font(.system(size: 7)).foregroundStyle(.secondary)
                    Text("Comprendre, prédire, décider, apprendre.").font(.system(size: 7)).foregroundStyle(.secondary).lineLimit(3)
                }.frame(maxWidth: .infinity)
            }
        case WidgetUniverse.play:
            HStack(spacing: 8) {
                ForEach(Array(entry.markets.prefix(2).enumerated()), id: \.offset) { _, market in
                    PlayRow(market: market, large: false)
                }
            }
        case WidgetUniverse.finance:
            HStack(spacing: 8) {
                VStack(spacing: 6) {
                    ForEach(Array(entry.assets.prefix(2).enumerated()), id: \.offset) { _, asset in
                        FinanceRow(asset: asset, large: false)
                    }
                }.frame(maxWidth: .infinity)
                Rectangle().fill(Color.white.opacity(0.08)).frame(width: 1)
                ChainRow(entry: entry, compact: false).frame(maxWidth: .infinity)
            }
        case WidgetUniverse.academy:
            HStack(spacing: 10) {
                AcademyRow(entry: entry).frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 6) {
                    Text("LA LIGNE VERTE").font(.system(size: 6, weight: .black)).foregroundStyle(.mint)
                    Text("Comprendre avant de risquer").font(.caption.bold())
                    Text("\(entry.streak) j de régularité · prochaine étape : \(entry.next)").font(.system(size: 7)).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity)
            }
        case WidgetUniverse.mixed:
            HStack(spacing: 8) {
                if let market = entry.markets.first { PlayRow(market: market, large: false).frame(maxWidth: .infinity) }
                Rectangle().fill(Color.white.opacity(0.08)).frame(width: 1)
                VStack(spacing: 6) {
                    ForEach(Array(entry.assets.prefix(2).enumerated()), id: \.offset) { _, asset in
                        FinanceRow(asset: asset, large: false)
                    }
                }.frame(maxWidth: .infinity)
            }
        }
    }

    private var accessoryCircle: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.14), lineWidth: 4)
            Circle()
                .trim(from: 0, to: CGFloat(max(0.04, Double(entry.progress) / 4)))
                .stroke(Color.mint, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: -1) {
                Text("\(entry.score)").font(.system(size: 13, weight: .black))
                Text("K").font(.system(size: 6, weight: .bold)).foregroundStyle(.secondary)
            }
        }
    }

    private var accessoryRect: some View {
        HStack(spacing: 7) {
            Image("KonsensLogo").resizable().scaledToFit().frame(width: 26, height: 26).clipShape(RoundedRectangle(cornerRadius: 7))
            if universe == WidgetUniverse.journey || universe == WidgetUniverse.academy {
                VStack(alignment: .leading, spacing: 1) {
                    Text(universe == WidgetUniverse.academy ? "Academy \(entry.score)/100" : "Score \(entry.score)/100").font(.caption.bold())
                    Text("\(entry.progress)/4 · \(entry.next)").font(.caption2).foregroundStyle(.secondary)
                }
            } else if universe == WidgetUniverse.finance, let asset = entry.assets.first {
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(asset.symbol)  \(String(format: "%+.1f%%", asset.change))").font(.caption.bold())
                    Text(chainLabel).font(.caption2).foregroundStyle(.secondary)
                }
            } else if let market = entry.markets.first {
                VStack(alignment: .leading) {
                    Text(market.category).font(.caption2)
                    Text("OUI \(market.probability)%").font(.caption.bold())
                }
            }
            Spacer()
        }
    }

    private var accessoryInline: some View {
        if universe == WidgetUniverse.journey {
            Text("Konsens \(entry.score)/100 · \(entry.next)")
        } else if universe == WidgetUniverse.academy {
            Text("Konsens Academy · \(entry.progress)/4 · \(entry.next)")
        } else if universe == WidgetUniverse.finance, let asset = entry.assets.first {
            Text("Konsens · \(asset.symbol) \(String(format: "%+.1f%%", asset.change)) · On-chain \(signedCompact(entry.chainFlow))")
        } else if let market = entry.markets.first {
            Text("Konsens · \(market.probability)% OUI")
        } else {
            Text("Konsens Live")
        }
    }

    private var modeTitle: String {
        switch universe {
        case WidgetUniverse.journey: return "AUJOURD’HUI"
        case WidgetUniverse.play: return "PLAY"
        case WidgetUniverse.finance: return "INVESTIR · ON-CHAIN"
        case WidgetUniverse.academy: return "APPRENDRE"
        case WidgetUniverse.mixed: return "PLAY · FINANCE"
        }
    }

    private var deepLink: String {
        switch universe {
        case WidgetUniverse.journey: return "konsens://today"
        case WidgetUniverse.play: return "konsens://play"
        case WidgetUniverse.finance: return "konsens://invest"
        case WidgetUniverse.academy: return "konsens://learn"
        case WidgetUniverse.mixed: return "konsens://play"
        }
    }

    private var footer: String {
        switch universe {
        case WidgetUniverse.academy: return "Apprendre · pratiquer · maîtriser"
        case WidgetUniverse.finance: return "Cours réel · Koins fictifs · chaîne publique"
        default: return "Entraîne ton intelligence financière"
        }
    }

    private var chainLabel: String {
        entry.chainFlow == 0 ? "On-chain en attente" : "On-chain \(signedCompact(entry.chainFlow))"
    }

    private var mark: some View {
        Image("KonsensLogo").resizable().scaledToFit().frame(width: 31, height: 31).clipShape(RoundedRectangle(cornerRadius: 9))
    }

    private var background: some View {
        ZStack {
            Color(red: 0.025, green: 0.045, blue: 0.065)
            if universe == WidgetUniverse.journey {
                RadialGradient(colors: [Color.mint.opacity(0.12), Color.purple.opacity(0.08), .clear], center: .topTrailing, startRadius: 0, endRadius: 180)
            } else if universe == WidgetUniverse.academy {
                RadialGradient(colors: [Color.mint.opacity(0.16), Color.yellow.opacity(0.06), .clear], center: .topTrailing, startRadius: 0, endRadius: 180)
            } else {
                if universe != WidgetUniverse.finance {
                    RadialGradient(colors: [Color.purple.opacity(0.18), .clear], center: .topTrailing, startRadius: 0, endRadius: 160)
                }
                if universe != WidgetUniverse.play {
                    LinearGradient(colors: [Color.blue.opacity(0.05), .clear], startPoint: .bottomLeading, endPoint: .topTrailing)
                }
            }
        }
    }

    private func empty(_ text: String) -> some View {
        Text(text).font(.caption).foregroundStyle(.secondary)
    }

    private func signedCompact(_ value: Double) -> String {
        let sign = value > 0 ? "+" : ""
        return sign + value.formatted(.number.notation(.compactName).precision(.fractionLength(0))) + "€"
    }
}

private struct JourneyRow: View {
    let entry: KonsensWidgetEntry
    let compact: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("DAILY KONSENS").font(.system(size: 6, weight: .black)).foregroundStyle(.mint)
                Spacer()
                Text("\(entry.progress)/4").font(.caption.monospacedDigit().bold())
            }
            Text(entry.progress >= 4 ? "Entraînement terminé" : "Prochaine étape : \(entry.next)")
                .font(.system(size: compact ? 9 : 11, weight: .bold)).lineLimit(2)
            HStack(spacing: 3) {
                ForEach(0..<4, id: \.self) { index in
                    Capsule().fill(index < entry.progress ? Color.mint : Color.white.opacity(0.08)).frame(height: 5)
                }
            }
            Text(entry.archetype).font(.system(size: 7)).foregroundStyle(.secondary)
        }
    }
}

private struct AcademyRow: View {
    let entry: KonsensWidgetEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Image(systemName: "graduationcap.fill").foregroundStyle(.mint)
                Text("ACADEMY").font(.system(size: 6, weight: .black)).foregroundStyle(.mint)
                Spacer()
                Text("\(entry.streak)🔥").font(.caption2.bold())
            }
            Text(entry.next).font(.system(size: 11, weight: .bold)).lineLimit(2)
            HStack(spacing: 3) {
                ForEach(0..<4, id: \.self) { index in
                    Circle().fill(index < entry.progress ? Color.mint : Color.white.opacity(0.09)).frame(width: 9, height: 9)
                    if index < 3 { Capsule().fill(index < entry.progress ? Color.mint.opacity(0.7) : Color.white.opacity(0.07)).frame(height: 3) }
                }
            }
            Text("Comprendre avant de risquer").font(.system(size: 7)).foregroundStyle(.secondary)
        }
    }
}

private struct ChainRow: View {
    let entry: KonsensWidgetEntry
    let compact: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle().fill(Color.mint).frame(width: 5, height: 5)
                Text("ON-CHAIN").font(.system(size: 6, weight: .black, design: .monospaced)).foregroundStyle(.mint)
                Spacer()
            }
            Text(entry.chainFlow == 0 ? "Flux en attente" : signed(entry.chainFlow))
                .font(.system(size: compact ? 10 : 13, weight: .bold, design: .monospaced))
                .foregroundStyle(entry.chainFlow >= 0 ? Color.mint : Color.red)
            Text(entry.chainWallet).font(.system(size: 6)).foregroundStyle(.secondary).lineLimit(1)
            if !compact { Text(entry.chainProvider).font(.system(size: 6)).foregroundStyle(.secondary).lineLimit(1) }
        }
        .padding(8)
        .background(Color.mint.opacity(0.055), in: RoundedRectangle(cornerRadius: 10))
    }

    private func signed(_ value: Double) -> String {
        let sign = value > 0 ? "+" : ""
        return sign + value.formatted(.number.notation(.compactName).precision(.fractionLength(0))) + "€ net"
    }
}

private struct PlayRow: View {
    let market: WidgetMarket
    let large: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(market.category.uppercased()).font(.system(size: 6, weight: .bold)).foregroundStyle(.purple)
                Spacer()
                Text("\(market.probability)%").font((large ? Font.title2 : Font.caption).monospacedDigit().bold()).foregroundStyle(.mint)
            }
            Text(market.question).font(.system(size: large ? 11 : 9, weight: .semibold)).lineLimit(large ? 3 : 2)
            HStack {
                Text("OUI").font(.system(size: 6, weight: .black)).foregroundStyle(.mint)
                Text("x\(String(format: "%.2f", 1 / max(0.02, Double(market.probability) / 100)))")
                    .font(.system(size: 7, weight: .bold)).foregroundStyle(.secondary)
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
                Text(asset.symbol).font(.system(size: large ? 12 : 9, weight: .black, design: .monospaced))
                Text(asset.price.formatted(.number.precision(.fractionLength(2))))
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

@main
struct KonsensWidget: Widget {
    let kind = "KonsensWidget"
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: KonsensWidgetIntent.self, provider: KonsensWidgetProvider()) { entry in
            KonsensWidgetView(entry: entry)
        }
        .configurationDisplayName("Konsens · 3 univers")
        .description("Ton Daily Konsens, Play, Finance + blockchain ou Academy dans un seul widget.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}