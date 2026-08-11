import SwiftUI
import Charts

struct MarketsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var amount = 50
    @State private var selectedCategory = "Tous"
    @State private var selectedMarket: Market?
    @State private var topic = "finance économie technologie"
    @State private var candidates: [NewsCandidate] = []
    @State private var generating = false

    private var categories: [String] {
        ["Tous"] + Array(Set(store.markets.map(\.category))).sorted()
    }

    private var filteredMarkets: [Market] {
        store.markets
            .filter { selectedCategory == "Tous" || $0.category == selectedCategory }
            .sorted { heat($0) > heat($1) }
    }

    private var featured: [Market] {
        let tagged = store.markets.filter { $0.tags.contains("featured") }
        return Array((tagged.isEmpty ? store.markets : tagged).prefix(5))
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                PlayHero(credits: store.credits, markets: store.markets)

                if !featured.isEmpty {
                    sectionTitle("À LA UNE", "Les marchés à surveiller")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(featured) { market in
                                FeaturedPlayCard(market: market) { selectedMarket = market }
                            }
                        }
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        ForEach(categories, id: \.self) { category in
                            Button { selectedCategory = category } label: {
                                HStack(spacing: 6) {
                                    Text(categoryIcon(category))
                                    Text(category)
                                }
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(selectedCategory == category ? Color.white : Color.konsensMuted)
                                .padding(.horizontal, 12).padding(.vertical, 9)
                                .background(selectedCategory == category ? Color.konsensViolet.opacity(0.22) : Color.white.opacity(0.035), in: Capsule())
                                .overlay(Capsule().stroke(selectedCategory == category ? Color.konsensViolet.opacity(0.45) : Color.white.opacity(0.06)))
                            }.buttonStyle(.plain)
                        }
                    }
                }

                HStack {
                    sectionTitle("EXPLORE", selectedCategory == "Tous" ? "Tous les marchés" : selectedCategory)
                    Spacer()
                    Text("\(filteredMarkets.count)").font(.caption.monospacedDigit().bold()).foregroundStyle(Color.konsensMuted)
                }

                AmountPicker(amount: $amount, accent: Color.konsensViolet)

                if filteredMarkets.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "sparkles.rectangle.stack.fill").font(.largeTitle).foregroundStyle(Color.konsensViolet)
                        Text("Aucun marché dans cette catégorie").font(.headline)
                    }.frame(maxWidth: .infinity).padding(30).playPanel()
                } else {
                    ForEach(filteredMarkets) { market in
                        PlayMarketRow(market: market, amount: amount) { selectedMarket = market }
                    }
                }

                if store.role == "admin" {
                    NewsStudio(topic: $topic, candidates: $candidates, generating: $generating)
                }

                RiskFooter()
            }
            .padding(.horizontal, 18).padding(.top, 92).padding(.bottom, 110)
        }
        .refreshable { await store.refreshFinance() }
        .sheet(item: $selectedMarket) { market in
            PlayMarketDetail(market: market, amount: $amount)
                .environmentObject(store)
                .presentationDetents([.large])
                .presentationBackground(Color(red: 0.035, green: 0.027, blue: 0.075))
        }
    }

    private func sectionTitle(_ eyebrow: String, _ title: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(eyebrow).font(.system(size: 7, weight: .black, design: .rounded)).tracking(1.2).foregroundStyle(Color.konsensViolet)
            Text(title).font(.title3.bold())
        }
    }

    private func heat(_ market: Market) -> Int {
        (market.tags.contains("featured") ? 100000 : 0) + (market.tags.contains("trending") ? 50000 : 0) + Int(market.volumeKoins)
    }
}

