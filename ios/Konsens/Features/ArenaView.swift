import SwiftUI

// MARK: - V2 game-first home

struct ArenaView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var ads: AdMobService
    @State private var dailyClaimable = true
    @State private var dailyRewardAmount = 100
    @State private var collectingReward = false
    @State private var leaders: [Leader] = []
    @State private var reactions: [LeagueReaction] = []
    @State private var leagueName = "Ligue Flash"

    private var myRank: Int { leaders.first(where: { $0.isCurrentUser })?.rank ?? 0 }
    private var isPremium: Bool { store.subscriptionTier == "premium" }

    private var featuredMarket: Market? {
        let fun = store.markets.filter { !["macro", "finance", "bourse"].contains($0.category.lowercased()) }
        return (fun.isEmpty ? store.markets : fun).first
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 15) {
                PlayerHero(username: store.username, score: store.wealth.total, rank: myRank, league: leagueName, streak: store.streak)

                if myRank > 1, let leader = leaders.first {
                    ChaseCard(leader: leader, myScore: store.wealth.total)
                }

                DailyDropCard(
                    claimable: dailyClaimable,
                    amount: dailyRewardAmount,
                    streak: store.streak,
                    premium: isPremium,
                    loading: collectingReward
                ) {
                    Task { await collectDailyReward() }
                }

                if let featuredMarket {
                    DailyChallengeCard(market: featuredMarket) { store.selectedTab = .play }
                } else {
                    GameEmptyCard(icon: "bolt.fill", title: "Les prochains paris arrivent", detail: "Sport, pop culture, internet, finance et sujets absurdes du quotidien.", color: Color.konsensPink)
                }

                HStack(spacing: 10) {
                    GameShortcut(title: "PARIER", detail: "Mets tes Koins en jeu", icon: "bolt.fill", tint: Color.konsensPink) {
                        store.selectedTab = .play
                    }
                    GameShortcut(title: "INVESTIR", detail: "Joue le marché réel", icon: "chart.line.uptrend.xyaxis", tint: Color.konsensBlue) {
                        store.selectedTab = .invest
                    }
                }

                GameShortcut(title: "DÉFIER MES POTES", detail: "Crée un pari que ta ligue peut accepter", icon: "person.2.fill", tint: Color.konsensGold) {
                    store.selectedTab = .league
                }

                LeaguePreview(leaders: leaders) { store.selectedTab = .league }
                LeaguePulse(reactions: reactions, activity: store.playActivity) { store.selectedTab = .league }

                PremiumCard(isPremium: isPremium) { store.selectedTab = .profile }

                if ads.privacyOptionsRequired {
                    Button("Gérer mes choix publicitaires") { Task { await ads.presentPrivacyOptions() } }
                        .font(.caption.bold())
                        .foregroundStyle(Color.konsensMuted)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 104)
            .padding(.bottom, 112)
        }
        .refreshable {
            await store.refreshFinance()
            await loadGameData()
        }
        .task { await loadGameData() }
    }

    @MainActor
    private func collectDailyReward() async {
        guard dailyClaimable, !collectingReward else { return }
        collectingReward = true
        defer { collectingReward = false }

        if !isPremium {
            guard ads.adsReady else {
                store.showToast("La pub se prépare. Vérifie ton consentement ou réessaie.")
                return
            }
            let earned = await ads.showRewarded()
            guard earned else {
                store.showToast("Regarde le spot jusqu’au bout pour débloquer tes Koins")
                return
            }
        }

        struct Row: Decodable { let claimed: Bool; let amount: Int; let balance: Double; let streak: Int }
        do {
            let rows: [Row] = try await store.supabase.rpc("claim_daily_reward_admob").execute().value
            if let row = rows.first {
                dailyClaimable = !row.claimed ? false : false
                dailyRewardAmount = row.amount
                store.showToast(row.claimed ? "+\(row.amount) Koins · série \(row.streak) 🔥" : "Drop déjà récupéré aujourd’hui")
            }
            await store.refreshFinance()
            await loadGameData()
        } catch {
            store.showToast("Impossible de créditer le Drop")
        }
    }

    @MainActor
    private func loadGameData() async {
        let status = await fetchDailyRewardStatus(store: store)
        dailyClaimable = status.claimable
        dailyRewardAmount = status.amount
        let league = await fetchLeagueBundle(store: store)
        leaders = league.leaders
        reactions = league.reactions
        leagueName = league.name
    }
}

