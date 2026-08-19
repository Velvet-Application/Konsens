import SwiftUI

// MARK: - Game-first home

struct ArenaView: View {
    @EnvironmentObject private var store: AppStore
    @State private var dailyClaimable = true
    @State private var leaders: [Leader] = []
    @State private var reactions: [LeagueReaction] = []
    @State private var leagueName = "Ligue Flash"
    @State private var showRewardedAd = false

    private var myRank: Int { leaders.first(where: { $0.isCurrentUser })?.rank ?? 0 }

    private var featuredMarket: Market? {
        let fun = store.markets.filter { !["macro", "finance", "bourse"].contains($0.category.lowercased()) }
        return (fun.isEmpty ? store.markets : fun).first
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 15) {
                PlayerHero(
                    username: store.username,
                    score: store.wealth.total,
                    rank: myRank,
                    league: leagueName,
                    streak: store.streak
                )

                DailyDropCard(claimable: dailyClaimable) {
                    showRewardedAd = true
                }

                if let featuredMarket {
                    DailyChallengeCard(market: featuredMarket) { store.selectedTab = .play }
                } else {
                    GameEmptyCard(
                        icon: "bolt.fill",
                        title: "Les prochains défis arrivent",
                        detail: "Pop culture, sport, internet, tech et sujets du quotidien.",
                        color: Color.konsensViolet
                    )
                }

                HStack(spacing: 10) {
                    GameShortcut(title: "MISER", detail: "Défie l’actualité", icon: "bolt.fill", tint: Color.konsensViolet) {
                        store.selectedTab = .play
                    }
                    GameShortcut(title: "INVESTIR", detail: "Joue le marché réel", icon: "chart.line.uptrend.xyaxis", tint: Color.konsensBlue) {
                        store.selectedTab = .invest
                    }
                }

                LeaguePreview(leaders: leaders) { store.selectedTab = .league }
                LeaguePulse(reactions: reactions, activity: store.playActivity) { store.selectedTab = .league }
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
        .sheet(isPresented: $showRewardedAd) {
            RewardedDailyAdView {
                dailyClaimable = false
                Task {
                    await store.refreshFinance()
                    await loadGameData()
                }
            }
            .environmentObject(store)
        }
    }

    @MainActor
    private func loadGameData() async {
        dailyClaimable = await fetchDailyRewardStatus(store: store)
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

private struct DailyDropCard: View {
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
                Image(systemName: claimable ? "gift.fill" : "checkmark.seal.fill")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(claimable ? Color.konsensGold : Color.konsensPositive)
            }

            Text(claimable
                 ? "Ils disparaissent ce soir si tu ne les récupères pas. Le spot sponsorisé débloque ton crédit quotidien."
                 : "Bien joué. Le prochain drop sera disponible demain à ta prochaine connexion.")
                .font(.caption)
                .foregroundStyle(Color.white.opacity(0.72))

            Button(action: action) {
                HStack {
                    Image(systemName: claimable ? "play.rectangle.fill" : "clock.fill")
                    Text(claimable ? "COLLECTER MES 100 K" : "REVENS DEMAIN")
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

private struct DailyChallengeCard: View {
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

private struct GameEmptyCard: View {
    let icon: String
    let title: String
    let detail: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.title2).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 16, weight: .bold, design: .rounded))
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

private struct LeaguePulse: View {
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

// MARK: - Play

struct GamePlayView: View {
    @EnvironmentObject private var store: AppStore
    @State private var index = 0
    @State private var amount = 50

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
                gameTitle("⚡ MISER", "Ton instinct contre la ligue.", "Des sujets rapides, légers et vérifiables. Tu engages des Koins, jamais de l’argent réel.", Color.konsensViolet)

                if let current {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack {
                            Text(current.category.uppercased()).font(.caption2.bold()).foregroundStyle(Color.konsensGreen)
                            Spacer()
                            Text("\(current.yesProbability)% OUI").font(.caption.monospacedDigit().bold()).foregroundStyle(Color.konsensMuted)
                        }

                        Text(current.question)
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .minimumScaleFactor(0.8)

                        stakePicker(values: [25, 50, 100, 250])

                        HStack(spacing: 10) {
                            betButton("NON", icon: "xmark", color: Color.konsensNegative) {
                                Task { await store.bet(current, outcome: "no", amount: amount); next() }
                            }
                            betButton("OUI", icon: "checkmark", color: Color.konsensPositive) {
                                Task { await store.bet(current, outcome: "yes", amount: amount); next() }
                            }
                        }
                    }
                    .padding(20)
                    .background(LinearGradient(colors: [Color.konsensViolet.opacity(0.19), Color.konsensPanelRaised], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 27))
                    .overlay(RoundedRectangle(cornerRadius: 27).stroke(Color.konsensViolet.opacity(0.22)))

                    HStack {
                        Text("Challenge \(min(index + 1, markets.count)) / \(markets.count)")
                            .font(.caption2.monospacedDigit()).foregroundStyle(Color.konsensMuted)
                        Spacer()
                        Button("PASSER →") { next() }.font(.caption.bold()).foregroundStyle(Color.konsensBlue)
                    }
                } else {
                    GameEmptyCard(icon: "sparkles", title: "Les prochains challenges se préparent", detail: "Le moteur privilégie les sujets fun et partageables.", color: Color.konsensViolet)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 106)
            .padding(.bottom, 112)
        }
    }

    @ViewBuilder
    private func gameTitle(_ eyebrow: String, _ title: String, _ detail: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(eyebrow).font(.system(size: 10, weight: .black, design: .rounded)).tracking(1.2).foregroundStyle(color)
            Text(title).font(.system(size: 31, weight: .black, design: .rounded))
            Text(detail).font(.caption).foregroundStyle(Color.konsensMuted)
        }
    }

