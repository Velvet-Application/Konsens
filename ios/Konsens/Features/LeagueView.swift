import SwiftUI
import Charts
import WidgetKit

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
    @State private var chainPulse: OnChainPulse?
    @State private var loadingChain = false
    @State private var chainStatus = "Lecture du réseau public…"

    private var visibleAssets: [AssetQuote] {
        showWatchedOnly ? store.assets.filter { store.watchedAssetIDs.contains($0.id) } : store.assets
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                FinanceHero(wealth: store.wealth.total, credits: store.credits)

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

                assetRail

                if let asset = selected {
                    HStack {
                        Text("ACTIF SÉLECTIONNÉ")
                            .font(.system(size: 7, weight: .black, design: .monospaced))
                            .tracking(1).foregroundStyle(Color.konsensBlue)
                        Spacer()
                        Button { Task { await store.toggleAssetWatch(asset) } } label: {
                            Label(
                                store.watchedAssetIDs.contains(asset.id) ? "Suivi" : "Suivre",
                                systemImage: store.watchedAssetIDs.contains(asset.id) ? "star.fill" : "star"
                            )
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 10).padding(.vertical, 7)
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
                        loading: loadingQuote
                    )

                    rangeSelector

                    OnChainPulsePanel(pulse: chainPulse, loading: loadingChain, status: chainStatus) {
                        Task { await refreshOnChain() }
                    }

                    LearningRiskBridge(quote: quote)

                    AmountPicker(amount: $amount, accent: Color.konsensBlue)
                    HStack(spacing: 8) {
                        Button {
                            Task {
                                await store.buyAsset(asset, amount: amount)
                                await refreshPosition(asset)
                                await refreshQuote(asset)
                            }
                        } label: {
                            Label("Acheter \(amount) K", systemImage: "plus.circle.fill")
                                .frame(maxWidth: .infinity).padding(13)
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
                                .frame(maxWidth: .infinity).padding(13)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.konsensNegative)
                        .background(Color.konsensNegative.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                        .disabled(positionValue < Double(amount))
                        .opacity(positionValue < Double(amount) ? 0.35 : 1)
                    }
                } else if !showWatchedOnly {
                    ContentUnavailableView(
                        "Marché en préparation",
                        systemImage: "chart.xyaxis.line",
                        description: Text("Les actifs connectés apparaîtront ici.")
                    ).financePanel()
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Capsule().fill(Color.konsensGreen).frame(width: 34, height: 3)
                        Text("LA LIGNE VERTE")
                            .font(.system(size: 7, weight: .black, design: .monospaced))
                            .tracking(1).foregroundStyle(Color.konsensGreen)
                    }
                    Text("Un bon investissement commence avant l’achat.")
                        .font(.headline.monospaced())
                    Text("Lis le cours, observe le risque, vérifie ce qui est réellement visible sur la chaîne puis engage seulement des Koins fictifs. Tu peux gagner, mais aussi perdre : c’est précisément ce que Konsens t’apprend à mesurer.")
                        .font(.caption).foregroundStyle(Color.konsensMuted).lineSpacing(3)
                }.financePanel()

                PremiumMarketsCard()
                RiskFooter()
            }
            .padding(.horizontal, 18).padding(.top, 92).padding(.bottom, 110)
        }
        .task {
            if selected == nil { selected = store.assets.first }
            await refreshOnChain()
        }
        .task(id: selected?.id) {
            if let asset = selected {
                await refreshQuote(asset)
                await refreshPosition(asset)
            }
        }
        .task(id: range) {
            if let asset = selected { await refreshQuote(asset) }
        }
        .refreshable {
            await store.refreshFinance()
            if let asset = selected {
                await refreshQuote(asset)
                await refreshPosition(asset)
            }
            await refreshOnChain()
        }
    }

    private var assetRail: some View {
        Group {
            if showWatchedOnly && visibleAssets.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "star").font(.largeTitle).foregroundStyle(Color.konsensBlue)
                    Text("Aucun marché suivi").font(.headline.monospaced())
                    Text("Ajoute un actif à tes suivis. Il remontera ici et dans ton widget Finance.")
                        .font(.caption).multilineTextAlignment(.center).foregroundStyle(Color.konsensMuted)
                    Button("Explorer les marchés") { showWatchedOnly = false }
                        .font(.caption.bold()).foregroundStyle(Color.konsensBlue)
                }
                .frame(maxWidth: .infinity).padding(28).financePanel()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        ForEach(visibleAssets) { asset in
                            Button { selected = asset } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 5) {
                                        Text(asset.symbol).font(.caption.monospaced().bold())
                                        if store.watchedAssetIDs.contains(asset.id) {
                                            Image(systemName: "star.fill").font(.system(size: 7)).foregroundStyle(Color.konsensBlue)
                                        }
                                    }
                                    Text(asset.kind.uppercased())
                                        .font(.system(size: 6, weight: .bold)).foregroundStyle(Color.konsensMuted)
                                }
                                .padding(.horizontal, 13).padding(.vertical, 10)
                                .background(selected?.id == asset.id ? Color.konsensBlue.opacity(0.10) : Color(red: 0.026, green: 0.050, blue: 0.065), in: RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(selected?.id == asset.id ? Color.konsensBlue.opacity(0.30) : Color.konsensBlue.opacity(0.08)))
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var rangeSelector: some View {
        HStack(spacing: 5) {
            ForEach(["1d", "5d", "1mo", "6mo", "1y", "5y"], id: \.self) { item in
                Button(item.uppercased()) { range = item }
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundStyle(range == item ? Color.konsensBackground : Color.konsensMuted)
                    .padding(.horizontal, 9).padding(.vertical, 7)
                    .background(range == item ? Color.konsensBlue : Color.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 5))
            }
        }
    }

    private var positionValue: Double {
        guard let quote else { return 0 }
        return positionQuantity * quote.price
    }

    private func refreshQuote(_ asset: AssetQuote) async {
        loadingQuote = true
        quote = await store.liveQuote(for: asset, range: range)
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
            .single().execute().value {
            positionQuantity = row.quantity
            positionAverage = row.average_price
        } else {
            positionQuantity = 0
            positionAverage = 0
        }
    }

    private func refreshOnChain() async {
        guard !loadingChain else { return }
        loadingChain = true
        chainStatus = "Lecture du réseau Ethereum public…"
        defer { loadingChain = false }

        struct Limit: Encodable { let p_limit: Int }
        struct Whale: Decodable {
            let id: UUID
            let address: String
            let display_name: String
            let wallet_kind: String
            let confidence_score: Int
        }

        let whales: [Whale] = (try? await store.supabase
            .rpc("get_whale_leaderboard", params: Limit(p_limit: 12))
            .execute().value) ?? []

        guard let whale = whales.first(where: { ["exchange", "institution", "bridge"].contains($0.wallet_kind) }) ?? whales.first else {
            chainPulse = nil
            chainStatus = "Aucune adresse publique disponible."
            return
        }
        guard var components = URLComponents(string: "https://mxuevsspybxoovsutsbs.supabase.co/functions/v1/blockchain-data") else { return }
        components.queryItems = [
            URLQueryItem(name: "wallet_id", value: whale.id.uuidString),
            URLQueryItem(name: "address", value: whale.address)
        ]
        guard let url = components.url, let token = store.supabase.auth.currentSession?.accessToken else {
            chainStatus = "Reconnecte-toi pour lire le flux blockchain."
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("sb_publishable_Xs7hyyDA2XUkbwXGGfSE2w_tARkgSL7", forHTTPHeaderField: "apikey")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
            let envelope = try JSONDecoder().decode(ChainEnvelope.self, from: data)
            let formatter = ISO8601DateFormatter()
            let points = envelope.transactions.prefix(30).compactMap { tx -> OnChainPoint? in
                guard let date = formatter.date(from: tx.blockTime) else { return nil }
                let value = abs(tx.estimatedValueEUR ?? 0)
                return OnChainPoint(
                    id: tx.providerEventId,
                    time: date,
                    valueEUR: value,
                    direction: tx.direction,
                    assetSymbol: tx.assetSymbol
                )
            }.sorted { $0.time < $1.time }

            chainPulse = OnChainPulse(
                walletName: whale.display_name,
                walletKind: whale.wallet_kind,
                confidence: whale.confidence_score,
                provider: envelope.provider,
                points: points
            )
            chainStatus = points.isEmpty ? "Flux public synchronisé, sans valeur EUR exploitable sur les dernières transactions." : "Flux public synchronisé."

            if let defaults = UserDefaults(suiteName: "group.com.konsens.beta") {
                defaults.set(whale.display_name, forKey: "konsens_widget_chain_wallet")
                defaults.set(envelope.provider, forKey: "konsens_widget_chain_provider")
                defaults.set(points.reduce(0) { $0 + ($1.direction == "in" ? $1.valueEUR : -$1.valueEUR) }, forKey: "konsens_widget_chain_flow")
                WidgetCenter.shared.reloadAllTimelines()
            }
        } catch {
            chainPulse = nil
            chainStatus = "Le flux blockchain est momentanément indisponible."
        }
    }
}

