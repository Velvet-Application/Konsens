import SwiftUI
import LocalAuthentication
import Charts
import WidgetKit

struct RootView: View {
    @EnvironmentObject private var store: AppStore
    @ObservedObject private var notifications = NotificationManager.shared
    @State private var unlocked = false
    @State private var biometricAttempted = false

    var body: some View {
        ZStack {
            WorldBackdrop(tab: store.selectedTab).ignoresSafeArea()
            if store.isLoading { ProgressView().tint(Color.konsensGreen) }
            else if !store.isAuthenticated { AuthView() }
            else if !store.onboardingComplete { NativeOnboardingView() }
            else if !unlocked { LockedView(unlock: unlock) }
            else { cockpit }
            if let toast = store.toast {
                VStack {
                    Spacer()
                    Text(toast)
                        .font(.caption.bold())
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.09)))
                        .padding(.bottom, 98)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.32), value: store.selectedTab)
        .onChange(of: store.isAuthenticated) { _, authenticated in
            if !authenticated { unlocked = false; biometricAttempted = false; notifications.stop() }
        }
        .onOpenURL { route($0) }
        .task {
            if store.isAuthenticated && store.onboardingComplete {
                notifications.start(store: store)
                WatchBridge.shared.start()
                if !biometricAttempted { unlock() }
            }
        }
    }

    private var cockpit: some View {
        ZStack {
            Group {
                switch store.selectedTab {
                case .wealth: ArenaView()
                case .play: MarketsView()
                case .invest: InvestWorldView()
                case .learn: AcademyNativeView()
                case .profile: ProfileView()
                }
            }
            VStack(spacing: 0) {
                FloatingHeader(notifications: notifications)
                LearningSpine(tab: store.selectedTab)
                    .padding(.top, 7)
                Spacer()
                FloatingDock()
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 8)
        }
    }

    private func route(_ url: URL) {
        let destination = (url.host ?? url.path.replacingOccurrences(of: "/", with: "")).lowercased()
        switch destination {
        case "play": store.selectedTab = .play
        case "invest", "finance": store.selectedTab = .invest
        case "learn", "academy": store.selectedTab = .learn
        case "profile", "notifications", "blockchain": store.selectedTab = .profile
        default: store.selectedTab = .wealth
        }
    }

    private func unlock() {
        biometricAttempted = true
        let context = LAContext()
        context.localizedCancelTitle = "Plus tard"
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else { unlocked = true; return }
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Déverrouiller ton parcours Konsens") { success, _ in
            DispatchQueue.main.async { unlocked = success }
        }
    }
}

private struct InvestWorldView: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            LeagueView()
            OnChainPulseCard()
                .padding(.horizontal, 18)
                .padding(.bottom, 118)
        }
    }
}

private struct OnChainPulseCard: View {
    @EnvironmentObject private var store: AppStore
    @State private var pulse: ChainPulse?
    @State private var loading = false
    @State private var expanded = true
    @State private var status = "Connexion au réseau public…"

