import SwiftUI
import Charts

struct LeagueView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selected: AssetQuote?
    @State private var quote: LiveMarketQuote?
    @State private var amount = 100
    @State private var range = "1mo"
    @State private var positionQuantity = 0.0
    @State private var positionAverage = 0.0
    @State private var loadingQuote = false
    @State private var showWatchedOnly = false

    private var visibleAssets: [AssetQuote] {
        showWatchedOnly ? store.assets.filter { store.watchedAssetIDs.contains($0.id) } : store.assets
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                FinanceHero(assetCount: store.assets.count, watchedCount: store.watchedAssetIDs.count)
                FinanceLearningBridge()

                FinanceCommandBar(
                    showWatchedOnly: $showWatchedOnly,
                    assetCount: store.assets.count,
                    watchedCount: store.watchedAssetIDs.count,
                    positionCount: positionQuantity > 0 ? 1 : 0
                ) {
                    if showWatchedOnly, selected.map({ !store.watchedAssetIDs.contains($0.id) }) == true {
                        selected = visibleAssets.first
                    }
                }

                if showWatchedOnly && visibleAssets.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "star").font(.largeTitle).foregroundStyle(Color.konsensBlue)
                        Text("Aucun marché suivi").font(.headline.monospaced())
                        Text("Ajoute un actif à tes suivis. Il remontera ici et dans ton widget Finance.")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Color.konsensMuted)
                        Button("Explorer les marchés") { showWatchedOnly = false }
                            .font(.caption.bold())
                            .foregroundStyle(Color.konsensBlue)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(28)
                    .financePanel()
                } else {
                    AssetRail(assets: visibleAssets, selected: $selected, watched: store.watchedAssetIDs)
                }

                if let asset = selected {
                    HStack {
                        HStack(spacing: 7) {
                            Circle()
                                .fill(assetAccent(asset))
                                .frame(width: 6, height: 6)
                                .shadow(color: assetAccent(asset).opacity(0.8), radius: 5)
                            Text(asset.kind.lowercased().contains("crypto") ? "ACTIF BLOCKCHAIN" : "ACTIF SÉLECTIONNÉ")
                                .font(.system(size: 7, weight: .black, design: .monospaced))
                                .tracking(1)
                                .foregroundStyle(asset.kind.lowercased().contains("crypto") ? Color.konsensGreen : Color.konsensBlue)
                        }
                        Spacer()
                        Button { Task { await store.toggleAssetWatch(asset) } } label: {
                            Label(
                                store.watchedAssetIDs.contains(asset.id) ? "Suivi" : "Suivre",
                                systemImage: store.watchedAssetIDs.contains(asset.id) ? "star.fill" : "star"
                            )
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Color.konsensBlue.opacity(store.watchedAssetIDs.contains(asset.id) ? 0.10 : 0.035), in: RoundedRectangle(cornerRadius: 6))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.konsensBlue.opacity(0.14)))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(store.watchedAssetIDs.contains(asset.id) ? Color.konsensBlue : Color.konsensMuted)
                    }

                    LiveAssetPanel(
                        asset: asset,
                        quote: quote,
                        positionQuantity: positionQuantity,
                        positionAverage: positionAverage,
                        amount: amount,
                        range: range,
                        loading: loadingQuote
                    )

                    RangePicker(range: $range)
                    AmountPicker(amount: $amount, accent: Color.konsensBlue)

                    HStack(spacing: 8) {
                        Button {
                            Task {
                                await store.buyAsset(asset, amount: amount)
                                await refreshPosition(asset)
                                await refreshQuote(asset)
                            }
                        } label: {
                            Label("Investir \(amount) K", systemImage: "plus.circle.fill")
                                .frame(maxWidth: .infinity)
                                .padding(13)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.konsensBackground)
                        .background(Color.konsensBlue, in: RoundedRectangle(cornerRadius: 8))
                        .disabled(store.credits < amount)
                        .opacity(store.credits < amount ? 0.35 : 1)

                        Button {
                            Task {
                                await store.sellAsset(asset, amount: amount)
                                await refreshPosition(asset)
                                await refreshQuote(asset)
                            }
                        } label: {
                            Label("Revendre", systemImage: "minus.circle.fill")
                                .frame(maxWidth: .infinity)
                                .padding(13)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.konsensNegative)
                        .background(Color.konsensNegative.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                        .disabled(positionValue < Double(amount))
                        .opacity(positionValue < Double(amount) ? 0.35 : 1)
                    }

                    GainLossLesson(quote: quote, amount: amount, range: range)
                } else if !showWatchedOnly {
                    ContentUnavailableView(
                        "Marché en préparation",
                        systemImage: "chart.xyaxis.line",
                        description: Text("Les actifs connectés apparaîtront ici.")
                    )
                    .financePanel()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Eyebrow(text: "DISCIPLINE D’INVESTISSEMENT")
                    Text("Un gain potentiel implique toujours un risque de perte.").font(.headline.monospaced())
                    Text("Konsens te fait lire le marché, simuler une décision, puis mesurer ce qu’elle aurait produit. Les Koins restent fictifs : l’objectif est de comprendre les conséquences avant de toucher à de l’argent réel.")
                        .font(.caption)
                        .foregroundStyle(Color.konsensMuted)
                        .lineSpacing(3)
                }
                .financePanel()

                PremiumMarketsCard()
                RiskFooter()
            }
            .padding(.horizontal, 18)
            .padding(.top, 106)
            .padding(.bottom, 110)
        }
        .task { if selected == nil { selected = store.assets.first } }
        .task(id: selected?.id) {
            if let asset = selected {
                await refreshQuote(asset)
                await refreshPosition(asset)
            }
        }
        .task(id: range) { if let asset = selected { await refreshQuote(asset) } }
        .refreshable {
            await store.refreshFinance()
            if let asset = selected {
                await refreshQuote(asset)
                await refreshPosition(asset)
            }
        }
    }

    private var positionValue: Double {
        guard let quote else { return 0 }
        return positionQuantity * quote.price
    }

    private func refreshQuote(_ asset: AssetQuote) async {
        loadingQuote = true
        if let coinID = coinGeckoID(for: asset), let cryptoQuote = await coinGeckoQuote(asset: asset, coinID: coinID, range: range) {
            quote = cryptoQuote
        } else {
            quote = await store.liveQuote(for: asset, range: range)
        }
        loadingQuote = false
    }

    private func refreshPosition(_ asset: AssetQuote) async {
        guard let userID = store.supabase.auth.currentUser?.id else { return }
        struct Row: Decodable { let quantity: Double; let average_price: Double }
        if let row: Row = try? await store.supabase
            .from("positions")
            .select("quantity,average_price")
            .eq("user_id", value: userID)
            .eq("asset_id", value: asset.id)
            .single()
            .execute()
            .value {
            positionQuantity = row.quantity
            positionAverage = row.average_price
        } else {
            positionQuantity = 0
            positionAverage = 0
        }
    }

    private func coinGeckoID(for asset: AssetQuote) -> String? {
        switch asset.symbol.uppercased() {
        case "BTC": return "bitcoin"
        case "ETH": return "ethereum"
        default: return nil
        }
    }

    private func coinGeckoQuote(asset: AssetQuote, coinID: String, range: String) async -> LiveMarketQuote? {
        let days: String
        switch range {
        case "1d": days = "1"
        case "5d": days = "5"
        case "1mo": days = "30"
        case "6mo": days = "180"
        case "1y": days = "365"
        case "5y": days = "1825"
        default: days = "30"
        }

        guard var components = URLComponents(string: "https://api.coingecko.com/api/v3/coins/\(coinID)/market_chart") else { return nil }
        components.queryItems = [
            URLQueryItem(name: "vs_currency", value: "eur"),
            URLQueryItem(name: "days", value: days),
            URLQueryItem(name: "precision", value: "full")
        ]
        guard let url = components.url else { return nil }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 10
            request.setValue("Konsens-iOS/2.0", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }

            struct Envelope: Decodable { let prices: [[Double]] }
            let decoded = try JSONDecoder().decode(Envelope.self, from: data)
            let points = decoded.prices.compactMap { row -> MarketPoint? in
                guard row.count >= 2, row[1].isFinite, row[1] > 0 else { return nil }
                return MarketPoint(time: Date(timeIntervalSince1970: row[0] / 1000), price: row[1])
            }
            guard let current = points.last?.price, !points.isEmpty else { return nil }
            let previous = points.first?.price ?? current
            let changePct = previous == 0 ? 0 : ((current - previous) / previous) * 100
            let updatedAt = ISO8601DateFormatter().string(from: points.last?.time ?? Date())
            return LiveMarketQuote(
                symbol: asset.symbol,
                currency: "EUR",
                exchange: "Crypto 24/7",
                price: current,
                previousClose: previous,
                changePct: changePct,
                updatedAt: updatedAt,
                provider: "CoinGecko Public API",
                points: points
            )
        } catch {
            return nil
        }
    }

    private func assetAccent(_ asset: AssetQuote) -> Color {
        asset.kind.lowercased().contains("crypto") ? Color.konsensGreen : Color.konsensBlue
    }
}

