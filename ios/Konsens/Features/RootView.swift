import SwiftUI
import LocalAuthentication

struct RootView: View {
    @EnvironmentObject private var store: AppStore
    @ObservedObject private var notifications = NotificationManager.shared
    @AppStorage("konsens_finance_pro_enabled") private var financeProEnabled = false
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
        }
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.28), value: store.selectedTab)
        .onChange(of: store.isAuthenticated) { _, authenticated in
            if !authenticated {
                unlocked = false
                biometricAttempted = false
                notifications.stop()
            }
        }
        .onChange(of: financeProEnabled) { _, enabled in
            if enabled && store.subscriptionTier != "premium" {
                financeProEnabled = false
            }
            if enabled && store.selectedTab == .league {
                store.selectedTab = .wealth
            }
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