    @ViewBuilder
    private func stakePicker(values: [Int]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TA MISE").font(.system(size: 8, weight: .black, design: .rounded)).foregroundStyle(Color.konsensMuted)
            HStack(spacing: 7) {
                ForEach(values, id: \.self) { value in
                    Button("\(value) K") { amount = value }
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(amount == value ? Color.konsensGold : Color.white.opacity(0.05), in: Capsule())
                        .foregroundStyle(amount == value ? Color.black : Color.white)
                }
            }
        }
    }

    private func betButton(_ title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(color, in: RoundedRectangle(cornerRadius: 16))
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .disabled(store.credits < amount)
        .opacity(store.credits < amount ? 0.35 : 1)
    }

    private func next() {
        guard !markets.isEmpty else { return }
        withAnimation(.easeOut(duration: 0.22)) { index = (index + 1) % markets.count }
    }
}

// MARK: - Invest

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
                    Text("📈 INVESTIR").font(.system(size: 10, weight: .black, design: .rounded)).tracking(1.2).foregroundStyle(Color.konsensBlue)
                    Text("Fais jouer le réel.").font(.system(size: 31, weight: .black, design: .rounded))
                    Text("Choisis un actif, engage tes Koins et regarde ton patrimoine évoluer avec le marché.").font(.caption).foregroundStyle(Color.konsensMuted)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 9) {
                        ForEach(store.assets) { asset in
                            Button { selectedID = asset.id } label: {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(asset.symbol).font(.headline.monospaced().bold())
                                    Text(asset.name).font(.caption2).lineLimit(1).foregroundStyle(Color.konsensMuted)
                                }
                                .frame(width: 112, alignment: .leading)
                                .padding(13)
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
                                Text(selected.name).font(.system(size: 20, weight: .bold, design: .rounded))
                                Text(selected.kind.uppercased()).font(.caption2.bold()).foregroundStyle(Color.konsensMuted)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(String(format: selected.price >= 1000 ? "%.0f" : "%.2f", selected.price)).font(.title2.monospacedDigit().bold())
                                Text(selected.currency).font(.caption2).foregroundStyle(Color.konsensMuted)
                            }
                        }

                        Text("Tu n’achètes rien de réel : Konsens reproduit l’impact de ce choix sur ton score.")
                            .font(.caption).foregroundStyle(Color.white.opacity(0.72))

                        HStack(spacing: 7) {
                            ForEach([50, 100, 250, 500], id: \.self) { value in
                                Button("\(value) K") { amount = value }
                                    .font(.caption.bold())
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 9)
                                    .background(amount == value ? Color.konsensBlue : Color.white.opacity(0.05), in: Capsule())
                            }
                        }

                        Button {
                            Task { await store.buyAsset(selected, amount: amount) }
                        } label: {
                            HStack {
                                Image(systemName: "rocket.fill")
                                Text("ENGAGER \(amount) K")
                                Spacer()
                                Text("GO")
                            }
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .padding(15)
                            .foregroundStyle(Color.black)
                            .background(Color.konsensGreen, in: RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                        .disabled(store.credits < amount)
                        .opacity(store.credits < amount ? 0.35 : 1)
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
            .padding(.horizontal, 18)
            .padding(.top, 106)
            .padding(.bottom, 112)
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 13))
    }
}