private struct FinanceHero: View {
    let assetCount: Int
    let watchedCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 7) {
                    Circle().fill(Color.konsensGreen).frame(width: 6, height: 6).shadow(color: Color.konsensGreen, radius: 5)
                    Text("KONSENS FINANCE · MARCHÉS CONNECTÉS")
                        .font(.system(size: 7, weight: .black, design: .monospaced))
                        .tracking(1.1)
                        .foregroundStyle(Color.konsensBlue)
                }
                Spacer()
                Text("SIMULATION")
                    .font(.system(size: 6, weight: .black, design: .monospaced))
                    .foregroundStyle(Color.konsensGreen)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.konsensGreen.opacity(0.08), in: RoundedRectangle(cornerRadius: 5))
            }
            Text("Lis le marché.\nTeste ta décision.")
                .font(.system(size: 37, weight: .bold, design: .monospaced))
                .tracking(-1.45)
            Text("Cours et historiques réels, Koins fictifs. Sur les actifs blockchain, Konsens charge un historique crypto dédié ; sur les autres marchés, il conserve la source finance connectée.")
                .font(.subheadline)
                .foregroundStyle(Color.konsensMuted)
                .lineSpacing(3)
            HStack(spacing: 8) {
                metric("\(assetCount)", "ACTIFS")
                metric("\(watchedCount)", "SUIVIS")
                metric("0 €", "ARGENT RÉEL")
            }
        }
        .padding(17)
        .background(
            LinearGradient(
                colors: [Color.konsensBlue.opacity(0.11), Color(red: 0.021, green: 0.043, blue: 0.054)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 12)
        )
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.konsensBlue.opacity(0.14)))
    }

    private func metric(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.caption.monospacedDigit().bold())
            Text(label).font(.system(size: 5, weight: .bold, design: .monospaced)).foregroundStyle(Color.konsensMuted)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 6))
    }
}

