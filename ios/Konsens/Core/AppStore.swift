import Foundation
import Supabase

@MainActor
final class AppStore: ObservableObject {
    @Published var selectedTab: AppTab = .wealth
    @Published var isAuthenticated = false
    @Published var onboardingComplete = false
    @Published var isLoading = true
    @Published var username = "Konsens"
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
        struct Update: Encodable {
            let username: String
            let first_name: String
            let last_name: String
            let birth_date: String
            let onboarding_completed_at: String
            let journey_mode: String
        }
        let day = DateFormatter(); day.dateFormat = "yyyy-MM-dd"
        let update = Update(
            username: username,
            first_name: firstName,
            last_name: lastName,
            birth_date: day.string(from: birthDate),
            onboarding_completed_at: ISO8601DateFormatter().string(from: Date()),
            journey_mode: "balanced"
        )
        guard let id = supabase.auth.currentUser?.id else { return }
        try await supabase.from("profiles").update(update).eq("id", value: id).execute()
        onboardingComplete = true
        self.username = username
        await refreshFinance()
    }

    func loadProfile() async {
        guard let id = supabase.auth.currentUser?.id else { return }
        struct Row: Decodable {
            let username: String
            let onboarding_completed_at: String?
            let subscription_tier: String
            let streak_days: Int
        }
        if let row: Row = try? await supabase.from("profiles")
            .select("username,onboarding_completed_at,subscription_tier,streak_days")
            .eq("id", value: id)
            .single()
            .execute().value {
            onboardingComplete = row.onboarding_completed_at != nil
            username = row.username
            subscriptionTier = row.subscription_tier
            streak = row.streak_days
        }
        await refreshFinance()
    }

    func refreshFinance() async {
        guard supabase.auth.currentUser != nil else { return }

        struct WealthRow: Decodable {
            let cash_value: Double
            let investments_value: Double
            let bets_value: Double
            let total_value: Double
        }
        if let rows: [WealthRow] = try? await supabase.rpc("get_my_wealth_snapshot").execute().value,
           let row = rows.first {
            wealth = WealthSnapshot(cash: row.cash_value, investments: row.investments_value, bets: row.bets_value, total: row.total_value)
            credits = Int(row.cash_value.rounded(.down))
        }

        struct RawMarket: Decodable {
            let id: UUID
            let category: String
            let question: String
            let yes_probability: Double
            let closes_at: String
        }
        if let rows: [RawMarket] = try? await supabase.from("markets")
            .select("id,category,question,yes_probability,closes_at")
            .eq("status", value: "open")
            .order("closes_at")
            .limit(12)
            .execute().value {
            markets = rows.map { Market(id: $0.id, category: $0.category, question: $0.question, yesProbability: Int(($0.yes_probability * 100).rounded()), closesAt: $0.closes_at) }
        }

        struct RawAsset: Decodable { let id: UUID; let symbol: String; let name: String; let kind: String }
        struct PriceRow: Decodable { let price: Double }
        if let rows: [RawAsset] = try? await supabase.from("assets")
            .select("id,symbol,name,kind")
            .eq("is_active", value: true)
            .order("symbol")
            .execute().value {
            var quotes: [AssetQuote] = []
            for asset in rows {
                let priceRow: PriceRow? = try? await supabase.from("price_history")
                    .select("price")
                    .eq("asset_id", value: asset.id)
                    .order("observed_at", ascending: false)
                    .limit(1)
                    .single()
                    .execute().value
                quotes.append(AssetQuote(id: asset.id, symbol: asset.symbol, name: asset.name, kind: asset.kind, price: priceRow?.price ?? 0))
            }
            assets = quotes
        }

        struct RawLesson: Decodable { let id: UUID; let title: String; let summary: String; let concept: String; let xp_reward: Int }
        if let rows: [RawLesson] = try? await supabase.from("learning_modules")
            .select("id,title,summary,concept,xp_reward")
            .eq("is_active", value: true)
            .order("position")
            .execute().value {
            lessons = rows.map { LearningLesson(id: $0.id, title: $0.title, summary: $0.summary, concept: $0.concept, xpReward: $0.xp_reward) }
        }
    }

    func buyAsset(_ asset: AssetQuote, amount: Int) async {
        await placeOrder(assetID: asset.id, marketID: nil, outcome: nil, amount: amount)
    }

    func bet(_ market: Market, outcome: String, amount: Int) async {
        await placeOrder(assetID: nil, marketID: market.id, outcome: outcome, amount: amount)
    }

    private func placeOrder(assetID: UUID?, marketID: UUID?, outcome: String?, amount: Int) async {
        guard let id = supabase.auth.currentUser?.id else { return }
        struct Order: Encodable {
            let user_id: UUID
            let asset_id: UUID?
            let market_id: UUID?
            let side: String
            let outcome: String?
            let credits: Int
            let idempotency_key: UUID
        }
        do {
            let order = Order(user_id: id, asset_id: assetID, market_id: marketID, side: "buy", outcome: outcome, credits: amount, idempotency_key: UUID())
            try await supabase.from("trade_orders").insert(order).execute()
            showToast(assetID == nil ? "Pari en Koins enregistré" : "Investissement simulé exécuté")
            await refreshFinance()
        } catch {
            showToast("Ordre refusé · vérifie ton solde")
        }
    }

    func signOut() async {
        try? await supabase.auth.signOut()
        isAuthenticated = false
        onboardingComplete = false
        wealth = WealthSnapshot()
        credits = 0
    }

    func showToast(_ message: String) {
        toast = message
        Task {
            try? await Task.sleep(for: .seconds(2))
            if toast == message { toast = nil }
        }
    }
}