    var body: some View {
        VStack(alignment: .leading, spacing: expanded ? 9 : 0) {
            Button { withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() } } label: {
                HStack(spacing: 8) {
                    Circle().fill(Color.konsensGreen).frame(width: 6, height: 6).shadow(color: Color.konsensGreen, radius: 5)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("ON-CHAIN PULSE · ETHEREUM")
                            .font(.system(size: 7, weight: .black, design: .monospaced))
                            .tracking(1).foregroundStyle(Color.konsensGreen)
                        Text(pulse?.walletName ?? "Transparence blockchain")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    if let pulse {
                        Text(signed(pulse.netFlowEUR))
                            .font(.caption.monospacedDigit().bold())
                            .foregroundStyle(pulse.netFlowEUR >= 0 ? Color.konsensPositive : Color.konsensNegative)
                    }
                    Image(systemName: expanded ? "chevron.down" : "chevron.up")
                        .font(.caption).foregroundStyle(Color.konsensMuted)
                }
            }
            .buttonStyle(.plain)

            if expanded {
                if loading {
                    HStack(spacing: 8) {
                        ProgressView().tint(Color.konsensGreen)
                        Text("Lecture des dernières transactions publiques…")
                            .font(.system(size: 8, design: .monospaced)).foregroundStyle(Color.konsensMuted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
                } else if let pulse, !pulse.points.isEmpty {
                    Chart(pulse.points) { point in
                        BarMark(
                            x: .value("Temps", point.time),
                            y: .value("Flux", point.direction == "in" ? max(point.valueEUR, 1) : -max(point.valueEUR, 1))
                        )
                        .foregroundStyle(point.direction == "in" ? Color.konsensPositive.opacity(0.85) : Color.konsensNegative.opacity(0.85))
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .frame(height: 72)

                    HStack(spacing: 10) {
                        chainMetric("ENTRÉES", pulse.inflowEUR, Color.konsensPositive)
                        chainMetric("SORTIES", pulse.outflowEUR, Color.konsensNegative)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("SOURCE").font(.system(size: 5, weight: .black, design: .monospaced)).foregroundStyle(Color.konsensMuted)
                            Text(pulse.provider).font(.system(size: 7, weight: .bold, design: .monospaced)).lineLimit(1)
                            Text("attrib. \(pulse.confidence)%").font(.system(size: 5, design: .monospaced)).foregroundStyle(Color.konsensMuted)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Text("Vert = entrées · rouge = sorties. Données publiques de chaîne : elles apportent de la transparence, jamais une garantie de performance.")
                        .font(.system(size: 7)).foregroundStyle(Color.konsensMuted).lineLimit(2)
                } else {
                    Text(status).font(.system(size: 8)).foregroundStyle(Color.konsensMuted)
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.konsensGreen.opacity(0.16)))
        .shadow(color: Color.black.opacity(0.28), radius: 18, y: 8)
        .task { await refresh() }
        .onTapGesture(count: 2) { Task { await refresh() } }
    }

    private func refresh() async {
        guard !loading else { return }
        loading = true
        status = "Connexion au réseau Ethereum public…"
        defer { loading = false }

        struct Params: Encodable { let p_limit: Int }
        struct Whale: Decodable {
            let id: UUID
            let address: String
            let display_name: String
            let wallet_kind: String
            let confidence_score: Int
        }

        let whales: [Whale] = (try? await store.supabase
            .rpc("get_whale_leaderboard", params: Params(p_limit: 12))
            .execute().value) ?? []

        guard let whale = whales.first(where: { ["exchange", "institution", "bridge"].contains($0.wallet_kind) }) ?? whales.first else {
            pulse = nil
            status = "Aucune adresse publique disponible pour le moment."
            return
        }

        guard var components = URLComponents(string: "https://mxuevsspybxoovsutsbs.supabase.co/functions/v1/blockchain-data") else { return }
        components.queryItems = [
            URLQueryItem(name: "wallet_id", value: whale.id.uuidString),
            URLQueryItem(name: "address", value: whale.address)
        ]
        guard let url = components.url, let token = store.supabase.auth.currentSession?.accessToken else {
            status = "Reconnecte-toi pour lire la chaîne."
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("sb_publishable_Xs7hyyDA2XUkbwXGGfSE2w_tARkgSL7", forHTTPHeaderField: "apikey")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
            let envelope = try JSONDecoder().decode(ChainEnvelope.self, from: data)
            let formatter = ISO8601DateFormatter()
            let points = envelope.transactions.prefix(24).compactMap { tx -> ChainPoint? in
                guard let date = formatter.date(from: tx.blockTime) else { return nil }
                return ChainPoint(
                    id: tx.providerEventId,
                    time: date,
                    direction: tx.direction,
                    valueEUR: abs(tx.estimatedValueEUR ?? 0),
                    asset: tx.assetSymbol
                )
            }.sorted { $0.time < $1.time }

            let next = ChainPulse(
                walletName: whale.display_name,
                walletKind: whale.wallet_kind,
                confidence: whale.confidence_score,
                provider: envelope.provider,
                points: points
            )
            pulse = next
            status = points.isEmpty ? "Flux public synchronisé, sans valorisation EUR exploitable sur ces transactions." : "Flux public synchronisé."

            if let defaults = UserDefaults(suiteName: "group.com.konsens.beta") {
                defaults.set(next.walletName, forKey: "konsens_widget_chain_wallet")
                defaults.set(next.provider, forKey: "konsens_widget_chain_provider")
                defaults.set(next.netFlowEUR, forKey: "konsens_widget_chain_flow")
                WidgetCenter.shared.reloadAllTimelines()
            }
        } catch {
            pulse = nil
            status = "Le flux blockchain est momentanément indisponible."
        }
    }

    private func chainMetric(_ label: String, _ value: Double, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 5, weight: .black, design: .monospaced)).foregroundStyle(Color.konsensMuted)
            Text(value.formatted(.currency(code: "EUR").notation(.compactName).precision(.fractionLength(0))))
                .font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func signed(_ value: Double) -> String {
        let prefix = value > 0 ? "+" : ""
        return prefix + value.formatted(.number.notation(.compactName).precision(.fractionLength(0))) + "€ net"
    }
}

private struct ChainPoint: Identifiable, Hashable {
    let id: String
    let time: Date
    let direction: String
    let valueEUR: Double
    let asset: String
}

private struct ChainPulse: Hashable {
    let walletName: String
    let walletKind: String
    let confidence: Int
    let provider: String
    let points: [ChainPoint]

    var inflowEUR: Double { points.filter { $0.direction == "in" }.reduce(0) { $0 + $1.valueEUR } }
    var outflowEUR: Double { points.filter { $0.direction != "in" }.reduce(0) { $0 + $1.valueEUR } }
    var netFlowEUR: Double { inflowEUR - outflowEUR }
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

private struct WorldBackdrop: View {
    let tab: AppTab

    var body: some View {
        ZStack {
            base
            LinearGradient(
                colors: [Color.konsensGreen.opacity(tab == .wealth || tab == .profile ? 0.06 : 0.035), .clear],
                startPoint: .topLeading,
                endPoint: .center
            )
            if tab == .play {
                RadialGradient(colors: [Color.konsensViolet.opacity(0.26), .clear], center: .topTrailing, startRadius: 0, endRadius: 420)
                RadialGradient(colors: [Color.konsensGreen.opacity(0.08), .clear], center: .bottomLeading, startRadius: 0, endRadius: 360)
                PlayGrid().opacity(0.55)
                Circle().stroke(Color.konsensViolet.opacity(0.12), lineWidth: 1).frame(width: 310, height: 310).offset(x: 180, y: -320)
                Circle().stroke(Color.konsensGreen.opacity(0.08), lineWidth: 1).frame(width: 220, height: 220).offset(x: 150, y: -290)
            } else if tab == .invest {
                FinanceGrid().opacity(0.52)
                LinearGradient(colors: [Color.konsensBlue.opacity(0.08), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
            } else if tab == .learn {
                RadialGradient(colors: [Color.konsensGreen.opacity(0.15), .clear], center: .topTrailing, startRadius: 0, endRadius: 360)
                RadialGradient(colors: [Color.konsensGold.opacity(0.10), .clear], center: .bottomLeading, startRadius: 0, endRadius: 300)
                AcademyDots().opacity(0.55)
            }
        }
    }

    private var base: Color {
        switch tab {
        case .play: Color(red: 0.035, green: 0.027, blue: 0.075)
        case .invest: Color(red: 0.018, green: 0.035, blue: 0.047)
        case .learn: Color(red: 0.031, green: 0.064, blue: 0.046)
        default: Color.konsensBackground
        }
    }
}

private struct PlayGrid: View {
    var body: some View {
        Canvas { context, size in
            var path = Path()
            let step: CGFloat = 44
            var x: CGFloat = 0
            while x < size.width {
                path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: size.height)); x += step
            }
            var y: CGFloat = 0
            while y < size.height {
                path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y)); y += step
            }
            context.stroke(path, with: .color(Color.konsensViolet.opacity(0.07)), lineWidth: 0.5)
        }
    }
}

private struct AcademyDots: View {
    var body: some View {
        Canvas { context, size in
            for row in 0..<16 {
                for col in 0..<10 {
                    let rect = CGRect(x: CGFloat(col) * 46 + 12, y: CGFloat(row) * 52 + 16, width: 3, height: 3)
                    context.fill(Path(ellipseIn: rect), with: .color(Color.konsensGreen.opacity(0.06)))
                }
            }
        }
    }
}

private struct FinanceGrid: View {
    var body: some View {
        Canvas { context, size in
            var path = Path()
            let step: CGFloat = 34
            var x: CGFloat = 0
            while x < size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += step
            }
            var y: CGFloat = 0
            while y < size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += step
            }
            context.stroke(path, with: .color(Color.konsensBlue.opacity(0.08)), lineWidth: 0.5)
        }
    }
}

