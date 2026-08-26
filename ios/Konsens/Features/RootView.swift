import SwiftUI
import LocalAuthentication
import UIKit
import RealityKit
import simd

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
        .onChange(of: store.selectedTab) { _, tab in
            guard unlocked, !isFinancePro else { return }
            mascot.react(.navigation(tab.title), username: store.username)
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

// MARK: - Konsens mascot · RealityKit/USDZ

private final class KonsensMascotDirector: ObservableObject {
    enum Phase: Equatable { case hidden, launch, peek, reaction }
    enum CoinEffect: Equatable { case none, gain, loss, stake }
    enum Action: String, Equatable {
        case idle
        case wave
        case peek
        case laugh
        case tease
        case coinToss
        case celebrate
        case lose
        case shrug

        var clipHints: [String] {
            switch self {
            case .idle: return ["idle", "breath"]
            case .wave: return ["wave", "hello", "opening", "welcome"]
            case .peek: return ["peek", "appear", "look"]
            case .laugh: return ["laugh", "chuckle"]
            case .tease: return ["tease", "taunt", "wink", "point"]
            case .coinToss: return ["coin_toss", "coin", "toss", "bet"]
            case .celebrate: return ["celebrate", "win", "victory", "happy"]
            case .lose: return ["lose", "loss", "fail", "coin_disappear"]
            case .shrug: return ["shrug", "rejected", "no_money"]
            }
        }
    }
    enum Signal: Equatable {
        case betPlaced
        case investment
        case rejected
        case gain(Int)
        case loss(Int)
        case navigation(String)
    }

    @Published var phase: Phase = .hidden
    @Published var message = ""
    @Published var coinEffect: CoinEffect = .none
    @Published var action: Action = .idle
    @Published var presentationID = UUID()

    private var started = false
    private var randomTask: Task<Void, Never>?
    private var hideTask: Task<Void, Never>?

    func start(username: String) {
        guard !started else { return }
        started = true
        present(
            phase: .launch,
            message: "Salut @\(username). Prêt à faire mieux que tes potes ?",
            coin: .gain,
            action: .wave,
            duration: 4
        )
        randomTask = Task { @MainActor [weak self] in
            try? await Task<Never, Never>.sleep(nanoseconds: 28_000_000_000)
            while !Task.isCancelled {
                guard let self else { return }
                self.randomPeek()
                let seconds = UInt64(Int.random(in: 28...65))
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
            action = .idle
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
                action: .coinToss,
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
                action: .tease,
                duration: 3
            )
        case .rejected:
            present(
                phase: .reaction,
                message: "Même moi, je ne peux pas miser des Koins que tu n’as pas.",
                coin: .none,
                action: .shrug,
                duration: 3
            )
        case .gain(let amount):
            let line = amount == 100
                ? "100 K récupérés. Belle récolte."
                : "+\(amount) K. Ah… là, tu commences à devenir agaçant."
            present(phase: .reaction, message: line, coin: .gain, action: .celebrate, duration: 3)
        case .loss(let amount):
            present(
                phase: .reaction,
                message: [
                    "−\(amount) K. Et hop… un Koin qui s’évapore.",
                    "Aïe. \(amount) K viennent de disparaître. Beau geste.",
                    "On va faire comme si personne dans ta ligue n’avait vu ça."
                ].randomElement()!,
                coin: .loss,
                action: .lose,
                duration: 3
            )
        case .navigation(let destination):
            let lower = destination.lowercased()
            let line: String
            let nextAction: Action
            if lower.contains("ligue") {
                line = "Va voir le classement. J’espère que tu n’as pas besoin de scroller trop bas."
                nextAction = .tease
            } else if lower.contains("jou") || lower.contains("mis") {
                line = "Ah, on vient jouer ? Là ça devient intéressant."
                nextAction = .peek
            } else if lower.contains("invest") {
                line = "Investir ? Essaie de faire semblant d’avoir un plan."
                nextAction = .tease
            } else if lower.contains("appr") || lower.contains("acad") {
                line = "Un peu de théorie. Ça peut sauver quelques Koins."
                nextAction = .wave
            } else {
                line = "Je te suis. Quelqu’un doit surveiller tes décisions."
                nextAction = .peek
            }
            present(phase: .peek, message: line, coin: .none, action: nextAction, duration: 2)
        }
    }

    private func randomPeek() {
        guard phase == .hidden else { return }
        let moments: [(String, Action)] = [
            ("Je surveille ton classement. Ça peut encore s’arranger.", .peek),
            ("T’as un plan… ou tu cliques au talent ?", .tease),
            ("Ton pote devant toi commence à se détendre. Mauvaise idée.", .tease),
            ("Un petit pari ? Qu’est-ce qui pourrait mal se passer ?", .peek),
            ("Je dis ça, je dis rien… mais ta ligue n’attend pas.", .wave),
            ("Je passais juste voir si tes Koins travaillaient vraiment.", .peek),
            ("Encore quelques bons coups et tu pourras vraiment les chambrer.", .laugh)
        ]
        let moment = moments.randomElement()!
        present(phase: .peek, message: moment.0, coin: .none, action: moment.1, duration: 4)
    }

    private func present(phase nextPhase: Phase, message: String, coin: CoinEffect, action: Action, duration: UInt64) {
        hideTask?.cancel()
        presentationID = UUID()
        withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
            self.message = message
            self.coinEffect = coin
            self.action = action
            self.phase = nextPhase
        }
        let id = presentationID
        hideTask = Task { @MainActor [weak self] in
            try? await Task<Never, Never>.sleep(nanoseconds: duration * 1_000_000_000)
            guard let self, !Task.isCancelled, self.presentationID == id else { return }
            withAnimation(.easeInOut(duration: 0.28)) {
                self.phase = .hidden
                self.coinEffect = .none
                self.action = .idle
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
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()
                        .transition(.opacity)

                    VStack(spacing: 10) {
                        Spacer(minLength: 20)
                        mascot(fullSize: true)
                            .frame(width: min(proxy.size.width * 0.92, 390), height: min(proxy.size.height * 0.58, 470))
                        MascotSpeechBubble(text: director.message, prominent: true)
                            .frame(maxWidth: min(proxy.size.width - 40, 370))
                        Spacer(minLength: 76)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.scale(scale: 0.86).combined(with: .opacity))
                } else if director.phase == .peek || director.phase == .reaction {
                    VStack {
                        Spacer()
                        HStack(alignment: .bottom, spacing: 6) {
                            Spacer(minLength: 14)
                            MascotSpeechBubble(text: director.message, prominent: false)
                                .frame(maxWidth: min(proxy.size.width * 0.60, 245))
                            mascot(fullSize: false)
                                .frame(width: 158, height: 188)
                                .offset(x: 24)
                        }
                        .padding(.bottom, 112)
                    }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }

                if director.coinEffect != .none && !KonsensMascot3DView.isAvailable {
                    MascotCoinFallback(effect: director.coinEffect)
                        .id(director.presentationID)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .animation(.spring(response: 0.42, dampingFraction: 0.8), value: director.phase)
    }

    @ViewBuilder
    private func mascot(fullSize: Bool) -> some View {
        if KonsensMascot3DView.isAvailable {
            KonsensMascot3DView(action: director.action, presentationID: director.presentationID)
                .clipShape(RoundedRectangle(cornerRadius: fullSize ? 30 : 38, style: .continuous))
                .shadow(color: Color.konsensGold.opacity(fullSize ? 0.20 : 0.10), radius: fullSize ? 28 : 14, y: 10)
        } else {
            KonsensMascotFallback(fullSize: fullSize)
        }
    }
}

private struct KonsensMascot3DView: UIViewRepresentable {
    let action: KonsensMascotDirector.Action
    let presentationID: UUID

    static var isAvailable: Bool {
        Bundle.main.url(forResource: "KonsensMascot", withExtension: "usdz") != nil
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        arView.backgroundColor = .clear
        arView.environment.background = .color(.clear)
        context.coordinator.install(in: arView)
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.play(action: action, presentationID: presentationID)
    }

    final class Coordinator {
        private weak var arView: ARView?
        private var mascot: Entity?
        private var baseTransform = Transform.identity
        private var lastPresentationID: UUID?
        private var pendingAction: KonsensMascotDirector.Action = .idle

        func install(in arView: ARView) {
            self.arView = arView

            let world = AnchorEntity(world: .zero)
            arView.scene.addAnchor(world)

            let camera = PerspectiveCamera()
            camera.camera.fieldOfViewInDegrees = 32
            camera.look(at: [0, 0.62, 0], from: [0, 0.48, 2.45], relativeTo: nil)
            world.addChild(camera)

            let key = DirectionalLight()
            key.light.intensity = 16_000
            key.look(at: [0, 0.55, 0], from: [1.2, 1.8, 2.0], relativeTo: nil)
            world.addChild(key)

            let fill = PointLight()
            fill.light.intensity = 2_800
            fill.light.attenuationRadius = 4
            fill.position = [-1.3, 0.8, 1.2]
            world.addChild(fill)

            do {
                let entity = try Entity.load(named: "KonsensMascot")
                entity.name = "KonsensMascot"
                entity.position = [0, -0.72, 0]
                entity.scale = SIMD3<Float>(repeating: 0.82)
                world.addChild(entity)
                mascot = entity
                baseTransform = entity.transform
                play(action: pendingAction, presentationID: UUID())
            } catch {
                mascot = nil
            }
        }

        func play(action: KonsensMascotDirector.Action, presentationID: UUID) {
            pendingAction = action
            guard lastPresentationID != presentationID || action == .idle else { return }
            lastPresentationID = presentationID
            guard let mascot else { return }

            mascot.stopAllAnimations(recursive: true)
            if let match = findAnimation(in: mascot, hints: action.clipHints) {
                match.entity.playAnimation(match.animation, transitionDuration: 0.16, startsPaused: false)
                return
            }
            playTransformFallback(action, on: mascot)
        }

        private func findAnimation(in entity: Entity, hints: [String]) -> (entity: Entity, animation: AnimationResource)? {
            let lowerHints = hints.map { $0.lowercased() }
            for animation in entity.availableAnimations {
                let name = animation.name?.lowercased() ?? ""
                if lowerHints.contains(where: { name.contains($0) }) {
                    return (entity, animation)
                }
            }
            for child in entity.children {
                if let found = findAnimation(in: child, hints: hints) { return found }
            }
            return nil
        }

        private func playTransformFallback(_ action: KonsensMascotDirector.Action, on entity: Entity) {
            entity.transform = baseTransform
            var target = baseTransform

            switch action {
            case .idle:
                target.translation.y += 0.02
            case .wave:
                target.rotation = simd_mul(baseTransform.rotation, simd_quatf(angle: -0.10, axis: [0, 1, 0]))
                target.translation.y += 0.04
            case .peek:
                target.rotation = simd_mul(baseTransform.rotation, simd_quatf(angle: 0.16, axis: [0, 1, 0]))
                target.translation.x += 0.08
            case .laugh:
                target.rotation = simd_mul(baseTransform.rotation, simd_quatf(angle: 0.06, axis: [0, 0, 1]))
                target.translation.y += 0.08
            case .tease:
                target.rotation = simd_mul(baseTransform.rotation, simd_quatf(angle: -0.12, axis: [0, 1, 0]))
                target.translation.x -= 0.04
            case .coinToss:
                target.rotation = simd_mul(baseTransform.rotation, simd_quatf(angle: 0.12, axis: [0, 1, 0]))
                target.translation.y += 0.06
            case .celebrate:
                target.translation.y += 0.13
                target.scale *= 1.04
            case .lose:
                target.rotation = simd_mul(baseTransform.rotation, simd_quatf(angle: 0.08, axis: [0, 0, 1]))
                target.translation.y -= 0.05
            case .shrug:
                target.rotation = simd_mul(baseTransform.rotation, simd_quatf(angle: -0.06, axis: [0, 0, 1]))
            }

            entity.move(to: target, relativeTo: entity.parent, duration: 0.24, timingFunction: .easeInOut)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) { [weak entity] in
                guard let entity else { return }
                entity.move(to: self.baseTransform, relativeTo: entity.parent, duration: 0.32, timingFunction: .easeInOut)
            }
        }
    }
}

private struct KonsensMascotFallback: View {
    let fullSize: Bool
    @State private var moving = false

    var body: some View {
        Image("KonsensMascotFallback")
            .resizable()
            .scaledToFit()
            .clipShape(RoundedRectangle(cornerRadius: fullSize ? 30 : 38, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: fullSize ? 30 : 38, style: .continuous)
                    .stroke(Color.konsensGold.opacity(0.34), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.46), radius: 18, y: 10)
            .offset(y: moving ? -5 : 5)
            .rotation3DEffect(
                .degrees(moving ? 3.5 : -2.5),
                axis: (x: 0.05, y: 1, z: 0),
                perspective: 0.72
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 1.7).repeatForever(autoreverses: true)) {
                    moving = true
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

private struct MascotCoinFallback: View {
    let effect: KonsensMascotDirector.CoinEffect
    @State private var animate = false

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.yellow.opacity(0.96), Color.konsensGold, Color.orange.opacity(0.82)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Circle().stroke(Color.white.opacity(0.52), lineWidth: 2)
                    Text("K")
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .foregroundStyle(Color.black.opacity(0.70))
                }
                .frame(width: 102, height: 102)
                .shadow(color: Color.konsensGold.opacity(0.55), radius: 20)
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
            withAnimation(.easeInOut(duration: effect == .loss ? 1.15 : 1.35)) {
                animate = true
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
        return effect == .stake ? 150 : 0
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