private struct PlayerHero: View {
    let username: String
    let score: Double
    let rank: Int
    let league: String
    let streak: Int

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(LinearGradient(colors: [Color.konsensPink, Color.konsensViolet, Color.konsensGreen], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 66, height: 66)
                .overlay(Text(String(username.prefix(1)).uppercased()).font(.system(size: 28, weight: .black, design: .rounded)).foregroundStyle(.white))
                .shadow(color: Color.konsensViolet.opacity(0.44), radius: 16)

            VStack(alignment: .leading, spacing: 4) {
                Text("@\(username)").font(.system(size: 18, weight: .black, design: .rounded))
                Text(league.uppercased()).font(.system(size: 7, weight: .black, design: .rounded)).tracking(0.8).foregroundStyle(Color.konsensGold)
                Text(rank > 0 ? "#\(rank) · 🔥 \(max(streak, 0)) jour\(streak == 1 ? "" : "s")" : "🔥 \(max(streak, 0)) jour\(streak == 1 ? "" : "s")")
                    .font(.caption2.bold()).foregroundStyle(Color.konsensMuted)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(String(format: "%.0f K", score)).font(.system(size: 25, weight: .black, design: .rounded)).monospacedDigit()
                Text("TA FORTUNE").font(.system(size: 6, weight: .black, design: .rounded)).tracking(0.8).foregroundStyle(Color.konsensGold)
            }
        }
        .padding(17)
        .background(LinearGradient(colors: [Color.konsensViolet.opacity(0.25), Color.konsensPink.opacity(0.08), Color.konsensPanelRaised.opacity(0.98)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 25, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 25).stroke(Color.konsensViolet.opacity(0.28)))
    }
}

private struct ChaseCard: View {
    let leader: Leader
    let myScore: Double
    private var gap: Double { max(0, leader.score - myScore) }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "flame.fill").font(.title2).foregroundStyle(Color.konsensOrange)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(leader.name) est devant toi.").font(.system(size: 15, weight: .black, design: .rounded))
                Text(String(format: "Il te manque %.0f K pour le rattraper.", gap)).font(.caption).foregroundStyle(Color.konsensMuted)
            }
            Spacer()
            Text("GO").font(.caption.black()).foregroundStyle(Color.konsensOrange)
        }
        .padding(14)
        .background(Color.konsensOrange.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.konsensOrange.opacity(0.15)))
    }
}

private struct DailyDropCard: View {
    let claimable: Bool
    let amount: Int
    let streak: Int
    let premium: Bool
    let loading: Bool
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("🎁 DROP DU JOUR").font(.system(size: 8, weight: .black, design: .rounded)).tracking(1).foregroundStyle(Color.konsensGold)
                    Text(claimable ? "+\(amount) KOINS" : "RÉCUPÉRÉ ✓").font(.system(size: 30, weight: .black, design: .rounded))
                }
                Spacer()
                Image(systemName: claimable ? "gift.fill" : "checkmark.seal.fill").font(.system(size: 36, weight: .bold)).foregroundStyle(claimable ? Color.konsensGold : Color.konsensPositive)
            }

            Text(claimable
                 ? (premium ? "KONSENS+ : ton Drop est disponible sans publicité." : "Regarde une pub récompensée pour débloquer ton Drop. Plus ta série dure, plus le montant grimpe.")
                 : "Reviens demain. Une série plus longue peut faire monter ton prochain Drop.")
                .font(.caption).foregroundStyle(Color.white.opacity(0.74))

            HStack(spacing: 6) {
                ForEach(1...7, id: \.self) { day in
                    Text(day <= max(1, min(streak, 7)) ? "●" : "○")
                        .font(.caption2.bold())
                        .foregroundStyle(day <= max(1, min(streak, 7)) ? Color.konsensGold : Color.konsensMuted.opacity(0.55))
                }
                Spacer()
                Text("JACKPOT J7").font(.system(size: 7, weight: .black, design: .rounded)).foregroundStyle(Color.konsensGold)
            }

            Button(action: action) {
                HStack {
                    if loading { ProgressView().tint(Color.black) }
                    Image(systemName: premium ? "crown.fill" : "play.rectangle.fill")
                    Text(claimable ? (premium ? "ENCAISSER MES \(amount) K" : "PUB → +\(amount) K") : "REVENS DEMAIN")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                    Spacer()
                    if claimable { Image(systemName: "chevron.right") }
                }
                .padding(14)
                .foregroundStyle(claimable ? Color.black : Color.konsensMuted)
                .background(claimable ? Color.konsensGold : Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 15))
            }
            .buttonStyle(.plain)
            .disabled(!claimable || loading)
        }
        .padding(17)
        .background(LinearGradient(colors: [Color.konsensGold.opacity(0.17), Color.konsensOrange.opacity(0.08), Color.konsensPanel], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.konsensGold.opacity(0.27)))
    }
}