private struct FloatingHeader: View {
    @EnvironmentObject private var store: AppStore
    @ObservedObject var notifications: NotificationManager

    var body: some View {
        HStack(spacing: 8) {
            KonsensMark(compact: true)
                .padding(8)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: headerRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: headerRadius).stroke(accent.opacity(0.16)))
            Text(universeName)
                .font(.system(size: 7, weight: .black, design: store.selectedTab == .invest ? .monospaced : .rounded))
                .tracking(1.1)
                .foregroundStyle(accent)
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .background(accent.opacity(0.08), in: Capsule())
            Spacer()
            Button { store.selectedTab = .profile } label: {
                ZStack {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.konsensMuted)
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial, in: Circle())
                    if notifications.unreadCount > 0 {
                        Text("\(min(notifications.unreadCount, 9))")
                            .font(.system(size: 7, weight: .black))
                            .foregroundStyle(.white)
                            .frame(width: 15, height: 15)
                            .background(Color.konsensViolet, in: Circle())
                            .offset(x: 13, y: -13)
                    }
                }
            }
            .buttonStyle(.plain)
            Button { store.selectedTab = .profile } label: {
                VStack(alignment: .trailing, spacing: 1) {
                    Text(store.subscriptionTier == "premium" ? "PREMIUM" : "PARCOURS")
                        .font(.system(size: 7, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(Color.konsensMuted)
                    HStack(spacing: 5) {
                        Text(store.wealth.total.formatted(.number.precision(.fractionLength(0))))
                            .font(.subheadline.monospacedDigit().bold())
                        Text("K").font(.system(size: 8)).foregroundStyle(Color.konsensMuted)
                        Text(String(format: "%+.1f%%", store.wealth.performance))
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(store.wealth.performance >= 0 ? Color.konsensPositive : Color.konsensNegative)
                    }
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: headerRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: headerRadius).stroke(accent.opacity(0.14)))
            }
            .buttonStyle(.plain)
        }
    }

    private var accent: Color {
        switch store.selectedTab {
        case .play: Color.konsensViolet
        case .invest: Color.konsensBlue
        case .learn: Color.konsensGreen
        default: Color.konsensGreen
        }
    }

    private var universeName: String {
        switch store.selectedTab {
        case .play: "PLAY"
        case .invest: "INVESTIR"
        case .learn: "APPRENDRE"
        case .wealth: "AUJOURD’HUI"
        case .profile: "PROFIL"
        }
    }

    private var headerRadius: CGFloat { store.selectedTab == .invest ? 10 : 16 }
}

