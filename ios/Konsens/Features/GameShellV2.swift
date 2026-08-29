import SwiftUI
import LocalAuthentication

// MARK: - Lean game shell

struct KonsensGameRootView: View {
    @EnvironmentObject private var store: AppStore
    @ObservedObject private var notifications = NotificationManager.shared
    @AppStorage("konsens_finance_pro_enabled") private var financeProEnabled = false
    @StateObject private var banter = KonsensBanterDirector()
    @State private var unlocked = false
    @State private var biometricAttempted = false

    private var isFinancePro: Bool {
        financeProEnabled && store.subscriptionTier == "premium"
    }

    var body: some View {
        ZStack {
            LeanBackdrop(tab: store.selectedTab, financePro: isFinancePro)
                .ignoresSafeArea()

            if store.isLoading {
                ProgressView().tint(Color.konsensGreen)
            } else if !store.isAuthenticated {
                AuthView()
            } else if !store.onboardingComplete {
                NativeOnboardingView()
            } else if !unlocked {
                LeanLockedView(unlock: unlock)
            } else {
                gameCockpit
            }

            if let toast = store.toast {
                VStack {
                    Spacer()
                    Text(toast)
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 10)
                        .background(Color.konsensPanelRaised.opacity(0.96), in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.08)))
                        .padding(.bottom, 94)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(80)
            }

            if store.isAuthenticated && store.onboardingComplete && unlocked && !isFinancePro {
                KonsensBanterOverlay(director: banter)
                    .zIndex(90)
            }
        }
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.2), value: store.selectedTab)
        .onChange(of: store.isAuthenticated) { _, authenticated in
            if !authenticated {
                unlocked = false
                biometricAttempted = false
                notifications.stop()
                banter.stop()
            }
        }
        .onChange(of: unlocked) { _, value in
            guard value, store.isAuthenticated, store.onboardingComplete, !isFinancePro else { return }
            banter.start(username: store.username)
        }
        .onChange(of: financeProEnabled) { _, enabled in
            if enabled && store.subscriptionTier != "premium" {
                financeProEnabled = false
            }
            if enabled && store.selectedTab == .league { store.selectedTab = .wealth }
            if enabled {
                banter.stop()
            } else if unlocked && store.isAuthenticated && store.onboardingComplete {
                banter.start(username: store.username)
            }
        }
        .onChange(of: store.selectedTab) { _, tab in
            guard unlocked, !isFinancePro else { return }
            banter.navigation(tab)
        }
        .onChange(of: store.wealth.total) { oldValue, newValue in
            guard unlocked, !isFinancePro, oldValue > 0 else { return }
            let delta = newValue - oldValue
            guard abs(delta) >= 5 else { return }
            banter.wealth(delta: Int(delta.rounded()))
        }
        .onChange(of: store.toast) { _, toast in
            guard unlocked, !isFinancePro, let toast else { return }
            if toast.contains("Position Play enregistrée") {
                banter.say(["Mise posée. Maintenant, assume.", "Ça y est. Tu l’as vraiment fait.", "Je note ce choix. Pour le dossier."].randomElement()!)
            } else if toast.localizedCaseInsensitiveContains("ordre refusé") || toast.localizedCaseInsensitiveContains("solde") {
                banter.say("Même moi, je ne peux pas miser des Koins que tu n’as pas.")
            }
        }
        .onOpenURL { route($0) }
        .task {
            if store.isAuthenticated && store.onboardingComplete {
                notifications.start(store: store)
                WatchBridge.shared.start()
                if !biometricAttempted { unlock() }
                if unlocked && !isFinancePro { banter.start(username: store.username) }
            }
        }
    }

    @ViewBuilder
    private var gameCockpit: some View {
        ZStack {
            Group {
                switch store.selectedTab {
                case .wealth:
                    if isFinancePro { FinanceLegacyHomeView() } else { GameHomeV2() }
                case .play:
                    if isFinancePro { MarketsView() } else { GamePlayV2() }
                case .invest:
                    if isFinancePro { LeagueView() } else { GameInvestV2() }
                case .league:
                    LeagueSocialView()
                case .learn:
                    if isFinancePro { AcademyNativeView() } else { GameHomeV2() }
                case .profile:
                    GameProfileV2()
                }
            }

            VStack(spacing: 0) {
                LeanHeader(financePro: isFinancePro, notifications: notifications)
                Spacer()
                LeanDock(financePro: isFinancePro)
            }
            .padding(.horizontal, 12)
            .padding(.top, 7)
            .padding(.bottom, 7)
        }
    }

    private func route(_ url: URL) {
        let destination = (url.host ?? url.path.replacingOccurrences(of: "/", with: "")).lowercased()
        switch destination {
        case "play", "bet": store.selectedTab = .play
        case "invest", "finance": store.selectedTab = .invest
        case "league": store.selectedTab = .league
        case "profile", "notifications", "blockchain": store.selectedTab = .profile
        case "learn", "academy": store.selectedTab = isFinancePro ? .learn : .wealth
        default: store.selectedTab = .wealth
        }
    }

    private func unlock() {
        biometricAttempted = true
        let context = LAContext()
        context.localizedCancelTitle = "Plus tard"
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            unlocked = true
            return
        }
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Déverrouiller Konsens") { success, _ in
            DispatchQueue.main.async { unlocked = success }
        }
    }
}