private struct DailyChallengeCard: View {
    let market: Market
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    Text("⚡ ÇA PARIE").font(.system(size: 8, weight: .black, design: .rounded)).tracking(1).foregroundStyle(Color.konsensPink)
                    Spacer()
                    Text(market.category.uppercased()).font(.system(size: 7, weight: .black, design: .rounded)).padding(.horizontal, 9).padding(.vertical, 5).background(Color.konsensViolet.opacity(0.18), in: Capsule())
                }
                Text(market.question).font(.system(size: 22, weight: .black, design: .rounded)).multilineTextAlignment(.leading).foregroundStyle(.white)
                HStack {
                    Text("\(market.yesProbability)% jouent OUI").font(.caption2.bold()).foregroundStyle(Color.white.opacity(0.72))
                    Spacer()
                    Label("MISER", systemImage: "arrow.right.circle.fill").font(.caption.black()).foregroundStyle(Color.konsensPink)
                }
            }
            .padding(18)
            .background(LinearGradient(colors: [Color.konsensPink.opacity(0.18), Color.konsensViolet.opacity(0.18), Color.konsensPanel], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 25))
            .overlay(RoundedRectangle(cornerRadius: 25).stroke(Color.konsensPink.opacity(0.20)))
        }
        .buttonStyle(.plain)
    }
}

private struct GameShortcut: View {
    let title: String
    let detail: String
    let icon: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 9) {
                Image(systemName: icon).font(.title2.bold()).foregroundStyle(tint)
                Text(title).font(.system(size: 16, weight: .black, design: .rounded))
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

private struct PremiumCard: View {
    let isPremium: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: "crown.fill").font(.title2).foregroundStyle(Color.konsensGold)
                VStack(alignment: .leading, spacing: 3) {
                    Text(isPremium ? "KONSENS+ ACTIF" : "KONSENS+").font(.system(size: 15, weight: .black, design: .rounded))
                    Text(isPremium ? "Zéro pub. Joue sans interruption." : "Plus de pub. Juste le jeu.").font(.caption).foregroundStyle(Color.konsensMuted)
                }
                Spacer()
                if !isPremium { Image(systemName: "chevron.right").foregroundStyle(Color.konsensGold) }
            }
            .padding(16)
            .background(Color.konsensGold.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.konsensGold.opacity(0.16)))
        }
        .buttonStyle(.plain)
    }
}

private struct GameEmptyCard: View {
    let icon: String
    let title: String
    let detail: String
    let color: Color
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.title2).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 16, weight: .black, design: .rounded))
                Text(detail).font(.caption).foregroundStyle(Color.konsensMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(17)
        .background(color.opacity(0.07), in: RoundedRectangle(cornerRadius: 20))
    }
}

