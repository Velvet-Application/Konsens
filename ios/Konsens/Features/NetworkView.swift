import SwiftUI
import GoogleMobileAds

// NetworkView is kept for the existing transparency route.
struct NetworkView: View {
    @EnvironmentObject private var store: AppStore
    var body: some View { TransparencyNativeView().environmentObject(store) }
}

// MARK: - Game home with real rewarded video

struct GameHomeView: View {
    @EnvironmentObject private var store: AppStore
    @StateObject private var rewardedVideo = KonsensRewardedVideoController()
    @State private var dailyClaimable = true
    @State private var leaders: [Leader] = []
    @State private var reactions: [LeagueReaction] = []
    @State private var leagueName = "Ligue Flash"
    @State private var showRewardedSheet = false

    private var myRank: Int { leaders.first(where: { $0.isCurrentUser })?.rank ?? 0 }

    private var featuredMarket: Market? {
        let fun = store.markets.filter { !["macro", "finance", "bourse"].contains($0.category.lowercased()) }
        return (fun.isEmpty ? store.markets : fun).first
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 15) {
                GameHomePlayerCard(
                    username: store.username,
                    score: store.wealth.total,
                    rank: myRank,
                    league: leagueName,
                    streak: store.streak
                )

                GameHomeDailyDropCard(claimable: dailyClaimable) {
                    showRewardedSheet = true
                }

                if let featuredMarket {
                    GameHomeChallengeCard(market: featuredMarket) {
                        store.selectedTab = .play
                    }
                }

                HStack(spacing: 10) {
                    GameHomeShortcut(title: "MISER", detail: "Défie l’actualité", icon: "bolt.fill", tint: Color.konsensViolet) {
                        store.selectedTab = .play
                    }
                    GameHomeShortcut(title: "INVESTIR", detail: "Joue le marché réel", icon: "chart.line.uptrend.xyaxis", tint: Color.konsensBlue) {
                        store.selectedTab = .invest
                    }
                }

                GameHomeLeagueCard(leaders: leaders) {
                    store.selectedTab = .league
                }

                GameHomeLeaguePulse(reactions: reactions, activity: store.playActivity) {
                    store.selectedTab = .league
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 104)
            .padding(.bottom, 112)
        }
        .refreshable {
            await store.refreshFinance()
            await loadGameHomeData()
        }
        .task { await loadGameHomeData() }
        .sheet(isPresented: $showRewardedSheet) {
            RewardedVideoSheet(
                controller: rewardedVideo,
                onClaimed: {
                    dailyClaimable = false
                    Task {
                        await store.refreshFinance()
                        await loadGameHomeData()
                    }
                }
            )
            .environmentObject(store)
        }
    }

    @MainActor
    private func loadGameHomeData() async {
        dailyClaimable = await fetchGameHomeDailyRewardStatus(store: store)
        let league = await fetchGameHomeLeagueBundle(store: store)
        leaders = league.leaders
        reactions = league.reactions
        leagueName = league.name
    }
}