// MARK: - League

struct LeagueSocialView: View {
    @EnvironmentObject private var store: AppStore
    @State private var leaders: [Leader] = []
    @State private var reactions: [LeagueReaction] = []
    @State private var leagueName = "Ligue Flash"
    @State private var sending = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("🏆 \(leagueName.uppercased())").font(.system(size: 10, weight: .black, design: .rounded)).foregroundStyle(Color.konsensGold)
                    Text("Passe devant. Fais-le savoir.").font(.system(size: 30, weight: .black, design: .rounded))
                    Text("Le classement suit ton patrimoine. Les réactions restent courtes et bon enfant.").font(.caption).foregroundStyle(Color.konsensMuted)
                }

                VStack(spacing: 8) {
                    ForEach(leaders) { leader in
                        HStack(spacing: 10) {
                            Text("#\(leader.rank)").font(.headline.monospacedDigit().bold()).foregroundStyle(leader.rank <= 3 ? Color.konsensGold : Color.konsensMuted).frame(width: 36, alignment: .leading)
                            Circle()
                                .fill(leader.isCurrentUser ? Color.konsensGreen : Color.konsensViolet.opacity(0.65))
                                .frame(width: 38, height: 38)
                                .overlay(Text(leader.initials).font(.caption.bold()))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(leader.isCurrentUser ? "\(leader.name) · TOI" : leader.name)
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(leader.isCurrentUser ? Color.konsensGreen : .white)
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
            .padding(.horizontal, 18)
            .padding(.top, 106)
            .padding(.bottom, 112)
        }
        .refreshable { await load() }
        .task { await load() }
    }

    @MainActor
    private func load() async {
        let bundle = await fetchLeagueBundle(store: store)
        leaders = bundle.leaders
        reactions = bundle.reactions
        leagueName = bundle.name
    }

    @MainActor
    private func sendReaction(to target: UUID, emoji: String) async {
        sending = true
        struct Params: Encodable { let p_target: UUID; let p_reaction: String }
        do {
            _ = try await store.supabase.rpc("send_league_reaction", params: Params(p_target: target, p_reaction: emoji)).execute()
            store.showToast("\(emoji) envoyé dans la ligue")
            await load()
        } catch {
            store.showToast("Réaction indisponible")
        }
        sending = false
    }

    private func relativeDate(_ date: Date) -> String {
        let seconds = max(0, Date().timeIntervalSince(date))
        if seconds < 60 { return "à l’instant" }
        if seconds < 3600 { return "il y a \(Int(seconds / 60)) min" }
        if seconds < 86400 { return "il y a \(Int(seconds / 3600)) h" }
        return "il y a \(Int(seconds / 86400)) j"
    }
}

// MARK: - Rewarded daily ad