private struct PlayHero: View {
    let credits: Int
    let markets: [Market]

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Circle().fill(Color.konsensGreen).frame(width: 6, height: 6).shadow(color: Color.konsensGreen, radius: 6)
                    Text("KONSENS PLAY · KOINS UNIQUEMENT").font(.system(size: 7, weight: .black, design: .rounded)).tracking(1.1).foregroundStyle(Color.konsensViolet)
                }
                Text("Et toi,\ntu mises sur quoi ?")
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .tracking(-1.4)
                Text("Actualité, sport, crypto, tech, économie. Les probabilités bougent avec les positions du marché Konsens.")
                    .font(.caption).foregroundStyle(Color.konsensMuted).lineSpacing(3)
                HStack(spacing: 7) {
                    heroStat("\(markets.count)", "marchés")
                    heroStat("\(credits)", "Koins")
                    heroStat("0 €", "réel")
                }
            }
            Spacer(minLength: 0)
            ZStack {
                Circle().stroke(Color.konsensViolet.opacity(0.28), lineWidth: 1)
                Circle().stroke(Color.konsensGreen.opacity(0.12), lineWidth: 1).padding(13)
                VStack(spacing: 1) {
                    Text("OUI").font(.system(size: 7, weight: .black)).foregroundStyle(Color.konsensMuted)
                    Text("?").font(.system(size: 42, weight: .black, design: .rounded)).foregroundStyle(LinearGradient(colors: [Color.konsensViolet, Color.konsensGreen], startPoint: .top, endPoint: .bottom))
                }
            }.frame(width: 104, height: 104)
        }
        .padding(18)
        .background(LinearGradient(colors: [Color.konsensViolet.opacity(0.15), Color.black.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.konsensViolet.opacity(0.18)))
    }

    private func heroStat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value).font(.caption.monospacedDigit().bold())
            Text(label.uppercased()).font(.system(size: 5, weight: .bold)).foregroundStyle(Color.konsensMuted)
        }.padding(.horizontal, 9).padding(.vertical, 7).background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 9))
    }
}

private struct FeaturedPlayCard: View {
    let market: Market
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("\(categoryIcon(market.category))  \(market.category.uppercased())").font(.system(size: 7, weight: .black)).foregroundStyle(Color.konsensMuted)
                    Spacer()
                    if market.tags.contains("trending") { Text("TENDANCE").font(.system(size: 6, weight: .black)).foregroundStyle(Color.konsensGreen).padding(5).background(Color.konsensGreen.opacity(0.08), in: Capsule()) }
                }
                Text(market.question).font(.system(size: 15, weight: .bold, design: .rounded)).lineLimit(3).multilineTextAlignment(.leading)
                Spacer(minLength: 4)
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("\(market.yesProbability)%").font(.system(size: 27, weight: .black, design: .rounded)).foregroundStyle(Color.white)
                        Text("OUI · x\(odd(market.yesProbability))").font(.system(size: 7, weight: .bold)).foregroundStyle(Color.konsensViolet)
                    }
                    Spacer()
                    Text("\(Int(market.volumeKoins)) K vol.").font(.system(size: 7)).foregroundStyle(Color.konsensMuted)
                }
            }
            .frame(width: 226, height: 158, alignment: .leading)
            .padding(15)
            .background(LinearGradient(colors: [Color.konsensViolet.opacity(0.13), Color.black.opacity(0.16)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.konsensViolet.opacity(0.20)))
        }.buttonStyle(.plain)
    }
}