private struct LeaguePreview: View {
    let leaders: [Leader]
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("🏆 TA LIGUE").font(.system(size: 9, weight: .black, design: .rounded)).foregroundStyle(Color.konsensGold)
                    Spacer()
                    Text("CLASSEMENT →").font(.system(size: 7, weight: .black, design: .rounded)).foregroundStyle(Color.konsensMuted)
                }
                if leaders.isEmpty {
                    Text("Chargement du classement…").font(.caption).foregroundStyle(Color.konsensMuted)
                } else {
                    ForEach(leaders.prefix(4)) { leader in
                        HStack(spacing: 10) {
                            Text("#\(leader.rank)").font(.caption.monospacedDigit().bold()).foregroundStyle(leader.rank <= 3 ? Color.konsensGold : Color.konsensMuted).frame(width: 27, alignment: .leading)
                            Circle().fill(leader.isCurrentUser ? Color.konsensGreen : Color.konsensViolet.opacity(0.65)).frame(width: 30, height: 30).overlay(Text(leader.initials).font(.caption2.bold()).foregroundStyle(.white))
                            Text(leader.name).font(.subheadline.bold()).foregroundStyle(leader.isCurrentUser ? Color.konsensGreen : .white)
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

private struct LeaguePulse: View {
    let reactions: [LeagueReaction]
    let activity: [PlayActivity]
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Text("💬 ÇA CHAMBRE").font(.system(size: 9, weight: .black, design: .rounded)).foregroundStyle(Color.konsensViolet)
                if let reaction = reactions.first {
                    Text("\(reaction.actorUsername) a envoyé \(reaction.reaction) à \(reaction.targetUsername)").font(.system(size: 15, weight: .black, design: .rounded))
                } else if let move = activity.first {
                    Text("Nouveau coup joué sur \(move.category).").font(.system(size: 15, weight: .black, design: .rounded))
                } else {
                    Text("Sois le premier à mettre l’ambiance.").font(.system(size: 15, weight: .black, design: .rounded))
                }
                Text("Réactions, gros coups et dépassements font vivre ta ligue.").font(.caption).foregroundStyle(Color.konsensMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(17)
            .background(Color.konsensViolet.opacity(0.07), in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.konsensViolet.opacity(0.16)))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Paris

struct GamePlayView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var ads: AdMobService
    @State private var index = 0
    @State private var amount = 50
    @State private var playing = false

    private var isPremium: Bool { store.subscriptionTier == "premium" }
    private var markets: [Market] {
        let fun = store.markets.filter { !["macro", "finance", "bourse"].contains($0.category.lowercased()) }
        return fun.isEmpty ? store.markets : fun
    }
    private var current: Market? {
        guard !markets.isEmpty else { return nil }
        return markets[min(index, markets.count - 1)]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("⚡ PARIS").font(.system(size: 10, weight: .black, design: .rounded)).tracking(1.2).foregroundStyle(Color.konsensPink)
                    Text("Ton instinct. Tes Koins.").font(.system(size: 31, weight: .black, design: .rounded))
                    Text(isPremium ? "KONSENS+ : mise instantanée, sans pub." : "Chaque mise gratuite est débloquée par une pub interstitielle. Jamais d’argent réel.").font(.caption).foregroundStyle(Color.konsensMuted)
                }

                if let current {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack {
                            Text(current.category.uppercased()).font(.caption2.bold()).foregroundStyle(Color.konsensGreen)
                            Spacer()
                            Text("\(current.yesProbability)% OUI").font(.caption.monospacedDigit().bold()).foregroundStyle(Color.konsensMuted)
                        }
                        Text(current.question).font(.system(size: 29, weight: .black, design: .rounded)).minimumScaleFactor(0.78)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("TA MISE").font(.system(size: 8, weight: .black, design: .rounded)).foregroundStyle(Color.konsensMuted)
                            HStack(spacing: 7) {
                                ForEach([25, 50, 100, 250], id: \.self) { value in
                                    Button("\(value) K") { amount = value }
                                        .font(.caption.bold()).frame(maxWidth: .infinity).padding(.vertical, 9)
                                        .background(amount == value ? Color.konsensGold : Color.white.opacity(0.05), in: Capsule())
                                        .foregroundStyle(amount == value ? Color.black : Color.white)
                                }
                            }
                        }

                        HStack(spacing: 10) {
                            betButton("NON", icon: "xmark", color: Color.konsensNegative) { Task { await play(current, outcome: "no") } }
                            betButton("OUI", icon: "checkmark", color: Color.konsensPositive) { Task { await play(current, outcome: "yes") } }
                        }
                    }
                    .padding(20)
                    .background(LinearGradient(colors: [Color.konsensPink.opacity(0.16), Color.konsensViolet.opacity(0.18), Color.konsensPanelRaised], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 27))
                    .overlay(RoundedRectangle(cornerRadius: 27).stroke(Color.konsensPink.opacity(0.22)))

                    HStack {
                        Text("Pari \(min(index + 1, markets.count)) / \(markets.count)").font(.caption2.monospacedDigit()).foregroundStyle(Color.konsensMuted)
                        Spacer()
                        Button("PASSER →") { next() }.font(.caption.bold()).foregroundStyle(Color.konsensBlue)
                    }
                } else {
                    GameEmptyCard(icon: "sparkles", title: "Les prochains paris se préparent", detail: "Le moteur privilégie les sujets fun, rapides et partageables.", color: Color.konsensPink)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 106)
            .padding(.bottom, 112)
        }
    }

    private func betButton(_ title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if playing { ProgressView().tint(.white) }
                Label(title, systemImage: icon)
            }
            .font(.system(size: 17, weight: .black, design: .rounded))
            .frame(maxWidth: .infinity).padding(.vertical, 15)
            .background(color, in: RoundedRectangle(cornerRadius: 16)).foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .disabled(store.credits < amount || playing)
        .opacity(store.credits < amount ? 0.35 : 1)
    }

    @MainActor
    private func play(_ market: Market, outcome: String) async {
        guard !playing else { return }
        playing = true
        defer { playing = false }

        if !isPremium {
            guard ads.adsReady else {
                store.showToast("La pub n’est pas encore disponible")
                return
            }
            let completed = await ads.showInterstitial()
            guard completed else {
                store.showToast("La mise n’a pas été débloquée")
                return
            }
        }

        await store.bet(market, outcome: outcome, amount: amount)
        next()
    }

    private func next() {
        guard !markets.isEmpty else { return }
        withAnimation(.easeOut(duration: 0.22)) { index = (index + 1) % markets.count }
    }
}