private struct RewardedDailyAdView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let onClaimed: () -> Void

    @State private var ad: SponsoredAd?
    @State private var impressionID: Int64?
    @State private var secondsLeft = 4
    @State private var ready = false
    @State private var claiming = false
    @State private var message: String?
    private let sessionID = UUID().uuidString

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.10, green: 0.04, blue: 0.18), Color.konsensBackground], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("RÉCOMPENSE DU JOUR").font(.caption.bold()).foregroundStyle(Color.konsensGold)
                    Spacer()
                    Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").font(.title2) }.foregroundStyle(Color.konsensMuted)
                }

                Spacer()
                Image(systemName: "play.rectangle.fill").font(.system(size: 58)).foregroundStyle(Color.konsensGold)

                if let ad {
                    Text(ad.eyebrow.uppercased()).font(.caption2.bold()).foregroundStyle(Color.konsensMuted)
                    Text(ad.headline).font(.system(size: 29, weight: .black, design: .rounded))
                    if let body = ad.body { Text(body).font(.subheadline).foregroundStyle(Color.white.opacity(0.72)) }
                    Text("Présenté par \(ad.sponsorName)").font(.caption.bold()).foregroundStyle(Color.konsensViolet)
                } else if let message {
                    Text("Spot indisponible").font(.system(size: 20, weight: .bold, design: .rounded))
                    Text(message).font(.caption).foregroundStyle(Color.konsensMuted)
                } else {
                    ProgressView("Chargement du sponsor…").tint(Color.konsensGold)
                }

                Spacer()

                Button { Task { await claim() } } label: {
                    HStack {
                        if claiming { ProgressView().tint(.black) }
                        Image(systemName: ready ? "gift.fill" : "clock.fill")
                        Text(ready ? "ENCAISSER +100 K" : "PATIENTE \(secondsLeft) s")
                        Spacer()
                    }
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .padding(15)
                    .foregroundStyle(ready ? Color.black : Color.konsensMuted)
                    .background(ready ? Color.konsensGold : Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .disabled(!ready || claiming || impressionID == nil)

                Text("Le crédit est accordé une seule fois par jour après validation du spot sponsorisé côté serveur.")
                    .font(.caption2).foregroundStyle(Color.konsensMuted)
            }
            .padding(22)
        }
        .task { await loadAd() }
    }

    @MainActor
    private func loadAd() async {
        struct Params: Encodable { let p_placement: String; let p_session_id: String }
        struct Row: Decodable {
            let campaign_id: UUID
            let creative_id: UUID
            let sponsor_name: String
            let eyebrow: String
            let headline: String
            let body: String?
            let cta_label: String
            let destination_url: String
            let placement: String
        }
        struct Track: Encodable {
            let p_campaign_id: UUID
            let p_creative_id: UUID
            let p_event_type: String
            let p_placement: String
            let p_session_id: String
        }

        do {
            let rows: [Row] = try await store.supabase.rpc("get_active_ad", params: Params(p_placement: "rewarded_daily", p_session_id: sessionID)).execute().value
            guard let row = rows.first else {
                message = "Aucune campagne récompensée n’est active."
                return
            }

            let loaded = SponsoredAd(
                campaignID: row.campaign_id,
                id: row.creative_id,
                sponsorName: row.sponsor_name,
                eyebrow: row.eyebrow,
                headline: row.headline,
                body: row.body,
                ctaLabel: row.cta_label,
                destinationURL: row.destination_url,
                placement: row.placement
            )
            ad = loaded

            let eventID: Int64 = try await store.supabase.rpc(
                "track_ad_event",
                params: Track(
                    p_campaign_id: loaded.campaignID,
                    p_creative_id: loaded.id,
                    p_event_type: "impression",
                    p_placement: "rewarded_daily",
                    p_session_id: sessionID
                )
            ).execute().value
            impressionID = eventID

            for remaining in stride(from: 4, through: 1, by: -1) {
                secondsLeft = remaining
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            secondsLeft = 0
            ready = true
        } catch {
            message = "Le module sponsorisé doit être activé côté serveur avant la collecte."
        }
    }

    @MainActor
    private func claim() async {
        guard let impressionID else { return }
        struct Params: Encodable { let p_ad_event_id: Int64 }
        struct Row: Decodable { let claimed: Bool; let amount: Int; let balance: Double; let streak: Int }

        claiming = true
        do {
            let rows: [Row] = try await store.supabase.rpc("claim_daily_reward", params: Params(p_ad_event_id: impressionID)).execute().value
            if let row = rows.first {
                store.showToast(row.claimed ? "+\(row.amount) Koins · série \(row.streak) 🔥" : "Drop déjà récupéré aujourd’hui")
            }
            onClaimed()
            dismiss()
        } catch {
            store.showToast("Impossible de créditer le drop")
        }
        claiming = false
    }
}