private struct GameHomePlayerCard: View {
    let username: String
    let score: Double
    let rank: Int
    let league: String
    let streak: Int

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(LinearGradient(colors: [Color.konsensViolet, Color.konsensGreen], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 64, height: 64)
                .overlay(
                    Text(String(username.prefix(1)).uppercased())
                        .font(.system(size: 27, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                )
                .shadow(color: Color.konsensViolet.opacity(0.42), radius: 14)

            VStack(alignment: .leading, spacing: 4) {
                Text("@\(username)")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                HStack(spacing: 6) {
                    Text(league.uppercased())
                        .font(.system(size: 7, weight: .black, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(Color.konsensGold)
                    if rank > 0 {
                        Text("#\(rank)")
                            .font(.system(size: 8, weight: .black, design: .rounded))
                            .foregroundStyle(Color.konsensGreen)
                    }
                }
                if streak > 0 {
                    Text("🔥 \(streak) jour\(streak > 1 ? "s" : "") de série")
                        .font(.caption2.bold())
                        .foregroundStyle(Color.konsensMuted)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text(String(format: "%.0f K", score))
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .monospacedDigit()
                Text("TON PATRIMOINE")
                    .font(.system(size: 6, weight: .black, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(Color.konsensMuted)
            }
        }
        .padding(17)
        .background(
            LinearGradient(colors: [Color.konsensViolet.opacity(0.17), Color.konsensPanelRaised.opacity(0.98)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.konsensViolet.opacity(0.22)))
    }
}

private struct GameHomeDailyDropCard: View {
    let claimable: Bool
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("🎁 DROP DU JOUR")
                        .font(.system(size: 8, weight: .black, design: .rounded))
                        .tracking(1)
                        .foregroundStyle(Color.konsensGold)
                    Text(claimable ? "+100 KOINS" : "RÉCUPÉRÉ ✓")
                        .font(.system(size: 29, weight: .black, design: .rounded))
                }
                Spacer()
                Image(systemName: claimable ? "play.rectangle.fill" : "checkmark.seal.fill")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(claimable ? Color.konsensGold : Color.konsensPositive)
            }

            Text(claimable
                 ? "Regarde une courte vidéo récompensée pour débloquer le drop. Le crédit est contrôlé côté serveur et limité à une fois par jour."
                 : "Bien joué. Le prochain drop sera disponible demain à ta prochaine connexion.")
                .font(.caption)
                .foregroundStyle(Color.white.opacity(0.72))

            Button(action: action) {
                HStack {
                    Image(systemName: claimable ? "play.fill" : "clock.fill")
                    Text(claimable ? "VOIR LA VIDÉO · +100 K" : "REVENS DEMAIN")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                    Spacer()
                    if claimable { Image(systemName: "chevron.right") }
                }
                .padding(14)
                .foregroundStyle(claimable ? Color.black : Color.konsensMuted)
                .background(claimable ? Color.konsensGold : Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 15))
            }
            .buttonStyle(.plain)
            .disabled(!claimable)
        }
        .padding(17)
        .background(
            LinearGradient(colors: [Color.konsensGold.opacity(0.14), Color(red: 0.14, green: 0.07, blue: 0.02).opacity(0.55)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 23)
        )
        .overlay(RoundedRectangle(cornerRadius: 23).stroke(Color.konsensGold.opacity(0.25)))
    }
}

private struct GameHomeChallengeCard: View {
    let market: Market
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    Text("⚡ CHALLENGE À JOUER")
                        .font(.system(size: 8, weight: .black, design: .rounded))
                        .tracking(1)
                        .foregroundStyle(Color.konsensGreen)
                    Spacer()
                    Text(market.category.uppercased())
                        .font(.system(size: 7, weight: .black, design: .rounded))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.konsensViolet.opacity(0.18), in: Capsule())
                }
                Text(market.question)
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(.white)
                HStack {
                    Text("\(market.yesProbability)% jouent OUI")
                        .font(.caption2.bold())
                        .foregroundStyle(Color.white.opacity(0.72))
                    Spacer()
                    Label("JOUER", systemImage: "arrow.right.circle.fill")
                        .font(.caption.bold())
                        .foregroundStyle(Color.konsensGreen)
                }
            }
            .padding(18)
            .background(
                LinearGradient(colors: [Color.konsensViolet.opacity(0.23), Color.konsensGreen.opacity(0.08), Color.konsensPanel], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 25)
            )
            .overlay(RoundedRectangle(cornerRadius: 25).stroke(Color.konsensGreen.opacity(0.18)))
        }
        .buttonStyle(.plain)
    }
}

private struct GameHomeShortcut: View {
    let title: String
    let detail: String
    let icon: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 9) {
                Image(systemName: icon).font(.title2.bold()).foregroundStyle(tint)
                Text(title).font(.system(size: 17, weight: .bold, design: .rounded))
                Text(detail).font(.caption2).foregroundStyle(Color.konsensMuted)
            }
            .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
            .padding(15)
            .background(tint.opacity(0.085), in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(tint.opacity(0.18)))
        }
        .buttonStyle(.plain)
    }
}

private struct GameHomeLeagueCard: View {
    let leaders: [Leader]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("🏆 TA LIGUE")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundStyle(Color.konsensGold)
                    Spacer()
                    Text("CLASSEMENT →")
                        .font(.system(size: 7, weight: .black, design: .rounded))
                        .foregroundStyle(Color.konsensMuted)
                }
                if leaders.isEmpty {
                    Text("Chargement du classement…").font(.caption).foregroundStyle(Color.konsensMuted)
                } else {
                    ForEach(leaders.prefix(4)) { leader in
                        HStack(spacing: 10) {
                            Text("#\(leader.rank)")
                                .font(.caption.monospacedDigit().bold())
                                .foregroundStyle(leader.rank <= 3 ? Color.konsensGold : Color.konsensMuted)
                                .frame(width: 27, alignment: .leading)
                            Circle()
                                .fill(leader.isCurrentUser ? Color.konsensGreen : Color.konsensViolet.opacity(0.65))
                                .frame(width: 30, height: 30)
                                .overlay(Text(leader.initials).font(.caption2.bold()).foregroundStyle(.white))
                            Text(leader.name)
                                .font(.subheadline.bold())
                                .foregroundStyle(leader.isCurrentUser ? Color.konsensGreen : .white)
                            Spacer()
                            Text(String(format: "%.0f K", leader.score)).font(.caption.monospacedDigit().bold())
                        }
                    }
                }
            }
            .padding(17)
            .background(Color.konsensPanelRaised.opacity(0.96), in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.konsensGold.opacity(0.12)))
        }
        .buttonStyle(.plain)
    }
}