private struct FinanceLearningBridge: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 8) {
                Capsule().fill(Color.konsensGreen).frame(width: 36, height: 2)
                Text("LE FIL VERT · APPRENDRE EN DÉCIDANT")
                    .font(.system(size: 7, weight: .black, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(Color.konsensGreen)
            }
            HStack(spacing: 0) {
                bridgeStep("01", "Observer", "le réel")
                connector
                bridgeStep("02", "Simuler", "sans argent")
                connector
                bridgeStep("03", "Comprendre", "gain & perte")
            }
            Text("Un graphique qui monte n’est pas une promesse. Ici tu apprends aussi ce que signifie être du mauvais côté du mouvement.")
                .font(.caption2)
                .foregroundStyle(Color.konsensMuted)
        }
        .padding(13)
        .background(Color.konsensGreen.opacity(0.035), in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.konsensGreen.opacity(0.10)))
    }

    private var connector: some View {
        Rectangle().fill(Color.konsensGreen.opacity(0.18)).frame(height: 1).frame(maxWidth: 26).padding(.horizontal, 3)
    }

    private func bridgeStep(_ index: String, _ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(index).font(.system(size: 6, weight: .black, design: .monospaced)).foregroundStyle(Color.konsensGreen)
            Text(title).font(.caption2.monospaced().bold())
            Text(subtitle.uppercased()).font(.system(size: 5, design: .monospaced)).foregroundStyle(Color.konsensMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AssetRail: View {
    let assets: [AssetQuote]
    @Binding var selected: AssetQuote?
    let watched: Set<UUID>

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(assets) { asset in
                    Button { selected = asset } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 5) {
                                Image(systemName: asset.kind.lowercased().contains("crypto") ? "link" : "chart.line.uptrend.xyaxis")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(asset.kind.lowercased().contains("crypto") ? Color.konsensGreen : Color.konsensBlue)
                                Text(asset.symbol).font(.caption.monospaced().bold())
                                if watched.contains(asset.id) {
                                    Image(systemName: "star.fill").font(.system(size: 7)).foregroundStyle(Color.konsensBlue)
                                }
                            }
                            Text(asset.kind.uppercased())
                                .font(.system(size: 6, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.konsensMuted)
                            if asset.price > 0 {
                                Text(asset.price.formatted(.number.precision(.fractionLength(2))))
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(Color.white.opacity(0.86))
                            }
                        }
                        .frame(minWidth: 96, alignment: .leading)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 10)
                        .background(
                            selected?.id == asset.id ? Color.konsensBlue.opacity(0.10) : Color(red: 0.026, green: 0.050, blue: 0.065),
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(selected?.id == asset.id ? Color.konsensBlue.opacity(0.30) : Color.konsensBlue.opacity(0.08))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct FinanceCommandBar: View {
    @Binding var showWatchedOnly: Bool
    let assetCount: Int
    let watchedCount: Int
    let positionCount: Int
    let changed: () -> Void

    var body: some View {
        VStack(spacing: 9) {
            HStack(spacing: 5) {
                Button("TOUS") { showWatchedOnly = false; changed() }.financeFilter(active: !showWatchedOnly)
                Button("★ SUIVIS \(watchedCount)") { showWatchedOnly = true; changed() }.financeFilter(active: showWatchedOnly)
                Spacer()
                HStack(spacing: 4) {
                    Circle().fill(Color.konsensGreen).frame(width: 5, height: 5)
                    Text("LIVE").font(.system(size: 6, weight: .black, design: .monospaced)).foregroundStyle(Color.konsensBlue)
                }
            }
            HStack {
                commandMetric("\(assetCount)", "ACTIFS")
                Spacer()
                commandMetric("\(watchedCount)", "SUIVIS")
                Spacer()
                commandMetric("\(positionCount)", "POSITION")
            }
        }
        .padding(10)
        .background(Color(red: 0.022, green: 0.042, blue: 0.053), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.konsensBlue.opacity(0.10)))
    }

    private func commandMetric(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.caption.monospacedDigit().bold())
            Text(label).font(.system(size: 5, weight: .bold, design: .monospaced)).foregroundStyle(Color.konsensMuted)
        }
    }
}