private struct LeanBackdrop: View {
    let tab: AppTab
    let financePro: Bool

    var body: some View {
        ZStack {
            Color.konsensBackground
            RadialGradient(
                colors: [accent.opacity(financePro ? 0.12 : 0.16), .clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 420
            )
        }
    }

    private var accent: Color {
        if financePro { return Color.konsensBlue }
        switch tab {
        case .wealth, .play, .profile: return Color.konsensViolet
        case .invest: return Color.konsensBlue
        case .league: return Color.konsensGold
        case .learn: return Color.konsensGreen
        }
    }
}

private struct LeanHeader: View {
    @EnvironmentObject private var store: AppStore
    let financePro: Bool
    @ObservedObject var notifications: NotificationManager

    var body: some View {
        HStack(spacing: 10) {
            Button { store.selectedTab = .wealth } label: {
                Text("KONSENS")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .tracking(0.4)
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: 5) {
                if !financePro, store.streak > 0 {
                    Text("🔥\(store.streak)")
                        .font(.caption.bold())
                        .foregroundStyle(Color.konsensGold)
                }
                Text(String(format: "%.0f K", store.wealth.total))
                    .font(.subheadline.monospacedDigit().bold())
                    .foregroundStyle(financePro ? Color.konsensBlue : Color.konsensGreen)
            }

            Button { store.selectedTab = .profile } label: {
                ZStack {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.white.opacity(0.82))
                    if notifications.unreadCount > 0 {
                        Circle()
                            .fill(Color.konsensViolet)
                            .frame(width: 7, height: 7)
                            .offset(x: 9, y: -9)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(Color.konsensPanel.opacity(0.86), in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.06)))
    }
}

private struct LeanDock: View {
    @EnvironmentObject private var store: AppStore
    let financePro: Bool

    private var tabs: [AppTab] { financePro ? AppTab.financeTabs : AppTab.gameTabs }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.self) { tab in
                Button {
                    withAnimation(.easeOut(duration: 0.16)) { store.selectedTab = tab }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 17, weight: store.selectedTab == tab ? .bold : .medium))
                        Text(tab.title)
                            .font(.system(size: 7, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(store.selectedTab == tab ? accent(tab) : Color.konsensMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 5)
        .background(Color.konsensPanel.opacity(0.94), in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.07)))
    }

    private func accent(_ tab: AppTab) -> Color {
        if financePro { return Color.konsensBlue }
        switch tab {
        case .wealth: return Color.konsensGreen
        case .play: return Color.konsensViolet
        case .invest: return Color.konsensBlue
        case .league: return Color.konsensGold
        case .profile: return Color.konsensViolet
        case .learn: return Color.konsensGreen
        }
    }
}