private struct PlayMarketRow: View {
    @EnvironmentObject private var store: AppStore
    let market: Market
    let amount: Int
    let open: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: open) {
                VStack(alignment: .leading, spacing: 11) {
                    HStack(spacing: 9) {
                        Text(categoryIcon(market.category))
                            .font(.title3.bold()).frame(width: 38, height: 38)
                            .background(categoryColor(market.category).opacity(0.11), in: RoundedRectangle(cornerRadius: 11))
                            .foregroundStyle(categoryColor(market.category))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(market.category.uppercased()).font(.system(size: 7, weight: .black)).foregroundStyle(Color.konsensMuted)
                            Text(market.tags.contains("new") ? "NOUVEAU" : market.tags.contains("ending-soon") ? "FIN PROCHE" : market.tags.contains("trending") ? "TENDANCE" : "MARCHÉ OUVERT")
                                .font(.system(size: 6, weight: .bold)).foregroundStyle(Color.konsensViolet)
                        }
                        Spacer()
                        Text("\(market.yesProbability)%").font(.title3.monospacedDigit().bold())
                    }
                    Text(market.question).font(.headline).multilineTextAlignment(.leading)
                    GeometryReader { proxy in
                        HStack(spacing: 0) {
                            LinearGradient(colors: [Color.konsensViolet, Color.konsensGreen], startPoint: .leading, endPoint: .trailing)
                                .frame(width: proxy.size.width * CGFloat(market.yesProbability) / 100)
                            Color.white.opacity(0.07)
                        }.clipShape(Capsule())
                    }.frame(height: 5)
                    HStack {
                        Text("\(Int(market.volumeKoins)) K volume").font(.system(size: 7)).foregroundStyle(Color.konsensMuted)
                        Spacer()
                        Text(shortDate(market.closesAt)).font(.system(size: 7)).foregroundStyle(Color.konsensMuted)
                    }
                }
            }.buttonStyle(.plain)

            HStack(spacing: 7) {
                Button { Task { await store.bet(market, outcome: "yes", amount: amount) } } label: {
                    HStack { Text("OUI"); Spacer(); Text("\(market.yesProbability) K"); Text("x\(odd(market.yesProbability))").opacity(0.65) }
                        .font(.system(size: 8, weight: .black)).padding(11).background(Color.konsensPositive.opacity(0.09), in: RoundedRectangle(cornerRadius: 11))
                }.buttonStyle(.plain).foregroundStyle(Color.konsensPositive).disabled(store.credits < amount)
                Button { Task { await store.bet(market, outcome: "no", amount: amount) } } label: {
                    HStack { Text("NON"); Spacer(); Text("\(100-market.yesProbability) K"); Text("x\(odd(100-market.yesProbability))").opacity(0.65) }
                        .font(.system(size: 8, weight: .black)).padding(11).background(Color.konsensNegative.opacity(0.08), in: RoundedRectangle(cornerRadius: 11))
                }.buttonStyle(.plain).foregroundStyle(Color.konsensNegative).disabled(store.credits < amount)
            }
        }.playPanel()
    }
}