// MARK: - Investir

struct GameInvestView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selectedID: UUID?
    @State private var amount = 100

    private var selected: AssetQuote? {
        if let selectedID { return store.assets.first(where: { $0.id == selectedID }) }
        return store.assets.first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("📈 INVEST").font(.system(size: 10, weight: .black, design: .rounded)).tracking(1.2).foregroundStyle(Color.konsensBlue)
                    Text("Bats les parieurs en jouant long.").font(.system(size: 30, weight: .black, design: .rounded))
                    Text("Le marché réel fait évoluer ton score virtuel. Aucun actif ni argent réel n’est acheté.").font(.caption).foregroundStyle(Color.konsensMuted)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 9) {
                        ForEach(store.assets) { asset in
                            Button { selectedID = asset.id } label: {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(asset.symbol).font(.headline.monospaced().bold())
                                    Text(asset.name).font(.caption2).lineLimit(1).foregroundStyle(Color.konsensMuted)
                                }
                                .frame(width: 112, alignment: .leading).padding(13)
                                .background(selected?.id == asset.id ? Color.konsensBlue.opacity(0.18) : Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 16))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if let selected {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(selected.name).font(.system(size: 20, weight: .black, design: .rounded))
                                Text(selected.kind.uppercased()).font(.caption2.bold()).foregroundStyle(Color.konsensMuted)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(String(format: selected.price >= 1000 ? "%.0f" : "%.2f", selected.price)).font(.title2.monospacedDigit().bold())
                                Text(selected.currency).font(.caption2).foregroundStyle(Color.konsensMuted)
                            }
                        }

                        HStack(spacing: 7) {
                            ForEach([50, 100, 250, 500], id: \.self) { value in
                                Button("\(value) K") { amount = value }
                                    .font(.caption.bold()).frame(maxWidth: .infinity).padding(.vertical, 9)
                                    .background(amount == value ? Color.konsensBlue : Color.white.opacity(0.05), in: Capsule())
                            }
                        }

                        Button { Task { await store.buyAsset(selected, amount: amount) } } label: {
                            HStack {
                                Image(systemName: "rocket.fill")
                                Text("INVESTIR \(amount) K")
                                Spacer()
                                Text("GO")
                            }
                            .font(.system(size: 17, weight: .black, design: .rounded)).padding(15)
                            .foregroundStyle(Color.black).background(Color.konsensGreen, in: RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain).disabled(store.credits < amount).opacity(store.credits < amount ? 0.35 : 1)
                    }
                    .padding(19)
                    .background(LinearGradient(colors: [Color.konsensBlue.opacity(0.16), Color.konsensPanelRaised], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 25))
                    .overlay(RoundedRectangle(cornerRadius: 25).stroke(Color.konsensBlue.opacity(0.2)))
                }

                HStack(spacing: 10) {
                    ScoreTile(title: "DISPO", value: String(format: "%.0f K", store.wealth.cash), color: Color.konsensGold)
                    ScoreTile(title: "INVESTI", value: String(format: "%.0f K", store.wealth.investments), color: Color.konsensBlue)
                    ScoreTile(title: "TOTAL", value: String(format: "%.0f K", store.wealth.total), color: Color.konsensGreen)
                }
            }
            .padding(.horizontal, 18).padding(.top, 106).padding(.bottom, 112)
        }
    }
}

private struct ScoreTile: View {
    let title: String
    let value: String
    let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 7, weight: .black, design: .rounded)).foregroundStyle(Color.konsensMuted)
            Text(value).font(.caption.monospacedDigit().bold()).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(11)
        .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 13))
    }
}

// MARK: - Ligue & paris entre potes

