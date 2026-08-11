import Foundation
import Supabase
import WidgetKit

@MainActor
final class AppStore: ObservableObject {
    @Published var selectedTab: AppTab = .wealth
    @Published var isAuthenticated = false
    @Published var onboardingComplete = false
    @Published var isLoading = true
    @Published var username = "Konsens"
    @Published var role = "user"
    @Published var subscriptionTier = "free"
    @Published var wealth = WealthSnapshot()
    @Published var credits = 0
    @Published var streak = 0
    @Published var markets: [Market] = []
    @Published var assets: [AssetQuote] = []
    @Published var lessons: [LearningLesson] = []
    @Published var toast: String?

    let supabase = SupabaseClient(
        supabaseURL: URL(string: "https://mxuevsspybxoovsutsbs.supabase.co")!,
        supabaseKey: "sb_publishable_Xs7hyyDA2XUkbwXGGfSE2w_tARkgSL7"
    )

    init() { Task { await restoreSession() } }

    func restoreSession() async {
        isAuthenticated = supabase.auth.currentSession != nil
        if isAuthenticated { await loadProfile() }
        isLoading = false
    }

    func signIn(email: String, password: String) async throws {
        try await supabase.auth.signIn(email: email, password: password)
        isAuthenticated = true
        await loadProfile()
    }

    func signUp(email: String, password: String) async throws {
        try await supabase.auth.signUp(email: email, password: password)
        showToast("Vérifie ta boîte mail pour confirmer ton inscription")
    }

    func signIn(provider: Provider) async throws {
        try await supabase.auth.signInWithOAuth(provider: provider, redirectTo: URL(string: "konsens://auth-callback"))
    }

    func completeProfile(username: String, firstName: String, lastName: String, birthDate: Date) async throws {
        struct Update: Encodable { let username: String; let first_name: String; let last_name: String; let birth_date: String; let onboarding_completed_at: String; let journey_mode: String }
        let day = DateFormatter(); day.dateFormat = "yyyy-MM-dd"
        let update = Update(username: username, first_name: firstName, last_name: lastName, birth_date: day.string(from: birthDate), onboarding_completed_at: ISO8601DateFormatter().string(from: Date()), journey_mode: "balanced")
        guard let id = supabase.auth.currentUser?.id else { return }
        try await supabase.from("profiles").update(update).eq("id", value: id).execute()
        onboardingComplete = true; self.username = username; await refreshFinance()
    }

    func loadProfile() async {
        guard let id = supabase.auth.currentUser?.id else { return }
        _ = try? await supabase.rpc("refresh_my_premium_status").execute()
        struct Row: Decodable { let username: String; let role: String; let onboarding_completed_at: String?; let subscription_tier: String; let streak_days: Int }
        if let row: Row = try? await supabase.from("profiles").select("username,role,onboarding_completed_at,subscription_tier,streak_days").eq("id", value: id).single().execute().value {
            onboardingComplete = row.onboarding_completed_at != nil; username = row.username; role = row.role; subscriptionTier = row.subscription_tier; streak = row.streak_days
        }
        await refreshFinance()
    }