private struct GameHomeLeaguePulse: View {
    let reactions: [LeagueReaction]
    let activity: [PlayActivity]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Text("💬 ÇA BOUGE DANS LA LIGUE")
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .foregroundStyle(Color.konsensViolet)
                if let reaction = reactions.first {
                    Text("\(reaction.actorUsername) a envoyé \(reaction.reaction) à \(reaction.targetUsername)")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                } else if let move = activity.first {
                    Text("Nouveau coup joué sur \(move.category).")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                } else {
                    Text("Sois le premier à mettre l’ambiance.")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                }
                Text("Réactions, gros coups et dépassements font vivre ta ligue.")
                    .font(.caption)
                    .foregroundStyle(Color.konsensMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(17)
            .background(Color.konsensViolet.opacity(0.07), in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.konsensViolet.opacity(0.16)))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Google rewarded video

@MainActor
final class KonsensRewardedVideoController: NSObject, ObservableObject, FullScreenContentDelegate {
    enum State: Equatable {
        case idle
        case loading
        case ready
        case presenting
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    private var rewardedAd: RewardedAd?
    private var rewardNonce = UUID()

    var adUnitID: String {
        (Bundle.main.object(forInfoDictionaryKey: "KonsensRewardedAdUnitID") as? String)
        ?? "ca-app-pub-3940256099942544/1712485313"
    }

    func prepare(userID: String?) async {
        if state == .ready || state == .loading { return }
        state = .loading
        MobileAds.shared.start()
        do {
            rewardNonce = UUID()
            let ad = try await RewardedAd.load(with: adUnitID, request: Request())
            let verification = ServerSideVerificationOptions()
            verification.userIdentifier = userID
            verification.customRewardText = rewardNonce.uuidString
            ad.serverSideVerificationOptions = verification
            ad.fullScreenContentDelegate = self
            rewardedAd = ad
            state = .ready
        } catch {
            rewardedAd = nil
            state = .failed(error.localizedDescription)
        }
    }

    func present(onEarned: @escaping (_ rewardNonce: UUID, _ adUnitID: String) -> Void) {
        guard let rewardedAd else {
            state = .failed("La vidéo n’est pas encore prête.")
            return
        }
        let nonce = rewardNonce
        state = .presenting
        rewardedAd.present(from: nil) { [weak self] in
            guard let self else { return }
            onEarned(nonce, self.adUnitID)
        }
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        rewardedAd = nil
        state = .idle
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        rewardedAd = nil
        state = .failed(error.localizedDescription)
    }
}

private struct RewardedVideoSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var controller: KonsensRewardedVideoController
    let onClaimed: () -> Void

