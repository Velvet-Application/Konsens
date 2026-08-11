import SwiftUI
import Charts

struct MarketsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var amount = 50
    @State private var topic = "finance économie technologie"
    @State private var candidates: [NewsCandidate] = []
    @State private var generating = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                Eyebrow(text: "KONSENS PREDICTION MARKET")
                Text("L’actualité devient\nun marché mesurable.")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                Text("Probabilité, sources, historique, volume, achat et revente sont visibles. Solde : \(store.credits.formatted()) Koins.")
                    .font(.subheadline).foregroundStyle(Color.konsensMuted)

                if store.role == "admin" {
                    NewsStudio(topic: $topic, candidates: $candidates, generating: $generating)
                }

                AmountPicker(amount: $amount)
                if store.markets.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "sparkles.rectangle.stack.fill").font(.largeTitle).foregroundStyle(Color.konsensViolet)
                        Text("Aucun marché ouvert").font(.headline)
                        Text(store.role == "admin" ? "Utilise le studio d’actualité ci-dessus pour créer un premier candidat vérifiable." : "Les prochains marchés apparaîtront après validation de leurs sources et règles de résolution.")
                            .font(.caption).foregroundStyle(Color.konsensMuted).multilineTextAlignment(.center)
                    }.frame(maxWidth: .infinity).padding(30).panel()
                } else {
                    ForEach(store.markets) { market in DynamicMarketCard(market: market, amount: amount) }
                }
                RiskFooter()
            }
            .padding(.horizontal, 18).padding(.top, 92).padding(.bottom, 110)
        }
        .refreshable { await store.refreshFinance() }
    }
}

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
            Text("Générer depuis l’actualité").font(.title3.bold())
            Text("Le flux GDELT fonctionne déjà. Le modèle Workers AI prend le relais dès que le Worker Cloudflare dispose de son jeton de déploiement.")
                .font(.caption).foregroundStyle(Color.konsensMuted)
            TextField("Sujet", text: $topic).textFieldStyle(.plain).padding(12).background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
            Button { Task { await generate() } } label: {
                Label(generating ? "Analyse…" : "Analyser les dernières 24 h", systemImage: "newspaper.fill").frame(maxWidth: .infinity).padding(12)
            }.buttonStyle(.plain).foregroundStyle(.white).background(Color.konsensViolet, in: RoundedRectangle(cornerRadius: 13)).disabled(generating)
            if !status.isEmpty { Text(status).font(.caption2).foregroundStyle(Color.konsensMuted) }
            ForEach(candidates) { candidate in
                VStack(alignment: .leading, spacing: 8) {
                    HStack { Text(candidate.category.uppercased()).font(.system(size: 7, weight: .bold)).foregroundStyle(Color.konsensGreen); Spacer(); Text("confiance \(Int(candidate.confidence * 100))%").font(.caption2).foregroundStyle(Color.konsensMuted) }
                    Text(candidate.question).font(.subheadline.bold())
                    Text(candidate.rationale).font(.caption2).foregroundStyle(Color.konsensMuted)
                    HStack { Text("\(Int(candidate.yesProbability * 100))% OUI").font(.headline.monospacedDigit()).foregroundStyle(Color.konsensGreen); Spacer(); Text("\(candidate.suggestedStakeMin)–\(candidate.suggestedStakeMax) K").font(.caption.bold()).foregroundStyle(Color.konsensGold) }
                    Button("Publier ce marché") { Task { await publish(candidate) } }
                        .font(.caption.bold()).foregroundStyle(Color.konsensBackground).frame(maxWidth: .infinity).padding(10).background(Color.konsensGreen, in: RoundedRectangle(cornerRadius: 11))
                }.padding(14).background(Color.black.opacity(0.14), in: RoundedRectangle(cornerRadius: 15))
            }
        }.padding(18).background(LinearGradient(colors: [Color.konsensViolet.opacity(0.12), Color.konsensPanel], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 22)).overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.konsensViolet.opacity(0.2)))
    }

    private func generate() async {
        generating = true; candidates = []; status = "Lecture de l’actualité GDELT…"
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
            struct Envelope: Decodable { let mode: String; let statistics: Statistics; let candidates: [NewsCandidate] }
            let decoded = try JSONDecoder().decode(Envelope.self, from: data)
            candidates = decoded.candidates
            status = "\(decoded.statistics.articles24h) articles · \(decoded.statistics.sources24h) sources · mode statistique GDELT."
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

private struct ProbabilityPoint: Identifiable { let id = UUID(); let time: Date; let probability: Double }

private struct DynamicMarketCard: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.openURL) private var openURL
    let market: Market
    let amount: Int
    @State private var history: [ProbabilityPoint] = []
    @State private var yesQuantity = 0.0
    @State private var noQuantity = 0.0

    private var yesValue: Double { yesQuantity * Double(market.yesProbability) / 100 }
    private var noValue: Double { noQuantity * Double(100 - market.yesProbability) / 100 }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { Eyebrow(text: market.sourceType == "ai_news" ? "\(market.category.uppercased()) · IA + SOURCES" : market.category.uppercased()); Spacer(); Text("\(market.yesProbability)% OUI").font(.caption.monospacedDigit().bold()).foregroundStyle(Color.konsensGreen) }
            Text(market.question).font(.headline)
            if !market.resolutionRules.isEmpty { Text(market.resolutionRules).font(.caption2).foregroundStyle(Color.konsensMuted).lineLimit(4) }

            if history.count > 1 {
                Chart(history) { point in
                    LineMark(x: .value("Date", point.time), y: .value("Probabilité", point.probability))
                        .interpolationMethod(.catmullRom).foregroundStyle(Color.konsensGreen)
                }.chartYScale(domain: 5...95).chartXAxis(.hidden).frame(height: 115)
            } else {
                GeometryReader { proxy in
                    HStack(spacing: 0) { Color.konsensPositive.frame(width: proxy.size.width * CGFloat(market.yesProbability) / 100); Color.konsensNegative }.clipShape(Capsule())
                }.frame(height: 5)
            }

            HStack(spacing: 7) {
                metric("VOLUME", "\(Int(market.volumeKoins)) K")
                metric("OUVERT", "\(Int(market.openInterestKoins)) K")
                metric("CONFIANCE", market.aiConfidence.map { "\(Int($0 * 100))%" } ?? "—")
            }

            if let rationale = market.aiRationale {
                VStack(alignment: .leading, spacing: 4) { Text("ANALYSE INITIALE").font(.system(size: 7, weight: .bold)).foregroundStyle(Color.konsensViolet); Text(rationale).font(.caption2).foregroundStyle(Color.konsensMuted).lineLimit(5) }
                    .padding(12).background(Color.konsensViolet.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
            }

            if !market.sourceURLs.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(market.sourceURLs.enumerated()), id: \.offset) { index, raw in
                            Button { if let url = URL(string: raw) { openURL(url) } } label: {
                                Label(market.sourceTitles.indices.contains(index) ? String(market.sourceTitles[index].prefix(30)) : "Source", systemImage: "arrow.up.forward.square")
                                    .font(.system(size: 8)).padding(8).background(Color.konsensBlue.opacity(0.07), in: Capsule())
                            }.buttonStyle(.plain).foregroundStyle(Color.konsensBlue)
                        }
                    }
                }
            }

            HStack { Text("Clôture \(shortDate(market.closesAt))").font(.caption2).foregroundStyle(Color.konsensMuted); Spacer(); Text("Enjeu \(amount) Koins").font(.caption2).foregroundStyle(Color.konsensMuted) }
            HStack(spacing: 8) {
                Button { Task { await store.bet(market, outcome: "yes", amount: amount); await load() } } label: { Text("ACHETER OUI").frame(maxWidth: .infinity).padding(12).background(Color.konsensPositive.opacity(0.12), in: RoundedRectangle(cornerRadius: 12)) }.foregroundStyle(Color.konsensPositive)
                Button { Task { await store.bet(market, outcome: "no", amount: amount); await load() } } label: { Text("ACHETER NON").frame(maxWidth: .infinity).padding(12).background(Color.konsensNegative.opacity(0.11), in: RoundedRectangle(cornerRadius: 12)) }.foregroundStyle(Color.konsensNegative)
            }.font(.caption.bold())
            HStack(spacing: 8) {
                Button { Task { await store.sellBet(market, outcome: "yes", amount: amount); await load() } } label: { Text("Revendre OUI · \(Int(yesValue)) K").frame(maxWidth: .infinity).padding(10).background(Color.konsensGold.opacity(0.07), in: RoundedRectangle(cornerRadius: 11)) }.foregroundStyle(Color.konsensGold).disabled(yesValue < Double(amount)).opacity(yesValue < Double(amount) ? 0.3 : 1)
                Button { Task { await store.sellBet(market, outcome: "no", amount: amount); await load() } } label: { Text("Revendre NON · \(Int(noValue)) K").frame(maxWidth: .infinity).padding(10).background(Color.konsensGold.opacity(0.07), in: RoundedRectangle(cornerRadius: 11)) }.foregroundStyle(Color.konsensGold).disabled(noValue < Double(amount)).opacity(noValue < Double(amount) ? 0.3 : 1)
            }.font(.system(size: 8, weight: .bold))
        }.panel().task { await load() }
    }

    private func metric(_ title: String, _ value: String) -> some View { VStack(alignment: .leading, spacing: 3) { Text(title).font(.system(size: 6, weight: .bold)).foregroundStyle(Color.konsensMuted); Text(value).font(.caption.monospacedDigit().bold()) }.frame(maxWidth: .infinity, alignment: .leading).padding(9).background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 10)) }

    private func load() async {
        struct HistoryRow: Decodable { let observed_at: String; let yes_probability: Double }
        if let rows: [HistoryRow] = try? await store.supabase.from("market_probability_history").select("observed_at,yes_probability").eq("market_id", value: market.id).order("observed_at").limit(120).execute().value {
            let formatter = ISO8601DateFormatter(); history = rows.compactMap { row in formatter.date(from: row.observed_at).map { ProbabilityPoint(time: $0, probability: row.yes_probability * 100) } }
        }
        guard let userID = store.supabase.auth.currentUser?.id else { return }
        struct Pos: Decodable { let side: String; let quantity: Double }
        let rows: [Pos] = (try? await store.supabase.from("positions").select("side,quantity").eq("user_id", value: userID).eq("market_id", value: market.id).execute().value) ?? []
        yesQuantity = rows.first(where: { $0.side == "yes" })?.quantity ?? 0; noQuantity = rows.first(where: { $0.side == "no" })?.quantity ?? 0
    }

    private func shortDate(_ raw: String) -> String { let formatter = ISO8601DateFormatter(); guard let date = formatter.date(from: raw) else { return raw }; return date.formatted(date: .abbreviated, time: .shortened) }
}