private struct LeanLockedView: View {
    let unlock: () -> Void

    var body: some View {
        VStack(spacing: 15) {
            Text("KONSENS")
                .font(.system(size: 30, weight: .black, design: .rounded))
            Image(systemName: "faceid")
                .font(.system(size: 45))
                .foregroundStyle(Color.konsensGreen)
            Button("Déverrouiller", action: unlock)
                .font(.headline.bold())
                .foregroundStyle(Color.black)
                .padding(.horizontal, 22)
                .padding(.vertical, 12)
                .background(Color.konsensGreen, in: Capsule())
        }
    }
}

// MARK: - Home: one loop, one priority

private struct GameHomeV2: View {
    @EnvironmentObject private var store: AppStore
    @State private var rank = 0
    @State private var leagueName = "Ligue Flash"
    @State private var playerAhead: String?

    private var featured: Market? {
        let fun = store.markets.filter { !["macro", "finance", "bourse"].contains($0.category.lowercased()) }
        return (fun.isEmpty ? store.markets : fun).first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                scoreStrip

                if let featured {
                    challengeHero(featured)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("PROCHAIN CHALLENGE")
                            .font(.caption2.bold())
                            .foregroundStyle(Color.konsensViolet)
                        Text("Ça arrive.")
                            .font(.system(size: 27, weight: .black, design: .rounded))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(Color.konsensPanelRaised, in: RoundedRectangle(cornerRadius: 22))
                }

                Button { store.selectedTab = .play } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("JOUER MAINTENANT")
                                .font(.system(size: 18, weight: .black, design: .rounded))
                            Text(store.subscriptionTier == "premium" ? "Sans pub" : "Pub courte avant la mise")
                                .font(.caption2.bold())
                                .foregroundStyle(Color.black.opacity(0.58))
                        }
                        Spacer()
                        Image(systemName: "bolt.fill").font(.title2)
                    }
                    .foregroundStyle(Color.black)
                    .padding(16)
                    .background(Color.konsensGreen, in: RoundedRectangle(cornerRadius: 18))
                }
                .buttonStyle(.plain)

                leagueStrip
            }
            .padding(.horizontal, 17)
            .padding(.top, 74)
            .padding(.bottom, 96)
        }
        .refreshable {
            await store.refreshFinance()
            await loadLeague()
        }
        .task { await loadLeague() }
    }

    private var scoreStrip: some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: "%.0f K", store.wealth.total))
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .monospacedDigit()
                Text(rank > 0 ? "#\(rank) · \(leagueName)" : leagueName)
                    .font(.caption.bold())
                    .foregroundStyle(Color.konsensMuted)
            }
            Spacer()
            if store.streak > 0 {
                Text("🔥 \(store.streak)")
                    .font(.headline.bold())
                    .foregroundStyle(Color.konsensGold)
            }
        }
    }

    private func challengeHero(_ market: Market) -> some View {
        Button { store.selectedTab = .play } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("À TOI DE JOUER")
                        .font(.caption2.bold())
                        .tracking(0.8)
                        .foregroundStyle(Color.konsensGreen)
                    Spacer()
                    Text(market.category.uppercased())
                        .font(.system(size: 7, weight: .black, design: .rounded))
                        .foregroundStyle(Color.konsensMuted)
                }

                Text(market.question)
                    .font(.system(size: 27, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(4)
                    .minimumScaleFactor(0.82)

                HStack {
                    Text("\(market.yesProbability)% disent OUI")
                        .font(.caption.bold())
                        .foregroundStyle(Color.white.opacity(0.62))
                    Spacer()
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.konsensViolet)
                }
            }
            .padding(20)
            .background(Color.konsensPanelRaised.opacity(0.98), in: RoundedRectangle(cornerRadius: 23))
            .overlay(RoundedRectangle(cornerRadius: 23).stroke(Color.konsensViolet.opacity(0.22)))
        }
        .buttonStyle(.plain)
    }

    private var leagueStrip: some View {
        Button { store.selectedTab = .league } label: {
            HStack(spacing: 12) {
                Image(systemName: "trophy.fill")
                    .font(.title3)
                    .foregroundStyle(Color.konsensGold)
                VStack(alignment: .leading, spacing: 2) {
                    Text("TA LIGUE")
                        .font(.caption2.bold())
                        .foregroundStyle(Color.konsensGold)
                    Text(playerAhead.map { "Rattrape @\($0)." } ?? "Prends la tête et chambre-les.")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(Color.konsensMuted)
            }
            .padding(15)
            .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }

    @MainActor
    private func loadLeague() async {
        struct Params: Encodable { let p_limit: Int }
        struct Row: Decodable {
            let position: Int
            let username: String
            let is_current_user: Bool
            let league_name: String
        }
        let rows: [Row] = (try? await store.supabase.rpc("get_my_league_leaderboard", params: Params(p_limit: 20)).execute().value) ?? []
        if let me = rows.first(where: { $0.is_current_user }) {
            rank = me.position
            leagueName = me.league_name
            playerAhead = rows.first(where: { $0.position == me.position - 1 })?.username
        }
    }
}

// MARK: - Play: question first, ad gate second

private struct GamePlayV2: View {
    @EnvironmentObject private var store: AppStore
    @ObservedObject private var ads = AdsService.shared
    @State private var index = 0
    @State private var amount = 50
    @State private var submitting = false

    private var markets: [Market] {
        let fun = store.markets.filter { !["macro", "finance", "bourse"].contains($0.category.lowercased()) }
        return fun.isEmpty ? store.markets : fun
    }

    private var current: Market? {
        guard !markets.isEmpty else { return nil }
        return markets[min(index, markets.count - 1)]
    }

    private var adsDisabled: Bool { store.subscriptionTier == "premium" }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("MISER")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundStyle(Color.konsensViolet)
                        Spacer()
                        if adsDisabled {
                            Text("SANS PUB")
                                .font(.caption2.bold())
                                .foregroundStyle(Color.konsensGreen)
                        } else {
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(ads.rewardedReady ? Color.konsensPositive : Color.konsensGold)
                                    .frame(width: 6, height: 6)
                                Text(ads.rewardedReady ? "PUB PRÊTE" : "PUB EN CHARGEMENT")
                                    .font(.system(size: 7, weight: .black, design: .rounded))
                                    .foregroundStyle(Color.konsensMuted)
                            }
                        }
                    }

                    if let current {
                        VStack(alignment: .leading, spacing: 18) {
                            HStack {
                                Text(current.category.uppercased())
                                    .font(.caption2.bold())
                                    .foregroundStyle(Color.konsensGreen)
                                Spacer()
                                Text("\(current.yesProbability)% OUI")
                                    .font(.caption.monospacedDigit().bold())
                                    .foregroundStyle(Color.konsensMuted)
                            }

                            Text(current.question)
                                .font(.system(size: 31, weight: .black, design: .rounded))
                                .minimumScaleFactor(0.76)
                                .fixedSize(horizontal: false, vertical: true)

                            stakePicker

                            HStack(spacing: 10) {
                                choiceButton("NON", color: Color.konsensNegative) { submit("no") }
                                choiceButton("OUI", color: Color.konsensPositive) { submit("yes") }
                            }
                        }
                        .padding(19)
                        .background(Color.konsensPanelRaised.opacity(0.98), in: RoundedRectangle(cornerRadius: 23))
                        .overlay(RoundedRectangle(cornerRadius: 23).stroke(Color.konsensViolet.opacity(0.20)))

                        HStack {
                            Text("\(min(index + 1, markets.count)) / \(markets.count)")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(Color.konsensMuted)
                            Spacer()
                            Button("PASSER") { next() }
                                .font(.caption.bold())
                                .foregroundStyle(Color.konsensMuted)
                        }
                    } else {
                        Text("Les prochains défis arrivent.")
                            .font(.title2.bold())
                    }
                }
                .padding(.horizontal, 17)
                .padding(.top, 74)
                .padding(.bottom, 98)
            }
        }
        .task { if !adsDisabled { await ads.loadRewarded() } }
    }

    private var stakePicker: some View {
        HStack(spacing: 7) {
            ForEach([25, 50, 100, 250], id: \.self) { value in
                Button("\(value) K") { amount = value }
                    .font(.caption.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .foregroundStyle(amount == value ? Color.black : Color.white)
                    .background(amount == value ? Color.konsensGold : Color.white.opacity(0.05), in: Capsule())
            }
        }
    }

    private func choiceButton(_ title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 19, weight: .black, design: .rounded))
                if !adsDisabled {
                    Text("REGARDER LA PUB & MISER")
                        .font(.system(size: 6, weight: .black, design: .rounded))
                        .opacity(0.76)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(.white)
            .background(color, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .disabled(submitting || store.credits < amount)
        .opacity((submitting || store.credits < amount) ? 0.38 : 1)
    }

    private func submit(_ outcome: String) {
        guard let market = current, !submitting else { return }
        guard store.credits >= amount else {
            store.showToast("Pas assez de Koins")
            return
        }

        let bet = {
            submitting = true
            Task { @MainActor in
                await store.bet(market, outcome: outcome, amount: amount)
                submitting = false
                next()
            }
        }

        if adsDisabled {
            bet()
            return
        }

        guard ads.presentRewarded(onReward: bet) else {
            store.showToast("La pub se charge… réessaie dans un instant")
            Task { await ads.loadRewarded(force: true) }
            return
        }
    }

    private func next() {
        guard !markets.isEmpty else { return }
        withAnimation(.easeOut(duration: 0.17)) { index = (index + 1) % markets.count }
    }
}