private struct LeagueChallenge: Identifiable {
    let id: UUID
    let creatorID: UUID
    let creatorUsername: String
    let opponentUsername: String?
    let question: String
    let stake: Int
    let status: String
    let createdAt: Date
    let isMine: Bool
}

struct LeagueSocialView: View {
    @EnvironmentObject private var store: AppStore
    @State private var leaders: [Leader] = []
    @State private var reactions: [LeagueReaction] = []
    @State private var challenges: [LeagueChallenge] = []
    @State private var leagueName = "Ligue Flash"
    @State private var sending = false
    @State private var showCreate = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("🏆 \(leagueName.uppercased())").font(.system(size: 10, weight: .black, design: .rounded)).foregroundStyle(Color.konsensGold)
                        Text("Sois meilleur. Fais-leur savoir.").font(.system(size: 27, weight: .black, design: .rounded))
                    }
                    Spacer()
                    Button { showCreate = true } label: {
                        Image(systemName: "plus").font(.headline.black()).frame(width: 42, height: 42).foregroundStyle(Color.black).background(Color.konsensGold, in: Circle())
                    }
                    .buttonStyle(.plain)
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("⚔️ PARIS ENTRE POTES").font(.system(size: 9, weight: .black, design: .rounded)).foregroundStyle(Color.konsensPink)
                        Spacer()
                        Button("CRÉER") { showCreate = true }.font(.caption.black()).foregroundStyle(Color.konsensGold)
                    }
                    if challenges.isEmpty {
                        Text("Aucun défi ouvert. Crée le premier pari de ta ligue.").font(.caption).foregroundStyle(Color.konsensMuted)
                    } else {
                        ForEach(challenges.prefix(8)) { challenge in
                            ChallengeRow(challenge: challenge) {
                                Task { await accept(challenge) }
                            }
                        }
                    }
                }
                .padding(16)
                .background(Color.konsensPink.opacity(0.06), in: RoundedRectangle(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.konsensPink.opacity(0.14)))

                VStack(spacing: 7) {
                    ForEach(leaders) { leader in
                        HStack(spacing: 10) {
                            Text("#\(leader.rank)").font(.headline.monospacedDigit().bold()).foregroundStyle(leader.rank <= 3 ? Color.konsensGold : Color.konsensMuted).frame(width: 36, alignment: .leading)
                            Circle().fill(leader.isCurrentUser ? Color.konsensGreen : Color.konsensViolet.opacity(0.65)).frame(width: 38, height: 38).overlay(Text(leader.initials).font(.caption.bold()))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(leader.isCurrentUser ? "\(leader.name) · TOI" : leader.name).font(.system(size: 15, weight: .black, design: .rounded)).foregroundStyle(leader.isCurrentUser ? Color.konsensGreen : .white)
                                Text(String(format: "%.0f Koins", leader.score)).font(.caption.monospacedDigit()).foregroundStyle(Color.konsensMuted)
                            }
                            Spacer()
                            if !leader.isCurrentUser {
                                Menu {
                                    ForEach(["😂", "🔥", "👀", "👏", "😈", "💀"], id: \.self) { emoji in
                                        Button("\(emoji) Envoyer") { Task { await sendReaction(to: leader.id, emoji: emoji) } }
                                    }
                                } label: {
                                    Image(systemName: "face.smiling").font(.title3).foregroundStyle(Color.konsensViolet).frame(width: 38, height: 38).background(Color.konsensViolet.opacity(0.1), in: Circle())
                                }
                                .disabled(sending)
                            }
                        }
                        .padding(13)
                        .background(leader.isCurrentUser ? Color.konsensGreen.opacity(0.07) : Color.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 17))
                    }
                }
                .padding(8)
                .background(Color.konsensPanelRaised.opacity(0.95), in: RoundedRectangle(cornerRadius: 23))

                VStack(alignment: .leading, spacing: 11) {
                    Text("💬 LE BANC").font(.system(size: 9, weight: .black, design: .rounded)).foregroundStyle(Color.konsensViolet)
                    if reactions.isEmpty {
                        Text("Aucune vanne pour l’instant. Fais un bon coup et lance les hostilités gentilles.").font(.caption).foregroundStyle(Color.konsensMuted)
                    } else {
                        ForEach(reactions.prefix(12)) { reaction in
                            HStack(alignment: .top, spacing: 9) {
                                Text(reaction.reaction).font(.title2)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(reaction.actorUsername) → \(reaction.targetUsername)").font(.caption.bold())
                                    Text(relativeDate(reaction.createdAt)).font(.caption2).foregroundStyle(Color.konsensMuted)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 5)
                        }
                    }
                }
                .padding(16)
                .background(Color.konsensViolet.opacity(0.06), in: RoundedRectangle(cornerRadius: 21))
            }
            .padding(.horizontal, 18).padding(.top, 106).padding(.bottom, 112)
        }
        .refreshable { await load() }
        .task { await load() }
        .sheet(isPresented: $showCreate) {
            CreateChallengeSheet { question, stake in
                Task { await createChallenge(question: question, stake: stake) }
            }
        }
    }

    @MainActor
    private func load() async {
        let bundle = await fetchLeagueBundle(store: store)
        leaders = bundle.leaders
        reactions = bundle.reactions
        leagueName = bundle.name
        challenges = await fetchLeagueChallenges(store: store)
    }

    @MainActor
    private func sendReaction(to target: UUID, emoji: String) async {
        sending = true
        struct Params: Encodable { let p_target: UUID; let p_reaction: String }
        do {
            _ = try await store.supabase.rpc("send_league_reaction", params: Params(p_target: target, p_reaction: emoji)).execute()
            store.showToast("\(emoji) envoyé dans la ligue")
            await load()
        } catch { store.showToast("Réaction indisponible") }
        sending = false
    }

    @MainActor
    private func createChallenge(question: String, stake: Int) async {
        struct Params: Encodable { let p_question: String; let p_stake: Int }
        do {
            let _: UUID = try await store.supabase.rpc("create_league_challenge", params: Params(p_question: question, p_stake: stake)).execute().value
            store.showToast("Défi lancé · \(stake) K")
            showCreate = false
            await load()
        } catch { store.showToast("Impossible de créer ce défi") }
    }

    @MainActor
    private func accept(_ challenge: LeagueChallenge) async {
        struct Params: Encodable { let p_challenge_id: UUID }
        do {
            _ = try await store.supabase.rpc("accept_league_challenge", params: Params(p_challenge_id: challenge.id)).execute()
            store.showToast("Défi accepté · \(challenge.stake) K en jeu")
            await load()
        } catch { store.showToast("Impossible d’accepter ce défi") }
    }

    private func relativeDate(_ date: Date) -> String {
        let seconds = max(0, Date().timeIntervalSince(date))
        if seconds < 60 { return "à l’instant" }
        if seconds < 3600 { return "il y a \(Int(seconds / 60)) min" }
        if seconds < 86400 { return "il y a \(Int(seconds / 3600)) h" }
        return "il y a \(Int(seconds / 86400)) j"
    }
}