struct AmountPicker: View {
    @Binding var amount: Int
    var body: some View {
        HStack(spacing: 7) { ForEach([25,50,100,250], id: \.self) { value in Button("\(value)") { amount = value }.font(.caption.bold()).foregroundStyle(amount == value ? Color.konsensBackground : Color.konsensMuted).padding(.horizontal, 12).padding(.vertical, 9).background(amount == value ? Color.konsensGreen : Color.clear, in: RoundedRectangle(cornerRadius: 10)) }; Spacer(); Text("Koins").font(.caption2).foregroundStyle(Color.konsensMuted) }
        .padding(7).background(Color.konsensPanel, in: RoundedRectangle(cornerRadius: 15)).overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.white.opacity(0.07)))
    }
}

struct RiskFooter: View {
    var body: some View { HStack(alignment: .top, spacing: 10) { Image(systemName: "exclamationmark.shield.fill").foregroundStyle(Color.konsensGold); Text("Risque visible, argent fictif. Les probabilités évoluent avec les positions, mais les Koins ne sont ni achetables, ni convertibles, ni retirable en argent.").font(.system(size: 9)).foregroundStyle(Color.konsensMuted) }.padding(14).background(Color.konsensGold.opacity(0.05), in: RoundedRectangle(cornerRadius: 16)) }
}
