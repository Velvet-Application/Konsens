import SwiftUI
import LocalAuthentication
import UIKit

struct RootView: View {
    @EnvironmentObject private var store: AppStore
    @ObservedObject private var notifications = NotificationManager.shared
    @AppStorage("konsens_finance_pro_enabled") private var financeProEnabled = false
    @StateObject private var mascot = KonsensMascotDirector()
    @State private var unlocked = false
    @State private var biometricAttempted = false

    private var isFinancePro: Bool {
        financeProEnabled && store.subscriptionTier == "premium"
    }

    var body: some View {
        ZStack {
            WorldBackdrop(tab: store.selectedTab, financePro: isFinancePro).ignoresSafeArea()
            if store.isLoading {
                ProgressView().tint(Color.konsensGreen)
            } else if !store.isAuthenticated {
                AuthView()
            } else if !store.onboardingComplete {
                NativeOnboardingView()
            } else if !unlocked {
                LockedView(unlock: unlock)
            } else {
                cockpit
            }

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

            if store.isAuthenticated && store.onboardingComplete && unlocked && !isFinancePro {
                KonsensMascotLayer(director: mascot)
                    .zIndex(100)
            }
        }
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.28), value: store.selectedTab)
        .onChange(of: store.isAuthenticated) { _, authenticated in
            if !authenticated {
                unlocked = false
                biometricAttempted = false
                notifications.stop()
                mascot.stop()
            }
        }
        .onChange(of: unlocked) { _, value in
            guard value, store.isAuthenticated, store.onboardingComplete, !isFinancePro else { return }
            mascot.start(username: store.username)
        }
        .onChange(of: financeProEnabled) { _, enabled in
            if enabled && store.subscriptionTier != "premium" {
                financeProEnabled = false
            }
            if enabled && store.selectedTab == .league {
                store.selectedTab = .wealth
            }
            if enabled {
                mascot.stop()
            } else if unlocked && store.isAuthenticated && store.onboardingComplete {
                mascot.start(username: store.username)
            }
        }
        .onChange(of: store.wealth.total) { oldValue, newValue in
            guard unlocked, !isFinancePro, oldValue > 0 else { return }
            let delta = newValue - oldValue
            guard abs(delta) >= 5 else { return }
            mascot.react(delta >= 0 ? .gain(Int(delta.rounded())) : .loss(Int(abs(delta).rounded())), username: store.username)
        }
        .onChange(of: store.toast) { _, toast in
            guard unlocked, !isFinancePro, let toast else { return }
            if toast.contains("Position Play enregistrée") {
                mascot.react(.betPlaced, username: store.username)
            } else if toast.contains("Investissement simulé exécuté") {
                mascot.react(.investment, username: store.username)
            } else if toast.localizedCaseInsensitiveContains("ordre refusé") || toast.localizedCaseInsensitiveContains("solde") {
                mascot.react(.rejected, username: store.username)
            }
        }
        .onOpenURL { route($0) }
        .task {
            if store.isAuthenticated && store.onboardingComplete {
                notifications.start(store: store)
                WatchBridge.shared.start()
                if !biometricAttempted { unlock() }
                if unlocked && !isFinancePro { mascot.start(username: store.username) }
            }
        }
    }

    @ViewBuilder
    private var cockpit: some View {
        ZStack {
            Group {
                switch store.selectedTab {
                case .wealth:
                    if isFinancePro { FinanceLegacyHomeView() } else { ArenaView() }
                case .play:
                    if isFinancePro { MarketsView() } else { GamePlayView() }
                case .invest:
                    if isFinancePro { LeagueView() } else { GameInvestView() }
                case .league:
                    LeagueSocialView()
                case .learn:
                    AcademyNativeView()
                case .profile:
                    ProfileView()
                }
            }

            VStack(spacing: 0) {
                FloatingHeader(financePro: isFinancePro, notifications: notifications)
                GameModeRibbon(financePro: isFinancePro)
                    .padding(.top, 7)
                Spacer()
                FloatingDock(financePro: isFinancePro)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 8)
        }
    }

    private func route(_ url: URL) {
        let destination = (url.host ?? url.path.replacingOccurrences(of: "/", with: "")).lowercased()
        switch destination {
        case "play", "bet": store.selectedTab = .play
        case "invest", "finance": store.selectedTab = .invest
        case "league": store.selectedTab = .league
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
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            unlocked = true
            return
        }
        context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "Déverrouiller ton patrimoine Konsens"
        ) { success, _ in
            DispatchQueue.main.async { unlocked = success }
        }
    }
}