private struct PlayMarketDetail: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    let market: Market
    @Binding var amount: Int
    @State private var history: [ProbabilityPoint] = []
    @State private var yesQuantity = 0.0
    @State private var noQuantity = 0.0

    private var yesValue: Double { yesQuantity * Double(market.yesProbability) / 100 }
    private var noValue: Double { noQuantity * Double(100 - market.yesProbability) / 100 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("\(categoryIcon(market.category))  \(market.category.uppercased())").font(.system(size: 8, weight: .black)).foregroundStyle(Color.konsensViolet)
                    Spacer()
                    Button { dismiss() } label: { Image(systemName: "xmark").frame(width: 34, height: 34).background(Color.white.opacity(0.06), in: Circle()) }.buttonStyle(.plain)
                }
                Text(market.question).font(.system(size: 31, weight: .black, design: .rounded)).tracking(-1)
                HStack(alignment: .firstTextBaseline, spacing: 9) {
                    Text("\(market.yesProbability)%").font(.system(size: 48, weight: .black, design: .rounded))
                    VStack(alignment: .leading, spacing: 1) { Text("PROBABILITÉ OUI").font(.system(size: 7, weight: .black)).foregroundStyle(Color.konsensMuted); Text("Cote Koin x\(odd(market.yesProbability))").font(.caption.bold()).foregroundStyle(Color.konsensViolet) }
                }

                if history.count > 1 {
                    Chart(history) { point in
                        AreaMark(x: .value("Date", point.time), y: .value("Probabilité", point.probability)).foregroundStyle(LinearGradient(colors: [Color.konsensViolet.opacity(0.25), .clear], startPoint: .top, endPoint: .bottom))
                        LineMark(x: .value("Date", point.time), y: .value("Probabilité", point.probability)).interpolationMethod(.catmullRom).foregroundStyle(Color.konsensViolet).lineStyle(StrokeStyle(lineWidth: 2.5))
                    }.chartYScale(domain: 5...95).chartXAxis(.hidden).frame(height: 190)
                } else {
                    RoundedRectangle(cornerRadius: 2).fill(LinearGradient(colors: [Color.konsensViolet, Color.konsensGreen], startPoint: .leading, endPoint: .trailing)).frame(height: 5)
                }

                HStack(spacing: 7) {
                    detailMetric("VOLUME", "\(Int(market.volumeKoins)) K")
                    detailMetric("OUVERT", "\(Int(market.openInterestKoins)) K")
                    detailMetric("ÉCHÉANCE", shortDate(market.closesAt))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("COMMENT CE MARCHÉ EST RÉSOLU").font(.system(size: 7, weight: .black)).tracking(1).foregroundStyle(Color.konsensViolet)
                    Text(market.resolutionRules).font(.caption).foregroundStyle(Color.konsensMuted).lineSpacing(3)
                    if let rationale = market.aiRationale {
                        Text("ANALYSE INITIALE").font(.system(size: 7, weight: .black)).tracking(1).foregroundStyle(Color.konsensViolet).padding(.top, 4)
                        Text(rationale).font(.caption).foregroundStyle(Color.konsensMuted)
                    }
                    if !market.sourceURLs.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(Array(market.sourceURLs.enumerated()), id: \.offset) { index, raw in
                                    Button { if let url = URL(string: raw) { openURL(url) } } label: {
                                        Label(market.sourceTitles.indices.contains(index) ? String(market.sourceTitles[index].prefix(30)) : "Source", systemImage: "arrow.up.forward.square")
                                            .font(.system(size: 8, weight: .bold)).padding(9).background(Color.konsensBlue.opacity(0.08), in: Capsule())
                                    }.buttonStyle(.plain).foregroundStyle(Color.konsensBlue)
                                }
                            }
                        }
                    }
                }.playPanel()

                AmountPicker(amount: $amount, accent: Color.konsensViolet)

                HStack(spacing: 8) {
                    Button { Task { await store.bet(market, outcome: "yes", amount: amount); await load() } } label: { Text("Acheter OUI · \(amount) K").frame(maxWidth: .infinity).padding(13).background(Color.konsensPositive, in: RoundedRectangle(cornerRadius: 12)) }.buttonStyle(.plain).foregroundStyle(Color(red: 0.02, green: 0.08, blue: 0.06)).disabled(store.credits < amount)
                    Button { Task { await store.bet(market, outcome: "no", amount: amount); await load() } } label: { Text("Acheter NON · \(amount) K").frame(maxWidth: .infinity).padding(13).background(Color.konsensNegative, in: RoundedRectangle(cornerRadius: 12)) }.buttonStyle(.plain).foregroundStyle(Color.white).disabled(store.credits < amount)
                }.font(.caption.bold())

                HStack(spacing: 8) {
                    positionCard("OUI", value: yesValue) { Task { await store.sellBet(market, outcome: "yes", amount: amount); await load() } }
                    positionCard("NON", value: noValue) { Task { await store.sellBet(market, outcome: "no", amount: amount); await load() } }
                }
                Text("Les cotes traduisent uniquement le prix/probabilité du marché en Koins fictifs. Aucun argent réel, aucun cash-out.")
                    .font(.system(size: 8)).foregroundStyle(Color.konsensMuted)
            }.padding(20).padding(.bottom, 30)
        }.task { await load() }
    }

    private func detailMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) { Text(title).font(.system(size: 6, weight: .black)).foregroundStyle(Color.konsensMuted); Text(value).font(.caption.monospacedDigit().bold()) }
            .frame(maxWidth: .infinity, alignment: .leading).padding(10).background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))
    }

    private func positionCard(_ side: String, value: Double, sell: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("POSITION \(side)").font(.system(size: 6, weight: .black)).foregroundStyle(Color.konsensMuted)
            Text("\(Int(value)) K").font(.headline.monospacedDigit())
            Button("Revendre \(amount) K", action: sell).font(.system(size: 7, weight: .bold)).disabled(value < Double(amount)).opacity(value < Double(amount) ? 0.28 : 1)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(12).background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
    }

    private func load() async {
        struct HistoryRow: Decodable { let observed_at: String; let yes_probability: Double }
        if let rows: [HistoryRow] = try? await store.supabase.from("market_probability_history").select("observed_at,yes_probability").eq("market_id", value: market.id).order("observed_at").limit(120).execute().value {
            let formatter = ISO8601DateFormatter(); history = rows.compactMap { row in formatter.date(from: row.observed_at).map { ProbabilityPoint(time: $0, probability: row.yes_probability * 100) } }
        }
        guard let userID = store.supabase.auth.currentUser?.id else { return }
        struct Pos: Decodable { let side: String; let quantity: Double }
        let rows: [Pos] = (try? await store.supabase.from("positions").select("side,quantity").eq("user_id", value: userID).eq("market_id", value: market.id).execute().value) ?? []
        yesQuantity = rows.first(where: { $0.side == "yes" })?.quantity ?? 0
        noQuantity = rows.first(where: { $0.side == "no" })?.quantity ?? 0
    }
}