private struct RangePicker: View {
    @Binding var range: String
    private let ranges = ["1d", "5d", "1mo", "6mo", "1y", "5y"]

    var body: some View {
        HStack(spacing: 5) {
            ForEach(ranges, id: \.self) { item in
                Button(item.uppercased()) { range = item }
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundStyle(range == item ? Color.konsensBackground : Color.konsensMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(range == item ? Color.konsensBlue : Color.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 5))
            }
        }
        .padding(5)
        .background(Color(red: 0.022, green: 0.041, blue: 0.052), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.konsensBlue.opacity(0.08)))
    }
}

private struct LiveAssetPanel: View {
    let asset: AssetQuote
    let quote: LiveMarketQuote?
    let positionQuantity: Double
    let positionAverage: Double
    let amount: Int
    let range: String
    let loading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Eyebrow(text: "\(asset.kind.uppercased()) · MARCHÉ CONNECTÉ")
                        if asset.kind.lowercased().contains("crypto") {
                            Text("24/7")
                                .font(.system(size: 6, weight: .black, design: .monospaced))
                                .foregroundStyle(Color.konsensGreen)
                        }
                    }
                    Text(asset.name).font(.title2.monospaced().bold())
                    Text(asset.symbol).font(.caption.monospaced()).foregroundStyle(Color.konsensMuted)
                }
                Spacer()
                if let quote {
                    VStack(alignment: .trailing, spacing: 3) {
                        Text("\(quote.price, specifier: quote.price >= 1000 ? "%.0f" : "%.2f") \(quote.currency)")
                            .font(.title2.monospacedDigit().bold())
                        Text(String(format: "%+.2f%%", quote.changePct))
                            .font(.caption.bold())
                            .foregroundStyle(quote.changePct >= 0 ? Color.konsensPositive : Color.konsensNegative)
                    }
                } else if loading {
                    ProgressView().tint(Color.konsensBlue)
                }
            }

            if let quote, quote.points.count > 1 {
                InteractiveMarketChart(quote: quote, range: range)
                MarketMetrics(quote: quote)
            } else if loading {
                VStack(spacing: 9) {
                    ProgressView().tint(Color.konsensBlue)
                    Text("Chargement de l’historique…").font(.caption2.monospaced()).foregroundStyle(Color.konsensMuted)
                }
                .frame(maxWidth: .infinity, minHeight: 180)
            }

            if let quote {
                HStack(spacing: 6) {
                    Circle().fill(Color.konsensGreen).frame(width: 5, height: 5)
                    Text(quote.provider.uppercased())
                        .font(.system(size: 6, weight: .black, design: .monospaced))
                        .foregroundStyle(asset.kind.lowercased().contains("crypto") ? Color.konsensGreen : Color.konsensBlue)
                    Spacer()
                    Text("MAJ \(shortDate(quote.updatedAt))")
                        .font(.system(size: 6, design: .monospaced))
                        .foregroundStyle(Color.konsensMuted)
                }
            }

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("POSITION KONSENS")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.konsensMuted)
                    Text(positionQuantity > 0 && quote != nil ? "\(positionQuantity * (quote?.price ?? 0), specifier: "%.0f") Koins" : "Aucune position")
                        .font(.headline.monospacedDigit())
                    if positionQuantity > 0 {
                        Text("\(positionQuantity, specifier: "%.4f") unités · PRU \(positionAverage, specifier: "%.2f")")
                            .font(.caption2.monospaced())
                            .foregroundStyle(Color.konsensMuted)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 3) {
                    Text("SIMULATION")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.konsensMuted)
                    Text("\(amount) Koins")
                        .font(.headline.monospacedDigit())
                    Text("Aucun ordre réel transmis")
                        .font(.caption2)
                        .foregroundStyle(Color.konsensMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .financePanel()
    }

    private func shortDate(_ value: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: value) else { return value }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}