// MARK: - Invest: reduced friction

private struct GameInvestV2: View {
    @EnvironmentObject private var store: AppStore
    @State private var selectedID: UUID?
    @State private var amount = 100

    private var selected: AssetQuote? {
        if let selectedID { return store.assets.first(where: { $0.id == selectedID }) }
        return store.assets.first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Text("INVESTIR")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(Color.konsensBlue)
                    Spacer()
                    Text(String(format: "%.0f K DISPO", store.wealth.cash))
                        .font(.caption.monospacedDigit().bold())
                        .foregroundStyle(Color.konsensGold)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(store.assets) { asset in
                            Button { selectedID = asset.id } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(asset.symbol).font(.headline.monospaced().bold())
                                    Text(asset.name).font(.caption2).lineLimit(1).foregroundStyle(Color.konsensMuted)
                                }
                                .frame(width: 104, alignment: .leading)
                                .padding(12)
                                .background(selected?.id == asset.id ? Color.konsensBlue.opacity(0.18) : Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 15))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if let selected {
                    VStack(alignment: .leading, spacing: 17) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(selected.name)
                                    .font(.system(size: 26, weight: .black, design: .rounded))
                                Text(selected.kind.uppercased())
                                    .font(.caption2.bold())
                                    .foregroundStyle(Color.konsensMuted)
                            }
                            Spacer()
                            Text(String(format: selected.price >= 1000 ? "%.0f" : "%.2f", selected.price))
                                .font(.title3.monospacedDigit().bold())
                        }

                        HStack(spacing: 7) {
                            ForEach([50, 100, 250, 500], id: \.self) { value in
                                Button("\(value) K") { amount = value }
                                    .font(.caption.bold())
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 9)
                                    .foregroundStyle(amount == value ? Color.black : .white)
                                    .background(amount == value ? Color.konsensBlue : Color.white.opacity(0.05), in: Capsule())
                            }
                        }

                        Button {
                            Task { await store.buyAsset(selected, amount: amount) }
                        } label: {
                            HStack {
                                Text("ENGAGER \(amount) K")
                                Spacer()
                                Image(systemName: "arrow.up.right")
                            }
                            .font(.system(size: 17, weight: .black, design: .rounded))
                            .padding(15)
                            .foregroundStyle(Color.black)
                            .background(Color.konsensGreen, in: RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                        .disabled(store.credits < amount)
                        .opacity(store.credits < amount ? 0.38 : 1)
                    }
                    .padding(19)
                    .background(Color.konsensPanelRaised.opacity(0.98), in: RoundedRectangle(cornerRadius: 22))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.konsensBlue.opacity(0.18)))
                }
            }
            .padding(.horizontal, 17)
            .padding(.top, 74)
            .padding(.bottom, 98)
        }
    }
}