private struct ProbabilityPoint: Identifiable { let id = UUID(); let time: Date; let probability: Double }

private struct NewsCandidate: Identifiable, Decodable, Hashable {
    let id = UUID()
    let question: String
    let category: String
    let resolutionRules: String
    let closesAt: String
    let yesProbability: Double
    let confidence: Double
    let rationale: String
    let sourceSummary: String
    let sourceUrls: [String]
    let sourceTitles: [String]
    let suggestedStakeMin: Int
    let suggestedStakeMax: Int
    let tags: [String]
    enum CodingKeys: String, CodingKey { case question, category, resolutionRules, closesAt, yesProbability, confidence, rationale, sourceSummary, sourceUrls, sourceTitles, suggestedStakeMin, suggestedStakeMax, tags }
}

private struct NewsStudio: View {
    @EnvironmentObject private var store: AppStore
    @Binding var topic: String
    @Binding var candidates: [NewsCandidate]
    @Binding var generating: Bool
    @State private var status = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Image(systemName: "sparkles").foregroundStyle(Color.konsensViolet); Eyebrow(text: "AI MARKET STUDIO · ADMIN") }
            Text("Créer de nouveaux marchés depuis l’actualité").font(.title3.bold())
            Text("Le moteur GDELT propose des candidats sourcés. Rien n’est publié sans validation admin.").font(.caption).foregroundStyle(Color.konsensMuted)
            TextField("IA, sport, crypto, énergie…", text: $topic).textFieldStyle(.plain).padding(12).background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
            Button { Task { await generate() } } label: { Label(generating ? "Analyse…" : "Créer des candidats", systemImage: "newspaper.fill").frame(maxWidth: .infinity).padding(12) }
                .buttonStyle(.plain).foregroundStyle(.white).background(Color.konsensViolet, in: RoundedRectangle(cornerRadius: 13)).disabled(generating)
            if !status.isEmpty { Text(status).font(.caption2).foregroundStyle(Color.konsensMuted) }
            ForEach(candidates) { candidate in
                VStack(alignment: .leading, spacing: 8) {
                    HStack { Text(candidate.category.uppercased()).font(.system(size: 7, weight: .black)).foregroundStyle(Color.konsensGreen); Spacer(); Text("confiance \(Int(candidate.confidence * 100))%").font(.caption2).foregroundStyle(Color.konsensMuted) }
                    Text(candidate.question).font(.subheadline.bold())
                    Text(candidate.rationale).font(.caption2).foregroundStyle(Color.konsensMuted)
                    HStack { Text("\(Int(candidate.yesProbability * 100))% OUI").font(.headline.monospacedDigit()).foregroundStyle(Color.konsensGreen); Spacer(); Button("Publier") { Task { await publish(candidate) } }.font(.caption.bold()) }
                }.padding(14).background(Color.black.opacity(0.14), in: RoundedRectangle(cornerRadius: 15))
            }
        }.padding(18).background(LinearGradient(colors: [Color.konsensViolet.opacity(0.13), Color.black.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 22)).overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.konsensViolet.opacity(0.2)))
    }

    private func generate() async {
        generating = true; candidates = []; status = "Lecture de l’actualité…"
        guard var components = URLComponents(string: "https://mxuevsspybxoovsutsbs.supabase.co/functions/v1/news-markets") else { generating = false; return }
        components.queryItems = [URLQueryItem(name: "topic", value: topic)]
        guard let url = components.url else { generating = false; return }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(store.supabase.auth.currentSession?.accessToken ?? "")", forHTTPHeaderField: "Authorization")
        request.setValue("sb_publishable_Xs7hyyDA2XUkbwXGGfSE2w_tARkgSL7", forHTTPHeaderField: "apikey")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
            struct Statistics: Decodable { let articles24h: Int; let sources24h: Int }
            struct Envelope: Decodable { let statistics: Statistics; let candidates: [NewsCandidate] }
            let decoded = try JSONDecoder().decode(Envelope.self, from: data)
            candidates = decoded.candidates
            status = "\(decoded.statistics.articles24h) articles · \(decoded.statistics.sources24h) sources"
        } catch { status = "Actualité indisponible : \(error.localizedDescription)" }
        generating = false
    }

    private func publish(_ candidate: NewsCandidate) async {
        struct Params: Encodable {
            let p_question: String; let p_category: String; let p_resolution_rules: String; let p_closes_at: String; let p_yes_probability: Double
            let p_source_urls: [String]; let p_source_titles: [String]; let p_source_summary: String; let p_ai_confidence: Double; let p_ai_rationale: String
            let p_suggested_stake_min: Int; let p_suggested_stake_max: Int; let p_tags: [String]
        }
        let params = Params(p_question: candidate.question, p_category: candidate.category, p_resolution_rules: candidate.resolutionRules, p_closes_at: candidate.closesAt, p_yes_probability: candidate.yesProbability, p_source_urls: candidate.sourceUrls, p_source_titles: candidate.sourceTitles, p_source_summary: candidate.sourceSummary, p_ai_confidence: candidate.confidence, p_ai_rationale: candidate.rationale, p_suggested_stake_min: candidate.suggestedStakeMin, p_suggested_stake_max: candidate.suggestedStakeMax, p_tags: candidate.tags)
        do {
            _ = try await store.supabase.rpc("publish_ai_market", params: params).execute()
            candidates.removeAll { $0.id == candidate.id }
            store.showToast("Marché publié")
            await store.refreshFinance()
        } catch { store.showToast("Publication refusée") }
    }
}