private struct ChallengeRow: View {
    let challenge: LeagueChallenge
    let accept: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("@\(challenge.creatorUsername)").font(.caption.bold()).foregroundStyle(Color.konsensViolet)
                Spacer()
                Text("\(challenge.stake) K").font(.caption.monospacedDigit().black()).foregroundStyle(Color.konsensGold)
            }
            Text(challenge.question).font(.system(size: 15, weight: .black, design: .rounded))
            HStack {
                Text(challenge.status == "open" ? "QUI PREND ?" : "ACCEPTÉ PAR @\(challenge.opponentUsername ?? "joueur")")
                    .font(.system(size: 8, weight: .black, design: .rounded)).foregroundStyle(challenge.status == "open" ? Color.konsensPink : Color.konsensGreen)
                Spacer()
                if challenge.status == "open" && !challenge.isMine {
                    Button("JE PRENDS") { accept() }
                        .font(.caption.black()).padding(.horizontal, 10).padding(.vertical, 7)
                        .foregroundStyle(Color.black).background(Color.konsensGold, in: Capsule())
                }
            }
        }
        .padding(13)
        .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct CreateChallengeSheet: View {
    @Environment(\.dismiss) private var dismiss
    let create: (String, Int) -> Void
    @State private var question = ""
    @State private var stake = 100

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text("Lance un pari à ta ligue").font(.system(size: 28, weight: .black, design: .rounded))
                Text("Exemple : Thomas arrive-t-il encore en retard samedi ?").font(.caption).foregroundStyle(Color.konsensMuted)
                TextField("Ton pari…", text: $question, axis: .vertical)
                    .lineLimit(3...6).padding(14).background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))

                Text("MISE").font(.caption2.black()).foregroundStyle(Color.konsensMuted)
                HStack(spacing: 8) {
                    ForEach([50, 100, 250, 500], id: \.self) { value in
                        Button("\(value) K") { stake = value }
                            .font(.caption.bold()).frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(stake == value ? Color.konsensGold : Color.white.opacity(0.06), in: Capsule())
                            .foregroundStyle(stake == value ? Color.black : Color.white)
                    }
                }

                Button("LANCER LE DÉFI") { create(question, stake) }
                    .font(.system(size: 15, weight: .black, design: .rounded)).frame(maxWidth: .infinity).padding(15)
                    .foregroundStyle(Color.black).background(Color.konsensGold, in: RoundedRectangle(cornerRadius: 15))
                    .disabled(question.trimmingCharacters(in: .whitespacesAndNewlines).count < 8)
                    .opacity(question.trimmingCharacters(in: .whitespacesAndNewlines).count < 8 ? 0.4 : 1)
                Spacer()
            }
            .padding(22).background(Color.konsensBackground.ignoresSafeArea())
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Fermer") { dismiss() } } }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Data loaders