private struct InteractiveMarketChart: View {
    let quote: LiveMarketQuote
    let range: String
    @State private var selectedDate: Date?

    private var selectedPoint: MarketPoint? {
        guard let selectedDate else { return nil }
        return quote.points.min { abs($0.time.timeIntervalSince(selectedDate)) < abs($1.time.timeIntervalSince(selectedDate)) }
    }

    private var lineColor: Color { quote.changePct >= 0 ? Color.konsensPositive : Color.konsensNegative }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedPoint == nil ? "ÉVOLUTION \(range.uppercased())" : "POINT SÉLECTIONNÉ")
                        .font(.system(size: 6, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.konsensMuted)
                    if let selectedPoint {
                        Text(selectedPoint.price.formatted(.number.precision(.fractionLength(selectedPoint.price >= 1000 ? 0 : 2))))
                            .font(.headline.monospacedDigit().bold())
                        Text(selectedPoint.time.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 7, design: .monospaced))
                            .foregroundStyle(Color.konsensMuted)
                    } else {
                        Text("Glisse sur la courbe pour lire un point")
                            .font(.caption2.monospaced())
                            .foregroundStyle(Color.konsensMuted)
                    }
                }
                Spacer()
                HStack(spacing: 5) {
                    Image(systemName: "hand.draw.fill").font(.system(size: 8))
                    Text("INTERACTIF").font(.system(size: 6, weight: .black, design: .monospaced))
                }
                .foregroundStyle(Color.konsensGreen)
            }

            Chart {
                ForEach(quote.points) { point in
                    AreaMark(
                        x: .value("Date", point.time),
                        yStart: .value("Base", baseline),
                        yEnd: .value("Cours", point.price)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [lineColor.opacity(0.20), lineColor.opacity(0.015)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(x: .value("Date", point.time), y: .value("Cours", point.price))
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                        .foregroundStyle(lineColor)
                }

                if let selectedPoint {
                    RuleMark(x: .value("Sélection", selectedPoint.time))
                        .foregroundStyle(Color.konsensGreen.opacity(0.52))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    PointMark(x: .value("Date", selectedPoint.time), y: .value("Cours", selectedPoint.price))
                        .symbolSize(58)
                        .foregroundStyle(Color.konsensGreen)
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine().foregroundStyle(Color.white.opacity(0.045))
                    AxisValueLabel {
                        if let number = value.as(Double.self) {
                            Text(number.formatted(.number.precision(.fractionLength(number >= 1000 ? 0 : 2))))
                                .font(.system(size: 6, design: .monospaced))
                                .foregroundStyle(Color.konsensMuted)
                        }
                    }
                }
            }
            .chartYScale(domain: yDomain)
            .chartXSelection(value: $selectedDate)
            .frame(height: 220)
        }
    }

    private var prices: [Double] { quote.points.map(\.price) }
    private var baseline: Double { prices.min() ?? 0 }
    private var yDomain: ClosedRange<Double> {
        let low = prices.min() ?? 0
        let high = prices.max() ?? 1
        let padding = max((high - low) * 0.12, max(high * 0.003, 0.01))
        return (low - padding)...(high + padding)
    }
}

private struct MarketMetrics: View {
    let quote: LiveMarketQuote