private struct WorldBackdrop: View {
    let tab: AppTab
    let financePro: Bool

    var body: some View {
        ZStack {
            Color.konsensBackground

            if financePro {
                LinearGradient(
                    colors: [Color.konsensBlue.opacity(0.11), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                FinanceGrid().opacity(0.38)
            } else {
                RadialGradient(
                    colors: [accent.opacity(0.30), .clear],
                    center: .topTrailing,
                    startRadius: 0,
                    endRadius: 430
                )
                RadialGradient(
                    colors: [Color.konsensGreen.opacity(0.10), .clear],
                    center: .bottomLeading,
                    startRadius: 0,
                    endRadius: 360
                )
                Circle()
                    .stroke(accent.opacity(0.10), lineWidth: 1)
                    .frame(width: 330, height: 330)
                    .offset(x: 180, y: -340)
            }
        }
    }

    private var accent: Color {
        switch tab {
        case .wealth: return Color.konsensViolet
        case .play: return Color.konsensViolet
        case .invest: return Color.konsensBlue
        case .league: return Color.konsensGold
        case .learn: return Color.konsensGreen
        case .profile: return Color.konsensViolet
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
    let financePro: Bool
    @ObservedObject var notifications: NotificationManager

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Image("KonsensLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 31, height: 31)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 1) {
                    Text(financePro ? "KONSENS PRO" : "KONSENS GAME")
                        .font(.system(size: 8, weight: .black, design: financePro ? .monospaced : .rounded))
                        .tracking(0.8)
                        .foregroundStyle(financePro ? Color.konsensBlue : Color.konsensGreen)
                    Text("@\(store.username)")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.konsensMuted)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 15, style: .continuous))

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
                    Text(financePro ? "PATRIMOINE" : "SCORE")
                        .font(.system(size: 6, weight: .black, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(Color.konsensMuted)
                    Text(String(format: "%.0f K", store.wealth.total))
                        .font(.subheadline.monospacedDigit().bold())
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }
}

private struct GameModeRibbon: View {
    let financePro: Bool

    var body: some View {
        HStack(spacing: 7) {
            Capsule()
                .fill(financePro ? Color.konsensBlue : Color.konsensGreen)
                .frame(width: 31, height: 2)
            Text(financePro ? "MODE FINANCE PRO · ANALYSE DÉTAILLÉE" : "PATRIMOINE = SCORE · JOUE · INVESTIS · GRIMPE")
                .font(.system(size: 6, weight: .black, design: financePro ? .monospaced : .rounded))
                .tracking(0.7)
                .foregroundStyle(financePro ? Color.konsensBlue : Color.konsensGreen)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
    }
}

private struct FloatingDock: View {
    @EnvironmentObject private var store: AppStore
    let financePro: Bool

    private var tabs: [AppTab] {
        financePro ? AppTab.financeTabs : AppTab.gameTabs
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(financePro ? Color.konsensBlue.opacity(0.75) : Color.konsensGreen.opacity(0.75))
                .frame(height: 2)
                .padding(.horizontal, 12)
            HStack(spacing: 3) {
                ForEach(tabs, id: \.self) { tab in
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) { store.selectedTab = tab }
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: tab.symbol)
                                .font(.system(size: 16, weight: .semibold))
                            Text(tab.title)
                                .font(.system(size: 7, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(store.selectedTab == tab ? accent(for: tab) : Color.konsensMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            store.selectedTab == tab ? accent(for: tab).opacity(0.11) : Color.clear,
                            in: RoundedRectangle(cornerRadius: financePro ? 8 : 14)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(5)
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: financePro ? 14 : 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: financePro ? 14 : 22).stroke(Color.white.opacity(0.08)))
        .shadow(color: Color.black.opacity(0.35), radius: 26, y: 14)
    }

    private func accent(for tab: AppTab) -> Color {
        if financePro {
            switch tab {
            case .play: return Color.konsensViolet
            case .invest: return Color.konsensBlue
            case .learn: return Color.konsensGreen
            default: return Color.konsensBlue
            }
        }
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

private struct LockedView: View {
    let unlock: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            KonsensMark()
            Image(systemName: "faceid")
                .font(.system(size: 52))
                .foregroundStyle(Color.konsensGreen)
            Text("Ton patrimoine est verrouillé")
                .font(.title2.bold())
            Text("Utilise Face ID pour retrouver tes Koins, tes challenges et ta ligue.")
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

// MARK: - Konsens mascot

private final class KonsensMascotDirector: ObservableObject {
    enum Phase: Equatable { case hidden, launch, peek, reaction }
    enum CoinEffect: Equatable { case none, gain, loss, stake }
    enum Signal: Equatable { case betPlaced, investment, rejected, gain(Int), loss(Int) }

    @Published var phase: Phase = .hidden
    @Published var message = ""
    @Published var coinEffect: CoinEffect = .none
    @Published var presentationID = UUID()

    private var started = false
    private var randomTask: Task<Void, Never>?
    private var hideTask: Task<Void, Never>?

    func start(username: String) {
        guard !started else { return }
        started = true
        present(
            phase: .launch,
            message: "Alors @\(username)… prêt à faire mieux que tes potes ?",
            coin: .gain,
            duration: 4
        )
        randomTask = Task { @MainActor [weak self] in
            try? await Task<Never, Never>.sleep(nanoseconds: 38_000_000_000)
            while !Task.isCancelled {
                guard let self else { return }
                self.randomPeek()
                let seconds = UInt64(Int.random(in: 38...78))
                try? await Task<Never, Never>.sleep(nanoseconds: seconds * 1_000_000_000)
            }
        }
    }

    func stop() {
        started = false
        randomTask?.cancel()
        hideTask?.cancel()
        randomTask = nil
        hideTask = nil
        withAnimation(.easeOut(duration: 0.2)) {
            phase = .hidden
            coinEffect = .none
        }
    }

    func react(_ signal: Signal, username: String) {
        switch signal {
        case .betPlaced:
            present(
                phase: .reaction,
                message: [
                    "Mise posée. Maintenant, assume.",
                    "Tu viens vraiment de jouer ça ? J’admire la confiance.",
                    "C’est parti. Je garde un œil sur tes Koins."
                ].randomElement()!,
                coin: .stake,
                duration: 3
            )
        case .investment:
            present(
                phase: .reaction,
                message: [
                    "Tes Koins sont au travail. Essaie de ne pas tout gâcher.",
                    "Investi. Propre. Maintenant on laisse le marché parler.",
                    "Ça, c’est plus élégant que de tout miser au hasard."
                ].randomElement()!,
                coin: .stake,
                duration: 3
            )
        case .rejected:
            present(
                phase: .reaction,
                message: "Même moi, je ne peux pas miser des Koins que tu n’as pas.",
                coin: .none,
                duration: 3
            )
        case .gain(let amount):
            let special = amount == 100 ? "100 K récupérés. Belle récolte." : "+\(amount) K. Ah… là, tu commences à devenir agaçant."
            present(phase: .reaction, message: special, coin: .gain, duration: 3)
        case .loss(let amount):
            present(
                phase: .reaction,
                message: [
                    "−\(amount) K. Et hop… un Koin qui s’évapore.",
                    "Aïe. \(amount) K viennent de changer de propriétaire imaginaire.",
                    "On va faire comme si personne dans ta ligue n’avait vu ça."
                ].randomElement()!,
                coin: .loss,
                duration: 3
            )
        }
    }

    private func randomPeek() {
        guard phase == .hidden else { return }
        let lines = [
            "Je surveille ton classement. Ça peut encore s’arranger.",
            "T’as un plan… ou tu cliques au talent ?",
            "Ton pote devant toi commence à se détendre. Mauvaise idée.",
            "Un petit pari ? Qu’est-ce qui pourrait mal se passer ?",
            "Je dis ça, je dis rien… mais ta ligue n’attend pas.",
            "Je passais juste voir si tes Koins travaillaient vraiment.",
            "Encore quelques bons coups et tu pourras vraiment les chambrer."
        ]
        present(phase: .peek, message: lines.randomElement()!, coin: .none, duration: 4)
    }

    private func present(phase nextPhase: Phase, message: String, coin: CoinEffect, duration: UInt64) {
        hideTask?.cancel()
        presentationID = UUID()
        withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
            self.message = message
            self.coinEffect = coin
            self.phase = nextPhase
        }
        let id = presentationID
        hideTask = Task { @MainActor [weak self] in
            try? await Task<Never, Never>.sleep(nanoseconds: duration * 1_000_000_000)
            guard let self, !Task.isCancelled, self.presentationID == id else { return }
            withAnimation(.easeInOut(duration: 0.28)) {
                self.phase = .hidden
                self.coinEffect = .none
            }
        }
    }
}

private struct KonsensMascotLayer: View {
    @ObservedObject var director: KonsensMascotDirector

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if director.phase == .launch {
                    Color.black.opacity(0.34)
                        .ignoresSafeArea()
                        .transition(.opacity)

                    VStack(spacing: 14) {
                        Spacer(minLength: 42)
                        KonsensMascotFullArtwork()
                            .frame(width: min(proxy.size.width * 0.82, 360))
                        MascotSpeechBubble(text: director.message, prominent: true)
                            .frame(maxWidth: min(proxy.size.width - 42, 360))
                        Spacer(minLength: 90)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.scale(scale: 0.86).combined(with: .opacity))
                } else if director.phase == .peek || director.phase == .reaction {
                    VStack {
                        Spacer()
                        HStack(alignment: .bottom, spacing: 8) {
                            Spacer(minLength: 18)
                            MascotSpeechBubble(text: director.message, prominent: false)
                                .frame(maxWidth: min(proxy.size.width * 0.62, 250))
                            KonsensMascotHeadArtwork()
                                .frame(width: 148, height: 158)
                                .offset(x: 24)
                        }
                        .padding(.bottom, 118)
                    }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }

                if director.coinEffect != .none {
                    MascotCoinEffectView(effect: director.coinEffect)
                        .id(director.presentationID)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .animation(.spring(response: 0.42, dampingFraction: 0.8), value: director.phase)
    }
}

private struct KonsensMascotFullArtwork: View {
    @State private var floating = false

    var body: some View {
        Image(uiImage: KonsensMascotArtwork.full)
            .resizable()
            .scaledToFit()
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(Color.konsensGold.opacity(0.28), lineWidth: 1)
            )
            .shadow(color: Color.konsensGold.opacity(0.22), radius: 34, y: 16)
            .offset(y: floating ? -5 : 5)
            .rotation3DEffect(
                .degrees(floating ? 2.4 : -2.4),
                axis: (x: 0.08, y: 1, z: 0),
                perspective: 0.72
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                    floating = true
                }
            }
    }
}

private struct KonsensMascotHeadArtwork: View {
    @State private var tilt = false

    var body: some View {
        Image(uiImage: KonsensMascotArtwork.head)
            .resizable()
            .scaledToFill()
            .clipShape(RoundedRectangle(cornerRadius: 38, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 38, style: .continuous)
                    .stroke(Color.konsensGold.opacity(0.55), lineWidth: 1.4)
            )
            .shadow(color: Color.black.opacity(0.55), radius: 18, y: 10)
            .rotation3DEffect(
                .degrees(tilt ? 5 : -3),
                axis: (x: 0.05, y: 1, z: 0),
                perspective: 0.76
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                    tilt = true
                }
            }
    }
}

private struct MascotSpeechBubble: View {
    let text: String
    let prominent: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Text("K")
                .font(.system(size: prominent ? 15 : 12, weight: .black, design: .rounded))
                .foregroundStyle(Color.black)
                .frame(width: prominent ? 30 : 25, height: prominent ? 30 : 25)
                .background(Color.konsensGold, in: Circle())
            Text(text)
                .font(.system(size: prominent ? 15 : 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, prominent ? 15 : 12)
        .padding(.vertical, prominent ? 13 : 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: prominent ? 20 : 17, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: prominent ? 20 : 17, style: .continuous)
                .stroke(Color.konsensGold.opacity(prominent ? 0.30 : 0.20), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 15, y: 8)
    }
}

private struct MascotCoinEffectView: View {
    let effect: KonsensMascotDirector.CoinEffect
    @State private var animate = false

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Image(uiImage: KonsensMascotArtwork.coin)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 104, height: 104)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.konsensGold.opacity(0.55), lineWidth: 1))
                    .shadow(color: Color.konsensGold.opacity(0.48), radius: 20)
                    .scaleEffect(scale)
                    .opacity(opacity)
                    .offset(x: xOffset, y: yOffset)
                    .rotation3DEffect(
                        .degrees(animate ? rotation : 0),
                        axis: (x: 0.12, y: 1, z: 0.08),
                        perspective: 0.55
                    )
                Spacer()
            }
            Spacer()
        }
        .onAppear {
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: effect == .loss ? 1.15 : 1.35)) {
                    animate = true
                }
            }
        }
    }

    private var scale: CGFloat {
        guard animate else { return effect == .gain ? 0.28 : 1.0 }
        switch effect {
        case .gain: return 1.42
        case .loss: return 0.02
        case .stake: return 0.18
        case .none: return 1
        }
    }

    private var opacity: Double {
        guard animate else { return 1 }
        switch effect {
        case .gain, .loss, .stake: return 0
        case .none: return 1
        }
    }

    private var xOffset: CGFloat {
        guard animate else { return 0 }
        switch effect {
        case .stake: return 150
        default: return 0
        }
    }

    private var yOffset: CGFloat {
        guard animate else { return 0 }
        switch effect {
        case .gain: return -115
        case .loss: return 95
        case .stake: return -35
        case .none: return 0
        }
    }

    private var rotation: Double {
        switch effect {
        case .gain: return 720
        case .loss: return -900
        case .stake: return 540
        case .none: return 0
        }
    }
}