private struct FinanceHero: View {
    let wealth: Double
    let credits: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Rectangle().fill(Color.konsensGreen).frame(width: 34, height: 3)
                    Text("UNIVERS INVESTIR")
                        .font(.system(size: 7, weight: .black, design: .monospaced))
                        .tracking(1.1).foregroundStyle(Color.konsensGreen)
                }
                Spacer()
                Text("MARKET + ON-CHAIN")
                    .font(.system(size: 6, weight: .black, design: .monospaced))
                    .foregroundStyle(Color.konsensBlue)
            }
            Text("Décider avec\ndes données, pas avec l’instinct.")
                .font(.system(size: 35, weight: .bold, design: .monospaced))
                .tracking(-1.4)
            Text("Cours réels comme référence, historique interactif, transparence blockchain et portefeuille en Koins fictifs. Le rendement potentiel est visible ; le risque de perte l’est aussi.")
                .font(.subheadline).foregroundStyle(Color.konsensMuted).lineSpacing(3)
            HStack(spacing: 8) {
                financeHeroMetric("\(Int(wealth.rounded())) K", "PATRIMOINE")
                financeHeroMetric("\(credits) K", "DISPONIBLE")
                financeHeroMetric("0 €", "ARGENT RÉEL")
            }
        }
        .padding(18)
        .background(Color(red: 0.019, green: 0.038, blue: 0.049), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.konsensBlue.opacity(0.13)))
    }

    private func financeHeroMetric(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.caption.monospacedDigit().bold())
            Text(label).font(.system(size: 5, weight: .bold, design: .monospaced)).foregroundStyle(Color.konsensMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(9)
        .background(Color.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 6))
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
                    Circle().fill(Color.konsensPositive).frame(width: 5, height: 5)
                    Text("LIVE").font(.system(size: 6, weight: .black, design: .monospaced)).foregroundStyle(Color.konsensBlue)
                }
            }
            HStack {
                commandMetric("\(assetCount)", "ACTIFS")
                Spacer()
                commandMetric("\(watchedCount)", "SUIVIS")
                Spacer()
                commandMetric("\(positionCount)", "POSITIONS")
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

private struct LiveAssetPanel: View {
    let asset: AssetQuote
    let quote: LiveMarketQuote?
    let positionQuantity: Double
    let positionAverage: Double
    let loading: Bool
    @State private var selectedDate: Date?

    private var selectedPoint: MarketPoint? {
        guard let selectedDate, let quote else { return nil }
        return quote.points.min { abs($0.time.timeIntervalSince(selectedDate)) < abs($1.time.timeIntervalSince(selectedDate)) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(asset.kind.uppercased()) · MARCHÉ CONNECTÉ")
                        .font(.system(size: 7, weight: .black, design: .monospaced))
                        .tracking(1).foregroundStyle(Color.konsensBlue)
                    Text(asset.name).font(.title2.monospaced().bold())
                    Text(asset.symbol).font(.caption.monospaced()).foregroundStyle(Color.konsensMuted)
                }
                Spacer()
                if let quote {
                    VStack(alignment: .trailing, spacing: 3) {
                        Text("\(quote.price, specifier: "%.2f") \(quote.currency)").font(.title2.monospacedDigit().bold())
                        Text(String(format: "%+.2f%%", quote.changePct))
                            .font(.caption.bold())
                            .foregroundStyle(quote.changePct >= 0 ? Color.konsensPositive : Color.konsensNegative)
                    }
                } else if loading {
                    ProgressView().tint(Color.konsensBlue)
                }
            }

            if let quote, quote.points.count > 1 {
                Chart {
                    ForEach(quote.points) { point in
                        LineMark(x: .value("Date", point.time), y: .value("Cours", point.price))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(quote.changePct >= 0 ? Color.konsensBlue : Color.konsensNegative)
                        AreaMark(x: .value("Date", point.time), y: .value("Cours", point.price))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [(quote.changePct >= 0 ? Color.konsensBlue : Color.konsensNegative).opacity(0.16), Color.clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                    if let selectedPoint {
                        RuleMark(x: .value("Sélection", selectedPoint.time))
                            .foregroundStyle(Color.konsensGreen.opacity(0.75))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        PointMark(x: .value("Date", selectedPoint.time), y: .value("Cours", selectedPoint.price))
                            .symbolSize(38).foregroundStyle(Color.konsensGreen)
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .chartXSelection(value: $selectedDate)
                .frame(height: 210)

                HStack {
                    if let selectedPoint {
                        Text("\(selectedPoint.time.formatted(date: .abbreviated, time: .shortened)) · \(selectedPoint.price, specifier: "%.2f") \(quote.currency)")
                            .foregroundStyle(Color.konsensGreen)
                    } else {
                        Text("Glisse sur le graphique pour lire un point de cours")
                    }
                    Spacer()
                    Text(quote.provider)
                }
                .font(.system(size: 7, design: .monospaced))
                .foregroundStyle(Color.konsensMuted)
            }

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("POSITION KONSENS").font(.system(size: 7, weight: .bold, design: .monospaced)).foregroundStyle(Color.konsensMuted)
                    Text(positionQuantity > 0 && quote != nil ? "\(positionQuantity * (quote?.price ?? 0), specifier: "%.0f") Koins" : "Aucune position")
                        .font(.headline.monospacedDigit())
                    if positionQuantity > 0 {
                        Text("\(positionQuantity, specifier: "%.4f") unités · PRU \(positionAverage, specifier: "%.2f")")
                            .font(.caption2.monospaced()).foregroundStyle(Color.konsensMuted)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: 3) {
                    Text("SOURCE").font(.system(size: 7, weight: .bold, design: .monospaced)).foregroundStyle(Color.konsensMuted)
                    Text(quote?.exchange.isEmpty == false ? quote!.exchange : "Marché externe").font(.caption.bold())
                    Text("Aucun ordre réel transmis").font(.caption2).foregroundStyle(Color.konsensMuted)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }.financePanel()
    }
}

private struct OnChainPulsePanel: View {
    let pulse: OnChainPulse?
    let loading: Bool
    let status: String
    let refresh: () -> Void

    private var inflow: Double {
        pulse?.points.filter { $0.direction == "in" }.reduce(0) { $0 + $1.valueEUR } ?? 0
    }
    private var outflow: Double {
        pulse?.points.filter { $0.direction != "in" }.reduce(0) { $0 + $1.valueEUR } ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("BLOCKCHAIN PULSE · ETHEREUM")
                        .font(.system(size: 7, weight: .black, design: .monospaced))
                        .tracking(1).foregroundStyle(Color.konsensGreen)
                    Text("Flux public vérifiable").font(.headline.monospaced())
                }
                Spacer()
                Button(action: refresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption.bold()).frame(width: 32, height: 32)
                        .background(Color.konsensGreen.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain).foregroundStyle(Color.konsensGreen).disabled(loading)
            }

            if loading {
                ProgressView("Synchronisation on-chain…").tint(Color.konsensGreen)
            } else if let pulse, !pulse.points.isEmpty {
                HStack(spacing: 8) {
                    chainMetric("ENTRÉES", inflow, Color.konsensPositive)
                    chainMetric("SORTIES", outflow, Color.konsensNegative)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("SOURCE").font(.system(size: 6, weight: .black, design: .monospaced)).foregroundStyle(Color.konsensMuted)
                        Text(pulse.provider).font(.system(size: 8, weight: .bold, design: .monospaced)).lineLimit(1)
                        Text("attrib. \(pulse.confidence)%").font(.system(size: 6, design: .monospaced)).foregroundStyle(Color.konsensMuted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).padding(9)
                    .background(Color.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 6))
                }

                Chart(pulse.points) { point in
                    BarMark(
                        x: .value("Temps", point.time),
                        y: .value("Valeur EUR", max(point.valueEUR, 1))
                    )
                    .foregroundStyle(point.direction == "in" ? Color.konsensPositive.opacity(0.75) : Color.konsensNegative.opacity(0.75))
                }
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine().foregroundStyle(Color.white.opacity(0.04))
                        AxisValueLabel {
                            if let amount = value.as(Double.self) {
                                Text(amount.formatted(.number.notation(.compactName)))
                                    .font(.system(size: 6, design: .monospaced))
                            }
                        }
                    }
                }
                .frame(height: 155)

                HStack {
                    Text("\(pulse.walletName) · \(pulse.walletKind.uppercased())")
                    Spacer()
                    Text("VERT = ENTRÉE · ROUGE = SORTIE")
                }
                .font(.system(size: 6, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.konsensMuted)
            } else {
                Text(status).font(.caption).foregroundStyle(Color.konsensMuted)
            }

            Text("Ce graphique vient d’adresses publiques attribuées et de transactions de chaîne. Il apporte de la transparence, pas une promesse de performance.")
                .font(.system(size: 8)).foregroundStyle(Color.konsensMuted).lineSpacing(2)
        }.financePanel()
    }

    private func chainMetric(_ label: String, _ value: Double, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 6, weight: .black, design: .monospaced)).foregroundStyle(Color.konsensMuted)
            Text(value.formatted(.currency(code: "EUR").notation(.compactName).precision(.fractionLength(0))))
                .font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(9)
        .background(Color.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 6))
    }
}