// MARK: - Profile: game essentials only

private struct GameProfileV2: View {
    @EnvironmentObject private var store: AppStore
    @ObservedObject private var notifications = NotificationManager.shared
    @AppStorage("konsens_finance_pro_enabled") private var financeProEnabled = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("@\(store.username)")
                            .font(.system(size: 27, weight: .black, design: .rounded))
                        Text(String(format: "%.0f K · 🔥 %d", store.wealth.total, store.streak))
                            .font(.caption.monospacedDigit().bold())
                            .foregroundStyle(Color.konsensMuted)
                    }
                    Spacer()
                }

                premiumCard
                modeCard
                notificationCard
                securityCard

                Button(role: .destructive) {
                    Task { await store.signOut() }
                } label: {
                    Text("SE DÉCONNECTER")
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity)
                        .padding(13)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.konsensNegative)
                .background(Color.konsensNegative.opacity(0.07), in: RoundedRectangle(cornerRadius: 15))
            }
            .padding(.horizontal, 17)
            .padding(.top, 74)
            .padding(.bottom, 98)
        }
        .onChange(of: store.subscriptionTier) { _, tier in
            if tier != "premium" { financeProEnabled = false }
        }
    }

    private var premiumCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("KONSENS+" )
                        .font(.caption2.bold())
                        .foregroundStyle(Color.konsensGold)
                    Text(store.subscriptionTier == "premium" ? "Zéro pub. Jeu instantané." : "Passe en mode sans pub")
                        .font(.headline.bold())
                }
                Spacer()
                Image(systemName: "crown.fill").foregroundStyle(Color.konsensGold)
            }

            if store.subscriptionTier != "premium" {
                Button {
                    Task { await store.startPremiumTrial() }
                } label: {
                    Text("TESTER SANS PUB")
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity)
                        .padding(11)
                        .foregroundStyle(Color.black)
                        .background(Color.konsensGold, in: RoundedRectangle(cornerRadius: 13))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color.konsensGold.opacity(0.07), in: RoundedRectangle(cornerRadius: 19))
        .overlay(RoundedRectangle(cornerRadius: 19).stroke(Color.konsensGold.opacity(0.15)))
    }

    private var modeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("INTERFACE")
                .font(.caption2.bold())
                .foregroundStyle(Color.konsensMuted)

            Button {
                financeProEnabled = false
                store.selectedTab = .wealth
            } label: {
                modeLine(icon: "gamecontroller.fill", title: "Jeu", selected: !financeProEnabled, color: Color.konsensViolet)
            }
            .buttonStyle(.plain)

            Button {
                guard store.subscriptionTier == "premium" else {
                    store.showToast("Mode Finance Pro réservé à Konsens+")
                    return
                }
                financeProEnabled = true
                store.selectedTab = .wealth
            } label: {
                modeLine(icon: "chart.xyaxis.line", title: "Finance Pro", selected: financeProEnabled && store.subscriptionTier == "premium", color: Color.konsensBlue)
            }
            .buttonStyle(.plain)
        }
        .padding(15)
        .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 18))
    }

    private var notificationCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Image(systemName: "bell.fill").foregroundStyle(Color.konsensViolet)
                Text("Notifications de ligue").font(.subheadline.bold())
                Spacer()
                if notifications.unreadCount > 0 {
                    Text("\(notifications.unreadCount)").font(.caption.bold()).foregroundStyle(Color.konsensViolet)
                }
            }

            if notifications.authorization != .authorized {
                Button("ACTIVER") {
                    Task { await notifications.requestPermission(store: store) }
                }
                .font(.caption.bold())
                .foregroundStyle(Color.konsensGreen)
            }
        }
        .padding(15)
        .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 18))
    }

    private var securityCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "faceid").foregroundStyle(Color.konsensGreen)
            VStack(alignment: .leading, spacing: 2) {
                Text("Face ID actif").font(.subheadline.bold())
                Text("Koins fictifs · aucun argent réel")
                    .font(.caption2)
                    .foregroundStyle(Color.konsensMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 18))
    }

    private func modeLine(icon: String, title: String, selected: Bool, color: Color) -> some View {
        HStack {
            Image(systemName: icon).foregroundStyle(color).frame(width: 28)
            Text(title).font(.subheadline.bold())
            Spacer()
            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(selected ? Color.konsensGreen : Color.konsensMuted)
        }
        .padding(.vertical, 5)
        .foregroundStyle(.white)
    }
}