    @State private var claiming = false
    @State private var earned = false
    @State private var backendMessage: String?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.10, green: 0.04, blue: 0.18), Color.konsensBackground],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("DROP VIDÉO · +100 K")
                        .font(.caption.bold())
                        .foregroundStyle(Color.konsensGold)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill").font(.title2)
                    }
                    .foregroundStyle(Color.konsensMuted)
                }

                Spacer()

                Image(systemName: "play.tv.fill")
                    .font(.system(size: 58))
                    .foregroundStyle(Color.konsensGold)

                Text("Une vidéo. Un drop. Une fois par jour.")
                    .font(.system(size: 29, weight: .black, design: .rounded))

                Text("La vidéo est fournie par Google Mobile Ads. En bêta, Konsens utilise le bloc rewarded de démonstration officiel Google : aucun annonceur réel n’est facturé.")
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.72))

                if let backendMessage {
                    Text(backendMessage)
                        .font(.caption.bold())
                        .foregroundStyle(Color.konsensNegative)
                }

                Spacer()

                Button(action: play) {
                    HStack {
                        if controller.state == .loading || claiming {
                            ProgressView().tint(.black)
                        } else {
                            Image(systemName: "play.fill")
                        }
                        Text(buttonTitle)
                        Spacer()
                    }
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .padding(15)
                    .foregroundStyle(canPlay ? Color.black : Color.konsensMuted)
                    .background(canPlay ? Color.konsensGold : Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .disabled(!canPlay || claiming || earned)

                Text("Les 100 K ne sont crédités qu’après le callback de récompense de la vidéo puis validation du RPC Supabase. Fermer la vidéo trop tôt ne crédite rien.")
                    .font(.caption2)
                    .foregroundStyle(Color.konsensMuted)
            }
            .padding(22)
        }
        .task {
            await controller.prepare(userID: store.supabase.auth.currentUser?.id.uuidString)
        }
    }

    private var canPlay: Bool {
        if case .ready = controller.state { return true }
        return false
    }

    private var buttonTitle: String {
        if claiming { return "CRÉDIT EN COURS…" }
        switch controller.state {
        case .idle: return "PRÉPARER LA VIDÉO"
        case .loading: return "CHARGEMENT DE LA VIDÉO…"
        case .ready: return "REGARDER LA VIDÉO · +100 K"
        case .presenting: return "VIDÉO EN COURS…"
        case .failed(let message): return "VIDÉO INDISPONIBLE · \(message)"
        }
    }

    private func play() {
        backendMessage = nil
        controller.present { nonce, adUnitID in
            Task { await claimReward(nonce: nonce, adUnitID: adUnitID) }
        }
    }

    @MainActor
    private func claimReward(nonce: UUID, adUnitID: String) async {
        guard !earned else { return }
        claiming = true

        struct Params: Encodable {
            let p_provider: String
            let p_ad_unit: String
            let p_reward_nonce: UUID
        }
        struct Row: Decodable {
            let claimed: Bool
            let amount: Int
            let balance: Double
            let streak: Int
        }

        do {
            let rows: [Row] = try await store.supabase.rpc(
                "claim_daily_reward_video",
                params: Params(p_provider: "admob", p_ad_unit: adUnitID, p_reward_nonce: nonce)
            ).execute().value

            guard let row = rows.first else {
                backendMessage = "Réponse serveur vide. Aucun crédit n’a été ajouté."
                claiming = false
                return
            }

            earned = true
            store.showToast(row.claimed ? "+\(row.amount) Koins · série \(row.streak) 🔥" : "Drop déjà récupéré aujourd’hui")
            onClaimed()
            dismiss()
        } catch {
            backendMessage = "La vidéo a été validée, mais le backend Konsens n’est pas encore activé sur ce projet Supabase."
            store.showToast("Drop non crédité · backend indisponible")
        }
        claiming = false
    }
}

// MARK: - Home data loaders

private struct GameHomeLeagueBundle {
    let leaders: [Leader]
    let reactions: [LeagueReaction]
    let name: String
}

@MainActor
private func fetchGameHomeDailyRewardStatus(store: AppStore) async -> Bool {
    struct Row: Decodable {
        let claimable: Bool
        let amount: Int
        let claimed_at: String?
    }
    do {
        let rows: [Row] = try await store.supabase.rpc("get_my_daily_reward_status").execute().value
        return rows.first?.claimable ?? true
    } catch {
        return true
    }
}

@MainActor
private func fetchGameHomeLeagueBundle(store: AppStore) async -> GameHomeLeagueBundle {
    struct Limit: Encodable { let p_limit: Int }
    struct LeaderRow: Decodable {
        let position: Int
        let user_id: UUID
        let username: String
        let avatar_seed: String
        let score: Double
        let is_current_user: Bool
        let league_name: String
    }
    struct ReactionRow: Decodable {
        let id: Int64
        let actor_id: UUID
        let actor_username: String
        let target_id: UUID
        let target_username: String
        let reaction: String
        let created_at: String
    }

    var leagueName = "Ligue Flash"
    var leaders: [Leader] = []
    var reactions: [LeagueReaction] = []

    do {
        let rows: [LeaderRow] = try await store.supabase.rpc(
            "get_my_league_leaderboard",
            params: Limit(p_limit: 20)
        ).execute().value
        leaders = rows.map { row in
            leagueName = row.league_name
            return Leader(
                id: row.user_id,
                rank: row.position,
                name: row.username,
                initials: String(row.avatar_seed.prefix(2)).uppercased(),
                score: row.score,
                isCurrentUser: row.is_current_user
            )
        }
    } catch { }

    do {
        let rows: [ReactionRow] = try await store.supabase.rpc(
            "get_my_league_reactions",
            params: Limit(p_limit: 20)
        ).execute().value
        let formatter = ISO8601DateFormatter()
        reactions = rows.map { row in
            LeagueReaction(
                id: row.id,
                actorID: row.actor_id,
                actorUsername: row.actor_username,
                targetID: row.target_id,
                targetUsername: row.target_username,
                reaction: row.reaction,
                createdAt: formatter.date(from: row.created_at) ?? Date()
            )
        }
    } catch { }

    if leaders.isEmpty, let userID = store.supabase.auth.currentUser?.id {
        leaders = [
            Leader(
                id: userID,
                rank: 1,
                name: store.username,
                initials: String(store.username.prefix(1)).uppercased(),
                score: store.wealth.total,
                isCurrentUser: true
            )
        ]
    }

    return GameHomeLeagueBundle(leaders: leaders, reactions: reactions, name: leagueName)
}