// MARK: - Data loaders

private struct LeagueBundle {
    let leaders: [Leader]
    let reactions: [LeagueReaction]
    let name: String
}

@MainActor
private func fetchDailyRewardStatus(store: AppStore) async -> Bool {
    struct Row: Decodable { let claimable: Bool; let amount: Int; let claimed_at: String? }
    do {
        let rows: [Row] = try await store.supabase.rpc("get_my_daily_reward_status").execute().value
        return rows.first?.claimable ?? true
    } catch {
        return true
    }
}

@MainActor
private func fetchLeagueBundle(store: AppStore) async -> LeagueBundle {
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
        let rows: [LeaderRow] = try await store.supabase.rpc("get_my_league_leaderboard", params: Limit(p_limit: 20)).execute().value
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
        let rows: [ReactionRow] = try await store.supabase.rpc("get_my_league_reactions", params: Limit(p_limit: 20)).execute().value
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
        leaders = [Leader(id: userID, rank: 1, name: store.username, initials: String(store.username.prefix(1)).uppercased(), score: store.wealth.total, isCurrentUser: true)]
    }

    return LeagueBundle(leaders: leaders, reactions: reactions, name: leagueName)
}

// MARK: - Preserved Premium finance home

struct FinanceLegacyHomeView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 7) {
                    Eyebrow(text: "MODE FINANCE PRO")
                    Text("Bonjour \(store.username).").font(.system(size: 36, weight: .bold, design: .rounded))
                    Text("Analyse ton patrimoine avec l’interface financière complète.").font(.subheadline).foregroundStyle(Color.konsensMuted)
                }

                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Eyebrow(text: "PATRIMOINE TOTAL")
                        Spacer()
                        Text(String(format: "%+.1f%%", store.wealth.performance))
                            .font(.caption.monospacedDigit().bold())
                            .foregroundStyle(store.wealth.performance >= 0 ? Color.konsensPositive : Color.konsensNegative)
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                        Text(String(format: "%.0f", store.wealth.total)).font(.system(size: 43, weight: .bold, design: .rounded)).monospacedDigit()
                        Text("Koins").font(.caption).foregroundStyle(Color.konsensMuted)
                    }
                    HStack(spacing: 8) {
                        PremiumMetric(title: "Disponible", value: store.wealth.cash)
                        PremiumMetric(title: "Investi", value: store.wealth.investments)
                        PremiumMetric(title: "Paris", value: store.wealth.bets)
                    }
                }
                .panel()

                HStack(spacing: 10) {
                    GameShortcut(title: "Marchés", detail: "Interface détaillée", icon: "bolt.horizontal.fill", tint: Color.konsensViolet) { store.selectedTab = .play }
                    GameShortcut(title: "Investir", detail: "Graphiques & API", icon: "chart.xyaxis.line", tint: Color.konsensBlue) { store.selectedTab = .invest }
                }
                GameShortcut(title: "Academy", detail: "Cours et quiz", icon: "graduationcap.fill", tint: Color.konsensGreen) { store.selectedTab = .learn }
            }
            .padding(.horizontal, 18)
            .padding(.top, 104)
            .padding(.bottom, 112)
        }
        .refreshable { await store.refreshFinance() }
    }
}

private struct PremiumMetric: View {
    let title: String
    let value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased()).font(.system(size: 7, weight: .bold)).foregroundStyle(Color.konsensMuted)
            Text(String(format: "%.0f", value)).font(.subheadline.monospacedDigit().bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
    }
}