private struct DailyRewardStatus {
    let claimable: Bool
    let amount: Int
}

private struct LeagueBundle {
    let leaders: [Leader]
    let reactions: [LeagueReaction]
    let name: String
}

@MainActor
private func fetchDailyRewardStatus(store: AppStore) async -> DailyRewardStatus {
    struct Row: Decodable { let claimable: Bool; let amount: Int; let claimed_at: String? }
    do {
        let rows: [Row] = try await store.supabase.rpc("get_my_daily_reward_status").execute().value
        if let row = rows.first { return DailyRewardStatus(claimable: row.claimable, amount: row.amount) }
    } catch { }
    return DailyRewardStatus(claimable: true, amount: 100)
}

@MainActor
private func fetchLeagueBundle(store: AppStore) async -> LeagueBundle {
    struct Limit: Encodable { let p_limit: Int }
    struct LeaderRow: Decodable { let position: Int; let user_id: UUID; let username: String; let avatar_seed: String; let score: Double; let is_current_user: Bool; let league_name: String }
    struct ReactionRow: Decodable { let id: Int64; let actor_id: UUID; let actor_username: String; let target_id: UUID; let target_username: String; let reaction: String; let created_at: String }

    var leagueName = "Ligue Flash"
    var leaders: [Leader] = []
    var reactions: [LeagueReaction] = []

    do {
        let rows: [LeaderRow] = try await store.supabase.rpc("get_my_league_leaderboard", params: Limit(p_limit: 20)).execute().value
        leaders = rows.map { row in
            leagueName = row.league_name
            return Leader(id: row.user_id, rank: row.position, name: row.username, initials: String(row.avatar_seed.prefix(2)).uppercased(), score: row.score, isCurrentUser: row.is_current_user)
        }
    } catch { }

    do {
        let rows: [ReactionRow] = try await store.supabase.rpc("get_my_league_reactions", params: Limit(p_limit: 20)).execute().value
        let formatter = ISO8601DateFormatter()
        reactions = rows.map { row in
            LeagueReaction(id: row.id, actorID: row.actor_id, actorUsername: row.actor_username, targetID: row.target_id, targetUsername: row.target_username, reaction: row.reaction, createdAt: formatter.date(from: row.created_at) ?? Date())
        }
    } catch { }

    if leaders.isEmpty, let userID = store.supabase.auth.currentUser?.id {
        leaders = [Leader(id: userID, rank: 1, name: store.username, initials: String(store.username.prefix(1)).uppercased(), score: store.wealth.total, isCurrentUser: true)]
    }
    return LeagueBundle(leaders: leaders, reactions: reactions, name: leagueName)
}

@MainActor
private func fetchLeagueChallenges(store: AppStore) async -> [LeagueChallenge] {
    struct Limit: Encodable { let p_limit: Int }
    struct Row: Decodable {
        let id: UUID; let creator_id: UUID; let creator_username: String; let opponent_username: String?; let question: String; let stake: Int; let status: String; let created_at: String; let is_mine: Bool
    }
    do {
        let rows: [Row] = try await store.supabase.rpc("get_my_league_challenges", params: Limit(p_limit: 20)).execute().value
        let formatter = ISO8601DateFormatter()
        return rows.map { row in
            LeagueChallenge(id: row.id, creatorID: row.creator_id, creatorUsername: row.creator_username, opponentUsername: row.opponent_username, question: row.question, stake: row.stake, status: row.status, createdAt: formatter.date(from: row.created_at) ?? Date(), isMine: row.is_mine)
        }
    } catch { return [] }
}