private struct LearningRiskBridge: View {
    let quote: LiveMarketQuote?

    private var drawdown: Double {
        guard let quote, let peak = quote.points.map(\.price).max(), peak > 0 else { return 0 }
        return ((quote.price - peak) / peak) * 100
    }

    private var reboundNeeded: Double {
        guard drawdown < 0 else { return 0 }
        let remaining = 1 + drawdown / 100
        guard remaining > 0 else { return 100 }
        return (1 / remaining - 1) * 100
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "graduationcap.fill")
                .foregroundStyle(Color.konsensGreen)
                .frame(width: 36, height: 36)
                .background(Color.konsensGreen.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 4) {
                Text("APPRENDRE DE LA COURBE")
                    .font(.system(size: 7, weight: .black, design: .monospaced)).tracking(1).foregroundStyle(Color.konsensGreen)
                if drawdown < -0.5 {
                    Text("Depuis le plus haut de la période : \(drawdown, specifier: "%.1f")%. Pour revenir à ce sommet, il faudrait environ +\(reboundNeeded, specifier: "%.1f")%.")
                        .font(.caption).foregroundStyle(Color.konsensMuted)
                } else {
                    Text("Une hausse passée ne garantit pas la suivante. Compare toujours le potentiel de gain au montant que tu peux perdre.")
                        .font(.caption).foregroundStyle(Color.konsensMuted)
                }
            }
        }
        .padding(13)
        .background(Color.konsensGreen.opacity(0.045), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.konsensGreen.opacity(0.12)))
    }
}