private struct LearningSpine: View {
    let tab: AppTab

    var body: some View {
        HStack(spacing: 8) {
            Capsule()
                .fill(Color.konsensGreen)
                .frame(width: 34, height: 2)
                .shadow(color: Color.konsensGreen.opacity(0.65), radius: 5)
            Text(copy)
                .font(.system(size: 6, weight: .black, design: tab == .invest ? .monospaced : .rounded))
                .tracking(0.75)
                .foregroundStyle(Color.konsensGreen.opacity(0.92))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
        .accessibilityLabel("Fil conducteur : \(copy)")
    }

    private var copy: String {
        switch tab {
        case .play: "TESTER UNE INTUITION → COMPRENDRE LE RISQUE"
        case .invest: "OBSERVER → SIMULER → MESURER LE RISQUE"
        case .learn: "APPRENDRE → TESTER → PROGRESSER"
        case .wealth: "CHAQUE JOUR → MIEUX DÉCIDER AVEC L’ARGENT"
        case .profile: "MESURER TA PROGRESSION, PAS SEULEMENT TES GAINS"
        }
    }
}

private struct FloatingDock: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        VStack(spacing: 0) {
            Capsule().fill(Color.konsensGreen.opacity(0.75)).frame(height: 2).padding(.horizontal, 12)
            HStack(spacing: 3) {
                ForEach(AppTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) { store.selectedTab = tab }
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: tab.symbol).font(.system(size: 16, weight: .semibold))
                            Text(tab.title).font(.system(size: 7, weight: .semibold))
                        }
                        .foregroundStyle(store.selectedTab == tab ? activeAccent : Color.konsensMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(store.selectedTab == tab ? activeAccent.opacity(0.10) : Color.clear, in: RoundedRectangle(cornerRadius: store.selectedTab == .invest ? 8 : 14))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(5)
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: store.selectedTab == .invest ? 14 : 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: store.selectedTab == .invest ? 14 : 22).stroke(activeAccent.opacity(0.15)))
        .shadow(color: Color.black.opacity(0.35), radius: 26, y: 14)
    }

    private var activeAccent: Color {
        switch store.selectedTab {
        case .play: Color.konsensViolet
        case .invest: Color.konsensBlue
        case .learn: Color.konsensGreen
        default: Color.konsensGreen
        }
    }
}

private struct LockedView: View {
    let unlock: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            KonsensMark()
            Image(systemName: "faceid").font(.system(size: 52)).foregroundStyle(Color.konsensGreen)
            Text("Ton parcours est verrouillé").font(.title2.bold())
            Text("Utilise Face ID pour retrouver tes Koins, tes décisions et ta progression.")
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.konsensMuted)
                .font(.subheadline)
            Button("Déverrouiller avec Face ID", action: unlock)
                .font(.headline)
                .foregroundStyle(Color.konsensBackground)
                .padding(.horizontal, 20)
                .padding(.vertical, 13)
                .background(Color.konsensGreen, in: Capsule())
        }
        .padding(30)
    }
}