struct AmountPicker: View {
    @Binding var amount: Int
    var accent: Color = Color.konsensGreen
    var body: some View {
        HStack(spacing: 7) {
            ForEach([25,50,100,250], id: \.self) { value in
                Button("\(value)") { amount = value }
                    .font(.caption.bold())
                    .foregroundStyle(amount == value ? Color.konsensBackground : Color.konsensMuted)
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .background(amount == value ? accent : Color.clear, in: RoundedRectangle(cornerRadius: 10))
            }
            Spacer(); Text("Koins").font(.caption2).foregroundStyle(Color.konsensMuted)
        }.padding(7).background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 15)).overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.white.opacity(0.07)))
    }
}

struct RiskFooter: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.shield.fill").foregroundStyle(Color.konsensGold)
            Text("Risque visible, argent fictif. Les Koins ne sont ni achetables, ni convertibles, ni retirable en argent.")
                .font(.system(size: 9)).foregroundStyle(Color.konsensMuted)
        }.padding(14).background(Color.konsensGold.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
    }
}

private extension View {
    func playPanel() -> some View {
        self.padding(15)
            .background(LinearGradient(colors: [Color.konsensViolet.opacity(0.07), Color.black.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.konsensViolet.opacity(0.12)))
    }
}

private func categoryIcon(_ category: String) -> String {
    switch category { case "Crypto": "₿"; case "Économie": "↕"; case "Finance": "⌁"; case "Sport": "●"; case "Climat": "☼"; case "Énergie": "ϟ"; case "IA": "✦"; case "Tech": "◇"; case "Marchés": "▥"; case "Tous": "◎"; default: "•" }
}

private func categoryColor(_ category: String) -> Color {
    switch category { case "Sport": Color.konsensGreen; case "Économie", "Tech": Color.konsensBlue; case "Climat", "Énergie": Color.konsensGold; case "Crypto", "IA": Color.konsensViolet; default: Color.konsensGreen }
}

private func odd(_ probability: Int) -> String {
    String(format: "%.2f", 100 / Double(max(2, min(98, probability))))
}

private func shortDate(_ raw: String) -> String {
    let formatter = ISO8601DateFormatter()
    guard let date = formatter.date(from: raw) else { return raw }
    return date.formatted(date: .abbreviated, time: .omitted)
}