private struct PremiumMarketsCard: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Image(systemName: "crown.fill").foregroundStyle(Color.konsensViolet); Eyebrow(text: "PREMIUM · 4,99 € / MOIS") }
            Text(store.subscriptionTier == "premium" ? "Premium actif." : "Du cours à l’analyse.").font(.title3.bold())
            Text("Sans pub, historiques enrichis, suivi blockchain public et outils d’analyse avancés. Pendant la bêta, l’essai Premium est gratuit 14 jours ; aucun paiement n’est débité.")
                .font(.caption).foregroundStyle(Color.konsensMuted)
            if store.subscriptionTier == "premium" {
                Label("Publicité supprimée", systemImage: "checkmark.seal.fill").font(.caption.bold()).foregroundStyle(Color.konsensPositive)
            } else {
                Button { Task { await store.startPremiumTrial() } } label: {
                    Text("Activer 14 jours de Premium bêta").frame(maxWidth: .infinity).padding(12)
                }
                .buttonStyle(.plain).foregroundStyle(.white)
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

private struct OnChainPoint: Identifiable, Hashable {
    let id: String
    let time: Date
    let valueEUR: Double
    let direction: String
    let assetSymbol: String
}

private struct OnChainPulse: Hashable {
    let walletName: String
    let walletKind: String
    let confidence: Int
    let provider: String
    let points: [OnChainPoint]
}

private struct ChainEnvelope: Decodable {
    let provider: String
    let transactions: [ChainTransaction]
}

private struct ChainTransaction: Decodable {
    let providerEventId: String
    let direction: String
    let assetSymbol: String
    let estimatedValueEUR: Double?
    let blockTime: String
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
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(active ? Color.konsensBlue : Color.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 5))
    }
}