private enum KonsensMascotArtwork {
    static let full: UIImage = {
        guard let data = Data(base64Encoded: base64, options: .ignoreUnknownCharacters),
              let image = UIImage(data: data) else { return UIImage() }
        return image
    }()

    static let head: UIImage = crop(
        full,
        normalized: CGRect(x: 0.267, y: 0.028, width: 0.508, height: 0.435)
    )

    static let coin: UIImage = crop(
        full,
        normalized: CGRect(x: 0.07, y: 0.255, width: 0.37, height: 0.30)
    )

    private static func crop(_ image: UIImage, normalized rect: CGRect) -> UIImage {
        guard let cg = image.cgImage else { return image }
        let width = CGFloat(cg.width)
        let height = CGFloat(cg.height)
        let cropRect = CGRect(
            x: rect.origin.x * width,
            y: rect.origin.y * height,
            width: rect.size.width * width,
            height: rect.size.height * height
        ).integral.intersection(CGRect(x: 0, y: 0, width: width, height: height))
        guard let cropped = cg.cropping(to: cropRect) else { return image }
        return UIImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation)
    }

    // Canonical artwork approved for Konsens. Keeping the render embedded guarantees
    // the mascot displayed in the app is pixel-faithful to the approved character.
    private static let base64 = """
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
"""
}