// MARK: - Mascot: text only

@MainActor
private final class KonsensBanterDirector: ObservableObject {
    @Published var text: String?
    @Published var id = UUID()

    private var started = false
    private var randomTask: Task<Void, Never>?
    private var hideTask: Task<Void, Never>?

    func start(username: String) {
        guard !started else { return }
        started = true
        say("Salut @\(username). Fais-moi au moins croire que tu as un plan.", duration: 3)
        randomTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 45_000_000_000)
            while !Task.isCancelled {
                guard let self else { return }
                self.say([
                    "Ton classement ne va pas monter tout seul.",
                    "Tu réfléchis vraiment ou c’est pour le suspense ?",
                    "Quelqu’un dans ta ligue est probablement en train de te dépasser.",
                    "Je dis ça, je dis rien… mais tes Koins s’ennuient.",
                    "Un bon coup et tu pourras recommencer à chambrer."
                ].randomElement()!)
                let delay = UInt64(Int.random(in: 55...95))
                try? await Task.sleep(nanoseconds: delay * 1_000_000_000)
            }
        }
    }

    func stop() {
        started = false
        randomTask?.cancel()
        hideTask?.cancel()
        randomTask = nil
        hideTask = nil
        text = nil
    }

    func navigation(_ tab: AppTab) {
        switch tab {
        case .play: say("Ah. Là on joue.", duration: 2)
        case .invest: say("Investir ? Essaie de faire semblant d’avoir une stratégie.", duration: 2.4)
        case .league: say("Le classement. J’espère que tu n’as pas besoin de descendre trop bas.", duration: 2.6)
        case .wealth: break
        case .profile: break
        case .learn: break
        }
    }

    func wealth(delta: Int) {
        if delta > 0 {
            say("+\(delta) K. Là, tu deviens presque fréquentable.")
        } else {
            say("\(delta) K. On va faire comme si personne n’avait vu ça.")
        }
    }

    func say(_ line: String, duration: Double = 3.0) {
        hideTask?.cancel()
        id = UUID()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) { text = line }
        let current = id
        hideTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard let self, self.id == current else { return }
            withAnimation(.easeOut(duration: 0.2)) { self.text = nil }
        }
    }
}

private struct KonsensBanterOverlay: View {
    @ObservedObject var director: KonsensBanterDirector

    var body: some View {
        VStack {
            if let text = director.text {
                HStack(spacing: 8) {
                    Text("K")
                        .font(.caption.weight(.black))
                        .foregroundStyle(Color.black)
                        .frame(width: 25, height: 25)
                        .background(Color.konsensGold, in: Circle())
                    Text(text)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.konsensPanelRaised.opacity(0.97), in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.konsensGold.opacity(0.18)))
                .padding(.horizontal, 18)
                .padding(.top, 66)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer()
        }
        .allowsHitTesting(false)
    }
}