    func refreshFinance() async {
        guard supabase.auth.currentUser != nil else { return }
        struct WealthRow: Decodable { let cash_value: Double; let investments_value: Double; let bets_value: Double; let total_value: Double }
        if let rows: [WealthRow] = try? await supabase.rpc("get_my_wealth_snapshot").execute().value, let row = rows.first {
            wealth = WealthSnapshot(cash: row.cash_value, investments: row.investments_value, bets: row.bets_value, total: row.total_value); credits = Int(row.cash_value.rounded(.down))
        }

        struct RawMarket: Decodable {
            let id: UUID; let category: String; let question: String; let yes_probability: Double; let closes_at: String; let resolution_rules: String
            let source_type: String; let source_urls: [String]; let source_titles: [String]; let source_summary: String?; let ai_confidence: Double?; let ai_rationale: String?
            let suggested_stake_min: Int?; let suggested_stake_max: Int?; let volume_koins: Double; let open_interest_koins: Double; let tags: [String]
        }
        if let rows: [RawMarket] = try? await supabase.from("markets").select("id,category,question,yes_probability,closes_at,resolution_rules,source_type,source_urls,source_titles,source_summary,ai_confidence,ai_rationale,suggested_stake_min,suggested_stake_max,volume_koins,open_interest_koins,tags").eq("status", value: "open").order("created_at", ascending: false).limit(60).execute().value {
            markets = rows.map { Market(id: $0.id, category: $0.category, question: $0.question, yesProbability: Int(($0.yes_probability * 100).rounded()), closesAt: $0.closes_at, resolutionRules: $0.resolution_rules, sourceType: $0.source_type, sourceURLs: $0.source_urls, sourceTitles: $0.source_titles, sourceSummary: $0.source_summary, aiConfidence: $0.ai_confidence, aiRationale: $0.ai_rationale, suggestedStakeMin: $0.suggested_stake_min, suggestedStakeMax: $0.suggested_stake_max, volumeKoins: $0.volume_koins, openInterestKoins: $0.open_interest_koins, tags: $0.tags) }
        }

        struct RawAsset: Decodable { let id: UUID; let symbol: String; let name: String; let kind: String; let currency: String; let external_ref: String }
        struct PriceRow: Decodable { let price: Double }
        if let rows: [RawAsset] = try? await supabase.from("assets").select("id,symbol,name,kind,currency,external_ref").eq("is_active", value: true).like("external_ref", pattern: "market:%").order("symbol").execute().value {
            var quotes: [AssetQuote] = []
            for asset in rows {
                let priceRow: PriceRow? = try? await supabase.from("price_history").select("price").eq("asset_id", value: asset.id).order("observed_at", ascending: false).limit(1).single().execute().value
                quotes.append(AssetQuote(id: asset.id, symbol: asset.symbol, name: asset.name, kind: asset.kind, currency: asset.currency, externalRef: asset.external_ref, price: priceRow?.price ?? 0))
            }
            assets = quotes
        }

        struct RawLesson: Decodable {
            let id: UUID; let title: String; let summary: String; let concept: String; let xp_reward: Int; let position: Int; let category: String; let duration_minutes: Int; let risk_note: String?; let level: String
            let learning_objectives: [String]; let key_takeaways: [String]; let content_json: [LessonChapter]; let media_json: [LessonMedia]; let quiz_json: [LessonQuiz]
        }
        if let rows: [RawLesson] = try? await supabase.from("learning_modules").select("id,title,summary,concept,xp_reward,position,category,duration_minutes,risk_note,level,learning_objectives,key_takeaways,content_json,media_json,quiz_json").eq("is_active", value: true).order("position").execute().value {
            lessons = rows.map { LearningLesson(id: $0.id, title: $0.title, summary: $0.summary, concept: $0.concept, xpReward: $0.xp_reward, position: $0.position, category: $0.category, durationMinutes: $0.duration_minutes, riskNote: $0.risk_note, level: $0.level, objectives: $0.learning_objectives, takeaways: $0.key_takeaways, chapters: $0.content_json, media: $0.media_json, quiz: $0.quiz_json) }
        }
        Task { await syncWidgetSnapshot() }
    }