    var body: some View {
        HStack(spacing: 7) {
            metric("HAUT", high, Color.konsensPositive)
            metric("BAS", low, Color.konsensNegative)
            metric("AMPLITUDE", spreadText, Color.konsensBlue)
        }
    }

    private var high: String { format(quote.points.map(\.price).max() ?? quote.price) }
    private var low: String { format(quote.points.map(\.price).min() ?? quote.price) }
    private var spreadText: String {
        let values = quote.points.map(\.price)
        guard let high = values.max(), let low = values.min(), low > 0 else { return "—" }
        return String(format: "%.1f%%", ((high - low) / low) * 100)
    }

    private func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(value >= 1000 ? 0 : 2)))
    }

    private func metric(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 5, weight: .black, design: .monospaced)).foregroundStyle(Color.konsensMuted)
            Text(value).font(.caption2.monospacedDigit().bold()).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color.white.opacity(0.022), in: RoundedRectangle(cornerRadius: 6))
    }
}

private struct GainLossLesson: View {
    let quote: LiveMarketQuote?
    let amount: Int
    let range: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 7) {
                    Image(systemName: "graduationcap.fill").foregroundStyle(Color.konsensGreen)
                    Text("CE QUE LA COURBE T’APPREND")
                        .font(.system(size: 7, weight: .black, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(Color.konsensGreen)
                }
                Spacer()
                Text(range.uppercased()).font(.system(size: 6, weight: .black, design: .monospaced)).foregroundStyle(Color.konsensMuted)
            }

            if let quote, let first = quote.points.first?.price, first > 0 {
                let simulatedValue = Double(amount) * (quote.price / first)
                let delta = simulatedValue - Double(amount)
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Si tu avais investi \(amount) K au début")
                            .font(.caption.bold())
                        Text("tu aurais aujourd’hui \(simulatedValue, specifier: "%.1f") K")
                            .font(.headline.monospacedDigit().bold())
                    }
                    Spacer()
                    Text(String(format: "%@%.1f K", delta >= 0 ? "+" : "", delta))
                        .font(.headline.monospacedDigit().bold())
                        .foregroundStyle(delta >= 0 ? Color.konsensPositive : Color.konsensNegative)
                }
                Text(delta >= 0 ? "Cette période aurait été favorable. Une autre période peut produire l’inverse." : "Cette période aurait détruit une partie de tes Koins. La perte fait partie du risque d’investissement.")
                    .font(.caption2)
                    .foregroundStyle(Color.konsensMuted)
            } else {
                Text("Charge un historique pour comparer concrètement une décision gagnante ou perdante.")
                    .font(.caption2)
                    .foregroundStyle(Color.konsensMuted)
            }
        }
        .padding(13)
        .background(Color.konsensGreen.opacity(0.035), in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.konsensGreen.opacity(0.10)))
    }
}

private struct PremiumMarketsCard: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "crown.fill").foregroundStyle(Color.konsensViolet)
                Eyebrow(text: "PREMIUM · 4,99 € / MOIS")
            }
            Text(store.subscriptionTier == "premium" ? "Premium actif." : "Du cours à l’analyse.").font(.title3.bold())
            Text("Sans pub, historiques enrichis, suivi blockchain public et outils d’analyse avancés. Pendant la bêta, l’essai Premium est gratuit 14 jours ; aucun paiement n’est débité.")
                .font(.caption)
                .foregroundStyle(Color.konsensMuted)
            if store.subscriptionTier == "premium" {
                Label("Publicité supprimée", systemImage: "checkmark.seal.fill")
                    .font(.caption.bold())
                    .foregroundStyle(Color.konsensPositive)
            } else {
                Button { Task { await store.startPremiumTrial() } } label: {
                    Text("Activer 14 jours de Premium bêta").frame(maxWidth: .infinity).padding(12)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(Color.konsensViolet, in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color.konsensViolet.opacity(0.10), Color(red: 0.025, green: 0.045, blue: 0.058)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 12)
        )
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.konsensViolet.opacity(0.17)))
    }
}

private extension View {
    func financePanel() -> some View {
        self.padding(15)
            .background(Color(red: 0.025, green: 0.047, blue: 0.060), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.konsensBlue.opacity(0.10)))
    }

    func financeFilter(active: Bool) -> some View {
        self.font(.system(size: 7, weight: .bold, design: .monospaced))
            .foregroundStyle(active ? Color.konsensBackground : Color.konsensMuted)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(active ? Color.konsensBlue : Color.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 5))
    }
}