    func liveQuote(for asset: AssetQuote, range: String = "1mo") async -> LiveMarketQuote? {
        let marketSymbol = asset.externalRef.replacingOccurrences(of: "market:", with: "")
        guard var components = URLComponents(string: "https://mxuevsspybxoovsutsbs.supabase.co/functions/v1/market-data") else { return nil }
        components.queryItems = [URLQueryItem(name: "symbol", value: marketSymbol), URLQueryItem(name: "range", value: range), URLQueryItem(name: "interval", value: range == "1d" ? "15m" : "1d")]
        guard let url = components.url else { return nil }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            struct PointRow: Decodable { let t: Double; let price: Double }
            struct QuoteRow: Decodable { let symbol: String; let currency: String; let exchange: String; let price: Double; let previousClose: Double; let changePct: Double; let updatedAt: String; let points: [PointRow]; let provider: String }
            struct Envelope: Decodable { let quote: QuoteRow }
            let decoded = try JSONDecoder().decode(Envelope.self, from: data)
            return LiveMarketQuote(symbol: decoded.quote.symbol, currency: decoded.quote.currency, exchange: decoded.quote.exchange, price: decoded.quote.price, previousClose: decoded.quote.previousClose, changePct: decoded.quote.changePct, updatedAt: decoded.quote.updatedAt, provider: decoded.quote.provider, points: decoded.quote.points.map { MarketPoint(time: Date(timeIntervalSince1970: $0.t), price: $0.price) })
        } catch { return nil }
    }

    func buyAsset(_ asset: AssetQuote, amount: Int) async { _ = await liveQuote(for: asset, range: "5d"); await placeOrder(assetID: asset.id, marketID: nil, outcome: nil, amount: amount, side: "buy") }
    func sellAsset(_ asset: AssetQuote, amount: Int) async { _ = await liveQuote(for: asset, range: "5d"); await placeOrder(assetID: asset.id, marketID: nil, outcome: nil, amount: amount, side: "sell") }
    func bet(_ market: Market, outcome: String, amount: Int) async { await placeOrder(assetID: nil, marketID: market.id, outcome: outcome, amount: amount, side: "buy") }
    func sellBet(_ market: Market, outcome: String, amount: Int) async { await placeOrder(assetID: nil, marketID: market.id, outcome: outcome, amount: amount, side: "sell") }

    private func placeOrder(assetID: UUID?, marketID: UUID?, outcome: String?, amount: Int, side: String) async {
        guard let id = supabase.auth.currentUser?.id else { return }
        struct Order: Encodable { let user_id: UUID; let asset_id: UUID?; let market_id: UUID?; let side: String; let outcome: String?; let credits: Int; let idempotency_key: UUID }
        do {
            let order = Order(user_id: id, asset_id: assetID, market_id: marketID, side: side, outcome: outcome, credits: amount, idempotency_key: UUID())
            struct Result: Decodable { let status: String; let rejection_reason: String? }
            let result: Result = try await supabase.from("trade_orders").insert(order).select("status,rejection_reason").single().execute().value
            if result.status != "executed" { showToast(result.rejection_reason ?? "Ordre refusé"); return }
            showToast(side == "sell" ? "Revente simulée exécutée" : (assetID == nil ? "Position Play enregistrée" : "Investissement simulé exécuté"))
            await refreshFinance()
        } catch { showToast("Ordre refusé · vérifie ton solde ou ta position") }
    }

    private func syncWidgetSnapshot() async {
        struct WidgetMarket: Codable { let question: String; let category: String; let probability: Int; let volume: Int }
        struct WidgetAsset: Codable { let symbol: String; let name: String; let price: Double; let change: Double; let currency: String }
        guard let defaults = UserDefaults(suiteName: "group.com.konsens.beta") else { return }
        defaults.set(Int(wealth.total.rounded()), forKey: "konsens_widget_wealth")
        defaults.set(wealth.performance, forKey: "konsens_widget_performance")

        let rankedMarkets = markets.sorted {
            let left = ($0.tags.contains("featured") ? 100000 : 0) + Int($0.volumeKoins)
            let right = ($1.tags.contains("featured") ? 100000 : 0) + Int($1.volumeKoins)
            return left > right
        }.prefix(3).map { WidgetMarket(question: $0.question, category: $0.category, probability: $0.yesProbability, volume: Int($0.volumeKoins)) }
        if let data = try? JSONEncoder().encode(Array(rankedMarkets)) { defaults.set(data, forKey: "konsens_widget_markets") }

        var preferredAssets = assets
        if let userID = supabase.auth.currentUser?.id {
            struct PositionRow: Decodable { let asset_id: UUID? }
            let rows: [PositionRow] = (try? await supabase.from("positions").select("asset_id").eq("user_id", value: userID).not("asset_id", operator: .is, value: "null").execute().value) ?? []
            let positionIDs = Set(rows.compactMap(\.asset_id))
            let positioned = assets.filter { positionIDs.contains($0.id) }
            if !positioned.isEmpty { preferredAssets = positioned + assets.filter { !positionIDs.contains($0.id) } }
        }
        var widgetAssets: [WidgetAsset] = []
        for asset in preferredAssets.prefix(3) {
            if let quote = await liveQuote(for: asset, range: "5d") {
                widgetAssets.append(WidgetAsset(symbol: asset.symbol, name: asset.name, price: quote.price, change: quote.changePct, currency: quote.currency))
            } else {
                widgetAssets.append(WidgetAsset(symbol: asset.symbol, name: asset.name, price: asset.price, change: 0, currency: asset.currency))
            }
        }
        if let data = try? JSONEncoder().encode(widgetAssets) { defaults.set(data, forKey: "konsens_widget_assets") }
        defaults.set(Date().timeIntervalSince1970, forKey: "konsens_widget_updated")
        WidgetCenter.shared.reloadAllTimelines()
    }

    func startPremiumTrial() async {
        do {
            _ = try await supabase.rpc("start_premium_beta_trial").execute()
            subscriptionTier = "premium"
            showToast("Premium bêta activé · publicité supprimée")
            await loadProfile()
        } catch { showToast("Activation Premium indisponible") }
    }

    func signOut() async { try? await supabase.auth.signOut(); isAuthenticated = false; onboardingComplete = false; wealth = WealthSnapshot(); credits = 0 }
    func showToast(_ message: String) { toast = message; Task { try? await Task.sleep(for: .seconds(2)); if toast == message { toast = nil } } }
}
